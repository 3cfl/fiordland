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
export GNUPGHOME=${FIORD_GNUPGHOME:-$HOME/.local/share/fiordland/signing}
key=${FIORD_SIGN_KEY:-11DC7CDCCFD3CB71196EBEF1FD69DE77164F4200}
if gpg --list-secret-keys "$key" >/dev/null 2>&1; then
  for f in repo/x86_64/*.pkg.tar.zst; do gpg -q --batch --yes -u "$key" --detach-sign "$f"; done
  repo-add -q -s -k "$key" repo/x86_64/fiordland.db.tar.gz repo/x86_64/*.pkg.tar.zst
else
  echo "signing key $key not found, building an unsigned repo"
  repo-add -q repo/x86_64/fiordland.db.tar.gz repo/x86_64/*.pkg.tar.zst
fi
unset GNUPGHOME

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
for f in repo/x86_64/*.pkg.tar.zst; do sudo rm -f "/var/cache/pacman/pkg/$(basename "$f")"; done
sudo mkarchiso -v -w work -o out iso
cleanwork
sudo chown "$(id -u):$(id -g)" out/*.iso
ls -lh out/
