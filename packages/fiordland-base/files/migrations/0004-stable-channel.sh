#!/usr/bin/env bash
set -e
[ -f /etc/fiordland/channel ] && exit 0
fiordland-channel stable >/dev/null
