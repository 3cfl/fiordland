#!/usr/bin/env bash
set -euo pipefail
[ $# -gt 0 ] || { echo "usage: $0 PKGBUILD_OR_PACKAGE..." >&2; exit 2; }
command -v namcap >/dev/null || { echo "missing tool: namcap" >&2; exit 2; }

for f in "$@"; do
  echo "== $f"
  namcap "$f" 2>&1
done
