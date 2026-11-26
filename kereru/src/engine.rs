use crate::config::Config;
use crate::library::Library;
use crate::outputs::Monitor;
use crate::sys;
use anyhow::{Context, Result};
use std::collections::BTreeSet;
use std::ffi::{OsStr, OsString};
use std::io::{Read, Write};
use std::os::unix::fs::FileTypeExt;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

const LOG_LIMIT: u64 = 4 << 20;
const HANDLER_GRACE: Duration = Duration::from_secs(45);
pub const BWRAP: &str = "/usr/bin/bwrap";
const ENGINE_DIR: &str = "/opt/linux-wallpaperengine";
const SANDBOX_HOME: &str = "/tmp/home";
const SANDBOX_XAUTH: &str = "/tmp/.Xauthority";
const MAX_TREE: usize = 256;
const ETC: [&str; 19] = [
    "/etc/ld.so.cache",
    "/etc/ld.so.conf",
    "/etc/ld.so.conf.d",
    "/etc/fonts",
    "/etc/alsa",
    "/etc/asound.conf",
    "/etc/pulse",
    "/etc/vulkan",
    "/etc/glvnd",
    "/etc/egl",
    "/etc/drirc",
    "/etc/OpenCL",
    "/etc/nvidia",
    "/etc/localtime",
    "/etc/locale.conf",
    "/etc/machine-id",
    "/etc/passwd",
    "/etc/group",
    "/etc/nsswitch.conf",
];

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Plan {
    pub screens: Vec<(String, PathBuf)>,
    pub assets: Option<PathBuf>,
    pub fps: u32,
    pub sound: bool,
    pub volume: u32,
    pub scaling: &'static str,
    pub fullscreen_pause: bool,
}

pub fn plan(cfg: &Config, lib: &Library, monitors: &[Monitor]) -> Plan {
    let screens = monitors
        .iter()
        .filter_map(|m| {
            let key = cfg.wallpaper_for(&m.name)?;
            lib.resolve(key).map(|dir| (m.name.clone(), dir))
        })
        .collect();
    Plan {
        screens,
        assets: lib.assets.clone(),
        fps: cfg.fps.clamp(5, 240),
        sound: cfg.sound,
        volume: cfg.volume.min(100),
        scaling: cfg.scaling.as_str(),
        fullscreen_pause: cfg.pause_on_fullscreen,
    }
}

impl Plan {
    pub fn args(&self) -> Vec<OsString> {
        let mut a: Vec<OsString> = vec!["--fps".into(), self.fps.to_string().into()];
        if self.sound {
            a.push("--volume".into());
            a.push(self.volume.to_string().into());
        } else {
            a.push("--silent".into());
        }
        if !self.fullscreen_pause {
            a.push("--no-fullscreen-pause".into());
        }
        if let Some(assets) = &self.assets {
            a.push("--assets-dir".into());
            a.push(assets.clone().into_os_string());
        }
        for (screen, dir) in &self.screens {
            a.push("--screen-root".into());
            a.push(screen.into());
            a.push("--bg".into());
            a.push(dir.clone().into_os_string());
            a.push("--scaling".into());
            a.push(self.scaling.into());
        }
        a
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PauseVia {
    Unknown,
    Signals,
    Stop,
}

pub struct Engine {
    child: Child,
    pid: i32,
    target: Option<i32>,
    started: Instant,
    via: PauseVia,
    paused: bool,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Host {
    pub runtime: Option<PathBuf>,
    pub wayland: Option<(OsString, PathBuf)>,
    pub x11: Option<(OsString, PathBuf)>,
    pub xauthority: Option<PathBuf>,
    pub sound: Vec<PathBuf>,
    pub lang: Option<OsString>,
    pub session: Option<&'static str>,
    pub devices: Vec<PathBuf>,
}

fn is_socket(p: &Path) -> bool {
    std::fs::symlink_metadata(p).is_ok_and(|m| m.file_type().is_socket())
}

fn plain_name(v: &OsStr) -> bool {
    let b = v.as_encoded_bytes();
    !b.is_empty()
        && b.len() <= 64
        && b.iter()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, b'.' | b'_' | b'-' | b'@'))
}

pub fn session_type(host: Option<&str>, wayland: bool, x11: bool) -> Option<&'static str> {
    match host {
        Some("x11") if x11 => Some("x11"),
        Some("wayland") if wayland => Some("wayland"),
        _ if wayland => Some("wayland"),
        _ if x11 => Some("x11"),
        _ => None,
    }
}

