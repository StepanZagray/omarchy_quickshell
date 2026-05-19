import QtQuick
import Quickshell
import Quickshell.Io
import "Palette.js" as Palette

// Live palette from omarchy's colors.toml. Startup reads the file once;
// every subsequent swap arrives as a JSON payload via `theme apply` IPC,
// pushed by ~/.config/omarchy/hooks/theme-set. See desktop/README.md.
//
// `seal` rides a `driftAmount` saturation bump on every reload (200ms
// rise, 2.8s taper) so a theme swap reads as a deliberate breath. The
// 1.55s lead-in lets theme-wash's animation exit first.
Item {
    id: theme

    readonly property string colorsPath: Quickshell.env("HOME") + "/.config/omarchy/current/theme/colors.toml"

    property color paper:   "#181616"
    property color ink:     "#c5c9c5"
    property color inkDeep: "#c8c093"
    property color sumi:    "#a6a69c"
    property color indigo:  "#658594"
    property color sealRaw: "#c4746e"
    property real  driftAmount: 0

    readonly property color seal: Qt.hsva(
        sealRaw.hsvHue,
        Math.min(1, sealRaw.hsvSaturation + driftAmount * 0.05),
        sealRaw.hsvValue,
        sealRaw.a
    )

    readonly property string serif: "serif"
    readonly property string mono:  "JetBrainsMono Nerd Font"

    readonly property color bg:     Qt.rgba(paper.r, paper.g, paper.b, 0.94)
    readonly property color fg:     ink
    readonly property color muted:  sumi
    readonly property color accent: seal
    readonly property color warn:   seal
    readonly property color sep:    Qt.rgba(ink.r, ink.g, ink.b, 0.18)
    readonly property color rowHi:  Qt.rgba(ink.r, ink.g, ink.b, 0.06)
    readonly property color rowSel: Qt.rgba(seal.r, seal.g, seal.b, 0.18)

    // watchChanges: false — `omarchy theme set` does an atomic rm+mv on
    // the theme dir, which would race an inotify watch. The hook tells us
    // when to reload instead.
    FileView {
        id: paletteFile
        path: theme.colorsPath
        watchChanges: false
        onLoaded: Palette.apply(theme, Palette.parse(paletteFile.text()))
    }

    Timer {
        id: driftDelay
        interval: 1550
        repeat: false
        onTriggered: driftAnim.restart()
    }

    SequentialAnimation {
        id: driftAnim
        NumberAnimation {
            target: theme; property: "driftAmount"
            from: 0; to: 1
            duration: 200
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: theme; property: "driftAmount"
            to: 0
            duration: 2800
            easing.type: Easing.OutCubic
        }
    }

    IpcHandler {
        target: "theme"
        // Push path: hook parses colors.toml and ships the result here as a
        // JSON string. Payload shape: { name: "<theme>", colors: { rawKey: hex, ... } }
        function apply(payload: string): void {
            try {
                const p = JSON.parse(payload);
                if (p && p.colors) {
                    Palette.apply(theme, Palette.mapKeys(p.colors));
                    driftDelay.restart();
                }
            } catch (_) {}
        }
        // Manual rescue: re-read colors.toml from disk and apply.
        function reload(): void {
            paletteFile.reload();
            driftDelay.restart();
        }
    }
}
