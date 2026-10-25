#!/usr/bin/env bash
# Rebuild previews/ (static HTML and PNG of every board) from mockups/*.dc.html.
# Needs node and Chrome or Chromium; runs headless, nothing appears on screen.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
chrome=$(command -v google-chrome-stable || command -v chromium || command -v chromium-browser) || { echo "no Chrome/Chromium" >&2; exit 1; }
node "$here/tools/render.mjs" "$here/mockups" "$here/previews"
python3 -c 'import json,sys; [print(k,*v) for k,v in json.load(open(sys.argv[1])).items()]' "$here/previews/sizes.json" |
while read -r name w h; do
  "$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --virtual-time-budget=4000 \
    --window-size="$w,$h" --screenshot="$here/previews/$name.png" "file://$here/previews/$name.html" >/dev/null 2>&1
done
echo "previews in $here/previews"
