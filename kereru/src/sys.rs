use anyhow::{bail, Context, Result};
use std::ffi::OsStr;
use std::io::{Read, Write};
use std::os::unix::fs::{DirBuilderExt, MetadataExt, OpenOptionsExt};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

pub const SAFE_PATH: &str = "/usr/local/bin:/usr/bin";
pub const XDG_OPEN: &str = "/usr/bin/xdg-open";
pub const ENGINE: &str = "/usr/bin/linux-wallpaperengine";
pub const KERERU: &str = "/usr/bin/kereru";
const MIN_KB: u64 = 4 * 1024 * 1024;

pub fn flag(name: &str) -> Option<bool> {
    match std::env::var(name).ok()?.as_str() {
        "1" => Some(true),
        "0" => Some(false),
        _ => None,
    }
}

pub fn euid() -> u32 {
    unsafe { libc::geteuid() }
}

fn xdg_dir(var: &str, fallback: &str) -> Option<PathBuf> {
    std::env::var_os(var)
        .map(PathBuf::from)
        .filter(|p| p.is_absolute())
        .or_else(|| home().map(|h| h.join(fallback)))
}

pub fn home() -> Option<PathBuf> {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .filter(|p| p.is_absolute())
}

pub fn config_home() -> Option<PathBuf> {
    xdg_dir("XDG_CONFIG_HOME", ".config")
}

pub fn cache_home() -> Option<PathBuf> {
    xdg_dir("XDG_CACHE_HOME", ".cache")
}

pub fn state_home() -> Option<PathBuf> {
    xdg_dir("XDG_STATE_HOME", ".local/state")
}

pub fn data_home() -> Option<PathBuf> {
    xdg_dir("XDG_DATA_HOME", ".local/share")
}

pub fn runtime_dir() -> Option<PathBuf> {
    let dir = PathBuf::from(std::env::var_os("XDG_RUNTIME_DIR")?);
    let meta = std::fs::symlink_metadata(&dir).ok()?;
    let private = meta.is_dir() && meta.uid() == euid() && meta.mode() & 0o077 == 0;
    (dir.is_absolute() && private).then_some(dir)
}

pub fn read_limited(path: &Path, limit: u64) -> Option<String> {
    let f = std::fs::File::open(path).ok()?;
    if !f.metadata().ok()?.is_file() {
        return None;
    }
    let mut buf = Vec::new();
    f.take(limit).read_to_end(&mut buf).ok()?;
    Some(String::from_utf8_lossy(&buf).into_owned())
}

pub fn private_dir(dir: &Path) -> Result<()> {
    if std::fs::symlink_metadata(dir).is_err() {
        std::fs::DirBuilder::new()
            .recursive(true)
            .mode(0o700)
            .create(dir)
            .with_context(|| format!("couldn't create {}", dir.display()))?;
    }
    let meta = std::fs::symlink_metadata(dir)?;
    if meta.file_type().is_symlink() || !meta.is_dir() || meta.uid() != euid() {
        bail!("{} is not a folder owned by you", dir.display());
    }
    Ok(())
}

pub fn write_private(path: &Path, data: &[u8]) -> Result<()> {
    let dir = path.parent().context("bad path")?;
    private_dir(dir)?;
    let name = path.file_name().context("bad path")?.to_string_lossy();
    let tmp = dir.join(format!(".{name}.{}.tmp", std::process::id()));
    let _ = std::fs::remove_file(&tmp);
    let mut f = std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW)
        .open(&tmp)
        .with_context(|| format!("couldn't write {}", tmp.display()))?;
    let written = f.write_all(data).and_then(|_| f.sync_all());
    drop(f);
    if let Err(e) = written.and_then(|_| std::fs::rename(&tmp, path)) {
        let _ = std::fs::remove_file(&tmp);
        return Err(e.into());
    }
    Ok(())
}

pub fn open_private_log(path: &Path) -> Result<std::fs::File> {
    let dir = path.parent().context("bad path")?;
    private_dir(dir)?;
    let _ = std::fs::remove_file(path);
    std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW)
        .open(path)
        .with_context(|| format!("couldn't open {}", path.display()))
}

pub fn spawn_detached<I, S>(bin: &str, args: I) -> bool
where
    I: IntoIterator<Item = S>,
    S: AsRef<OsStr>,
{
    let child = Command::new(bin)
        .env("PATH", SAFE_PATH)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();
    match child {
        Ok(mut c) => {
            std::thread::spawn(move || {
                let _ = c.wait();
            });
            true
        }
        Err(_) => false,
    }
}

extern "C" {
    fn signal(sig: i32, handler: usize) -> usize;
}

pub fn reset_sigpipe() {
    unsafe {
        signal(13, 0);
    }
}

pub fn self_exe() -> String {
    if Path::new(KERERU).is_file() {
        return KERERU.to_string();
    }
    std::env::current_exe()
        .ok()
        .filter(|p| p.is_file())
        .map(|p| p.to_string_lossy().into_owned())
        .unwrap_or_default()
}

pub fn open_url(url: &str) {
    spawn_detached(XDG_OPEN, [url]);
}

pub fn on_battery() -> bool {
    on_battery_in(Path::new("/sys/class/power_supply"))
}

