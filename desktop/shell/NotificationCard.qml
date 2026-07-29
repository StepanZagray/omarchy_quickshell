import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../fx"

// Compact notification card using the same glass, hairline, mono-caps, seal
// accent, and motion language as the rest of the desktop shell. Open/close use
// the same BootGlitch + ContentGlitch pair as CardWindow / Aether.
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
    readonly property real contentReveal: contentTransition.progress
    property real contentTravel: 10
    // Keep notification content on CardWindow's top-to-bottom glitch path.
    property vector2d contentGlitchDirection: Qt.vector2d(0, 1)
    property real contentGlitchSplit: contentTransition.splitStrength
    property real glitchOriginX: card.x
    property real glitchOriginY: card.y
    property real closeDurationFactor: 0.6
    property bool _closing: false
    property string _closeReason: "dismiss"

    width: parent ? parent.width : 0
    height: surface.height

    function expiryInterval() {
        if (card.critical || notification.expireTimeout === 0)
            return 0;
        if (notification.expireTimeout < 0)
            return notification.urgency === NotificationUrgency.Low ? 3500 : 5000;
        // The freedesktop notification protocol supplies this value in ms.
        return Math.max(1000, notification.expireTimeout);
    }

    function restartExpiry() {
        if (card._closing)
            return;
        expireTimer.stop();
        expireTimer.interval = card.expiryInterval();
        if (expireTimer.interval > 0 && !cardMouse.containsMouse)
            expireTimer.restart();
    }

    function animateReveal(toValue, durationFactor) {
        revealAnim.stop();
        revealAnim.from = card.reveal;
        revealAnim.to = toValue;
        revealAnim.duration = Math.max(1, card.root.animationDuration * durationFactor);
        revealAnim.easing.type = Easing.InOutCubic;
        revealAnim.start();
    }

    function openEffects() {
        card._closing = false;
        closeHoldTimer.stop();
        card.animateReveal(1, 1);
        contentTransition.open(contentTransition.phase < 0.001, 1);
        bootGlitch.open(card.reveal < 0.001 && contentTransition.phase < 0.001);
    }

    function beginClose(reason) {
        if (card._closing)
            return;
        card._closing = true;
        card._closeReason = reason || "dismiss";
        expireTimer.stop();
        contentTransition.close(card.closeDurationFactor);
        bootGlitch.close();
        card.animateReveal(0, card.closeDurationFactor);
        closeHoldTimer.restart();
    }

    function finishClose() {
        card.root.finalizeNotificationClose(card.notification, card._closeReason);
    }

    Component.onCompleted: {
        card.reveal = 0;
        contentTransition.phase = 0;
        openEffects();
        restartExpiry();
    }

    NumberAnimation {
        id: revealAnim
        target: card
        property: "reveal"
        duration: card.root.animationDuration
    }

    PopupGlitchTransition {
        id: contentTransition

        duration: card.root.animationDuration
        closeDurationFactor: card.closeDurationFactor
        freeStanding: true
    }

    Timer {
        id: expireTimer
        repeat: false
        onTriggered: card.root.requestCloseNotification(card.notification, "expire")
    }

    Timer {
        id: closeHoldTimer
        interval: Math.round(card.root.animationDuration * card.closeDurationFactor) + 40
        repeat: false
        onTriggered: card.finishClose()
    }

    Connections {
        target: card.root
        function onNotificationCloseRequested(notification, reason) {
            if (notification === card.notification)
                card.beginClose(reason);
        }
    }

    Connections {
        target: card.notification
        function onExpireTimeoutChanged() { card.restartExpiry(); }
        function onSummaryChanged() { card.restartExpiry(); }
        function onBodyChanged() { card.restartExpiry(); }
    }

    Item {
        id: surface

        width: parent.width
        height: content.implicitHeight + 24
        readonly property color borderBase: card.critical ? card.root.seal : card.root.sep
        opacity: 1
        scale: 1
        transformOrigin: Item.Center
        layer.enabled: contentTransition.layerRequired
        layer.smooth: false
        layer.effect: ContentGlitch {
            sectionReveal: true
            progress: contentTransition.progress
            quality: contentTransition.quality
            resolutionPixels: contentTransition.resolutionPixels
            seed: contentTransition.seed
            splitStrength: card.contentGlitchSplit
            splitPixels: contentTransition.splitPixels
            visualScale: 1
            corner: card.root.popupCornerRadius
            cornerPower: card.root.popupCornerPower
            accent: card.root.accent
        }

        SquircleSurface {
            anchors.fill: parent
            color: card.root.bg
            borderColor: surface.borderBase
            borderWidth: card.critical ? 2 : 1
            radius: card.root.popupCornerRadius
            power: card.root.popupCornerPower
        }

        // Declared before content so the cells sit underneath the glyphs.
        // Screen-local origin matches CardWindow's stable popup lattice.
        BootGlitch {
            id: bootGlitch

            anchors.fill: parent
            theme: card.root
            corner: card.root.popupCornerRadius
            cornerPower: card.root.popupCornerPower
            visualScale: 1
            resolutionPixels: contentTransition.resolutionPixels
            originX: card.glitchOriginX
            originY: card.glitchOriginY
        }

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            enabled: !card._closing
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

        Item {
            id: contentHost

            anchors.fill: parent

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
                                enabled: !card._closing
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: card.root.requestCloseNotification(card.notification, "dismiss")
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
                                    enabled: !card._closing
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
}
