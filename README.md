<h1 align="center">Fiordland Linux</h1>

<p align="center">Arch-based, fast and stable, with its own shell, installer and package manager.<br>
Named after the Fiordland penguin, the tawaki.</p>

<p align="center"><a href="https://fiordland.apollo44.lat">fiordland.apollo44.lat</a></p>

![Desktop](docs/screenshots/desktop.webp)

![Terminal](docs/screenshots/terminal.webp)

## What's inside

| Path | What it is |
|------|------------|
| `crest/` | The desktop shell. Top bar, dashboard, launcher, notifications, lock screen, settings. Quickshell + a C++ plugin, forked from Caelestia. |
| `tawaki/` | Package manager in Rust. One command that picks the cleanest source: pacman, then Flathub, then AUR. |
| `rawaru/` | Graphical installer (PySide6 + QML). Btrfs with snapper snapshots, zram, systemd-boot or GRUB, GPU driver detection, CachyOS or Arch kernel. |
| `packages/` | PKGBUILDs for everything above, plus `fiordland-desktop` (Hyprland config, theme, icons, defaults). |
| `iso/` | archiso profile for the live ISO. |
| `web/` | The website. |
| `tools/` | Build helpers: chroot builds, colour scheme and wallpaper generators, VM control. |

## tawaki

```
tawaki install spotify      i
tawaki remove spotify       r, rm
tawaki update               u, up
tawaki search obs           s
tawaki list                 ls
tawaki install foo --from aur
```

If the top pick is a Flatpak that would pull a big runtime you don't have yet, tawaki takes a prebuilt pacman or AUR package instead, and tells you how much it skipped. The Flathub catalogue refreshes in the background, so searches never wait on it.

Config: `~/.config/tawaki/config.toml`

```toml
priority = ["pacman", "flatpak", "aur"]
aur_helper = "auto"
flatpak_scope = "user"
flatpak_remote = "flathub"
prefer_light = true
```

## Kernel and drivers

Installs default to the [CachyOS](https://cachyos.org) kernel (`linux-cachyos`), pulled from CachyOS's baseline `[cachyos]` repo, which sits after the Arch repos so only CachyOS-only packages come from it. The stock Arch `linux` kernel stays installed as a second boot entry. Pick "Arch kernel" in the installer to skip CachyOS entirely.

The installer detects the GPU: NVIDIA Turing and newer get `nvidia-open` (plus `linux-cachyos-nvidia-open`), older NVIDIA cards use nouveau, Intel and AMD get the matching Vulkan and VA-API drivers. Multilib is enabled for Steam and Wine.

## crest

Runs with `qs -c crest`. Settings live in `~/.config/caelestia/shell.json` and in the settings app (Super + I).

Changes from Caelestia:

- Floating top bar instead of the side bar and screen frame; panels and popouts drop down from it
- Grey and baby blue scheme (`fiordland`), Inter everywhere
- Pill workspace indicator, single-line clock that opens the dashboard
- Fiordland wallpaper, no mascot artwork
- Terminal system info toggle (Settings → Apps → Terminal)

## Building

Needs an Arch-based host with `archiso`, `devtools` and `base-devel`.

```
./build.sh            build all packages and the ISO into out/
SKIP_AUR=1 ./build.sh skip the chroot builds of crest and its AUR deps
./vm.sh --share       boot the ISO in QEMU
```

Installed systems use the package repo at `https://fiordland.apollo44.lat/repo/x86_64`.

## Credits

- [Caelestia shell](https://github.com/caelestia-dots/shell) by the Caelestia contributors, which crest is forked from (GPL-3.0)
- [archiso](https://gitlab.archlinux.org/archlinux/archiso), the base of the ISO profile
- AUR maintainers of the bundled PKGBUILDs in `packages/aur/`
- Tawaki photos on the website from Wikimedia Commons, credited per photo

## License

GPL-3.0. See [LICENSE](LICENSE).
