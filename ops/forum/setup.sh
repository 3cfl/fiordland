#!/bin/bash
set -euo pipefail
env=/etc/fiordland/smtp.env
[ -r "$env" ] || { echo "missing $env (SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASS SMTP_FROM ADMIN_EMAIL)"; exit 1; }
set -a; . "$env"; set +a
for v in SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASS SMTP_FROM ADMIN_EMAIL; do [ -n "${!v:-}" ] || { echo "$v not set"; exit 1; }; done
command -v docker >/dev/null || { apt-get update -q && apt-get install -yq docker.io; systemctl enable --now docker; }
[ -d /var/discourse ] || git clone https://github.com/discourse/discourse_docker.git /var/discourse
here=$(cd "$(dirname "$0")" && pwd)
umask 077
python3 - "$here/app.yml.in" /var/discourse/containers/app.yml <<'PY'
import os, sys
s = open(sys.argv[1]).read()
for k in ("ADMIN_EMAIL", "SMTP_HOST", "SMTP_PORT", "SMTP_USER", "SMTP_PASS", "SMTP_FROM"):
    s = s.replace("@" + k + "@", os.environ[k].replace('"', '\\"'))
open(sys.argv[2], "w").write(s)
PY
cd /var/discourse && ./launcher rebuild app
