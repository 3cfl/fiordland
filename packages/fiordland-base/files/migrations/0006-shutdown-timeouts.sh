#!/usr/bin/env bash
set -euo pipefail
. /usr/lib/fiordland/lib.sh
if [ "$(systemctl is-enabled NetworkManager-wait-online.service 2>/dev/null || true)" = enabled ]; then
  systemctl disable NetworkManager-wait-online.service
fi
if booted; then
  systemctl daemon-reexec || true
fi
