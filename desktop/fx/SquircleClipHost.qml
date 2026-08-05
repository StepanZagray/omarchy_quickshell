import QtQuick
import "."

// Permanent squircle mask for a popup surface. Transition shaders also clip,
// but they detach once phase reaches 1 — this keeps the silhouette stable.
Item {
    id: host

    default property alias data: inner.data

    property var root: null
    // true = popup/frame shell (frameCornerRadius); false = content controls.
    property bool shell: false
    property real radius: -1
    property real power: host.root ? host.root.contentCornerPower : 4
    readonly property real effectiveRadius: host.radius >= 0
                                            ? host.radius
                                            : (host.root
                                               ? (host.shell
                                                  ? host.root.frameCornerRadius
                                                  : host.root.contentCornerRadius)
                                               : 0)

    Item {
        id: inner

        anchors.fill: parent
        layer.enabled: host.effectiveRadius > 0.001
        layer.smooth: true
        layer.effect: SquircleClipEffect {
            corner: host.effectiveRadius
            cornerPower: host.power
        }
    }
}
