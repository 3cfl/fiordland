# linux-fiord

`linux-fiord` is Fiordland's own kernel. It is a fork of the [CachyOS](https://github.com/CachyOS/linux-cachyos) kernel packaging, built from the same signed CachyOS kernel source, with defaults picked so one package works well on a ten-year-old laptop and on a current gaming desktop.

It ships as two packages:

| Package | What it has |
| --- | --- |
| `linux-fiord` | The kernel image, modules and `/usr/lib/sysctl.d/70-linux-fiord.conf`. Provides `NTSYNC-MODULE`, `WIREGUARD-MODULE`, `KSMBD-MODULE`, `V4L2LOOPBACK-MODULE`, `VHBA-MODULE`, `VIRTUALBOX-GUEST-MODULES`, `ADIOS-MODULE`. |
| `linux-fiord-headers` | Everything DKMS needs to build out-of-tree modules (NVIDIA, VirtualBox, ZFS and so on). Provides `LINUX-HEADERS`. |

`uname -r` shows the flavour, for example `7.3.6-1-fiord`.

## Defaults

| Setting | linux-fiord | linux-cachyos PKGBUILD default | Arch `linux` |
| --- | --- | --- | --- |
| CPU scheduler | BORE on top of EEVDF | EEVDF (BORE is a build option) | EEVDF |
| sched_ext | on | on | on |
| Timer | 1000 Hz, tickless | 1000 Hz, tickless | 300 Hz |
| Preemption | full, with `PREEMPT_DYNAMIC` | full | dynamic |
| Compiler | GCC, `-O2`, no LTO | Clang ThinLTO, `-O3` | GCC, `-O2` |
| CPU target | x86-64 baseline (v1) | native for local builds, v3/v4 in the CachyOS repos | x86-64 baseline |
| TCP congestion control | BBRv3 with the `fq` qdisc | CUBIC | CUBIC |
| NTSYNC | built in | module | module |
| Transparent huge pages | `madvise` | `always` | |
| zswap | built in, off by default, zstd | on by default, zstd | |
| zram | lz4 and zstd backends, zstd default | same | |
| MGLRU | on | on | on |
| Module compression | zstd | zstd | zstd |

Security hardening is kept as CachyOS ships it: the lockdown LSM is built in and can be enabled with `lockdown=integrity` or `lockdown=confidentiality`, landlock and yama are active, `init_on_alloc` is on by default, kernel stack offsets are randomised on every syscall, and Intel IBT, the strong stack protector, hardened usercopy and hardened freelists stay on. Clang CFI is not enabled in CachyOS's config and stays off here, since the default build uses GCC.

### Why these choices

- **x86-64 v1.** CachyOS's optimised repos need x86-64-v3 or v4, which leaves out older CPUs that are otherwise fine for a desktop. linux-fiord runs on any 64-bit x86 CPU. The kernel itself gains little from v3, because it does not use vector instructions in hot paths.
- **1000 Hz.** BORE's default minimum slice is 2 ms, and with a 1 ms tick the scheduler can end a slice on time instead of rounding it up to the next tick (3.3 ms at 300 Hz). The idle cost is close to zero, because idle CPUs stop the tick. The extra interrupts on a busy core cost well under 1% even on old dual-core machines, and desktops feel the latency more than the throughput.
- **Full preemption with `PREEMPT_DYNAMIC`.** Best latency by default, and anyone who wants throughput can boot with `preempt=voluntary` or `preempt=lazy`, without a different kernel.
- **GCC `-O2`, no LTO.** The package has to build reliably inside the 6 hour GitHub Actions limit. ThinLTO with Clang is a few percent faster in some benchmarks but much slower and heavier to build, and every DKMS module would then need Clang. GCC also matches what DKMS uses by default.
- **THP `madvise`.** `always` can waste a lot of memory on machines with 4 to 8 GB. Programs that benefit from huge pages, such as databases, JVMs and some games, ask for them with `madvise`.
- **zswap off by default.** Fiordland sets up zram swap, and running zswap in front of zram compresses every page twice. If you use a swap file or partition instead, turn zswap on with `zswap.enabled=1`.
- **BBRv3 with `fq`.** Better throughput and lower latency on lossy links such as Wi-Fi, and it is fair to CUBIC flows.
- **NTSYNC built in.** Wine and Proton find `/dev/ntsync` without loading a module.
- **Debug options.** `SCHEDSTATS`, `PM_DEBUG` and the stack tracer are off. BTF debug info stays, because sched_ext and BPF tools need it.

