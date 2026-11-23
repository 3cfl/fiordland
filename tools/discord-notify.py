#!/usr/bin/env python3
import json
import os
import sys
import urllib.error
import urllib.request

REPO = os.environ.get("FIORD_REPO", "3cfl/fiordland")
HOOK = os.environ.get("DISCORD_WEBHOOK", "")
STATE = os.environ.get("STATE_FILE", "/var/lib/fiordland-discord/state.json")

COLOURS = {"opened": 0x8EC5FF, "reopened": 0x8EC5FF, "merged": 0xA78BFA, "closed": 0x6B7280, "published": 0x34D399,
           "push": 0x60A5FA, "create": 0x34D399, "delete": 0x6B7280, "fork": 0xF59E0B, "star": 0xFBBF24}


def load():
    try:
        with open(STATE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save(state):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f)
    os.replace(tmp, STATE)


def api(path):
    return urllib.request.Request(f"https://api.github.com/repos/{REPO}/{path}",
                                  headers={"User-Agent": "fiordland-discord", "Accept": "application/vnd.github+json"})


def commits(p):
    if p.get("commits"):
        return [(c["sha"], c["message"], c.get("author", {}).get("name", "")) for c in p["commits"]]
    before, head = p.get("before", ""), p.get("head", "")
    if not head:
        return []
    try:
        if before and set(before) != {"0"}:
            with urllib.request.urlopen(api(f"compare/{before}...{head}"), timeout=20) as r:
                data = json.load(r)["commits"]
        else:
            with urllib.request.urlopen(api(f"commits/{head}"), timeout=20) as r:
                data = [json.load(r)]
    except (urllib.error.URLError, ValueError, KeyError):
        return [(head, "", "")]
    return [(c["sha"], c["commit"]["message"], c["commit"]["author"]["name"]) for c in data]


def fetch(etag):
    req = api("events?per_page=50")
    if etag:
        req.add_header("If-None-Match", etag)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.load(r), r.headers.get("ETag")
    except urllib.error.HTTPError as e:
        if e.code == 304:
            return None, etag
        raise


def embed(ev):
    t, p, actor = ev["type"], ev["payload"], ev["actor"]
    if t == "PullRequestEvent":
        pr = p["pull_request"]
        action = p["action"]
        if action == "closed" and pr.get("merged"):
            action = "merged"
        if action not in ("opened", "reopened", "closed", "merged"):
            return None
        return {"title": f"Pull request #{pr['number']} {action}: {pr['title']}"[:256], "url": pr["html_url"],
                "description": (pr.get("body") or "")[:400], "color": COLOURS[action]}
    if t == "IssuesEvent":
        issue = p["issue"]
        if p["action"] not in ("opened", "reopened", "closed"):
            return None
        return {"title": f"Issue #{issue['number']} {p['action']}: {issue['title']}"[:256], "url": issue["html_url"],
                "description": (issue.get("body") or "")[:400], "color": COLOURS[p["action"]]}
    if t == "PushEvent":
        branch = p.get("ref", "").removeprefix("refs/heads/")
        cs = commits(p)
        if not cs:
            return None
        lines = [f"[`{sha[:7]}`](https://github.com/{REPO}/commit/{sha}) {msg.splitlines()[0][:90] if msg else ''}"
                 for sha, msg, _ in cs[-10:]]
        if len(cs) > 10:
            lines.insert(0, f"...and {len(cs) - 10} earlier")
        n = len(cs)
        url = f"https://github.com/{REPO}/compare/{p['before'][:12]}...{p['head'][:12]}" if n > 1 and p.get("before") \
            else f"https://github.com/{REPO}/commit/{cs[-1][0]}"
        return {"title": f"{n} new commit{'s' if n != 1 else ''} to {branch}"[:256], "url": url,
                "description": "\n".join(lines)[:2000], "color": COLOURS["push"]}
    if t in ("CreateEvent", "DeleteEvent") and p.get("ref_type") in ("branch", "tag"):
        verb = "created" if t == "CreateEvent" else "deleted"
        ref = p["ref"]
        url = f"https://github.com/{REPO}/tree/{ref}" if verb == "created" else f"https://github.com/{REPO}"
        return {"title": f"{p['ref_type'].capitalize()} {ref} {verb}"[:256], "url": url,
                "color": COLOURS["create" if verb == "created" else "delete"]}
    if t == "ForkEvent":
        f = p["forkee"]
        return {"title": f"Forked to {f['full_name']}"[:256], "url": f["html_url"], "color": COLOURS["fork"]}
    if t == "WatchEvent" and p.get("action") == "started":
        return {"title": f"Starred {REPO}", "url": f"https://github.com/{REPO}/stargazers", "color": COLOURS["star"]}
    if t == "ReleaseEvent" and p["action"] == "published":
        rel = p["release"]
        return {"title": f"Released {rel.get('name') or rel['tag_name']}"[:256], "url": rel["html_url"],
                "description": (rel.get("body") or "")[:400], "color": COLOURS["published"]}
    return None


def post(e, actor):
    e["author"] = {"name": actor["login"], "icon_url": actor["avatar_url"], "url": f"https://github.com/{actor['login']}"}
    e["footer"] = {"text": REPO}
    body = json.dumps({"username": "Fiordland", "embeds": [e], "allowed_mentions": {"parse": []}}).encode()
    req = urllib.request.Request(HOOK, data=body, headers={"Content-Type": "application/json", "User-Agent": "fiordland-discord"})
    urllib.request.urlopen(req, timeout=20).close()


def main():
    if not HOOK:
        sys.exit("DISCORD_WEBHOOK not set")
    state = load()
    events, etag = fetch(state.get("etag"))
    if events is None:
        return
    seen = set(state.get("seen", []))
    first = "seen" not in state
    for ev in sorted(events, key=lambda x: int(x["id"])):
        if ev["id"] in seen:
            continue
        seen.add(ev["id"])
        if first:
            continue
        e = embed(ev)
        if e:
            post(e, ev["actor"])
    state["seen"] = sorted(seen, key=int)[-300:]
    state["etag"] = etag
    save(state)


if __name__ == "__main__":
    main()
