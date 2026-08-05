#!/usr/bin/env bash
# Start the desktop shell once. Hypr autostart and omarchy post-boot can both
# call this; flock prevents the race where two -n checks pass before either
# process registers.
set -euo pipefail

LOCK="${XDG_RUNTIME_DIR:-/tmp}/quickshell-desktop.lock"
exec 9>"$LOCK"
flock -n 9 || exit 0

if qs -c desktop -n 2>/dev/null; then
  exit 0
fi

exec qs -d -c desktop