pub fn x11_socket(display: &str) -> Option<PathBuf> {
    let rest = display.strip_prefix(':')?;
    let num = rest.split('.').next()?;
    (!num.is_empty() && num.len() <= 6 && num.bytes().all(|b| b.is_ascii_digit()))
        .then(|| PathBuf::from(format!("/tmp/.X11-unix/X{num}")))
}

impl Host {
    pub fn detect() -> Host {
        let runtime = sys::runtime_dir();
        let wayland = std::env::var_os("WAYLAND_DISPLAY").and_then(|v| {
            let p = Path::new(&v);
            let sock = if p.is_absolute() {
                p.to_path_buf()
            } else if plain_name(&v) {
                runtime.as_ref()?.join(p)
            } else {
                return None;
            };
            is_socket(&sock).then_some((v, sock))
        });
        let x11 = std::env::var("DISPLAY").ok().and_then(|d| {
            let sock = x11_socket(&d)?;
            is_socket(&sock).then(|| (OsString::from(d), sock))
        });
        let xauthority = x11.as_ref().and_then(|_| {
            std::env::var_os("XAUTHORITY")
                .map(PathBuf::from)
                .filter(|p| p.is_absolute())
                .or_else(|| sys::home().map(|h| h.join(".Xauthority")))
                .filter(|p| std::fs::symlink_metadata(p).is_ok_and(|m| m.is_file()))
        });
        let sound = runtime
            .iter()
            .flat_map(|r| [r.join("pulse/native"), r.join("pipewire-0")])
            .filter(|p| is_socket(p))
            .collect();
        let lang = std::env::var_os("LANG").filter(|v| plain_name(v));
        let session = session_type(
            std::env::var("XDG_SESSION_TYPE").ok().as_deref(),
            wayland.is_some(),
            x11.is_some(),
        );
        let mut devices: Vec<PathBuf> = std::fs::read_dir("/dev")
            .map(|d| {
                d.flatten()
                    .filter(|e| e.file_name().as_encoded_bytes().starts_with(b"nvidia"))
                    .filter(|e| e.file_type().is_ok_and(|t| t.is_char_device()))
                    .map(|e| e.path())
                    .collect()
            })
            .unwrap_or_default();
        devices.sort();
        Host {
            runtime,
            wayland,
            x11,
            xauthority,
            sound,
            lang,
            session,
            devices,
        }
    }
}

