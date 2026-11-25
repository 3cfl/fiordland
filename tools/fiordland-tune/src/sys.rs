use std::fs::{self, DirBuilder, OpenOptions};
use std::io::{self, Write};
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt};
use std::path::Path;
use std::process::{Command, Stdio};

pub fn is_root() -> bool {
    fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|s| {
            s.lines()
                .find_map(|l| l.strip_prefix("Uid:"))
                .and_then(|v| v.split_whitespace().nth(1).map(|e| e == "0"))
        })
        .unwrap_or(false)
}

pub fn write_atomic(path: &Path, content: &str, mode: u32) -> io::Result<bool> {
    if let Ok(old) = fs::read_to_string(path) {
        if old == content {
            return Ok(false);
        }
    }
    let dir = path
        .parent()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "no parent directory"))?;
    DirBuilder::new().recursive(true).mode(0o755).create(dir)?;
    let name = path
        .file_name()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "no file name"))?
        .to_string_lossy()
        .into_owned();
    let tmp = dir.join(format!(".{name}.{}.tmp", std::process::id()));
    let result = (|| {
        let mut f = OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(mode)
            .open(&tmp)?;
        f.set_permissions(fs::Permissions::from_mode(mode))?;
        f.write_all(content.as_bytes())?;
        f.sync_all()?;
        fs::rename(&tmp, path)
    })();
    if result.is_err() {
        let _ = fs::remove_file(&tmp);
    }
    result.map(|_| true)
}

pub fn remove_if_exists(path: &Path) -> io::Result<bool> {
    match fs::remove_file(path) {
        Ok(()) => Ok(true),
        Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(false),
        Err(e) => Err(e),
    }
}

pub fn run(prog: &str, args: &[&str]) -> Result<(), String> {
    let status = Command::new(prog)
        .args(args)
        .stdin(Stdio::null())
        .status()
        .map_err(|e| format!("could not run {prog}: {e}"))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("{prog} {} failed ({status})", args.join(" ")))
    }
}

pub fn run_quiet(prog: &str, args: &[&str]) -> bool {
    Command::new(prog)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

pub fn mount_fstype(mounts: &str, target: &str) -> Option<String> {
    mounts
        .lines()
        .filter_map(|l| {
            let mut f = l.split_whitespace();
            let _src = f.next()?;
            let mnt = f.next()?;
            let ty = f.next()?;
            (mnt == target).then(|| ty.to_string())
        })
        .next_back()
}

#[cfg(test)]
pub fn test_dir(tag: &str) -> std::path::PathBuf {
    use std::sync::atomic::{AtomicUsize, Ordering};
    static N: AtomicUsize = AtomicUsize::new(0);
    let d = std::env::temp_dir().join(format!(
        "fiordland-tune-{tag}-{}-{}",
        std::process::id(),
        N.fetch_add(1, Ordering::SeqCst)
    ));
    let _ = fs::remove_dir_all(&d);
    DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(&d)
        .unwrap();
    d
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn atomic_write_creates_and_skips_same() {
        let d = test_dir("write");
        let p = d.join("a/b/file.conf");
        assert!(write_atomic(&p, "x=1\n", 0o644).unwrap());
        assert_eq!(fs::read_to_string(&p).unwrap(), "x=1\n");
        assert_eq!(
            fs::metadata(&p).unwrap().permissions().mode() & 0o777,
            0o644
        );
        assert!(!write_atomic(&p, "x=1\n", 0o644).unwrap());
        assert!(write_atomic(&p, "x=2\n", 0o644).unwrap());
        assert_eq!(fs::read_to_string(&p).unwrap(), "x=2\n");
        assert_eq!(fs::read_dir(p.parent().unwrap()).unwrap().count(), 1);
        assert!(remove_if_exists(&p).unwrap());
        assert!(!remove_if_exists(&p).unwrap());
        fs::remove_dir_all(&d).unwrap();
    }

    #[test]
    fn atomic_write_replaces_symlink_not_target() {
        let d = test_dir("link");
        let target = d.join("target");
        fs::write(&target, "keep").unwrap();
        let link = d.join("link.conf");
        std::os::unix::fs::symlink(&target, &link).unwrap();
        write_atomic(&link, "new", 0o644).unwrap();
        assert_eq!(fs::read_to_string(&target).unwrap(), "keep");
        assert!(!fs::symlink_metadata(&link)
            .unwrap()
            .file_type()
            .is_symlink());
        fs::remove_dir_all(&d).unwrap();
    }

    #[test]
    fn fstype_of_root() {
        let m = "proc /proc proc rw 0 0\n/dev/vda2 / btrfs rw,noatime 0 0\n/dev/vda2 /home btrfs rw 0 0\n";
        assert_eq!(mount_fstype(m, "/").as_deref(), Some("btrfs"));
        assert_eq!(mount_fstype(m, "/boot"), None);
        let over = "/dev/vda2 / btrfs rw 0 0\noverlay / overlay rw 0 0\n";
        assert_eq!(mount_fstype(over, "/").as_deref(), Some("overlay"));
    }
}
