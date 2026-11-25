#!/usr/bin/env bash
set -euo pipefail
. /usr/lib/fiordland/lib.sh
enable_if_disabled bluetooth.service cups.socket avahi-daemon.service ufw.service power-profiles-daemon.service \
  fwupd-refresh.timer paccache.timer plocate-updatedb.timer fstrim.timer snapper-cleanup.timer reflector.timer
if [ -f /etc/ufw/ufw.conf ] && ! grep -q '^ENABLED=yes' /etc/ufw/ufw.conf; then
  set_conf /etc/ufw/ufw.conf ENABLED yes
fi
if [ "$(findmnt -no FSTYPE / 2>/dev/null || true)" = btrfs ]; then
  enable_if_disabled btrfs-scrub@-.timer
fi
if [ -f /etc/nsswitch.conf ] && ! grep -q mdns_minimal /etc/nsswitch.conf; then
  sed -i -E '0,/^(hosts:.*)\bresolve\b/s//\1mdns_minimal [NOTFOUND=return] resolve/' /etc/nsswitch.conf
fi
