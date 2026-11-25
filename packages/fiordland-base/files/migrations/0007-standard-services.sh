#!/usr/bin/env bash
set -euo pipefail
. /usr/lib/fiordland/lib.sh
enable_if_disabled bluetooth.service cups.socket avahi-daemon.service power-profiles-daemon.service \
  fwupd-refresh.timer paccache.timer plocate-updatedb.timer fstrim.timer snapper-cleanup.timer reflector.timer
other_firewall() {
  local u
  for u in firewalld.service nftables.service iptables.service ip6tables.service; do
    [ "$(systemctl is-enabled "$u" 2>/dev/null || true)" = enabled ] && return 0
  done
  return 1
}
unit_enabled() {
  [ "$(systemctl is-enabled "$1" 2>/dev/null || true)" = enabled ]
}
if command -v ufw >/dev/null && [ -f /etc/ufw/ufw.conf ] && ! grep -q '^ENABLED=yes' /etc/ufw/ufw.conf && ! other_firewall; then
  if unit_enabled sshd.service || unit_enabled sshd.socket; then
    ufw limit 22/tcp comment ssh >/dev/null
  fi
  if [ -x /usr/bin/kdeconnectd ] || [ -x /usr/lib/kdeconnectd ]; then
    ufw allow 1714:1764/tcp comment kdeconnect >/dev/null
    ufw allow 1714:1764/udp comment kdeconnect >/dev/null
  fi
  set_conf /etc/ufw/ufw.conf ENABLED yes
  enable_if_disabled ufw.service
fi
if [ "$(findmnt -no FSTYPE / 2>/dev/null || true)" = btrfs ]; then
  enable_if_disabled btrfs-scrub@-.timer
fi
if [ -f /etc/nsswitch.conf ] && ! grep -q mdns_minimal /etc/nsswitch.conf; then
  sed -i -E '0,/^(hosts:.*)\bresolve\b/s//\1mdns_minimal [NOTFOUND=return] resolve/' /etc/nsswitch.conf
fi
