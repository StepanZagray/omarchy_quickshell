import QtQuick
import Quickshell
import Quickshell.Wayland

// Click-through visual shell: unified frame + widget glass in FrameBorder.
PanelWindow {
    id: shellVisual

    required property var root
    property string shellScreenName: ""

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "omarchy-shell-visual"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    FrameBorder {
        root: shellVisual.root
        screen: shellVisual.screen
        shellScreenName: shellVisual.shellScreenName
    }

    mask: Region {
    }

}
