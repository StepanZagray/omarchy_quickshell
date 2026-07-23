# desktop

A Quickshell config that runs the navbar and omni-menu command palette in a single process. One daemon, one live palette, atomic theme swaps across bar and palette.

![navbar preview](./assets/preview.png)

## Quick start

```sh
git clone https://github.com/bjarneo/quickshell ~/.config/quickshell

# disable omarchy's waybar (also bound to SUPER + SHIFT + SPACE)
omarchy toggle waybar

# autostart on every Hyprland session
install -m 755 ~/.config/quickshell/desktop/contrib/post-boot.d/quickshell-desktop \
  ~/.config/omarchy/hooks/post-boot.d/quickshell-desktop

# launch once now
qs -n -d -c desktop
```

Reload the Hyprland session (or run `omarchy-hook post-boot`) and the bar appears with the palette one keybind away.

## Surfaces

The palette ships two `GlobalShortcut`s, registered as `quickshell:palette-toggle` and `quickshell:palette-quick` (bind them globally in Hyprland to skip the `qs` client fork on the hot path). `palette-quick` opens pre-pivoted to the Quick-mode tile grid (battery, audio, wifi, bluetooth, display, aether, cpu, calendar, screenshots, videos, power).

Everything else goes through IPC:

```sh
qs -c desktop ipc call palette toggle        # omni-menu
qs -c desktop ipc call palette openCategory Quick  # palette pinned to Quick mode
qs -c desktop ipc call screenshots toggle    # screenshots browser
qs -c desktop ipc call videos toggle         # video browser
qs -c desktop ipc call display toggle        # display sliders
qs -c desktop ipc call aether toggle         # aether blueprint picker
qs -c desktop ipc call calendar toggle       # calendar
```

The navbar omarchy/menu button calls `toggle()` on the sibling palette in-process, no IPC round-trip or subprocess.

## What's inside

| Component | What it does |
| --- | --- |
| Bar | Numeric workspace markers, telemetry (cpu, mem, bt, wifi, audio, battery), centred clock, click-through popups for calendar, screenshots, videos, display, media, aether blueprints. |
| Omni-menu | Full-screen command palette over installed apps and the omarchy-menu (Style, Setup, Install, Remove, Update, System, Toggle, Trigger, Capture, Share, Learn), file search, GitHub repo search, processes, theme picker, plus Quick-mode tile grid, tldr lookup (`$`), and local Ollama chat (`?`). |
| Theme | Shared live palette sourced from `~/.config/omarchy/current/theme/colors.toml`. Drift animation runs on theme swap so bar + palette breathe in sync. Shell surfaces share `animationDuration` (200ms) for reveal/fade motion. |

## Bar layout

```
left   | omarchy | sep | ws1..ws10 |
center | HH:MM |
right  | media | sep | cpu | bt | wifi | audio | battery |
```

- Click the omarchy glyph to toggle the omni-menu palette. Right-click runs `xdg-terminal-exec`.
- Click the clock to open the calendar popup.
- Click a workspace number to `hyprctl dispatch workspace N`.
- Click media for the media popup. Right-click skips to the next track.
- Click display for warmth, brightness, gamma sliders + presets.
- Click camera to browse `~/Pictures/screenshot-*.png`. Right-click captures a new one.
- Click filmstrip to browse recent videos in `~/Videos`. Right-click opens the folder.
- Click audio for `omarchy-launch-audio`. Right-click toggles mute.
- Click battery for the power menu.
- Cycle bar faces with `qs -c desktop ipc call bar toggle`; jump directly with `qs -c desktop ipc call bar zen` or `qs -c desktop ipc call bar hackerman`.

## Palette

Type to filter across titles, categories, and a curated synonym list. Drill into any category, run with Enter.

| Key | Action |
| --- | --- |
| Type | Filter by title, category, and per-item synonyms |
| Up / Down / Tab / Shift+Tab | Move selection, wraps at both ends |
| PageUp / PageDown | Jump 8 rows, clamps at both ends |
| Home / End | Jump to first / last result |
| Enter | Drill into a category, or run the selected action |
| Ctrl + S | Star / unstar the current row |
| Ctrl + Plus / Minus | Bump font scale (0.7x to 2.0x) |
| Ctrl + = | Reset font scale to 1.0 |
| Ctrl + C | In tldr / chat preview, copy selection (or whole rendered preview if nothing is selected) |
| Backspace | Delete a char; when empty, walk back up one level |
| Esc | Cascade: collapse quick-tile detail, then clear query, then unwind drill-down, then close |

