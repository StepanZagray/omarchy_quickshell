import QtQuick
import "."

// Drop-in squircle replacement for Rectangle in popup controls. Uses the same
// fourth-power superellipse as SquircleSurface / FrameBorder. Set clipContents
// when children (e.g. album art) must be masked to the squircle silhouette.
// Pass `root` to inherit contentCornerRadius and contentCornerPower from Theme.
Item {
    id: squircle

    default property alias data: contentLayer.data

    property var root: null
    property color color: "transparent"
    // When unset (< 0), inherit contentCornerRadius from `root`.
    property real radius: -1
    readonly property real effectiveRadius: squircle.radius >= 0
                                            ? squircle.radius
                                            : (squircle.root ? squircle.root.contentCornerRadius : 0)
    property real power: squircle.root ? squircle.root.contentCornerPower : 4
    property bool clipContents: false
    property bool antialiasing: true
    property int borderWidth: 0
    property color borderColor: "transparent"

    function refreshClipLayer() {
        if (!contentLayer.layer.enabled)
            return;

        contentLayer.layer.enabled = false;
        contentLayer.layer.enabled = true;
    }

    SquircleSurface {
        id: surface

        anchors.fill: parent
        color: squircle.color
        radius: squircle.effectiveRadius
        power: squircle.power
        borderWidth: squircle.borderWidth
        borderColor: squircle.borderColor
    }

    Item {
        id: contentLayer

        anchors.fill: parent
        layer.enabled: squircle.clipContents && squircle.effectiveRadius > 0.001
        layer.smooth: true
        layer.effect: SquircleClipEffect {
            corner: squircle.effectiveRadius
            cornerPower: squircle.power
        }
    }
}
