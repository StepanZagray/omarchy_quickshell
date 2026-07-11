import QtQuick
import QtQuick.Layouts

Rectangle {
    required property var root

    Layout.alignment: Qt.AlignVCenter
    Layout.preferredWidth: 1
    Layout.preferredHeight: 16
    Layout.leftMargin: 2
    Layout.rightMargin: 2
    color: root.sep
}
