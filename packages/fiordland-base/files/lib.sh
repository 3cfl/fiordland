#!/usr/bin/env bash

booted() {
  [ -d /run/systemd/system ]
}

enable_if_disabled() {
  local u st
  for u in "$@"; do
    st=$(systemctl is-enabled "$u" 2>/dev/null || true)
    if [ "$st" = disabled ]; then
      systemctl enable "$u" || true
    fi
  done
}

backup() {
  local f=$1 b
  b="$f.fiordland-$(date +%Y%m%d%H%M%S)"
  [ -f "$f" ] && cp -a "$f" "$b"
  printf '%s\n' "$b"
}

set_conf() {
  local file=$1 key=$2 value=$3 tmp
  [[ $key =~ ^[A-Z_][A-Z0-9_]*$ ]] || return 2
  tmp=$(mktemp "$file.XXXXXX")
  awk -v k="$key" -v v="$value" '
    BEGIN { done = 0 }
    $0 ~ "^[[:space:]]*#?[[:space:]]*" k "=" && !done { print k "=" v; done = 1; next }
    $0 ~ "^[[:space:]]*" k "=" { next }
    { print }
    END { if (!done) print k "=" v }
  ' "$file" > "$tmp"
  chmod --reference="$file" "$tmp"
  mv -f "$tmp" "$file"
}

unset_conf() {
  local file=$1 key=$2 tmp
  [[ $key =~ ^[A-Z_][A-Z0-9_]*$ ]] || return 2
  tmp=$(mktemp "$file.XXXXXX")
  grep -v -E "^[[:space:]]*$key=" "$file" > "$tmp" || true
  chmod --reference="$file" "$tmp"
  mv -f "$tmp" "$file"
}

grub_regen() {
  local cfg=/boot/grub/grub.cfg new
  [ -f "$cfg" ] || return 0
  command -v grub-mkconfig >/dev/null || return 0
  new=$(mktemp /boot/grub/.grub.cfg.XXXXXX)
  if ! grub-mkconfig -o "$new"; then
    rm -f "$new"
    return 1
  fi
  if command -v grub-script-check >/dev/null && ! grub-script-check "$new"; then
    rm -f "$new"
    return 1
  fi
  if ! grep -q "menuentry " "$new"; then
    rm -f "$new"
    return 1
  fi
  cp -a "$cfg" "$cfg.fiordland-old"
  chmod --reference="$cfg" "$new"
  mv -f "$new" "$cfg"
}
