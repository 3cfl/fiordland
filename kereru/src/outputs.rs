use crate::config;
use std::process::{Command, Stdio};
use wayland_client::protocol::{wl_output, wl_registry};
use wayland_client::{Connection, Dispatch, QueueHandle};

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Monitor {
    pub name: String,
    pub label: String,
}

#[derive(Default)]
struct Out {
    name: Option<String>,
    description: Option<String>,
    make: String,
    model: String,
}

#[derive(Default)]
struct State {
    outputs: Vec<(u32, Out)>,
}

impl Dispatch<wl_registry::WlRegistry, ()> for State {
    fn event(
        state: &mut Self,
        registry: &wl_registry::WlRegistry,
        event: wl_registry::Event,
        _: &(),
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        if let wl_registry::Event::Global {
            name,
            interface,
            version,
        } = event
        {
            if interface == "wl_output"
                && version >= 4
                && state.outputs.len() < config::MAX_MONITORS
            {
                registry.bind::<wl_output::WlOutput, _, _>(name, 4, qh, name);
                state.outputs.push((name, Out::default()));
            }
        }
    }
}

impl Dispatch<wl_output::WlOutput, u32> for State {
    fn event(
        state: &mut Self,
        _: &wl_output::WlOutput,
        event: wl_output::Event,
        id: &u32,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        let Some((_, out)) = state.outputs.iter_mut().find(|(n, _)| n == id) else {
            return;
        };
        match event {
            wl_output::Event::Name { name } => out.name = Some(name),
            wl_output::Event::Description { description } => out.description = Some(description),
            wl_output::Event::Geometry { make, model, .. } => {
                out.make = make;
                out.model = model;
            }
            _ => {}
        }
    }
}

fn label(name: &str, make: &str, model: &str, description: Option<&str>) -> String {
    let pretty = [make, model]
        .iter()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty() && !s.eq_ignore_ascii_case("unknown"))
        .collect::<Vec<_>>()
        .join(" ");
    let pretty = if pretty.is_empty() {
        description.unwrap_or("").trim().to_string()
    } else {
        pretty
    };
    let pretty = crate::sys::clean_text(&pretty, 48);
    if pretty.is_empty() || pretty == name {
        name.to_string()
    } else {
        format!("{name} · {pretty}")
    }
}

fn wayland() -> Option<Vec<Monitor>> {
    std::env::var_os("WAYLAND_DISPLAY")?;
    let conn = Connection::connect_to_env().ok()?;
    let mut queue = conn.new_event_queue();
    let qh = queue.handle();
    conn.display().get_registry(&qh, ());
    let mut state = State::default();
    queue.roundtrip(&mut state).ok()?;
    queue.roundtrip(&mut state).ok()?;
    let mut list: Vec<Monitor> = state
        .outputs
        .into_iter()
        .filter_map(|(_, o)| {
            let name = o.name?;
            config::valid_monitor(&name).then(|| Monitor {
                label: label(&name, &o.make, &o.model, o.description.as_deref()),
                name,
            })
        })
        .collect();
    list.sort();
    list.dedup_by(|a, b| a.name == b.name);
    Some(list)
}

pub fn parse_xrandr(text: &str) -> Vec<Monitor> {
    let mut list: Vec<Monitor> = text
        .lines()
        .skip(1)
        .filter_map(|l| {
            let name = l.split_whitespace().last()?;
            config::valid_monitor(name).then(|| Monitor {
                name: name.to_string(),
                label: name.to_string(),
            })
        })
        .take(config::MAX_MONITORS)
        .collect();
    list.sort();
    list.dedup();
    list
}

fn x11() -> Option<Vec<Monitor>> {
    std::env::var_os("DISPLAY")?;
    let out = Command::new("/usr/bin/xrandr")
        .arg("--listactivemonitors")
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output()
        .ok()?;
    out.status
        .success()
        .then(|| parse_xrandr(&String::from_utf8_lossy(&out.stdout)))
}

pub fn list() -> Vec<Monitor> {
    wayland()
        .filter(|l| !l.is_empty())
        .or_else(x11)
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn xrandr_monitors() {
        let text = "Monitors: 2\n 0: +*eDP-1 1920/344x1080/194+0+0  eDP-1\n 1: +HDMI-1 2560/597x1440/336+1920+0  HDMI-1\n 2: +bad name 1/1x1/1+0+0  --evil\n";
        let names: Vec<_> = parse_xrandr(text).into_iter().map(|m| m.name).collect();
        assert_eq!(names, vec!["HDMI-1", "eDP-1"]);
    }

    #[test]
    fn labels() {
        assert_eq!(
            label("DP-1", "Dell Inc.", "U2720Q", None),
            "DP-1 · Dell Inc. U2720Q"
        );
        assert_eq!(
            label("Virtual-1", "Unknown", "Unknown", Some("")),
            "Virtual-1"
        );
        assert_eq!(label("HDMI-A-1", "", "", Some("LG TV")), "HDMI-A-1 · LG TV");
    }
}
