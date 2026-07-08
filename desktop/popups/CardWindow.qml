// Tier-B popup shell. Full-screen overlay PanelWindow + positioned surface,
// click-outside dismiss, Esc dismiss. Widgets own all visible content.

import QtQuick
import Quickshell
import Quickshell.Wayland

// Usage:
//   CardWindow {
//       theme: root
//       revealed: root.aetherVisible
//       onDismiss: root.aetherVisible = false
//       onKeyPressed: function(event) { ... widget keys ... }
//       Item { ... body ... }
//   }
PanelWindow {
    id: card

    required property var theme
    property bool revealed: false
    property real cardWidth: 460
    // -1 -> auto-size from content implicit height; otherwise fixed.
    property real cardHeight: -1
    readonly property int animationDuration: card.theme && card.theme.frameAnimationDuration !== undefined ? card.theme.frameAnimationDuration : 320
    property int animationEasing: Easing.InOutCubic
    property real contentTravel: 10
    property real contentOpenDelayFactor: 0
    property real contentOpenDurationFactor: 1
    property real contentCloseDurationFactor: 1
    property string layerNamespace: "omarchy-card"
    // Body inset inside the card surface. Override per popup, e.g.
    // bodyPaddingTop: 4 for a tighter top edge on frame-attached widgets.
    property int bodyPaddingTop: 8
    property int bodyPaddingBottom: 8
    property int bodyPaddingLeft: 16
    property int bodyPaddingRight: 16
    property int bodySpacing: 12
    readonly property int bodyPaddingVertical: bodyPaddingTop + bodyPaddingBottom
    property bool frameAttached: false
    property bool frameAttachRight: false
    property string frameScreenName: ""
    // Anchored placement. "top" (default) places widgets below the taskbar;
    // "" centres the card; "bottom"/"left"/"right" hug the bar's inner edge
    // and centre on (anchorBarX, anchorBarY) along the parallel axis,
    // clamped on-screen. The Scale origin tracks the trigger so a clamped
    // card still feels rooted in the icon the user clicked.
    property string anchorEdge: "top"
    property real anchorBarX: 0
    property real anchorBarY: 0
    property real anchorGap: 8
    readonly property real frameInset: 0
    readonly property real frameTopInset: frameAttached ? -1 : 0
    readonly property real frameRightInset: frameAttached && frameAttachRight ? 2 : 0
    readonly property real joinRadius: frameAttached ? theme.frameRounding * 1.5 : 0
    readonly property color surfaceColor: frameAttached ? theme.frameBg : theme.bg
    readonly property real contentReveal: _contentReveal
    readonly property bool _anchored: anchorEdge === "top" || anchorEdge === "bottom" || anchorEdge === "left" || anchorEdge === "right"
    // PanelWindow can report 0×0 for a frame before the screen geometry lands.
    // Never paint (or publish frame chrome) until placement inputs are real.
    readonly property bool _layoutReady: width > 0 && height > 0 && surface.width > 0 && surface.height > 0
    default property alias bodyData: bodyContainer.data
    property real _reveal: 0
    property real _contentReveal: 0
    property bool _closing: false

    signal dismiss()
    signal keyPressed(var event)

    function animateReveal(toValue) {
        revealAnim.stop();
        revealAnim.from = card._reveal;
        revealAnim.to = toValue;
        revealAnim.easing.type = card.animationEasing;
        revealAnim.start();
    }

    function animateContentReveal(toValue, durationFactor) {
        contentOpenDelay.stop();
        contentRevealAnim.stop();
        contentRevealAnim.from = card._contentReveal;
        contentRevealAnim.to = toValue;
        contentRevealAnim.duration = Math.max(0, card.animationDuration * durationFactor);
        contentRevealAnim.easing.type = card.animationEasing;
        contentRevealAnim.start();
    }

    function animateContentOpen() {
        contentOpenDelay.stop();
        contentRevealAnim.stop();
        const delayMs = Math.max(0, card.animationDuration * card.contentOpenDelayFactor);
        if (delayMs <= 0) {
            card.animateContentReveal(1, card.contentOpenDurationFactor);
            return ;
        }
        contentOpenDelay.interval = delayMs;
        contentOpenDelay.restart();
    }

    function publishFrameSurface() {
        if (!card.frameAttached || !card.theme || card.theme.frameWidgetVisible === undefined)
            return ;

        // Shell geometry + visibility follow `revealed`, not content `_reveal`,
        // so FrameBorder can morph the desktop frame independently.
        if (card._layoutReady && card.revealed) {
            card.theme.frameWidgetOwner = card.layerNamespace;
            card.theme.frameWidgetVisible = true;
            card.theme.frameWidgetX = surface.x;
            card.theme.frameWidgetY = surface.y;
            card.theme.frameWidgetWidth = surface.width;
            card.theme.frameWidgetHeight = surface.height;
            card.theme.frameWidgetAttachRight = card.frameAttachRight;
            card.theme.frameWidgetScreen = card.frameScreenName.length > 0 ? card.frameScreenName : (card.screen ? card.screen.name : card.theme.frameWidgetScreen);
        } else if (!card.revealed && card.theme.frameWidgetOwner === card.layerNamespace) {
            card.theme.frameWidgetVisible = false;
        }
    }

    visible: revealed || _closing || _reveal > 0.001 || revealAnim.running
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: ((revealed || _closing || revealAnim.running) && _layoutReady) ? null : emptyRegion
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: layerNamespace
    WlrLayershell.keyboardFocus: (revealed && _layoutReady) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onRevealedChanged: {
        if (!card.revealed) {
            card._closing = true;
            closeHoldTimer.restart();
            card.animateReveal(0);
            card.animateContentReveal(0, card.contentCloseDurationFactor);
        } else {
            closeHoldTimer.stop();
            card._closing = false;
            if (card._layoutReady) {
                card.animateReveal(1);
                card.animateContentOpen();
            }
        }
        card.publishFrameSurface();
    }
    on_LayoutReadyChanged: {
        if (!card.revealed || !card._layoutReady)
            return ;

        if (card._reveal < 0.001)
            card.animateReveal(1);

        if (card._contentReveal < 0.001)
            card.animateContentOpen();

        card.publishFrameSurface();
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Region {
        id: emptyRegion
    }

    MouseArea {
        anchors.fill: parent
        enabled: card.revealed && card._layoutReady
        onClicked: card.dismiss()
    }

    Item {
        id: surface

        width: card.cardWidth
        height: card.cardHeight > 0 ? card.cardHeight : (bodyCol.implicitHeight + card.bodyPaddingVertical)
        onXChanged: card.publishFrameSurface()
        onYChanged: card.publishFrameSurface()
        onWidthChanged: card.publishFrameSurface()
        onHeightChanged: card.publishFrameSurface()
        x: {
            if (!card._anchored)
                return (parent.width - width) / 2;

            if (card.frameAttached && card.frameAttachRight)
                return parent.width - width - card.theme.frameThickness - card.frameRightInset;

            if (card.anchorEdge === "left")
                return card.theme.barHeight + card.anchorGap;

            if (card.anchorEdge === "right")
                return parent.width - card.theme.barHeight - width - card.anchorGap;

            const xAnchor = card.anchorBarX > 0 ? card.anchorBarX : parent.width / 2;
            return Math.max(card.anchorGap, Math.min(parent.width - width - card.anchorGap, xAnchor - width / 2));
        }
        y: {
            if (!card._anchored)
                return (parent.height - height) / 2;

            const gap = card.frameAttached ? card.frameTopInset : card.anchorGap;
            if (card.anchorEdge === "top")
                return card.theme.barHeight + gap;

            if (card.anchorEdge === "bottom")
                return parent.height - card.theme.barHeight - height - gap;

            const yAnchor = card.anchorBarY > 0 ? card.anchorBarY : parent.height / 2;
            return Math.max(gap, Math.min(parent.height - height - gap, yAnchor - height / 2));
        }
        opacity: 1
        focus: card.revealed && card._layoutReady
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                card.dismiss();
                event.accepted = true;
                return ;
            }
            card.keyPressed(event);
        }

        Rectangle {
            visible: !card.frameAttached
            anchors.fill: parent
            color: card.surfaceColor
            border.color: card.theme.sep
            border.width: 1
            radius: card.theme.cornerRadius
        }

        // Swallow clicks so the dismiss MouseArea doesn't fire on body taps.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: bodyCol

            anchors.fill: parent
            anchors.leftMargin: card.bodyPaddingLeft + card.joinRadius
            anchors.rightMargin: card.bodyPaddingRight + card.joinRadius
            anchors.topMargin: card.bodyPaddingTop
            anchors.bottomMargin: card.bodyPaddingBottom
            spacing: card.bodySpacing

            Item {
                id: bodyContainer

                width: parent.width
                height: childrenRect.height
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: card.revealed ? 160 : 90
                easing.type: card.animationEasing
            }

        }

        transform: Scale {
            origin.x: {
                if (!card._anchored)
                    return surface.width / 2;

                if (card.frameAttached && card.frameAttachRight)
                    return surface.width;

                if (card.anchorEdge === "left")
                    return 0;

                if (card.anchorEdge === "right")
                    return surface.width;

                const xAnchor = card.anchorBarX > 0 ? card.anchorBarX : card.width / 2;
                return Math.max(0, Math.min(surface.width, xAnchor - surface.x));
            }
            origin.y: {
                if (!card._anchored)
                    return surface.height / 2;

                if (card.anchorEdge === "top")
                    return 0;

                if (card.anchorEdge === "bottom")
                    return surface.height;

                const yAnchor = card.anchorBarY > 0 ? card.anchorBarY : card.height / 2;
                return Math.max(0, Math.min(surface.height, yAnchor - surface.y));
            }
            xScale: card._layoutReady ? (card.frameAttached ? 1 : card._reveal) : 0
            yScale: card._layoutReady ? (card.frameAttached ? 1 : card._reveal) : 0
        }

    }

    NumberAnimation {
        id: revealAnim

        target: card
        property: "_reveal"
        duration: card.animationDuration
    }

    NumberAnimation {
        id: contentRevealAnim

        target: card
        property: "_contentReveal"
        duration: card.animationDuration
    }

    Timer {
        id: contentOpenDelay

        repeat: false
        onTriggered: card.animateContentReveal(1, card.contentOpenDurationFactor)
    }

    Timer {
        id: closeHoldTimer

        interval: card.animationDuration + 40
        repeat: false
        onTriggered: card._closing = false
    }

}
