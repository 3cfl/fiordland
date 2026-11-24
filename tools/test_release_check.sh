#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

sum() {
  printf '%s' "$1" | sha256sum | cut -d' ' -f1
}

tag_repo() {
  local name=$1 tag
  shift
  git init -q --bare "$T/git/$name"
  git init -q "$T/work/$name"
  git -C "$T/work/$name" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
  for tag in "$@"; do
    git -C "$T/work/$name" tag "$tag"
  done
  git -C "$T/work/$name" push -q "$T/git/$name" HEAD:refs/heads/main --tags
}

tarball() {
  mkdir -p "$T/git/$1/archive"
  printf '%s' "$3" > "$T/git/$1/archive/v$2.tar.gz"
}

pkgbuild() {
  mkdir -p "$T/pkgs/$1"
  cat > "$T/pkgs/$1/PKGBUILD" <<PKG
pkgname=$1
pkgver=$2
url="file://$T/git/$1"
source=("\$pkgname-\$pkgver.tar.gz::\$url/archive/v\$pkgver.tar.gz")
sha256sums=('$3')
PKG
}

expect() {
  local label=$1 want=$2 pattern=$3 out rc=0
  shift 3
  out=$(PACKAGES_DIR=$T/pkgs "$here/tools/release-check.sh" "$@" 2>&1) || rc=$?
  [ "$rc" = "$want" ] || { echo "FAIL $label: exit $rc, wanted $want"; echo "$out"; exit 1; }
  grep -q -- "$pattern" <<< "$out" || { echo "FAIL $label: output lacks '$pattern'"; echo "$out"; exit 1; }
}

tag_repo good v1.0 v1.9 v1.10 v1.11-rc1
tarball good 1.10 payload
pkgbuild good 1.10 "$(sum payload)"

tag_repo lag v1.0 v1.1
tarball lag 1.0 payload
pkgbuild lag 1.0 "$(sum payload)"

tag_repo badsum v2.0
tarball badsum 2.0 payload
pkgbuild badsum 2.0 "$(sum other)"

tag_repo skipped v3.0
tarball skipped 3.0 payload
pkgbuild skipped 3.0 SKIP

tag_repo untagged
pkgbuild untagged 1.0 "$(sum payload)"

tag_repo nofile v4.0
pkgbuild nofile 4.0 "$(sum payload)"

expect "matching version, newest tag by version order" 0 "ok good v1.10" good
expect "pkgbuild behind the newest tag" 1 "PKGBUILD is v1.0, latest tag is v1.1" lag
expect "checksum differs from the tagged archive" 1 "sha256 of v2.0" badsum
expect "unpinned checksum" 1 "sha256sums is SKIP" skipped
expect "repository without release tags" 1 "no release tags" untagged
expect "archive missing" 1 "could not download" nofile
expect "pkgbuild missing" 1 "not found" missing
expect "one failure fails the run, the rest still report" 1 "ok good v1.10" good lag
echo ok