pub fn sandbox_args(bin: &Path, plan: &Plan, host: &Host) -> Vec<OsString> {
    let mut a: Vec<OsString> = Vec::new();
    let mut push = |parts: &[&OsStr]| a.extend(parts.iter().map(|p| p.to_os_string()));
    let s = OsStr::new;
    push(&[
        s("--unshare-all"),
        s("--die-with-parent"),
        s("--cap-drop"),
        s("ALL"),
        s("--clearenv"),
        s("--setenv"),
        s("PATH"),
        s(sys::SAFE_PATH),
        s("--setenv"),
        s("HOME"),
        s(SANDBOX_HOME),
        s("--ro-bind"),
        s("/usr"),
        s("/usr"),
        s("--symlink"),
        s("usr/bin"),
        s("/bin"),
        s("--symlink"),
        s("usr/bin"),
        s("/sbin"),
        s("--symlink"),
        s("usr/lib"),
        s("/lib"),
        s("--symlink"),
        s("usr/lib"),
        s("/lib64"),
        s("--ro-bind-try"),
        s(ENGINE_DIR),
        s(ENGINE_DIR),
    ]);
    for e in ETC {
        push(&[s("--ro-bind-try"), s(e), s(e)]);
    }
    push(&[
        s("--proc"),
        s("/proc"),
        s("--dev"),
        s("/dev"),
        s("--dev-bind-try"),
        s("/dev/dri"),
        s("/dev/dri"),
    ]);
    for d in &host.devices {
        push(&[s("--dev-bind-try"), d.as_os_str(), d.as_os_str()]);
    }
    push(&[
        s("--ro-bind"),
        s("/sys"),
        s("/sys"),
        s("--tmpfs"),
        s("/tmp"),
        s("--dir"),
        s(SANDBOX_HOME),
    ]);
    let mut dirs = BTreeSet::new();
    if let Some(parent) = bin.parent() {
        if !parent.starts_with("/usr") && !parent.starts_with(ENGINE_DIR) {
            dirs.insert(parent.to_path_buf());
        }
    }
    dirs.extend(plan.assets.iter().cloned());
    dirs.extend(plan.screens.iter().map(|(_, d)| d.clone()));
    for d in &dirs {
        push(&[s("--ro-bind"), d.as_os_str(), d.as_os_str()]);
    }
    if let Some(r) = &host.runtime {
        push(&[
            s("--perms"),
            s("0700"),
            s("--dir"),
            r.as_os_str(),
            s("--setenv"),
            s("XDG_RUNTIME_DIR"),
            r.as_os_str(),
        ]);
    }
    if let Some((name, sock)) = &host.wayland {
        push(&[
            s("--ro-bind"),
            sock.as_os_str(),
            sock.as_os_str(),
            s("--setenv"),
            s("WAYLAND_DISPLAY"),
            name,
        ]);
    }
    if let Some((name, sock)) = &host.x11 {
        push(&[
            s("--ro-bind"),
            sock.as_os_str(),
            sock.as_os_str(),
            s("--setenv"),
            s("DISPLAY"),
            name,
        ]);
        if let Some(x) = &host.xauthority {
            push(&[
                s("--ro-bind"),
                x.as_os_str(),
                s(SANDBOX_XAUTH),
                s("--setenv"),
                s("XAUTHORITY"),
                s(SANDBOX_XAUTH),
            ]);
        }
    }
    if plan.sound && host.runtime.is_some() {
        for sock in &host.sound {
            push(&[s("--ro-bind"), sock.as_os_str(), sock.as_os_str()]);
            if sock.ends_with("pulse/native") {
                let mut server = OsString::from("unix:");
                server.push(sock);
                push(&[s("--setenv"), s("PULSE_SERVER"), &server]);
            }
        }
    }
    if let Some(session) = host.session {
        push(&[s("--setenv"), s("XDG_SESSION_TYPE"), s(session)]);
    }
    if let Some(lang) = &host.lang {
        push(&[s("--setenv"), s("LANG"), lang]);
    }
    push(&[s("--"), bin.as_os_str()]);
    a.extend(plan.args());
    a
}

fn children_of(pid: i32) -> Vec<i32> {
    let Ok(tasks) = std::fs::read_dir(format!("/proc/{pid}/task")) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for t in tasks.flatten().take(MAX_TREE) {
        if let Some(text) = sys::read_limited(&t.path().join("children"), 64 * 1024) {
            out.extend(
                text.split_whitespace()
                    .filter_map(|c| c.parse::<i32>().ok()),
            );
        }
    }
    out
}

pub fn descendants(pid: i32) -> Vec<i32> {
    let mut out = Vec::new();
    let mut queue = vec![pid];
    while let Some(p) = queue.pop() {
        for c in children_of(p) {
            if c > 1 && out.len() < MAX_TREE && !out.contains(&c) {
                out.push(c);
                queue.push(c);
            }
        }
    }
    out
}

pub fn engine_path() -> Option<PathBuf> {
    if let Some(p) = std::env::var_os("KERERU_ENGINE").map(PathBuf::from) {
        return (p.is_absolute() && p.is_file()).then_some(p);
    }
    let p = PathBuf::from(sys::ENGINE);
    p.is_file().then_some(p)
}

