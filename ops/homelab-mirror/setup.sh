#!/bin/bash
set -euo pipefail

[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }
PHASE="${1:-install}"
ETC=/etc/fiordland-mirror
DATA=/srv/fiordland-mirror

install_base() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq caddy curl gnupg
  systemctl disable --now caddy >/dev/null 2>&1 || true

  if ! command -v cloudflared >/dev/null; then
    install -d -m 0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg -o /usr/share/keyrings/cloudflare-main.gpg
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' > /etc/apt/sources.list.d/cloudflared.list
    apt-get update -qq
    apt-get install -y -qq cloudflared
    systemctl disable --now cloudflared >/dev/null 2>&1 || true
  fi

  id fiordland-mirror >/dev/null 2>&1 || useradd --system --no-create-home --home-dir "$DATA" --shell /usr/sbin/nologin fiordland-mirror
  install -d -m 0755 -o fiordland-mirror -g fiordland-mirror "$DATA"
  install -d -m 0750 "$ETC"

  curl -fsSL https://fiordland.apollo44.lat/mirrors/sync.sh -o /usr/local/bin/fiordland-mirror-sync
  chmod 0755 /usr/local/bin/fiordland-mirror-sync
  [ -f "$ETC/sync.env" ] || printf 'FIORDLAND_SKIP_ISO=1\n' > "$ETC/sync.env"

  cat > "$ETC/Caddyfile" <<'CADDY'
{
	admin off
	auto_https off
}

:8080 {
	bind 127.0.0.1
	root * /srv/fiordland-mirror
	@db path_regexp db \.(db|files)(\.tar\.gz)?(\.sig)?$|/lastupdate$
	header @db Cache-Control "no-cache"
	header X-Content-Type-Options nosniff
	file_server
}
CADDY

  cat > /etc/systemd/system/fiordland-mirror-web.service <<'UNIT'
[Unit]
Description=Fiordland mirror web server (localhost only)
After=network.target

[Service]
DynamicUser=yes
Environment=XDG_DATA_HOME=/var/lib/fiordland-mirror-web XDG_CONFIG_HOME=/var/lib/fiordland-mirror-web
StateDirectory=fiordland-mirror-web
ExecStart=/usr/bin/caddy run --config /etc/fiordland-mirror/Caddyfile --adapter caddyfile
ReadOnlyPaths=/srv/fiordland-mirror /etc/fiordland-mirror/Caddyfile
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
CapabilityBoundingSet=
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RestrictNamespaces=true
LockPersonality=true
MemoryMax=256M
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

  cat > /etc/systemd/system/fiordland-mirror-sync.service <<'UNIT'
[Unit]
Description=Sync the Fiordland mirror
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=fiordland-mirror
Group=fiordland-mirror
EnvironmentFile=/etc/fiordland-mirror/sync.env
ExecStart=/bin/bash /usr/local/bin/fiordland-mirror-sync /srv/fiordland-mirror
ReadWritePaths=/srv/fiordland-mirror
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
UNIT

  cat > /etc/systemd/system/fiordland-mirror-sync.timer <<'UNIT'
[Unit]
Description=Sync the Fiordland mirror hourly

[Timer]
OnBootSec=5min
OnUnitActiveSec=1h
RandomizedDelaySec=10min

[Install]
WantedBy=timers.target
UNIT

  systemctl daemon-reload
  systemctl enable --now fiordland-mirror-web.service fiordland-mirror-sync.timer
  systemctl start fiordland-mirror-sync.service
  sleep 2
  curl -fsS -o /dev/null -w "local mirror answers: %{http_code}\n" http://127.0.0.1:8080/repo/lastupdate
  echo "install done"
}

install_tunnel() {
  local src="${2:-}"
  [ -n "$src" ] && [ -f "$src" ] || { echo "usage: setup.sh tunnel /path/to/tunnel.token" >&2; exit 1; }
  install -d -m 0750 "$ETC"
  install -m 0600 -o root -g root "$src" "$ETC/tunnel.token"
  shred -u "$src" 2>/dev/null || rm -f "$src"

  cat > /etc/systemd/system/fiordland-mirror-tunnel.service <<'UNIT'
[Unit]
Description=Fiordland mirror Cloudflare tunnel
After=network-online.target fiordland-mirror-web.service
Wants=network-online.target

[Service]
DynamicUser=yes
LoadCredential=tunnel:/etc/fiordland-mirror/tunnel.token
ExecStart=/usr/bin/cloudflared --no-autoupdate tunnel run --token-file %d/tunnel
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
CapabilityBoundingSet=
RestrictNamespaces=true
LockPersonality=true
MemoryMax=256M
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now fiordland-mirror-tunnel.service
  sleep 6
  systemctl is-active fiordland-mirror-tunnel.service
  echo "tunnel done"
}

case "$PHASE" in
  install) install_base ;;
  tunnel) install_tunnel "$@" ;;
  *) echo "usage: setup.sh [install|tunnel FILE]" >&2; exit 1 ;;
esac
