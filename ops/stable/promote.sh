#!/usr/bin/env bash
set -euo pipefail
cand=${1:?usage: promote.sh YYYY/MM/DD}
[[ $cand =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]] || { echo "date must be YYYY/MM/DD"; exit 2; }
curl -fsI "https://archive.archlinux.org/repos/$cand/core/os/x86_64/core.db" >/dev/null || { echo "no archive snapshot for $cand"; exit 1; }
ssh main bash -s -- "$cand" <<'REMOTE'
set -euo pipefail
cand=$1
[[ $cand =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]] || { echo "bad date"; exit 2; }
f=/etc/caddy/fiordland-stable.caddy
prev=$(sed -n 's|.*archive.archlinux.org/repos/\([0-9/]*\){.*|\1|p' "$f" 2>/dev/null || true)
cp -a "$f" "$f.prev"
cat > "$f.new" <<EOF
handle /stable/date {
	header Content-Type text/plain
	header Cache-Control "no-cache"
	respond "$cand
" 200
}
@stablefile path_regexp ^/stable(/(core|extra|multilib)/os/x86_64/[A-Za-z0-9@._+:-]+)\$
handle @stablefile {
	redir https://archive.archlinux.org/repos/$cand{re.stablefile.1} 302
}
EOF
mv "$f.new" "$f"
if ! caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1 || ! systemctl reload caddy; then
  mv "$f.prev" "$f"
  systemctl reload caddy || true
  echo "caddy rejected the new config, kept ${prev:-the old date}"
  exit 1
fi
echo "stable: ${prev:-unknown} -> $cand"
REMOTE
