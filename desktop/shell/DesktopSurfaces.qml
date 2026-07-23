import "../bar"
import "../popups"
import QtQuick
import Quickshell

// Layer surfaces for the desktop shell: bar, frame, popups, tooltips.
Item {
    id: root

    required property var shell
    required property var osd

    Variants {
        id: shellVisuals

        property var shellRoot: root.shell

        model: Quickshell.screens

        delegate: ShellVisual {
            required property var modelData

            root: shellVisuals.shellRoot
            screen: modelData
            shellScreenName: modelData.name
        }

    }

    Variants {
        id: bars

        property var shellRoot: root.shell

        model: Quickshell.screens

        delegate: Bar {
            required property var modelData

            root: bars.shellRoot
            screen: modelData
            shellScreenName: modelData.name
        }

    }

    Variants {
        id: desktopFrames

        property var shellRoot: root.shell

        model: Quickshell.screens

        delegate: DesktopFrame {
            required property var modelData

            root: desktopFrames.shellRoot
            screen: modelData
            visible: false
        }

    }

    Variants {
        id: notificationOverlays

        property var shellRoot: root.shell

        model: Quickshell.screens

        delegate: NotificationOverlay {
            required property var modelData

            root: notificationOverlays.shellRoot
            screen: modelData
            shellScreenName: modelData.name
            fallbackScreen: Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]
        }

    }

    TooltipOverlay {
        root: root.shell
    }

    SystemPopup {
        root: root.shell
    }

    Variants {
        id: powerMenuPopups

        property var shellRoot: root.shell

        model: Quickshell.screens

        delegate: PowerMenuPopup {
            required property var modelData

            root: powerMenuPopups.shellRoot
            screen: modelData
            shellScreenName: modelData.name
        }

    }

    Variants {
        id: calendarPopups

        property var shellRoot: root.shell

        model: Quickshell.screens

        delegate: CalendarPopup {
            required property var modelData

            root: calendarPopups.shellRoot
            screen: modelData
            shellScreenName: modelData.name
        }

    }

    Variants {
        id: mediaPopups

        property var shellRoot: root.shell

        model: Quickshell.screens

        delegate: MediaPopup {
            required property var modelData

            root: mediaPopups.shellRoot
            screen: modelData
            shellScreenName: modelData.name
        }

    }

    Variants {
        id: osdPopups

        property var shellRoot: root.shell
        property var osdRef: root.osd

        model: Quickshell.screens

        delegate: OsdPopup {
            required property var modelData

            root: osdPopups.shellRoot
            osd: osdPopups.osdRef
            screen: modelData
            shellScreenName: modelData.name
        }

    }

    Variants {
        id: widgetDismissLayers

        property var shellRoot: root.shell

        model: Quickshell.screens

        delegate: WidgetDismissLayer {
            required property var modelData

            root: widgetDismissLayers.shellRoot
            screen: modelData
            shellScreenName: modelData.name
        }

    }

    ScreenshotsPopup {
        root: root.shell
    }

    VideosPopup {
        root: root.shell
    }

    AetherPopup {
        root: root.shell
    }

    DisplayPopup {
        root: root.shell
    }

}
