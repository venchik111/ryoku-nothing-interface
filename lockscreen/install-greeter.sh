#!/usr/bin/env bash
# Install the user theme through Ryoku and enable the persistent SDDM wallpaper.
set -euo pipefail
if (( EUID == 0 )); then
    echo "Run this installer as your desktop user; it requests system authorization when needed." >&2
    exit 1
fi
LOCKSCREEN_SOURCE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
python3 -c 'from PIL import Image' || {
    echo "Install python-pillow before continuing." >&2
    exit 1
}
command -v ryoku-hub >/dev/null
python3 - "$LOCKSCREEN_SOURCE" <<'PY'
from pathlib import Path
import shutil
import sys

source = Path(sys.argv[1])
theme = Path.home() / '.local/share/qylock/themes/nothing-interface'
for entry in (source / 'nothing-interface').rglob('*'):
    if not entry.is_file() or '__pycache__' in entry.parts:
        continue
    target = theme / entry.relative_to(source / 'nothing-interface')
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(entry, target)
service = Path.home() / '.config/systemd/user/nothing-greeter-wallpaper.service'
service.parent.mkdir(parents=True, exist_ok=True)
shutil.copy2(source / 'nothing-greeter-wallpaper.service', service)
PY
pkexec /usr/bin/python3 "$LOCKSCREEN_SOURCE/prepare-greeter-background.py"
python3 "$HOME/.local/share/qylock/themes/nothing-interface/bin/greeter-wallpaper.py" --once
ryoku-hub lock set nothing-interface
systemctl --user daemon-reload
systemctl --user enable --now nothing-greeter-wallpaper.service
echo "Nothing Interface installed. The next sign-in uses the saved wallpaper; changes follow Ryogami automatically."
