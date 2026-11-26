use crate::colors;
use crate::config::{self, Config};
use crate::engine::{self, Engine, Plan};
use crate::library::{self, Library};
use crate::outputs::{self, Monitor};
use crate::sys;
use anyhow::Result;
use ksni::blocking::TrayMethods;
use std::os::fd::AsRawFd;
use std::os::unix::fs::OpenOptionsExt;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, RecvTimeoutError, Sender};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

const TICK: Duration = Duration::from_secs(1);
const MONITOR_EVERY: Duration = Duration::from_secs(5);
const BATTERY_EVERY: Duration = Duration::from_secs(5);
const SCAN_EVERY: Duration = Duration::from_secs(120);
const QUICK_CRASH: Duration = Duration::from_secs(20);
const MAX_FAILURES: u32 = 5;
const MENU_ITEMS: usize = 40;

static QUIT: AtomicBool = AtomicBool::new(false);

extern "C" fn on_quit_signal(_: libc::c_int) {
    QUIT.store(true, Ordering::SeqCst);
}

fn quit_on_signals() {
    let handler = on_quit_signal as extern "C" fn(libc::c_int) as libc::sighandler_t;
    for sig in [libc::SIGTERM, libc::SIGINT, libc::SIGHUP] {
        unsafe {
            libc::signal(sig, handler);
        }
    }
}

pub fn stop_wallpaper(c: &mut Config) {
    c.wallpaper = None;
    c.monitors.clear();
}

pub enum Msg {
    Wake,
    Quit,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct View {
    pub cfg: Option<Config>,
    pub current: Option<String>,
    pub current_title: String,
    pub items: Vec<(String, String)>,
    pub screens: usize,
    pub running: bool,
    pub paused: bool,
    pub battery: bool,
    pub problem: Option<String>,
}

pub fn lock() -> Option<std::fs::File> {
    let dir = sys::runtime_dir()?;
    let f = std::fs::OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
        .open(dir.join("kereru.lock"))
        .ok()?;
    let r = unsafe { libc::flock(f.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) };
    (r == 0).then_some(f)
}

pub fn running() -> bool {
    match lock() {
        Some(f) => {
            drop(f);
            false
        }
        None => sys::runtime_dir().is_some(),
    }
}

pub fn start_in_background() -> bool {
    if running() {
        return true;
    }
    let exe = sys::self_exe();
    !exe.is_empty() && sys::spawn_detached(&exe, ["--tray"])
}

pub fn open_picker() {
    let exe = sys::self_exe();
    if !exe.is_empty() {
        sys::spawn_detached(&exe, std::iter::empty::<&str>());
    }
}

struct Tray {
    view: Arc<Mutex<View>>,
    tx: Sender<Msg>,
}

impl Tray {
    fn change(&self, f: impl FnOnce(&mut Config)) {
        if Config::update(f).is_ok() {
            let _ = self.tx.send(Msg::Wake);
        }
    }

    fn snapshot(&self) -> View {
        self.view.lock().unwrap_or_else(|e| e.into_inner()).clone()
    }
}

pub fn status_line(v: &View) -> String {
    if let Some(p) = &v.problem {
        return p.clone();
    }
    if v.current.is_none() {
        return "Pick a wallpaper to get started".into();
    }
    if v.paused {
        let user = v.cfg.as_ref().is_some_and(|c| c.paused);
        return if user {
            "Paused".into()
        } else if v.battery {
            "Paused on battery".into()
        } else {
            "Paused".into()
        };
    }
    if !v.running {
        return "Starting".into();
    }
    match v.screens {
        0 | 1 => "Playing".into(),
        n => format!("Playing on {n} screens"),
    }
}

impl ksni::Tray for Tray {
    fn id(&self) -> String {
        "kereru".into()
    }

    fn title(&self) -> String {
        "Kererū".into()
    }

    fn icon_name(&self) -> String {
        "kereru".into()
    }

    fn status(&self) -> ksni::Status {
        ksni::Status::Active
    }

    fn tool_tip(&self) -> ksni::ToolTip {
        let v = self.snapshot();
        let mut description = status_line(&v);
        if v.current.is_some() && v.problem.is_none() {
            description = format!("{}\n{}", v.current_title, description);
        }
        ksni::ToolTip {
            title: "Live wallpaper".into(),
            description,
            ..Default::default()
        }
    }

    fn activate(&mut self, _x: i32, _y: i32) {
        open_picker();
    }

