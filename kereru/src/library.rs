use crate::{config, sys};
use serde::Deserialize;
use std::collections::BTreeSet;
use std::os::unix::fs::MetadataExt;
use std::path::{Component, Path, PathBuf};

pub const APP_ID: &str = "431960";
const PROJECT_LIMIT: u64 = 1 << 20;
const VDF_LIMIT: u64 = 256 * 1024;
const PREVIEW_LIMIT: u64 = 32 << 20;
const MAX_ITEMS: usize = 2000;
const MAX_LIBRARIES: usize = 32;
pub const WEB_NOTE: &str = "Web wallpapers aren't supported yet";

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum Kind {
    Scene,
    Video,
    Web,
}

impl Kind {
    pub fn parse(v: &str) -> Option<Kind> {
        match v.to_ascii_lowercase().as_str() {
            "scene" => Some(Kind::Scene),
            "video" => Some(Kind::Video),
            "web" => Some(Kind::Web),
            _ => None,
        }
    }

    pub fn playable(self) -> bool {
        matches!(self, Kind::Scene | Kind::Video)
    }

    pub fn label(self) -> &'static str {
        match self {
            Kind::Scene => "scene",
            Kind::Video => "video",
            Kind::Web => "web",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Item {
    pub key: String,
    pub dir: PathBuf,
    pub title: String,
    pub kind: Kind,
    pub preview: Option<PathBuf>,
    pub mature: bool,
    pub workshop: bool,
}

#[derive(Clone, Debug, Default)]
pub struct Library {
    pub items: Vec<Item>,
    pub assets: Option<PathBuf>,
    pub steam: bool,
    pub skipped: usize,
}

#[derive(Deserialize)]
struct Project {
    title: Option<serde_json::Value>,
    #[serde(rename = "type")]
    kind: Option<String>,
    preview: Option<String>,
    contentrating: Option<String>,
}

fn steam_roots(home: &Path) -> Vec<PathBuf> {
    [
        ".local/share/Steam",
        ".steam/steam",
        ".steam/root",
        ".var/app/com.valvesoftware.Steam/.local/share/Steam",
        "snap/steam/common/.local/share/Steam",
    ]
    .iter()
    .map(|r| home.join(r))
    .collect()
}

pub fn vdf_paths(text: &str) -> Vec<PathBuf> {
    let mut out = Vec::new();
    for line in text.lines() {
        let mut parts = Vec::new();
        let mut rest = line.trim();
        while let Some(start) = rest.find('"') {
            let after = &rest[start + 1..];
            let mut value = String::new();
            let mut end = None;
            let mut chars = after.char_indices();
            while let Some((i, c)) = chars.next() {
                match c {
                    '\\' => {
                        if let Some((_, n)) = chars.next() {
                            value.push(n);
                        }
                    }
                    '"' => {
                        end = Some(i);
                        break;
                    }
                    _ => value.push(c),
                }
            }
            let Some(e) = end else {
                break;
            };
            parts.push(value);
            rest = &after[e + 1..];
        }
        if parts.len() == 2 && parts[0].eq_ignore_ascii_case("path") {
            let p = PathBuf::from(&parts[1]);
            if p.is_absolute() && !parts[1].chars().any(char::is_control) {
                out.push(p);
            }
        }
    }
    out
}

pub fn libraries(home: &Path) -> Vec<PathBuf> {
    let mut seen = BTreeSet::new();
    let mut out = Vec::new();
    let mut add = |p: PathBuf, out: &mut Vec<PathBuf>| {
        if out.len() >= MAX_LIBRARIES {
            return;
        }
        if let Ok(real) = std::fs::canonicalize(&p) {
            if real.join("steamapps").is_dir() && seen.insert(real.clone()) {
                out.push(real);
            }
        }
    };
    for root in steam_roots(home) {
        add(root.clone(), &mut out);
        for f in ["steamapps/libraryfolders.vdf", "config/libraryfolders.vdf"] {
            if let Some(text) = sys::read_limited(&root.join(f), VDF_LIMIT) {
                for p in vdf_paths(&text) {
                    add(p, &mut out);
                }
            }
        }
    }
    out
}

fn plain_file(dir: &Path, name: &str) -> Option<PathBuf> {
    let rel = Path::new(name);
    let mut comps = rel.components();
    let only = matches!(comps.next(), Some(Component::Normal(_))) && comps.next().is_none();
    if !only || name.chars().any(char::is_control) {
        return None;
    }
    let p = dir.join(rel);
    let meta = std::fs::symlink_metadata(&p).ok()?;
    (meta.is_file() && meta.len() <= PREVIEW_LIMIT).then_some(p)
}

fn title_of(v: Option<&serde_json::Value>) -> Option<String> {
    let s = match v? {
        serde_json::Value::String(s) => s.clone(),
        serde_json::Value::Number(n) => n.to_string(),
        _ => return None,
    };
    let t = sys::clean_text(&s, 120);
    (!t.is_empty()).then_some(t)
}

pub fn read_item(dir: &Path, workshop: bool) -> Option<Item> {
    let meta = std::fs::symlink_metadata(dir).ok()?;
    if !meta.is_dir() {
        return None;
    }
    let name = dir.file_name()?.to_str()?.to_string();
    let text = sys::read_limited(&dir.join("project.json"), PROJECT_LIMIT)?;
    let p: Project = serde_json::from_str(text.trim_start_matches('\u{feff}')).ok()?;
    let kind = Kind::parse(p.kind.as_deref()?)?;
    let key = if workshop && config::valid_workshop_id(&name) {
        name.clone()
    } else {
        dir.to_str()?.to_string()
    };
    if !config::valid_wallpaper(&key) {
        return None;
    }
    Some(Item {
        key,
        title: title_of(p.title.as_ref()).unwrap_or_else(|| sys::clean_text(&name, 120)),
        kind,
        preview: p.preview.as_deref().and_then(|f| plain_file(dir, f)),
        mature: p.contentrating.as_deref().is_some_and(|r| {
            r.eq_ignore_ascii_case("mature") || r.eq_ignore_ascii_case("questionable")
        }),
        dir: dir.to_path_buf(),
        workshop,
    })
}

fn scan_dir(dir: &Path, workshop: bool, lib: &mut Library, seen: &mut BTreeSet<String>) {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    let mut dirs: Vec<PathBuf> = entries.flatten().map(|e| e.path()).collect();
    dirs.sort();
    for d in dirs {
        if lib.items.len() >= MAX_ITEMS {
            return;
        }
        match read_item(&d, workshop) {
            Some(item) => {
                if seen.insert(item.key.clone()) {
                    lib.items.push(item);
                }
            }
            None => lib.skipped += 1,
        }
    }
}

fn owned_by_user(p: &Path) -> bool {
    std::fs::metadata(p).is_ok_and(|m| m.uid() == sys::euid() || m.uid() == 0)
}

pub fn scan_home(home: &Path, data: Option<&Path>) -> Library {
    let mut lib = Library::default();
    let mut seen = BTreeSet::new();
    for root in libraries(home) {
        lib.steam = true;
        let apps = root.join("steamapps");
        let we = apps.join("common").join("wallpaper_engine");
        let assets = we.join("assets");
        if lib.assets.is_none() && assets.is_dir() && owned_by_user(&assets) {
            lib.assets = Some(assets);
        }
        scan_dir(
            &apps.join("workshop").join("content").join(APP_ID),
            true,
            &mut lib,
            &mut seen,
        );
        scan_dir(
            &we.join("projects").join("myprojects"),
            false,
            &mut lib,
            &mut seen,
        );
        scan_dir(
            &we.join("projects").join("defaultprojects"),
            false,
            &mut lib,
            &mut seen,
        );
    }
    if let Some(data) = data {
        scan_dir(
            &data.join("kereru").join("wallpapers"),
            false,
            &mut lib,
            &mut seen,
        );
    }
    lib.items.sort_by(|a, b| {
        a.title
            .to_lowercase()
            .cmp(&b.title.to_lowercase())
            .then(a.key.cmp(&b.key))
    });
    lib
}

pub fn scan() -> Library {
    match sys::home() {
        Some(h) => scan_home(&h, sys::data_home().as_deref()),
        None => Library::default(),
    }
}

pub fn arrived_in(home: &Path, id: &str) -> bool {
    config::valid_workshop_id(id)
        && libraries(home).iter().any(|root| {
            let dir = root
                .join("steamapps")
                .join("workshop")
                .join("content")
                .join(APP_ID)
                .join(id);
            read_item(&dir, true).is_some()
        })
}

pub fn arrived(id: &str) -> bool {
    sys::home().is_some_and(|h| arrived_in(&h, id))
}

impl Library {
    pub fn find(&self, key: &str) -> Option<&Item> {
        self.items.iter().find(|i| i.key == key)
    }

    pub fn current(&self, key: &str) -> Option<Item> {
        match self.find(key) {
            Some(i) => read_item(&i.dir, i.workshop),
            None if config::valid_workshop_id(key) => None,
            None => read_item(Path::new(key), false),
        }
    }

    pub fn resolve(&self, key: &str) -> Option<PathBuf> {
        self.current(key)
            .filter(|i| i.kind.playable())
            .map(|i| i.dir)
    }

    pub fn unsupported(&self, key: &str) -> bool {
        self.current(key).is_some_and(|i| !i.kind.playable())
    }

    pub fn playable(&self) -> impl Iterator<Item = &Item> {
        self.items.iter().filter(|i| i.kind.playable())
    }

    pub fn title(&self, key: &str) -> String {
        self.find(key)
            .map(|i| i.title.clone())
            .unwrap_or_else(|| sys::clean_text(key, 60))
    }

    pub fn next_after(&self, key: Option<&str>) -> Option<&Item> {
        let n = self.items.len();
        let start = key
            .and_then(|k| self.items.iter().position(|i| i.key == k))
            .map_or(0, |p| p + 1);
        (0..n)
            .map(|o| &self.items[(start + o) % n])
            .find(|i| i.kind.playable())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn scratch(tag: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("kereru-lib-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        d
    }

    fn project(dir: &Path, json: &str) {
        std::fs::create_dir_all(dir).unwrap();
        std::fs::write(dir.join("project.json"), json).unwrap();
    }

    #[test]
    fn parses_library_folders() {
        let text = "\"libraryfolders\"\n{\n\t\"0\"\n\t{\n\t\t\"path\"\t\t\"/home/k/.local/share/Steam\"\n\t}\n\t\"1\"\n\t{\n\t\t\"path\"\t\t\"/mnt/games/Steam \\\"Library\\\"\"\n\t\t\"label\"\t\t\"\"\n\t}\n\t\"2\" { \"path\" \"relative/nope\" }\n}\n";
        assert_eq!(
            vdf_paths(text),
            vec![
                PathBuf::from("/home/k/.local/share/Steam"),
                PathBuf::from("/mnt/games/Steam \"Library\"")
            ]
        );
    }

    #[test]
    fn scans_workshop_and_skips_broken_items() {
        let home = scratch("scan");
        let steam = home.join(".local/share/Steam");
        let ws = steam.join("steamapps/workshop/content/431960");
        project(
            &ws.join("111"),
            r#"{"title":"Fjord at night","type":"Scene","preview":"preview.gif","contentrating":"Everyone"}"#,
        );
        std::fs::write(ws.join("111/preview.gif"), b"GIF89a").unwrap();
        project(
            &ws.join("222"),
            r#"{"title":"Rain","type":"video","preview":"../../../../etc/passwd"}"#,
        );
        project(
            &ws.join("333"),
            r#"{"title":"Some app","type":"application"}"#,
        );
        std::fs::create_dir_all(ws.join("444")).unwrap();
        project(&ws.join("555"), "not json");
        project(
            &steam.join("steamapps/common/wallpaper_engine/projects/defaultprojects/clouds"),
            r#"{"title":"Clouds","type":"web","contentrating":"Mature"}"#,
        );
        std::fs::create_dir_all(steam.join("steamapps/common/wallpaper_engine/assets")).unwrap();
        assert!(arrived_in(&home, "111"));
        assert!(!arrived_in(&home, "333"));
        assert!(!arrived_in(&home, "444"));
        assert!(!arrived_in(&home, "999"));
        assert!(!arrived_in(&home, "../111"));
        let lib = scan_home(&home, None);
        let keys: Vec<_> = lib.items.iter().map(|i| i.title.as_str()).collect();
        assert_eq!(keys, vec!["Clouds", "Fjord at night", "Rain"]);
        assert_eq!(lib.skipped, 3);
        assert!(lib.assets.is_some());
        let fjord = lib.find("111").unwrap();
        assert_eq!(fjord.kind, Kind::Scene);
        assert!(fjord.preview.is_some());
        assert!(!fjord.mature);
        assert!(lib.find("222").unwrap().preview.is_none());
        let clouds = lib.items.iter().find(|i| i.title == "Clouds").unwrap();
        assert!(clouds.key.starts_with('/'));
        assert!(clouds.mature);
        assert_eq!(lib.resolve("111"), Some(fjord.dir.clone()));
        assert_eq!(lib.resolve("999"), None);
        assert_eq!(lib.next_after(Some("222")).unwrap().title, "Fjord at night");
        assert_eq!(lib.next_after(None).unwrap().title, "Fjord at night");
        assert_eq!(lib.resolve(&clouds.key), None);
        assert!(lib.unsupported(&clouds.key));
        assert!(!lib.unsupported("111"));
        assert_eq!(lib.playable().count(), 2);
        project(
            &ws.join("111"),
            r#"{"title":"Fjord at night","type":"web"}"#,
        );
        assert_eq!(lib.resolve("111"), None);
        assert!(lib.unsupported("111"));
        let _ = std::fs::remove_dir_all(&home);
    }

    #[test]
    fn preview_must_be_a_plain_file_in_the_item() {
        let d = scratch("preview");
        std::fs::write(d.join("p.jpg"), b"x").unwrap();
        assert!(plain_file(&d, "p.jpg").is_some());
        assert!(plain_file(&d, "../p.jpg").is_none());
        assert!(plain_file(&d, "/etc/passwd").is_none());
        assert!(plain_file(&d, "sub/p.jpg").is_none());
        assert!(plain_file(&d, "missing.jpg").is_none());
        std::os::unix::fs::symlink("/etc/hostname", d.join("link.jpg")).unwrap();
        assert!(plain_file(&d, "link.jpg").is_none());
        let _ = std::fs::remove_dir_all(&d);
    }

    #[test]
    fn numeric_titles_and_bom() {
        let d = scratch("bom");
        project(&d.join("42"), "\u{feff}{\"title\":2077,\"type\":\"video\"}");
        let i = read_item(&d.join("42"), true).unwrap();
        assert_eq!(i.title, "2077");
        assert_eq!(i.key, "42");
        let _ = std::fs::remove_dir_all(&d);
    }
}
