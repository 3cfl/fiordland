#!/usr/bin/env bash
set -e
[ -f /boot/grub/grub.cfg ] || exit 0
if [ -f /etc/default/grub ] && ! grep -q '^GRUB_DISABLE_BOOTNEXT=' /etc/default/grub; then
  echo GRUB_DISABLE_BOOTNEXT=true >> /etc/default/grub
fi
[ -e /etc/grub.d/42_fiordland_safe ] && mv /etc/grub.d/42_fiordland_safe /etc/grub.d/11_fiordland_safe
[ "$(systemctl is-enabled grub-btrfsd 2>/dev/null)" = disabled ] && systemctl enable grub-btrfsd
grub-mkconfig -o /boot/grub/grub.cfg