    fn menu(&self) -> Vec<ksni::MenuItem<Self>> {
        use ksni::menu::{CheckmarkItem, RadioGroup, RadioItem, StandardItem, SubMenu};
        let v = self.snapshot();
        let cfg = v.cfg.clone().unwrap_or_default();
        let mut menu: Vec<ksni::MenuItem<Self>> = Vec::new();
        let header = menu_text(&if v.current.is_some() && v.problem.is_none() {
            format!("{} · {}", v.current_title, status_line(&v).to_lowercase())
        } else {
            status_line(&v)
        });
        menu.push(
            StandardItem {
                label: header,
                enabled: false,
                ..Default::default()
            }
            .into(),
        );
        menu.push(ksni::MenuItem::Separator);
        menu.push(
            StandardItem {
                label: if cfg.paused {
                    "Resume".into()
                } else {
                    "Pause".into()
                },
                icon_name: if cfg.paused {
                    "media-playback-start".into()
                } else {
                    "media-playback-pause".into()
                },
                enabled: v.current.is_some(),
                activate: Box::new(|t: &mut Self| t.change(|c| c.paused = !c.paused)),
                ..Default::default()
            }
            .into(),
        );
        menu.push(
            StandardItem {
                label: "Next wallpaper".into(),
                icon_name: "media-skip-forward".into(),
                enabled: v.items.len() > 1,
                activate: Box::new(|t: &mut Self| {
                    let lib = library::scan();
                    let cur = t.snapshot().current;
                    if let Some(next) = lib.next_after(cur.as_deref()) {
                        let key = next.key.clone();
                        t.change(|c| {
                            c.wallpaper = Some(key);
                            c.monitors.clear();
                        });
                    }
                }),
                ..Default::default()
            }
            .into(),
        );
        if !v.items.is_empty() {
            let selected = v
                .current
                .as_ref()
                .and_then(|k| v.items.iter().position(|(key, _)| key == k))
                .unwrap_or(usize::MAX);
            let keys: Vec<String> = v.items.iter().map(|(k, _)| k.clone()).collect();
            menu.push(
                SubMenu {
                    label: "Switch to".into(),
                    submenu: vec![RadioGroup {
                        selected,
                        select: Box::new(move |t: &mut Self, i| {
                            if let Some(key) = keys.get(i).cloned() {
                                t.change(|c| {
                                    c.wallpaper = Some(key);
                                    c.monitors.clear();
                                });
                            }
                        }),
                        options: v
                            .items
                            .iter()
                            .map(|(_, title)| RadioItem {
                                label: menu_text(title),
                                ..Default::default()
                            })
                            .collect(),
                    }
                    .into()],
                    ..Default::default()
                }
                .into(),
            );
        }
        menu.push(
            StandardItem {
                label: "Choose wallpaper…".into(),
                icon_name: "preferences-desktop-wallpaper".into(),
                activate: Box::new(|_: &mut Self| open_picker()),
                ..Default::default()
            }
            .into(),
        );
        menu.push(
            StandardItem {
                label: "Stop live wallpaper".into(),
                icon_name: "media-playback-stop".into(),
                enabled: v.current.is_some(),
                activate: Box::new(|t: &mut Self| t.change(stop_wallpaper)),
                ..Default::default()
            }
            .into(),
        );
        menu.push(ksni::MenuItem::Separator);
        menu.push(
            CheckmarkItem {
                label: "Sound".into(),
                checked: cfg.sound,
                activate: Box::new(|t: &mut Self| t.change(|c| c.sound = !c.sound)),
                ..Default::default()
            }
            .into(),
        );
        menu.push(
            CheckmarkItem {
                label: "Pause when an app is fullscreen".into(),
                checked: cfg.pause_on_fullscreen,
                activate: Box::new(|t: &mut Self| {
                    t.change(|c| c.pause_on_fullscreen = !c.pause_on_fullscreen)
                }),
                ..Default::default()
            }
            .into(),
        );
        menu.push(
            CheckmarkItem {
                label: "Pause on battery".into(),
                checked: cfg.pause_on_battery,
                activate: Box::new(|t: &mut Self| {
                    t.change(|c| c.pause_on_battery = !c.pause_on_battery)
                }),
                ..Default::default()
            }
            .into(),
        );
        menu.push(ksni::MenuItem::Separator);
        menu.push(
            StandardItem {
                label: "Quit".into(),
                icon_name: "application-exit".into(),
                activate: Box::new(|t: &mut Self| {
                    let _ = t.tx.send(Msg::Quit);
                }),
                ..Default::default()
            }
            .into(),
        );
        menu
    }
}

struct Supervisor {
    log: Option<std::path::PathBuf>,
    engine: Option<Engine>,
    running_plan: Option<Plan>,
    failures: u32,
    retry_at: Instant,
    gave_up_on: Option<Plan>,
}

impl Supervisor {
    fn stop(&mut self) {
        if let Some(e) = self.engine.take() {
            e.stop();
        }
        self.running_plan = None;
    }

