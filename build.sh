#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
root=$PWD

[ -n "${SKIP_AUR:-}" ] || tools/aurbuild.sh
for pkg in packages/*/; do
  case "$pkg" in packages/aur/|packages/crest/) continue ;; esac
  (cd "$pkg" && rm -f ./*.pkg.tar.zst && makepkg -fd --noconfirm >/dev/null)
done
mkdir -p repo/x86_64
rm -f repo/x86_64/*
cp packages/*/*.pkg.tar.zst packages/aur/out/*.pkg.tar.zst repo/x86_64/
rm -f repo/x86_64/*-debug-*.pkg.tar.zst
repo-add -q repo/x86_64/fiordland.db.tar.gz repo/x86_64/*.pkg.tar.zst

rm -rf iso/airootfs/opt/fiordland/repo
mkdir -p iso/airootfs/opt/fiordland
cp -r repo/x86_64 iso/airootfs/opt/fiordland/repo

sed -i "s#^Server = file://.*#Server = file://$root/repo/x86_64#" iso/pacman.conf
trap 'sed -i "s#^Server = file://.*#Server = file://@REPO@#" iso/pacman.conf' EXIT

cleanwork() {
  findmnt -rn -o TARGET | grep -F "$root/work/" | sort -r | xargs -r -n1 sudo umount -R 2>/dev/null || true
  sudo rm -rf --one-file-system work
}

cleanwork
sudo mkarchiso -v -w work -o out iso
cleanwork
sudo chown "$(id -u):$(id -g)" out/*.iso
ls -lh out/
