mod hw;
mod profile;
mod scx;
mod swap;
mod sys;

use profile::{Choice, Profile};
use std::fs;
use std::path::Path;
use std::process::ExitCode;

const CONF: &str = "/etc/fiordland/tune.conf";
const SYSCTL: &str = "/etc/sysctl.d/99-fiordland-tune.conf";
const ZRAM: &str = "/etc/systemd/zram-generator.conf.d/99-fiordland-tune.conf";
const SYSCTL_BIN: &str = "/usr/lib/systemd/systemd-sysctl";

const USAGE: &str = "usage: fiordland-tune [COMMAND]

  status              show the hardware and the active profile (default)
  profiles            list the profiles
  apply PROFILE       switch profile: auto, low-end, balanced or performance
  scx SCHEDULER       run a sched_ext CPU scheduler: lavd, bpfland or off
  swapfile SIZE|off   add a Btrfs swap file of SIZE GB (1-64) behind zram, or remove it

auto picks low-end on machines with less than 4 GB of memory, two or fewer
CPU threads, or no GPU acceleration, and balanced everywhere else. It is the
default and is checked again on every boot.";

#[derive(Debug, PartialEq, Eq)]
enum Cmd {
    Status,
    Profiles,
    Apply(Choice),
    Boot,
    Scx(scx::Sched),
    SwapOn(u32),
    SwapOff,
    Help,
}

fn parse(args: &[&str]) -> Result<Cmd, String> {
    match args {
        [] | ["status"] => Ok(Cmd::Status),
        ["profiles"] => Ok(Cmd::Profiles),
        ["-h" | "--help" | "help"] => Ok(Cmd::Help),
        ["boot"] => Ok(Cmd::Boot),
        ["apply", p] => Choice::parse(p)
            .map(Cmd::Apply)
            .ok_or_else(|| format!("unknown profile: {p}")),
        ["scx", s] => scx::Sched::parse(s)
            .map(Cmd::Scx)
            .ok_or_else(|| format!("unknown scheduler: {s}")),
        ["swapfile", "off"] => Ok(Cmd::SwapOff),
        ["swapfile", n] => swap::parse_size(n)
            .map(Cmd::SwapOn)
            .ok_or_else(|| format!("swap file size must be 1 to {} (GB)", swap::MAX_GIB)),
        _ => Err("unknown command".into()),
    }
}

fn read_choice() -> Choice {
    fs::read_to_string(CONF)
        .map(|s| Choice::from_conf(&s))
        .unwrap_or(Choice::Auto)
}

fn gb(kib: u64) -> String {
    format!("{:.1} GB", kib as f64 / 1_048_576.0)
}

fn status() {
    let hw = hw::detect(Path::new("/"));
    let choice = read_choice();
    let p = choice.resolve(&hw);
    println!(
        "Hardware   {} memory, {} CPU threads, {}",
        gb(hw.mem_kib),
        hw.cpus,
        if hw.gpu_accel {
            "GPU acceleration"
        } else {
            "software rendering"
        }
    );
    let reasons = hw.low_end_reasons();
    if reasons.is_empty() {
        println!("Class      not low-end");
    } else {
        println!("Class      low-end: {}", reasons.join(", "));
    }
    match choice {
        Choice::Auto => println!("Profile    auto, now {}", p.name()),
        Choice::Fixed(_) => println!("Profile    {}", p.name()),
    }
    let sched = scx::kernel_state().unwrap_or_else(|| "not supported by this kernel".into());
    println!("sched_ext  {sched}");
}

fn profiles() {
    println!("auto         low-end or balanced, picked from the hardware");
    for p in [Profile::LowEnd, Profile::Balanced, Profile::Performance] {
        println!("{:<12} {}", p.name(), p.about());
    }
}

fn write_profile(p: Profile) -> Result<bool, String> {
    let a = sys::write_atomic(Path::new(SYSCTL), &p.sysctl(), 0o644)
        .map_err(|e| format!("{SYSCTL}: {e}"))?;
    let b =
        sys::write_atomic(Path::new(ZRAM), &p.zram(), 0o644).map_err(|e| format!("{ZRAM}: {e}"))?;
    if Path::new(SYSCTL_BIN).exists() {
        sys::run_quiet(SYSCTL_BIN, &[SYSCTL]);
    }
    Ok(a || b)
}

