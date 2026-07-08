import QtQuick
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    property int activeWs: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : root._lastActiveWs
    property var existingWs: []
    property int lastDirection: 0
    property int _lastActiveWs: 1

    onActiveWsChanged: {
        if (root.activeWs > root._lastActiveWs)
            root.lastDirection = 1;
        else if (root.activeWs < root._lastActiveWs)
            root.lastDirection = -1;
        root._lastActiveWs = root.activeWs;
    }

    Process {
        id: wsProbe

        running: false
        command: ["bash", "-lc", "hyprctl workspaces -j 2>/dev/null | tr ',' '\\n' | sed -n 's/.*\"id\": *\\([0-9]*\\).*/\\1/p' | sort -nu | paste -sd,"]

        stdout: StdioCollector {
            onStreamFinished: {
                const have = this.text.split(",").map((s) => {
                    return parseInt(s);
                }).filter((n) => {
                    return !isNaN(n);
                });
                root.existingWs = have.sort((a, b) => {
                    return a - b;
                }).slice(0, 9);
            }
        }

    }

    Timer {
        interval: 500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            wsProbe.running = false;
            wsProbe.running = true;
        }
    }

}
