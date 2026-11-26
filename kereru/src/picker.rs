use crate::config::Config;
use crate::library::{self, Item, Library};
use crate::outputs::{self, Monitor};
use crate::workshop::{self, Query, Sort};
use crate::{daemon, engine, sys, App, Screen, Shop, Theme, Wall};
use anyhow::Result;
use slint::{ComponentHandle, Model, ModelRc, Rgba8Pixel, SharedPixelBuffer, VecModel};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::rc::Rc;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

const THUMB_W: u32 = 384;
const THUMB_H: u32 = 216;
const WORKSHOP: &str = "steam://url/SteamWorkshopPage/431960";
const STORE: &str = "steam://store/431960";

type Thumb = (u32, u32, Vec<u8>);

pub struct Problem {
    pub title: &'static str,
    pub text: &'static str,
    pub action: &'static str,
    pub url: &'static str,
}

pub fn problem(engine: bool, lib: &Library) -> Option<Problem> {
    if !engine {
        return Some(Problem {
            title: "the wallpaper engine is missing",
            text: "Install the linux-wallpaperengine package, then open this again.",
            action: "",
            url: "",
        });
    }
    if !lib.steam {
        return Some(Problem {
            title: "Steam isn't set up",
            text: "Live wallpapers come from Wallpaper Engine in your Steam library. Install Steam, sign in, then come back.",
            action: "",
            url: "",
        });
    }
    if lib.assets.is_none() {
        return Some(Problem {
            title: "Wallpaper Engine isn't installed",
            text: "Buy or install Wallpaper Engine in Steam. In its Properties, turn on Steam Play so Steam downloads it on Linux. Scene wallpapers need its files.",
            action: "open in Steam",
            url: STORE,
        });
    }
    if lib.items.is_empty() {
        return Some(Problem {
            title: "no wallpapers yet",
            text: "Subscribe to wallpapers in the Steam Workshop. Steam downloads them and they show up here.",
            action: "open the Workshop",
            url: WORKSHOP,
        });
    }
    None
}

pub fn matches(item: &Item, filter: &str, query: &str) -> bool {
    let kind_ok = filter == "all" || item.kind.label() == filter;
    let q = query.trim().to_lowercase();
    kind_ok && (q.is_empty() || item.title.to_lowercase().contains(&q) || item.key.contains(&q))
}

fn decode(path: &Path, blur: bool) -> Option<Thumb> {
    let reader = image::ImageReader::open(path)
        .ok()?
        .with_guessed_format()
        .ok()?;
    decode_reader(reader, blur)
}

fn decode_bytes(bytes: &[u8], blur: bool) -> Option<Thumb> {
    let reader = image::ImageReader::new(std::io::Cursor::new(bytes))
        .with_guessed_format()
        .ok()?;
    decode_reader(reader, blur)
}

fn decode_reader<R: std::io::BufRead + std::io::Seek>(
    mut reader: image::ImageReader<R>,
    blur: bool,
) -> Option<Thumb> {
    let mut limits = image::Limits::default();
    limits.max_image_width = Some(8192);
    limits.max_image_height = Some(8192);
    limits.max_alloc = Some(256 << 20);
    reader.limits(limits);
    let img = reader.decode().ok()?;
    let img = if blur {
        img.resize_exact(16, 9, image::imageops::FilterType::Triangle)
    } else {
        img
    };
    let thumb = img.resize_to_fill(THUMB_W, THUMB_H, image::imageops::FilterType::Triangle);
    let rgba = thumb.to_rgba8();
    Some((rgba.width(), rgba.height(), rgba.into_raw()))
}

struct State {
    lib: Library,
    monitors: Vec<Monitor>,
    thumbs: HashMap<(String, bool), Option<Thumb>>,
    shop: Vec<workshop::Entry>,
    shop_thumbs: HashMap<(String, bool), Option<Thumb>>,
    shop_page: u32,
    shop_gen: u64,
    shop_loaded: bool,
    pending: Vec<(String, Instant)>,
}

