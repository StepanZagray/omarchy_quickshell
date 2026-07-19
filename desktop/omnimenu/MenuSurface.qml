import QtQuick
import Quickshell
import Quickshell.Wayland
import "components" as Components

// Owns the two layer-shell surfaces, card layout, and keyboard routing.
// All behaviour is delegated through the public OmniMenu state object.
Item {
    id: view

    required property var omni
    required property var processes
    required property var themes
    required property var bookmarks
    required property var ollamaChat

    KeyRouter {
        id: keyRouter
        omni: view.omni
        quickContainer: quickContainer
        resultList: resultListInstance
        previewPane: previewPaneInstance
        bookmarks: view.bookmarks
    }

    function positionResultAtIndex(index, mode) {
        resultListInstance.list.positionViewAtIndex(index, mode);
    }

    // ---------- Panel ----------
    // Card-sized glass layer. Keeping the blur surface separate from the
    // fullscreen input layer prevents Hyprland from processing transparent
    // pixels across the whole monitor.
    PanelWindow {
        id: paletteGlass
        visible: view.omni.visible_
        color: "transparent"
        implicitWidth: card.width
        implicitHeight: card.height
        anchors { top: true }
        margins.top: screen ? screen.height * 0.18 : 0
        exclusionMode: ExclusionMode.Ignore
        // The visual glass sits on Top while the fullscreen keyboard/input
        // layer remains Overlay, keeping all Omni content above this background.
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "omni-menu-blur"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        Rectangle {
            anchors.fill: parent
            color: view.omni.bg
            radius: view.omni.cornerRadius
        }
    }

    PanelWindow {
        id: panel
        visible: view.omni.visible_ || reveal > 0.001
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "omni-menu-input"
        WlrLayershell.keyboardFocus: view.omni.visible_ ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        property real reveal: view.omni.visible_ ? 1 : 0
        // Open and close are both instant: SUPER+SPACE paints the palette on
        // the very next frame, and dismissal drops it the same frame with no
        // fade or scale-out lag.

        // The full-screen layer stays visually transparent; the card-sized
        // paletteGlass surface supplies compositor blur independently.
        // A near-zero alpha fill makes Qt clear every buffer pixel instead of
        // leaving untouched regions black on some scaled multi-monitor setups.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.001)
        }

        // Outside-click dismiss.
        MouseArea {
            anchors.fill: parent
            onClicked: view.omni.close()
        }

        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            // Card sits slightly above visual centre so the result list grows
            // downward without dragging the search field out of the eyeline.
            y: parent.height * 0.18
            // Wide in any preview-bearing mode (file, github, processes,
            // themes) so a ~520px preview pane fits next to the result
            // list; narrow 640 elsewhere — including Quick mode whether
            // collapsed or expanded — so opening a tile doesn't cause any
            // horizontal jump. The tile column compresses to 64px on the
            // left of the same 640 card, leaving ~509px for the detail
            // panel.
            width: view.omni.previewActive ? 1000 : 640
            Behavior on width {
                NumberAnimation { duration: view.omni.animationDuration; easing.type: Easing.InOutCubic }
            }
            // Cap the card so it never exceeds the screen even on small
            // displays; cardCol implicitHeight covers the search + list +
            // footer block.
            height: Math.min(cardCol.implicitHeight + 34, parent.height * 0.72)
            color: "transparent"
            border.color: view.omni.sep
            border.width: 1
            radius: view.omni.cornerRadius
            transformOrigin: Item.Center
            scale: panel.reveal

            // Swallow clicks so the underlying dismiss MouseArea doesn't fire.
            MouseArea { anchors.fill: parent }

            focus: view.omni.visible_
            Keys.onPressed: keyRouter.handle(event)

            Column {
                id: cardCol
                anchors.fill: parent
                anchors.margins: 17
                spacing: 12

                Components.HeaderBar {
                    id: headerBar
                    omni: view.omni
                    processes: view.processes
                    themes: view.themes
                    bookmarks: view.bookmarks
                }

                Rectangle { width: parent.width; height: 1; color: view.omni.sep }

                Components.QuickContainer {
                    id: quickContainer
                    omni: view.omni
                    panel: panel
                }

                Components.SearchInput { omni: view.omni }

                Rectangle {
                    visible: !view.omni.quickMode
                    width: parent.width
                    height: 1
                    color: view.omni.sep
                }

                // Fixed row height in the delegate keeps positionViewAtIndex
                // honest under fast keyboard navigation; the wrapping Item's
                // clip prevents the bottom row bleeding into the footer
                // hairline mid-scroll.
                Item {
                    id: listArea
                    visible: !view.omni.quickMode
                    width: parent.width
                    height: visible
                        ? Math.max(60, card.height - 34 - headerBar.height - 34 - 12 * 4)
                        : 0
                    clip: true

                    // In file mode the list shrinks to ~44% of the card so
                    // a 520px-ish preview pane fits alongside it. The 1px
                    // hairline + 1px inverse hairline divider sits between
                    // them. animated alongside card.width for a single
                    // smooth widen-and-split motion.
                    readonly property real listFraction: view.omni.previewActive ? 0.44 : 1.0

                    Components.ResultList {
                        id: resultListInstance
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        // Follows card.width's Behavior animation — adding a
                        // second Behavior here would animate to a moving
                        // target and produce staggered motion.
                        width: parent.width * listArea.listFraction
                        omni: view.omni
                        bookmarks: view.bookmarks
                        processes: view.processes
                        themes: view.themes
                        ollamaChat: view.ollamaChat
                    }

                    Rectangle {
                        visible: view.omni.previewActive
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: resultListInstance.right
                        width: 1
                        color: view.omni.sep
                    }

                    Components.PreviewPane {
                        id: previewPaneInstance
                        visible: view.omni.previewActive
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: resultListInstance.right
                        anchors.leftMargin: 13
                        anchors.right: parent.right
                        omni: view.omni
                        ollamaChat: view.ollamaChat
                    }
                }

            }
        }
    }
}
