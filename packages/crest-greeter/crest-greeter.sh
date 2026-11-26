#!/usr/bin/env bash
set -euo pipefail

shell=/usr/share/crest-greeter/shell.qml
test=0
case "${1:-}" in
  --test) test=1 ;;
  "") ;;
  *) echo "usage: crest-greeter [--test]" >&2; exit 2 ;;
esac

if [ "$(id -u)" -eq 0 ]; then
  echo "crest-greeter: refusing to run as root" >&2
  exit 1
fi

export QT_LOGGING_RULES='*.debug=false;quickshell.service.greetd.debug=false'
export QS_NO_RELOAD_POPUP=1
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
unset QT_QUICK_BACKEND

kbd=/etc/X11/xorg.conf.d/00-keyboard.conf
xkb_opt() {
  sed -n -E 's/^[[:space:]]*Option[[:space:]]+"'"$1"'"[[:space:]]+"([^"]*)".*/\1/p' "$kbd" 2>/dev/null | head -n 1
}
if [ -r "$kbd" ]; then
  for pair in XkbLayout:XKB_DEFAULT_LAYOUT XkbVariant:XKB_DEFAULT_VARIANT XkbModel:XKB_DEFAULT_MODEL XkbOptions:XKB_DEFAULT_OPTIONS; do
    value="$(xkb_opt "${pair%%:*}")"
    if [[ $value =~ ^[A-Za-z0-9_,:+()-]{1,128}$ ]]; then
      export "${pair#*:}=$value"
    fi
  done
fi

if [ "$test" -eq 1 ]; then
  export CREST_DEMO=1
  exec qs -p "$shell"
fi

exec cage -s -m last -- qs -p "$shell"