const PENDING_FOR: Duration = Duration::from_secs(2 * 60 * 60);

fn to_image(t: &Thumb) -> slint::Image {
    let buf = SharedPixelBuffer::<Rgba8Pixel>::clone_from_slice(&t.2, t.0, t.1);
    slint::Image::from_rgba8(buf)
}

fn scope_key(ui: &App, monitors: &[Monitor]) -> Option<String> {
    let s = ui.get_scope();
    (s > 0)
        .then(|| monitors.get((s - 1) as usize).map(|m| m.name.clone()))
        .flatten()
}

fn current_for(cfg: &Config, scope: Option<&str>) -> Option<String> {
    match scope {
        Some(m) => cfg.wallpaper_for(m).map(str::to_string),
        None => cfg.wallpaper.clone(),
    }
}

fn refresh(ui: &App, st: &Rc<std::cell::RefCell<State>>) {
    let cfg = Config::load();
    let st_ref = st.borrow();
    let scope = scope_key(ui, &st_ref.monitors);
    let current = current_for(&cfg, scope.as_deref());
    let filter = ui.get_filter().to_string();
    let query = ui.get_query().to_string();
    let mature = ui.get_show_mature();
    let walls: Vec<Wall> = st_ref
        .lib
        .items
        .iter()
        .filter(|i| matches(i, &filter, &query))
        .map(|i| {
            let hidden = i.mature && !mature;
            let thumb = st_ref
                .thumbs
                .get(&(i.key.clone(), hidden))
                .cloned()
                .flatten();
            Wall {
                key: i.key.as_str().into(),
                title: i.title.as_str().into(),
                kind: i.kind.label().into(),
                has_preview: thumb.is_some(),
                preview: thumb.as_ref().map(to_image).unwrap_or_default(),
                hidden,
                selected: current.as_deref() == Some(i.key.as_str()),
            }
        })
        .collect();
    ui.set_walls(ModelRc::new(VecModel::from(walls)));
    ui.set_total(st_ref.lib.items.len() as i32);
    ui.set_screens(ModelRc::new(VecModel::from(
        st_ref
            .monitors
            .iter()
            .map(|m| Screen {
                name: m.name.as_str().into(),
                label: m.label.as_str().into(),
                custom: cfg.monitors.contains_key(&m.name),
            })
            .collect::<Vec<_>>(),
    )));
    ui.set_paused(cfg.paused);
    ui.set_has_choice(cfg.wallpaper.is_some() || !cfg.monitors.is_empty());
    let running = daemon::running();
    ui.set_running(running);
    let monitors = st_ref.monitors.len();
    ui.set_subline(
        match (running, cfg.paused) {
            (false, _) => "Not running. Press start, or pick a wallpaper.".to_string(),
            (true, true) => "Paused. Your wallpaper stays as it is.".to_string(),
            (true, false) if monitors > 1 => {
                format!("Running in the background on {monitors} screens.")
            }
            (true, false) => "Running in the background.".to_string(),
        }
        .into(),
    );
    let has_engine = engine::engine_path().is_some();
    match problem(has_engine, &st_ref.lib) {
        Some(p) => {
            ui.set_problem_title(p.title.into());
            ui.set_problem(p.text.into());
            ui.set_problem_action(p.action.into());
        }
        None => {
            ui.set_problem_title("".into());
            ui.set_problem("".into());
            ui.set_problem_action("".into());
        }
    }
    let mut note = format!(
        "{} wallpapers found{}.",
        st_ref.lib.items.len(),
        if st_ref.lib.skipped > 0 {
            format!(
                ", {} skipped (apps or unfinished downloads)",
                st_ref.lib.skipped
            )
        } else {
            String::new()
        }
    );
    if let Some(log) = engine::log_path() {
        note.push_str(&format!(" Engine log: {}", log.display()));
    }
    ui.set_engine_note(note.into());
    ui.set_pause_fullscreen(cfg.pause_on_fullscreen);
    ui.set_pause_battery(cfg.pause_on_battery);
    ui.set_sound(cfg.sound);
    ui.set_autostart(cfg.autostart);
    ui.set_fps(cfg.fps as i32);
}

