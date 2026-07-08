import QtQuick
import Quickshell.Io

Item {
    id: root

    required property var shell
    property bool displayVisible: false
    property real warmthK: 6500
    property int brightnessPct: 100
    property real gammaPct: 100
    property string monitorName: "eDP-1"
    property string monitorRes: "2880x1800"
    property real monitorRate: 60
    property real monitorScale: 2
    readonly property var displayPresets: [{
        "label": "DAY",
        "warmth": 6500,
        "gamma": 100,
        "bright": 100
    }, {
        "label": "READING",
        "warmth": 4500,
        "gamma": 95,
        "bright": 60
    }, {
        "label": "NIGHT",
        "warmth": 3000,
        "gamma": 85,
        "bright": 30
    }, {
        "label": "CANDLE",
        "warmth": 2000,
        "gamma": 80,
        "bright": 15
    }]
    property int selectedPreset: 0
    property int displayRow: 0
    property bool sunsetReady: false
    readonly property string ensureSunset: "pgrep -x hyprsunset >/dev/null" + " || { uwsm app -- hyprsunset --gamma_max 200 >/dev/null 2>&1 &" + "      for i in 1 2 3 4 5 6 7 8; do" + "        hyprctl hyprsunset identity >/dev/null 2>&1 && break;" + "        sleep 0.08;" + "      done; }; "

    function openDisplay() {
        if (shell.displayAnchorItem)
            shell.anchorPopupTo(shell.displayAnchorItem);

        displayProbe.running = true;
        root.displayRow = 0;
        root.displayVisible = true;
    }

    function runSunset(verb) {
        const cmd = "hyprctl hyprsunset " + verb;
        if (root.sunsetReady) {
            shell.run(cmd);
        } else {
            shell.run(root.ensureSunset + cmd);
            root.sunsetReady = true;
        }
    }

    function setWarmth(k) {
        k = Math.max(1000, Math.min(6500, Math.round(k / 50) * 50));
        root.warmthK = k;
        root.runSunset(k >= 6500 ? "identity" : "temperature " + k);
    }

    function setBrightness(pct) {
        pct = Math.max(1, Math.min(100, Math.round(pct)));
        root.brightnessPct = pct;
        shell.run("brightnessctl set " + pct + "%");
    }

    function setGamma(pct) {
        pct = Math.max(50, Math.min(150, Math.round(pct)));
        root.gammaPct = pct;
        root.runSunset("gamma " + pct);
    }

    function applyPreset(p) {
        root.warmthK = p.warmth;
        root.gammaPct = p.gamma;
        root.brightnessPct = p.bright;
        const w = (p.warmth >= 6500) ? "identity" : "temperature " + p.warmth;
        const prelude = root.sunsetReady ? "" : root.ensureSunset;
        shell.run(prelude + "hyprctl hyprsunset " + w + " && hyprctl hyprsunset gamma " + p.gamma + " && brightnessctl set " + p.bright + "%");
        root.sunsetReady = true;
    }

    function blankScreen() {
        shell.run("sleep 0.25 && hyprctl dispatch dpms off");
        root.displayVisible = false;
    }

    function resetDisplay() {
        root.warmthK = 6500;
        root.gammaPct = 100;
        root.brightnessPct = 100;
        const prelude = root.sunsetReady ? "" : root.ensureSunset;
        shell.run(prelude + "hyprctl hyprsunset identity" + " && hyprctl hyprsunset gamma 100" + " && brightnessctl set 100%");
        root.sunsetReady = true;
    }

    Process {
        id: displayProbe

        running: false
        command: ["bash", "-lc", "m=$(hyprctl monitors -j 2>/dev/null" + " | jq -r '.[0] | [.name,(\"\\(.width)x\\(.height)\"),(.refreshRate|tostring),(.scale|tostring)] | join(\"|\")' 2>/dev/null);" + " b=$(brightnessctl get 2>/dev/null);" + " mb=$(brightnessctl max 2>/dev/null);" + " pct=100;" + " if [ -n \"$b\" ] && [ -n \"$mb\" ] && [ \"$mb\" -gt 0 ]; then pct=$(( b * 100 / mb )); fi;" + " printf '%s|%d' \"$m\" \"$pct\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split("|");
                if (p.length < 5)
                    return;

                root.monitorName = p[0] || "eDP-1";
                root.monitorRes = p[1] || "2880x1800";
                root.monitorRate = parseFloat(p[2]) || 60;
                root.monitorScale = parseFloat(p[3]) || 1;
                root.brightnessPct = parseInt(p[4]) || 100;
            }
        }

    }

}
