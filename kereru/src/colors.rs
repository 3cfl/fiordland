use crate::sys;
use image::DynamicImage;
use std::path::{Path, PathBuf};

pub const MAX_W: u32 = 320;
pub const MAX_H: u32 = 180;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Now {
    Playing {
        key: String,
        preview: Option<PathBuf>,
    },
    Idle,
}

impl Now {
    fn id(&self) -> Option<&str> {
        match self {
            Now::Playing { key, .. } => Some(key),
            Now::Idle => None,
        }
    }
}

pub fn playing_key<'a>(
    screens: &[(String, PathBuf)],
    key_for: impl Fn(&str) -> Option<&'a str>,
) -> Option<&'a str> {
    screens.first().and_then(|(mon, _)| key_for(mon))
}

pub fn limits() -> image::Limits {
    let mut limits = image::Limits::default();
    limits.max_image_width = Some(8192);
    limits.max_image_height = Some(8192);
    limits.max_alloc = Some(256 << 20);
    limits
}

pub fn open_image(path: &Path) -> Option<DynamicImage> {
    let mut reader = image::ImageReader::open(path)
        .ok()?
        .with_guessed_format()
        .ok()?;
    reader.limits(limits());
    reader.decode().ok()
}

pub fn fit(img: DynamicImage) -> DynamicImage {
    if img.width() > MAX_W || img.height() > MAX_H {
        img.resize(MAX_W, MAX_H, image::imageops::FilterType::Triangle)
    } else {
        img
    }
}

pub fn png(preview: &Path) -> Option<Vec<u8>> {
    let img = fit(open_image(preview)?).to_rgba8();
    let mut out = std::io::Cursor::new(Vec::new());
    img.write_to(&mut out, image::ImageFormat::Png).ok()?;
    Some(out.into_inner())
}

pub fn json(now: &Now, image: Option<&Path>) -> String {
    let v = match now {
        Now::Playing { key, .. } => {
            let mut m = serde_json::Map::new();
            m.insert("playing".into(), true.into());
            m.insert("key".into(), key.as_str().into());
            if let Some(p) = image {
                m.insert("image".into(), p.to_string_lossy().into_owned().into());
            }
            serde_json::Value::Object(m)
        }
        Now::Idle => serde_json::json!({ "playing": false }),
    };
    v.to_string()
}

pub fn dir() -> Option<PathBuf> {
    sys::state_home().map(|d| d.join("kereru"))
}

pub fn write_in(dir: &Path, now: &Now) -> anyhow::Result<()> {
    let image = match now {
        Now::Playing {
            preview: Some(p), ..
        } => png(p).and_then(|data| {
            let path = dir.join("colors.png");
            sys::write_private(&path, &data).ok().map(|_| path)
        }),
        _ => None,
    };
    sys::write_private(
        &dir.join("colors.json"),
        json(now, image.as_deref()).as_bytes(),
    )
}

pub struct Publisher {
    dir: Option<PathBuf>,
    last: Option<Option<String>>,
}

impl Publisher {
    pub fn new(dir: Option<PathBuf>) -> Publisher {
        Publisher { dir, last: None }
    }

    pub fn publish(&mut self, key: Option<&str>, preview: impl FnOnce(&str) -> Option<PathBuf>) {
        if self.last.as_ref().map(Option::as_deref) == Some(key) {
            return;
        }
        let now = match key {
            Some(k) => Now::Playing {
                key: k.to_string(),
                preview: preview(k),
            },
            None => Now::Idle,
        };
        self.write(&now);
    }

