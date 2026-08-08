#!/usr/bin/env bash
# Start the desktop shell once. Hypr autostart and omarchy post-boot can both
# call this, and so does the SUPER+CTRL+R reload binding (which pkills the old
# shell first).
#
# Three things here are deliberate, because getting them wrong leaves the
# session with no bar at all and gives no hint why:
#
#   * `qs list` is the status check. `qs -c desktop -n` is NOT a check - it
#     launches the shell in the foreground and blocks.
#   * We wait for the lock instead of `flock -n ... || exit 0`. The lock lives
#     in XDG_RUNTIME_DIR, which outlives a single graphical session, so on
#     logout/login the previous session's shell can still be exiting while the
#     new session's autostart runs. Treating "looks busy" as "job done" is what
#     used to lose the bar.
#   * The lock fd is closed for the shell (9>&-) so the lock covers only the
#     spawn rather than the whole life of the shell. fds are not CLOEXEC and
#     would otherwise survive into the daemon.
set -euo pipefail

LOCK="${XDG_RUNTIME_DIR:-/tmp}/quickshell-desktop.lock"
exec 9>"$LOCK"

flock -w 15 9 || echo "ensure-running: lock still busy after 15s, starting anyway" >&2

# PIDs of instances of this config that are actually alive. A shell that is on
# its way down can still be listed, so confirm each one with kill -0.
live_pids() {
  qs list -c desktop -j 2>/dev/null \
    | grep -oE '"pid"[[:space:]]*:[[:space:]]*[0-9]+' \
    | grep -oE '[0-9]+$' \
    | while read -r p; do kill -0 "$p" 2>/dev/null && echo "$p"; done \
    || true
}

# Give a dying shell a moment to actually go away, so the reload binding
# (pkill + immediate re-run) doesn't mistake the corpse for a live shell and
# skip the restart.
for _ in $(seq 25); do
  [ -z "$(live_pids)" ] && break
  sleep 0.2
done

# Still alive after the grace period: a healthy shell is up, leave it alone.
if [ -n "$(live_pids)" ]; then
  exit 0
fi

# -d detaches, -n is a last-resort duplicate guard against a concurrent caller.
qs -d -c desktop -n 9>&-
