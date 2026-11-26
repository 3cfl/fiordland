use crate::engine::Plan;
use crate::outputs::Monitor;
use crate::sys;
use std::collections::{HashMap, HashSet};
use std::ffi::OsString;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

const SLACK: f64 = 1.3;
const LIMIT: Duration = Duration::from_secs(30 * 60);
const BWRAP: &str = "/usr/bin/bwrap";
const NICE: &str = "/usr/bin/nice";
const OUT_FILE: &str = "scaled.mp4";

#[derive(Clone, Debug, PartialEq)]
struct Video {
    file: String,
    width: u32,
    height: u32,
}

#[derive(Default)]
pub struct Scaler {
    probes: HashMap<PathBuf, Option<Video>>,
    running: Arc<Mutex<HashSet<PathBuf>>>,
}

impl Scaler {
    pub fn apply(&mut self, plan: &mut Plan, monitors: &[Monitor]) {
        if !tools_present() {
            return;
        }
        for (mon, dir) in plan.screens.iter_mut() {
            let Some(size) = monitors
                .iter()
                .find(|m| &m.name == mon)
                .and_then(|m| m.size)
            else {
                continue;
            };
            let video = self
                .probes
                .entry(dir.clone())
                .or_insert_with(|| probe(dir))
                .clone();
            let Some(video) = video else {
                continue;
            };
            if !oversized((video.width, video.height), size) {
                continue;
            }
            let Some(out) = cache_dir(dir, &video, size) else {
                continue;
            };
            if out.join("project.json").is_file() {
                *dir = out;
                continue;
            }
            if failed_marker(&out).exists() {
                continue;
            }
            self.spawn(dir.clone(), video, size, out);
        }
    }

    fn spawn(&self, src: PathBuf, video: Video, size: (u32, u32), out: PathBuf) {
        {
            let mut running = self.running.lock().unwrap_or_else(|e| e.into_inner());
            if !running.insert(out.clone()) {
                return;
            }
        }
        let running = Arc::clone(&self.running);
        std::thread::spawn(move || {
            if build(&src, &video, size, &out).is_err() {
                let _ = std::fs::write(failed_marker(&out), b"");
            }
            running
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .remove(&out);
        });
    }
}

fn tools_present() -> bool {
    [BWRAP, NICE, "/usr/bin/ffmpeg", "/usr/bin/ffprobe"]
        .iter()
        .all(|p| Path::new(p).is_file())
}

pub fn oversized(video: (u32, u32), screen: (u32, u32)) -> bool {
    let v = video.0 as f64 * video.1 as f64;
    let s = screen.0 as f64 * screen.1 as f64;
    if s <= 0.0 || v <= s * SLACK {
        return false;
    }
    let t = target(video, screen);
    t.0 < video.0 && t.1 < video.1
}

pub fn target(video: (u32, u32), screen: (u32, u32)) -> (u32, u32) {
    let f = (screen.0 as f64 / video.0 as f64).max(screen.1 as f64 / video.1 as f64);
    let even = |x: f64| ((x / 2.0).round() as u32 * 2).max(2);
    (even(video.0 as f64 * f), even(video.1 as f64 * f))
}

fn valid_file(f: &str) -> bool {
    !f.is_empty() && f.len() < 256 && !f.contains('/') && !f.contains('\0') && f != "." && f != ".."
}

fn project(dir: &Path) -> Option<serde_json::Value> {
    let text = sys::read_limited(&dir.join("project.json"), 1 << 20)?;
    serde_json::from_str(&text).ok()
}

fn probe(dir: &Path) -> Option<Video> {
    let p = project(dir)?;
    let kind = p.get("type")?.as_str()?;
    if !kind.eq_ignore_ascii_case("video") {
        return None;
    }
    let file = p.get("file")?.as_str()?.to_string();
    if !valid_file(&file) {
        return None;
    }
    let path = dir.join(&file);
    if !path.is_file() {
        return None;
    }
    let mut cmd = sandboxed(dir, None);
    cmd.args([
        "/usr/bin/ffprobe",
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=width,height",
        "-of",
        "csv=p=0",
    ])
    .arg(&path);
    let out = cmd
        .stderr(Stdio::null())
        .stdin(Stdio::null())
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    let (width, height) = parse_dims(&String::from_utf8_lossy(&out.stdout))?;
    Some(Video {
        file,
        width,
        height,
    })
}

