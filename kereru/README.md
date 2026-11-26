# Kererū

Live wallpapers for Fiordland Linux. Kererū plays the Wallpaper Engine
wallpapers you have downloaded from the Steam Workshop on your desktop, with a
tray icon to pause and switch them and a picker with previews.

Wallpaper Engine is proprietary software. You need to own it on Steam. Kererū
only plays the wallpapers and assets that Steam has already downloaded to your
machine. The drawing is done by the open-source
[linux-wallpaperengine](https://github.com/Almamu/linux-wallpaperengine).

## Install

Kererū is an optional extra:

```sh
tawaki install kereru
```

or `sudo pacman -S kereru`. Then:

1. In Steam, turn on Steam Play for all titles and install Wallpaper Engine.
   It downloads the shared assets that scene wallpapers need. You don't have to
   run it.
2. Subscribe to some wallpapers on the Steam Workshop and let Steam download
   them.
3. Open **Live Wallpapers** from the app menu and pick one.

Kererū starts on its own when you log in. On Hyprland, Fiordland starts it from
its Hyprland config. On niri, GNOME, KDE and other desktops it uses XDG autostart.
On sway, labwc, i3, bspwm and openbox, rawaru adds it to your window manager's
startup.

## Using it

- **Picker**: choose a wallpaper for all screens, or a different one for each
  screen. Previews of wallpapers marked mature are blurred until you choose to
  show them.
- **Tray**: pause and resume, next wallpaper, switch, sound, open the picker,
  quit. Left click opens the picker.
- **Pausing**: by default the wallpaper pauses while an app is fullscreen and
  while a laptop runs on battery. You can turn either off.
- **Sound** is off by default.

From a terminal:

```
kereru             open the picker
kereru --tray      run the background service with a tray icon
kereru --pause     pause
kereru --resume    resume
kereru --toggle    pause or resume
kereru --next      switch to the next wallpaper
kereru --status    show what is playing
```

Settings live in `~/.config/kereru/kereru.conf`. The engine's output goes to
`~/.local/state/kereru/engine.log`. To stop Kererū from starting at login, turn
off "start when I log in" in the picker's settings.

## Wallpaper folders

Kererū looks in each Steam library for Workshop items (app 431960) and for
Wallpaper Engine's own `projects/myprojects` and `projects/defaultprojects`. It
also looks in `~/.local/share/kereru/wallpapers`, where each wallpaper is a folder
with a `project.json`. Native Steam, Flatpak Steam and Snap Steam are all found.

Scene and video wallpapers work best. Web wallpapers work too, but they use more
memory. Application wallpapers are not supported.

## License

GPL-3.0-only.
