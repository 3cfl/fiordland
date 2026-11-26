# Live wallpapers

Kererū plays Wallpaper Engine wallpapers on your Fiordland desktop. It is an optional extra and is not installed by default.

Wallpaper Engine is proprietary Windows software. You need to own it on Steam. Kererū only plays the wallpapers that Steam has already downloaded for you. The drawing is done by the open-source [linux-wallpaperengine](https://github.com/Almamu/linux-wallpaperengine).

## Set it up

```
tawaki install kereru
```

1. In Steam, open **Settings → Compatibility** and turn on Steam Play for all other titles.
2. Install Wallpaper Engine. Kererū needs the assets it downloads. You don't have to run it.
3. Subscribe to wallpapers on the Steam Workshop and wait for Steam to download them.
4. Open **Live Wallpapers** from the app menu and click a wallpaper.

From then on Kererū starts when you log in and keeps playing your pick. Its icon sits in the tray.

## Choosing wallpapers

The picker shows every wallpaper it finds, with a preview. Click **all screens** to set one wallpaper everywhere, or click a screen's name to give that screen its own. Search and the scene, video and web filters narrow the list.

Previews of wallpapers marked mature on the Workshop are blurred. Turn on **show mature previews** in the settings to see them.

Scene and video wallpapers work best. Web wallpapers use more memory. Application wallpapers are not supported.

## Pausing

The tray menu has **Pause** and **Resume**. By default the wallpaper also pauses:

- while an app is fullscreen, such as a game or a video
- while a laptop runs on battery

Turn either off in the picker's settings or from the tray menu. Sound is off until you turn on **play sound**.

## From the terminal

```
kereru --pause
kereru --resume
kereru --toggle
kereru --next
kereru --status
```

`kereru --toggle` works well bound to a key in your window manager.

## When something goes wrong

- **The picker says Wallpaper Engine isn't installed.** Install it in Steam with Steam Play turned on. Scene wallpapers need its assets.
- **A wallpaper is black or keeps crashing.** Kererū stops retrying after a few crashes and tells you so. Pick another one. The engine's output is in `~/.local/state/kereru/engine.log`.
- **No tray icon.** Your panel needs to support tray icons (StatusNotifierItem). The wallpaper still plays. Use the picker or the terminal commands.
- **Stop it starting at login.** Turn off **start when I log in** in the picker.
- **Remove it.** `tawaki remove kereru`. Your settings stay in `~/.config/kereru`.
