import hashlib
import json
import os
import re
import time
import urllib.request
from pathlib import Path

ROOT = Path(os.environ.get("FIORDLAND_ROOT", "/srv/fiordland"))
REPO = ROOT / "repo" / "x86_64"
LASTUPDATE = ROOT / "repo" / "lastupdate"
ISO = ROOT / "iso"
OUT = ROOT / "site" / "mirrors"
STATE = Path(os.environ.get("STATE_DIRECTORY", "/var/lib/fiordland-mirrors")) / "hashes.json"
MAX_LAG = 6 * 3600
NAME = re.compile(r"^[A-Za-z0-9._+@:-]+$")


def write(path, text):
    tmp = path.with_name("." + path.name + ".tmp")
    tmp.write_text(text)
    tmp.chmod(0o644)
    tmp.replace(path)


def digest(path, cache):
    st = path.stat()
    key = f"{path}:{st.st_size}:{st.st_mtime_ns}"
    if key not in cache:
        h = hashlib.sha256()
        with path.open("rb") as handle:
            for block in iter(lambda: handle.read(1 << 20), b""):
                h.update(block)
        cache[key] = h.hexdigest()
    return cache[key]


def build_manifest():
    try:
        cache = json.loads(STATE.read_text())
    except (OSError, ValueError):
        cache = {}
    entries = []
    newest = 0
    for path in sorted(REPO.iterdir()):
        if path.is_symlink():
            if path.name not in ("fiordland.db", "fiordland.files", "fiordland.db.sig", "fiordland.files.sig"):
                continue
            if path.resolve().parent != REPO.resolve():
                continue
        if not path.is_file() or not NAME.fullmatch(path.name):
            continue
        newest = max(newest, int(path.stat().st_mtime))
        entries.append(("repo/x86_64/" + path.name, path))
    write(LASTUPDATE, f"{newest}\n")
    entries.append(("repo/lastupdate", LASTUPDATE))
    for path in sorted(ISO.iterdir()):
        if path.is_symlink() or not path.is_file() or not NAME.match(path.name):
            continue
        if path.suffix == ".iso" or path.name == "latest.json":
            entries.append(("iso/" + path.name, path))
    lines = [f"{digest(p, cache)} {p.stat().st_size} {rel}" for rel, p in entries]
    live = {f"{p}:{p.stat().st_size}:{p.stat().st_mtime_ns}" for _, p in entries}
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps({k: v for k, v in cache.items() if k in live}))
    OUT.mkdir(parents=True, exist_ok=True)
    write(OUT / "manifest.txt", "\n".join(lines) + "\n")
    return newest


def probe(url):
    started = time.monotonic()
    try:
        request = urllib.request.Request(url.rstrip("/") + "/repo/lastupdate", headers={"User-Agent": "fiordland-mirror-check"})
        with urllib.request.urlopen(request, timeout=8) as response:
            body = response.read(64).decode().strip()
        for suffix in ("fiordland.db", "fiordland.db.sig"):
            url_db = url.rstrip("/") + "/repo/x86_64/" + suffix
            with urllib.request.urlopen(url_db, timeout=8) as response:
                prefix = response.read(2)
                if len(prefix) != 2 or (suffix.endswith(".db") and prefix != b"\x1f\x8b"):
                    return {"ok": False}
        return {"ok": True, "updated": int(body), "ms": int((time.monotonic() - started) * 1000)}
    except (OSError, ValueError):
        return {"ok": False}


def check(newest):
    mirrors = json.loads((OUT / "mirrors.json").read_text())["mirrors"]
    now = int(time.time())
    status = {}
    up = []
    for m in mirrors:
        url = m["url"].rstrip("/")
        if not url.startswith("https://") or m.get("disabled"):
            continue
        result = probe(url)
        if result["ok"]:
            result["lag"] = max(0, newest - result["updated"])
            result["ok"] = result["lag"] <= MAX_LAG
        result["checked"] = now
        status[url] = result
        if result["ok"]:
            up.append((not m.get("primary"), result["ms"], url))
    up.sort()
    write(OUT / "status.json", json.dumps({"updated": now, "mirrors": status}))
    write(OUT / "mirrorlist", "".join(f"Server = {url}/repo/$arch\n" for _, _, url in up))


if __name__ == "__main__":
    check(build_manifest())