fn load_thumbs(ui: &App, st: &Rc<std::cell::RefCell<State>>) {
    let mature = ui.get_show_mature();
    let jobs: Vec<(String, bool, PathBuf)> = {
        let s = st.borrow();
        s.lib
            .items
            .iter()
            .filter_map(|i| {
                let hidden = i.mature && !mature;
                let p = i.preview.clone()?;
                (!s.thumbs.contains_key(&(i.key.clone(), hidden)))
                    .then(|| (i.key.clone(), hidden, p))
            })
            .collect()
    };
    if jobs.is_empty() {
        return;
    }
    let queue = Arc::new(Mutex::new(jobs));
    let workers = std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(2)
        .clamp(1, 4);
    for _ in 0..workers {
        let queue = queue.clone();
        let weak = ui.as_weak();
        std::thread::spawn(move || loop {
            let job = queue.lock().unwrap_or_else(|e| e.into_inner()).pop();
            let Some((key, hidden, path)) = job else {
                break;
            };
            let thumb = decode(&path, hidden);
            let _ = weak.upgrade_in_event_loop(move |ui| {
                STATE.with(|cell| {
                    if let Some(st) = cell.borrow().as_ref() {
                        st.borrow_mut()
                            .thumbs
                            .insert((key.clone(), hidden), thumb.clone());
                        let model = ui.get_walls();
                        for row in 0..model.row_count() {
                            if let Some(mut w) = model.row_data(row) {
                                if w.key.as_str() == key && w.hidden == hidden {
                                    w.has_preview = thumb.is_some();
                                    w.preview = thumb.as_ref().map(to_image).unwrap_or_default();
                                    model.set_row_data(row, w);
                                }
                            }
                        }
                    }
                });
            });
        });
    }
}

pub fn shop_state(installed: bool, waiting: bool) -> &'static str {
    if installed {
        "installed"
    } else if waiting {
        "waiting"
    } else {
        "get"
    }
}

fn shop_rows(ui: &App, st: &State) -> Vec<Shop> {
    let mature = ui.get_show_mature();
    st.shop
        .iter()
        .map(|e| {
            let hidden = e.mature && !mature;
            let thumb = st
                .shop_thumbs
                .get(&(e.id.clone(), hidden))
                .cloned()
                .flatten();
            Shop {
                id: e.id.as_str().into(),
                title: e.title.as_str().into(),
                kind: e.kind.label().into(),
                has_preview: thumb.is_some(),
                preview: thumb.as_ref().map(to_image).unwrap_or_default(),
                hidden,
                state: shop_state(
                    st.lib.find(&e.id).is_some(),
                    st.pending.iter().any(|(p, _)| *p == e.id),
                )
                .into(),
                subs: workshop::short_count(e.subscriptions).into(),
            }
        })
        .collect()
}

fn show_shop(ui: &App, st: &Rc<std::cell::RefCell<State>>) {
    let rows = shop_rows(ui, &st.borrow());
    ui.set_shop(ModelRc::new(VecModel::from(rows)));
}

fn shop_query(ui: &App, page: u32) -> Query {
    Query {
        text: ui.get_shop_query().to_string(),
        sort: Sort::parse(&ui.get_shop_sort()),
        kind: library::Kind::parse(&ui.get_shop_kind()),
        page,
    }
}

