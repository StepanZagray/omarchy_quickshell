# navbar

A minimal Quickshell top bar for omarchy. Kanagawa Dragon layout, kanji workspace markers, omarchy-theme-aware colors.

![navbar preview](assets/preview.png)

## Quick start

```sh
git clone https://github.com/bjarneo/quickshell ~/.config/quickshell

# disable omarchy's waybar (see below)
omarchy toggle waybar

# autostart on every Hyprland session
install -m 755 ~/.config/quickshell/navbar/contrib/post-boot.d/quickshell-navbar \
  ~/.config/omarchy/hooks/post-boot.d/quickshell-navbar

# launch once now
qs -n -d -c navbar
```

Reload the Hyprland session (or run `omarchy-hook post-boot`) and the bar will appear.

## Requirements

| Package | Why |
| --- | --- |
| quickshell | The runtime that loads `shell.qml`. |
| hyprland | Provides `hyprctl` for workspace state, active workspace, hyprsunset. |
| pamixer | Audio mute query. |
| bluetoothctl | Bluetooth power and connection state. |
| nmcli | Wifi signal strength when no ethernet is up. |
| brightnessctl | Backlight slider in the display popup. |
| hyprsunset | Color temperature + gamma in the display popup. Auto-started on first slider touch. |
| jq, curl | Weather popup data fetch from wttr.in. |
| omarchy | For the theme file at `~/.config/omarchy/current/theme/colors.toml`. |

## Toggle waybar

omarchy ships a one-shot toggle that flips waybar between enabled and disabled:

```sh
omarchy toggle waybar
```

It's also bound to `SUPER + SHIFT + SPACE` out of the box. Under the hood it manages the `~/.local/state/omarchy/toggles/waybar-off` flag, which omarchy's autostart checks at session start.

The toggle only affects whether waybar launches on the *next* Hyprland session. To swap bars live without re-login:

```sh
pkill waybar                          # stop the current waybar
waybar &>/dev/null & disown           # or, to restart it
```

## Theme reactivity

The bar reads `~/.config/omarchy/current/theme/colors.toml` and remaps these keys:

| toml key | role | maps to |
| --- | --- | --- |
| background | bar surface | `paper` |
| foreground | primary text | `ink` |
| color7 | secondary text | `inkDeep` |
| color8 | muted decoration | `sumi` |
| accent | info accent | `indigo` |
| color1 | active workspace, alerts | `seal` |

`omarchy theme set <name>` rebuilds the theme dir atomically (`rm -rf` + `mv`). That invalidates the inotify watch on `colors.toml`, so the bar also watches `~/.config/omarchy/current/theme.name` (rewritten in place via `echo > file`, stable inode) as a swap beacon and force-reloads the palette when it fires.

## Layout

```
left   | omarchy | sep | ws1..ws10 |
center | HH:MM |
right  | weather | display | camera | sep | cpu | bt | wifi | audio | battery | edge |
```

- Click the omarchy glyph to open the omni-menu palette. Right-click for `xdg-terminal-exec`.
- Click the clock to open the calendar popup.
- Click a kanji to `hyprctl dispatch workspace N`.
- Click weather for the forecast popup. Right-click to force-refresh.
- Click display for the warmth/brightness/gamma popup. Right-click resets.
- Click camera to browse recent screenshots. Right-click captures a new one.
- Click the audio glyph to open `omarchy-launch-audio`. Right-click toggles mute.
- Click battery to open the power menu.
- Click the edge arrow to cycle the bar between top, right, bottom, left.

## Popups

All popups are click-anywhere-to-dismiss overlays, keyboard-focused while open, and follow the same Kanagawa Dragon palette as the bar.

| Popup | Trigger | What it does |
| --- | --- | --- |
| Calendar | Click clock | Month grid with Norwegian red days, keyboard month nav, today highlight. |
| Screenshots | Click camera | Paged thumbnails of `~/Pictures/screenshot-*.png`. Enter opens, `C` copies to clipboard. |
| Display | Click display glyph | Warmth (hyprsunset), brightness (brightnessctl), gamma sliders. Four presets, blank, reset. |
| Weather | Click weather glyph | wttr.in current conditions, sunrise/sunset, 2-day forecast. Manual location via `~/.config/omarchy/weather/location`. |
| Omni-menu | Click omarchy glyph | Full-screen palette fusing installed apps and omarchy-menu actions (separate config). |

## Weather location

Defaults to wttr.in's IP geolocation. Override by writing a single line to `~/.config/omarchy/weather/location`:

```
Oslo
```

Or any of: `City, Country` | `LHR` (IATA) | `94103` (zip) | `60.42,11.24` (lat,lon). Click the subtitle inside the weather popup to open the file in your editor. The bar re-fetches on save.

## IPC

External keybinds drive each popup via `qs ipc call`:

```
bind = SUPER, SPACE, exec, qs ipc call palette toggle
bind = SUPER, P,     exec, qs ipc call screenshots toggle
bind = SUPER, D,     exec, qs ipc call display toggle
bind = SUPER, W,     exec, qs ipc call weather toggle
```

`refresh`, `open`, `close`, `reset`, and `blank` are also exposed where relevant.

## Customization

Everything lives in `shell.qml`. Common tweaks:

| Want to change | Where |
| --- | --- |
| Bar height | `barHeight` property near the top. |
| Workspace count | `Repeater { model: 10 ... }`. |
| Animation speed | `Behavior on ... { duration: ... }` blocks in the `Workspace` component. |
| Font | `mono` and `serif` properties. |
| Telemetry interval | The `Timer { interval: ... }` blocks. |

Quickshell hot-reloads on save, so edits show up live.

## Autostart hook

`contrib/post-boot.d/quickshell-navbar` is a drop-in for omarchy's hook system. It runs ~2s after Hyprland starts.

```sh
#!/bin/bash
qs -n -d -c navbar
```

`-d` daemonizes (so the hook returns immediately). `-n` makes it idempotent (no double-launch if `omarchy-hook post-boot` runs again).

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `Could not open config file at "navbar"` | Use `-c navbar`, not `-p navbar`. `-c` resolves to `~/.config/quickshell/navbar/shell.qml`. |
| Theme colors don't update on `omarchy theme set` | Check `~/.config/omarchy/current/theme.name` exists and is being rewritten. The bar uses it as the reload trigger. |
| Workspace switch feels laggy | Bump `wsProbe`'s `Timer { interval: ... }` from 500ms down to 150ms, or wire it to Hyprland's IPC socket. |
| Qt version mismatch warning | `quickshell` was built against an older Qt minor. Rebuild the package against your current Qt. |

## License

MIT.
