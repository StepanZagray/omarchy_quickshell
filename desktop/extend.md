# Extending the desktop

How to add palette entries, rearrange the bar, retune scoring, and swap the theme. Edits are made directly in the files under `desktop/`. Quickshell hot-reloads on save, so most changes appear without restarting.

For the high-level overview and IPC surface, see [README.md](./README.md).

## TL;DR by goal

| I want to | File | Anchor |
| --- | --- | --- |
| Add a row to the palette | `data/Data.js` | `omarchyItems` |
| Add a new drill-down category | `data/Data.js` | `categoryNav` |
| Change which icon renders for a file extension | `data/Data.js` | `fileIcons` |
| Resize the bar | `Desktop.qml` | `barHeight` |
| Add or remove a bar module | `bar/Bar.qml` | the `Module { ... }` blocks |
| Change palette result cap | `OmniMenu.qml` | `maxResults` |
| Retune search scoring | `OmniMenu.qml` | `scPrefix`, `scTitle`, `scKw`, `scCat` |
| Change fonts | `Theme.qml` | `mono`, `serif` |
| Tune shell motion (popups, OSD, tooltips) | `Theme.qml` | `animationDuration` |
| Tune theme-swap animation | `Theme.qml` | `driftDelay`, `driftAnim` |
| Remap colors.toml keys to palette roles | `data/Palette.js` | `mapKeys` |

## Adding a palette row

Open `data/Data.js` and append to `omarchyItems`:

```js
{ title: "Open Vault",
  icon: "",
  category: "Setup",
  keywords: "vault password manager secrets bitwarden",
  exec: "bitwarden-desktop" }
```

| Field | Purpose |
| --- | --- |
| `title` | Shown in the row and matched as the primary search field. |
| `icon` | A Nerd Font glyph. Paste from `nerdfonts.com/cheat-sheet`. |
| `category` | Decides which drill-down surfaces the row. Use an existing category to slot in, or add a new one (see below). |
| `keywords` | Space-separated synonyms. Anything you would plausibly type to find this row. |
| `exec` | Bash, run via `setsid -f uwsm-app -- bash -c "<exec>"`. Pipes, `&&`, `||` all work. |
| `tui` (optional) | Wrapper command that prefixes `exec`. Set to `omarchy-launch-tui` or `omarchy-launch-floating-terminal-with-presentation` if the action needs a terminal. |

Save and the next palette open picks it up. No restart needed.

## Adding a drill-down category

Categories are the synthetic top-level rows (`Apps >`, `Style >`, ...). Append to `categoryNav` in `data/Data.js`:

```js
{ title: "Vault",
  icon: "",
  category: "Browse",
  isCategory: true,
  target: "Vault",
  keywords: "vault passwords secrets keys" }
```

Then tag your `omarchyItems` entries with `category: "Vault"` and they appear when the user drills in.

Rules:
- `target` must equal the `category` string used by leaf items.
- Keep `category: "Browse"` on the nav row itself. That is the bucket all drill rows live in.
- Order in `categoryNav` is the order shown at root.

## Hiding a built-in row

Comment it out in `omarchyItems`, or remove the row entirely. There is no `hidden: true` flag; the array is the source of truth.

## File-search icons

`data/Data.js` exposes `fileIcons`, a map from lowercased extension (or full filename, for dotless names like `Makefile`) to a Nerd Font glyph. Add to it to cover a new extension:

```js
const fileIcons = {
    // ...
    "kdl": "",
    "nix": ""
};
```

`fileExt()` and `fileIcon()` are pure helpers; no other wiring required.

## Bar layout

`bar/Bar.qml` is a flat list of `Module { ... }` and `Separator { ... }` blocks arranged left, center, right. To remove a module, delete its block. To reorder, move the block. To add a new one, copy an existing `Module` block and change its bindings.

The shape of a `Module`:

```qml
Module {
    root: bar.root
    icon: bar.root.icoSearch
    label: someStringBinding
    tooltip: "Tooltip text"
    onClicked:        someAction()
    onRightClicked:   someAlternateAction()
}
```

Icons live as `icoFoo` properties on `Desktop.qml`'s `root`. Add new ones with `String.fromCodePoint(0xNNNN)` against any Nerd Font codepoint.

## Bar geometry

`Desktop.qml`:

