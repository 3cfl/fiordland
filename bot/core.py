import json
import re
import tarfile
import urllib.parse
from pathlib import Path

ISO_JSON = Path("/srv/fiordland/iso/latest.json")
REPO_DB = Path("/srv/fiordland/repo/x86_64/fiordland.db.tar.gz")
SITE = "https://fiordland.apollo44.lat"
REPO = "3cfl/fiordland"
QUERY = re.compile(r"^[\w.+@-]{1,64}$")

_cache = {"mtime": None, "rows": []}


def clean_query(text):
    text = text.strip()
    return text if QUERY.match(text) else None


def iso_info(path=ISO_JSON):
    data = json.loads(Path(path).read_text())
    return {
        "file": data["file"],
        "size": f"{data['size'] / 1e9:.1f} GB",
        "date": data["date"].replace("-", "."),
        "sha256": data["sha256"],
        "url": f"{SITE}/iso/{urllib.parse.quote(data['file'])}",
    }


def repo_rows(path=REPO_DB):
    path = Path(path)
    mtime = path.stat().st_mtime
    if _cache["mtime"] == mtime and _cache.get("path") == str(path):
        return _cache["rows"]
    rows = []
    with tarfile.open(path, "r:gz") as tar:
        for member in tar.getmembers():
            if not member.name.endswith("/desc"):
                continue
            text = tar.extractfile(member).read().decode(errors="replace")
            fields = {}
            for block in text.split("\n\n"):
                lines = block.strip().split("\n")
                if len(lines) >= 2 and lines[0].startswith("%"):
                    fields[lines[0].strip("%")] = lines[1]
            if "NAME" in fields:
                rows.append({"name": fields["NAME"], "version": fields.get("VERSION", ""), "desc": fields.get("DESC", "")})
    _cache.update(mtime=mtime, rows=rows, path=str(path))
    return rows


def search_repo(query, limit=3, path=REPO_DB):
    q = query.lower()
    rows = [r for r in repo_rows(path) if q in r["name"].lower()]
    rows.sort(key=lambda r: (r["name"].lower() != q, len(r["name"])))
    return rows[:limit]


def arch_url(query):
    return "https://archlinux.org/packages/search/json/?" + urllib.parse.urlencode({"q": query, "limit": 5})


def aur_url(query):
    return "https://aur.archlinux.org/rpc/v5/search/" + urllib.parse.quote(query, safe="") + "?by=name-desc"


def parse_arch(data, limit=5):
    out = []
    for r in data.get("results", [])[:limit]:
        out.append({"repo": r["repo"], "name": r["pkgname"], "version": f"{r['pkgver']}-{r['pkgrel']}", "desc": r.get("pkgdesc", "")})
    return out


def parse_aur(data, limit=5):
    rows = sorted(data.get("results", []), key=lambda r: r.get("Popularity", 0), reverse=True)
    return [{"name": r["Name"], "version": r["Version"], "desc": r.get("Description") or ""} for r in rows[:limit]]


def line(repo, name, version, desc, url=None):
    label = f"[`{name}`]({url})" if url else f"`{name}`"
    text = f"**{repo}** {label} {version}"
    if desc:
        text += f"\n{desc[:120]}"
    return text


def release_embed_fields(data):
    return {
        "title": f"Fiordland {data.get('name') or data['tag_name']}",
        "url": data["html_url"],
        "description": (data.get("body") or "")[:900],
        "id": data["id"],
    }
