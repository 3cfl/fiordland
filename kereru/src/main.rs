mod config;
mod daemon;
mod engine;
mod library;
mod outputs;
mod picker;
mod sys;
mod workshop;

use config::Config;

slint::include_modules!();

const USAGE: &str = "usage: kereru [--tray | --autostart | --pause | --resume | --toggle | --next | --status | --version]";

fn change(f: impl FnOnce(&mut Config)) -> anyhow::Result<()> {
    Config::update(f)?;
    Ok(())
}

fn status() {
    let cfg = Config::load();
    let lib = library::scan();
    let name = |k: &str| {
        if lib.unsupported(k) {
            format!("{} ({})", lib.title(k), library::WEB_NOTE)
        } else {
            lib.title(k)
        }
    };
    let pick = cfg
        .wallpaper
        .as_deref()
        .map(name)
        .unwrap_or_else(|| "none".into());
    println!("wallpaper: {pick}");
    for (m, k) in &cfg.monitors {
        println!("  {m}: {}", name(k));
    }
    println!("running: {}", if daemon::running() { "yes" } else { "no" });
    println!("paused: {}", if cfg.paused { "yes" } else { "no" });
    println!("library: {} wallpapers", lib.items.len());
    println!(
        "wallpaper engine assets: {}",
        lib.assets
            .as_ref()
            .map(|p| p.display().to_string())
            .unwrap_or_else(|| "not found".into())
    );
}

fn main() -> anyhow::Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.len() > 1 {
        eprintln!("{USAGE}");
        std::process::exit(2);
    }
    match args.first().map(String::as_str) {
        None => picker::run(),
        Some("--tray") => daemon::run(false),
        Some("--autostart") => daemon::run(true),
        Some("--pause") => change(|c| c.paused = true),
        Some("--resume") => change(|c| c.paused = false),
        Some("--toggle") => change(|c| c.paused = !c.paused),
        Some("--next") => {
            let lib = library::scan();
            let cfg = Config::load();
            match lib.next_after(cfg.wallpaper.as_deref()) {
                Some(item) => {
                    let key = item.key.clone();
                    change(|c| {
                        c.wallpaper = Some(key);
                        c.monitors.clear();
                    })
                }
                None => {
                    eprintln!("kereru: no wallpapers found");
                    std::process::exit(1);
                }
            }
        }
        Some("--status") => {
            status();
            Ok(())
        }
        Some("--version") | Some("-V") => {
            println!("kereru {}", env!("CARGO_PKG_VERSION"));
            Ok(())
        }
        Some("--help") | Some("-h") => {
            println!("{USAGE}");
            Ok(())
        }
        Some(other) => {
            eprintln!("kereru: unknown option {other}\n{USAGE}");
            std::process::exit(2);
        }
    }
}
