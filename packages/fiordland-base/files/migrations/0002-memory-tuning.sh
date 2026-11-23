#!/usr/bin/env bash
set -e
[ -f /etc/systemd/zram-generator.conf ] || printf '[zram0]\nzram-size = min(ram / 2, 8192)\ncompression-algorithm = zstd\n' > /etc/systemd/zram-generator.conf
[ -f /etc/sysctl.d/99-fiordland.conf ] || printf 'vm.swappiness = 180\nvm.watermark_boost_factor = 0\nvm.watermark_scale_factor = 125\nvm.page-cluster = 0\n' > /etc/sysctl.d/99-fiordland.conf
