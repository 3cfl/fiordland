#!/usr/bin/env bash
set -euo pipefail
. /usr/lib/fiordland/lib.sh
f=/etc/pam.d/greetd
[ -f "$f" ] || exit 0
[ -f /usr/lib/security/pam_gnome_keyring.so ] || exit 0
grep -q pam_gnome_keyring "$f" && exit 0
backup "$f" >/dev/null
tmp=$(mktemp "$f.XXXXXX")
awk '
  { print }
  /^auth[[:space:]]+include[[:space:]]+system-local-login/ { print "auth       optional     pam_gnome_keyring.so" }
  /^session[[:space:]]+include[[:space:]]+system-local-login/ { print "session    optional     pam_gnome_keyring.so auto_start" }
' "$f" > "$tmp"
chmod --reference="$f" "$tmp"
mv -f "$tmp" "$f"
