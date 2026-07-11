import QtQuick
import QtQuick.Layouts

Item {
    id: wsCell

    required property var root
    property int wsId: 0
    property bool active: false
    property bool present: false

    signal activated()

    Layout.alignment: Qt.AlignVCenter
    Layout.fillHeight: true
    Layout.preferredWidth: tag.implicitWidth + 4
    Layout.preferredHeight: root.barHeight

    Bloom {
        id: bloom

        root: wsCell.root
    }

    Text {
        id: tag

        anchors.centerIn: parent
        text: String(wsCell.wsId).padStart(2, "0")
        color: wsCell.active ? wsCell.root.seal : (wsCell.present ? wsCell.root.ink : Qt.rgba(wsCell.root.ink.r, wsCell.root.ink.g, wsCell.root.ink.b, 0.22))
        opacity: wsCell.active ? 1 : (wsCell.present ? 0.85 : 0.5)
        font.family: wsCell.root.mono
        font.pixelSize: 12
        font.weight: wsCell.active ? Font.Bold : Font.Normal
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        width: tag.implicitWidth
        height: 2
        radius: 1
        color: wsCell.root.seal
        visible: wsCell.active
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: bloom.fire(mouseX, mouseY)
        onClicked: wsCell.activated()
    }

}
