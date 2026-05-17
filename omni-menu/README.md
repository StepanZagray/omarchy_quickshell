# omni-menu

A Quickshell command palette that fuses installed apps (`.desktop` scan) with every action exposed by `omarchy-menu`. Search across titles, categories, and a curated synonym list, drill into any category, run with Enter.

## Quick start

```sh
# Autostart on every Hyprland session. The hook in ~/.config/hypr/autostart.lua
# runs `qs -n -d -c omni-menu` on hyprland.start.
hl.on("hyprland.start", function()
  hl.exec_cmd("qs -n -d -c omni-menu")
end)

# Or launch it once now.
qs -n -d -c omni-menu

# Toggle via Hyprland keybind (bindings.lua):
hl.unbind("SUPER + SPACE")
hl.bind(
  "SUPER + SPACE",
  hl.dsp.exec_cmd("qs -c omni-menu ipc call palette toggle"),
  { description = "Omni menu" }
)
```

Reload Hyprland (`hyprctl reload`) and hit `SUPER + SPACE`.

## What's inside

| Group | Count | Source |
| --- | --- | --- |
| Apps | varies | `~/.local/share/applications`, `/usr/share/applications`, Flatpak, Snap |
| Style, Setup, Install, Remove, Update, System, Toggle, Trigger, Capture, Share, Learn | ~125 | hardcoded mirror of `omarchy-menu` leaves |

Apps are scanned once at startup via a single Python `configparser` pass (NoDisplay/Hidden filtered, `%U`/`%f` field codes stripped, dedupe by name). Trigger a rescan with `qs -c omni-menu ipc call palette refresh`.

## Keys

| Key | Action |
| --- | --- |
| Type | Filter results by title, category, and per-item synonyms |
| Up / Down / Tab / Shift+Tab | Move selection, wraps at both ends |
| PageUp / PageDown | Jump 8 rows, clamps at both ends |
| Home / End | Jump to first / last result |
| Enter | Drill into a category nav row, or run the selected action |
| Backspace | Delete a char from the query; when empty, walk back up one level |
| Esc | Drilled in: back to root. At root: close. |

## Search

Every entry is indexed against three fields:

- `title` (the visible label)
- `category` (e.g. `Style`, `Setup`, `Install`, `App`)
- `keywords` (a curated synonym list per item; for apps, the `.desktop` Keywords, Categories, GenericName, and Comment fields are folded in)

Scoring (per query token, all must match somewhere):

| Match | Weight |
| --- | --- |
| Title prefix | 100 |
| Title substring | 60 |
| Keywords substring | 20 |
| Category substring | 10 |

So `theme` matches Theme on a title prefix; `dark mode` and `wallpaper` and `reboot` land on the right rows via their synonyms. Tokens are AND'd, scores stack. Top 250 sorted by score, then nav-rows-first, then alpha.

## Drill-down

At root, the first 12 rows are category navigators: `Apps >`, `Style >`, `Setup >`, etc. Activating one filters the list to that category and updates the header breadcrumb to `GO > SETUP` (or wherever). Esc / Backspace-on-empty walks back to root.

## App icons

Resolved via `Quickshell.iconPath()` for theme names (`firefox`, `chromium`) and `file://` for absolute paths from `.desktop` Icon fields. Every icon is then passed through a `MultiEffect` with `colorization: 1.0` so they render as a flat-tinted silhouette in the active theme color (ink at rest, seal accent on the selected row). Icons that fail to decode (e.g. SVGs Qt can't parse) fall back to the row's nerd-font glyph in the same slot.

## Theme reactivity

Reads `~/.config/omarchy/current/theme/colors.toml` and remaps:

| toml key | role |
| --- | --- |
| background | card surface |
| foreground | primary text |
| color7 | icon tint at rest |
| color8 | secondary text |
| color1 | accent (selection rail, breadcrumb, hot icon) |

`omarchy theme set <name>` rebuilds the theme dir atomically, which invalidates the inotify watch on `colors.toml`. A second FileView watches `~/.config/omarchy/current/theme.name` (rewritten in place, stable inode) as a swap beacon and force-reloads the palette.

## IPC

```sh
qs -c omni-menu ipc call palette toggle   # show/hide
qs -c omni-menu ipc call palette open     # show
qs -c omni-menu ipc call palette close    # hide
qs -c omni-menu ipc call palette refresh  # rescan .desktop files
```

## Adding entries

Edit the `omarchyItems` array in `shell.qml`. Each row is:

```qml
{ title: "My Action", icon: "", category: "Style",
  keywords: "synonym one synonym two related terms",
  exec: "my-command --flag" }
```

- `category` decides which drill-in surfaces the row and which navigator it belongs to.
- `keywords` is a space-separated synonym list. Anything you'd plausibly type to find this row goes here.
- `exec` is fed to `setsid -f uwsm-app -- bash -c "<exec>"`, so shell syntax (pipes, `||`, `&&`) works.

## Launch convention

Matches `omarchy-launch-or-focus`: `setsid -f uwsm-app -- bash -c "<exec>"`. `setsid -f` detaches the spawn into its own session so it outlives the launcher. `uwsm-app --` registers the spawn under a systemd-user scope so it gets a managed unit, cgroup, and clean logout teardown.

## Requirements

| Package | Why |
| --- | --- |
| quickshell | Loads `shell.qml`. |
| hyprland | Keybinds and the autostart hook. |
| python3 | Parses `.desktop` files via `configparser`. |
| omarchy | Provides the live palette and the `omarchy-menu <verb>` dispatcher. |
| uwsm | `uwsm-app` scope wrapper for spawned apps. |
