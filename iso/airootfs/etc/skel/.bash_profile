[ -f ~/.bashrc ] && . ~/.bashrc
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = /dev/tty1 ]; then
  exec /usr/lib/plasma-dbus-run-session-if-needed startplasma-wayland > /tmp/plasma.log 2>&1
fi
