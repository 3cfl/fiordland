#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
root=$PWD

PUBLISHED=${PUBLISHED:-https://fiordland.apollo44.lat/repo/x86_64}
export PUBLISHED
[ -n "${SKIP_AUR:-}" ] || tools/aurbuild.sh
for pkg in packages/*/; do
  case "$pkg" in packages/aur/|packages/crest/) continue ;; esac
  (
    cd "$pkg"
    rm -f ./*.pkg.tar.zst
    reused=1
    for f in $(PKGEXT=.pkg.tar.zst makepkg --packagelist); do
      n=$(basename "$f")
      curl -fsSL -o "$n" "$PUBLISHED/$n" || { reused=0; break; }
    done
    if [ "$reused" = 1 ] && [ -z "${REBUILD:-}" ]; then
      echo "reusing published $(basename "$pkg")"
    else
      rm -f ./*.pkg.tar.zst
      PKGEXT=.pkg.tar.zst makepkg -fd --noconfirm >/dev/null
    fi
  )
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
profile=iso
if [ -n "${FLAVOR:-}" ]; then
  [ -d "flavors/$FLAVOR" ] || { echo "no flavor $FLAVOR"; exit 1; }
  profile=$root/work-profile
  rm -rf "$profile"
  cp -a iso "$profile"
  cp -a "flavors/$FLAVOR/airootfs/." "$profile/airootfs/"
  if [ -f "flavors/$FLAVOR/packages.remove" ]; then
    grep -vxFf "flavors/$FLAVOR/packages.remove" iso/packages.x86_64 > "$profile/packages.x86_64"
  fi
  [ -f "flavors/$FLAVOR/packages.add" ] && cat "flavors/$FLAVOR/packages.add" >> "$profile/packages.x86_64"
  sort -u -o "$profile/packages.x86_64" "$profile/packages.x86_64"
  sed -i -e "s/^iso_name=.*/iso_name=\"fiordland-$FLAVOR\"/" \
    -e "s/^iso_application=.*/iso_application=\"Fiordland Linux Live ($FLAVOR)\"/" "$profile/profiledef.sh"
fi
sudo mkarchiso -v -w work -o out "$profile"
[ "$profile" = iso ] || rm -rf "$profile"
cleanwork
sudo chown "$(id -u):$(id -g)" out/*.iso
ls -lh out/
