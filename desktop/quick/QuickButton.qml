import QtQuick

// Mono-caps action button used throughout the Quick detail panels.
// Compact, optional left glyph + label, click signal.
// Hover and `selected` share the same seal-accented look.
Item {
    id: btn

    required property var root
    property string label: ""
    property string glyph: ""
    property bool selected: false
    // Bumps the horizontal padding for tighter button rows.
    property int padH: 14
    readonly property bool lit: btn.selected || (mouse.containsMouse && btn.enabled)

    signal clicked()
    signal hovered()

    implicitWidth: content.implicitWidth + padH * 2
    implicitHeight: 32
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: btn.root.cornerRadius
        color: btn.lit
               ? Qt.rgba(btn.root.seal.r, btn.root.seal.g, btn.root.seal.b, 0.2)
               : Qt.rgba(btn.root.ink.r, btn.root.ink.g, btn.root.ink.b, 0.03)
        border.color: btn.lit ? btn.root.seal : btn.root.sep
        border.width: btn.lit ? 2 : 1

        Behavior on color {
            ColorAnimation {
                duration: btn.root.animationDuration
                easing.type: Easing.InOutCubic
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: btn.root.animationDuration
                easing.type: Easing.InOutCubic
            }
        }

        Behavior on border.width {
            NumberAnimation {
                duration: btn.root.animationDuration
                easing.type: Easing.InOutCubic
            }
        }
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 8

        Text {
            visible: btn.glyph.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: btn.glyph
            color: btn.lit ? btn.root.seal : btn.root.ink
            font.family: btn.root.mono
            font.pixelSize: 14
        }

        Text {
            visible: btn.label.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: btn.label
            color: btn.lit ? btn.root.seal : btn.root.ink
            font.family: btn.root.mono
            font.pixelSize: 12
            font.letterSpacing: 1.5
            font.weight: Font.Medium
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: btn.clicked()
        onContainsMouseChanged: {
            if (containsMouse && btn.enabled)
                btn.hovered();
        }
    }
}
