import QtQuick

Text {
    required property var root

    width: parent ? parent.width : 0
    color: root.inkDeep
    font.family: root.mono
    font.pixelSize: 10
    font.letterSpacing: 2
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    opacity: 0.7
}
