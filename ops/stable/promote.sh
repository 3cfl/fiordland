#!/usr/bin/env bash
set -euo pipefail
cand=${1:?usage: promote.sh YYYY/MM/DD}
[[ $cand =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]] || { echo "date must be YYYY/MM/DD"; exit 2; }
curl -fsI "https://archive.archlinux.org/repos/$cand/core/os/x86_64/core.db" >/dev/null || { echo "no archive snapshot for $cand"; exit 1; }
ssh main bash -s -- "$cand" <<'REMOTE'
set -e
cand=$1
f=/etc/fiordland/stable-date.conf
prev=$(sed -n 's/.*$stable_date { default "\(.*\)"; }.*/\1/p' "$f" 2>/dev/null || true)
prev=${prev:-$cand}
mkdir -p /etc/fiordland
printf 'map "" $stable_date { default "%s"; }\nmap "" $stable_previous { default "%s"; }\n' "$cand" "$prev" > "$f.new"
mv "$f.new" "$f"
nginx -t -q && systemctl reload nginx
echo "stable: $prev -> $cand"
REMOTE
