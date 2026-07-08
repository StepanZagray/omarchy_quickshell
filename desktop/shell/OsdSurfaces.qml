import QtQuick
import Quickshell
import Quickshell.Wayland

// Per-monitor volume/brightness toasts. Kept separate from DesktopSurfaces
// because OSD is ephemeral system feedback, not a bar-attached widget.
Item {
    id: root

    required property var shell
    required property var osd

    Variants {
        id: osdOverlays

        property var shellRef: root.shell
        property var osdRef: root.osd

        model: Quickshell.screens

        delegate: OsdOverlay {
            required property var modelData

            osd: osdOverlays.osdRef
            theme: osdOverlays.shellRef
            screen: modelData
            shellScreenName: modelData.name
        }
    }
}
