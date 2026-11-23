import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import time
import urllib.request

release = Path('/srv/fiordland/ops/bot-setup')
runtime = Path('/run/fiordland-bot-setup')
saved_link = Path('/root/fiordland-bot-setup-link')
unit = Path('/run/systemd/system/fiordland-bot-setup.service')
snippet = Path('/etc/caddy/ivy-setup/fiordland-bot.caddy')
cleanup = Path('/usr/local/libexec/fiordland-bot-setup-cleanup')

if os.geteuid() != 0:
    raise SystemExit('run as root')
active = subprocess.run(['systemctl', 'is-active', '--quiet', 'fiordland-bot-setup'], check=False).returncode == 0
if active:
    print(saved_link.read_text().strip())
    raise SystemExit(0)

runtime.mkdir(mode=0o700, exist_ok=True)
runtime.chmod(0o700)
route = '/f-' + secrets.token_hex(16)
secret = secrets.token_urlsafe(32)
config = {'route': route, 'tokenHash': hashlib.sha256(secret.encode()).hexdigest(), 'expiresAt': int(time.time() * 1000) + 86400000}
config_file = runtime / 'config.json'
config_file.unlink(missing_ok=True)
with config_file.open('x') as handle:
    config_file.chmod(0o600)
    json.dump(config, handle)
url = 'https://ivy.rest' + route + '#' + secret
saved_link.unlink(missing_ok=True)
with saved_link.open('x') as handle:
    saved_link.chmod(0o600)
    handle.write(url + '\n')
cleanup.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(release / 'cleanup.sh', cleanup)
cleanup.chmod(0o755)
shutil.copyfile(release / 'setup.service', unit)
unit.chmod(0o644)
snippet.write_text((release / 'setup.caddy').read_text().replace('__ROUTE__', route))
snippet.chmod(0o640)
try:
    subprocess.run(['caddy', 'validate', '--config', '/etc/caddy/Caddyfile'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(['systemctl', 'daemon-reload'], check=True)
    subprocess.run(['systemctl', 'start', 'fiordland-bot-setup'], check=True)
    for attempt in range(20):
        try:
            request = urllib.request.Request('http://127.0.0.1:3719' + route, headers={'Host': 'ivy.rest'})
            with urllib.request.urlopen(request, timeout=2) as response:
                if response.status == 200:
                    break
        except OSError:
            time.sleep(0.25)
    else:
        raise RuntimeError('setup did not become ready')
    subprocess.run(['caddy', 'reload', '--config', '/etc/caddy/Caddyfile'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
except Exception:
    subprocess.run(['systemctl', 'stop', 'fiordland-bot-setup'], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    snippet.unlink(missing_ok=True)
    saved_link.unlink(missing_ok=True)
    config_file.unlink(missing_ok=True)
    unit.unlink(missing_ok=True)
    raise
print(url)
