import QtQuick
import Quickshell
import Quickshell.Io
import "data/Palette.js" as Palette

// `seal` rides `driftAmount` (200ms rise, 2.8s taper) so each theme swap
// reads as a breath rather than a hard cut. The 1.55s lead-in lets
// theme-wash's animation exit first.
Item {
    id: theme

    readonly property string paletteReadCommand:
        "theme_name=$(cat \"$HOME/.config/omarchy/current/theme.name\" 2>/dev/null); "
        + "colors_file=\"$HOME/.config/omarchy/themes/$theme_name/colors.toml\"; "
        + "[ -f \"$colors_file\" ] || colors_file=\"$HOME/.config/omarchy/current/theme/colors.toml\"; "
        + "cat \"$colors_file\" 2>/dev/null"

    // Our own persisted round/sharp toggle. Flipped from the omni menu
    // (or any client) via the `corners` IpcHandler below. We don't read
    // omarchy's walker.css because that file is rewritten by a buggy
    // script and would drift out of sync with what we actually rendered.
    readonly property string cornerStatePath: Quickshell.env("HOME") + "/.local/state/quickshell-desktop/corners"
    // Global corner radii — change the *Default values to retune the shell.
    // frameCornerRadius (16): desktop frame hole + every popup shell (pockets,
    // free cards, Omni glass, notifications, tooltips).
    // contentCornerRadius (12): popup innards + bar controls.
    readonly property int frameCornerRadiusDefault: 16
    readonly property int contentCornerRadiusDefault: 16
    property int frameCornerRadius: frameCornerRadiusDefault
    property int contentCornerRadius: contentCornerRadiusDefault
    readonly property int frameRounding: frameCornerRadius
    readonly property bool round: contentCornerRadius > 0
    readonly property real contentCornerPower: 4

    // 4px spatial rhythm for every shell surface (interface-design density).
    readonly property int space1: 4
    readonly property int space2: 8
    readonly property int space3: 12
    readonly property int space4: 16
    readonly property int popupPadX: space4
    readonly property int popupPadY: space2
    readonly property int popupPadBottom: space4
    readonly property int popupSectionGap: space3
    readonly property int popupAnchorGap: space3
    readonly property int shellInset: space4

    function setCorners(mode) {
        const sharp = (mode === "sharp" || mode === false || mode === 0);
        theme.frameCornerRadius = sharp ? 0 : theme.frameCornerRadiusDefault;
        theme.contentCornerRadius = sharp ? 0 : theme.contentCornerRadiusDefault;
        cornerWriter.command = ["bash", "-lc",
            "mkdir -p " + JSON.stringify(theme.cornerStatePath.replace(/\/[^/]+$/, ""))
            + " && printf '%s' " + JSON.stringify(sharp ? "sharp" : "round")
            + " > " + JSON.stringify(theme.cornerStatePath)];
        cornerWriter.running = false;
        cornerWriter.running = true;
    }
    function toggleCorners() { theme.setCorners(theme.round ? "sharp" : "round"); }

    property color paper:   "#181616"
    property color ink:     "#c5c9c5"
    property color inkDeep: "#c8c093"
    property color sumi:    "#a6a69c"
    property color indigo:  "#658594"
    property color green:   "#a9b665"
    property color sealRaw: "#c4746e"
    property real  driftAmount: 0

    readonly property color seal: Qt.hsva(
        sealRaw.hsvHue,
        Math.min(1, sealRaw.hsvSaturation + driftAmount * 0.05),
        sealRaw.hsvValue,
        sealRaw.a
    )

    readonly property string mono:  "JetBrainsMono Nerd Font"
    readonly property string serif: mono

    // Standard motion duration for popups, OSD, frame morph, tooltips, and
    // other shell reveal/fade surfaces. Pair with Easing.InOutCubic.
    property int animationDuration: 300

    readonly property color bg:     Qt.rgba(paper.r, paper.g, paper.b, 0.70)
    readonly property color fg:     ink
    readonly property color muted:  sumi
    readonly property color accent: seal
    readonly property color warn:   seal
    readonly property color sep:    Qt.rgba(ink.r, ink.g, ink.b, 0.18)
    readonly property color rowHi:  Qt.rgba(ink.r, ink.g, ink.b, 0.06)
    readonly property color rowSel: Qt.rgba(seal.r, seal.g, seal.b, 0.18)

    // Name of the last theme applied via IPC. Used to suppress the drift
    // animation when the hook pushes the same theme twice or races the
    // startup FileView read.
    property string lastAppliedName: ""

    // Prefer the named theme directory over the copied current/theme
    // snapshot, so manual edits to ~/.config/omarchy/themes/<name>/colors.toml
    // are picked up on Quickshell startup and IPC reload.
    Process {
        id: paletteReader
        running: true
        command: ["bash", "-lc", theme.paletteReadCommand]
        stdout: StdioCollector {
            onStreamFinished: Palette.apply(theme, Palette.parse(this.text))
        }
    }

    // Local persistence: one-line file containing "round" or "sharp".
    // Read at startup so the toggle survives across logins. We read via a
    // Process (not FileView) because FileView's initial load races with
    // property assignment in some Quickshell builds, leaving contentCornerRadius
    // at its default of 0 even when the file says "round".
    Process { id: cornerWriter; running: false }
    Process {
        id: cornerReader
        running: true
        command: ["cat", theme.cornerStatePath]
        stdout: StdioCollector {
            onStreamFinished: {
                const round = this.text.trim() === "round";
                theme.frameCornerRadius = round ? theme.frameCornerRadiusDefault : 0;
                theme.contentCornerRadius = round ? theme.contentCornerRadiusDefault : 0;
            }
        }
        onExited: function(code) {
            if (code !== 0) {
                theme.frameCornerRadius = theme.frameCornerRadiusDefault;
                theme.contentCornerRadius = theme.contentCornerRadiusDefault;
            }
        }
    }

    IpcHandler {
        target: "corners"
        function set(mode: string): void { theme.setCorners(mode); }
        function round(): void  { theme.setCorners("round"); }
        function sharp(): void  { theme.setCorners("sharp"); }
        function toggle(): void { theme.toggleCorners(); }
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
            duration: theme.animationDuration
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            target: theme; property: "driftAmount"
            to: 0
            duration: theme.animationDuration * 14
            easing.type: Easing.InOutCubic
        }
    }

    IpcHandler {
        target: "theme"
        function apply(payload: string): void {
            let p;
            try { p = JSON.parse(payload); }
            catch (e) { console.warn("theme.apply: bad payload —", e); return; }
            if (!p || !p.colors) return;
            Palette.apply(theme, Palette.mapKeys(p.colors));
            if (p.name && p.name !== theme.lastAppliedName) {
                theme.lastAppliedName = p.name;
                driftDelay.restart();
            }
        }
        function reload(): void {
            paletteReader.running = false;
            paletteReader.running = true;
            driftDelay.restart();
        }
    }
}
