import QtQuick
import Quickshell
import Quickshell.Wayland

// Tier-B popup chrome. Full-screen overlay PanelWindow + centered card with
// the OmniMenu visual language: mono-caps header (title + status subtitle),
// scale-from-center reveal, click-outside dismiss, Esc dismiss, optional
// footer hint line. Widgets put their own body inside as default children
// and listen to keyPressed() for widget-specific keyboard nav.
//
// Usage:
//   CardWindow {
//       theme: root
//       revealed: root.aetherVisible
//       onDismiss: root.aetherVisible = false
//       onKeyPressed: function(event) { ... widget keys ... }
//       title: "AETHER"
//       subtitle: "12 BLUEPRINTS"
//       footer: "↵ APPLY  ·  ESC CLOSE"
//       Item { ... body ... }
//   }
PanelWindow {
    id: card

    required property var theme

    property bool revealed: false
    property real cardWidth: 460
    // -1 -> auto-size from content implicit height; otherwise fixed.
    property real cardHeight: -1
    property string title: ""
    property string subtitle: ""
    property string footer: ""
    property string layerNamespace: "omarchy-card"
    // Right-side header content (chevrons, refresh buttons, etc.). The
    // inline Component is instantiated as a Loader child; lexical scope
    // means ids declared in the popup file are reachable from inside.
    property Component headerRight: null

    // Anchored placement. When anchorEdge is "" (default), the card centers
    // on screen with a scale-from-center reveal — the original tier-B
    // behaviour. When anchorEdge matches the bar's edge ("top"/"bottom"/
    // "left"/"right"), the card hugs the bar's inner edge and centres on
    // (anchorBarX, anchorBarY) along the parallel axis, clamped to stay
    // on screen. The Scale transform's origin tracks the trigger so the
    // reveal grows out of the bar icon rather than the card's centroid.
    property string anchorEdge: ""
    property real   anchorBarX: 0
    property real   anchorBarY: 0
    property real   anchorBarSize: 0
    property real   anchorGap: 8
    property real   anchorEdgeMargin: 8
    readonly property bool _anchored: anchorEdge === "top"  || anchorEdge === "bottom"
                                   || anchorEdge === "left" || anchorEdge === "right"

    signal dismiss()
    signal keyPressed(var event)

    default property alias bodyData: bodyContainer.data

    visible: revealed || _reveal > 0.001
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: layerNamespace
    WlrLayershell.keyboardFocus: revealed ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real _reveal: revealed ? 1 : 0
    Behavior on _reveal {
        NumberAnimation {
            duration: card.revealed ? 220 : 140
            easing.type: card.revealed ? Easing.OutCubic : Easing.InCubic
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: card.dismiss()
    }

    Rectangle {
        id: surface
        width: card.cardWidth
        height: card.cardHeight > 0 ? card.cardHeight : (bodyCol.implicitHeight + 34)
        color: card.theme.bg
        border.color: card.theme.sep
        border.width: 1
        radius: 0

        // Position. Centered (the default) keeps the original "modal card"
        // feel; anchored placement hugs the bar's inner edge with a small
        // gap and centres on the trigger along the parallel axis (clamped
        // to keep the card on-screen).
        x: {
            if (!card._anchored) return (parent.width - width) / 2;
            if (card.anchorEdge === "left")  return card.anchorBarSize + card.anchorGap;
            if (card.anchorEdge === "right") return parent.width - card.anchorBarSize - width - card.anchorGap;
            return Math.max(card.anchorEdgeMargin,
                            Math.min(parent.width - width - card.anchorEdgeMargin,
                                     card.anchorBarX - width / 2));
        }
        y: {
            if (!card._anchored) return (parent.height - height) / 2;
            if (card.anchorEdge === "top")    return card.anchorBarSize + card.anchorGap;
            if (card.anchorEdge === "bottom") return parent.height - card.anchorBarSize - height - card.anchorGap;
            return Math.max(card.anchorEdgeMargin,
                            Math.min(parent.height - height - card.anchorEdgeMargin,
                                     card.anchorBarY - height / 2));
        }

        // Reveal animation. Centered: scale grows from the geometric
        // centre. Anchored: scale grows out of the bar edge at the
        // trigger's projected position, so even when the card is clamped
        // against a screen edge the visual still feels rooted in the
        // icon the user clicked.
        transform: Scale {
            origin.x: {
                if (!card._anchored) return surface.width / 2;
                if (card.anchorEdge === "left")  return 0;
                if (card.anchorEdge === "right") return surface.width;
                return Math.max(0, Math.min(surface.width, card.anchorBarX - surface.x));
            }
            origin.y: {
                if (!card._anchored) return surface.height / 2;
                if (card.anchorEdge === "top")    return 0;
                if (card.anchorEdge === "bottom") return surface.height;
                return Math.max(0, Math.min(surface.height, card.anchorBarY - surface.y));
            }
            xScale: card._reveal
            yScale: card._reveal
        }

        // Swallow clicks so the dismiss MouseArea doesn't fire on body taps.
        MouseArea { anchors.fill: parent }

        focus: card.revealed
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                card.dismiss();
                event.accepted = true;
                return;
            }
            card.keyPressed(event);
        }

        Column {
            id: bodyCol
            anchors.fill: parent
            anchors.margins: 17
            spacing: 12

            Item {
                width: parent.width
                height: 43
                visible: card.title.length > 0 || card.subtitle.length > 0 || card.headerRight !== null

                Column {
                    anchors.left: parent.left
                    anchors.right: headerRightLoader.left
                    anchors.rightMargin: card.headerRight ? 12 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        visible: card.title.length > 0
                        text: card.title
                        color: card.theme.ink
                        font.family: card.theme.mono
                        font.pixelSize: 19
                        font.letterSpacing: 4
                        font.weight: Font.Medium
                    }
                    Text {
                        visible: card.subtitle.length > 0
                        width: parent.width
                        elide: Text.ElideRight
                        text: card.subtitle
                        color: card.theme.inkDeep
                        font.family: card.theme.mono
                        font.pixelSize: 11
                        font.letterSpacing: 2
                    }
                }

                Loader {
                    id: headerRightLoader
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: card.headerRight
                }
            }

            Rectangle {
                visible: card.title.length > 0 || card.subtitle.length > 0
                width: parent.width
                height: 1
                color: card.theme.sep
            }

            Item {
                id: bodyContainer
                width: parent.width
                height: childrenRect.height
            }

            Rectangle {
                visible: card.footer.length > 0
                width: parent.width
                height: 1
                color: card.theme.sep
                opacity: 0.5
            }

            Text {
                visible: card.footer.length > 0
                width: parent.width
                text: card.footer
                color: card.theme.inkDeep
                font.family: card.theme.mono
                font.pixelSize: 10
                font.letterSpacing: 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.7
            }
        }
    }
}
