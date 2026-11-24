#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/../.."
cand=${1:?usage: test.sh YYYY/MM/DD [BASE_YYYY/MM/DD]}
base=${2:-$(curl -fsS https://fiordlandlinux.org/stable/date 2>/dev/null || echo "$cand")}
vmc() { python3 tools/vmctl.py exec "$1"; }
log() { printf '\n== %s\n' "$*"; }

wait_guest() {
  for _ in $(seq 60); do timeout 10 python3 tools/vmctl.py exec true >/dev/null 2>&1 && return 0; sleep 5; done
  echo "guest agent never came up"; return 1
}

boot() {
  ./vm.sh --headless "$@" > vm/test-qemu.log 2>&1 &
  sleep 5
  wait_guest
}

halt() {
  vmc 'systemctl poweroff' >/dev/null 2>&1 || true
  for _ in $(seq 30); do pgrep -f "qemu-system-x86_64.*vm/disk.qcow2" >/dev/null || return 0; sleep 2; done
  pkill -f "qemu-system-x86_64.*vm/disk.qcow2" || true
}

install_at() {
  log "install from $1"
  boot --fresh
  vmc "printf %s '{\"disk\":\"/dev/vda\",\"username\":\"tester\",\"password\":\"test\",\"hostname\":\"stabletest\",\"desktop\":\"${DESKTOP:-plasma}\",\"autologin\":true,\"channel\":\"stable\",\"stable_server\":\"https://archive.archlinux.org/repos/$1/\$repo/os/\$arch\"}' > /root/t.json; python3 /usr/lib/rawaru/engine.py /root/t.json > /root/t.log 2>&1; rc=\$?; tail -c 400 /root/t.log; exit \$rc"
  halt
}

check() {
  log "boot check: $1"
  boot --disk
  sleep 45
  local script
  script=$(cat <<'REMOTE'
f=$(systemctl --failed --no-legend --plain | grep -v "^$" || true); echo "kernel $(uname -r)"; echo "failed: ${f:-none}"; loginctl list-sessions --no-legend | grep -q tester || { echo "no desktop session"; exit 1; }; [ -z "$f" ]
REMOTE
)
  vmc "$script"
}

install_at "$base"
check "fresh install at $base"
log "update $base -> $cand"
vmc "echo 'Server = https://archive.archlinux.org/repos/$cand/\$repo/os/\$arch' > /etc/pacman.d/fiordland-stable; pacman -Syu --noconfirm > /root/u.log 2>&1; rc=\$?; tail -5 /root/u.log; exit \$rc"
halt
check "after update to $cand"
halt
if [ "$base" != "$cand" ]; then
  install_at "$cand"
  check "fresh install at $cand"
  halt
fi
log "PASS $cand"