| Property | What it does |
| --- | --- |
| `barHeight: 28` | Pixel height of the top bar. |

Workspace count lives in `bar/Bar.qml`:

```qml
Repeater { model: 10; /* ... */ }
```

## Telemetry intervals

Bar pollers are split by concern under `state/`: CPU/memory in `SystemState.qml`, Bluetooth/Wi-Fi in `ConnectivityState.qml`, audio in `AudioState.qml`, and battery/clock in `PowerState.qml`. Each has a `Timer` block with an `interval` in milliseconds. Lower for snappier readings at the cost of CPU. Workspace state polls every 500ms via `wsProbe` in `state/WorkspaceState.qml`; drop to 150ms if workspace switches feel laggy.

## Palette tuning

`OmniMenu.qml`:

| Property | Default | Effect |
| --- | --- | --- |
| `maxResults` | 250 | Hard cap on result rows after scoring. |
| `scPrefix` | 100 | Score for a title-prefix match. |
| `scTitle` | 60 | Score for a title-substring match. |
| `scKw` | 20 | Score for a keywords-substring match. |
| `scCat` | 10 | Score for a category-substring match. |

Per-token scores stack. A query token has to match somewhere or the row is dropped. Raise `scKw` if synonyms feel underweighted; raise `scPrefix` if you want titles you typed first to dominate harder.

## Fonts

`Theme.qml`:

```qml
property string mono:  "JetBrainsMono Nerd Font"
property string serif: "..."
```

Both the bar and the palette read from these. Change once, both surfaces follow.

## Shell motion

Popups (`CardWindow`), OSD toasts, tooltips, and the frame-widget morph all share one timing constant on `Theme.qml`:

| Property | Default | What it drives |
| --- | --- | --- |
| `animationDuration` | 200ms | Reveal/fade duration for shell surfaces |

Use `Easing.InOutCubic` with that duration. Do not hardcode per-widget millisecond values for show/hide — read `theme.animationDuration` (or `root.animationDuration` on the `Desktop` shell facade).

Standard reveal pattern:

```qml
property real reveal: shouldShow ? 1 : 0
Behavior on reveal {
    NumberAnimation {
        duration: root.animationDuration
        easing.type: Easing.InOutCubic
    }
}
visible: reveal > 0.001
opacity: reveal
```

`ChromeState.frameAnimationDuration` and `Desktop.frameAnimationDuration` alias `theme.animationDuration` so `CardWindow` and `FrameBorder` stay in sync.

Micro-interactions inside a popup (hover color, border width) may use shorter local durations; anything that opens or closes a surface should use the global constant.

## Theme animation

`Theme.qml`:

| Property | What it does |
| --- | --- |
| `driftDelay` | Rise time on a theme swap (default 200ms). |
| `driftAnim` | Taper time after the rise (default 2800ms). |

These drive the `seal` saturation breath. Drop to zero for hard cuts; raise for slower breathing.

## Palette colors

The shell exposes six semantic roles (`paper`, `ink`, `inkDeep`, `sumi`, `indigo`, `seal`) that the rest of the QML binds to. Those roles are filled from `colors.toml` by `data/Palette.js`. Remap which `colors.toml` key drives which role by editing `mapKeys` in `data/Palette.js`:

```js
function mapKeys(raw) {
    return {
        paper:   raw.background,
        ink:     raw.foreground,
        inkDeep: raw.color7,
        sumi:    raw.color8,
        indigo:  raw.accent,
        seal:    raw.color1,
    };
}
```

Useful when a theme stores its accent under a non-standard key, or when you want to wire `seal` to a different alert color.

## Workflow tips

- Quickshell hot-reloads on save. Watch the launch terminal for QML errors.
- After editing `data/Data.js`, the palette picks up changes on the next open; force a rescan with `qs -c desktop ipc call palette refresh`.
- After theme key remaps, push a fresh palette with `qs -c desktop ipc call theme apply '<json>'` (see README "Hook-driven refresh" for payload shape).
- If something stops painting, the QML import chain in `shell.qml` is the place to start. Each surface (`Desktop`, `OmniMenu`, popups) is wired there.

## Going further

If you find yourself maintaining a long fork of `data/Data.js`, the cleaner path is to split your additions into a separate JS module and merge them onto `omarchyItems` in `OmniMenu.qml`'s `Component.onCompleted`. That keeps upstream merges painless and your additions in one file.
