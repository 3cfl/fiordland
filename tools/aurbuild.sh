#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
root=$PWD
chroot=$root/chroot
out=$root/packages/aur/out
mkdir -p "$out"

order=(crest crest-greeter)
[ $# -gt 0 ] && order=("$@")

sudo arch-nspawn "$chroot/root" pacman -Syu --noconfirm >/dev/null

for p in "${order[@]}"; do
  echo ":: $p"
  if [ "$p" = crest ]; then
    cd "$root/packages/crest"
    rm -f crest-*.tar.gz
    ver=$(awk -F= '$1=="pkgver"{print $2}' PKGBUILD)
    tar --exclude=tests -czf "crest-$ver.tar.gz" -C "$root" crest
  elif [ "$p" = crest-greeter ]; then
    cd "$root/packages/crest-greeter"
    rm -f crest-greeter-*.tar.gz
    ver=$(awk -F= '$1=="pkgver"{print $2}' PKGBUILD)
    tar --exclude=tests -czf "crest-greeter-$ver.tar.gz" -C "$root" crest-greeter crest/theme crest/components crest/assets/wallpaper.webp crest/LICENSE
  else
    cd "$root/packages/aur/$p"
  fi
  rm -f ./*.pkg.tar.zst
  deps=()
  for f in "$out"/*.pkg.tar.zst; do [ -e "$f" ] && [[ $f != *-debug-* && $(basename "$f") != crest-* ]] && deps+=(-I "$f"); done
  makechrootpkg -c -r "$chroot" "${deps[@]}" -- --noconfirm --skippgpcheck
  rm -f ./*-debug-*.pkg.tar.zst
  for f in ./*.pkg.tar.zst; do
    name=$(tar -xOf "$f" .PKGINFO | awk -F' = ' '$1=="pkgname"{print $2}')
    rm -f "$out/$name"-[0-9r]*.pkg.tar.zst
    mv "$f" "$out/"
  done
done
ls -1 "$out"
