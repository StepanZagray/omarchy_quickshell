import QtQuick
import Quickshell.Io

Item {
    id: root

    required property var shell
    property int cpuVal: 0
    property int memVal: 0
    property bool systemVisible: false
    property bool omarchyUpdateAvailable: false
    property string omarchyLatestTag: ""

    function openSystem() {
        if (shell.systemAnchorItem)
            shell.anchorPopupTo(shell.systemAnchorItem);

        root.refreshSystemStats();
        root.systemVisible = true;
    }

    function refreshSystemStats() {
        if (systemProbe.running)
            return;

        systemProbe.running = false;
        systemProbe.running = true;
    }

    function openOmarchyUpdate() {
        shell.run("omarchy-launch-floating-terminal-with-presentation omarchy-update");
    }

    function refreshOmarchyUpdateCheck() {
        omarchyUpdateProbe.running = false;
        omarchyUpdateProbe.running = true;
    }

    Process {
        id: systemProbe

        running: false
        command: ["bash", "-lc", "read _ a b c d _ < <(grep '^cpu ' /proc/stat); " + "sleep 0.15; " + "read _ e f g h _ < <(grep '^cpu ' /proc/stat); " + "du=$(( (e+f+g) - (a+b+c) )); dt=$(( (e+f+g+h) - (a+b+c+d) )); " + "cpu=$(( dt>0 ? du*100/dt : 0 )); " + "mem=$(awk '/MemTotal/{t=$2}/MemAvailable/{m=$2}END{printf \"%d\",(t-m)*100/t}' /proc/meminfo); " + "printf '%d|%d' \"$cpu\" \"$mem\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.split("|");
                if (p.length === 2) {
                    root.cpuVal = parseInt(p[0]) || 0;
                    root.memVal = parseInt(p[1]) || 0;
                }
            }
        }

    }

    Process {
        id: omarchyUpdateProbe

        running: false
        command: ["omarchy-update-available"]
        onExited: (code, status) => {
            if (code === 0) {
                const m = omarchyUpdateOut.text.match(/\(([^)]+)\)/);
                root.omarchyLatestTag = m ? m[1] : "";
                root.omarchyUpdateAvailable = true;
            } else {
                root.omarchyUpdateAvailable = false;
                root.omarchyLatestTag = "";
            }
        }

        stdout: StdioCollector {
            id: omarchyUpdateOut
        }

    }

    Timer {
        interval: 2.16e+07
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshOmarchyUpdateCheck()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshSystemStats()
    }

}
