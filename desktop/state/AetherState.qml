import QtQuick
import Quickshell.Io

Item {
    id: root

    required property var shell
    property bool aetherVisible: false
    property var aetherBlueprints: []
    property int selectedAether: -1
    property bool aetherLoading: false
    property string aetherQuery: ""
    readonly property var aetherFiltered: {
        const q = root.aetherQuery.toLowerCase();
        if (q === "")
            return root.aetherBlueprints;

        return root.aetherBlueprints.filter((b) => {
            return String(b.name || "").toLowerCase().indexOf(q) !== -1;
        });
    }

    function openAether() {
        root.aetherQuery = "";
        root.selectedAether = 0;
        root.refreshAetherBlueprints();
        root.aetherVisible = true;
    }

    function refreshAetherBlueprints() {
        root.aetherLoading = true;
        aetherProbe.running = false;
        aetherProbe.running = true;
    }

    function moveAetherSelection(delta, wrap) {
        const n = root.aetherFiltered.length;
        if (n === 0) {
            root.selectedAether = -1;
            return;
        }
        const cur = root.selectedAether < 0 ? 0 : root.selectedAether;
        let next = cur + delta;
        if (wrap) {
            next = ((next % n) + n) % n;
        } else {
            if (next < 0)
                next = 0;
            else if (next >= n)
                next = n - 1;
        }
        root.selectedAether = next;
    }

    function applyAetherBlueprint(name) {
        if (!name)
            return;

        shell.run("aether --apply-blueprint " + JSON.stringify(name));
        root.aetherVisible = false;
    }

    onAetherQueryChanged: {
        root.selectedAether = root.aetherFiltered.length > 0 ? 0 : -1;
    }

    Process {
        id: aetherProbe

        running: false
        command: ["aether", "--list-blueprints", "--json"]

        stdout: StdioCollector {
            onStreamFinished: {
                let arr = [];
                try {
                    const obj = JSON.parse(this.text);
                    arr = (obj.blueprints || []).slice();
                } catch (_) {
                    arr = [];
                }
                arr.sort((a, b) => {
                    return (Number(b.timestamp) || 0) - (Number(a.timestamp) || 0);
                });
                root.aetherBlueprints = arr;
                root.aetherLoading = false;
                root.selectedAether = arr.length > 0 ? 0 : -1;
            }
        }

    }

}