fn apply(choice: Choice) -> Result<(), String> {
    let hw = hw::detect(Path::new("/"));
    let p = choice.resolve(&hw);
    sys::write_atomic(Path::new(CONF), &choice.to_conf(), 0o644)
        .map_err(|e| format!("{CONF}: {e}"))?;
    write_profile(p)?;
    if Path::new("/usr/bin/powerprofilesctl").exists() {
        sys::run_quiet("/usr/bin/powerprofilesctl", &["set", p.power_profile()]);
    }
    match choice {
        Choice::Auto => println!("Profile auto, now {}: {}", p.name(), p.about()),
        Choice::Fixed(_) => println!("Profile {}: {}", p.name(), p.about()),
    }
    println!("Memory settings are active now; the zram size changes on the next boot.");
    Ok(())
}

fn boot() -> Result<(), String> {
    let hw = hw::detect(Path::new("/"));
    let p = read_choice().resolve(&hw);
    if write_profile(p)? {
        println!("fiordland-tune: {} profile written", p.name());
    }
    Ok(())
}

fn need_root(cmd: &Cmd) -> bool {
    !matches!(cmd, Cmd::Status | Cmd::Profiles | Cmd::Help)
}

fn main() -> ExitCode {
    let owned: Vec<String> = std::env::args().skip(1).collect();
    let args: Vec<&str> = owned.iter().map(String::as_str).collect();
    let cmd = match parse(&args) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("fiordland-tune: {e}\n\n{USAGE}");
            return ExitCode::from(2);
        }
    };
    if need_root(&cmd) && !sys::is_root() {
        eprintln!("fiordland-tune: this needs root, run it with sudo");
        return ExitCode::from(1);
    }
    let r = match cmd {
        Cmd::Status => {
            status();
            Ok(())
        }
        Cmd::Profiles => {
            profiles();
            Ok(())
        }
        Cmd::Help => {
            println!("{USAGE}");
            Ok(())
        }
        Cmd::Apply(c) => apply(c),
        Cmd::Boot => boot(),
        Cmd::Scx(s) => scx::set(s),
        Cmd::SwapOn(n) => swap::on(n),
        Cmd::SwapOff => swap::off(),
    };
    match r {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("fiordland-tune: {e}");
            ExitCode::from(1)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_allowed_commands() {
        assert_eq!(parse(&[]), Ok(Cmd::Status));
        assert_eq!(parse(&["profiles"]), Ok(Cmd::Profiles));
        assert_eq!(
            parse(&["apply", "low-end"]),
            Ok(Cmd::Apply(Choice::Fixed(Profile::LowEnd)))
        );
        assert_eq!(parse(&["apply", "auto"]), Ok(Cmd::Apply(Choice::Auto)));
        assert_eq!(parse(&["scx", "lavd"]), Ok(Cmd::Scx(scx::Sched::Lavd)));
        assert_eq!(parse(&["swapfile", "8"]), Ok(Cmd::SwapOn(8)));
        assert_eq!(parse(&["swapfile", "off"]), Ok(Cmd::SwapOff));
        assert_eq!(parse(&["boot"]), Ok(Cmd::Boot));
    }

    #[test]
    fn rejects_everything_else() {
        assert!(parse(&["apply"]).is_err());
        assert!(parse(&["apply", "fast"]).is_err());
        assert!(parse(&["apply", "auto", "extra"]).is_err());
        assert!(parse(&["scx", "rusty"]).is_err());
        assert!(parse(&["swapfile", "100"]).is_err());
        assert!(parse(&["swapfile", "$(id)"]).is_err());
        assert!(parse(&["--root=/tmp"]).is_err());
    }

    #[test]
    fn root_only_for_changes() {
        assert!(!need_root(&Cmd::Status));
        assert!(!need_root(&Cmd::Profiles));
        assert!(need_root(&Cmd::Boot));
        assert!(need_root(&Cmd::Apply(Choice::Auto)));
        assert!(need_root(&Cmd::SwapOff));
    }
}
