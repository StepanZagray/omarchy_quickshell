import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Shared power action body used by the Omni quick tile and the standalone
// system menu. It mirrors Omarchy's system menu and deliberately delegates
// session-sensitive work to Omarchy's own commands.
Item {
    id: body

    required property var root
    required property var shell
    property int kbdIndex: 0
    property bool suspendAvailable: true
    property bool hibernateAvailable: false
    // Primary column: Lock → Restart → Shutdown
    readonly property var _primary: [{
        "glyph": "󰌾",
        "label": "LOCK",
        "argv": ["omarchy-system-lock"],
        "available": true
    }, {
        "glyph": "󰜉",
        "label": "RESTART",
        "argv": ["omarchy-system-reboot"],
        "available": true
    }, {
        "glyph": "󰐥",
        "label": "SHUTDOWN",
        "argv": ["omarchy-system-shutdown"],
        "available": true
    }]
    // Secondary 2×2: Screensaver | Logout / Hibernate | Suspend
    // Unavailable actions stay visible but grayed out.
    readonly property var _secondary: [{
        "glyph": "󱄄",
        "label": "SAVER",
        "argv": ["omarchy-launch-screensaver", "force"],
        "available": true
    }, {
        "glyph": "󰗽",
        "label": "LOGOUT",
        "argv": ["omarchy-system-logout"],
        "available": true
    }, {
        "glyph": "󰋊",
        "label": "HIBERNATE",
        "argv": ["systemctl", "hibernate"],
        "available": body.hibernateAvailable
    }, {
        "glyph": "󰤄",
        "label": "SUSPEND",
        "argv": ["systemctl", "suspend"],
        "available": body.suspendAvailable
    }]
    readonly property var _actions: body._primary.concat(body._secondary)

    signal close()

    function refreshAvailability() {
        availabilityProbe.running = false;
        availabilityProbe.running = true;
    }

    function kbdHandle(event) {
        const k = event.key;
        const n = body._actions.length;
        if (k === Qt.Key_Left || k === Qt.Key_Up) {
            body.kbdIndex = (body.kbdIndex - 1 + n) % n;
            return true;
        }
        if (k === Qt.Key_Right || k === Qt.Key_Down || k === Qt.Key_Tab) {
            body.kbdIndex = (body.kbdIndex + 1) % n;
            return true;
        }
        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            body._fire(body._actions[body.kbdIndex]);
            return true;
        }
        return false;
    }

    function _fire(a) {
        if (!a || !a.available)
            return ;

        body.close();
        if (a.argv)
            Quickshell.execDetached(a.argv);

    }

    width: parent ? parent.width : 0
    height: implicitHeight
    implicitHeight: col.implicitHeight
    Component.onCompleted: refreshAvailability()

    Process {
        id: availabilityProbe

        running: false
        command: ["bash", "-lc", "if omarchy-toggle-enabled suspend-off; then s=0; else s=1; fi; " + "if omarchy-hibernation-available; then h=1; else h=0; fi; " + "printf '%s|%s' \"$s\" \"$h\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split("|");
                body.suspendAvailable = parts[0] !== "0";
                body.hibernateAvailable = parts[1] === "1";
                body.kbdIndex = Math.min(body.kbdIndex, body._actions.length - 1);
            }
        }

    }

    Column {
        id: col

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 8
        width: parent.width

        Repeater {
            model: body._primary

            delegate: QuickButton {
                required property var modelData
                required property int index

                root: body.root
                glyph: modelData.glyph
                label: modelData.label
                enabled: modelData.available
                selected: body.kbdIndex === index
                width: parent.width
                height: implicitHeight
                onClicked: body._fire(modelData)
            }

        }

        Grid {
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            width: parent.width

            Repeater {
                model: body._secondary

                delegate: QuickButton {
                    required property var modelData
                    required property int index

                    root: body.root
                    glyph: modelData.glyph
                    label: modelData.label
                    enabled: modelData.available
                    selected: body.kbdIndex === body._primary.length + index
                    width: (parent.width - parent.columnSpacing) / 2
                    height: implicitHeight
                    onClicked: body._fire(modelData)
                }

            }

        }

    }

}
