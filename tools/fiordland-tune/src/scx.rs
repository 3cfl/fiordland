use crate::sys;
use std::fs;
use std::path::Path;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Sched {
    Lavd,
    Bpfland,
    Off,
}

pub enum Backend {
    Loader,
    Legacy,
}

const UNITS: &str = "/usr/lib/systemd/system";
const LOADER_CONF: &str = "/etc/scx_loader.toml";
const LEGACY_CONF: &str = "/etc/default/scx";

impl Sched {
    pub fn parse(s: &str) -> Option<Sched> {
        match s {
            "lavd" | "scx_lavd" => Some(Sched::Lavd),
            "bpfland" | "scx_bpfland" => Some(Sched::Bpfland),
            "off" | "none" => Some(Sched::Off),
            _ => None,
        }
    }

    pub fn binary(self) -> Option<&'static str> {
        match self {
            Sched::Lavd => Some("scx_lavd"),
            Sched::Bpfland => Some("scx_bpfland"),
            Sched::Off => None,
        }
    }
}

pub fn loader_conf(bin: &str) -> String {
    format!("default_sched = \"{bin}\"\ndefault_mode = \"Auto\"\n")
}

pub fn legacy_conf(bin: &str) -> String {
    format!("SCX_SCHEDULER={bin}\nSCX_FLAGS=\n")
}

pub fn backend(units: &Path) -> Option<Backend> {
    if units.join("scx_loader.service").exists() {
        Some(Backend::Loader)
    } else if units.join("scx.service").exists() {
        Some(Backend::Legacy)
    } else {
        None
    }
}

pub fn kernel_state() -> Option<String> {
    let state = fs::read_to_string("/sys/kernel/sched_ext/state").ok()?;
    let ops = fs::read_to_string("/sys/kernel/sched_ext/root/ops").unwrap_or_default();
    let state = state.trim();
    if ops.trim().is_empty() {
        Some(state.to_string())
    } else {
        Some(format!("{state} ({})", ops.trim()))
    }
}

pub fn set(s: Sched) -> Result<(), String> {
    let backend = backend(Path::new(UNITS));
    let Some(bin) = s.binary() else {
        for unit in ["scx_loader.service", "scx.service"] {
            if Path::new(UNITS).join(unit).exists() {
                sys::run("/usr/bin/systemctl", &["disable", "--now", unit])?;
            }
        }
        println!("sched_ext scheduler turned off, the kernel's default scheduler is back.");
        return Ok(());
    };
    if !Path::new("/sys/kernel/sched_ext").exists() {
        return Err("this kernel has no sched_ext support. The CachyOS, linux-fiord and current Arch kernels have it.".into());
    }
    let Some(backend) = backend else {
        return Err(
            "scx-scheds is not installed. Install it first: sudo pacman -S scx-scheds".into(),
        );
    };
    if !Path::new("/usr/bin").join(bin).exists() {
        return Err(format!("{bin} is missing from this scx-scheds"));
    }
    let (conf, text, unit) = match backend {
        Backend::Loader => (LOADER_CONF, loader_conf(bin), "scx_loader.service"),
        Backend::Legacy => (LEGACY_CONF, legacy_conf(bin), "scx.service"),
    };
    sys::write_atomic(Path::new(conf), &text, 0o644).map_err(|e| format!("{conf}: {e}"))?;
    sys::run("/usr/bin/systemctl", &["enable", unit])?;
    sys::run("/usr/bin/systemctl", &["restart", unit])?;
    println!("{bin} is running and starts on every boot. Undo with: fiordland-tune scx off");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_scheds() {
        assert_eq!(Sched::parse("lavd"), Some(Sched::Lavd));
        assert_eq!(Sched::parse("scx_bpfland"), Some(Sched::Bpfland));
        assert_eq!(Sched::parse("off"), Some(Sched::Off));
        assert_eq!(Sched::parse("rusty;rm"), None);
        assert_eq!(Sched::Off.binary(), None);
    }

    #[test]
    fn configs() {
        assert_eq!(
            loader_conf("scx_lavd"),
            "default_sched = \"scx_lavd\"\ndefault_mode = \"Auto\"\n"
        );
        assert!(legacy_conf("scx_bpfland").starts_with("SCX_SCHEDULER=scx_bpfland\n"));
    }

    #[test]
    fn picks_backend() {
        let d = sys::test_dir("scx");
        assert!(backend(&d).is_none());
        fs::write(d.join("scx.service"), "").unwrap();
        assert!(matches!(backend(&d), Some(Backend::Legacy)));
        fs::write(d.join("scx_loader.service"), "").unwrap();
        assert!(matches!(backend(&d), Some(Backend::Loader)));
        fs::remove_dir_all(&d).unwrap();
    }
}
