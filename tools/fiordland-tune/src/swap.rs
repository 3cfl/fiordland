use crate::sys;
use std::fs;
use std::path::Path;

pub const DIR: &str = "/swap";
pub const FILE: &str = "/swap/swapfile";
pub const FSTAB_LINE: &str = "/swap/swapfile none swap defaults,nofail,pri=10 0 0";
pub const MAX_GIB: u32 = 64;

pub fn parse_size(s: &str) -> Option<u32> {
    let n = s
        .strip_suffix("Gi")
        .or_else(|| s.strip_suffix(['G', 'g']))
        .unwrap_or(s);
    if n.is_empty() || !n.bytes().all(|b| b.is_ascii_digit()) {
        return None;
    }
    let v: u32 = n.parse().ok()?;
    (1..=MAX_GIB).contains(&v).then_some(v)
}

pub fn fstab_add(fstab: &str) -> Option<String> {
    if fstab.lines().any(is_ours) {
        return None;
    }
    let mut s = fstab.to_string();
    if !s.is_empty() && !s.ends_with('\n') {
        s.push('\n');
    }
    s.push_str(FSTAB_LINE);
    s.push('\n');
    Some(s)
}

pub fn fstab_remove(fstab: &str) -> Option<String> {
    if !fstab.lines().any(is_ours) {
        return None;
    }
    let mut s: String = fstab
        .lines()
        .filter(|l| !is_ours(l))
        .map(|l| format!("{l}\n"))
        .collect();
    if !fstab.ends_with('\n') && s.ends_with('\n') {
        s.pop();
    }
    Some(s)
}

fn is_ours(line: &str) -> bool {
    line.split_whitespace().next() == Some(FILE)
}

fn fstab_mode() -> u32 {
    use std::os::unix::fs::PermissionsExt;
    fs::metadata("/etc/fstab")
        .map(|m| m.permissions().mode() & 0o7777)
        .unwrap_or(0o644)
}

pub fn on(gib: u32) -> Result<(), String> {
    let mounts = fs::read_to_string("/proc/self/mounts").map_err(|e| e.to_string())?;
    if sys::mount_fstype(&mounts, "/").as_deref() != Some("btrfs") {
        return Err(
            "the root file system is not Btrfs; this command only sets up Btrfs swap files".into(),
        );
    }
    if fs::symlink_metadata(FILE).is_ok() {
        return Err(format!(
            "{FILE} already exists. Remove it first: fiordland-tune swapfile off"
        ));
    }
    match fs::symlink_metadata(DIR) {
        Ok(m) if m.file_type().is_dir() => {}
        Ok(_) => return Err(format!("{DIR} exists and is not a directory")),
        Err(_) => sys::run("/usr/bin/btrfs", &["subvolume", "create", DIR])?,
    }
    let size = format!("{gib}g");
    sys::run(
        "/usr/bin/btrfs",
        &["filesystem", "mkswapfile", "--size", &size, FILE],
    )?;
    sys::run("/usr/bin/swapon", &["--priority", "10", FILE])?;
    let fstab = fs::read_to_string("/etc/fstab").map_err(|e| format!("/etc/fstab: {e}"))?;
    if let Some(new) = fstab_add(&fstab) {
        sys::write_atomic(Path::new("/etc/fstab"), &new, fstab_mode())
            .map_err(|e| format!("/etc/fstab: {e}"))?;
    }
    println!("A {gib} GB swap file is on at {FILE}, used after zram fills up.");
    println!("It sits in its own subvolume, so snapshots skip it. Remove it with: fiordland-tune swapfile off");
    Ok(())
}

pub fn off() -> Result<(), String> {
    if Path::new(FILE).exists() {
        let swaps = fs::read_to_string("/proc/swaps").unwrap_or_default();
        if swaps
            .lines()
            .any(|l| l.split_whitespace().next() == Some(FILE))
        {
            sys::run("/usr/bin/swapoff", &[FILE])?;
        }
    }
    let fstab = fs::read_to_string("/etc/fstab").map_err(|e| format!("/etc/fstab: {e}"))?;
    if let Some(new) = fstab_remove(&fstab) {
        sys::write_atomic(Path::new("/etc/fstab"), &new, fstab_mode())
            .map_err(|e| format!("/etc/fstab: {e}"))?;
    }
    sys::remove_if_exists(Path::new(FILE)).map_err(|e| format!("{FILE}: {e}"))?;
    if Path::new(DIR).is_dir()
        && fs::read_dir(DIR)
            .map(|mut d| d.next().is_none())
            .unwrap_or(false)
    {
        sys::run_quiet("/usr/bin/btrfs", &["subvolume", "delete", DIR]);
    }
    println!("The swap file is gone. zram stays on.");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sizes() {
        assert_eq!(parse_size("8"), Some(8));
        assert_eq!(parse_size("8G"), Some(8));
        assert_eq!(parse_size("16GiB"), None);
        assert_eq!(parse_size("16Gi"), Some(16));
        assert_eq!(parse_size("0"), None);
        assert_eq!(parse_size("65"), None);
        assert_eq!(parse_size("64"), Some(64));
        assert_eq!(parse_size("-1"), None);
        assert_eq!(parse_size("8;reboot"), None);
        assert_eq!(parse_size(""), None);
    }

    #[test]
    fn fstab_edits() {
        let base = "UUID=a / btrfs rw 0 0\n";
        let added = fstab_add(base).unwrap();
        assert_eq!(added, format!("{base}{FSTAB_LINE}\n"));
        assert_eq!(fstab_add(&added), None);
        assert_eq!(fstab_remove(&added).unwrap(), base);
        assert_eq!(fstab_remove(base), None);
        assert_eq!(
            fstab_add("UUID=a / btrfs rw 0 0").unwrap(),
            format!("{base}{FSTAB_LINE}\n")
        );
        let commented = format!("# {FILE} none swap\n");
        assert!(fstab_add(&commented).is_some());
    }
}