fn search_shop(ui: &App, st: &Rc<std::cell::RefCell<State>>, more: bool) {
    let (generation, page) = {
        let mut s = st.borrow_mut();
        s.shop_gen += 1;
        s.shop_loaded = true;
        if !more {
            s.shop.clear();
            s.shop_page = 0;
        }
        (s.shop_gen, s.shop_page + 1)
    };
    if !more {
        ui.set_shop(ModelRc::new(VecModel::from(Vec::<Shop>::new())));
    }
    ui.set_shop_busy(true);
    ui.set_shop_status("".into());
    let q = shop_query(ui, page);
    let weak = ui.as_weak();
    std::thread::spawn(move || {
        let result = workshop::search(&q);
        let _ = weak.upgrade_in_event_loop(move |ui| {
            STATE.with(|cell| {
                let Some(st) = cell.borrow().as_ref().cloned() else {
                    return;
                };
                if st.borrow().shop_gen != generation {
                    return;
                }
                ui.set_shop_busy(false);
                match result {
                    Ok(found) => {
                        let mut s = st.borrow_mut();
                        s.shop_page = page;
                        let fresh: Vec<_> = found
                            .into_iter()
                            .filter(|e| !s.shop.iter().any(|x| x.id == e.id))
                            .collect();
                        ui.set_shop_more(!fresh.is_empty() && page < 50);
                        s.shop.extend(fresh);
                    }
                    Err(e) => {
                        ui.set_shop_more(false);
                        ui.set_shop_status(
                            format!("{e}. Check your connection and try again.").into(),
                        );
                    }
                }
                show_shop(&ui, &st);
                load_shop_thumbs(&ui, &st);
            });
        });
    });
}

fn load_shop_thumbs(ui: &App, st: &Rc<std::cell::RefCell<State>>) {
    let mature = ui.get_show_mature();
    let jobs: Vec<(String, bool, String)> = {
        let s = st.borrow();
        s.shop
            .iter()
            .filter_map(|e| {
                let hidden = e.mature && !mature;
                let url = e.preview.clone()?;
                (!s.shop_thumbs.contains_key(&(e.id.clone(), hidden)))
                    .then(|| (e.id.clone(), hidden, url))
            })
            .collect()
    };
    if jobs.is_empty() {
        return;
    }
    {
        let mut s = st.borrow_mut();
        for (id, hidden, _) in &jobs {
            s.shop_thumbs.insert((id.clone(), *hidden), None);
        }
    }
    let queue = Arc::new(Mutex::new(jobs));
    for _ in 0..4 {
        let queue = queue.clone();
        let weak = ui.as_weak();
        std::thread::spawn(move || loop {
            let job = queue.lock().unwrap_or_else(|e| e.into_inner()).pop();
            let Some((id, hidden, url)) = job else {
                break;
            };
            let thumb = workshop::preview(&url)
                .ok()
                .and_then(|b| decode_bytes(&b, hidden));
            let _ = weak.upgrade_in_event_loop(move |ui| {
                STATE.with(|cell| {
                    let Some(st) = cell.borrow().as_ref().cloned() else {
                        return;
                    };
                    st.borrow_mut()
                        .shop_thumbs
                        .insert((id.clone(), hidden), thumb.clone());
                    let model = ui.get_shop();
                    for row in 0..model.row_count() {
                        if let Some(mut w) = model.row_data(row) {
                            if w.id.as_str() == id && w.hidden == hidden {
                                w.has_preview = thumb.is_some();
                                w.preview = thumb.as_ref().map(to_image).unwrap_or_default();
                                model.set_row_data(row, w);
                            }
                        }
                    }
                });
            });
        });
    }
}

fn apply(ui: &App, st: &Rc<std::cell::RefCell<State>>, key: String) {
    let scope = scope_key(ui, &st.borrow().monitors);
    save(|c| match scope {
        Some(m) => {
            if c.wallpaper.is_none() {
                c.wallpaper = Some(key.clone());
            }
            if c.wallpaper.as_deref() == Some(key.as_str()) {
                c.monitors.remove(&m);
            } else {
                c.monitors.insert(m, key.clone());
            }
        }
        None => c.wallpaper = Some(key.clone()),
    });
    daemon::start_in_background();
    refresh(ui, st);
}

