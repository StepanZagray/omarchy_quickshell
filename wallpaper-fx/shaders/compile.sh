#!/usr/bin/env bash
# Compile every *.frag in this directory into a Qt6 *.qsb bundle.
set -euo pipefail

QSB="${QSB:-/usr/lib/qt6/bin/qsb}"
if ! [ -x "$QSB" ]; then
    QSB="$(command -v qsb)" || {
        echo "qsb not found. Install qt6-shadertools." >&2
        exit 1
    }
fi

cd "$(dirname "$0")"
for f in *.frag; do
    [ -e "$f" ] || continue
    echo "qsb $f -> $f.qsb"
    "$QSB" --glsl 300es,330 --hlsl 50 --msl 12 -o "$f.qsb" "$f"
done

# ShaderEffect caches .qsb; restart so the new bake is loaded.
if pgrep -f 'qs -n -d -c wallpaper-fx' >/dev/null; then
    echo "reloading wallpaper-fx"
    pkill -f 'qs -n -d -c wallpaper-fx' || true
    sleep 0.2
    qs -n -d -c wallpaper-fx
fi
