#!/usr/bin/env bash
set -euo pipefail
. /usr/lib/fiordland/lib.sh
c=/etc/snapper/configs/root
[ -f "$c" ] || exit 0
grep -q '^NUMBER_LIMIT="50"$' "$c" && set_conf "$c" NUMBER_LIMIT '"10"'
grep -q '^NUMBER_LIMIT_IMPORTANT="10"$' "$c" && set_conf "$c" NUMBER_LIMIT_IMPORTANT '"5"'
grep -q '^NUMBER_CLEANUP="yes"$' "$c" || set_conf "$c" NUMBER_CLEANUP '"yes"'
grep -q '^TIMELINE_CLEANUP="yes"$' "$c" || set_conf "$c" TIMELINE_CLEANUP '"yes"'
grep -q '^EMPTY_PRE_POST_CLEANUP="yes"$' "$c" || set_conf "$c" EMPTY_PRE_POST_CLEANUP '"yes"'
grep -q '^FREE_LIMIT=' "$c" || set_conf "$c" FREE_LIMIT '"0.2"'
enable_if_disabled snapper-cleanup.timer
