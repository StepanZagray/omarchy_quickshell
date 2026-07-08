import QtQuick
import QtQuick.Layouts

// Bar telemetry readout: optional glyph, dim label, mono value, and optional
// 5-segment gauge. Glyphs use the theme nerd font; interaction matches
// Module.qml — hover wash, bloom, delayed tooltip, left/right click.
Item {
    id: cell
    required property var root

    property string glyph: ""
    property string label: ""
    property string value: ""
    property color  valueColor: root.ink
    property color  labelColor: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
    property real   gauge: -1                 // < 0 hides the bar; otherwise 0..100
    property color  gaugeColor: valueColor
    property bool   blink: false              // pulses the whole cell (e.g. an alert)
    property string tooltip: ""

    signal activated()
    signal rightActivated()

    readonly property int pad: 5
    readonly property string nerdFont: cell.root.mono

    Layout.alignment: Qt.AlignVCenter
    Layout.preferredHeight: root.barHeight
    Layout.preferredWidth: row.implicitWidth + 2 * cell.pad

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        color: mouse.containsMouse
               ? Qt.rgba(cell.root.ink.r, cell.root.ink.g, cell.root.ink.b, 0.08)
               : "transparent"
        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.InOutCubic } }
    }

    Bloom { id: bloom; root: cell.root }

    Row {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: cell.pad
        anchors.rightMargin: cell.pad
        spacing: 5
        property real pulse: 1.0
        opacity: cell.blink ? pulse : 1.0

        Text {
            visible: cell.glyph.length > 0
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: cell.glyph
            color: cell.valueColor
            font.family: cell.nerdFont
            font.pixelSize: 12
        }
        Text {
            visible: cell.label.length > 0
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: cell.label
            color: cell.labelColor
            font.family: cell.nerdFont
            font.pixelSize: 9
            font.letterSpacing: 1
            font.weight: Font.Medium
        }
        Text {
            visible: cell.value.length > 0
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: cell.value
            color: cell.valueColor
            font.family: cell.nerdFont
            font.pixelSize: 11
            font.weight: Font.Medium
        }
        Item {
            visible: cell.gauge >= 0
            height: parent.height
            width: gaugeRow.width

            Row {
                id: gaugeRow
                anchors.centerIn: parent
                spacing: 1
                Repeater {
                    model: 5
                    delegate: Rectangle {
                        required property int index
                        width: 3
                        height: 8
                        readonly property bool lit: cell.gauge >= (index + 0.5) * 20
                        color: lit ? cell.gaugeColor
                                   : Qt.rgba(cell.root.ink.r, cell.root.ink.g, cell.root.ink.b, 0.16)
                        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.InOutCubic } }
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: blinker
        running: cell.blink
        loops: Animation.Infinite
        NumberAnimation { target: row; property: "pulse"; to: 0.25; duration: 520; easing.type: Easing.InOutCubic }
        NumberAnimation { target: row; property: "pulse"; to: 1.0;  duration: 520; easing.type: Easing.InOutCubic }
    }

    Timer {
        id: tipDelay
        interval: 320
        onTriggered: {
            if (!cell.tooltip) return;
            const p = cell.mapToItem(null, cell.width / 2, cell.height / 2);
            cell.root.showTooltip(cell.tooltip, p.x, p.y);
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: { bloom.fire(mouseX, mouseY); if (cell.tooltip) tipDelay.restart(); }
        onExited:  { tipDelay.stop(); cell.root.hideTooltip(cell.tooltip); }
        onClicked: (e) => {
            tipDelay.stop();
            cell.root.hideTooltip(cell.tooltip);
            if (e.button === Qt.RightButton) cell.rightActivated();
            else cell.activated();
        }
    }
}
