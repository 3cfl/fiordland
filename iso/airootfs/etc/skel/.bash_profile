[ -f ~/.bashrc ] && . ~/.bashrc
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = /dev/tty1 ]; then
  exec start-hyprland > /tmp/hyprland.log 2>&1
fi