fn drain_to_log<R: Read + Send + 'static>(mut from: R, log: Option<std::fs::File>) {
    std::thread::spawn(move || {
        let mut log = log;
        let mut written = 0u64;
        let mut buf = [0u8; 8192];
        loop {
            match from.read(&mut buf) {
                Ok(0) | Err(_) => break,
                Ok(n) => {
                    if let Some(f) = log.as_mut() {
                        if written < LOG_LIMIT {
                            let take = n.min((LOG_LIMIT - written) as usize);
                            if f.write_all(&buf[..take]).is_err() {
                                log = None;
                            }
                            written += take as u64;
                        }
                    }
                }
            }
        }
    });
}

pub fn log_path() -> Option<PathBuf> {
    sys::state_home().map(|d| d.join("kereru").join("engine.log"))
}

pub fn caught_signals(pid: i32) -> Option<u64> {
    let status = sys::read_limited(Path::new(&format!("/proc/{pid}/status")), 64 * 1024)?;
    parse_sigcgt(&status)
}

pub fn parse_sigcgt(status: &str) -> Option<u64> {
    let hex = status
        .lines()
        .find_map(|l| l.strip_prefix("SigCgt:"))?
        .trim();
    u64::from_str_radix(hex, 16).ok()
}

pub fn catches_pause(mask: u64) -> bool {
    let bit = |s: i32| 1u64 << (s - 1);
    mask & bit(libc::SIGUSR1) != 0 && mask & bit(libc::SIGUSR2) != 0
}

impl Engine {
    pub fn start(bin: &Path, plan: &Plan, log: Option<&Path>) -> Result<Engine> {
        if !Path::new(BWRAP).is_file() {
            anyhow::bail!("bubblewrap isn't installed, so the wallpaper can't run safely");
        }
        let mut cmd = Command::new(BWRAP);
        cmd.args(sandbox_args(bin, plan, &Host::detect()))
            .env_clear()
            .env("PATH", sys::SAFE_PATH)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .process_group(0);
        unsafe {
            cmd.pre_exec(|| {
                libc::signal(libc::SIGUSR1, libc::SIG_IGN);
                libc::signal(libc::SIGUSR2, libc::SIG_IGN);
                if libc::prctl(libc::PR_SET_PDEATHSIG, libc::SIGTERM as libc::c_ulong) != 0 {
                    return Err(std::io::Error::last_os_error());
                }
                Ok(())
            });
        }
        let mut child = cmd
            .spawn()
            .with_context(|| format!("couldn't start {BWRAP}"))?;
        let log = log.and_then(|p| sys::open_private_log(p).ok());
        let log2 = log.as_ref().and_then(|f| f.try_clone().ok());
        if let Some(out) = child.stdout.take() {
            drain_to_log(out, log);
        }
        if let Some(err) = child.stderr.take() {
            drain_to_log(err, log2);
        }
        let pid = i32::try_from(child.id()).unwrap_or(0);
        if pid <= 1 {
            let _ = child.kill();
            let _ = child.wait();
            anyhow::bail!("the engine got an unusable process id");
        }
        Ok(Engine {
            child,
            pid,
            target: None,
            started: Instant::now(),
            via: PauseVia::Unknown,
            paused: false,
        })
    }

    pub fn alive(&mut self) -> bool {
        matches!(self.child.try_wait(), Ok(None))
    }

    pub fn uptime(&self) -> Duration {
        self.started.elapsed()
    }

    fn find_target(&self) -> Option<i32> {
        descendants(self.pid)
            .into_iter()
            .find(|p| caught_signals(*p).is_some_and(catches_pause))
    }

    fn probe(&mut self) {
        if self.via != PauseVia::Unknown {
            return;
        }
        if let Some(t) = self.find_target() {
            self.target = Some(t);
            self.via = PauseVia::Signals;
        } else if self.started.elapsed() > HANDLER_GRACE {
            self.via = PauseVia::Stop;
        }
    }

