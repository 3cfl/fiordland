set -eu
rm -f /etc/caddy/ivy-setup/fiordland-bot.caddy /root/fiordland-bot-setup-link /run/systemd/system/fiordland-bot-setup.service /run/fiordland-bot-setup/config.json
/usr/bin/caddy reload --config /etc/caddy/Caddyfile >/dev/null 2>&1
