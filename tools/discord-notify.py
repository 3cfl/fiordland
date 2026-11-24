#!/usr/bin/env python3
import json
import os
import sys
import urllib.error
import urllib.request

REPOS = [r.strip() for r in os.environ.get("FIORD_REPOS", "Fiordland-Linux/fiordland,Fiordland-Linux/tawaki,Fiordland-Linux/rawaru,Fiordland-Linux/kuaka").split(",") if r.strip()]
NAME = os.environ.get("DISCORD_NAME", "GitHub")
AVATAR = os.environ.get("DISCORD_AVATAR", "https://fiordlandlinux.org/assets/github.png")
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


def api(repo, path):
    return urllib.request.Request(f"https://api.github.com/repos/{repo}/{path}",
                                  headers={"User-Agent": "fiordland-discord", "Accept": "application/vnd.github+json"})


def commits(repo, p):
    if p.get("commits"):
        return [(c["sha"], c["message"], c.get("author", {}).get("name", "")) for c in p["commits"]]
    before, head = p.get("before", ""), p.get("head", "")
    if not head:
        return []
    try:
        if before and set(before) != {"0"}:
            with urllib.request.urlopen(api(repo, f"compare/{before}...{head}"), timeout=20) as r:
                data = json.load(r)["commits"]
        else:
            with urllib.request.urlopen(api(repo, f"commits/{head}"), timeout=20) as r:
                data = [json.load(r)]
    except (urllib.error.URLError, ValueError, KeyError):
        return [(head, "", "")]
    return [(c["sha"], c["commit"]["message"], c["commit"]["author"]["name"]) for c in data]


def fetch(repo, etag):
    req = api(repo, "events?per_page=50")
    if etag:
        req.add_header("If-None-Match", etag)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.load(r), r.headers.get("ETag")
    except urllib.error.HTTPError as e:
        if e.code == 304:
            return None, etag
        raise


def embed(repo, ev):
    t, p = ev["type"], ev["payload"]
    if t == "PullRequestEvent":
        pr = p["pull_request"]
        if "title" not in pr:
            try:
                with urllib.request.urlopen(api(repo, f"pulls/{pr['number']}"), timeout=20) as r:
                    pr = json.load(r)
            except (urllib.error.URLError, ValueError):
                pr = {**pr, "title": "", "html_url": f"https://github.com/{repo}/pull/{pr['number']}"}
        action = p["action"]
        if action == "closed" and pr.get("merged"):
            action = "merged"
        if action not in ("opened", "reopened", "closed", "merged"):
            return None
        return {"title": f"Pull request #{pr['number']} {action}: {pr['title']}"[:256], "url": pr["html_url"],
                "description": (pr.get("body") or "")[:400], "color": COLOURS[action]}
    if t == "IssuesEvent":
        issue = p["issue"]
        if "title" not in issue:
            try:
                with urllib.request.urlopen(api(repo, f"issues/{issue['number']}"), timeout=20) as r:
                    issue = json.load(r)
            except (urllib.error.URLError, ValueError):
                issue = {**issue, "title": "", "html_url": f"https://github.com/{repo}/issues/{issue['number']}"}
        if p["action"] not in ("opened", "reopened", "closed"):
            return None
        return {"title": f"Issue #{issue['number']} {p['action']}: {issue['title']}"[:256], "url": issue["html_url"],
                "description": (issue.get("body") or "")[:400], "color": COLOURS[p["action"]]}
    if t == "PushEvent":
        branch = p.get("ref", "").removeprefix("refs/heads/")
        cs = commits(repo, p)
        if not cs:
            return None
        lines = [f"[`{sha[:7]}`](https://github.com/{repo}/commit/{sha}) {msg.splitlines()[0][:90] if msg else ''}"
                 for sha, msg, _ in cs[-10:]]
        if len(cs) > 10:
            lines.insert(0, f"...and {len(cs) - 10} earlier")
        n = len(cs)
        url = f"https://github.com/{repo}/compare/{p['before'][:12]}...{p['head'][:12]}" if n > 1 and p.get("before") \
            else f"https://github.com/{repo}/commit/{cs[-1][0]}"
        return {"title": f"{n} new commit{'s' if n != 1 else ''} to {branch}"[:256], "url": url,
                "description": "\n".join(lines)[:2000], "color": COLOURS["push"]}
    if t in ("CreateEvent", "DeleteEvent") and p.get("ref_type") in ("branch", "tag"):
        verb = "created" if t == "CreateEvent" else "deleted"
        ref = p["ref"]
        url = f"https://github.com/{repo}/tree/{ref}" if verb == "created" else f"https://github.com/{repo}"
        return {"title": f"{p['ref_type'].capitalize()} {ref} {verb}"[:256], "url": url,
                "color": COLOURS["create" if verb == "created" else "delete"]}
    if t == "ForkEvent":
        f = p["forkee"]
        return {"title": f"Forked to {f['full_name']}"[:256], "url": f["html_url"], "color": COLOURS["fork"]}
    if t == "WatchEvent" and p.get("action") == "started":
        return {"title": f"Starred {repo}", "url": f"https://github.com/{repo}/stargazers", "color": COLOURS["star"]}
    if t == "ReleaseEvent" and p["action"] == "published":
        rel = p["release"]
        return {"title": f"Released {rel.get('name') or rel['tag_name']}"[:256], "url": rel["html_url"],
                "description": (rel.get("body") or "")[:400], "color": COLOURS["published"]}
    return None


def post(repo, e, actor):
    e["author"] = {"name": actor["login"], "icon_url": actor["avatar_url"], "url": f"https://github.com/{actor['login']}"}
    e["footer"] = {"text": repo}
    body = json.dumps({"username": NAME, "avatar_url": AVATAR, "embeds": [e], "allowed_mentions": {"parse": []}}).encode()
    req = urllib.request.Request(HOOK, data=body, headers={"Content-Type": "application/json", "User-Agent": "fiordland-discord"})
    urllib.request.urlopen(req, timeout=20).close()


def poll(repo, st):
    events, etag = fetch(repo, st.get("etag"))
    if events is None:
        return
    seen = set(st.get("seen", []))
    first = "seen" not in st
    for ev in sorted(events, key=lambda x: int(x["id"])):
        if ev["id"] in seen:
            continue
        seen.add(ev["id"])
        if first:
            continue
        e = embed(repo, ev)
        if e:
            post(repo, e, ev["actor"])
    st["seen"] = sorted(seen, key=int)[-300:]
    st["etag"] = etag


def main():
    if not HOOK:
        sys.exit("DISCORD_WEBHOOK not set")
    state = load()
    if "repos" not in state:
        state = {"repos": {"3cfl/fiordland": state} if state else {}}
    state.pop("next", None)
    failed = False
    try:
        for repo in REPOS:
            try:
                poll(repo, state["repos"].setdefault(repo, {}))
            except (urllib.error.URLError, OSError, ValueError) as e:
                print(f"{repo}: {e}", file=sys.stderr)
                failed = True
    finally:
        save(state)
    if failed:
        sys.exit(1)

if __name__ == "__main__":
    main()