### Query shapes

The first character of the query can pivot the whole pane:

| Prefix | Mode |
| --- | --- |
| `$ <cmd>` | tldr lookup. Renders the tldr page inline in a preview pane, palette-tinted. Enter opens a floating terminal with the command pre-filled at a readline prompt. |
| `? <question>` | Local Ollama chat. Streams against `qwen3.5:0.8b` (no network). First Enter probes the daemon; if Ollama isn't installed / running / the model isn't pulled, the preview shows what to do and Enter runs the right setup step in a terminal. |

### Quick mode

`ALT + SPACE` opens the palette pre-pivoted to a quick tile grid: battery, audio, network, bluetooth, display, aether, cpu, calendar, screenshots, videos, power. Each tile binds to live navbar telemetry so the panel paints with current state on the very first frame.

| Key | Action |
| --- | --- |
| Hjkl / arrow keys | Move tile selection |
| Tab / Shift+Tab | Step forward / backward through the grid |
| Enter | Expand the selected tile into a detail panel beside the grid |
| Right-click on tile | Run the tile's long action (mute toggle, refresh, reset) without opening detail |
| Esc | Collapse the detail panel, then close the palette |

Expanding a tile compresses the grid to a 64px column on the left so the detail body (volume sliders, wifi list, bluetooth pairing, display warmth/brightness/gamma, aether blueprints, screenshot/video browsers, ...) gets the wider right half.

### Scoring

Every entry is indexed against three fields. All query tokens must match somewhere; scores stack per token.

| Match | Weight |
| --- | --- |
| Title prefix | 100 |
| Title substring | 60 |
| Keywords substring | 20 |
| Category substring | 10 |

Top 250 sorted by score, nav-rows-first on ties, then alpha.

### Drill-downs

At root the first rows are category navigators (`Apps >`, `Style >`, `Files >`, `GitHub >`, `Processes >`, `Themes >`, ...). Activating one filters the list and updates the header breadcrumb. Files and GitHub drills pivot to fd / gh CLI output; Processes drills into a kill list; Themes drills into the omarchy theme switcher with swatch + preview pane.

## Theme

Reads `~/.config/omarchy/current/theme/colors.toml` and remaps:

| toml key | role | maps to |
| --- | --- | --- |
| background | surface base | `paper` |
| foreground | primary text | `ink` |
| color7 | secondary bright text | `inkDeep` |
| color8 | muted decoration | `sumi` |
| accent | info accent | `indigo` |
| color1 | active marker, alerts | `seal` (drift-modulated) |

Parsing lives in `data/Palette.js`:

- `parseAll(text)` returns every `key = "value"` pair from a colors.toml.
- `mapKeys(raw)` renames the six keys this shell uses onto semantic slots.
- `parse(text)` is `parseAll` + `mapKeys`, a one-shot convenience.
- `apply(theme, palette)` writes a parsed palette onto the live `Theme` instance.

### Hook-driven refresh

`omarchy theme set <name>` rewrites `colors.toml` atomically (`rm -rf` + `mv` of the whole theme directory), which breaks inotify-style watching. The desktop instead relies on omarchy's `~/.config/omarchy/hooks/theme-set` hook to push a fully-parsed palette via DBus and Quickshell IPC. Listeners never have to touch `colors.toml` themselves.

```sh
# ~/.config/omarchy/hooks/theme-set

# (whatever else the hook does — cava reload, etc.)

# Parse colors.toml once into JSON and push to every listener.
# tomlq ships with the `yq` package; same jq syntax, TOML input.
theme_name="$(cat "$HOME/.config/omarchy/current/theme.name" 2>/dev/null)"
colors_file="$HOME/.config/omarchy/current/theme/colors.toml"

payload="$(tomlq -c --arg name "$theme_name" \
    '{name: $name, colors: (with_entries(.key |= ascii_downcase))}' \
    "$colors_file" 2>/dev/null)"

if [ -n "$payload" ]; then
    dbus-send --session --type=signal /org/omarchy/Theme \
        org.omarchy.Theme.Changed "string:${payload}" 2>/dev/null || true
    qs -c desktop ipc call theme apply "${payload}" 2>/dev/null || true
fi
```

