import QtQuick
import Quickshell
import Quickshell.Wayland

// Click-through, focused-monitor notification stack. Only the cards enter the
// input region; the rest of this layer never blocks desktop interaction.
PanelWindow {
    id: overlay

    required property var root
    property string shellScreenName: ""
    property bool fallbackScreen: false
    readonly property bool activeScreen: root.focusedMonitorName.length > 0
                                         ? root.focusedMonitorName === shellScreenName
                                         : fallbackScreen

    visible: activeScreen
    color: "transparent"
    implicitWidth: 420
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        right: true
    }

    Column {
        id: stack

        anchors.top: parent.top
        anchors.topMargin: overlay.root.barInset + 12
        anchors.right: parent.right
        anchors.rightMargin: overlay.root.frameThickness + 12
        width: parent.width - overlay.root.frameThickness - 24
        spacing: 8

        Repeater {
            model: overlay.root.notificationModel

            delegate: NotificationCard {
                required property var modelData

                width: stack.width
                root: overlay.root
                notification: modelData
            }
        }
    }

    mask: Region {
        item: stack
    }
}
