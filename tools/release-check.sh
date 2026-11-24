#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."

dir=${PACKAGES_DIR:-packages}
names=("$@")
[ ${#names[@]} -gt 0 ] || names=(tawaki rawaru kuaka weka)
failed=0

fail() {
  echo "FAIL $1: $2" >&2
  failed=1
}

pkginfo() {
  bash -c '. "$1" && printf "%s\n" "$url" "$pkgver" "${sha256sums[0]}" "${source[0]#*::}"' _ "$1"
}

latest_tag() {
  git ls-remote --tags --refs "$1" 'v*' | sed 's|.*refs/tags/||' | { grep -E '^v[0-9]+(\.[0-9]+)*$' || true; } | sort -V | tail -n1
}

check() {
  local name=$1 pkgbuild url ver sum src latest actual
  pkgbuild=$dir/$name/PKGBUILD
  [ -f "$pkgbuild" ] || { fail "$name" "$pkgbuild not found"; return; }
  { read -r url; read -r ver; read -r sum; read -r src; } < <(pkginfo "$pkgbuild")
  latest=$(latest_tag "$url")
  if [ -z "$latest" ]; then
    fail "$name" "no release tags at $url"
    return
  fi
  if [ "$latest" != "v$ver" ]; then
    fail "$name" "PKGBUILD is v$ver, latest tag is $latest"
    return
  fi
  if [ "$sum" = SKIP ]; then
    fail "$name" "sha256sums is SKIP, pin the checksum of $latest"
    return
  fi
  if ! actual=$(curl -fsSL "$src" | sha256sum | cut -d' ' -f1); then
    fail "$name" "could not download $src"
    return
  fi
  if [ "$actual" != "$sum" ]; then
    fail "$name" "sha256 of $latest is $actual, PKGBUILD has $sum"
    return
  fi
  echo "ok $name $latest"
}

for name in "${names[@]}"; do
  check "$name"
done
exit "$failed"
