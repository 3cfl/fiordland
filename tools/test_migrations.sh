#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
files=$here/packages/fiordland-base/files
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fails=0

check() {
  if [ "$2" = "$3" ]; then
    echo "ok   $1"
  else
    echo "FAIL $1: wanted [$2], got [$3]"
    fails=1
  fi
}

. "$files/lib.sh"

printf 'A=1\n#GRUB_TOP_LEVEL="/x"\nB=2\n' > "$T/grub"
chmod 640 "$T/grub"
set_conf "$T/grub" GRUB_TOP_LEVEL '"/boot/vmlinuz-linux-fiord"'
check "set_conf replaces a commented key in place" 'A=1
GRUB_TOP_LEVEL="/boot/vmlinuz-linux-fiord"
B=2' "$(cat "$T/grub")"
check "set_conf keeps the file mode" 640 "$(stat -c %a "$T/grub")"
set_conf "$T/grub" GRUB_TOP_LEVEL '"/y"'
check "set_conf is idempotent" 1 "$(grep -c GRUB_TOP_LEVEL "$T/grub")"
set_conf "$T/grub" NEW_KEY yes
check "set_conf appends a missing key" NEW_KEY=yes "$(tail -1 "$T/grub")"
unset_conf "$T/grub" GRUB_TOP_LEVEL
check "unset_conf removes the key" 0 "$(grep -c GRUB_TOP_LEVEL "$T/grub" || true)"
rc=0
set_conf "$T/grub" 'X;rm' 1 || rc=$?
check "set_conf rejects bad keys" 2 "$rc"

mk_migrate() {
  sed -e "s#^DIR=.*#DIR=$T/m#" -e "s#^STATE=.*#STATE=$T/state#" "$files/fiordland-migrate" > "$T/fiordland-migrate"
  mkdir -p "$T/m"
  local n
  for n in 0001-a 0005-b 0006-c 0010-d; do
    printf '#!/usr/bin/env bash\ntrue\n' > "$T/m/$n.sh"
  done
}
mk_migrate
bash "$T/fiordland-migrate" --stamp
check "--stamp covers only what the installer does" '0001-a
0005-b' "$(cat "$T/state")"
bash "$T/fiordland-migrate" --stamp
check "--stamp twice adds nothing" 2 "$(wc -l < "$T/state")"
check "--list shows pending migrations" 'applied  0001-a
applied  0005-b
pending  0006-c
pending  0010-d' "$(bash "$T/fiordland-migrate" --list)"

snap=$T/snapper
printf 'NUMBER_CLEANUP="yes"\nNUMBER_LIMIT="50"\nNUMBER_LIMIT_IMPORTANT="10"\nTIMELINE_CLEANUP="no"\n' > "$snap"
sed -e "s#^c=.*#c=$snap#" -e "s#^\. /usr/lib/fiordland/lib.sh#. $files/lib.sh#" \
  -e 's#^enable_if_disabled .*#true#' "$files/migrations/0008-snapper-cleanup.sh" > "$T/0008.sh"
bash "$T/0008.sh"
bash "$T/0008.sh"
check "snapper cleanup sets the number limit" 'NUMBER_LIMIT="10"' "$(grep '^NUMBER_LIMIT=' "$snap")"
check "snapper cleanup turns timeline cleanup on" 'TIMELINE_CLEANUP="yes"' "$(grep '^TIMELINE_CLEANUP=' "$snap")"
check "snapper cleanup adds a free space limit once" 1 "$(grep -c '^FREE_LIMIT=' "$snap")"
printf 'NUMBER_LIMIT="25"\n' > "$snap"
bash "$T/0008.sh"
check "snapper cleanup keeps a custom limit" 'NUMBER_LIMIT="25"' "$(grep '^NUMBER_LIMIT=' "$snap")"

for f in "$files"/migrations/*.sh; do
  if bash -n "$f"; then echo "ok   syntax $(basename "$f")"; else echo "FAIL syntax $f"; fails=1; fi
done
grep -L 'set -e' "$files"/migrations/*.sh | while read -r f; do echo "FAIL $f has no set -e"; done | grep . && fails=1

for f in "$files"/system/systemd/system.conf.d/*.conf "$files"/system/systemd/user.conf.d/*.conf; do
  grep -q '^\[Manager\]$' "$f" || { echo "FAIL $f has no [Manager] section"; fails=1; }
done
check "system stop timeout" DefaultTimeoutStopSec=10s "$(grep -h DefaultTimeoutStopSec "$files"/system/systemd/system.conf.d/*.conf)"
check "user stop timeout" DefaultTimeoutStopSec=5s "$(grep -h DefaultTimeoutStopSec "$files"/system/systemd/user.conf.d/*.conf)"

exit "$fails"
