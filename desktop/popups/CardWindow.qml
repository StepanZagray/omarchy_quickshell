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
    // Writable so popups can override for debugging, e.g. animationDuration: 800.
    // Defaults to theme.animationDuration when not set by the caller.
    property int animationDuration: card.theme && card.theme.animationDuration !== undefined
                                    ? card.theme.animationDuration
                                    : (card.theme && card.theme.frameAnimationDuration !== undefined
                                       ? card.theme.frameAnimationDuration : 200)
    property int animationEasing: Easing.InOutCubic
    property real contentTravel: 10
    property real contentOpenDelayFactor: 0
    property real contentOpenDurationFactor: 1
    property real contentCloseDurationFactor: 1
    property real revealScaleFrom: 0 // default = current 0→1 behavior
    property bool revealFades: false // default = opacity stays 1
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
    property bool frameAttachLeft: false
    property bool frameAttachBottom: false
    property string frameScreenName: ""
    // OSD toasts must not steal keyboard focus from the active window.
    property bool exclusiveFocus: true
    // When false, the fullscreen overlay stays click-through (toast-style).
    property bool captureInput: true
    // Anchored placement. anchored=true places widgets below the top bar,
    // centred on anchorBarX; anchored=false centres the card on screen.
    // The Scale origin tracks the trigger so a clamped card still feels
    // rooted in the icon the user clicked.
    property bool anchored: true
    property real anchorBarX: 0
    property real anchorGap: 8
    readonly property real frameInset: 0
    readonly property real frameTopInset: frameAttached && !frameAttachBottom ? -1 : 0
    readonly property real frameRightInset: frameAttached && frameAttachRight ? 2 : 0
    readonly property real frameLeftInset: frameAttached && frameAttachLeft ? 2 : 0
    readonly property real frameBottomInset: frameAttached && frameAttachBottom ? 2 : 0
    // Integer so body margins stay pixel-aligned. Fractional insets put radius:N
    // rects on half-pixels and stair-step their corners (very visible on OSD).
    readonly property int joinRadius: frameAttached ? Math.round(theme.frameRounding * 1.5) : 0
    readonly property color surfaceColor: frameAttached ? theme.frameBg : theme.bg
    readonly property real contentReveal: _contentReveal
    readonly property bool _anchored: anchored
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
            // Publish geometry before visibility. FrameBorder reacts to
            // frameWidgetVisible synchronously; width/height must already
            // be set or the first open after reload skips the frame morph.
            card.theme.frameWidgetOwner = card.layerNamespace;
            card.theme.frameWidgetX = surface.x;
            card.theme.frameWidgetY = surface.y;
            card.theme.frameWidgetWidth = surface.width;
            card.theme.frameWidgetHeight = surface.height;
            card.theme.frameWidgetAttachRight = card.frameAttachRight;
            card.theme.frameWidgetAttachLeft = card.frameAttachLeft;
            card.theme.frameWidgetAttachBottom = card.frameAttachBottom;
            card.theme.frameWidgetScreen = card.frameScreenName.length > 0 ? card.frameScreenName : (card.screen ? card.screen.name : card.theme.frameWidgetScreen);
            card.theme.frameWidgetVisible = true;
        } else if (!card.revealed && card.theme.frameWidgetOwner === card.layerNamespace) {
            card.theme.frameWidgetVisible = false;
        }
    }

    visible: revealed || _closing || _reveal > 0.001 || revealAnim.running
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: (captureInput && (revealed || _closing || revealAnim.running) && _layoutReady) ? null : emptyRegion
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: layerNamespace
    WlrLayershell.keyboardFocus: (revealed && _layoutReady && exclusiveFocus) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
        enabled: card.captureInput && card.revealed && card._layoutReady
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
            let px = 0;
            if (!card._anchored)
                px = (parent.width - width) / 2;
            else if (card.frameAttached && card.frameAttachRight)
                px = parent.width - width - card.theme.frameThickness - card.frameRightInset;
            else if (card.frameAttached && card.frameAttachLeft)
                px = card.theme.frameThickness - card.frameLeftInset;
            else {
                const xAnchor = card.anchorBarX > 0 ? card.anchorBarX : parent.width / 2;
                px = Math.max(card.anchorGap, Math.min(parent.width - width - card.anchorGap, xAnchor - width / 2));
            }
            return Math.round(px);
        }
        y: {
            let py = 0;
            if (!card._anchored)
                py = (parent.height - height) / 2;
            else if (card.frameAttached && card.frameAttachBottom)
                py = parent.height - height - card.theme.frameThickness - card.frameBottomInset;
            else {
                const gap = card.frameAttached ? card.frameTopInset : card.anchorGap;
                py = card.theme.barHeight + gap;
            }
            return Math.round(py);
        }
        // Panel chrome fades by baking alpha into the fill/border. Item.opacity
        // on a layer-shell surface is easy to miss (and would also multiply the
        // delayed content fade). Content keeps using contentReveal on its own.
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
            readonly property real fade: card.revealFades ? card._reveal : 1
            color: Qt.rgba(card.surfaceColor.r, card.surfaceColor.g, card.surfaceColor.b,
                           card.surfaceColor.a * fade)
            border.color: Qt.rgba(card.theme.sep.r, card.theme.sep.g, card.theme.sep.b,
                                  card.theme.sep.a * fade)
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

        transform: Scale {
            origin.x: {
                if (!card._anchored)
                    return surface.width / 2;

                if (card.frameAttached && card.frameAttachRight)
                    return surface.width;

                if (card.frameAttached && card.frameAttachLeft)
                    return 0;

                const xAnchor = card.anchorBarX > 0 ? card.anchorBarX : card.width / 2;
                return Math.max(0, Math.min(surface.width, xAnchor - surface.x));
            }
            origin.y: {
                if (!card._anchored)
                    return surface.height / 2;

                if (card.frameAttached && card.frameAttachBottom)
                    return surface.height;

                return 0;
            }
            xScale: card._layoutReady
                    ? (card.frameAttached ? 1
                       : (card.revealScaleFrom + (1 - card.revealScaleFrom) * card._reveal))
                    : card.revealScaleFrom
            yScale: card._layoutReady
                    ? (card.frameAttached ? 1
                       : (card.revealScaleFrom + (1 - card.revealScaleFrom) * card._reveal))
                    : card.revealScaleFrom
        }

    }

    Connections {
        target: card.theme

        function onFrameWidgetVisibleChanged() {
            if (card.revealed && card.frameAttached && !card.theme.frameWidgetVisible)
                card.publishFrameSurface();
        }

        function onFrameWidgetOwnerChanged() {
            if (!card.revealed || !card.frameAttached)
                return;

            if (card.theme.frameWidgetOwner !== card.layerNamespace && !card.theme.frameWidgetVisible)
                card.publishFrameSurface();
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
