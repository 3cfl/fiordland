use crate::config::Config;
use crate::library::Library;
use crate::outputs::Monitor;
use crate::sys;
use anyhow::{Context, Result};
use std::ffi::OsString;
use std::io::{Read, Write};
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

const LOG_LIMIT: u64 = 4 << 20;
const HANDLER_GRACE: Duration = Duration::from_secs(45);

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
    started: Instant,
    via: PauseVia,
    paused: bool,
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
        let mut cmd = Command::new(bin);
        cmd.args(plan.args())
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
            .with_context(|| format!("couldn't start {}", bin.display()))?;
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

    fn probe(&mut self) {
        if self.via != PauseVia::Unknown {
            return;
        }
        if caught_signals(self.pid).is_some_and(catches_pause) {
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
                unsafe { libc::kill(self.pid, sig) == 0 }
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
            libc::kill(self.pid, libc::SIGTERM);
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

    fn lib() -> Library {
        Library {
            items: vec![Item {
                key: "111".into(),
                dir: PathBuf::from("/s/431960/111"),
                title: "a".into(),
                kind: Kind::Scene,
                preview: None,
                mature: false,
                workshop: true,
            }],
            assets: Some(PathBuf::from("/s/assets")),
            steam: true,
            skipped: 0,
        }
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

    #[test]
    fn plan_uses_overrides_and_skips_unknown() {
        let mut cfg = Config::parse("wallpaper = 111\nmonitor.DP-2 = 999\n");
        cfg.sound = false;
        let p = plan(&cfg, &lib(), &mons(&["DP-1", "DP-2"]));
        assert_eq!(
            p.screens,
            vec![("DP-1".into(), PathBuf::from("/s/431960/111"))]
        );
        let args: Vec<String> = p
            .args()
            .into_iter()
            .map(|a| a.into_string().unwrap())
            .collect();
        assert_eq!(
            args,
            vec![
                "--fps",
                "30",
                "--silent",
                "--assets-dir",
                "/s/assets",
                "--screen-root",
                "DP-1",
                "--bg",
                "/s/431960/111",
                "--scaling",
                "fill"
            ]
        );
    }

    #[test]
    fn sound_and_fullscreen_flags() {
        let cfg = Config::parse(
            "wallpaper = 111\nsound = on\nvolume = 35\npause_on_fullscreen = off\nfps = 60\n",
        );
        let args: Vec<String> = plan(&cfg, &lib(), &mons(&["eDP-1"]))
            .args()
            .into_iter()
            .map(|a| a.into_string().unwrap())
            .collect();
        assert!(args.windows(2).any(|w| w == ["--volume", "35"]));
        assert!(!args.contains(&"--silent".to_string()));
        assert!(args.contains(&"--no-fullscreen-pause".to_string()));
        assert!(args.windows(2).any(|w| w == ["--fps", "60"]));
    }

    #[test]
    fn nothing_to_show_without_a_choice() {
        let p = plan(&Config::default(), &lib(), &mons(&["DP-1"]));
        assert!(p.screens.is_empty());
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
