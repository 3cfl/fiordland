# crest

The Hyprland shell of [Fiordland Linux](https://fiordlandlinux.org), written in plain QML for [Quickshell](https://quickshell.org). There is no C++ plugin and nothing to compile.

crest 1 is a rewrite of the earlier Caelestia-based shell. It uses Material 3 Expressive shapes and spring motion, and puts translucent glass over Hyprland's blur.

## What's in it

- a bar with a workspace pill that morphs between workspaces, a clock, the tray, and network, audio, battery and notification indicators
- a launcher with fuzzy app search, a calculator (start with `=`) and emoji (start with `:`)
- notification popups and a unified dashboard with notifications, calendar, music, system stats and clipboard history
- quick settings for Wi-Fi, Bluetooth, power profile, do not disturb and night light, plus volume and brightness sliders and media controls
- Bluetooth pairing from quick settings: your devices, nearby devices, battery levels, and a prompt for pairing codes and PINs, answered through `bluetoothctl` running as the pairing agent
- on-screen displays for volume and brightness
- a lock screen that uses `ext-session-lock` and PAM, with optional fingerprint unlock
- a session menu, a workspace overview, a wallpaper picker and a settings window

Anything that isn't always on screen loads only when it's opened, so an idle desktop uses next to no CPU.

## Colours

When a wallpaper is set, `matugen` builds a Material colour scheme from it. When there is no wallpaper, or matugen fails, crest uses the Fiordland palette in `theme/Colours.qml`.

## Low-end mode

Low-end mode turns off blur, shadows and most animation. It switches on by itself under software rendering or with less than 4 GB of memory. You can also force it on or off under settings → performance.

## Running

```sh
qs -c crest
```

The package installs crest to `/etc/xdg/quickshell/crest`. Settings are saved to `~/.config/crest/config.json`, and the generated colour scheme is cached in `~/.local/state/crest`.

## Shortcuts and IPC

Hyprland binds keys to crest's global shortcuts as `hl.dsp.global("crest:<name>")`. The names are `launcher`, `emoji`, `quicksettings`, `notifications`, `clearNotifs`, `session`, `lock`, `overview`, `wallpaper`, `settings`, `mediaToggle`, `mediaNext`, `mediaPrev`, `mediaStop`, `volumeUp`, `volumeDown`, `volumeMute`, `brightnessUp` and `brightnessDown`.

Scripts can drive the same things over IPC:

```sh
qs -c crest ipc show
qs -c crest ipc call launcher toggle
qs -c crest ipc call lock lock
```

## The greeter

`crest-greeter/`, at the top of the repository, holds the login screen for greetd. It reuses crest's `theme/` and `components/`.

## Development

`tools/crest-qml.sh lint` runs qmllint over crest and the greeter, `unit` runs the JS unit tests, and `render` draws the main surfaces offscreen to PNG files. CI runs all three.

## Credits

crest's look and behaviour draw on these GPL-3.0 projects, and some of crest's patterns are adapted from them. Thanks to their authors.

- [Caelestia shell](https://github.com/caelestia-dots/shell) by the Caelestia contributors. The earlier crest shell was a fork of it.
- [end-4's dots-hyprland](https://github.com/end-4/dots-hyprland) and its illogical-impulse Quickshell config.
- [Quickshell](https://quickshell.org) by outfoxxed and contributors, which crest is built on.

The shape and motion tokens follow Google's [Material 3 Expressive](https://m3.material.io) guidelines. Icons come from Material Symbols Rounded.

## License

GPL-3.0-only, see [LICENSE](LICENSE).
