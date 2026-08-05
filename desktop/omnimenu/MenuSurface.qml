import QtQuick
import Quickshell
import Quickshell.Wayland
import "components" as Components
import "../fx"

// Owns the two layer-shell surfaces, card layout, and keyboard routing.
// All behaviour is delegated through the public OmniMenu state object.
Item {
    id: view

    required property var omni
    required property var processes
    required property var themes
    required property var bookmarks
    required property var ollamaChat

    property bool shown: view.omni.visible_
    property bool closing: false
    property real reveal: 0
    // Geometry remains full-size; a binary centre-out section mask constructs
    // both of Omni's layer-shell surfaces.
    readonly property real revealScaleFrom: 1
    readonly property real revealScale: revealScaleFrom + (1 - revealScaleFrom) * reveal
    readonly property real closeDurationFactor: 0.6
    readonly property int closeDuration: Math.round(view.omni.animationDuration * closeDurationFactor)
    readonly property bool transitionVisible: shown || closing
                                                || contentTransition.effectActive
    readonly property real frameTopInset: view.omni.desktop
                                           ? view.omni.desktop.barInset : 0
    readonly property real frameBottomInset: view.omni.desktop
                                              ? view.omni.desktop.frameThickness : 0

    function centeredCardY(containerHeight, cardHeight) {
        const insideHeight = Math.max(0, containerHeight
                                         - view.frameTopInset
                                         - view.frameBottomInset);
        return view.frameTopInset + Math.max(0, insideHeight - cardHeight) / 2;
    }

    function animateReveal(toValue, durationMs) {
        revealAnim.stop();
        revealAnim.from = view.reveal;
        revealAnim.to = toValue;
        revealAnim.duration = Math.max(1, durationMs);
        revealAnim.start();
    }

    function openTransition() {
        closeHold.stop();
        view.closing = false;
        const freshOpen = contentTransition.phase < 0.001;
        view.animateReveal(1, view.omni.animationDuration);
        contentTransition.open(freshOpen, 1);
        bootGlitch.open(freshOpen);
    }

    function closeTransition() {
        view.closing = true;
        view.animateReveal(0, view.closeDuration);
        contentTransition.close(view.closeDurationFactor);
        bootGlitch.close();
        closeHold.restart();
    }

    onShownChanged: {
        if (shown)
            openTransition();
        else
            closeTransition();
    }

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
        visible: view.transitionVisible
        color: "transparent"
        implicitWidth: card.width
        implicitHeight: card.height
        anchors { top: true }
        margins.top: screen ? view.centeredCardY(screen.height, height) : 0
        exclusionMode: ExclusionMode.Ignore
        // The visual glass sits on Top while the fullscreen keyboard/input
        // layer remains Overlay, keeping all Omni content above this background.
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "omni-menu-blur"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        Item {
            id: paletteSurface
            anchors.fill: parent
            opacity: 1
            scale: 1

            SquircleClipHost {
                anchors.fill: parent
                root: view.omni
                shell: true

                Item {
                    anchors.fill: parent
                    layer.enabled: paletteGlass.visible && contentTransition.layerRequired
                    layer.smooth: false
                    layer.effect: ContentGlitch {
                        sectionReveal: true
                        progress: contentTransition.progress
                        quality: contentTransition.quality
                        resolutionPixels: contentTransition.resolutionPixels
                        seed: contentTransition.seed
                        splitStrength: contentTransition.splitStrength
                        splitPixels: contentTransition.splitPixels
                        visualScale: 1
                        corner: view.omni.frameCornerRadius
                        cornerPower: view.omni.contentCornerPower
                        accent: view.omni.seal
                    }

                    SquircleSurface {
                        anchors.fill: parent
                        color: view.omni.bg
                        radius: view.omni.frameCornerRadius
                        power: view.omni.contentCornerPower
                    }

                    BootGlitch {
                        id: bootGlitch
                        anchors.fill: parent
                        theme: view.omni.theme
                        corner: view.omni.frameCornerRadius
                        cornerPower: view.omni.contentCornerPower
                        visualScale: 1
                        resolutionPixels: contentTransition.resolutionPixels
                        originX: paletteGlass.screen ? (paletteGlass.screen.width - paletteGlass.width) / 2 : 0
                        originY: paletteGlass.screen
                                 ? view.centeredCardY(paletteGlass.screen.height,
                                                      paletteGlass.height)
                                 : 0
                        openDuration: view.omni.animationDuration
                        closeDurationFactor: view.closeDurationFactor
                    }
                }
            }
        }
    }

    PanelWindow {
        id: panel
        visible: view.transitionVisible
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "omni-menu-input"
        WlrLayershell.keyboardFocus: view.omni.visible_ ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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

        Item {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            // Align the card's centre with the usable area inside the frame,
            // accounting for the thicker top bar and the bottom frame rail.
            y: view.centeredCardY(parent.height, height)
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
            transformOrigin: Item.Center
            scale: 1

            SquircleClipHost {
                anchors.fill: parent
                root: view.omni
                shell: true

                Item {
                    anchors.fill: parent
                    layer.enabled: panel.visible && contentTransition.layerRequired
                    layer.smooth: false
                    layer.effect: ContentGlitch {
                        sectionReveal: true
                        progress: contentTransition.progress
                        quality: contentTransition.quality
                        resolutionPixels: contentTransition.resolutionPixels
                        seed: contentTransition.seed
                        splitStrength: contentTransition.splitStrength
                        splitPixels: contentTransition.splitPixels
                        visualScale: 1
                        corner: view.omni.frameCornerRadius
                        cornerPower: view.omni.contentCornerPower
                        accent: view.omni.seal
                    }

                    SquircleSurface {
                        anchors.fill: parent
                        color: "transparent"
                        borderColor: view.omni.sep
                        borderWidth: 1
                        radius: view.omni.frameCornerRadius
                        power: view.omni.contentCornerPower
                    }

                    // Swallow clicks so the underlying dismiss MouseArea doesn't fire.
                    MouseArea { anchors.fill: parent }

                    Column {
                        id: cardCol
                        anchors.fill: parent
                        anchors.margins: view.omni.shellInset
                        spacing: view.omni.popupSectionGap

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

            focus: view.omni.visible_
            Keys.onPressed: keyRouter.handle(event)
        }
    }

    PopupGlitchTransition {
        id: contentTransition

        duration: view.omni.animationDuration
        closeDurationFactor: view.closeDurationFactor
        freeStanding: true
    }

    NumberAnimation {
        id: revealAnim

        target: view
        property: "reveal"
        easing.type: Easing.InOutCubic
    }

    Timer {
        id: closeHold
        interval: view.closeDuration + 40
        repeat: false
        onTriggered: view.closing = false
    }
}
