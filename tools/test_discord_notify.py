import runpy
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

import pytest


def test_retry_after_partial_delivery(tmp_path):
    notify = runpy.run_path(str(Path(__file__).with_name("discord-notify.py")))
    poll = notify["poll"]
    stamp = datetime.now(timezone.utc).isoformat()
    events = [{"id": str(i), "actor": {}, "type": "IssuesEvent", "created_at": stamp} for i in (1, 2, 3, 4)]
    delivered = []

    def send(repo, event, actor):
        if event["id"] == "4" and delivered == ["2"]:
            raise OSError("delivery failed")
        delivered.append(event["id"])

    state = {"repos": {"repo": {"seen": ["1"], "etag": "previous"}}}
    with patch.dict(poll.__globals__, STATE=str(tmp_path / "state.json"),
                    fetch=lambda *_: (events, "next"), embed=lambda _, e: e if e["id"] != "3" else None, post=send):
        with pytest.raises(OSError):
            poll("repo", state)
        saved = notify["load"]()
        assert saved["repos"]["repo"] == {"seen": ["1", "2", "3"], "etag": "previous", "pushes": []}
        with patch.dict(poll.__globals__, post=lambda _, e, actor: delivered.append(e["id"])):
            poll("repo", saved)
            poll("first-poll", saved)
    assert delivered == ["2", "4"]


def test_late_events_and_repeated_push_ids(tmp_path):
    poll = runpy.run_path(str(Path(__file__).with_name("discord-notify.py")))["poll"]
    now = datetime.now(timezone.utc).isoformat()
    old = "2020-01-01T00:00:00Z"

    def event(i, stamp, kind, payload):
        return {"id": str(i), "created_at": stamp, "type": kind, "payload": payload, "actor": {}}

    events = [event(1, now, "PushEvent", {"push_id": 42}),
              event(2, now, "PushEvent", {"push_id": 42}),
              event(3, old, "PushEvent", {"push_id": 43}),
              event(4, old, "CreateEvent", {"ref": "release"}),
              event(5, now, "PushEvent", {"push_id": 44, "head": "previously-authored-commit"}),
              event(6, now, "PullRequestEvent", {"action": "opened"})]
    state = {"repos": {"repo": {"seen": ["1"]}}}
    posted = []
    with patch.dict(poll.__globals__, STATE=str(tmp_path / "state.json"), fetch=lambda *_: (events, "v1"),
                    embed=lambda _, e: {"id": e["id"]}, post=lambda _, e, actor: posted.append(e)):
        poll("repo", state)
        poll("repo", state)
        # GitHub can return a push under a different event ID on a later page.
        events[:] = [event(7, now, "PushEvent", {"push_id": 44})]
        poll("repo", state)
    assert [e["id"] for e in posted] == ["5", "6"]
    assert all(e["timestamp"] == now for e in posted)
    assert state["repos"]["repo"]["seen"] == [str(i) for i in range(1, 8)]
