use crate::sys;
use anyhow::{Context, Result};
use std::collections::BTreeMap;
use std::path::PathBuf;

const LIMIT: u64 = 64 * 1024;
pub const MAX_MONITORS: usize = 16;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Scaling {
    Fill,
    Fit,
    Stretch,
    Default,
}

impl Scaling {
    pub fn parse(v: &str) -> Option<Scaling> {
        match v {
            "fill" => Some(Scaling::Fill),
            "fit" => Some(Scaling::Fit),
            "stretch" => Some(Scaling::Stretch),
            "default" => Some(Scaling::Default),
            _ => None,
        }
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Scaling::Fill => "fill",
            Scaling::Fit => "fit",
            Scaling::Stretch => "stretch",
            Scaling::Default => "default",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Config {
    pub wallpaper: Option<String>,
    pub monitors: BTreeMap<String, String>,
    pub paused: bool,
    pub pause_on_fullscreen: bool,
    pub pause_on_battery: bool,
    pub sound: bool,
    pub volume: u32,
    pub fps: u32,
    pub scaling: Scaling,
    pub autostart: bool,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            wallpaper: None,
            monitors: BTreeMap::new(),
            paused: false,
            pause_on_fullscreen: true,
            pause_on_battery: true,
            sound: false,
            volume: 50,
            fps: 30,
            scaling: Scaling::Fill,
            autostart: true,
        }
    }
}

fn boolean(v: &str) -> Option<bool> {
    match v {
        "true" | "yes" | "on" | "1" => Some(true),
        "false" | "no" | "off" | "0" => Some(false),
        _ => None,
    }
}

pub fn valid_monitor(name: &str) -> bool {
    !name.is_empty()
        && name.len() <= 64
        && !name.starts_with('-')
        && name
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"._-:".contains(&b))
}

pub fn valid_workshop_id(id: &str) -> bool {
    !id.is_empty() && id.len() <= 20 && id.bytes().all(|b| b.is_ascii_digit())
}

pub fn valid_wallpaper(v: &str) -> bool {
    if valid_workshop_id(v) {
        return true;
    }
    v.starts_with('/')
        && v.len() <= 4096
        && !v.chars().any(char::is_control)
        && !v.split('/').any(|c| c == "..")
}

impl Config {
    pub fn parse(text: &str) -> Config {
        let mut c = Config::default();
        for line in text.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            let Some((k, v)) = line.split_once('=') else {
                continue;
            };
            let (k, v) = (k.trim(), v.trim());
            if let Some(m) = k.strip_prefix("monitor.") {
                if valid_monitor(m) && valid_wallpaper(v) && c.monitors.len() < MAX_MONITORS {
                    c.monitors.insert(m.to_string(), v.to_string());
                }
                continue;
            }
            match k {
                "wallpaper" => {
                    c.wallpaper = valid_wallpaper(v).then(|| v.to_string());
                }
                "paused" => c.paused = boolean(v).unwrap_or(c.paused),
                "pause_on_fullscreen" => {
                    c.pause_on_fullscreen = boolean(v).unwrap_or(c.pause_on_fullscreen)
                }
                "pause_on_battery" => c.pause_on_battery = boolean(v).unwrap_or(c.pause_on_battery),
                "sound" => c.sound = boolean(v).unwrap_or(c.sound),
                "volume" => {
                    if let Ok(n) = v.parse::<u32>() {
                        c.volume = n.min(100);
                    }
                }
                "fps" => {
                    if let Ok(n) = v.parse::<u32>() {
                        c.fps = n.clamp(5, 240);
                    }
                }
                "scaling" => c.scaling = Scaling::parse(v).unwrap_or(c.scaling),
                "autostart" => c.autostart = boolean(v).unwrap_or(c.autostart),
                _ => {}
            }
        }
        c
    }

    pub fn render(&self) -> String {
        let mut out = String::new();
        if let Some(w) = self.wallpaper.as_deref().filter(|w| valid_wallpaper(w)) {
            out.push_str(&format!("wallpaper = {w}\n"));
        }
        for (m, w) in self.monitors.iter().take(MAX_MONITORS) {
            if valid_monitor(m) && valid_wallpaper(w) {
                out.push_str(&format!("monitor.{m} = {w}\n"));
            }
        }
        out.push_str(&format!(
            "paused = {}\npause_on_fullscreen = {}\npause_on_battery = {}\nsound = {}\nvolume = {}\nfps = {}\nscaling = {}\nautostart = {}\n",
            self.paused,
            self.pause_on_fullscreen,
            self.pause_on_battery,
            self.sound,
            self.volume.min(100),
            self.fps.clamp(5, 240),
            self.scaling.as_str(),
            self.autostart
        ));
        out
    }

    pub fn wallpaper_for(&self, monitor: &str) -> Option<&str> {
        self.monitors
            .get(monitor)
            .map(String::as_str)
            .or(self.wallpaper.as_deref())
    }

    pub fn load() -> Config {
        path()
            .and_then(|p| sys::read_limited(&p, LIMIT))
            .map(|t| Config::parse(&t))
            .unwrap_or_default()
    }

    pub fn save(&self) -> Result<()> {
        let p = path().context("no home folder")?;
        sys::write_private(&p, self.render().as_bytes())
    }

    pub fn update(f: impl FnOnce(&mut Config)) -> Result<Config> {
        let mut c = Config::load();
        f(&mut c);
        c.save()?;
        Ok(c)
    }
}

