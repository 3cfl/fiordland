use crate::library::{Kind, APP_ID};
use crate::sys;
use anyhow::{bail, Context, Result};
use std::collections::BTreeSet;
use std::time::Duration;

const BROWSE: &str = "https://steamcommunity.com/workshop/browse/";
const DETAILS: &str =
    "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/";
const PAGE_LIMIT: u64 = 4 << 20;
const DETAILS_LIMIT: u64 = 2 << 20;
const PREVIEW_LIMIT: u64 = 8 << 20;
const PER_PAGE: usize = 30;
const IMAGE_HOSTS: [&str; 4] = [
    "images.steamusercontent.com",
    "steamuserimages-a.akamaihd.net",
    "shared.akamai.steamstatic.com",
    "shared.fastly.steamstatic.com",
];

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Sort {
    Popular,
    Top,
    New,
}

impl Sort {
    pub fn parse(s: &str) -> Sort {
        match s {
            "top" => Sort::Top,
            "new" => Sort::New,
            _ => Sort::Popular,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Query {
    pub text: String,
    pub sort: Sort,
    pub kind: Option<Kind>,
    pub page: u32,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Entry {
    pub id: String,
    pub title: String,
    pub kind: Kind,
    pub preview: Option<String>,
    pub mature: bool,
    pub subscriptions: u64,
}

fn agent() -> ureq::Agent {
    ureq::Agent::config_builder()
        .https_only(true)
        .timeout_global(Some(Duration::from_secs(20)))
        .max_redirects(3)
        .user_agent(concat!("kereru/", env!("CARGO_PKG_VERSION")))
        .build()
        .into()
}

fn encode(s: &str) -> String {
    let mut out = String::new();
    for b in s.bytes() {
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') {
            out.push(b as char);
        } else {
            out.push_str(&format!("%{b:02X}"));
        }
    }
    out
}

fn tag_for(kind: Kind) -> &'static str {
    match kind {
        Kind::Scene => "Scene",
        Kind::Video => "Video",
        Kind::Web => "Web",
    }
}

pub fn browse_url(q: &Query) -> String {
    let text = sys::clean_text(&q.text, 100);
    let mut url = format!(
        "{BROWSE}?appid={APP_ID}&section=readytouseitems&p={}",
        q.page.clamp(1, 1000)
    );
    if !text.is_empty() {
        url.push_str("&browsesort=textsearch&searchtext=");
        url.push_str(&encode(&text));
    } else {
        url.push_str(match q.sort {
            Sort::Popular => "&browsesort=trend&days=7",
            Sort::Top => "&browsesort=totaluniquesubscribers",
            Sort::New => "&browsesort=mostrecent",
        });
    }
    if let Some(k) = q.kind {
        url.push_str("&requiredtags%5B%5D=");
        url.push_str(tag_for(k));
    }
    url
}

pub fn parse_ids(html: &str) -> Vec<String> {
    const MARK: &str = "sharedfiles/filedetails/?id=";
    let mut seen = BTreeSet::new();
    let mut out = Vec::new();
    let mut rest = html;
    while let Some(at) = rest.find(MARK) {
        rest = &rest[at + MARK.len()..];
        let id: String = rest.chars().take_while(char::is_ascii_digit).collect();
        if (1..=20).contains(&id.len()) && seen.insert(id.clone()) {
            out.push(id);
            if out.len() >= PER_PAGE {
                break;
            }
        }
    }
    out
}

pub fn image_url_ok(url: &str) -> bool {
    let Some(rest) = url.strip_prefix("https://") else {
        return false;
    };
    let host = rest.split(['/', '?', '#']).next().unwrap_or("");
    IMAGE_HOSTS.contains(&host) && !url.chars().any(|c| c.is_control() || c.is_whitespace())
}

fn number(v: &serde_json::Value) -> u64 {
    match v {
        serde_json::Value::Number(n) => n.as_u64().unwrap_or(0),
        serde_json::Value::String(s) => s.parse().unwrap_or(0),
        _ => 0,
    }
}

pub fn parse_details(json: &str) -> Vec<Entry> {
    let Ok(v) = serde_json::from_str::<serde_json::Value>(json) else {
        return Vec::new();
    };
    let Some(list) = v["response"]["publishedfiledetails"].as_array() else {
        return Vec::new();
    };
    let app: u64 = APP_ID.parse().unwrap_or(0);
    let mut out = Vec::new();
    for d in list {
        let id = match &d["publishedfileid"] {
            serde_json::Value::String(s) => s.clone(),
            serde_json::Value::Number(n) => n.to_string(),
            _ => continue,
        };
        if !crate::config::valid_workshop_id(&id)
            || number(&d["result"]) != 1
            || number(&d["consumer_app_id"]) != app
            || number(&d["banned"]) != 0
        {
            continue;
        }
        let tags: Vec<String> = d["tags"]
            .as_array()
            .map(|t| {
                t.iter()
                    .filter_map(|x| x["tag"].as_str().map(str::to_string))
                    .collect()
            })
            .unwrap_or_default();
        let Some(kind) = tags.iter().find_map(|t| Kind::parse(t)) else {
            continue;
        };
        let mature = tags
            .iter()
            .any(|t| t.eq_ignore_ascii_case("mature") || t.eq_ignore_ascii_case("questionable"));
        let title = sys::clean_text(d["title"].as_str().unwrap_or(""), 120);
        out.push(Entry {
            title: if title.is_empty() { id.clone() } else { title },
            id,
            kind,
            preview: d["preview_url"]
                .as_str()
                .filter(|u| image_url_ok(u))
                .map(str::to_string),
            mature,
            subscriptions: number(&d["subscriptions"]),
        });
    }
    out
}

fn read_body(resp: &mut ureq::http::Response<ureq::Body>, limit: u64) -> Result<Vec<u8>> {
    Ok(resp.body_mut().with_config().limit(limit).read_to_vec()?)
}

pub fn search(q: &Query) -> Result<Vec<Entry>> {
    let agent = agent();
    let mut resp = agent
        .get(&browse_url(q))
        .call()
        .context("couldn't reach the Steam Workshop")?;
    let html = String::from_utf8_lossy(&read_body(&mut resp, PAGE_LIMIT)?).into_owned();
    let ids = parse_ids(&html);
    if ids.is_empty() {
        return Ok(Vec::new());
    }
    let count = ids.len().to_string();
    let keys: Vec<String> = (0..ids.len())
        .map(|i| format!("publishedfileids[{i}]"))
        .collect();
    let mut form: Vec<(&str, &str)> = vec![("itemcount", count.as_str())];
    form.extend(
        keys.iter()
            .map(String::as_str)
            .zip(ids.iter().map(String::as_str)),
    );
    let mut resp = agent
        .post(DETAILS)
        .send_form(form)
        .context("couldn't read wallpaper details from Steam")?;
    let json = String::from_utf8_lossy(&read_body(&mut resp, DETAILS_LIMIT)?).into_owned();
    let mut entries = parse_details(&json);
    entries.sort_by_key(|e| ids.iter().position(|i| *i == e.id));
    Ok(entries)
}

pub fn preview(url: &str) -> Result<Vec<u8>> {
    if !image_url_ok(url) {
        bail!("not a Steam image");
    }
    let mut resp = agent().get(url).call()?;
    read_body(&mut resp, PREVIEW_LIMIT)
}

pub fn item_page(id: &str, steam: bool) -> Option<String> {
    if !crate::config::valid_workshop_id(id) {
        return None;
    }
    Some(if steam {
        format!("steam://url/CommunityFilePage/{id}")
    } else {
        format!("https://steamcommunity.com/sharedfiles/filedetails/?id={id}")
    })
}

pub fn short_count(n: u64) -> String {
    match n {
        0..=999 => n.to_string(),
        1_000..=999_999 => format!("{:.1}k", n as f64 / 1_000.0).replace(".0k", "k"),
        _ => format!("{:.1}M", n as f64 / 1_000_000.0).replace(".0M", "M"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn urls() {
        let mut q = Query {
            text: String::new(),
            sort: Sort::New,
            kind: Some(Kind::Video),
            page: 2,
        };
        assert_eq!(
            browse_url(&q),
            "https://steamcommunity.com/workshop/browse/?appid=431960&section=readytouseitems&p=2&browsesort=mostrecent&requiredtags%5B%5D=Video"
        );
        q.text = "fjord & night\n".into();
        q.kind = None;
        q.page = 0;
        assert_eq!(
            browse_url(&q),
            "https://steamcommunity.com/workshop/browse/?appid=431960&section=readytouseitems&p=1&browsesort=textsearch&searchtext=fjord%20%26%20night"
        );
    }

    #[test]
    fn ids_from_page() {
        let html = r#"<a href="https://steamcommunity.com/sharedfiles/filedetails/?id=123&searchtext=">x</a>
            <a href="https://steamcommunity.com/sharedfiles/filedetails/?id=123">dup</a>
            <a href="https://steamcommunity.com/sharedfiles/filedetails/?id=456">y</a>
            <a href="https://steamcommunity.com/sharedfiles/filedetails/?id=abc">bad</a>"#;
        assert_eq!(parse_ids(html), vec!["123", "456"]);
    }

    #[test]
    fn image_hosts() {
        assert!(image_url_ok(
            "https://images.steamusercontent.com/ugc/1/ABC/"
        ));
        assert!(!image_url_ok("http://images.steamusercontent.com/ugc/1/"));
        assert!(!image_url_ok(
            "https://images.steamusercontent.com.evil.example/x"
        ));
        assert!(!image_url_ok(
            "https://evil.example/?images.steamusercontent.com"
        ));
        assert!(!image_url_ok(
            "https://images.steamusercontent.com@evil.example/"
        ));
    }

    #[test]
    fn details() {
        let json = r#"{"response":{"publishedfiledetails":[
            {"publishedfileid":"1","result":1,"consumer_app_id":431960,"banned":0,"title":"Rain\nFjord",
             "preview_url":"https://images.steamusercontent.com/ugc/1/A/","subscriptions":1500,
             "tags":[{"tag":"Scene"},{"tag":"Everyone"}]},
            {"publishedfileid":"2","result":1,"consumer_app_id":431960,"banned":0,"title":"x",
             "preview_url":"https://evil.example/a.png","tags":[{"tag":"Video"},{"tag":"Mature"}]},
            {"publishedfileid":"3","result":1,"consumer_app_id":431960,"banned":0,"title":"app",
             "tags":[{"tag":"Application"}]},
            {"publishedfileid":"4","result":1,"consumer_app_id":570,"banned":0,"title":"other game",
             "tags":[{"tag":"Scene"}]},
            {"publishedfileid":"5","result":9,"consumer_app_id":431960,"banned":0,"tags":[{"tag":"Scene"}]},
            {"publishedfileid":"6","result":1,"consumer_app_id":431960,"banned":1,"tags":[{"tag":"Scene"}]}
        ]}}"#;
        let e = parse_details(json);
        assert_eq!(e.len(), 2);
        assert_eq!(e[0].title, "Rain Fjord");
        assert_eq!(e[0].kind, Kind::Scene);
        assert!(!e[0].mature);
        assert_eq!(e[0].subscriptions, 1500);
        assert!(e[1].mature);
        assert_eq!(e[1].preview, None);
        assert!(parse_details("not json").is_empty());
    }

    #[test]
    fn pages_and_counts() {
        assert_eq!(
            item_page("42", true).as_deref(),
            Some("steam://url/CommunityFilePage/42")
        );
        assert_eq!(item_page("4;2", true), None);
        assert_eq!(short_count(999), "999");
        assert_eq!(short_count(1500), "1.5k");
        assert_eq!(short_count(2_000_000), "2M");
    }
}
