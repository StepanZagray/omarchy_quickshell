import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var shell

    property bool osdVisible: false
    property string osdKind: "" // volume | brightness | kbd-brightness | caps | mic | touchpad
    property int osdValue: 0
    property bool osdMuted: false
    property bool osdActive: false
    property string osdLabel: ""
    property string osdScreen: ""

    property bool _lastCaps: false
    property bool _capsSeeded: false

    // Prefer the internal panel backlight on eDP/LVDS; otherwise walk sysfs in
    // Omarchy order (amdgpu → intel → acpi → nvidia).
    readonly property string _brightnessDeviceScript: "focus=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null); " + "device=\"\"; " + "if [[ \"$focus\" == eDP* || \"$focus\" == LVDS* ]] && [ -e /sys/class/backlight/intel_backlight ]; then device=intel_backlight; " + "else for c in amdgpu_bl* intel_backlight acpi_video* nvidia_*; do " + "[ -e \"/sys/class/backlight/$c\" ] && device=\"$c\" && break; done; fi"

    readonly property string _kbdLedScript: "for c in /sys/class/leds/*kbd_backlight*; do " + "[ -e \"$c\" ] && basename \"$c\" && break; done"

    readonly property string _touchpadStatePath: Quickshell.env("HOME") + "/.local/state/omarchy/toggles/hypr/touchpad-disabled.conf"

    function _screenName() {
        const name = shell.focusedScreenName();
        return name.length > 0 ? name : shell.focusedMonitorName;
    }

    function show(kind, value, muted, label, active) {
        root.osdKind = kind;
        root.osdValue = Math.max(0, Math.min(100, Math.round(value)));
        root.osdMuted = !!muted;
        root.osdLabel = label || "";
        root.osdActive = active !== undefined ? !!active : false;
        root.osdScreen = root._screenName();
        root.osdVisible = true;
        hideTimer.restart();
    }

    function showBar(kind, value, muted) {
        root.show(kind, value, muted, "", false);
    }

    function showStatus(kind, label, active) {
        root.show(kind, active ? 100 : 0, false, label, active);
    }

    function hide() {
        root.osdVisible = false;
    }

    function volumeRaise() { root.volumeAdjust("raise"); }
    function volumeLower() { root.volumeAdjust("lower"); }
    function volumeMute() { root.volumeAdjust("mute"); }
    function volumeUp1() { root.volumeAdjust("+1"); }
    function volumeDown1() { root.volumeAdjust("-1"); }
    function brightnessUp(step) { root.brightnessAdjust(step); }
    function brightnessDown(step) { root.brightnessAdjust(-step); }
    function brightnessMax() { root.brightnessSet(100); }
    function brightnessMin() { root.brightnessSet(1); }
    function kbdBrightnessUp() { root.kbdBrightnessAdjust("up"); }
    function kbdBrightnessDown() { root.kbdBrightnessAdjust("down"); }
    function kbdBrightnessCycle() { root.kbdBrightnessAdjust("cycle"); }
    function micMuteToggle() { root.micMuteProbe.running = false; root.micMuteProbe.running = true; }
    function touchpadToggle() { root.touchpadAdjust("toggle"); }
    function touchpadOn() { root.touchpadAdjust("on"); }
    function touchpadOff() { root.touchpadAdjust("off"); }

    function volumeAdjust(mode) {
        let cmd = "";
        if (mode === "raise")
            cmd = "pamixer --allow-boost --increase 5";
        else if (mode === "lower")
            cmd = "pamixer --allow-boost --decrease 5";
        else if (mode === "mute")
            cmd = "pamixer -t";
        else if (mode === "+1")
            cmd = "pamixer --allow-boost --increase 1";
        else if (mode === "-1")
            cmd = "pamixer --allow-boost --decrease 1";
        else
            return;

        volumeProbe.command = ["bash", "-lc", cmd + "; v=$(pamixer --get-volume 2>/dev/null || echo 0); " + "m=$(pamixer --get-mute 2>/dev/null || echo false); " + "printf '%s|%s' \"$v\" \"$m\""];
        volumeProbe.running = false;
        volumeProbe.running = true;
    }

    function brightnessSet(target) {
        const pct = Math.max(1, Math.min(100, Math.round(target)));
        root.showBar("brightness", pct, false);
        root._runBrightnessProbe("omarchy-brightness-display " + pct + "%");
    }

    function brightnessAdjust(delta) {
        const step = Math.round(delta);
        if (step === 0)
            return;

        const est = Math.max(1, Math.min(100, shell.brightnessPct + step));
        root.showBar("brightness", est, false);

        const arg = step > 0 ? "+" + step + "%" : (-step) + "%-";
        root._runBrightnessProbe("omarchy-brightness-display " + arg);
    }

    function _runBrightnessProbe(adjustCmd) {
        brightnessProbe.command = ["bash", "-lc", adjustCmd + " >/dev/null 2>&1; " + root._brightnessDeviceScript + "; " + "pct=$(brightnessctl -d \"$device\" -m 2>/dev/null | cut -d',' -f4 | tr -d '%'); " + "printf '%s' \"${pct:-0}\""];
        brightnessProbe.running = false;
        brightnessProbe.running = true;
    }

    function kbdBrightnessAdjust(direction) {
        kbdBrightnessProbe.command = ["bash", "-lc", "device=$(" + root._kbdLedScript + "); " + "[ -n \"$device\" ] || exit 1; " + "max=$(brightnessctl -d \"$device\" max 2>/dev/null); " + "cur=$(brightnessctl -d \"$device\" get 2>/dev/null); " + "step=$(( max / 10 )); [ \"$step\" -lt 1 ] && step=1; " + "dir=\"" + direction + "\"; " + "if [ \"$dir\" = cycle ]; then n=$((cur + step)); [ \"$n\" -gt \"$max\" ] && n=0; " + "elif [ \"$dir\" = up ]; then n=$((cur + step)); [ \"$n\" -gt \"$max\" ] && n=$max; " + "else n=$((cur - step)); [ \"$n\" -lt 0 ] && n=0; fi; " + "brightnessctl -d \"$device\" set \"$n\" >/dev/null; " + "pct=$(( n * 100 / max )); printf '%s' \"$pct\""];
        kbdBrightnessProbe.running = false;
        kbdBrightnessProbe.running = true;
    }

    function touchpadAdjust(mode) {
        touchpadProbe.command = ["bash", "-lc", "device=$(omarchy-hw-touchpad 2>/dev/null || true); " + "[ -n \"$device\" ] || exit 1; " + "state=\"" + JSON.stringify(root._touchpadStatePath) + "\"; " + "action=\"" + mode + "\"; " + "enable() { hyprctl keyword \"device[$device]:enabled\" true >/dev/null; rm -f \"$state\"; echo enabled; }; " + "disable() { hyprctl keyword \"device[$device]:enabled\" false >/dev/null; mkdir -p \"$(dirname \"$state\")\"; " + "printf 'device {\\n    name = %s\\n    enabled = false\\n}\\n' \"$device\" > \"$state\"; echo disabled; }; " + "case \"$action\" in on) enable;; off) disable;; toggle) if [ -f \"$state\" ]; then enable; else disable; fi;; esac"];
        touchpadProbe.running = false;
        touchpadProbe.running = true;
    }

    Timer {
        id: hideTimer

        interval: 1200
        onTriggered: root.hide()
    }

    Timer {
        id: capsPoll

        interval: 300
        repeat: true
        running: true
        onTriggered: {
            capsProbe.running = false;
            capsProbe.running = true;
        }
    }

    Process {
        id: volumeProbe

        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.split("|");
                if (p.length !== 2)
                    return;

                const v = parseInt(p[0]);
                const m = p[1].trim() === "true";
                shell.audioVol = isNaN(v) ? 0 : v;
                shell.audioMuted = m;
                if (m)
                    shell.audioIcon = shell.icoMute;
                else if (isNaN(v) || v <= 0)
                    shell.audioIcon = shell.icoVol1;
                else if (v < 50)
                    shell.audioIcon = shell.icoVol2;
                else
                    shell.audioIcon = shell.icoVol3;
                root.showBar("volume", isNaN(v) ? 0 : v, m);
            }
        }
    }

    Process {
        id: brightnessProbe

        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const pct = parseInt(this.text.trim(), 10);
                if (isNaN(pct))
                    return;

                root.showBar("brightness", pct, false);
                shell.brightnessPct = pct;
            }
        }
    }

    Process {
        id: kbdBrightnessProbe

        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const pct = parseInt(this.text.trim());
                if (isNaN(pct))
                    return;

                root.showBar("kbd-brightness", pct, false);
            }
        }
    }

    Process {
        id: micMuteProbe

        running: false
        command: ["bash", "-lc", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle >/dev/null; " + "if pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | rg -q yes; then echo muted; else echo live; fi"]

        stdout: StdioCollector {
            onStreamFinished: {
                const muted = this.text.trim() === "muted";
                root.showStatus("mic", muted ? "Mic muted" : "Mic on", !muted);
            }
        }
    }

    Process {
        id: touchpadProbe

        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const state = this.text.trim();
                if (state === "enabled")
                    root.showStatus("touchpad", "Touchpad on", true);
                else if (state === "disabled")
                    root.showStatus("touchpad", "Touchpad off", false);
            }
        }
    }

    Process {
        id: capsProbe

        running: false
        command: ["bash", "-lc", "hyprctl devices -j 2>/dev/null | jq -r '.keyboards[] | select(.main==true) | .capsLock'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const on = this.text.trim() === "true";
                if (!root._capsSeeded) {
                    root._capsSeeded = true;
                    root._lastCaps = on;
                    return;
                }
                if (on === root._lastCaps)
                    return;

                root._lastCaps = on;
                root.showStatus("caps", on ? "Caps on" : "Caps off", on);
            }
        }
    }

    Component.onCompleted: capsProbe.running = true
}