pub fn path() -> Option<PathBuf> {
    sys::config_home().map(|d| d.join("kereru").join("kereru.conf"))
}

pub fn stamp() -> Option<(std::time::SystemTime, u64)> {
    let m = std::fs::metadata(path()?).ok()?;
    Some((m.modified().ok()?, m.len()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_are_quiet_and_battery_friendly() {
        let c = Config::default();
        assert!(!c.sound);
        assert!(c.pause_on_battery);
        assert!(c.pause_on_fullscreen);
        assert_eq!(c.fps, 30);
        assert!(c.autostart);
    }

    #[test]
    fn round_trip() {
        let mut c = Config {
            wallpaper: Some("3559984950".into()),
            paused: true,
            sound: true,
            volume: 20,
            fps: 60,
            scaling: Scaling::Fit,
            autostart: false,
            ..Config::default()
        };
        c.monitors.insert("HDMI-A-1".into(), "/home/k/wall".into());
        assert_eq!(Config::parse(&c.render()), c);
    }

    #[test]
    fn rejects_bad_values() {
        let c = Config::parse(
            "wallpaper = ../etc\nmonitor.-x = 1\nmonitor.DP-1 = rel/path\nmonitor.eDP-1 = /a/../b\nfps = 9000\nvolume = 400\nscaling = zoom\nsound = maybe\n",
        );
        assert_eq!(c.wallpaper, None);
        assert!(c.monitors.is_empty());
        assert_eq!(c.fps, 240);
        assert_eq!(c.volume, 100);
        assert_eq!(c.scaling, Scaling::Fill);
        assert!(!c.sound);
    }

    #[test]
    fn rejects_injected_lines() {
        let c = Config {
            wallpaper: Some("/x\npaused = true".into()),
            ..Config::default()
        };
        let back = Config::parse(&c.render());
        assert_eq!(back.wallpaper, None);
        assert!(!back.paused);
    }

    #[test]
    fn monitor_override_wins() {
        let c = Config::parse("wallpaper = 1\nmonitor.DP-2 = 2\n");
        assert_eq!(c.wallpaper_for("DP-2"), Some("2"));
        assert_eq!(c.wallpaper_for("DP-3"), Some("1"));
    }

    #[test]
    fn caps_monitor_count() {
        let text: String = (0..40).map(|i| format!("monitor.M{i} = {i}\n")).collect();
        assert_eq!(Config::parse(&text).monitors.len(), MAX_MONITORS);
    }

    #[test]
    fn monitor_names() {
        assert!(valid_monitor("HDMI-A-1"));
        assert!(valid_monitor("eDP-1"));
        assert!(!valid_monitor(""));
        assert!(!valid_monitor("--bg"));
        assert!(!valid_monitor("a b"));
        assert!(!valid_monitor("a=b"));
    }
}