pub fn parse_dims(s: &str) -> Option<(u32, u32)> {
    let line = s.lines().find(|l| !l.trim().is_empty())?;
    let mut it = line.trim().trim_end_matches(',').split(',');
    let w: u32 = it.next()?.trim().parse().ok()?;
    let h: u32 = it.next()?.trim().parse().ok()?;
    (w > 0 && h > 0 && w <= 16384 && h <= 16384).then_some((w, h))
}

fn fnv(data: &[u8]) -> u64 {
    data.iter().fold(0xcbf29ce484222325u64, |h, b| {
        (h ^ *b as u64).wrapping_mul(0x100000001b3)
    })
}

fn cache_dir(dir: &Path, video: &Video, size: (u32, u32)) -> Option<PathBuf> {
    let meta = std::fs::metadata(dir.join(&video.file)).ok()?;
    let mtime = meta
        .modified()
        .ok()?
        .duration_since(std::time::UNIX_EPOCH)
        .ok()?
        .as_secs();
    let id = format!("{}|{}|{}|{}", dir.display(), video.file, meta.len(), mtime);
    let root = sys::cache_home()?.join("kereru").join("scaled");
    Some(root.join(format!("{:016x}-{}x{}", fnv(id.as_bytes()), size.0, size.1)))
}

fn failed_marker(out: &Path) -> PathBuf {
    let mut s: OsString = out.as_os_str().to_owned();
    s.push(".failed");
    PathBuf::from(s)
}

fn render_node() -> Option<PathBuf> {
    let mut nodes: Vec<PathBuf> = std::fs::read_dir("/dev/dri")
        .ok()?
        .flatten()
        .map(|e| e.path())
        .filter(|p| {
            p.file_name()
                .and_then(|n| n.to_str())
                .is_some_and(|n| n.starts_with("renderD"))
        })
        .collect();
    nodes.sort();
    nodes.into_iter().next()
}

fn sandboxed(src: &Path, out: Option<&Path>) -> Command {
    let mut c = Command::new(NICE);
    c.env_clear().env("PATH", sys::SAFE_PATH);
    c.args(["-n", "19", BWRAP]);
    c.args([
        "--unshare-all",
        "--die-with-parent",
        "--new-session",
        "--cap-drop",
        "ALL",
        "--clearenv",
        "--setenv",
        "PATH",
        "/usr/bin",
        "--ro-bind",
        "/usr",
        "/usr",
        "--symlink",
        "usr/bin",
        "/bin",
        "--symlink",
        "usr/lib",
        "/lib",
        "--symlink",
        "usr/lib",
        "/lib64",
        "--ro-bind-try",
        "/etc/ld.so.cache",
        "/etc/ld.so.cache",
        "--proc",
        "/proc",
        "--dev",
        "/dev",
        "--dev-bind-try",
        "/dev/dri",
        "/dev/dri",
        "--ro-bind-try",
        "/sys",
        "/sys",
        "--tmpfs",
        "/tmp",
        "--ro-bind",
    ]);
    c.arg(src).arg(src);
    if let Some(o) = out {
        c.arg("--bind").arg(o).arg(o);
    }
    c.arg("--");
    c
}

fn encode_args(
    node: Option<&Path>,
    input: &Path,
    output: &Path,
    dims: (u32, u32),
) -> Vec<OsString> {
    let mut a: Vec<OsString> = vec![
        "/usr/bin/ffmpeg".into(),
        "-nostdin".into(),
        "-v".into(),
        "error".into(),
        "-y".into(),
    ];
    if let Some(n) = node {
        a.push("-vaapi_device".into());
        a.push(n.into());
    }
    a.push("-i".into());
    a.push(input.into());
    a.extend(["-map", "0:v:0", "-map", "0:a?", "-c:a", "copy"].map(OsString::from));
    match node {
        Some(_) => {
            a.push("-vf".into());
            a.push(format!("format=nv12,hwupload,scale_vaapi=w={}:h={}", dims.0, dims.1).into());
            a.extend(["-c:v", "h264_vaapi", "-qp", "20"].map(OsString::from));
        }
        None => {
            a.push("-vf".into());
            a.push(format!("scale={}:{}", dims.0, dims.1).into());
            a.extend(["-c:v", "libx264", "-preset", "veryfast", "-crf", "20"].map(OsString::from));
        }
    }
    a.extend(["-movflags", "+faststart", "-f", "mp4"].map(OsString::from));
    a.push(output.into());
    a
}

