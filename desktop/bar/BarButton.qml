import QtQuick
import QtQuick.Layouts

// Clickable bar cell: icon-only or glyph + label + value + optional gauge.
// Hover wash, bloom, delayed tooltip, left/right click.
Item {
    id: btn

    required property var root
    property string glyph: ""
    property string label: ""
    property string value: ""
    property color color: root.ink
    property color valueColor: color
    property color labelColor: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
    property string fontFamily: root.mono
    property int fontSize: 12
    property real gauge: -1
    property color gaugeColor: valueColor
    property bool blink: false
    property string tooltip: ""
    readonly property bool iconOnly: btn.label.length === 0 && btn.value.length === 0 && btn.gauge < 0
    readonly property int pad: 7

    signal activated()
    signal rightActivated()

    Layout.alignment: Qt.AlignVCenter
    Layout.fillHeight: true
    Layout.preferredHeight: root.barHeight
    Layout.preferredWidth: row.implicitWidth + 2 * btn.pad

    Rectangle {
        anchors.fill: parent
        radius: btn.root.cornerRadius
        color: mouse.containsMouse ? Qt.rgba(btn.root.ink.r, btn.root.ink.g, btn.root.ink.b, 0.08) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 180
                easing.type: Easing.InOutCubic
            }

        }

    }

    Bloom {
        id: bloom

        root: btn.root
    }

    Text {
        visible: btn.iconOnly
        anchors.centerIn: parent
        text: btn.glyph
        color: btn.color
        font.family: btn.fontFamily
        font.pixelSize: btn.fontSize
    }

    Row {
        id: row

        property real pulse: 1

        visible: !btn.iconOnly
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: btn.pad
        anchors.rightMargin: btn.pad
        spacing: 5
        opacity: btn.blink ? pulse : 1

        Text {
            visible: btn.glyph.length > 0
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: btn.glyph
            color: btn.valueColor
            font.family: btn.fontFamily
            font.pixelSize: btn.fontSize
        }

        Text {
            visible: btn.label.length > 0
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: btn.label
            color: btn.labelColor
            font.family: btn.root.mono
            font.pixelSize: 9
            font.letterSpacing: 1
            font.weight: Font.Medium
        }

        Text {
            visible: btn.value.length > 0
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: btn.value
            color: btn.valueColor
            font.family: btn.root.mono
            font.pixelSize: 11
            font.weight: Font.Medium
        }

        Item {
            visible: btn.gauge >= 0
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
                        readonly property bool lit: btn.gauge >= (index + 0.5) * 20

                        width: 3
                        height: 8
                        color: lit ? btn.gaugeColor : Qt.rgba(btn.root.ink.r, btn.root.ink.g, btn.root.ink.b, 0.16)

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                                easing.type: Easing.InOutCubic
                            }

                        }

                    }

                }

            }

        }

    }

    SequentialAnimation {
        running: btn.blink
        loops: Animation.Infinite

        NumberAnimation {
            target: row
            property: "pulse"
            to: 0.25
            duration: 520
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: row
            property: "pulse"
            to: 1
            duration: 520
            easing.type: Easing.InOutCubic
        }

    }

    Timer {
        id: tipDelay

        interval: 320
        onTriggered: {
            if (!btn.tooltip)
                return ;

            const p = btn.mapToItem(null, btn.width / 2, btn.height / 2);
            btn.root.showTooltip(btn.tooltip, p.x, p.y);
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            bloom.fire(mouseX, mouseY);
            if (btn.tooltip)
                tipDelay.restart();

        }
        onExited: {
            tipDelay.stop();
            btn.root.hideTooltip(btn.tooltip);
        }
        onClicked: (e) => {
            tipDelay.stop();
            btn.root.hideTooltip(btn.tooltip);
            if (e.button === Qt.RightButton)
                btn.rightActivated();
            else
                btn.activated();
        }
    }

}
