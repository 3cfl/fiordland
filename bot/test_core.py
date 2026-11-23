import json
import tarfile
import tempfile
from pathlib import Path

import core


def make_db(tmp):
    db = Path(tmp) / "x.db.tar.gz"
    src = Path(tmp) / "src"
    (src / "tawaki-0.1.0-1").mkdir(parents=True)
    (src / "tawaki-0.1.0-1" / "desc").write_text("%NAME%\ntawaki\n\n%VERSION%\n0.1.0-1\n\n%DESC%\nThe package manager\n")
    with tarfile.open(db, "w:gz") as tar:
        tar.add(src / "tawaki-0.1.0-1", arcname="tawaki-0.1.0-1")
    return db


def test_clean_query():
    assert core.clean_query(" firefox ") == "firefox"
    assert core.clean_query("a b") is None
    assert core.clean_query("x" * 65) is None
    assert core.clean_query("../etc") is None


def test_repo_search():
    with tempfile.TemporaryDirectory() as tmp:
        db = make_db(tmp)
        rows = core.search_repo("taw", path=db)
        assert rows[0]["name"] == "tawaki" and rows[0]["desc"] == "The package manager"
        assert core.search_repo("nope", path=db) == []


def test_iso():
    with tempfile.TemporaryDirectory() as tmp:
        p = Path(tmp) / "latest.json"
        p.write_text(json.dumps({"file": "f.iso", "size": 2818965504, "date": "2026-11-23", "sha256": "ab"}))
        info = core.iso_info(p)
        assert info["size"] == "2.8 GB" and info["date"] == "2026.11.23" and info["url"].endswith("/iso/f.iso")


def test_parsers():
    arch = core.parse_arch({"results": [{"repo": "extra", "pkgname": "ncspot", "pkgver": "1.5.0", "pkgrel": "2", "pkgdesc": "d"}]})
    assert arch[0]["version"] == "1.5.0-2"
    aur = core.parse_aur({"results": [{"Name": "a", "Version": "1", "Popularity": 1}, {"Name": "b", "Version": "2", "Popularity": 5, "Description": None}]})
    assert [r["name"] for r in aur] == ["b", "a"] and aur[0]["desc"] == ""
    assert "q=a+b" in core.arch_url("a b")
    assert core.aur_url("a/b").startswith("https://aur.archlinux.org/rpc/v5/search/a%2Fb")


def test_downloads_and_status():
    with tempfile.TemporaryDirectory() as tmp:
        log = Path(tmp) / "iso.log"
        line = lambda status, method="GET", uri="/iso/f.iso": json.dumps({"status": status, "request": {"method": method, "uri": uri}}) + "\n"
        log.write_text(line(200) + line(206) + line(200, "HEAD") + line(200, uri="/x") + "{broken")
        state = {}
        assert core.count_downloads(state, log) == 1
        with log.open("a") as f:
            f.write("\n" + line(200))
        assert core.count_downloads(state, log) == 2
        assert core.count_downloads(state, log) == 2
        log.write_text(line(200))
        assert core.count_downloads(state, log) == 3
        iso = Path(tmp) / "latest.json"
        iso.write_text(json.dumps({"file": "f.iso", "size": 1, "date": "2026-11-23", "sha256": "a"}))
        items = core.status_items(state, iso, log)
        assert items[0] == ("playing", "Fiordland 2026.11.23") and len(items) == 2
        for _ in range(8):
            with log.open("a") as f:
                f.write(line(200))
        assert core.status_items(state, iso, log)[1] == ("watching", "11 ISO downloads")