    fn step(&mut self, want: &Plan, bin: Option<&std::path::Path>) -> Option<String> {
        let Some(bin) = bin else {
            self.stop();
            return Some("linux-wallpaperengine isn't installed".into());
        };
        if let Some(e) = self.engine.as_mut() {
            if !e.alive() {
                let quick = e.uptime() < QUICK_CRASH;
                self.engine = None;
                if quick {
                    self.failures += 1;
                    let wait = 2u64.saturating_pow(self.failures).min(300);
                    self.retry_at = Instant::now() + Duration::from_secs(wait);
                } else {
                    self.failures = 0;
                    self.retry_at = Instant::now() + Duration::from_secs(2);
                }
                if self.failures >= MAX_FAILURES {
                    self.gave_up_on = self.running_plan.clone();
                }
                self.running_plan = None;
            } else if e.uptime() > Duration::from_secs(60) {
                self.failures = 0;
            }
        }
        if self.running_plan.as_ref() != Some(want) {
            self.stop();
            if self.gave_up_on.as_ref() != Some(want) {
                self.gave_up_on = None;
                if self.failures >= MAX_FAILURES {
                    self.failures = 0;
                    self.retry_at = Instant::now();
                }
            }
        }
        if self.gave_up_on.as_ref() == Some(want) {
            return Some("This wallpaper keeps crashing. Pick another one.".into());
        }
        if want.screens.is_empty() {
            return None;
        }
        if self.engine.is_none() && Instant::now() >= self.retry_at {
            match Engine::start(bin, want, self.log.as_deref()) {
                Ok(e) => {
                    self.engine = Some(e);
                    self.running_plan = Some(want.clone());
                }
                Err(e) => {
                    self.failures += 1;
                    self.retry_at = Instant::now() + Duration::from_secs(30);
                    return Some(format!("{e:#}"));
                }
            }
        }
        None
    }
}

pub fn menu_text(s: &str) -> String {
    s.replace('_', "__")
}

fn menu_items(lib: &Library) -> Vec<(String, String)> {
    lib.playable()
        .take(MENU_ITEMS)
        .map(|i| (i.key.clone(), i.title.clone()))
        .collect()
}

pub fn run(autostart: bool) -> Result<()> {
    if autostart && !Config::load().autostart {
        return Ok(());
    }
    let Some(_lock) = lock() else {
        if sys::runtime_dir().is_some() {
            return Ok(());
        }
        anyhow::bail!("XDG_RUNTIME_DIR is missing or not private");
    };
    quit_on_signals();
    let view = Arc::new(Mutex::new(View::default()));
    let (tx, rx) = mpsc::channel();
    let handle = Tray {
        view: view.clone(),
        tx: tx.clone(),
    }
    .assume_sni_available(true)
    .spawn()
    .map_err(|e| anyhow::anyhow!("no system tray: {e}"));
    let handle = match handle {
        Ok(h) => Some(h),
        Err(e) => {
            eprintln!("kereru: {e:#}, running without a tray icon");
            None
        }
    };

    let mut cfg = Config::load();
    let mut stamp = config::stamp();
    let mut lib = library::scan();
    let mut scanned = Instant::now();
    let mut monitors: Vec<Monitor> = outputs::list();
    let mut monitors_at = Instant::now();
    let mut battery = cfg.pause_on_battery && sys::on_battery();
    let mut battery_at = Instant::now();
    let mut sup = Supervisor {
        log: engine::log_path(),
        engine: None,
        running_plan: None,
        failures: 0,
        retry_at: Instant::now(),
        gave_up_on: None,
    };
    let mut shown = View::default();
    let mut publisher = colors::Publisher::new(colors::dir());

    loop {
        if QUIT.load(Ordering::SeqCst) {
            break;
        }
        let mut force = false;
        match rx.recv_timeout(TICK) {
            Ok(Msg::Quit) | Err(RecvTimeoutError::Disconnected) => break,
            Ok(Msg::Wake) => force = true,
            Err(RecvTimeoutError::Timeout) => {}
        }
        let now_stamp = config::stamp();
        if force || now_stamp != stamp {
            stamp = now_stamp;
            let fresh = Config::load();
            let picked_new = fresh.wallpaper != cfg.wallpaper || fresh.monitors != cfg.monitors;
            cfg = fresh;
            if picked_new {
                lib = library::scan();
                scanned = Instant::now();
            }
            battery = cfg.pause_on_battery && sys::on_battery();
        }
        if scanned.elapsed() >= SCAN_EVERY {
            lib = library::scan();
            scanned = Instant::now();
        }
        if monitors_at.elapsed() >= MONITOR_EVERY {
            let fresh = outputs::list();
            if !fresh.is_empty() || monitors.is_empty() {
                monitors = fresh;
            }
            monitors_at = Instant::now();
        }
        if battery_at.elapsed() >= BATTERY_EVERY {
            battery = cfg.pause_on_battery && sys::on_battery();
            battery_at = Instant::now();
        }

        let want = engine::plan(&cfg, &lib, &monitors);
        let bin = engine::engine_path();
        let mut problem = sup.step(&want, bin.as_deref());
        if problem.is_none() && cfg.wallpaper.is_some() && want.screens.is_empty() {
            problem = Some(if monitors.is_empty() {
                "No screens found".into()
            } else if monitors
                .iter()
                .filter_map(|m| cfg.wallpaper_for(&m.name))
                .any(|k| lib.unsupported(k))
            {
                library::WEB_NOTE.into()
            } else {
                "The chosen wallpaper isn't installed anymore".into()
            });
        }
        let pause = cfg.paused || battery;
        if let Some(e) = sup.engine.as_mut() {
            e.set_paused(pause);
        }
        let playing = match (&sup.engine, &sup.running_plan) {
            (Some(_), Some(p)) => colors::playing_key(&p.screens, |m| cfg.wallpaper_for(m)),
            _ => None,
        };
        publisher.publish(playing, |k| lib.current(k).and_then(|i| i.preview));

        let current = monitors
            .first()
            .and_then(|m| cfg.wallpaper_for(&m.name))
            .or(cfg.wallpaper.as_deref())
            .map(str::to_string);
        let next = View {
            current_title: current.as_deref().map(|k| lib.title(k)).unwrap_or_default(),
            current,
            items: menu_items(&lib),
            screens: want.screens.len(),
            running: sup.engine.is_some(),
            paused: pause,
            battery,
            problem,
            cfg: Some(cfg.clone()),
        };
        if next != shown {
            *view.lock().unwrap_or_else(|e| e.into_inner()) = next.clone();
            shown = next;
            if let Some(h) = handle.as_ref() {
                h.update(|_| {});
            }
        }
    }
    sup.stop();
    publisher.publish(None, |_| None);
    drop(handle);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn status_lines() {
        let mut v = View::default();
        assert_eq!(status_line(&v), "Pick a wallpaper to get started");
        v.current = Some("1".into());
        v.running = true;
        v.screens = 2;
        assert_eq!(status_line(&v), "Playing on 2 screens");
        v.paused = true;
        v.battery = true;
        v.cfg = Some(Config::default());
        assert_eq!(status_line(&v), "Paused on battery");
        v.problem = Some("boom".into());
        assert_eq!(status_line(&v), "boom");
    }

    #[test]
    fn supervisor_reports_missing_engine() {
        let mut s = Supervisor {
            log: None,
            engine: None,
            running_plan: None,
            failures: 0,
            retry_at: Instant::now(),
            gave_up_on: None,
        };
        let plan = engine::plan(&Config::default(), &Library::default(), &[]);
        assert!(s.step(&plan, None).unwrap().contains("isn't installed"));
        assert!(s
            .step(&plan, Some(std::path::Path::new("/bin/true")))
            .is_none());
        assert!(s.engine.is_none());
    }

    #[test]
    fn supervisor_gives_up_after_repeated_quick_crashes() {
        let mut s = Supervisor {
            log: None,
            engine: None,
            running_plan: None,
            failures: 0,
            retry_at: Instant::now(),
            gave_up_on: None,
        };
        let plan = Plan {
            screens: vec![("X".into(), std::path::PathBuf::from("/nonexistent"))],
            assets: None,
            fps: 30,
            sound: false,
            volume: 0,
            scaling: "fill",
            fullscreen_pause: true,
        };
        let bin = std::path::Path::new("/bin/false");
        for _ in 0..(MAX_FAILURES * 2) {
            s.retry_at = Instant::now();
            s.step(&plan, Some(bin));
            std::thread::sleep(Duration::from_millis(80));
        }
        let msg = s.step(&plan, Some(bin));
        assert!(msg.unwrap().contains("keeps crashing"));
        let other = Plan {
            fps: 60,
            ..plan.clone()
        };
        s.retry_at = Instant::now();
        assert!(s.step(&other, Some(bin)).is_none());
        assert!(s.engine.is_some());
        s.stop();
    }
}
