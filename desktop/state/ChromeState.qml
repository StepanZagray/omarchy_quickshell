import QtQuick
import Quickshell.Hyprland

Item {
    id: root

    required property var shell
    // Desktop frame state. Visuals are click-through and rendered by FrameBorder.
    readonly property int frameThickness: 4
    readonly property int frameRounding: 6
    // Shared by CardWindow reveal and FrameBorder widget morph.
    readonly property int frameAnimationDuration: shell.theme.animationDuration
    readonly property color frameBg: Qt.rgba(shell.bg.r, shell.bg.g, shell.bg.b, 0.8)
    property bool frameWidgetVisible: false
    property string frameWidgetOwner: ""
    property real frameWidgetX: 0
    property real frameWidgetY: 0
    property real frameWidgetWidth: 0
    property real frameWidgetHeight: 0
    property bool frameWidgetAttachRight: false
    property string frameWidgetScreen: ""
    property string tooltipText: ""
    property real tooltipBarX: 0
    property real tooltipBarY: 0
    property bool tooltipShown: false
    property real popupAnchorX: 0
    property real popupAnchorY: 0
    property string popupAnchorScreen: ""
    readonly property string focusedMonitorName: Hyprland.focusedMonitor && Hyprland.focusedMonitor.lastIpcObject ? Hyprland.focusedMonitor.lastIpcObject.name : ""
    property Item calendarAnchorItem: null
    property Item mediaAnchorItem: null
    property Item displayAnchorItem: null
    property Item systemAnchorItem: null

    function showTooltip(text, x, y) {
        if (!text)
            return ;

        root.tooltipText = text;
        root.tooltipBarX = x;
        root.tooltipBarY = y;
        root.tooltipShown = true;
    }

    function hideTooltip(text) {
        if (!text || root.tooltipText === text)
            root.tooltipShown = false;

    }

    function focusedScreenName() {
        return root.focusedMonitorName;
    }

    function anchorPopupTo(item) {
        if (!item)
            return ;

        const p = item.mapToItem(null, item.width / 2, item.height / 2);
        root.popupAnchorX = p.x;
        root.popupAnchorY = p.y;
    }

    onFocusedMonitorNameChanged: {
        if (!root.focusedMonitorName || !root.popupAnchorScreen)
            return ;

        if ((shell.calendarVisible || shell.mediaVisible) && root.focusedMonitorName !== root.popupAnchorScreen) {
            shell.calendarVisible = false;
            shell.mediaVisible = false;
        }
    }
}
