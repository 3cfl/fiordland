#!/bin/bash
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
T=$(mktemp -d)
port=$((20000 + RANDOM % 20000))
trap 'kill $srv 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/src/repo/x86_64" "$T/src/iso" "$T/src/mirrors" "$T/dest/iso"
cd "$T/src"
echo db > repo/x86_64/fiordland.db
printf 'GOODISO1' > iso/f.iso
printf '{"file": "f.iso"}' > iso/latest.json
for f in repo/x86_64/fiordland.db iso/f.iso iso/latest.json; do
  echo "$(sha256sum "$f" | cut -d' ' -f1) $(stat -c %s "$f") $f"
done > mirrors/manifest.txt
printf 'EVILISO1' > "$T/dest/iso/f.iso"
python3 -m http.server "$port" -b 127.0.0.1 -d "$T/src" >/dev/null 2>&1 &
srv=$!
for _ in $(seq 50); do curl -fs "http://127.0.0.1:$port/mirrors/manifest.txt" >/dev/null && break; sleep 0.1; done
FIORDLAND_SRC="http://127.0.0.1:$port" bash "$here/web/mirrors/sync.sh" "$T/dest" >/dev/null
[ "$(cat "$T/dest/iso/f.iso")" = GOODISO1 ] || { echo "FAIL: same-size tampered iso kept"; exit 1; }
echo "ok"