On apply, `seal` saturation rides a 200ms rise and 2.8s taper (`driftDelay` + `driftAnim` in `Theme.qml`), so a theme swap reads as a deliberate breath rather than a hard cut.

### Payload shape

```json
{
  "name": "kanagawa-dragon",
  "colors": {
    "background": "#181616",
    "foreground": "#c5c9c5",
    "accent":     "#658594",
    "color1":     "#c4746e",
    "color7":     "#c8c093",
    "color8":     "#a6a69c",
    "color0":     "#0d0c0c",
    "color9":     "...",
    "...":        "..."
  }
}
```

`colors` is every `key = "value"` pair from the active `colors.toml` (typically ~22: `background`, `foreground`, `accent`, `cursor`, `selection_foreground`, `selection_background`, `color0..color15`).

### External listeners

```sh
# sed strips dbus-monitor's `string "..."` wrapper from the arg line.
dbus-monitor --session "type='signal',interface='org.omarchy.Theme',member='Changed'" \
  | grep --line-buffered '"name"' \
  | sed -u 's/^[[:space:]]*string "//; s/"$//' \
  | while read -r json; do
      bg=$(echo "$json" | jq -r '.colors.background')
      echo "new background: $bg"
    done
```

## IPC

`toggle`, `open`, `close`, and (where relevant) `refresh`, `reset`, `blank` are exposed on each target. `palette` also exposes `openCategory <name>` to pivot the palette into a drill-down on open. `qs -c desktop ipc show` lists everything. See [Surfaces](#surfaces) above for the common verbs.

## App scan

Apps are scanned once at startup via a single Python `configparser` pass (NoDisplay/Hidden filtered, `%U`/`%f` field codes stripped, deduped by name) across `~/.local/share/applications`, `/usr/share/applications`, Flatpak, and Snap. Trigger a rescan with `qs -c desktop ipc call palette refresh`.

App icons resolve via `Quickshell.iconPath()` for theme names and `file://` for absolute paths, then render through `MultiEffect colorization` so they paint as flat-tinted silhouettes in the live palette (ink at rest, seal on the selected row).

## Adding palette entries

Edit `omarchyItems` in `data/OmniData.js`. Each row is:

```js
{ title: "My Action", icon: "", category: "Style",
  keywords: "synonym one synonym two related terms",
  exec: "my-command --flag" }
```

- `category` decides which drill-in surfaces the row.
- `keywords` is a space-separated synonym list. Anything you'd plausibly type to find this row goes here.
- `exec` is fed to `setsid -f uwsm-app -- bash -c "<exec>"`, so pipes, `||`, `&&` all work.

## Customization

Everything lives under `desktop/`. `Desktop.qml` is the shell facade: the taskbar is `bar/Bar.qml`; bars and popups bind to `root.*`. State lives under `state/`, layer wiring under `shell/`.

| Path | Owns |
| --- | --- |
| `Desktop.qml` | Shell facade, theme pass-through, icon constants, state wiring. |
| `bar/` | Taskbar (`Bar`, `Module`, `Workspace`, …). |
| `popups/` | Card-window surfaces and popup-only controls (`OsdPopup`, media, calendar, …). |
| `state/OsdState.qml` | OSD logic, pamixer/brightnessctl, auto-hide. |
| `state/InputState.qml` | Keyboard layout tracking for the bar language indicator. |
| `quick/` | Quick-mode detail bodies and quick-panel controls. |
| `services/` | Desktop-wide services shared by more than one feature. |
| `omnimenu/services/` | App scan, bookmarks/history, and Omni search providers. |
| `data/` | Static palette entries and theme-palette parsing helpers. |
| `state/ChromeState.qml` | Tooltip anchors, popup anchors, frame-widget geometry. |
| `shell/DesktopSurfaces.qml` | Per-monitor bar/popup/shell surface construction. |
| `shell/DesktopIpc.qml` | Desktop shell IPC targets. |

`OmniMenu.qml` is the stable public entry point and state coordinator. The implementation is grouped by responsibility in `omnimenu/`:

| File | Owns |
| --- | --- |
| `omnimenu/SearchModel.qml` | Search index, filtering, ranking, and result cap. |
| `omnimenu/ActionDispatcher.qml` | Row and Quick-tile command execution. |
| `omnimenu/MenuSurface.qml` | Layer-shell windows and card composition. |
| `omnimenu/KeyRouter.qml` | Keyboard navigation, preview scrolling, and clipboard shortcuts. |
| `omnimenu/components/` | Header, input, Quick grid, result list, and preview pane. |
| `omnimenu/data/` | Quick-tile data and preview formatting helpers. |
| `omnimenu/services/` | Omni-only data providers and persistent state. |

Common tweaks:

| Want to change | Where |
| --- | --- |
| Bar height | `barHeight` in `Desktop.qml`. |
| Workspace count | `Repeater { model: 10 ... }` in `bar/Bar.qml`. |
| Bar font | `mono` / `serif` in `Desktop.qml`. |
| Palette font | `mono` / `serif` in `OmniMenu.qml`. |
| Palette result cap | `maxResults` in `omnimenu/SearchModel.qml`. |
| Score weights | The four `*Score` properties in `omnimenu/SearchModel.qml`. |
| Quick-tile order / actions | `base` array in `omnimenu/data/Tiles.js`. |
| Telemetry interval | `Timer { interval: ... }` blocks in the matching `state/*State.qml`. |
| Drift animation | `driftDelay` / `driftAnim` in `Theme.qml`. |
| Shell motion (popups, OSD, tooltips) | `animationDuration` in `Theme.qml` — use with `Easing.InOutCubic`; see [extend.md](./extend.md#shell-motion). |

Quickshell hot-reloads on save, so edits show up live.

## OSD

Volume and brightness keys are wired in `~/.config/hypr/bindings.conf` to `qs -c desktop ipc call osd …`. Caps lock is detected automatically. Keyboard layout is shown in the bar when multiple layouts are configured (`us,ua` in `hypr/input.conf`).

| Kind | Trigger | Display |
| --- | --- | --- |
| Volume | Multimedia keys | Bar + % |
| Brightness | Display brightness keys | Bar + % |
| Keyboard brightness | Kbd brightness keys | Bar + % |
| Caps lock | Caps key (polled) | Status label |
| Mic mute | `XF86AudioMicMute` | Status label |
| Touchpad | Touchpad toggle keys | Status label |
| Layout | Alt+Shift toggle | Bar indicator (US / UA) |

```sh
qs -c desktop ipc call osd volumeRaise
qs -c desktop ipc call osd brightnessUp5
qs -c desktop ipc call osd kbdBrightnessUp
qs -c desktop ipc call osd micMuteToggle
qs -c desktop ipc call osd touchpadToggle
```

## Autostart

`desktop/contrib/post-boot.d/quickshell-desktop` is a drop-in for omarchy's hook system. It runs at session start with:

```sh
#!/bin/bash
qs -n -d -c desktop
```

`-d` daemonizes, `-n` makes it idempotent.

## Requirements

| Package | Why |
| --- | --- |
| quickshell | Runtime. |
| hyprland | Workspace state, keybinds, autostart hook. |
| omarchy | Live theme palette and the `omarchy-menu <verb>` dispatcher. |
| python3 | Parses `.desktop` files. |
| uwsm | `uwsm-app` scope wrapper for spawned apps. |
| pamixer | Audio mute query. |
| bluetoothctl | Bluetooth power and connection state. |
| nmcli | Wifi signal strength when no ethernet is up. |
| brightnessctl | Backlight slider in the display popup. |
| hyprsunset | Color temperature and gamma in the display popup. |
| yq | Provides `tomlq` for the theme-set hook's TOML-to-JSON pass. |
| fd, gh | File search and GitHub repo search drill-downs (optional). |
| dragon-drop | Drag-and-drop hand-off for the videos popup (optional, AUR). |

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `Could not open config file at "desktop"` | Use `-c desktop`, not `-p desktop`. `-c` resolves to `~/.config/quickshell/desktop/shell.qml`. |
| Palette doesn't appear on SUPER + SPACE | Confirm the keybind targets `qs -c desktop ipc call palette toggle`, not the old `omni-menu/toggle.sh`. |
| Theme colours don't update on `omarchy theme set` | Check `~/.config/omarchy/current/theme.name` exists and is being rewritten. The desktop uses it as the reload trigger. |
| Workspace switch feels laggy | Bump `wsProbe`'s `Timer { interval: ... }` from 500ms down to 150ms in `state/WorkspaceState.qml`, or wire it to Hyprland's IPC socket. |
| Qt version mismatch warning | `quickshell` was built against an older Qt minor. Rebuild the package against your current Qt. |

## License

MIT.