    fn write(&mut self, now: &Now) {
        let state = now.id().map(str::to_string);
        let Some(dir) = self.dir.as_deref() else {
            return;
        };
        if let Err(e) = write_in(dir, now) {
            eprintln!("kereru: couldn't write colors: {e:#}");
        }
        self.last = Some(state);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn scratch(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("kereru-colors-{}-{name}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        d
    }

    fn parse(s: &str) -> serde_json::Value {
        serde_json::from_str(s).unwrap()
    }

    #[test]
    fn json_when_playing() {
        let now = Now::Playing {
            key: "3645562838".into(),
            preview: None,
        };
        let v = parse(&json(
            &now,
            Some(Path::new("/home/u/.local/state/kereru/colors.png")),
        ));
        assert_eq!(
            v,
            serde_json::json!({
                "playing": true,
                "key": "3645562838",
                "image": "/home/u/.local/state/kereru/colors.png"
            })
        );
        let v = parse(&json(&now, None));
        assert_eq!(
            v,
            serde_json::json!({ "playing": true, "key": "3645562838" })
        );
    }

    #[test]
    fn json_when_idle() {
        assert_eq!(
            parse(&json(&Now::Idle, None)),
            serde_json::json!({ "playing": false })
        );
        assert_eq!(
            parse(&json(&Now::Idle, Some(Path::new("/x.png")))),
            serde_json::json!({ "playing": false })
        );
    }

    #[test]
    fn json_escapes_odd_keys() {
        let now = Now::Playing {
            key: "/home/u/walls/a \"b\"\n".into(),
            preview: None,
        };
        let v = parse(&json(&now, None));
        assert_eq!(v["key"], "/home/u/walls/a \"b\"\n");
    }

    #[test]
    fn writes_png_and_json() {
        let d = scratch("write");
        let preview = d.join("preview.jpg");
        image::RgbImage::from_pixel(1280, 720, image::Rgb([200, 40, 10]))
            .save(&preview)
            .unwrap();
        let out = d.join("state");
        let now = Now::Playing {
            key: "111".into(),
            preview: Some(preview),
        };
        write_in(&out, &now).unwrap();
        let v = parse(&std::fs::read_to_string(out.join("colors.json")).unwrap());
        assert_eq!(v["playing"], true);
        assert_eq!(
            v["image"],
            out.join("colors.png").to_string_lossy().as_ref()
        );
        let png = image::open(out.join("colors.png")).unwrap();
        assert_eq!((png.width(), png.height()), (320, 180));
        let px = png.to_rgb8().get_pixel(10, 10).0;
        assert!(px[0] > 180 && px[1] < 70 && px[2] < 40);
        use std::os::unix::fs::PermissionsExt;
        let mode = std::fs::metadata(out.join("colors.json"))
            .unwrap()
            .permissions()
            .mode();
        assert_eq!(mode & 0o077, 0);

        let broken = d.join("broken.png");
        std::fs::write(&broken, b"not an image").unwrap();
        let now = Now::Playing {
            key: "222".into(),
            preview: Some(broken),
        };
        write_in(&out, &now).unwrap();
        let v = parse(&std::fs::read_to_string(out.join("colors.json")).unwrap());
        assert_eq!(v, serde_json::json!({ "playing": true, "key": "222" }));

        write_in(&out, &Now::Idle).unwrap();
        let v = parse(&std::fs::read_to_string(out.join("colors.json")).unwrap());
        assert_eq!(v, serde_json::json!({ "playing": false }));
        let _ = std::fs::remove_dir_all(&d);
    }

    #[test]
    fn gif_uses_first_frame_and_keeps_aspect() {
        let d = scratch("gif");
        let path = d.join("preview.gif");
        {
            let f = std::fs::File::create(&path).unwrap();
            let mut enc = image::codecs::gif::GifEncoder::new(f);
            let red = image::RgbaImage::from_pixel(400, 400, image::Rgba([255, 0, 0, 255]));
            let blue = image::RgbaImage::from_pixel(400, 400, image::Rgba([0, 0, 255, 255]));
            enc.encode_frames([image::Frame::new(red), image::Frame::new(blue)])
                .unwrap();
        }
        let img = image::load_from_memory(&png(&path).unwrap()).unwrap();
        assert_eq!((img.width(), img.height()), (180, 180));
        let px = img.to_rgb8().get_pixel(90, 90).0;
        assert!(px[0] > 200 && px[2] < 50);
        let _ = std::fs::remove_dir_all(&d);
    }

    #[test]
    fn small_previews_are_not_enlarged() {
        let img = DynamicImage::new_rgb8(100, 50);
        let f = fit(img);
        assert_eq!((f.width(), f.height()), (100, 50));
        let f = fit(DynamicImage::new_rgb8(1000, 1000));
        assert_eq!((f.width(), f.height()), (180, 180));
    }

    #[test]
    fn publisher_writes_only_on_change() {
        let d = scratch("publish");
        let file = d.join("colors.json");
        let read = || parse(&std::fs::read_to_string(&file).unwrap());
        let mut p = Publisher::new(Some(d.clone()));
        let looked = std::cell::Cell::new(0);
        let none = |_: &str| {
            looked.set(looked.get() + 1);
            None
        };
        p.publish(Some("1"), none);
        assert_eq!(read(), serde_json::json!({ "playing": true, "key": "1" }));
        std::fs::write(&file, "{}").unwrap();
        p.publish(Some("1"), none);
        p.publish(Some("1"), none);
        assert_eq!(read(), serde_json::json!({}));
        assert_eq!(looked.get(), 1);
        p.publish(Some("2"), none);
        assert_eq!(read()["key"], "2");
        p.publish(None, none);
        assert_eq!(read(), serde_json::json!({ "playing": false }));
        std::fs::write(&file, "{}").unwrap();
        p.publish(None, none);
        assert_eq!(read(), serde_json::json!({}));
        p.publish(Some("2"), none);
        assert_eq!(read()["playing"], true);
        assert_eq!(looked.get(), 3);
        let _ = std::fs::remove_dir_all(&d);
    }

    #[test]
    fn first_screen_decides_the_key() {
        let screens = vec![
            ("DP-1".to_string(), PathBuf::from("/a")),
            ("DP-2".to_string(), PathBuf::from("/b")),
        ];
        let key_for = |m: &str| {
            if m == "DP-1" {
                Some("111")
            } else {
                Some("222")
            }
        };
        assert_eq!(playing_key(&screens, key_for), Some("111"));
        assert_eq!(playing_key(&[], key_for), None);
    }

    #[test]
    fn publisher_without_a_state_dir_does_nothing() {
        let mut p = Publisher::new(None);
        p.publish(Some("1"), |_| None);
        assert!(p.last.is_none());
    }
}