    pub fn set_paused(&mut self, want: bool) {
        self.probe();
        if want == self.paused {
            return;
        }
        let ok = match self.via {
            PauseVia::Unknown => false,
            PauseVia::Signals => {
                let sig = if want { libc::SIGUSR1 } else { libc::SIGUSR2 };
                let tree = descendants(self.pid);
                if !self.target.is_some_and(|t| tree.contains(&t)) {
                    self.target = self.find_target();
                }
                match self.target {
                    Some(t) => unsafe { libc::kill(t, sig) == 0 },
                    None => false,
                }
            }
            PauseVia::Stop => {
                let sig = if want { libc::SIGSTOP } else { libc::SIGCONT };
                unsafe { libc::kill(-self.pid, sig) == 0 }
            }
        };
        if ok {
            self.paused = want;
        }
    }

    pub fn stop(mut self) {
        unsafe {
            libc::kill(-self.pid, libc::SIGCONT);
            libc::kill(-self.pid, libc::SIGTERM);
        }
        let deadline = Instant::now() + Duration::from_secs(4);
        while Instant::now() < deadline {
            if !self.alive() {
                break;
            }
            std::thread::sleep(Duration::from_millis(50));
        }
        unsafe {
            libc::kill(-self.pid, libc::SIGKILL);
        }
        let _ = self.child.wait();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::Config;
    use crate::library::{Item, Kind, Library};

    struct Fixture {
        root: PathBuf,
        lib: Library,
    }

    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.root);
        }
    }

    fn item(root: &Path, name: &str, kind: &str) -> PathBuf {
        let dir = root.join(name);
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(
            dir.join("project.json"),
            format!(r#"{{"title":"{name}","type":"{kind}"}}"#),
        )
        .unwrap();
        dir
    }

    fn fixture(tag: &str) -> Fixture {
        let root = std::env::temp_dir().join(format!("kereru-engine-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        let entry = |key: &str, kind: &str, k: Kind| Item {
            key: key.into(),
            dir: item(&root, key, kind),
            title: key.into(),
            kind: k,
            preview: None,
            mature: false,
            workshop: true,
        };
        let lib = Library {
            items: vec![
                entry("111", "scene", Kind::Scene),
                entry("222", "web", Kind::Web),
            ],
            assets: Some(PathBuf::from("/s/assets")),
            steam: true,
            skipped: 0,
        };
        Fixture { root, lib }
    }

    fn mons(names: &[&str]) -> Vec<Monitor> {
        names
            .iter()
            .map(|n| Monitor {
                name: n.to_string(),
                label: n.to_string(),
            })
            .collect()
    }

    fn strings(p: &Plan) -> Vec<String> {
        p.args()
            .into_iter()
            .map(|a| a.into_string().unwrap())
            .collect()
    }

    #[test]
    fn plan_uses_overrides_and_skips_unknown() {
        let f = fixture("plan");
        let mut cfg = Config::parse("wallpaper = 111\nmonitor.DP-2 = 999\n");
        cfg.sound = false;
        let p = plan(&cfg, &f.lib, &mons(&["DP-1", "DP-2"]));
        let dir = f.root.join("111");
        assert_eq!(p.screens, vec![("DP-1".into(), dir.clone())]);
        assert_eq!(
            strings(&p),
            vec![
                "--fps".to_string(),
                "30".into(),
                "--silent".into(),
                "--assets-dir".into(),
                "/s/assets".into(),
                "--screen-root".into(),
                "DP-1".into(),
                "--bg".into(),
                dir.to_string_lossy().into_owned(),
                "--scaling".into(),
                "fill".into(),
            ]
        );
    }

    #[test]
    fn web_wallpapers_never_reach_the_engine() {
        let f = fixture("web");
        let loose = item(&f.root, "loose-web", "web");
        let loose = loose.to_str().unwrap();
        let screens = mons(&["DP-1", "DP-2"]);
        let cases = [
            "wallpaper = 222\n".to_string(),
            "wallpaper = 111\nmonitor.DP-2 = 222\n".to_string(),
            format!("wallpaper = {loose}\n"),
            format!("wallpaper = 111\nmonitor.DP-1 = {loose}\n"),
        ];
        for case in &cases {
            let p = plan(&Config::parse(case), &f.lib, &screens);
            let args = strings(&p).join("\n");
            assert!(!args.contains("222"), "{case}");
            assert!(!args.contains("loose-web"), "{case}");
            assert!(p.screens.iter().all(|(_, d)| d.ends_with("111")), "{case}");
        }
        item(&f.root, "111", "web");
        let p = plan(&Config::parse("wallpaper = 111\n"), &f.lib, &screens);
        assert!(p.screens.is_empty());
    }

    #[test]
    fn sound_and_fullscreen_flags() {
        let f = fixture("flags");
        let cfg = Config::parse(
            "wallpaper = 111\nsound = on\nvolume = 35\npause_on_fullscreen = off\nfps = 60\n",
        );
        let args = strings(&plan(&cfg, &f.lib, &mons(&["eDP-1"])));
        assert!(args.windows(2).any(|w| w == ["--volume", "35"]));
        assert!(!args.contains(&"--silent".to_string()));
        assert!(args.contains(&"--no-fullscreen-pause".to_string()));
        assert!(args.windows(2).any(|w| w == ["--fps", "60"]));
    }

    #[test]
    fn nothing_to_show_without_a_choice() {
        let f = fixture("none");
        let p = plan(&Config::default(), &f.lib, &mons(&["DP-1"]));
        assert!(p.screens.is_empty());
    }

    fn host() -> Host {
        Host {
            runtime: Some(PathBuf::from("/run/user/1000")),
            wayland: Some((
                "wayland-1".into(),
                PathBuf::from("/run/user/1000/wayland-1"),
            )),
            x11: None,
            xauthority: None,
            sound: vec![
                PathBuf::from("/run/user/1000/pulse/native"),
                PathBuf::from("/run/user/1000/pipewire-0"),
            ],
            lang: Some("en_NZ.UTF-8".into()),
            session: Some("wayland"),
            devices: vec![PathBuf::from("/dev/nvidia0")],
        }
    }

    fn sandbox(p: &Plan, h: &Host) -> Vec<String> {
        sandbox_args(Path::new("/usr/bin/linux-wallpaperengine"), p, h)
            .into_iter()
            .map(|a| a.into_string().unwrap())
            .collect()
    }

    fn has(args: &[String], seq: &[&str]) -> bool {
        args.windows(seq.len()).any(|w| w == seq)
    }

    #[test]
    fn sandbox_is_tight() {
        let f = fixture("bwrap");
        let mut cfg = Config::parse("wallpaper = 111\n");
        cfg.sound = false;
        let p = plan(&cfg, &f.lib, &mons(&["DP-1"]));
        let a = sandbox(&p, &host());
        let dir = f.root.join("111").to_string_lossy().into_owned();
        for flag in ["--unshare-all", "--die-with-parent", "--clearenv"] {
            assert!(a.contains(&flag.to_string()), "{flag}");
        }
        assert!(!a.iter().any(|x| x == "--share-net" || x == "--new-session"));
        assert!(has(&a, &["--cap-drop", "ALL"]));
        assert!(has(&a, &["--setenv", "HOME", "/tmp/home"]));
        assert!(has(&a, &["--ro-bind", &dir, &dir]));
        assert!(has(&a, &["--ro-bind", "/s/assets", "/s/assets"]));
        assert!(has(
            &a,
            &[
                "--ro-bind",
                "/run/user/1000/wayland-1",
                "/run/user/1000/wayland-1"
            ]
        ));
        assert!(has(&a, &["--setenv", "WAYLAND_DISPLAY", "wayland-1"]));
        assert!(has(&a, &["--setenv", "XDG_SESSION_TYPE", "wayland"]));
        assert!(has(&a, &["--dev-bind-try", "/dev/nvidia0", "/dev/nvidia0"]));
        assert!(!a
            .iter()
            .any(|x| x.starts_with("/run/user/1000/p") || x == "PULSE_SERVER"));
        assert!(!a.iter().any(|x| x == "--bind" || x == "--dev-bind"));
        let home = std::env::var("HOME").unwrap_or_else(|_| "/home".into());
        let binds: Vec<&String> = a
            .windows(2)
            .filter(|w| w[0].starts_with("--") && w[0].contains("bind"))
            .map(|w| &w[1])
            .collect();
        assert!(binds
            .iter()
            .all(|b| b.as_str() != home && b.as_str() != "/home"));
        assert!(binds.iter().all(|b| !b.ends_with("/.ssh")));
        let sep = a.iter().position(|x| x == "--").unwrap();
        assert_eq!(a[sep + 1], "/usr/bin/linux-wallpaperengine");
        assert_eq!(a[sep + 2..].to_vec(), strings(&p));
    }

    #[test]
    fn sandbox_sound_and_x11() {
        let f = fixture("bwrap-x");
        let cfg = Config::parse("wallpaper = 111\nsound = on\n");
        let p = plan(&cfg, &f.lib, &mons(&["DP-1"]));
        let mut h = host();
        h.wayland = None;
        h.x11 = Some((":0".into(), PathBuf::from("/tmp/.X11-unix/X0")));
        h.xauthority = Some(PathBuf::from("/home/u/.Xauthority"));
        h.session = Some("x11");
        let a = sandbox(&p, &h);
        assert!(has(
            &a,
            &[
                "--ro-bind",
                "/run/user/1000/pulse/native",
                "/run/user/1000/pulse/native"
            ]
        ));
        assert!(has(
            &a,
            &[
                "--setenv",
                "PULSE_SERVER",
                "unix:/run/user/1000/pulse/native"
            ]
        ));
        assert!(has(
            &a,
            &["--ro-bind", "/tmp/.X11-unix/X0", "/tmp/.X11-unix/X0"]
        ));
        assert!(has(
            &a,
            &["--ro-bind", "/home/u/.Xauthority", "/tmp/.Xauthority"]
        ));
        assert!(!a.iter().any(|x| x == "WAYLAND_DISPLAY"));
        let tmpfs = a.iter().position(|x| x == "--tmpfs").unwrap();
        let x0 = a.iter().position(|x| x == "/tmp/.X11-unix/X0").unwrap();
        assert!(tmpfs < x0);
    }

    #[test]
    fn display_names() {
        assert_eq!(x11_socket(":0"), Some(PathBuf::from("/tmp/.X11-unix/X0")));
        assert_eq!(
            x11_socket(":12.0"),
            Some(PathBuf::from("/tmp/.X11-unix/X12"))
        );
        assert_eq!(x11_socket("remote:0"), None);
        assert_eq!(x11_socket(":../0"), None);
        assert_eq!(x11_socket(":"), None);
        assert_eq!(session_type(Some("x11"), true, true), Some("x11"));
        assert_eq!(session_type(Some("x11"), true, false), Some("wayland"));
        assert_eq!(session_type(None, false, true), Some("x11"));
        assert_eq!(session_type(Some("tty"), false, false), None);
        assert!(plain_name(OsStr::new("wayland-1")));
        assert!(!plain_name(OsStr::new("../wayland-1")));
        assert!(!plain_name(OsStr::new("")));
    }

    #[test]
    fn finds_own_children() {
        let mut child = std::process::Command::new("/bin/sleep")
            .arg("5")
            .spawn()
            .unwrap();
        let me = std::process::id() as i32;
        let kids = descendants(me);
        let _ = child.kill();
        let _ = child.wait();
        assert!(kids.contains(&(child.id() as i32)));
    }

    #[test]
    fn sigcgt() {
        let s = "Name:\tx\nSigCgt:\t0000000180004a02\n";
        let m = parse_sigcgt(s).unwrap();
        assert!(catches_pause(m | (1 << 9) | (1 << 11)));
        assert!(!catches_pause(0x4002));
        assert_eq!(parse_sigcgt("Name: x\n"), None);
    }

    #[test]
    fn own_process_reports_signal_mask() {
        assert!(caught_signals(std::process::id() as i32).is_some());
    }
}