fn rescan(ui: &App, st: &Rc<std::cell::RefCell<State>>) {
    {
        let mut s = st.borrow_mut();
        s.lib = library::scan();
        s.monitors = outputs::list();
    }
    refresh(ui, st);
    load_thumbs(ui, st);
    show_shop(ui, st);
}

fn check_pending(ui: &App, st: &Rc<std::cell::RefCell<State>>) {
    let arrived: Vec<String> = {
        let mut s = st.borrow_mut();
        s.pending.retain(|(_, at)| at.elapsed() < PENDING_FOR);
        let done: Vec<String> = s
            .pending
            .iter()
            .filter(|(id, _)| library::arrived(id))
            .map(|(id, _)| id.clone())
            .collect();
        s.pending.retain(|(id, _)| !done.contains(id));
        done
    };
    if arrived.is_empty() {
        return;
    }
    rescan(ui, st);
    if let Some(id) = arrived.last() {
        let title = st.borrow().lib.find(id).map(|i| i.title.clone());
        if let Some(title) = title {
            apply(ui, st, id.clone());
            ui.set_shop_status(format!("{title} downloaded and is playing now.").into());
            show_shop(ui, st);
        }
    }
}

thread_local! {
    static STATE: std::cell::RefCell<Option<Rc<std::cell::RefCell<State>>>> = const { std::cell::RefCell::new(None) };
}

fn save(f: impl FnOnce(&mut Config)) {
    if let Err(e) = Config::update(f) {
        eprintln!("kereru: couldn't save settings: {e:#}");
    }
}

pub fn select_backend() {
    if std::env::var_os("SLINT_BACKEND").is_some() {
        return;
    }
    if sys::low_end() {
        let _ = slint::BackendSelector::new()
            .backend_name("winit".into())
            .renderer_name("software".into())
            .select();
    }
}

