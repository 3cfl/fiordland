#!/usr/bin/env bash
set -e
pacman -Q fiordland-gaming >/dev/null 2>&1 && exit 0
systemctl reset-failed fiordland-gaming-install.service 2>/dev/null || true
systemd-run --quiet --collect --on-active=20 --property=TimeoutStopSec=2min --unit=fiordland-gaming-install /usr/lib/fiordland/install-gaming
