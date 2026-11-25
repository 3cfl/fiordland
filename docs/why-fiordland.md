# Why Fiordland, if you already run CachyOS

CachyOS is a fast, well-run Arch distribution, and Fiordland uses its kernel and gaming packages. This page says what Fiordland does differently, so you can decide whether that matters to you. Where CachyOS does something better or equally well, it says so.

## What Fiordland adds

- **A tested stable channel.** Arch packages come from a snapshot that moves forward every two weeks, after Fiordland's install, update and boot tests pass. Security fixes arrive sooner. CachyOS follows Arch as it lands, which is newer but less tested. If you want that on Fiordland too: `fiordland-channel rolling`.
- **System changes arrive with updates.** Fixes to an installed system (service defaults, timeouts, snapshot limits) ship as numbered migrations in `fiordland-base`. Each runs once, after the update or at boot, and is written to be safe twice. You never need to reinstall to get a newer ISO's defaults.
- **Snapshots you can boot and keep.** Every install is Btrfs with snapper. Each package update takes a snapshot, older snapshots show up in the GRUB menu, and `sudo fiordland-rollback` makes the one you booted permanent.
- **One package manager for three sources.** tawaki installs from pacman, Flathub or the AUR, picks the cleanest source, and avoids pulling a large Flatpak runtime when a native package exists.
- **Its own desktop and shell.** crest (a Hyprland shell), the rawaru installer with 11 desktops and 13 window managers, kuaka for updates and weka to switch desktops.
- **Settings that pick themselves on weak hardware.** `fiordland-tune` detects machines with less than 4 GB of memory, two CPU threads or no GPU acceleration and uses lighter memory settings on its own. You can switch to `low-end`, `balanced` or `performance` by hand.
- **Plain bug reports.** `fiordland report` writes the details a bug report needs to one file in your home folder, with your user and host names replaced. Nothing is uploaded.

## What both do

- CachyOS kernel, sched_ext schedulers (`fiordland-tune scx lavd`), zram, systemd-oomd, the CachyOS Proton and Wine builds, Steam and gaming tools.
- Firewall on by default, printing, Bluetooth, firmware updates, codecs and hardware video decoding out of the box.

## What CachyOS does that Fiordland does not

- **x86-64-v3 and v4 package builds.** CachyOS rebuilds the Arch repos for newer CPUs. Fiordland uses Arch's generic x86-64 packages, so one install runs on any 64-bit PC, and the stable channel can test exactly what Arch ships.
- **ananicy-cpp with a large rules set**, enabled by default. Fiordland ships systemd-oomd and leaves process priorities alone. ananicy-cpp is in the Arch repos if you want it.
- **More kernels and a longer track record.** CachyOS has several kernel variants and years of users. Fiordland 1 is the first release out of beta.

## Security notes

- The firewall (ufw) denies incoming connections by default and allows mDNS so network printers still show up.
- AppArmor is available (`sudo pacman -S apparmor`). Turning it on needs `lsm=landlock,lockdown,yama,integrity,apparmor,bpf` on the kernel command line in `/etc/default/grub`, then `sudo grub-mkconfig -o /boot/grub/grub.cfg` and `sudo systemctl enable apparmor`. It is not on by default because most desktop apps ship no profiles yet.
- Encrypted DNS is one command away: `sudo fiordland dns tls`.
