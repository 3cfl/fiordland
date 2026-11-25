use crate::hw::Hardware;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Profile {
    LowEnd,
    Balanced,
    Performance,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Choice {
    Auto,
    Fixed(Profile),
}

impl Profile {
    pub fn name(self) -> &'static str {
        match self {
            Profile::LowEnd => "low-end",
            Profile::Balanced => "balanced",
            Profile::Performance => "performance",
        }
    }

    pub fn about(self) -> &'static str {
        match self {
            Profile::LowEnd => {
                "zram as large as memory, small write-back buffers, no proactive compaction"
            }
            Profile::Balanced => "Fiordland defaults: zram up to half of memory (8 GB max)",
            Profile::Performance => {
                "performance power profile, no split-lock slowdown, zram up to 16 GB"
            }
        }
    }

    pub fn power_profile(self) -> &'static str {
        match self {
            Profile::Performance => "performance",
            _ => "balanced",
        }
    }

    pub fn sysctl(self) -> String {
        let (dirty, background) = match self {
            Profile::LowEnd => (67_108_864u64, 16_777_216u64),
            _ => (268_435_456, 67_108_864),
        };
        let mut s = format!("vm.dirty_bytes = {dirty}\nvm.dirty_background_bytes = {background}\n");
        match self {
            Profile::LowEnd => s.push_str("vm.compaction_proactiveness = 0\n"),
            Profile::Balanced => {}
            Profile::Performance => s.push_str("-kernel.split_lock_mitigate = 0\n"),
        }
        s
    }

    pub fn zram(self) -> String {
        let size = match self {
            Profile::LowEnd => "ram",
            Profile::Balanced => "min(ram / 2, 8192)",
            Profile::Performance => "min(ram / 2, 16384)",
        };
        format!("[zram0]\nzram-size = {size}\ncompression-algorithm = zstd\n")
    }
}

impl Choice {
    pub fn parse(s: &str) -> Option<Choice> {
        match s {
            "auto" => Some(Choice::Auto),
            "low-end" | "lowend" | "low" => Some(Choice::Fixed(Profile::LowEnd)),
            "balanced" => Some(Choice::Fixed(Profile::Balanced)),
            "performance" => Some(Choice::Fixed(Profile::Performance)),
            _ => None,
        }
    }

    pub fn name(self) -> &'static str {
        match self {
            Choice::Auto => "auto",
            Choice::Fixed(p) => p.name(),
        }
    }

    pub fn resolve(self, hw: &Hardware) -> Profile {
        match self {
            Choice::Fixed(p) => p,
            Choice::Auto if hw.is_low_end() => Profile::LowEnd,
            Choice::Auto => Profile::Balanced,
        }
    }

    pub fn from_conf(text: &str) -> Choice {
        text.lines()
            .filter_map(|l| l.trim().strip_prefix("profile="))
            .next_back()
            .and_then(|v| Choice::parse(v.trim()))
            .unwrap_or(Choice::Auto)
    }

    pub fn to_conf(self) -> String {
        format!("profile={}\n", self.name())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const NAMES: [&str; 4] = ["auto", "low-end", "balanced", "performance"];

    const BIG: Hardware = Hardware {
        mem_kib: 32_000_000,
        cpus: 16,
        gpu_accel: true,
    };
    const SMALL: Hardware = Hardware {
        mem_kib: 1_900_000,
        cpus: 2,
        gpu_accel: false,
    };

    #[test]
    fn parse_names() {
        for n in NAMES {
            assert_eq!(Choice::parse(n).unwrap().name(), n);
        }
        assert_eq!(
            Choice::parse("lowend"),
            Some(Choice::Fixed(Profile::LowEnd))
        );
        assert_eq!(Choice::parse("turbo"), None);
        assert_eq!(Choice::parse(""), None);
    }

    #[test]
    fn auto_never_picks_performance() {
        assert_eq!(Choice::Auto.resolve(&BIG), Profile::Balanced);
        assert_eq!(Choice::Auto.resolve(&SMALL), Profile::LowEnd);
        assert_eq!(
            Choice::Fixed(Profile::Performance).resolve(&SMALL),
            Profile::Performance
        );
    }

    #[test]
    fn conf_round_trip() {
        for n in NAMES {
            let c = Choice::parse(n).unwrap();
            assert_eq!(Choice::from_conf(&c.to_conf()), c);
        }
        assert_eq!(Choice::from_conf(""), Choice::Auto);
        assert_eq!(Choice::from_conf("profile=bogus\n"), Choice::Auto);
        assert_eq!(
            Choice::from_conf("profile=balanced\nprofile=low-end\n"),
            Choice::Fixed(Profile::LowEnd)
        );
    }

    #[test]
    fn rendered_files() {
        assert!(Profile::LowEnd.zram().contains("zram-size = ram\n"));
        assert!(Profile::Balanced.zram().starts_with("[zram0]\n"));
        assert!(Profile::LowEnd
            .sysctl()
            .contains("vm.dirty_bytes = 67108864"));
        assert!(Profile::Performance
            .sysctl()
            .contains("-kernel.split_lock_mitigate = 0"));
        assert!(!Profile::Balanced.sysctl().contains("split_lock"));
        assert_eq!(Profile::Performance.power_profile(), "performance");
        assert_eq!(Profile::LowEnd.power_profile(), "balanced");
    }
}
