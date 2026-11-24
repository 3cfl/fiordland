#!/bin/bash
set -euo pipefail

SRC="${FIORDLAND_SRC:-https://fiordlandlinux.org}"
DEST="${1:?usage: fiordland-mirror-sync /path/to/mirror}"
SKIP_ISO="${FIORDLAND_SKIP_ISO:-0}"

mkdir -p "$DEST/repo/x86_64" "$DEST/iso"
exec 9>"$DEST/.sync.lock"
flock -n 9 || exit 0

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
curl -fsS --retry 3 --max-time 60 "$SRC/mirrors/manifest.txt" -o "$work/manifest"

valid='^(repo/x86_64/[A-Za-z0-9._+@:-]+|repo/lastupdate|iso/[A-Za-z0-9._+-]+)$'
grep -Eq ' repo/x86_64/fiordland\.db' "$work/manifest" || { echo "manifest looks wrong, aborting" >&2; exit 1; }

fetch() {
  local sum="$1" size="$2" rel="$3" target="$DEST/$3"
  if [ -f "$target" ] && [ "$(stat -c %s "$target")" = "$size" ]; then
    [ "$(sha256sum "$target" | cut -d' ' -f1)" = "$sum" ] && return 0
  fi
  echo "fetching $rel"
  curl -fsS --retry 3 -C - "$SRC/$rel" -o "$target.part"
  [ "$(sha256sum "$target.part" | cut -d' ' -f1)" = "$sum" ] || { rm -f "$target.part"; echo "checksum mismatch for $rel" >&2; return 1; }
  mv "$target.part" "$target"
}

pass() {
  while read -r sum size rel; do
    [[ "$rel" =~ $valid ]] || continue
    [ "$SKIP_ISO" = 1 ] && [[ "$rel" == iso/*.iso ]] && continue
    case "$rel" in
      repo/x86_64/*.db*|repo/x86_64/*.files*|repo/lastupdate|iso/latest.json) [ "$1" = last ] || continue ;;
      *) [ "$1" = first ] || continue ;;
    esac
    fetch "$sum" "$size" "$rel"
  done < "$work/manifest"
}

pass first
pass last

awk '{print $3}' "$work/manifest" | sort > "$work/keep"
for dir in repo/x86_64 iso; do
  find "$DEST/$dir" -maxdepth 1 -type f ! -name '*.part' -printf "$dir/%f\n" | sort > "$work/have"
  comm -13 "$work/keep" "$work/have" | while read -r stale; do
    [ "$SKIP_ISO" = 1 ] && [[ "$stale" == iso/* ]] && continue
    echo "removing $stale"
    rm -f "$DEST/$stale"
  done
done

latest=$(sed -n 's/.*"file": *"\([^"]*\)".*/\1/p' "$DEST/iso/latest.json" 2>/dev/null || true)
if [[ "$latest" =~ ^[A-Za-z0-9._+-]+\.iso$ ]] && [ -f "$DEST/iso/$latest" ]; then
  ln -sfn "$latest" "$DEST/iso/fiordland-latest.iso"
fi
echo "sync complete"
