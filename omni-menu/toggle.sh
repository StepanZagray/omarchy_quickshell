#!/usr/bin/env bash
# Toggle the omni-menu palette; cold-start the daemon if it isn't running.
# Used by SUPER+SPACE and the navbar omni button.

# Fast path: daemon already up, just toggle.
qs -c omni-menu ipc call palette toggle 2>/dev/null && exit 0

# Cold path: spawn daemon, poll IPC until it answers, then open.
# Daemon needs ~100-300ms to register the IPC handler; cap polling at ~2s.
setsid -f qs -n -d -c omni-menu >/dev/null 2>&1
for _ in $(seq 1 40); do
    qs -c omni-menu ipc call palette open 2>/dev/null && exit 0
    sleep 0.05
done
