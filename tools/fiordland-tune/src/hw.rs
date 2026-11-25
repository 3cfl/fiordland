use std::fs;
use std::path::Path;

pub const LOW_MEM_KIB: u64 = 3_670_016;
pub const LOW_CPUS: usize = 2;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Hardware {
    pub mem_kib: u64,
    pub cpus: usize,
    pub gpu_accel: bool,
}

impl Hardware {
    pub fn low_end_reasons(&self) -> Vec<&'static str> {
        let mut r = Vec::new();
        if self.mem_kib < LOW_MEM_KIB {
            r.push("less than 4 GB of memory");
        }
        if self.cpus <= LOW_CPUS {
            r.push("two or fewer CPU threads");
        }
        if !self.gpu_accel {
            r.push("no GPU acceleration (software rendering)");
        }
        r
    }

    pub fn is_low_end(&self) -> bool {
        !self.low_end_reasons().is_empty()
    }
}

pub fn detect(root: &Path) -> Hardware {
    let mem_kib = fs::read_to_string(root.join("proc/meminfo"))
        .ok()
        .and_then(|s| parse_mem_kib(&s))
        .unwrap_or(0);
    let cpus = fs::read_to_string(root.join("sys/devices/system/cpu/online"))
        .ok()
        .and_then(|s| parse_cpu_list(&s))
        .unwrap_or(1);
    Hardware {
        mem_kib,
        cpus,
        gpu_accel: has_render_node(&root.join("dev/dri")),
    }
}

pub fn parse_mem_kib(meminfo: &str) -> Option<u64> {
    meminfo.lines().find_map(|l| {
        let rest = l.strip_prefix("MemTotal:")?;
        rest.split_whitespace().next()?.parse().ok()
    })
}

pub fn parse_cpu_list(list: &str) -> Option<usize> {
    let mut n = 0usize;
    for part in list.trim().split(',').filter(|p| !p.is_empty()) {
        match part.split_once('-') {
            Some((a, b)) => {
                let a: usize = a.parse().ok()?;
                let b: usize = b.parse().ok()?;
                if b < a {
                    return None;
                }
                n += b - a + 1;
            }
            None => {
                part.parse::<usize>().ok()?;
                n += 1;
            }
        }
    }
    if n == 0 {
        None
    } else {
        Some(n)
    }
}

fn has_render_node(dri: &Path) -> bool {
    fs::read_dir(dri)
        .map(|it| {
            it.flatten()
                .any(|e| e.file_name().to_string_lossy().starts_with("renderD"))
        })
        .unwrap_or(false)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mem_total() {
        let s = "MemTotal:        8034636 kB\nMemFree:  100 kB\n";
        assert_eq!(parse_mem_kib(s), Some(8_034_636));
        assert_eq!(parse_mem_kib("MemFree: 1 kB\n"), None);
    }

    #[test]
    fn cpu_lists() {
        assert_eq!(parse_cpu_list("0-3\n"), Some(4));
        assert_eq!(parse_cpu_list("0"), Some(1));
        assert_eq!(parse_cpu_list("0-1,4,6-7"), Some(5));
        assert_eq!(parse_cpu_list(""), None);
        assert_eq!(parse_cpu_list("3-1"), None);
        assert_eq!(parse_cpu_list("x"), None);
    }

    #[test]
    fn low_end_rules() {
        let big = Hardware {
            mem_kib: 16_000_000,
            cpus: 8,
            gpu_accel: true,
        };
        assert!(!big.is_low_end());
        assert!(Hardware {
            mem_kib: 2_000_000,
            ..big
        }
        .is_low_end());
        assert!(!Hardware {
            mem_kib: 3_900_000,
            ..big
        }
        .is_low_end());
        assert!(Hardware { cpus: 2, ..big }.is_low_end());
        assert!(!Hardware { cpus: 3, ..big }.is_low_end());
        assert!(Hardware {
            gpu_accel: false,
            ..big
        }
        .is_low_end());
    }

    #[test]
    fn detect_fake_root() {
        let root = crate::sys::test_dir("detect");
        fs::create_dir_all(root.join("proc")).unwrap();
        fs::create_dir_all(root.join("sys/devices/system/cpu")).unwrap();
        fs::create_dir_all(root.join("dev/dri")).unwrap();
        fs::write(root.join("proc/meminfo"), "MemTotal: 2000000 kB\n").unwrap();
        fs::write(root.join("sys/devices/system/cpu/online"), "0-7\n").unwrap();
        fs::write(root.join("dev/dri/card0"), "").unwrap();
        let hw = detect(&root);
        assert_eq!(hw.mem_kib, 2_000_000);
        assert_eq!(hw.cpus, 8);
        assert!(!hw.gpu_accel);
        fs::write(root.join("dev/dri/renderD128"), "").unwrap();
        assert!(detect(&root).gpu_accel);
        fs::remove_dir_all(&root).unwrap();
    }
}
