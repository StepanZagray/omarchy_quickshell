import QtQuick
import Quickshell.Io

Item {
    id: root

    required property var shell
    property int batVal: 0
    property string batState: "Unknown"
    property real batPower: 0
    property string hh: "--"
    property string mm: "--"
    property string dd: "--"
    property string mon: "---"
    property string powerProfile: ""
    property var powerProfiles: []

    function setPowerProfile(name) {
        if (!name)
            return;

        root.powerProfile = name;
        shell.run("powerprofilesctl set " + name);
        powerProfileRefreshTimer.restart();
    }

    function refreshPowerProfile() {
        powerProfileProbe.running = false;
        powerProfileProbe.running = true;
    }

    function batteryIcon() {
        if (root.batState === "Charging" || root.batState === "Full" || root.batState === "Not charging")
            return shell.icoPlug;

        const c = root.batVal;
        const r = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        return r[Math.min(9, Math.floor(c / 10))];
    }

    Component.onCompleted: refreshPowerProfile()

    Timer {
        id: powerProfileRefreshTimer

        interval: 400
        repeat: false
        onTriggered: root.refreshPowerProfile()
    }

    Process {
        id: tel

        running: false
        command: ["bash", "-lc", "bat=0; bst=Unknown; pwr=0; " + "if [ -d /sys/class/power_supply/BAT0 ]; then " + "  bat=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0); " + "  bst=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo Unknown); " + "  pwr=$(cat /sys/class/power_supply/BAT0/power_now 2>/dev/null || echo 0); " + "elif [ -d /sys/class/power_supply/BAT1 ]; then " + "  bat=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 0); " + "  bst=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo Unknown); " + "  pwr=$(cat /sys/class/power_supply/BAT1/power_now 2>/dev/null || echo 0); " + "fi; " + "pwr=${pwr#-}; " + "printf '%d|%s|%s|%s|%s|%s|%d' " + "  \"$bat\" \"$bst\" " + "  \"$(date +%H)\" \"$(date +%M)\" \"$(date +%d)\" \"$(date +%b)\" \"$pwr\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.split("|");
                if (p.length === 7) {
                    root.batVal = parseInt(p[0]) || 0;
                    root.batState = p[1] || "Unknown";
                    root.hh = p[2];
                    root.mm = p[3];
                    root.dd = p[4];
                    root.mon = p[5];
                    root.batPower = (parseInt(p[6]) || 0) / 1e6;
                }
            }
        }

    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            tel.running = false;
            tel.running = true;
        }
    }

    Process {
        id: powerProfileProbe

        running: false
        command: ["bash", "-lc", "cur=$(powerprofilesctl get 2>/dev/null); " + "if [ -z \"$cur\" ]; then echo '|'; exit 0; fi; " + "list=$(powerprofilesctl list 2>/dev/null | awk -F: '/^[ *]+[a-z-]+:/{gsub(/^[ *]+|:$/,\"\",$1); print $1}' | paste -sd,); " + "printf '%s|%s' \"$cur\" \"$list\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split("|");
                if (p.length !== 2)
                    return;

                const cur = p[0] || "";
                const list = p[1] ? p[1].split(",").filter(Boolean) : [];
                if (root.powerProfile !== cur)
                    root.powerProfile = cur;

                if (JSON.stringify(root.powerProfiles) !== JSON.stringify(list))
                    root.powerProfiles = list;

            }
        }

    }

}
