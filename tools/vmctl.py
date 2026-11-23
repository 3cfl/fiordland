#!/usr/bin/env python3
import json
import os
import socket
import subprocess
import sys
import time

DIR = os.environ.get("VMDIR", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "vm"))
QMP = os.path.join(DIR, "qmp.sock")


class Qmp:
    def __init__(self):
        self.s = socket.socket(socket.AF_UNIX)
        self.s.connect(QMP)
        self.f = self.s.makefile("rw")
        self.f.readline()
        self.cmd("qmp_capabilities")

    def cmd(self, name, **args):
        self.f.write(json.dumps({"execute": name, "arguments": args}) + "\n")
        self.f.flush()
        while True:
            r = json.loads(self.f.readline())
            if "return" in r or "error" in r:
                return r


def gexec(cmd, timeout=600):
    s = socket.socket(socket.AF_UNIX)
    s.connect(os.path.join(DIR, "qga.sock"))
    s.settimeout(timeout)
    f = s.makefile("rw")

    def call(name, **args):
        f.write(json.dumps({"execute": name, "arguments": args}) + "\n")
        f.flush()
        while True:
            line = f.readline()
            if not line:
                raise RuntimeError("guest agent closed")
            r = json.loads(line)
            if "return" in r or "error" in r:
                return r

    call("guest-sync", id=4242)
    pid = call("guest-exec", path="/bin/sh", arg=["-c", cmd], **{"capture-output": True})["return"]["pid"]
    end = time.time() + timeout
    while time.time() < end:
        r = call("guest-exec-status", pid=pid)["return"]
        if r.get("exited"):
            import base64
            out = base64.b64decode(r.get("out-data", "")).decode(errors="replace")
            err = base64.b64decode(r.get("err-data", "")).decode(errors="replace")
            return r.get("exitcode", 0), out, err
        time.sleep(0.3)
    raise TimeoutError(cmd)


def size(q):
    tmp = os.path.join(DIR, "probe.ppm")
    if "error" not in q.cmd("screendump", filename=tmp):
        with open(tmp, "rb") as f:
            f.readline()
            w, h = map(int, f.readline().split())
        return w, h
    cache = os.path.join(DIR, "size")
    if os.path.exists(cache):
        return tuple(map(int, open(cache).read().split()))
    import base64
    import struct
    code, data, err = gexec(GRIM, 60)
    w, h = struct.unpack(">II", base64.b64decode(data)[16:24])
    open(cache, "w").write(f"{w} {h}")
    return w, h


GRIM = ("u=$(stat -c %U /run/user/1000); w=$(basename $(ls /run/user/1000/wayland-? | head -1)); "
        "su \"$u\" -c \"XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=$w grim -t png -\" | base64 -w0")


def shot(q, out):
    tmp = os.path.join(DIR, "shot.ppm")
    if "error" not in q.cmd("screendump", filename=tmp):
        subprocess.run(["magick", tmp, out], check=True)
        return
    import base64
    code, data, err = gexec(GRIM, 60)
    if code or not data:
        raise RuntimeError("grim failed: " + err)
    with open(out, "wb") as f:
        f.write(base64.b64decode(data))


def move(q, x, y):
    w, h = size(q)
    q.cmd("input-send-event", events=[
        {"type": "abs", "data": {"axis": "x", "value": int(x * 32767 / w)}},
        {"type": "abs", "data": {"axis": "y", "value": int(y * 32767 / h)}},
    ])


def click(q, x, y, button="left"):
    move(q, x, y)
    time.sleep(0.15)
    for down in (True, False):
        q.cmd("input-send-event", events=[{"type": "btn", "data": {"down": down, "button": button}}])
        time.sleep(0.08)


KEYMAP = {" ": "spc", "\n": "ret", "-": "minus", ".": "dot", "/": "slash", "_": "shift-minus", "@": "shift-2",
          "!": "shift-1", ":": "shift-semicolon", "=": "equal", ",": "comma", "'": "apostrophe"}


def key(q, combo):
    keys = [{"type": "qcode", "data": k} for k in combo.split("-")]
    q.cmd("send-key", keys=keys)
    time.sleep(0.05)


def typ(q, text):
    for ch in text:
        if ch in KEYMAP:
            key(q, KEYMAP[ch])
        elif ch.isupper():
            key(q, "shift-" + ch.lower())
        else:
            key(q, ch)


def main():
    a = sys.argv[1:]
    if a and a[0] == "exec":
        code, out, err = gexec(a[1], float(a[2]) if len(a) > 2 else 600)
        sys.stdout.write(out)
        sys.stderr.write(err)
        sys.exit(code)
    q = Qmp()
    while a:
        op = a.pop(0)
        if op == "shot":
            shot(q, a.pop(0))
        elif op == "click":
            click(q, float(a.pop(0)), float(a.pop(0)))
        elif op == "move":
            move(q, float(a.pop(0)), float(a.pop(0)))
        elif op == "key":
            key(q, a.pop(0))
        elif op == "type":
            typ(q, a.pop(0))
        elif op == "sleep":
            time.sleep(float(a.pop(0)))
        elif op == "size":
            print(*size(q))
        elif op == "quit":
            q.cmd("quit")
        else:
            print("unknown", op, file=sys.stderr)
            sys.exit(2)


if __name__ == "__main__":
    main()
