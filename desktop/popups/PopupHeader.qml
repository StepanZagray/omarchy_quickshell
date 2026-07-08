import QtQuick

Item {
    id: header

    required property var root
    property string title: ""
    property string subtitle: ""
    property Component rightContent: null

    width: parent ? parent.width : 0
    height: 43

    Column {
        anchors.left: parent.left
        anchors.right: rightLoader.left
        anchors.rightMargin: header.rightContent ? 12 : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            visible: header.title.length > 0
            text: header.title
            color: header.root.ink
            font.family: header.root.mono
            font.pixelSize: 19
            font.letterSpacing: 4
            font.weight: Font.Medium
        }

        Text {
            visible: header.subtitle.length > 0
            width: parent.width
            elide: Text.ElideRight
            text: header.subtitle
            color: header.root.inkDeep
            font.family: header.root.mono
            font.pixelSize: 11
            font.letterSpacing: 2
        }
    }

    Loader {
        id: rightLoader

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: header.rightContent
    }
}
