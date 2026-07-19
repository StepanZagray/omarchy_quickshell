import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Compact notification card using the same glass, hairline, mono-caps, seal
// accent, and motion language as the rest of the desktop shell.
Item {
    id: card

    required property var root
    required property var notification

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property color accent: critical ? root.seal : root.ink
    readonly property string iconSource: notification.image.length > 0
                                               ? notification.image
                                               : (notification.appIcon.length > 0
                                                  ? Quickshell.iconPath(notification.appIcon, "")
                                                  : "")
    property real reveal: 0

    width: parent ? parent.width : 0
    height: surface.height
    opacity: reveal
    transform: Translate { x: (1 - card.reveal) * 18 }

    function expiryInterval() {
        if (card.critical || notification.expireTimeout === 0)
            return 0;
        if (notification.expireTimeout < 0)
            return notification.urgency === NotificationUrgency.Low ? 3500 : 5000;
        // The freedesktop notification protocol supplies this value in ms.
        return Math.max(1000, notification.expireTimeout);
    }

    function restartExpiry() {
        expireTimer.stop();
        expireTimer.interval = card.expiryInterval();
        if (expireTimer.interval > 0 && !cardMouse.containsMouse)
            expireTimer.restart();
    }

    Component.onCompleted: {
        revealAnimation.start();
        restartExpiry();
    }

    NumberAnimation {
        id: revealAnimation
        target: card
        property: "reveal"
        from: 0
        to: 1
        duration: card.root.animationDuration
        easing.type: Easing.InOutCubic
    }

    Timer {
        id: expireTimer
        repeat: false
        onTriggered: card.notification.expire()
    }

    Connections {
        target: card.notification
        function onExpireTimeoutChanged() { card.restartExpiry(); }
        function onSummaryChanged() { card.restartExpiry(); }
        function onBodyChanged() { card.restartExpiry(); }
    }

    Rectangle {
        id: surface

        width: parent.width
        height: content.implicitHeight + 24
        color: card.root.bg
        border.color: card.critical ? card.root.seal : card.root.sep
        border.width: card.critical ? 2 : 1
        radius: card.root.cornerRadius

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: card.notification.actions.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: card.root.invokeNotification(card.notification)
            onContainsMouseChanged: {
                if (containsMouse)
                    expireTimer.stop();
                else
                    card.restartExpiry();
            }
        }

        Row {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 12

            Item {
                width: 42
                height: 42
                anchors.top: parent.top

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.10)
                    border.color: card.critical ? card.root.seal : card.root.sep
                    border.width: 1
                    radius: card.root.cornerRadius
                }

                Image {
                    visible: card.iconSource.length > 0
                    anchors.fill: parent
                    anchors.margins: 6
                    source: card.iconSource
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                Text {
                    visible: card.iconSource.length === 0
                    anchors.centerIn: parent
                    text: card.critical ? "󰀪" : "󰂚"
                    color: card.accent
                    font.family: card.root.mono
                    font.pixelSize: 17
                }
            }

            Column {
                width: parent.width - 54
                spacing: 5

                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        width: parent.width - closeButton.width - 8
                        text: (card.notification.appName || "NOTIFICATION").toUpperCase()
                        color: card.root.inkDeep
                        font.family: card.root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Item {
                        id: closeButton
                        width: 18
                        height: 18

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: closeMouse.containsMouse ? card.root.seal : card.root.inkDeep
                            font.family: card.root.mono
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.notification.dismiss()
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: card.notification.summary
                    color: card.root.ink
                    font.family: card.root.mono
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: card.notification.body
                    textFormat: Text.StyledText
                    color: card.root.inkDeep
                    font.family: card.root.mono
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                Rectangle {
                    readonly property real progressValue: Number(card.notification.hints["value"])
                    visible: !isNaN(progressValue) && progressValue >= 0 && progressValue <= 100
                    width: parent.width
                    height: visible ? 3 : 0
                    color: Qt.rgba(card.root.ink.r, card.root.ink.g, card.root.ink.b, 0.14)

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, parent.progressValue / 100))
                        height: parent.height
                        color: card.accent
                    }
                }

                Flow {
                    width: parent.width
                    height: childrenRect.height
                    spacing: 6

                    Repeater {
                        model: card.notification.actions

                        delegate: Item {
                            id: actionButton
                            required property var modelData
                            readonly property bool displayAction: modelData.identifier !== "default"
                            visible: displayAction
                            width: displayAction ? actionLabel.implicitWidth + 18 : 0
                            height: displayAction ? 26 : 0

                            Rectangle {
                                anchors.fill: parent
                                color: actionMouse.containsMouse
                                       ? Qt.rgba(card.root.ink.r, card.root.ink.g, card.root.ink.b, 0.10)
                                       : Qt.rgba(card.root.ink.r, card.root.ink.g, card.root.ink.b, 0.03)
                                border.color: actionMouse.containsMouse ? card.accent : card.root.sep
                                border.width: 1
                                radius: card.root.cornerRadius
                            }

                            Text {
                                id: actionLabel
                                anchors.centerIn: parent
                                text: actionButton.modelData.text.toUpperCase()
                                color: card.root.ink
                                font.family: card.root.mono
                                font.pixelSize: 9
                                font.letterSpacing: 1
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: actionButton.modelData.invoke()
                            }
                        }
                    }
                }
            }
        }
    }
}