The sysctl file sets `vm.max_map_count = 1048576`, which some games and Proton titles need. This is the same value Arch's `filesystem` package uses; shipping it with the kernel keeps it if that changes.

Everything above is a config fragment (`packages/linux-fiord/fiord.config`) applied over the CachyOS config, plus the BORE patch from CachyOS's kernel-patches repo. There are no Fiordland-specific kernel patches. The build stops if any line of the fragment does not end up in the final config.

### Changing behaviour at runtime

| What | How |
| --- | --- |
| Preemption model | `preempt=none`, `voluntary`, `full` or `lazy` on the kernel command line |
| BORE | `sysctl kernel.sched_bore=0` to fall back to plain EEVDF |
| sched_ext schedulers | install `scx-scheds` and run one, for example `sudo scx_lavd` |
| TCP congestion control | `sysctl net.ipv4.tcp_congestion_control=cubic` |
| Transparent huge pages | `echo always \| sudo tee /sys/kernel/mm/transparent_hugepage/enabled` |
| zswap | `zswap.enabled=1` on the kernel command line |

## Switching to linux-fiord

Keep a second kernel installed (the stock Arch `linux` or `linux-cachyos`) so you can boot it if something goes wrong.

```
sudo pacman -S linux-fiord linux-fiord-headers
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

mkinitcpio builds the initramfs as part of the install. Reboot and pick linux-fiord under "Advanced options" in GRUB, then check with `uname -r`. To boot it by default, add `GRUB_TOP_LEVEL="/boot/vmlinuz-linux-fiord"` to `/etc/default/grub` and run `grub-mkconfig` again.

### NVIDIA

The prebuilt `linux-cachyos-nvidia-open` module only matches the CachyOS kernel. With linux-fiord, use the DKMS module, which builds against `linux-fiord-headers` on every kernel update:

```
sudo pacman -S nvidia-open-dkms
```

Other DKMS modules (`virtualbox-host-dkms`, `zfs-dkms`, `v4l2loopback-dkms`) work the same way. Modules built by DKMS are not signed with the kernel's build key, so they will not load if you enable lockdown or `module.sig_enforce=1`.

### Going back

```
sudo pacman -Rns linux-fiord linux-fiord-headers
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Remove `GRUB_TOP_LEVEL` from `/etc/default/grub` first if you set it.

## Building

```
cd packages/linux-fiord
gpg --import keys/pgp/*.asc
makepkg -s
```

Build options, set in the environment:

| Variable | Values | Default |
| --- | --- | --- |
| `_processor_opt` | `generic_v1`, `generic_v2`, `generic_v3`, `generic_v4`, `zen4`, `native` | `generic_v1` |
| `_use_llvm_lto` | `none`, `thin`, `full` | `none` |

For example `_processor_opt=generic_v3 makepkg -s` builds for Haswell, Zen 1 and newer. A `thin` or `full` LTO build uses Clang, and its headers package then depends on Clang so DKMS can build modules.

`./build.sh` reuses the published linux-fiord packages when their version is already in the repo, and only builds the kernel when `pkgver` or `pkgrel` changed. `REBUILD=1` does not rebuild the kernel; use `REBUILD_KERNEL=1` for that.

### Updating to a new CachyOS release

1. Set `_major`, `_minor` and `_tagrel` to the new [CachyOS/linux](https://github.com/CachyOS/linux/releases) tag and reset `pkgrel` to 1.
2. Take `config` from the same version of [linux-cachyos](https://github.com/CachyOS/linux-cachyos/tree/master/linux-cachyos), and point `_patchcommit` at the [kernel-patches](https://github.com/CachyOS/kernel-patches) commit that matches it.
3. Run `updpkgsums`, then `makepkg --verifysource` to check the source signature against the keys in `keys/pgp`. The `dkms-clang.patch` hashes in the LTO branch of the PKGBUILD are not touched by `updpkgsums`; update them by hand with `sha256sum` and `b2sum`.
4. Push a branch. The `kernel` workflow applies the patches and the config fragment, builds both packages, runs namcap and builds `nvidia-open-dkms` against the new headers.
