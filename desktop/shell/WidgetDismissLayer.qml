import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: dismissLayer

    required property var root
    property string shellScreenName: ""
    readonly property string activeScreen: root.popupAnchorScreen || root.focusedScreenName()
    readonly property bool widgetOpen: root.calendarVisible || root.mediaVisible || root.powerMenuVisible

    visible: false
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: clickRegion
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-widget-dismiss"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Region {
        id: clickRegion

        x: 0
        y: 0
        width: dismissLayer.width
        height: dismissLayer.height
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.001)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            preventStealing: true
            onPressed: {
                dismissLayer.root.calendarVisible = false;
                dismissLayer.root.mediaVisible = false;
                dismissLayer.root.powerMenuVisible = false;
                mouse.accepted = true;
            }
        }

    }

}
