#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
here=$PWD
name=${NAME:-fiordland-xfce}
date=${DATE:-$(date +%Y.%m.%d)}
snapshot=${SNAPSHOT:-$(date -u -d '2 days ago' +%Y/%m/%d)}
selkies=${SELKIES_VERSION:-2.2.1}
work=$here/work
root=$work/root
out=$here/out

cleanup() {
  sudo umount -R "$root"/{proc,sys,dev,run,tmp} 2>/dev/null || true
}
trap cleanup EXIT

sudo rm -rf "$work"
mkdir -p "$work/repo" "$out"
(cd ../packages/fiordland-container && PKGEXT=.pkg.tar.zst makepkg -fd --noconfirm >/dev/null)
cp ../packages/fiordland-container/*.pkg.tar.zst "$work/repo/"
gh=https://github.com/selkies-project/selkies/releases/download/$selkies
curl -fsSL -o "$work/repo/selkies-$selkies-x86_64.pkg.tar.zst" "$gh/selkies-$selkies-x86_64.pkg.tar.zst"
curl -fsSL -o "$work/SHA256SUMS" "$gh/SHA256SUMS"
(cd "$work/repo" && sha256sum -c --ignore-missing "$work/SHA256SUMS")
echo "Server = https://archive.archlinux.org/repos/$snapshot/\$repo/os/\$arch" > "$work/mirrorlist"
curl -fsI "https://archive.archlinux.org/repos/$snapshot/core/os/x86_64/core.db" >/dev/null
repo-add -q "$work/repo/build.db.tar.gz" "$work/repo/"*.pkg.tar.zst

repos() {
  printf "[fiordland]\nSigLevel = Required\nServer = https://fiordlandlinux.org/repo/\$arch\n\n"
  for r in core extra multilib; do printf '[%s]\nInclude = %s\n\n' "$r" "$1"; done
}
options='[options]
HoldPkg = pacman glibc
Architecture = auto
Color
CheckSpace
ParallelDownloads = 10
DownloadUser = alpm
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional
NoExtract = usr/share/help/* !usr/share/help/en*
NoExtract = usr/share/gtk-doc/html/* usr/share/doc/*
NoExtract = usr/share/backgrounds/xfce/xfce-x.svg
'
{
  printf '%s\n' "$options"
  printf 'CacheDir = /var/cache/fiordland-container/\nParallelDownloads = 3\nDisableDownloadTimeout\n\n'
  printf '[build]\nSigLevel = Never\nServer = file://%s/repo\n\n' "$work"
  repos "$work/mirrorlist"
} > "$work/pacman.conf"

sudo install -d -m755 -o root -g root "$root"
sudo install -d -m755 /var/cache/fiordland-container
mapfile -t pkgs < <(grep -v '^$' packages)
for try in 1 2 3 4; do
  sudo pacstrap -c -G -M -C "$work/pacman.conf" "$root" "${pkgs[@]}" && break
  [ "$try" = 4 ] && exit 1
  sleep 10
done

{
  printf '%sDisableSandbox\n\n' "$options"
  repos /etc/pacman.d/mirrorlist
} | sudo tee "$root/etc/pacman.conf" >/dev/null
sudo install -m644 "$work/mirrorlist" "$root/etc/pacman.d/mirrorlist"
printf 'snapshot=%s\nselkies=%s\nbuilt=%s\n' "$snapshot" "$selkies" "$date" | sudo install -Dm644 /dev/stdin "$root/etc/fiordland/image"
sudo cp -r --no-preserve=ownership rootfs/. "$root/"
sudo chmod 755 "$root"/usr/local/bin/fiordland-*
sudo chmod 440 "$root/etc/sudoers.d/10-wheel"
sudo ln -sfn /usr/share/fiordland/wallpaper.png "$root/usr/share/backgrounds/xfce/xfce-x.svg"
sudo sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' "$root/etc/locale.gen"
echo LANG=en_US.UTF-8 | sudo tee "$root/etc/locale.conf" >/dev/null
sudo arch-chroot "$root" bash -e <<'IN'
locale-gen >/dev/null
pacman-key --init >/dev/null 2>&1
pacman-key --populate archlinux fiordland >/dev/null 2>&1
fiordland-migrate --os-release
rm -f /etc/machine-id
dbus-uuidgen --ensure=/etc/machine-id
IN
cleanup
sudo rm -rf "$root"/var/cache/pacman/pkg/* "$root"/var/lib/pacman/sync/* "$root"/var/log/* \
  "$root"/etc/pacman.d/gnupg/{openpgp-revocs.d,S.*} "$root"/root/.cache "$root"/tmp/* 2>/dev/null || true

tarball=$out/$name-$date.tar.zst
sudo tar --numeric-owner --xattrs --acls -C "$root" -c . | zstd -q -T0 -10 -o "$tarball" -f
sha256sum "$tarball" | sed "s|  .*/|  |" > "$tarball.sha256"
podman import \
  --change 'ENV LANG=en_US.UTF-8' \
  --change 'ENV NVIDIA_DRIVER_CAPABILITIES=all' \
  --change 'ENV NVIDIA_VISIBLE_DEVICES=all' \
  --change 'CMD ["/usr/local/bin/fiordland-selkies"]' \
  --change 'EXPOSE 8080' \
  --change "LABEL org.opencontainers.image.source=https://github.com/Fiordland-Linux/fiordland" \
  --change "LABEL org.opencontainers.image.version=$date" \
  --change "LABEL lat.apollo44.fiordland.snapshot=$snapshot" \
  --change "LABEL lat.apollo44.fiordland.selkies=$selkies" \
  "$tarball" "localhost/$name:$date" >/dev/null
podman tag "localhost/$name:$date" "localhost/$name:latest"
ls -la "$tarball"
podman images "localhost/$name"
