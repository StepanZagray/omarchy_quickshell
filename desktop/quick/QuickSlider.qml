import QtQuick
import "../fx"

// Slim horizontal slider used by the QuickMenu detail panels. Click
// anywhere on the track to jump; drag the handle for fine adjustment.
// The `set` signal fires both on drag-move and on track click so the
// owning code can stream changes (volume, brightness) live.
Item {
    id: slider
    required property var root

    property real value: 0
    property real min: 0
    property real max: 100
    property string label: ""

    signal committed(real v)

    implicitHeight: 26

    function _clamp(v) { return Math.max(slider.min, Math.min(slider.max, v)); }
    function _setFromX(x) {
        const w = track.width;
        if (w <= 0) return;
        const ratio = Math.max(0, Math.min(1, x / w));
        const v = slider._clamp(slider.min + ratio * (slider.max - slider.min));
        slider.committed(v);
    }

    SquircleRect {
        id: track
        anchors.left: parent.left
        anchors.right: labelText.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        root: slider.root
        radius: 3
        color: Qt.rgba(slider.root.ink.r, slider.root.ink.g, slider.root.ink.b, 0.12)

        SquircleRect {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1,
                (slider.value - slider.min) / Math.max(0.0001, slider.max - slider.min)))
            root: slider.root
            radius: 3
            color: slider.root.seal
        }

        SquircleRect {
            id: handle
            width: 14; height: 14
            root: slider.root
            radius: 7
            color: slider.root.bg
            borderColor: slider.root.seal
            borderWidth: 2
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width * Math.max(0, Math.min(1,
                (slider.value - slider.min) / Math.max(0.0001, slider.max - slider.min)))
               - width / 2
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onPressed: (e) => slider._setFromX(e.x + 6)
            onPositionChanged: (e) => { if (pressed) slider._setFromX(e.x + 6); }
        }
    }

    Text {
        id: labelText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: slider.label
        color: slider.root.inkDeep
        font.family: slider.root.mono
        font.pixelSize: 10
        font.letterSpacing: 1.5
        font.weight: Font.Medium
    }
}
