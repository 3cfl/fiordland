#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
root=$PWD
pkg=$root/packages/linux-fiord
mode=${1:-}

case "$mode" in
  prepare|build) ;;
  *) echo "usage: $0 prepare|build" >&2; exit 2 ;;
esac

[ "$(id -u)" = 0 ] || { echo "run as root inside an archlinux:base-devel container" >&2; exit 2; }

restore_owner() {
  if [ -n "${HOST_UID:-}" ] && [ -n "${HOST_GID:-}" ]; then
    chown -R "$HOST_UID:$HOST_GID" "$root"
  fi
}
trap restore_owner EXIT

mapfile -t deps < <(bash -c 'source "$1"; printf "%s\n" "${makedepends[@]}"' _ "$pkg/PKGBUILD")
pacman -Syu --noconfirm --needed git namcap ccache "${deps[@]}"

id b >/dev/null 2>&1 || useradd -m b
chown -R b: "$pkg"
as_b() {
  runuser -u b -- env HOME=/home/b "$@"
}
as_b gpg --batch --import "$pkg"/keys/pgp/*.asc

if [ "$mode" = prepare ]; then
  (cd "$pkg" && as_b makepkg --nobuild --noconfirm)
  grep -E '^CONFIG_(LOCALVERSION|SCHED_BORE|HZ|PREEMPT_DYNAMIC|PREEMPT|CC_OPTIMIZE_FOR_PERFORMANCE|LTO_NONE|GENERIC_CPU|X86_64_VERSION|MODULE_COMPRESS_ZSTD|LRU_GEN_ENABLED|ZSWAP_COMPRESSOR_DEFAULT|ZRAM_DEF_COMP|DEFAULT_TCP_CONG|DEFAULT_NET_SCH|NTSYNC|SCHED_CLASS_EXT|DEBUG_INFO_BTF|LSM|INIT_ON_ALLOC_DEFAULT_ON|RANDOMIZE_KSTACK_OFFSET_DEFAULT|RUST)=' \
    "$pkg"/src/cachyos-*/.config
  cat "$pkg"/src/cachyos-*/version
  exit 0
fi

: "${CCACHE_DIR:=$root/.ccache}"
export CCACHE_DIR
export CCACHE_MAXSIZE=${CCACHE_MAXSIZE:-4G}
export CCACHE_BASEDIR=$pkg/src
export CCACHE_COMPRESS=1
mkdir -p "$CCACHE_DIR"
chown -R b: "$CCACHE_DIR"
sed -i 's/!ccache/ccache/' /etc/makepkg.conf
as_b ccache -z

rm -f "$pkg"/*.pkg.tar.zst
(cd "$pkg" && as_b makepkg -f --noconfirm)
as_b ccache -s

mapfile -t built < <(find "$pkg" -maxdepth 1 -name '*.pkg.tar.zst' | sort)
[ "${#built[@]}" = 2 ] || { echo "expected 2 packages, got ${#built[@]}" >&2; exit 1; }

failed=0
for f in "${built[@]}"; do
  out=$(namcap "$f" 2>&1)
  printf '== %s\n%s\n' "$f" "$out"
  if grep -q ' E: ' <<<"$out"; then failed=1; fi
done
[ "$failed" = 0 ] || { echo "namcap reported errors" >&2; exit 1; }

pacman -U --noconfirm --assume-installed initramfs "${built[@]}"
kdir=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -name '*-fiord' | head -n1)
[ -n "$kdir" ] || { echo "no linux-fiord modules directory" >&2; exit 1; }
kver=${kdir##*/}
echo "kernel release $kver"
info=$(file "$kdir/vmlinuz")
echo "$info"
grep -qF "version $kver (linux-fiord@fiordland)" <<<"$info"
[ "$(cat "$kdir/pkgbase")" = linux-fiord ]
[ -f /usr/lib/sysctl.d/70-linux-fiord.conf ]
[ -x "$kdir/build/scripts/sign-file" ]
[ -x "$kdir/build/tools/objtool/objtool" ]
[ -f "$kdir/build/Module.symvers" ]

pacman -S --noconfirm --needed nvidia-open-dkms
dkms autoinstall -k "$kver" || true
status=$(dkms status -k "$kver")
echo "$status"
if ! grep -q 'nvidia.*installed' <<<"$status"; then
  find /var/lib/dkms/nvidia -name make.log -exec tail -n 80 {} \;
  echo "nvidia-open-dkms did not build against $kver" >&2
  exit 1
fi
modinfo -k "$kver" -F version nvidia
