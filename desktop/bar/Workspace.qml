import QtQuick
import QtQuick.Layouts

Item {
    id: wsCell

    required property var root
    property int wsId: 0
    property bool active: false
    property bool present: false

    signal activated()

    visible: root.isHorizontal || active || present
    Layout.alignment: root.isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter
    Layout.preferredWidth: root.isHorizontal ? tag.implicitWidth : root.barHeight
    Layout.preferredHeight: root.isHorizontal ? root.barHeight : tag.implicitHeight

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
        visible: wsCell.active && wsCell.root.isHorizontal
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: root.isHorizontal ? -2 : -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: bloom.fire(mouseX, mouseY)
        onClicked: wsCell.activated()
    }

}
