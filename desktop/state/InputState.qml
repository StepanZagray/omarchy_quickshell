import QtQuick
import Quickshell.Io

Item {
    id: root

    required property var shell

    property string layoutLabel: ""
    property string layoutKeymap: ""
    property var layoutCodes: []
    property int layoutCount: 0
    property string keyboardName: ""

    readonly property string layoutTooltip: {
        let s = root.layoutKeymap || root.layoutLabel || "Keyboard layout";
        if (root.layoutCount > 1)
            s += " · Alt+Shift to switch";
        return s;
    }

    function cycleLayout() {
        if (!root.keyboardName.length || root.layoutCount < 2)
            return;

        shell.run("hyprctl switchxkblayout " + JSON.stringify(root.keyboardName) + " next");
    }

    function _prettyLayout(keymap, layoutCodes, index) {
        const codes = (layoutCodes || "").split(",").filter(function (c) { return c.length > 0; });
        if (index >= 0 && index < codes.length)
            return codes[index].toUpperCase();

        const km = (keymap || "").toLowerCase();
        if (km.indexOf("ukrain") >= 0)
            return "UA";
        if (km.indexOf("english") >= 0 || km.indexOf("(us)") >= 0)
            return "US";
        if (keymap && keymap.length > 0)
            return keymap.replace(/.*\(([^)]+)\).*/, "$1").trim().toUpperCase();

        return "??";
    }

    function _applyLayout(keymap, layouts, index, keyboard) {
        const codes = (layouts || "").split(",").filter(function (c) { return c.length > 0; });
        root.layoutKeymap = keymap || "";
        root.layoutCodes = codes;
        root.layoutCount = codes.length;
        root.layoutLabel = root._prettyLayout(keymap, layouts, index);
        if (keyboard && keyboard.length)
            root.keyboardName = keyboard;
    }

    Process {
        id: hyprEventProbe

        running: true
        command: ["python3", "-u", "-c", "import os,socket,sys\n" + "p=os.environ['XDG_RUNTIME_DIR']+'/hypr/'+os.environ['HYPRLAND_INSTANCE_SIGNATURE']+'/.socket2.sock'\n" + "s=socket.socket(socket.AF_UNIX); s.connect(p)\n" + "f=s.makefile('r')\n" + "for ln in f:\n" + "    if ln.startswith('activelayout>>'):\n" + "        sys.stdout.write('layout\\n'); sys.stdout.flush()"]

        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() !== "layout")
                    return;

                layoutProbe.running = false;
                layoutProbe.running = true;
            }
        }

        onRunningChanged: if (!running)
            hyprEventRevive.restart()
    }

    Timer {
        id: hyprEventRevive

        interval: 3000
        onTriggered: {
            hyprEventProbe.running = false;
            hyprEventProbe.running = true;
        }
    }

    Process {
        id: layoutProbe

        running: false
        command: ["bash", "-lc", "hyprctl devices -j 2>/dev/null | jq -r '.keyboards[] | select(.main==true) | [.name,.active_keymap,.layout,.active_layout_index] | @tsv'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split("\t");
                if (p.length < 4)
                    return;

                root._applyLayout(p[1], p[2], parseInt(p[3]), p[0]);
            }
        }
    }

    Component.onCompleted: layoutProbe.running = true
}
