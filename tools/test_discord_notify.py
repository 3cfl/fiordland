import runpy
from pathlib import Path
from unittest.mock import patch

import pytest


def test_retry_after_partial_delivery(tmp_path):
    notify = runpy.run_path(str(Path(__file__).with_name("discord-notify.py")))
    poll = notify["poll"]
    events = [{"id": str(i), "actor": {}} for i in (1, 2, 3, 4)]
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
        assert saved["repos"]["repo"] == {"seen": ["1", "2", "3"], "etag": "previous"}
        with patch.dict(poll.__globals__, post=lambda _, e, actor: delivered.append(e["id"])):
            poll("repo", saved)
            poll("first-poll", saved)
    assert delivered == ["2", "4"]
