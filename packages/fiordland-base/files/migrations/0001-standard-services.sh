#!/usr/bin/env bash
set -e
for s in NetworkManager bluetooth systemd-timesyncd fstrim.timer power-profiles-daemon snapper-timeline.timer \
         snapper-cleanup.timer reflector.timer tawaki-catalogue.timer cups.socket avahi-daemon ufw systemd-oomd \
         fwupd-refresh.timer paccache.timer pkgfile-update.timer; do
  st=$(systemctl is-enabled "$s" 2>/dev/null || true)
  [ "$st" = disabled ] && systemctl enable "$s"
done
if [ -f /etc/ufw/ufw.conf ]; then
  sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf
fi
if [ -f /etc/nsswitch.conf ] && ! grep -q mdns_minimal /etc/nsswitch.conf; then
  sed -i -E '0,/^(hosts:.*)\bresolve\b/s//\1mdns_minimal [NOTFOUND=return] resolve/' /etc/nsswitch.conf
fi
true
