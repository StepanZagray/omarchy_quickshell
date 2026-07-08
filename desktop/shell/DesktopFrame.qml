import QtQuick
import Quickshell
import Quickshell.Wayland

// Visual-only frame per monitor. mask: Region {} = clicks pass through to windows.
PanelWindow {
    id: frame
    required property var root

    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: false }
    implicitHeight: frame.screen ? frame.screen.height : 0

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "omarchy-frame"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    FrameBorder {
        root: frame.root
        screen: frame.screen
    }
}
