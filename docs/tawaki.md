# Installing and updating apps with tawaki

[tawaki](https://github.com/Fiordland-Linux/tawaki) is Fiordland's package manager. One command installs, removes and updates software, wherever it comes from. The same page is on the website at [fiordlandlinux.org/docs/apps](https://fiordlandlinux.org/docs/apps/).

## Where software comes from

tawaki looks in three places at once:

| Source | What it is |
| --- | --- |
| `pacman` | The system repositories: Arch Linux, Fiordland and CachyOS. Signed packages. |
| `flatpak` | Flathub, the app store for Flatpak apps. They run in a sandbox and bring their own runtimes. |
| `aur` | The Arch User Repository. Build scripts uploaded by users. Nobody at Arch or Fiordland reviews them. |

"Cleanest source" means the first place in your priority list that has the package: `pacman`, then `flatpak`, then `aur`. You can change the order in the [config](#settings).

One exception. If the first match is a Flatpak that needs a runtime of 50 MB or more that you do not have yet, tawaki takes a prebuilt package from another source instead, when there is one, and tells you how much it skipped. Turn this off with `prefer_light = false`.

## Commands

```
tawaki install NAME...      i
tawaki remove NAME...       r, rm
tawaki update               u, up
tawaki check
tawaki search WORDS...      s
tawaki list                 ls
```

### install

```
tawaki install firefox steam
tawaki install foo --from aur
```

It searches, prints one line per package showing which sources have it and which one it picked, then asks `Proceed with installation?`. Names are checked first, and anything that is not a valid package name (lowercase letters, digits and `@ . _ + -`) is refused. A package that is already installed is reported and skipped. If a name is found nowhere, nothing is installed.

`--from` forces a source: `pacman`, `flatpak` or `aur`. `-y` skips the questions.

### remove

```
tawaki remove firefox
```

Lists what it will remove and asks to confirm. It removes the package wherever it came from, including packages you installed with plain `pacman` or `flatpak`. `-y` skips the question.

### update

```
tawaki update
```

Counts what is waiting in each source, asks `Update now?`, then updates the system with `pacman -Syu`, then AUR packages, then Flatpaks. It asks for your password through `sudo`. `-y` skips the questions.

Before the system update, it deletes any `.sig` file in `/var/lib/pacman/sync` that is really an HTML error page left by a failed download, so the update does not stop on it.

When a system update changes the Fiordland release number, tawaki prints it, for example `Fiordland 0.9.0 -> 1.0.0`, with that release's notes. System changes that ship with a release are applied once, after the pre-update snapshot. See [rollback.md](rollback.md) for what to do if an update goes wrong.

### Update channel

Arch packages arrive through one of two channels. `stable` is a snapshot of the Arch repos that moves forward every two weeks, after Fiordland's install, update and boot tests pass. Security fixes arrive sooner. `rolling` gets packages the day Arch releases them: newer and less tested. Stable is the default.

```
fiordland-channel
fiordland-channel rolling
fiordland-channel stable
```

Without an argument it prints the current channel. With one it switches (it asks for your password through `sudo`), then run `tawaki update` to sync.

### check

```
tawaki check
tawaki check --json
```

Lists pending updates without installing anything. `--json` prints them for other programs; the Kuaka update app uses it.

### search

```
tawaki search obs
tawaki search obs --from flatpak
```

Searches every source at once, or only the one you name.

### list

```
tawaki list
tawaki list --from aur
```

Lists the packages that were installed with tawaki, with their source. Packages you installed another way are not shown. The list is kept in `~/.local/share/tawaki/installed.json`.

## Settings

tawaki works without any configuration. To change it, create `~/.config/tawaki/config.toml`. These are the defaults:

```toml
priority = ["pacman", "flatpak", "aur"]
aur_helper = "auto"
flatpak_scope = "user"
flatpak_remote = "flathub"
prefer_light = true
```

| Key | Values |
| --- | --- |
| `priority` | The order sources are tried in. A source you leave out is still searched, after the ones you list. |
| `aur_helper` | `auto` uses `paru` or `yay` if one is installed. `paru` or `yay` pick one. `none` always builds with `makepkg`. |
| `flatpak_scope` | `user` installs Flatpaks for your account only. `system` installs them for everyone. |
| `flatpak_remote` | The Flatpak remote to search. |
| `prefer_light` | `true` avoids Flatpaks that would pull in a large new runtime. |

A mistake in the file is reported with its path and tawaki stops, rather than guessing.

## About the AUR

AUR packages are build scripts, and building one runs code from a stranger. Prefer `pacman` and `flatpak`, and use `--from aur` only for packages you trust.

tawaki warns you before an AUR install. Unless you pass `-y`, it then asks `Review PKGBUILD for NAME?` (the default answer is yes). If you say yes, it opens the `PKGBUILD` in your pager (`$PAGER`, or `less`) and asks once more before building.

No AUR helper is installed by default. Without one, tawaki builds with `makepkg` and does not resolve dependencies that are only in the AUR. Install `paru` or `yay` yourself if you need that, and tawaki will use it.

## Other tools still work

`pacman` and `flatpak` work as usual. tawaki is a front end, not a replacement. Flathub's catalogue refreshes in the background through `tawaki-catalogue.timer`, so searches never wait on it.