fn run_limited(mut cmd: Command) -> bool {
    let Ok(mut child) = cmd
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
    else {
        return false;
    };
    let start = Instant::now();
    loop {
        match child.try_wait() {
            Ok(Some(st)) => return st.success(),
            Ok(None) if start.elapsed() < LIMIT => std::thread::sleep(Duration::from_millis(500)),
            _ => {
                let _ = child.kill();
                let _ = child.wait();
                return false;
            }
        }
    }
}

fn build(src: &Path, video: &Video, size: (u32, u32), out: &Path) -> anyhow::Result<()> {
    let parent = out.parent().ok_or_else(|| anyhow::anyhow!("no parent"))?;
    std::fs::create_dir_all(parent)?;
    let mut tmp_name: OsString = out.as_os_str().to_owned();
    tmp_name.push(".tmp");
    let tmp = PathBuf::from(tmp_name);
    let _ = std::fs::remove_dir_all(&tmp);
    std::fs::create_dir_all(&tmp)?;
    let dims = target((video.width, video.height), size);
    let input = src.join(&video.file);
    let output = tmp.join(OUT_FILE);
    let node = render_node();
    let mut ok = false;
    if let Some(n) = node.as_deref() {
        let mut cmd = sandboxed(src, Some(&tmp));
        cmd.args(encode_args(Some(n), &input, &output, dims));
        ok = run_limited(cmd);
    }
    if !ok {
        let mut cmd = sandboxed(src, Some(&tmp));
        cmd.args(encode_args(None, &input, &output, dims));
        ok = run_limited(cmd);
    }
    if !ok || std::fs::metadata(&output).map(|m| m.len()).unwrap_or(0) == 0 {
        let _ = std::fs::remove_dir_all(&tmp);
        anyhow::bail!("encode failed");
    }
    let mut p = project(src).ok_or_else(|| anyhow::anyhow!("project.json"))?;
    if let Some(prev) = p
        .get("preview")
        .and_then(|v| v.as_str())
        .filter(|f| valid_file(f))
    {
        let _ = std::fs::copy(src.join(prev), tmp.join(prev));
    }
    p["file"] = serde_json::Value::String(OUT_FILE.into());
    std::fs::write(tmp.join("project.json"), serde_json::to_vec(&p)?)?;
    let _ = std::fs::remove_dir_all(out);
    std::fs::rename(&tmp, out)?;
    prune(parent, out);
    Ok(())
}

fn prune(root: &Path, keep: &Path) {
    let Ok(entries) = std::fs::read_dir(root) else {
        return;
    };
    let mut dirs: Vec<(std::time::SystemTime, PathBuf)> = entries
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.is_dir() && p != keep && p.extension().is_none())
        .filter_map(|p| Some((std::fs::metadata(&p).ok()?.modified().ok()?, p)))
        .collect();
    dirs.sort();
    while dirs.len() > 7 {
        let (_, p) = dirs.remove(0);
        let _ = std::fs::remove_dir_all(p);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_clearly_bigger_videos_get_scaled() {
        assert!(oversized((3686, 2074), (1920, 1080)));
        assert!(!oversized((1920, 1080), (1920, 1080)));
        assert!(!oversized((2048, 1152), (1920, 1080)));
        assert!(!oversized((3840, 2160), (3840, 2160)));
        assert!(!oversized((3840, 2160), (0, 0)));
    }

    #[test]
    fn target_covers_screen_with_even_dims() {
        assert_eq!(target((3686, 2074), (1920, 1080)), (1920, 1080));
        assert_eq!(target((3840, 1600), (1920, 1080)), (2592, 1080));
        assert!(!oversized((1081, 3001), (1920, 1080)));
        let (w, h) = target((3001, 1999), (1366, 768));
        assert!(w % 2 == 0 && h % 2 == 0 && w >= 1366 && h >= 768);
    }

    #[test]
    fn dims_parse_and_reject_junk() {
        assert_eq!(parse_dims("3686,2074\n"), Some((3686, 2074)));
        assert_eq!(parse_dims("1920,1080,\n"), Some((1920, 1080)));
        assert_eq!(parse_dims("0,1080"), None);
        assert_eq!(parse_dims("abc"), None);
        assert_eq!(parse_dims("99999,1"), None);
    }

    #[test]
    fn file_names_cannot_escape() {
        assert!(valid_file("25B28(1).mp4"));
        assert!(!valid_file("../x.mp4"));
        assert!(!valid_file("a/b.mp4"));
        assert!(!valid_file(".."));
        assert!(!valid_file(""));
    }
}
