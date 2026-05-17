import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Omarchy top bar. Layout and typography are Kanagawa Dragon's — kanji
// workspaces, smoked sumi surface, autumn seal accents. Colours are
// reactive: they read ~/.config/omarchy/current/theme/colors.toml so the
// bar follows whatever omarchy theme is active.
ShellRoot {
    id: root

    // ---------- Theme path ----------
    readonly property string colorsPath: Quickshell.env("HOME") + "/.config/omarchy/current/theme/colors.toml"
    readonly property string themeNamePath: Quickshell.env("HOME") + "/.config/omarchy/current/theme.name"

    // ---------- Semantic palette (resolved from colors.toml) ----------
    // Names match the original Kanagawa Dragon mapping so the visual
    // hierarchy carries over to any palette:
    //   paper    = background          (bar surface base)
    //   ink      = foreground          (primary text)
    //   inkDeep  = color7              (secondary bright text)
    //   sumi     = color8              (muted/decorative)
    //   indigo   = accent              (info accent, e.g. low-battery warn)
    //   seal     = color1              (alert / active marker)
    property color paper:   "#181616"
    property color ink:     "#c5c9c5"
    property color inkDeep: "#c8c093"
    property color sumi:    "#a6a69c"
    property color indigo:  "#658594"
    // sealRaw is the palette-sourced value. seal is its drift-modulated
    // view: saturation rides driftAmount*0.05 above resting, which gets
    // pumped right after a theme swap and eases back over ~3s. Every
    // existing root.seal reference inherits the drift via this binding.
    property color sealRaw: "#c4746e"
    property real  driftAmount: 0
    readonly property color seal: Qt.hsva(
        sealRaw.hsvHue,
        Math.min(1, sealRaw.hsvSaturation + driftAmount * 0.05),
        sealRaw.hsvValue,
        sealRaw.a
    )

    // Derived bar colours. bg is paper at 0.94; sep is ink at 0.18.
    readonly property color bg:     Qt.rgba(paper.r, paper.g, paper.b, 0.94)
    readonly property color fg:     ink
    readonly property color muted:  sumi
    readonly property color accent: seal
    readonly property color warn:   seal
    readonly property color sep:    Qt.rgba(ink.r, ink.g, ink.b, 0.18)

    readonly property string serif: "serif"
    readonly property string mono:  "JetBrainsMono Nerd Font"

    // Kanji numerals 〇 一 二 ... 十.
    readonly property var kanjiNum: ["〇","一","二","三","四","五","六","七","八","九","十"]
    function indexKanji(n) { return n >= 0 && n <= 10 ? kanjiNum[n] : String(n); }

    // BMP Private Use Area icons; written via fromCodePoint so the source
    // stays ASCII-safe.
    readonly property string icoOmarchy: String.fromCodePoint(0xe900)
    readonly property string icoBtOn:    String.fromCodePoint(0xf294)
    readonly property string icoVol1:    String.fromCodePoint(0xf026)
    readonly property string icoVol2:    String.fromCodePoint(0xf027)
    readonly property string icoVol3:    String.fromCodePoint(0xf028)
    readonly property string icoMute:    String.fromCodePoint(0xeee8)

    readonly property int barHeight: 26

    // ---------- Edge ----------
    // Which screen edge the bar lives on. Cycles top → right → bottom →
    // left via the edge-toggle Module. Drives the bar anchors, the bar's
    // internal flow (horizontal vs vertical Row/Column), and the direction
    // the calendar popup unrolls from.
    property string barEdge: "top"
    readonly property bool isHorizontal: barEdge === "top" || barEdge === "bottom"
    readonly property bool isLeading:    barEdge === "top" || barEdge === "left"

    function cycleBarEdge() {
        const edges = ["top", "right", "bottom", "left"];
        root.barEdge = edges[(edges.indexOf(root.barEdge) + 1) % 4];
    }

    function edgeArrow() {
        return ({top: "↑", right: "→", bottom: "↓", left: "←"})[root.barEdge] || "?";
    }

    // ---------- State ----------
    property int activeWs: 1
    property var existingWs: [1, 2, 3, 4, 5]
    // +1 = user navigated to a higher-numbered workspace (rightward along
    // the bar), -1 = lower-numbered (leftward), 0 = no recent travel. The
    // active Workspace cell reads this to bias its kanji's entry offset.
    property int lastDirection: 0

    property int cpuVal: 0
    property int memVal: 0
    property int batVal: 0
    property string batState: "Unknown"

    property string netIcon: "󰤯"
    property string btIcon:  "󰂲"
    property string audioIcon: ""

    property string hh: "--"
    property string mm: "--"
    property string dd: "--"
    property string mon: "---"

    // ---------- Calendar popup state ----------
    property bool calendarVisible: false
    property int calendarMonthOffset: 0
    // Bumped on each open so the cells/title bindings below re-evaluate
    // (new Date() is opaque to QML's dependency tracker — touching this
    // int forces a recompute even when calendarMonthOffset is unchanged).
    property int calendarTick: 0

    readonly property var calendarCells: {
        root.calendarTick;
        const now = new Date();
        const m = now.getMonth() + root.calendarMonthOffset;
        const first = new Date(now.getFullYear(), m, 1);
        const lastDay = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
        // Monday-first week: shift Sunday (0) to slot 6.
        const startDay = (first.getDay() + 6) % 7;
        const today = new Date();
        const isCurrentMonth = first.getFullYear() === today.getFullYear()
                            && first.getMonth() === today.getMonth();
        const cells = [];
        for (let i = 0; i < startDay; i++) cells.push({day: 0, today: false});
        for (let d = 1; d <= lastDay; d++) {
            cells.push({day: d, today: isCurrentMonth && d === today.getDate()});
        }
        while (cells.length < 42) cells.push({day: 0, today: false});
        return cells;
    }

    readonly property string calendarMonthName: {
        root.calendarTick;
        const months = ["JANUARY","FEBRUARY","MARCH","APRIL","MAY","JUNE",
                        "JULY","AUGUST","SEPTEMBER","OCTOBER","NOVEMBER","DECEMBER"];
        const now = new Date();
        const d = new Date(now.getFullYear(), now.getMonth() + root.calendarMonthOffset, 1);
        return months[d.getMonth()];
    }

    readonly property string calendarYear: {
        root.calendarTick;
        const now = new Date();
        const d = new Date(now.getFullYear(), now.getMonth() + root.calendarMonthOffset, 1);
        return String(d.getFullYear());
    }

    function openCalendar() {
        root.calendarMonthOffset = 0;
        root.calendarTick++;
        root.calendarVisible = true;
    }

    // ---------- Palette loader ----------
    // Reads omarchy's colors.toml and re-applies the palette on any change.
    // The file is rewritten in place when `omarchy theme set` runs, so
    // FileView's inode watcher catches it without extra hooks.
    function parseColors(text) {
        const want = {
            background: null, foreground: null, accent: null,
            color1: null, color7: null, color8: null
        };
        const re = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]+)"/;
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(re);
            if (m && (m[1] in want)) want[m[1]] = m[2];
        }
        if (want.background) root.paper   = want.background;
        if (want.foreground) root.ink     = want.foreground;
        if (want.color7)     root.inkDeep = want.color7;
        if (want.color8)     root.sumi    = want.color8;
        if (want.accent)     root.indigo  = want.accent;
        if (want.color1)     root.sealRaw = want.color1;
    }

    FileView {
        id: paletteFile
        path: root.colorsPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseColors(paletteFile.text())
    }

    // omarchy-theme-set rm -rf's current/theme/ and mv's a fresh dir in, so
    // colors.toml gets a new inode each swap and paletteFile's inotify watch
    // dies with it. theme.name, by contrast, is rewritten in place (echo > )
    // so its inode is stable. Use it as a swap-detection beacon.
    FileView {
        id: themeMarker
        path: root.themeNamePath
        watchChanges: true
        // Restart the drift delay every swap. onFileChanged only fires on
        // inotify-driven changes (not on the initial load), so this is the
        // right place to detect "user just did `omarchy theme set`."
        onFileChanged: { reload(); paletteFile.reload(); driftDelay.restart(); }
    }

    // theme-wash's animation runs ~1.5s; wait it out so the saturation
    // bump lands as it exits, then rise quick and taper slow over ~3s.
    Timer {
        id: driftDelay
        interval: 1550
        repeat: false
        onTriggered: driftAnim.restart()
    }

    SequentialAnimation {
        id: driftAnim
        NumberAnimation {
            target: root; property: "driftAmount"
            from: 0; to: 1
            duration: 200
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root; property: "driftAmount"
            to: 0
            duration: 2800
            easing.type: Easing.OutCubic
        }
    }

    // ---------- Generic launcher ----------
    Process { id: runner; running: false }
    function run(cmd) {
        runner.command = ["bash", "-lc", cmd];
        runner.running = false;
        runner.running = true;
    }

    // ---------- Telemetry (1 Hz) ----------
    Process {
        id: tel
        running: false
        command: ["bash", "-lc",
            "read _ a b c d _ < <(grep '^cpu ' /proc/stat); "
            + "sleep 0.15; "
            + "read _ e f g h _ < <(grep '^cpu ' /proc/stat); "
            + "du=$(( (e+f+g) - (a+b+c) )); dt=$(( (e+f+g+h) - (a+b+c+d) )); "
            + "cpu=$(( dt>0 ? du*100/dt : 0 )); "
            + "mem=$(awk '/MemTotal/{t=$2}/MemAvailable/{m=$2}END{printf \"%d\",(t-m)*100/t}' /proc/meminfo); "
            + "bat=0; bst=Unknown; "
            + "if [ -d /sys/class/power_supply/BAT0 ]; then "
            + "  bat=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0); "
            + "  bst=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo Unknown); "
            + "elif [ -d /sys/class/power_supply/BAT1 ]; then "
            + "  bat=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 0); "
            + "  bst=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo Unknown); "
            + "fi; "
            + "printf '%d|%d|%d|%s|%s|%s|%s|%s' "
            + "  \"$cpu\" \"$mem\" \"$bat\" \"$bst\" "
            + "  \"$(date +%H)\" \"$(date +%M)\" \"$(date +%d)\" \"$(date +%b | tr a-z A-Z)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.split("|");
                if (p.length === 8) {
                    root.cpuVal = parseInt(p[0]) || 0;
                    root.memVal = parseInt(p[1]) || 0;
                    root.batVal = parseInt(p[2]) || 0;
                    root.batState = p[3] || "Unknown";
                    root.hh = p[4]; root.mm = p[5];
                    root.dd = p[6]; root.mon = p[7];
                }
            }
        }
    }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { tel.running = false; tel.running = true; } }

    // ---------- Workspaces (2 Hz) ----------
    Process {
        id: wsProbe
        running: false
        command: ["bash", "-lc",
            "act=$(hyprctl activeworkspace -j 2>/dev/null | sed -n 's/.*\"id\": *\\([0-9]*\\).*/\\1/p' | head -1); "
            + "ids=$(hyprctl workspaces -j 2>/dev/null | tr ',' '\\n' | sed -n 's/.*\"id\": *\\([0-9]*\\).*/\\1/p' | sort -nu | paste -sd,); "
            + "printf '%s|%s' \"${act:-1}\" \"${ids:-1}\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.split("|");
                if (p.length === 2) {
                    const next = parseInt(p[0]) || 1;
                    // Set direction first; the Workspace delegates read it
                    // inside their onActiveChanged handlers, which fire as
                    // soon as we write activeWs below.
                    if (next > root.activeWs) root.lastDirection = 1;
                    else if (next < root.activeWs) root.lastDirection = -1;
                    root.activeWs = next;
                    const have = p[1].split(",").map(s => parseInt(s)).filter(n => !isNaN(n));
                    root.existingWs = [...new Set([...have, 1, 2, 3, 4, 5])].sort((a,b) => a-b).slice(0, 9);
                }
            }
        }
    }
    Timer { interval: 500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { wsProbe.running = false; wsProbe.running = true; } }

    // ---------- Network status ----------
    Process {
        id: netProbe
        running: false
        command: ["bash", "-lc",
            "type=none; "
            + "if ip -o addr show | grep -qE '^[0-9]+: (en|eth)[^ ]*.*inet '; then type=eth; fi; "
            + "if [ \"$type\" = none ]; then "
            + "  for w in $(iw dev 2>/dev/null | awk '/Interface/{print $2}'); do "
            + "    dbm=$(iw dev \"$w\" link 2>/dev/null | awk '/signal:/{print $2}'); "
            + "    if [ -n \"$dbm\" ]; then "
            + "      pct=$((2 * (dbm + 100))); "
            + "      [ $pct -lt 0 ] && pct=0; "
            + "      [ $pct -gt 100 ] && pct=100; "
            + "      type=wifi:$pct; break; "
            + "    fi; "
            + "  done; "
            + "fi; printf '%s' \"$type\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t === "eth") root.netIcon = "󰀂";
                else if (t.startsWith("wifi:")) {
                    const sig = parseInt(t.split(":")[1]) || 0;
                    const ramp = ["󰤯","󰤟","󰤢","󰤥","󰤨"];
                    const idx = sig >= 80 ? 4 : sig >= 60 ? 3 : sig >= 40 ? 2 : sig >= 20 ? 1 : 0;
                    root.netIcon = ramp[idx];
                } else root.netIcon = "󰤮";
            }
        }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { netProbe.running = false; netProbe.running = true; } }

    // ---------- Network burst detection ----------
    // Samples cumulative rx+tx bytes from /proc/net/dev once per second.
    // When the per-second delta crosses the threshold and the burst is
    // armed, emits netBurst() and disarms for `burstCooldown.interval` ms
    // so a sustained download doesn't keep retriggering — this should read
    // as a rare event, not a continuous activity light.
    signal netBurst()
    property real netPrevBytes: -1
    property bool burstArmed: false
    // First sample after startup seeds netPrevBytes; arm only after a
    // settling beat, otherwise the initial delta (counter vs 0) would
    // always fire.
    Timer { interval: 2500; running: true; repeat: false
        onTriggered: root.burstArmed = true }

    Process {
        id: netBurstProbe
        running: false
        // $2 is rx_bytes, $10 is tx_bytes per /proc/net/dev's column layout.
        // Skip loopback so localhost chatter doesn't count as "network".
        command: ["bash", "-lc",
            "awk 'NR>2 && $1!~/^lo:/ {s+=$2+$10} END {print s+0}' /proc/net/dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                const cur = parseFloat(this.text.trim());
                if (isNaN(cur)) return;
                if (root.netPrevBytes < 0) { root.netPrevBytes = cur; return; }
                const delta = cur - root.netPrevBytes;
                root.netPrevBytes = cur;
                // ~1.5 MB in a 1s sample window. Low enough that an active
                // download or stream paints the arc regularly, high enough
                // that idle browser chatter doesn't.
                if (root.burstArmed && delta > 1.5 * 1024 * 1024) {
                    root.burstArmed = false;
                    root.netBurst();
                    burstCooldown.restart();
                }
            }
        }
    }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { netBurstProbe.running = false; netBurstProbe.running = true; } }
    Timer { id: burstCooldown; interval: 2000; repeat: false
        onTriggered: root.burstArmed = true }

    // ---------- Idle dim ----------
    // Polls hyprctl cursorpos at ~3Hz. If the cursor hasn't moved for
    // idleThresholdMs the bar eases to 0.75 opacity over 4s; the next
    // movement snaps it back over 80ms. Asymmetry is the whole point —
    // slow fade reads ambient, fast restore reads responsive.
    property string lastCursorPos: ""
    property real lastMoveMs: Date.now()
    property bool isIdle: false
    readonly property int idleThresholdMs: 30000

    Process {
        id: cursorProbe
        running: false
        command: ["bash", "-lc", "hyprctl cursorpos 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const cur = this.text.trim();
                if (!cur) return;
                if (cur !== root.lastCursorPos) {
                    root.lastCursorPos = cur;
                    root.lastMoveMs = Date.now();
                    if (root.isIdle) root.isIdle = false;
                } else if (!root.isIdle && Date.now() - root.lastMoveMs > root.idleThresholdMs) {
                    root.isIdle = true;
                }
            }
        }
    }
    Timer { interval: 300; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { cursorProbe.running = false; cursorProbe.running = true; } }

    // ---------- Bluetooth status ----------
    Process {
        id: btProbe
        running: false
        command: ["bash", "-lc",
            "p=$(bluetoothctl show 2>/dev/null | grep -c 'Powered: yes' || echo 0); "
            + "c=$(bluetoothctl devices Connected 2>/dev/null | wc -l); "
            + "if [ \"$p\" = 0 ]; then echo off; "
            + "elif [ \"$c\" -gt 0 ]; then echo on-conn; "
            + "else echo on; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = this.text.trim();
                if (s === "off") root.btIcon = "󰂲";
                else if (s === "on-conn") root.btIcon = "󰂱";
                else root.btIcon = root.icoBtOn;
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { btProbe.running = false; btProbe.running = true; } }

    // ---------- Audio status ----------
    // Icon ramps with volume: muted → icoMute, 0 → off, <50 → low, ≥50 → high.
    Process {
        id: audioProbe
        running: false
        command: ["bash", "-lc",
            "v=$(pamixer --get-volume 2>/dev/null || echo 0); "
            + "m=$(pamixer --get-mute 2>/dev/null || echo false); "
            + "printf '%s|%s' \"$v\" \"$m\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.split("|");
                if (p.length !== 2) return;
                const v = parseInt(p[0]);
                const m = p[1].trim() === "true";
                if (m) {
                    root.audioIcon = root.icoMute;
                } else if (isNaN(v) || v <= 0) {
                    root.audioIcon = root.icoVol1;
                } else if (v < 50) {
                    root.audioIcon = root.icoVol2;
                } else {
                    root.audioIcon = root.icoVol3;
                }
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { audioProbe.running = false; audioProbe.running = true; } }

    // ---------- Battery icon helper ----------
    function batteryIcon() {
        const charging = root.batState === "Charging" || root.batState === "Full";
        const c = root.batVal;
        if (charging) {
            const r = ["󰢜","󰂆","󰂇","󰂈","󰢝","󰂉","󰢞","󰂊","󰂋","󰂅"];
            return r[Math.min(9, Math.floor(c / 10))];
        }
        const r = ["󰁺","󰁻","󰁼","󰁽","󰁾","󰁿","󰂀","󰂁","󰂂","󰁹"];
        return r[Math.min(9, Math.floor(c / 10))];
    }

    // ---------- Panel ----------
    PanelWindow {
        id: bar
        color: "transparent"
        // Anchors track barEdge — three sides anchored, the side opposite
        // the bar's edge is left free for the bar's thickness to extend.
        anchors {
            top:    root.barEdge !== "bottom"
            bottom: root.barEdge !== "top"
            left:   root.barEdge !== "right"
            right:  root.barEdge !== "left"
        }
        implicitHeight: root.isHorizontal ? root.barHeight : 0
        implicitWidth:  root.isHorizontal ? 0 : root.barHeight
        exclusiveZone:  root.barHeight

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "omarchy-menu"

        Rectangle {
            anchors.fill: parent
            color: root.bg
            opacity: root.isIdle ? 0.7 : 1.0
            Behavior on opacity {
                NumberAnimation {
                    duration: root.isIdle ? 6000 : 60
                    easing.type: root.isIdle ? Easing.OutQuart : Easing.OutQuad
                }
            }

            // 静 (stillness) mark, parked in the bar's trailing corner.
            Text {
                anchors.right:  root.isHorizontal ? parent.right  : undefined
                anchors.bottom: root.isHorizontal ? undefined     : parent.bottom
                anchors.rightMargin:  root.isHorizontal ? 8 : 0
                anchors.bottomMargin: root.isHorizontal ? 0 : 8
                anchors.verticalCenter:   root.isHorizontal ? parent.verticalCenter   : undefined
                anchors.horizontalCenter: root.isHorizontal ? undefined : parent.horizontalCenter
                text: "静"
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.07)
                font.family: root.serif
                font.pixelSize: root.barHeight + 6
                font.weight: Font.Light
                z: 0
            }

            // Inner-edge hairline (facing the rest of the screen).
            Rectangle {
                visible: root.isHorizontal
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.top:    root.barEdge === "bottom" ? parent.top    : undefined
                anchors.bottom: root.barEdge === "top"    ? parent.bottom : undefined
                height: 1
                color: root.sep
            }
            Rectangle {
                visible: !root.isHorizontal
                anchors.top:    parent.top
                anchors.bottom: parent.bottom
                anchors.right:  root.barEdge === "left"  ? parent.right : undefined
                anchors.left:   root.barEdge === "right" ? parent.left  : undefined
                width: 1
                color: root.sep
            }

            // Centre cluster: clock only, clickable. Horizontal bars show
            // "HH:MM" on one line; vertical bars stack HH and MM.
            Item {
                id: clockItem
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter:   parent.verticalCenter
                z: 10

                implicitWidth:  root.isHorizontal
                                ? clockOneLine.implicitWidth + 14
                                : Math.max(clockHH.implicitWidth, clockMM.implicitWidth) + 8
                implicitHeight: root.isHorizontal
                                ? clockOneLine.implicitHeight + 8
                                : (clockHH.implicitHeight + clockMM.implicitHeight + 6)

                Bloom { id: clockBloom }

                Text {
                    id: clockOneLine
                    visible: root.isHorizontal
                    anchors.centerIn: parent
                    text: root.hh + ":" + root.mm
                    color: clockMouse.containsMouse ? root.seal : root.ink
                    font.family: root.mono
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    font.weight: Font.Light
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                Text {
                    id: clockHH
                    visible: !root.isHorizontal
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.verticalCenter
                    anchors.bottomMargin: 1
                    text: root.hh
                    color: clockMouse.containsMouse ? root.seal : root.ink
                    font.family: root.mono
                    font.pixelSize: 11
                    font.weight: Font.Light
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                Text {
                    id: clockMM
                    visible: !root.isHorizontal
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.verticalCenter
                    anchors.topMargin: 1
                    text: root.mm
                    color: clockMouse.containsMouse ? root.seal : root.ink
                    font.family: root.mono
                    font.pixelSize: 11
                    font.weight: Font.Light
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                MouseArea {
                    id: clockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: clockBloom.fire(mouseX, mouseY)
                    onClicked: {
                        if (root.calendarVisible) root.calendarVisible = false;
                        else root.openCalendar();
                    }
                }
            }

            GridLayout {
                anchors.fill: parent
                anchors.leftMargin:   root.isHorizontal ? 10 : 0
                anchors.rightMargin:  root.isHorizontal ? 10 : 0
                anchors.topMargin:    root.isHorizontal ? 0  : 10
                anchors.bottomMargin: root.isHorizontal ? 0  : 10
                flow: root.isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
                rowSpacing: 4
                columnSpacing: 4
                columns: root.isHorizontal ? -1 : 1
                rows:    root.isHorizontal ? 1  : -1

                Module {
                    glyph: root.icoOmarchy
                    color: root.seal
                    fontFamily: "omarchy"
                    fontSize: 14
                    onActivated: root.run("omarchy-menu")
                    onRightActivated: root.run("xdg-terminal-exec")
                }

                Separator {}

                Repeater {
                    model: 10
                    delegate: Workspace {
                        required property int index
                        wsId: index + 1
                        label: root.indexKanji(index + 1)
                        active: root.activeWs === (index + 1)
                        present: root.existingWs.indexOf(index + 1) !== -1
                        onActivated: root.run("hyprctl dispatch workspace " + (index + 1))
                    }
                }

                Item {
                    Layout.fillWidth:  root.isHorizontal
                    Layout.fillHeight: !root.isHorizontal
                }

                Separator {}

                Module {
                    glyph: "󰍛"
                    color: root.cpuVal > 80 ? root.seal : root.ink
                    onActivated: root.run("omarchy-launch-or-focus-tui btop")
                }

                Module {
                    id: netMod
                    glyph: root.netIcon
                    onActivated: root.run("omarchy-launch-wifi")

                    // Network-burst dot: traverses the wifi glyph's outermost
                    // arc once when a heavy rx+tx burst is detected.
                    // Geometry is eyeballed for the Nerd Font wifi icon
                    // rendered at fontSize 12 inside the 24x26 Module slot.
                    Item {
                        id: arc
                        anchors.fill: parent
                        property real t: 0
                        property real op: 0
                        readonly property real cx: width / 2
                        readonly property real cy: 17
                        readonly property real r:  6

                        Rectangle {
                            width: 3
                            height: 3
                            radius: 1.5
                            color: Qt.lighter(root.seal, 1.7)
                            antialiasing: true
                            opacity: arc.op
                            x: arc.cx - arc.r * Math.cos(Math.PI * arc.t) - width / 2
                            y: arc.cy - arc.r * Math.sin(Math.PI * arc.t) - height / 2
                        }

                        ParallelAnimation {
                            id: arcAnim
                            NumberAnimation {
                                target: arc; property: "t"
                                from: 0; to: 1
                                duration: 700
                                easing.type: Easing.InOutQuad
                            }
                            SequentialAnimation {
                                NumberAnimation { target: arc; property: "op"; from: 0; to: 1; duration: 120; easing.type: Easing.OutQuad }
                                PauseAnimation { duration: 380 }
                                NumberAnimation { target: arc; property: "op"; to: 0; duration: 200; easing.type: Easing.InCubic }
                            }
                        }

                        Connections {
                            target: root
                            function onNetBurst() { arc.t = 0; arcAnim.restart(); }
                        }
                    }
                }

                Module {
                    glyph: root.btIcon
                    onActivated: root.run("omarchy-launch-bluetooth")
                }

                Module {
                    glyph: root.audioIcon
                    onActivated: root.run("omarchy-launch-audio")
                    onRightActivated: root.run("pamixer -t")
                }

                Module {
                    glyph: root.batteryIcon()
                    color: root.batVal <= 10 ? root.seal : root.batVal <= 20 ? root.indigo : root.ink
                    onActivated: root.run("omarchy-menu power")
                }

                // Edge toggle — click to cycle top → right → bottom → left.
                // The arrow shows the current edge.
                Module {
                    glyph: root.edgeArrow()
                    color: root.sumi
                    fontSize: 12
                    onActivated: root.cycleBarEdge()
                }
            }
        }
    }

    // ---------- Calendar popup ----------
    // Full-screen transparent overlay. The card sits dead-centre on the
    // screen regardless of barEdge and scales up from its centre.
    // Keyboard focus is exclusive so Esc / Q close it without first
    // clicking inside; clicking anywhere outside the card also dismisses.
    PanelWindow {
        id: calendarPopup
        visible: root.calendarVisible || reveal > 0.001
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "omarchy-calendar"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        property real reveal: root.calendarVisible ? 1 : 0
        Behavior on reveal {
            NumberAnimation {
                duration: root.calendarVisible ? 220 : 140
                easing.type: root.calendarVisible ? Easing.OutCubic : Easing.InCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.calendarVisible = false
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 322
            height: cardCol.implicitHeight + 34
            color: root.bg
            border.color: root.sep
            border.width: 1
            radius: 0

            // Uniform scale from centre — same animation in/out, no
            // direction dependence.
            transformOrigin: Item.Center
            scale: calendarPopup.reveal

            // Take keyboard focus while visible so Esc / Q close without
            // needing a prior click.
            focus: root.calendarVisible
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
                    root.calendarVisible = false;
                    event.accepted = true;
                }
            }

            // Swallow clicks on the card so they don't bubble to the
            // outer dismiss area.
            MouseArea { anchors.fill: parent }

            Column {
                id: cardCol
                anchors.fill: parent
                anchors.margins: 17
                spacing: 12

                // Header: month label on the left, year underneath; prev /
                // today-reset / next chevrons on the right.
                Item {
                    width: parent.width
                    height: 43

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: root.calendarMonthName
                            color: root.ink
                            font.family: root.mono
                            font.pixelSize: 19
                            font.letterSpacing: 4
                            font.weight: Font.Medium
                        }
                        Text {
                            text: root.calendarYear
                            color: root.sumi
                            font.family: root.mono
                            font.pixelSize: 13
                            font.letterSpacing: 2
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Text {
                            text: "‹"
                            color: prevMouse.containsMouse ? root.seal : root.ink
                            font.family: root.mono
                            font.pixelSize: 24
                            Behavior on color { ColorAnimation { duration: 120 } }
                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent
                                anchors.margins: -7
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.calendarMonthOffset--; root.calendarTick++; }
                            }
                        }
                        Text {
                            text: "•"
                            color: todayMouse.containsMouse ? root.seal : root.sumi
                            font.family: root.mono
                            font.pixelSize: 19
                            Behavior on color { ColorAnimation { duration: 120 } }
                            MouseArea {
                                id: todayMouse
                                anchors.fill: parent
                                anchors.margins: -7
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.calendarMonthOffset = 0; root.calendarTick++; }
                            }
                        }
                        Text {
                            text: "›"
                            color: nextMouse.containsMouse ? root.seal : root.ink
                            font.family: root.mono
                            font.pixelSize: 24
                            Behavior on color { ColorAnimation { duration: 120 } }
                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                anchors.margins: -7
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.calendarMonthOffset++; root.calendarTick++; }
                            }
                        }
                    }
                }

                // Hairline under header.
                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.sep
                }

                // Weekday row (Monday first). Sat/Sun tinted seal so the
                // week's shape is readable at a glance.
                Row {
                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: ["MO","TU","WE","TH","FR","SA","SU"]
                        delegate: Item {
                            required property string modelData
                            required property int index
                            width: cardCol.width / 7
                            height: 22
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: index >= 5 ? root.seal : root.sumi
                                opacity: index >= 5 ? 0.85 : 0.7
                                font.family: root.mono
                                font.pixelSize: 12
                                font.letterSpacing: 2
                            }
                        }
                    }
                }

                // Day grid: 6 rows of 7 cells. Today is a filled chip with
                // theme-aware contrast text. Inactive (leading/trailing
                // month) days are faded to maintain the grid silhouette.
                Grid {
                    columns: 7
                    rowSpacing: 2
                    columnSpacing: 0
                    width: parent.width

                    Repeater {
                        model: root.calendarCells
                        delegate: Item {
                            id: dayCell
                            required property var modelData
                            required property int index
                            width: cardCol.width / 7
                            height: 34

                            readonly property int  dayOfWeek: index % 7
                            readonly property bool isWeekend: dayOfWeek >= 5
                            readonly property bool isCurrentMonth: modelData.day !== 0
                            readonly property bool isToday: modelData.today

                            // Today chip.
                            Rectangle {
                                anchors.centerIn: parent
                                width: 29
                                height: 29
                                radius: 14
                                color: root.seal
                                visible: dayCell.isToday
                                antialiasing: true
                            }

                            // Hover halo on regular cells.
                            Rectangle {
                                anchors.centerIn: parent
                                width: 29
                                height: 29
                                radius: 14
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                visible: dayMouse.containsMouse && !dayCell.isToday && dayCell.isCurrentMonth
                                antialiasing: true
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: dayCell.modelData.day === 0 ? "" : dayCell.modelData.day
                                color: dayCell.isToday
                                       ? (root.seal.hsvValue < 0.5 ? root.ink : root.paper)
                                       : (dayCell.isCurrentMonth
                                          ? (dayCell.isWeekend ? root.seal : root.ink)
                                          : root.sumi)
                                opacity: dayCell.isCurrentMonth ? 1.0 : 0.35
                                font.family: root.mono
                                font.pixelSize: 15
                                font.weight: dayCell.isToday ? Font.Medium : Font.Light
                            }

                            MouseArea {
                                id: dayMouse
                                anchors.fill: parent
                                hoverEnabled: dayCell.isCurrentMonth
                                enabled: dayCell.isCurrentMonth
                                cursorShape: dayCell.isCurrentMonth
                                             ? Qt.PointingHandCursor
                                             : Qt.ArrowCursor
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------- Components ----------
    component Separator: Rectangle {
        Layout.alignment: root.isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter
        Layout.preferredWidth:  root.isHorizontal ? 1  : 12
        Layout.preferredHeight: root.isHorizontal ? 12 : 1
        Layout.leftMargin:   root.isHorizontal ? 4 : 0
        Layout.rightMargin:  root.isHorizontal ? 4 : 0
        Layout.topMargin:    root.isHorizontal ? 0 : 4
        Layout.bottomMargin: root.isHorizontal ? 0 : 4
        color: root.sep
    }

    // Hover bloom: a soft accent-tinted halo that radiates from the cursor's
    // entry point and fades inside the item rect. Single-beat sibling of
    // clipboard-ripple — same halo/ox/oy/haloR/haloO vocabulary, just
    // scaled down for the bar (~250 ms, no inner core pulse) and clipped to
    // the host bounds so neighbours don't get splashed.
    component Bloom: Item {
        id: bloomRoot
        anchors.fill: parent
        clip: true

        property real ox: 0
        property real oy: 0
        property real haloR: 0
        property real haloO: 0

        function fire(x, y) {
            bloomRoot.ox = x;
            bloomRoot.oy = y;
            bloomAnim.restart();
        }

        Rectangle {
            width: bloomRoot.haloR * 2
            height: bloomRoot.haloR * 2
            radius: bloomRoot.haloR
            x: bloomRoot.ox - bloomRoot.haloR
            y: bloomRoot.oy - bloomRoot.haloR
            color: Qt.lighter(root.accent, 1.35)
            opacity: bloomRoot.haloO
            antialiasing: true
        }

        SequentialAnimation {
            id: bloomAnim
            ScriptAction { script: { bloomRoot.haloR = 0; bloomRoot.haloO = 0; } }
            ParallelAnimation {
                NumberAnimation {
                    target: bloomRoot; property: "haloR"
                    from: 2; to: Math.max(bloomRoot.width, bloomRoot.height) * 0.9
                    duration: 250
                    easing.type: Easing.OutCubic
                }
                SequentialAnimation {
                    NumberAnimation { target: bloomRoot; property: "haloO"; from: 0; to: 0.22; duration: 80; easing.type: Easing.OutQuad }
                    NumberAnimation { target: bloomRoot; property: "haloO"; to: 0; duration: 170; easing.type: Easing.InCubic }
                }
            }
        }
    }

    component Module: Item {
        property string glyph: ""
        property color color: root.ink
        property string fontFamily: root.mono
        property int fontSize: 12

        signal activated()
        signal rightActivated()

        Layout.alignment: root.isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter
        Layout.preferredWidth:  root.isHorizontal ? 24 : root.barHeight
        Layout.preferredHeight: root.isHorizontal ? root.barHeight : 24

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 0
            color: mouse.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        Bloom { id: bloom }

        Text {
            anchors.centerIn: parent
            text: glyph
            color: parent.color
            font.family: parent.fontFamily
            font.pixelSize: parent.fontSize
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onEntered: bloom.fire(mouseX, mouseY)
            onClicked: (e) => {
                if (e.button === Qt.RightButton) parent.rightActivated();
                else parent.activated();
            }
        }
    }

    // Workspace cell.
    component Workspace: Item {
        id: wsCell
        property int wsId: 0
        property string label: ""
        property bool active: false
        property bool present: false
        signal activated()

        Layout.alignment: root.isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter
        Layout.preferredWidth:  root.isHorizontal ? 20 : root.barHeight
        Layout.preferredHeight: root.isHorizontal ? root.barHeight : 20

        onActiveChanged: {
            if (active && root.lastDirection !== 0) {
                slideHome.stop();
                if (root.isHorizontal) {
                    kanji.slideX = root.lastDirection * 2;
                    kanji.slideY = 0;
                } else {
                    kanji.slideY = root.lastDirection * 2;
                    kanji.slideX = 0;
                }
                slideHome.start();
            }
        }

        NumberAnimation {
            id: slideHome
            target: kanji
            properties: "slideX,slideY"
            to: 0
            duration: 180
            easing.type: Easing.OutCubic
        }

        Bloom { id: bloom }

        Text {
            id: kanji
            property real slideX: 0
            property real slideY: 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: slideX
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: slideY
            text: label
            color: active ? root.seal : (present ? root.ink : root.sumi)
            opacity: active ? 1.0 : (present ? 0.75 : 0.35)
            font.family: root.serif
            font.pixelSize: active ? 14 : 12
            font.weight: Font.Light
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on font.pixelSize { NumberAnimation { duration: 120 } }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: bloom.fire(mouseX, mouseY)
            onClicked: parent.activated()
        }
    }
}
