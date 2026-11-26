# Live wallpapers

Kererū plays Wallpaper Engine wallpapers on your Fiordland desktop. It is an optional extra and is not installed by default.

Wallpaper Engine is proprietary Windows software. You need to own it on Steam. Kererū only plays the wallpapers that Steam has downloaded for you. It can browse the Workshop for you, but Steam does the downloading. The drawing is done by the open-source [linux-wallpaperengine](https://github.com/Almamu/linux-wallpaperengine).

## Set it up

```
tawaki install kereru
```

1. In Steam, open **Settings → Compatibility** and turn on Steam Play for all other titles.
2. Install Wallpaper Engine. Kererū needs the assets it downloads. You don't have to run it.
3. Open **Live Wallpapers** from the app menu and click a wallpaper, or get new ones from the **workshop** tab.

From then on Kererū starts when you log in and keeps playing your pick. Its icon sits in the tray.

## Choosing wallpapers

The picker shows every wallpaper it finds, with a preview. Click **all screens** to set one wallpaper everywhere, or click a screen's name to give that screen its own. Search and the scene and video filters narrow the list.

Previews of wallpapers marked mature on the Workshop are blurred. Turn on **show mature previews** in the settings to see them.

Kererū plays scene and video wallpapers. Web and application wallpapers aren't supported yet. Web wallpapers show up greyed out, and you can't pick them.

## Safety

Workshop wallpapers are files made by strangers, so Kererū runs the engine in a [bubblewrap](https://github.com/containers/bubblewrap) sandbox. Inside it the engine has no network access and can't see your home folder. It can only read the wallpapers it is showing, Wallpaper Engine's assets, the system's libraries, and your display. When sound is on, it can also use your sound server.

Web wallpapers aren't supported because they would need a web browser engine running untrusted code.

## Getting new wallpapers

The **workshop** tab shows wallpapers from the Steam Workshop: trending, most subscribed or newest. Type in the search box and press Enter to search. The scene and video filters work here too. Web wallpapers are listed but greyed out.

1. Press **get** on a wallpaper. Steam opens its Workshop page.
2. Press **Subscribe** in Steam.
3. The button says **waiting for Steam** while Steam downloads it. When it's done, Kererū plays it and the button changes to **use**.

You never sign in to Kererū. Steam handles your account and the download. If Steam isn't installed, **get** opens the page in your web browser instead. Clicking a preview opens the wallpaper's Workshop page.

The tab reads Steam's public Workshop pages, item details and preview images over HTTPS. It needs no API key.

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
- **The workshop tab can't load.** It needs an internet connection to `steamcommunity.com` and `api.steampowered.com`. Your own wallpapers still work offline.
- **Get stays on waiting for Steam.** Make sure you pressed Subscribe in Steam and that the download has finished in Steam's Downloads page. Kererū keeps watching for two hours. After that, press **rescan** in the settings.
- **Every wallpaper fails to start.** The sandbox needs unprivileged user namespaces. Some hardened kernels turn them off. The engine's output in `~/.local/state/kereru/engine.log` will say so.
- **No tray icon.** Your panel needs to support tray icons (StatusNotifierItem). The wallpaper still plays. Use the picker or the terminal commands.
- **Stop it starting at login.** Turn off **start when I log in** in the picker.
- **Remove it.** `tawaki remove kereru`. Your settings stay in `~/.config/kereru`.