pub fn on_battery_in(root: &Path) -> bool {
    let Ok(entries) = std::fs::read_dir(root) else {
        return false;
    };
    let mut battery = false;
    for e in entries.flatten() {
        let p = e.path();
        let read = |f: &str| {
            std::fs::read_to_string(p.join(f))
                .map(|s| s.trim().to_string())
                .unwrap_or_default()
        };
        match read("type").as_str() {
            "Mains" | "USB" if read("online") == "1" => return false,
            "Battery" if read("scope") != "Device" && read("status") == "Discharging" => {
                battery = true;
            }
            _ => {}
        }
    }
    battery
}

pub fn mem_total_kb(meminfo: &str) -> Option<u64> {
    meminfo
        .lines()
        .find_map(|l| l.strip_prefix("MemTotal:"))
        .and_then(|v| v.split_whitespace().next())
        .and_then(|v| v.parse().ok())
}

pub fn software_gl(get: impl Fn(&str) -> Option<String>) -> bool {
    if get("LIBGL_ALWAYS_SOFTWARE").is_some_and(|v| !v.is_empty() && v != "0") {
        return true;
    }
    if get("GALLIUM_DRIVER").is_some_and(|v| v == "llvmpipe" || v == "softpipe") {
        return true;
    }
    get("SLINT_BACKEND").is_some_and(|v| v.contains("software"))
}

fn render_node() -> bool {
    std::fs::read_dir("/dev/dri")
        .map(|d| {
            d.flatten()
                .any(|e| e.file_name().to_string_lossy().starts_with("renderD"))
        })
        .unwrap_or(false)
}

pub fn low_end() -> bool {
    if let Some(forced) = flag("KERERU_LOW_END") {
        return forced;
    }
    if software_gl(|k| std::env::var(k).ok()) {
        return true;
    }
    let mem = std::fs::read_to_string("/proc/meminfo")
        .ok()
        .and_then(|m| mem_total_kb(&m));
    if mem.is_some_and(|kb| kb < MIN_KB) {
        return true;
    }
    !render_node()
}

fn font_dirs() -> Vec<PathBuf> {
    let mut dirs = vec![
        PathBuf::from("/usr/share/fonts"),
        PathBuf::from("/usr/local/share/fonts"),
    ];
    if let Some(data) = data_home() {
        dirs.push(data.join("fonts"));
    }
    if let Some(h) = home() {
        dirs.push(h.join(".fonts"));
    }
    dirs
}

pub fn symbols_font() -> bool {
    if let Some(forced) = flag("KERERU_SYMBOLS") {
        return forced;
    }
    let is_symbols = |p: &Path| {
        p.file_name()
            .map(|n| n.to_string_lossy().starts_with("MaterialSymbolsRounded"))
            .unwrap_or(false)
    };
    for dir in font_dirs() {
        let Ok(entries) = std::fs::read_dir(&dir) else {
            continue;
        };
        for e in entries.flatten() {
            let p = e.path();
            if is_symbols(&p) {
                return true;
            }
            if e.file_type().is_ok_and(|t| t.is_dir()) {
                if let Ok(sub) = std::fs::read_dir(&p) {
                    if sub.flatten().any(|s| is_symbols(&s.path())) {
                        return true;
                    }
                }
            }
        }
    }
    false
}

pub fn theme_mode() -> i32 {
    match std::env::var("KERERU_THEME").as_deref() {
        Ok("dark") => 1,
        Ok("light") => 2,
        _ => 0,
    }
}

pub fn clean_text(s: &str, max: usize) -> String {
    let mut out: String = s
        .chars()
        .map(|c| if c.is_control() { ' ' } else { c })
        .collect::<String>()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ");
    if out.chars().count() > max {
        out = out.chars().take(max.saturating_sub(1)).collect();
        out.push('…');
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn supply(root: &Path, name: &str, files: &[(&str, &str)]) {
        let d = root.join(name);
        std::fs::create_dir_all(&d).unwrap();
        for (k, v) in files {
            std::fs::write(d.join(k), v).unwrap();
        }
    }

    fn scratch(tag: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("kereru-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn battery_only_when_discharging_without_mains() {
        let d = scratch("bat1");
        supply(
            &d,
            "BAT0",
            &[("type", "Battery"), ("status", "Discharging")],
        );
        assert!(on_battery_in(&d));
        supply(&d, "AC", &[("type", "Mains"), ("online", "1")]);
        assert!(!on_battery_in(&d));
        let _ = std::fs::remove_dir_all(&d);
    }

    #[test]
    fn peripheral_batteries_and_desktops_are_not_on_battery() {
        let d = scratch("bat2");
        assert!(!on_battery_in(&d));
        supply(
            &d,
            "hidpp_battery_0",
            &[
                ("type", "Battery"),
                ("scope", "Device"),
                ("status", "Discharging"),
            ],
        );
        assert!(!on_battery_in(&d));
        supply(&d, "BAT1", &[("type", "Battery"), ("status", "Full")]);
        assert!(!on_battery_in(&d));
        let _ = std::fs::remove_dir_all(&d);
    }

    #[test]
    fn clean_text_strips_controls_and_truncates() {
        assert_eq!(clean_text("a\u{1b}[31mb\nc", 50), "a [31mb c");
        assert_eq!(clean_text("abcdef", 4), "abc…");
        assert_eq!(clean_text("  x   y ", 10), "x y");
    }

    #[test]
    fn software_gl_detection() {
        assert!(software_gl(
            |k| (k == "GALLIUM_DRIVER").then(|| "llvmpipe".into())
        ));
        assert!(!software_gl(|_| None));
    }
}
