import QtQuick
import Quickshell.Io

Item {
    id: root

    required property var shell
    property string netIcon: "󰤯"
    property string netKind: "none"
    property string wifiSsid: ""
    property int wifiSignal: 0
    property var wifiNetworks: []
    property bool wifiRadioOn: true
    property bool wifiScanning: false
    property string _wifiNetworksSer: ""
    property string btIcon: "󰂲"
    property bool btPowered: false
    property int btCount: 0
    property var btDevices: []
    property bool btScanning: false
    property string _btDevicesSer: ""
    property real netPrevBytes: -1
    property bool burstArmed: false
    readonly property var _wifiBarsRamp: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]

    function wifiBarsGlyph(pct) {
        const idx = pct >= 80 ? 4 : pct >= 60 ? 3 : pct >= 40 ? 2 : pct >= 20 ? 1 : 0;
        return root._wifiBarsRamp[idx];
    }

    function refreshWifi() {
        if (wifiScanProbe.running)
            return;

        root.wifiScanning = true;
        wifiScanProbe.running = false;
        wifiScanProbe.running = true;
    }

    function connectWifi(ssid) {
        if (!ssid)
            return;

        shell.run("DEV=$(iwctl --dont-ask device list 2>/dev/null" + " | sed 's/\\x1b\\[[0-9;]*m//g'" + " | awk '/station/{print $1; exit}');" + " [ -n \"$DEV\" ] && iwctl --dont-ask station \"$DEV\" connect " + JSON.stringify(ssid));
        wifiPostConnectTimer.restart();
    }

    function disconnectWifi() {
        shell.run("DEV=$(iwctl --dont-ask device list 2>/dev/null" + " | sed 's/\\x1b\\[[0-9;]*m//g'" + " | awk '/station/{print $1; exit}');" + " [ -n \"$DEV\" ] && iwctl --dont-ask station \"$DEV\" disconnect");
        wifiPostConnectTimer.restart();
    }

    function toggleWifiRadio() {
        const target = root.wifiRadioOn ? "off" : "on";
        root.wifiRadioOn = !root.wifiRadioOn;
        shell.run("DEV=$(iwctl --dont-ask device list 2>/dev/null" + " | sed 's/\\x1b\\[[0-9;]*m//g'" + " | awk '/^[[:space:]]+[a-z][a-z0-9]+/{print $1; exit}');" + " [ -n \"$DEV\" ] && iwctl --dont-ask device \"$DEV\" set-property Powered " + target);
        wifiPostConnectTimer.restart();
    }

    function refreshBluetooth() {
        if (btDevicesProbe.running)
            return;

        btDevicesProbe.running = false;
        btDevicesProbe.running = true;
    }

    function btConnect(mac) {
        if (!mac)
            return;

        shell.run("bt-device --connect " + mac);
        btPostActionTimer.restart();
    }

    function btDisconnect(mac) {
        if (!mac)
            return;

        shell.run("bt-device --disconnect " + mac);
        btPostActionTimer.restart();
    }

    function btTogglePower() {
        root.btPowered = !root.btPowered;
        shell.run("bt-adapter -s Powered " + (root.btPowered ? 1 : 0));
        btPostActionTimer.restart();
    }

    function btToggleScan() {
        root.btScanning = !root.btScanning;
        if (root.btScanning) {
            shell.run("setsid -f bt-adapter -d --timeout 15 >/dev/null 2>&1");
            btScanStopTimer.restart();
        }
        btPostActionTimer.restart();
    }

    Timer {
        id: wifiPostConnectTimer

        interval: 800
        repeat: false
        onTriggered: root.refreshWifi()
    }

    Timer {
        id: btPostActionTimer

        interval: 600
        repeat: false
        onTriggered: root.refreshBluetooth()
    }

    Timer {
        id: btScanStopTimer

        interval: 15000
        repeat: false
        onTriggered: root.btScanning = false
    }

    Process {
        id: netProbe

        running: false
        command: ["bash", "-lc", "type=none; " + "if ip -o addr show | grep -qE '^[0-9]+: (en|eth)[^ ]*.*inet '; then type=eth; fi; " + "if [ \"$type\" = none ]; then " + "  for w in $(iw dev 2>/dev/null | awk '/Interface/{print $2}'); do " + "    link=$(iw dev \"$w\" link 2>/dev/null); " + "    dbm=$(printf '%s\\n' \"$link\" | awk '/signal:/{print $2}'); " + "    if [ -n \"$dbm\" ]; then " + "      pct=$((2 * (dbm + 100))); " + "      [ $pct -lt 0 ] && pct=0; " + "      [ $pct -gt 100 ] && pct=100; " + "      ssid=$(printf '%s\\n' \"$link\" | sed -n 's/^[[:space:]]*SSID: //p'); " + "      type=\"wifi:$pct:$ssid\"; break; " + "    fi; " + "  done; " + "fi; printf '%s' \"$type\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t === "eth") {
                    root.netIcon = "󰀂";
                    root.netKind = "eth";
                    root.wifiSsid = "";
                    root.wifiSignal = 0;
                } else if (t.startsWith("wifi:")) {
                    const rest = t.slice(5);
                    const c = rest.indexOf(":");
                    const sig = parseInt(c < 0 ? rest : rest.slice(0, c)) || 0;
                    const ssid = c < 0 ? "" : rest.slice(c + 1);
                    root.netIcon = root.wifiBarsGlyph(sig);
                    root.netKind = "wifi";
                    root.wifiSignal = sig;
                    root.wifiSsid = ssid;
                } else {
                    root.netIcon = "󰤮";
                    root.netKind = "none";
                    root.wifiSsid = "";
                    root.wifiSignal = 0;
                }
            }
        }

    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netProbe.running = false;
            netProbe.running = true;
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: false
        onTriggered: root.burstArmed = true
    }

    Process {
        id: netBurstProbe

        running: false
        command: ["awk", "NR>2 && $1!~/^lo:/ {s+=$2+$10} END {print s+0}", "/proc/net/dev"]

        stdout: StdioCollector {
            onStreamFinished: {
                const cur = parseFloat(this.text.trim());
                if (isNaN(cur))
                    return;

                if (root.netPrevBytes < 0) {
                    root.netPrevBytes = cur;
                    return;
                }
                const delta = cur - root.netPrevBytes;
                root.netPrevBytes = cur;
                if (root.burstArmed && delta > 1.5 * 1024 * 1024) {
                    root.burstArmed = false;
                    shell.netBurst();
                    burstCooldown.restart();
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
            netBurstProbe.running = false;
            netBurstProbe.running = true;
        }
    }

    Timer {
        id: burstCooldown

        interval: 2000
        repeat: false
        onTriggered: root.burstArmed = true
    }

    Process {
        id: btProbe

        running: false
        command: ["bash", "-lc", "p=$(bt-adapter --info 2>/dev/null | awk '/Powered:/{print $2; exit}');" + " if [ \"$p\" = 1 ]; then echo on; else echo off; fi"]

        stdout: StdioCollector {
            onStreamFinished: {
                const s = this.text.trim();
                const powered = (s === "on");
                if (root.btPowered !== powered)
                    root.btPowered = powered;

                if (!powered) {
                    if (root.btIcon !== "󰂲")
                        root.btIcon = "󰂲";

                    if (root.btCount !== 0)
                        root.btCount = 0;

                } else {
                    const icon = root.btCount > 0 ? "󰂱" : shell.icoBtOn;
                    if (root.btIcon !== icon)
                        root.btIcon = icon;

                }
            }
        }

    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            btProbe.running = false;
            btProbe.running = true;
        }
    }

    Process {
        id: btDevicesProbe

        running: false
        command: ["bash", "-lc", "macs=$(bt-device -l 2>/dev/null | tail -n +2" + "   | sed -n 's/.*(\\([0-9A-F:]\\{17\\}\\))$/\\1/p');" + " for m in $macs; do" + "   info=$(bt-device --info \"$m\" 2>/dev/null);" + "   [ -z \"$info\" ] && continue;" + "   name=$(printf '%s' \"$info\" | awk -F': ' '/^[[:space:]]*Name:/{print $2; exit}');" + "   conn=$(printf '%s' \"$info\" | awk '/^[[:space:]]*Connected: 1/{print 1; exit}');" + "   paired=$(printf '%s' \"$info\" | awk '/^[[:space:]]*Paired: 1/{print 1; exit}');" + "   trusted=$(printf '%s' \"$info\" | awk '/^[[:space:]]*Trusted: 1/{print 1; exit}');" + "   printf '%s\\t%s\\t%s\\t%s\\t%s\\n' \"$m\" \"${name:-$m}\" \"${conn:-0}\" \"${paired:-0}\" \"${trusted:-0}\";" + " done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter((s) => {
                    return s.length > 0;
                });
                const devs = lines.map((line) => {
                    const f = line.split("\t");
                    return {
                        "mac": f[0] || "",
                        "name": (f[1] || "").trim() || (f[0] || ""),
                        "connected": f[2] === "1",
                        "paired": f[3] === "1",
                        "trusted": f[4] === "1"
                    };
                });
                devs.sort((a, b) => {
                    return (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name);
                });
                const serialised = JSON.stringify(devs);
                if (serialised === root._btDevicesSer)
                    return;

                root._btDevicesSer = serialised;
                root.btDevices = devs;
                const connCount = devs.filter((d) => {
                    return d.connected;
                }).length;
                if (root.btCount !== connCount)
                    root.btCount = connCount;

            }
        }

    }

    Process {
        id: wifiScanProbe

        running: false
        command: ["bash", "-lc", "DEV=$(iwctl --dont-ask device list 2>/dev/null" + "   | sed 's/\\x1b\\[[0-9;]*m//g'" + "   | awk '/station/{print $1; exit}');" + " if [ -z \"$DEV\" ]; then echo 'RADIO|off'; exit 0; fi;" + " powered=$(iwctl --dont-ask device \"$DEV\" show 2>/dev/null" + "   | sed 's/\\x1b\\[[0-9;]*m//g'" + "   | awk '/Powered/{print $NF; exit}');" + " if [ \"$powered\" != on ]; then echo 'RADIO|off'; exit 0; fi;" + " echo 'RADIO|on';" + " iwctl --dont-ask station \"$DEV\" scan >/dev/null 2>&1;" + " iwctl --dont-ask station \"$DEV\" get-networks rssi-dbms 2>/dev/null" + "   | sed 's/\\x1b\\[[0-9;]*m//g'" + "   | awk '" + "       /^-+$/ { sep++; next }" + "       sep < 2 || $0 ~ /^[[:space:]]*$/ { next }" + "       {" + "         line=$0;" + "         conn=(index(substr(line,1,4),\">\")>0)?1:0;" + "         sub(/^[ >]+/, \"\", line);" + "         sub(/[ ]+$/, \"\", line);" + "         if (match(line, /^(.*[^ ])  +([^ ]+)  +(-?[0-9]+)$/, m))" + "           printf \"%d\\t%s\\t%s\\t%s\\n\", conn, m[1], m[2], m[3];" + "       }'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter((s) => {
                    return s.length > 0;
                });
                let radioOn = false;
                const networks = [];
                for (const line of lines) {
                    if (line.startsWith("RADIO|")) {
                        radioOn = line.slice(6) === "on";
                        continue;
                    }
                    const f = line.split("\t");
                    if (f.length < 4)
                        continue;

                    const dbm = parseInt(f[3]) / 100;
                    const pct = Math.max(0, Math.min(100, Math.round(2 * (dbm + 100))));
                    networks.push({
                        "inUse": f[0] === "1",
                        "ssid": f[1],
                        "signal": pct,
                        "security": f[2]
                    });
                }
                networks.sort((a, b) => {
                    return (b.inUse - a.inUse) || (b.signal - a.signal);
                });
                if (root.wifiRadioOn !== radioOn)
                    root.wifiRadioOn = radioOn;

                const ser = JSON.stringify(networks);
                if (ser !== root._wifiNetworksSer) {
                    root._wifiNetworksSer = ser;
                    root.wifiNetworks = networks;
                }
                root.wifiScanning = false;
            }
        }

    }

}
