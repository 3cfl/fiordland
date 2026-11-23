#!/bin/bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
rsync -a "$here"/*.wiki main:/tmp/flwiki/
ssh main 'cd /srv/fiordland/wiki/w && chmod a+r /tmp/flwiki/*.wiki && for f in /tmp/flwiki/*.wiki; do
  b=$(basename "$f" .wiki)
  case "$b" in
    Main_Page) t="Main Page" ;;
    Fiordland_Linux) t="Fiordland Linux" ;;
    Style_guide) t="Fiordland Wiki:Style guide" ;;
    Sidebar) t="MediaWiki:Sidebar" ;;
    Vector-2022.css) t="MediaWiki:Vector-2022.css" ;;
    *) t="$b" ;;
  esac
  sudo -u www-data php maintenance/run.php edit -u Apollo -s "Sync from repo" "$t" < "$f" | tail -1
done; systemctl restart php8.3-fpm'