pub fn run() -> Result<()> {
    select_backend();
    let ui = App::new()?;
    let _ = slint::set_xdg_app_id("kereru");
    let theme = ui.global::<Theme>();
    let low = sys::low_end();
    theme.set_mode(sys::theme_mode());
    theme.set_low_end(low);
    theme.set_reduce_motion(sys::flag("KERERU_REDUCE_MOTION").unwrap_or(low));
    theme.set_symbols(sys::symbols_font());
    ui.set_version(env!("CARGO_PKG_VERSION").into());

    let st = Rc::new(std::cell::RefCell::new(State {
        lib: library::scan(),
        monitors: outputs::list(),
        thumbs: HashMap::new(),
        shop: Vec::new(),
        shop_thumbs: HashMap::new(),
        shop_page: 0,
        shop_gen: 0,
        shop_loaded: false,
        pending: Vec::new(),
    }));
    STATE.with(|c| *c.borrow_mut() = Some(st.clone()));
    refresh(&ui, &st);
    load_thumbs(&ui, &st);
    if st.borrow().lib.items.is_empty() && st.borrow().lib.assets.is_some() {
        ui.set_tab(1);
        search_shop(&ui, &st, false);
    }

    let weak = ui.as_weak();
    let s = st.clone();
    ui.on_pick(move |key| {
        if let Some(ui) = weak.upgrade() {
            apply(&ui, &s, key.to_string());
        }
    });

    let weak = ui.as_weak();
    let s = st.clone();
    ui.on_tab_changed(move || {
        let Some(ui) = weak.upgrade() else { return };
        if ui.get_tab() == 1 && !s.borrow().shop_loaded {
            search_shop(&ui, &s, false);
        }
    });

    let weak = ui.as_weak();
    let s = st.clone();
    ui.on_shop_search(move || {
        if let Some(ui) = weak.upgrade() {
            search_shop(&ui, &s, false);
        }
    });

    let weak = ui.as_weak();
    let s = st.clone();
    ui.on_shop_load_more(move || {
        if let Some(ui) = weak.upgrade() {
            search_shop(&ui, &s, true);
        }
    });

    let weak = ui.as_weak();
    let s = st.clone();
    ui.on_shop_get(move |id| {
        let Some(ui) = weak.upgrade() else { return };
        let steam = s.borrow().lib.steam;
        let Some(url) = workshop::item_page(&id, steam) else {
            return;
        };
        sys::open_url(&url);
        {
            let mut st = s.borrow_mut();
            st.pending.retain(|(p, _)| *p != id.as_str());
            st.pending.push((id.to_string(), Instant::now()));
        }
        ui.set_shop_status(
            if steam {
                "Opened in Steam. Press Subscribe there. The wallpaper plays here as soon as Steam has downloaded it."
            } else {
                "Opened the Workshop page in your browser. Subscribe there, and the wallpaper plays here once Steam has downloaded it."
            }
            .into(),
        );
        show_shop(&ui, &s);
    });

    let weak = ui.as_weak();
    let s = st.clone();
    ui.on_shop_use(move |id| {
        let Some(ui) = weak.upgrade() else { return };
        if s.borrow().lib.find(&id).is_some() {
            apply(&ui, &s, id.to_string());
        }
    });

    let s = st.clone();
    ui.on_shop_open(move |id| {
        if let Some(url) = workshop::item_page(&id, s.borrow().lib.steam) {
            sys::open_url(&url);
        }
    });

    let weak = ui.as_weak();
    let s = st.clone();
    ui.on_reset_screen(move || {
        let Some(ui) = weak.upgrade() else { return };
        if let Some(m) = scope_key(&ui, &s.borrow().monitors) {
            save(|c| {
                c.monitors.remove(&m);
            });
        }
        refresh(&ui, &s);
    });

    let weak = ui.as_weak();
    let s = st.clone();
    ui.on_scope_changed(move || {
        if let Some(ui) = weak.upgrade() {
            refresh(&ui, &s);
        }
    });

    let weak = ui.as_weak();
    let s = st.clone();
    ui.on_filter_changed(move || {
        if let Some(ui) = weak.upgrade() {
            refresh(&ui, &s);
        }
    });

    let weak = ui.as_weak();
    let s = st.clone();
    ui.on_mature_changed(move || {
        if let Some(ui) = weak.upgrade() {
            refresh(&ui, &s);
            load_thumbs(&ui, &s);
            show_shop(&ui, &s);
            load_shop_thumbs(&ui, &s);
        }
    });

    let weak = ui.as_weak();
    let s = st.clone();
    ui.on_settings_changed(move || {
        let Some(ui) = weak.upgrade() else { return };
        let (fs, bat, snd, auto, fps) = (
            ui.get_pause_fullscreen(),
            ui.get_pause_battery(),
            ui.get_sound(),
            ui.get_autostart(),
            ui.get_fps(),
        );
        save(|c| {
            c.pause_on_fullscreen = fs;
            c.pause_on_battery = bat;
            c.sound = snd;
            c.autostart = auto;
            c.fps = fps.clamp(5, 240) as u32;
        });
        refresh(&ui, &s);
    });

    let weak = ui.as_weak();
    let s = st.clone();
    ui.on_toggle_pause(move || {
        let Some(ui) = weak.upgrade() else { return };
        save(|c| c.paused = !c.paused);
        daemon::start_in_background();
        refresh(&ui, &s);
    });

    let weak = ui.as_weak();
    let s = st.clone();
    ui.on_start_service(move || {
        let Some(ui) = weak.upgrade() else { return };
        daemon::start_in_background();
        let weak = ui.as_weak();
        let s = s.clone();
        slint::Timer::single_shot(std::time::Duration::from_millis(800), move || {
            if let Some(ui) = weak.upgrade() {
                refresh(&ui, &s);
            }
        });
    });

    let weak = ui.as_weak();
    let s = st.clone();
    ui.on_rescan(move || {
        if let Some(ui) = weak.upgrade() {
            rescan(&ui, &s);
        }
    });

    let s = st.clone();
    ui.on_problem_clicked(move || {
        if let Some(p) = problem(engine::engine_path().is_some(), &s.borrow().lib) {
            if !p.url.is_empty() {
                sys::open_url(p.url);
            }
        }
    });

    let weak = ui.as_weak();
    let s = st.clone();
    let timer = slint::Timer::default();
    timer.start(
        slint::TimerMode::Repeated,
        std::time::Duration::from_secs(3),
        move || {
            if let Some(ui) = weak.upgrade() {
                let running = daemon::running();
                if running != ui.get_running() {
                    refresh(&ui, &s);
                }
                if !s.borrow().pending.is_empty() {
                    check_pending(&ui, &s);
                }
            }
        },
    );

    ui.run()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::library::Kind;

    fn item(title: &str, kind: Kind) -> Item {
        Item {
            key: "123".into(),
            dir: PathBuf::from("/x"),
            title: title.into(),
            kind,
            preview: None,
            mature: false,
            workshop: true,
        }
    }

    #[test]
    fn filtering() {
        let i = item("Fjord Night", Kind::Video);
        assert!(matches(&i, "all", ""));
        assert!(matches(&i, "video", "fjord"));
        assert!(matches(&i, "all", "123"));
        assert!(!matches(&i, "scene", ""));
        assert!(!matches(&i, "all", "rain"));
    }

    #[test]
    fn problems_in_order() {
        let mut lib = Library::default();
        assert!(problem(false, &lib).unwrap().title.contains("engine"));
        assert!(problem(true, &lib).unwrap().title.contains("Steam"));
        lib.steam = true;
        assert_eq!(problem(true, &lib).unwrap().url, STORE);
        lib.assets = Some(PathBuf::from("/a"));
        assert_eq!(problem(true, &lib).unwrap().url, WORKSHOP);
        lib.items.push(item("a", Kind::Scene));
        assert!(problem(true, &lib).is_none());
    }

    #[test]
    fn decodes_and_blurs_previews() {
        let dir = std::env::temp_dir().join(format!("kereru-thumb-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let p = dir.join("p.png");
        let mut img = image::RgbaImage::new(64, 36);
        for (x, _, px) in img.enumerate_pixels_mut() {
            *px = if x % 2 == 0 {
                image::Rgba([255, 255, 255, 255])
            } else {
                image::Rgba([0, 0, 0, 255])
            };
        }
        img.save(&p).unwrap();
        let (w, h, sharp) = decode(&p, false).unwrap();
        assert_eq!((w, h), (THUMB_W, THUMB_H));
        let (_, _, soft) = decode(&p, true).unwrap();
        let spread = |b: &[u8]| {
            let px: Vec<u8> = b.chunks(4).map(|c| c[0]).collect();
            px.iter().max().unwrap() - px.iter().min().unwrap()
        };
        assert!(spread(&soft) < spread(&sharp));
        std::fs::write(dir.join("bad.png"), b"nope").unwrap();
        assert!(decode(&dir.join("bad.png"), false).is_none());
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn shop_states() {
        assert_eq!(shop_state(true, true), "installed");
        assert_eq!(shop_state(false, true), "waiting");
        assert_eq!(shop_state(false, false), "get");
    }

    #[test]
    fn current_per_scope() {
        let c = Config::parse("wallpaper = 1\nmonitor.DP-1 = 2\n");
        assert_eq!(current_for(&c, None).as_deref(), Some("1"));
        assert_eq!(current_for(&c, Some("DP-1")).as_deref(), Some("2"));
        assert_eq!(current_for(&c, Some("DP-9")).as_deref(), Some("1"));
    }
}
