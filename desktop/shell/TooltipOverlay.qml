import QtQuick
import Quickshell
import Quickshell.Wayland
import "../fx"

// Click-through layer pinned above everything. Position is computed from
// the bar-window-local anchor (set by the hovered module) so the tip sits
// just below the top bar, centred on the icon.
PanelWindow {
    id: tooltipOverlay
    required property var root

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-tooltip"
    mask: Region {}

    // Keep alive briefly so the fade-out can play before the window is
    // torn down on first show; afterwards visibility tracks reveal.
    property real reveal: root.tooltipShown ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: tooltipOverlay.root.animationDuration
            easing.type: Easing.InOutCubic
        }
    }
    visible: reveal > 0.001

    Item {
        id: tip
        readonly property int gap:  6
        readonly property int padH: 8
        readonly property int padV: 3

        width:  tipLabel.implicitWidth  + padH * 2
        height: tipLabel.implicitHeight + padV * 2

        x: {
            const center = tooltipOverlay.root.tooltipBarX;
            return Math.max(4, Math.min(parent.width - width - 4, center - width / 2));
        }
        y: tooltipOverlay.root.barHeight + gap

        opacity: tooltipOverlay.reveal

        SquircleSurface {
            anchors.fill: parent
            color: tooltipOverlay.root.bg
            borderColor: tooltipOverlay.root.sep
            borderWidth: 1
            radius: tooltipOverlay.root.popupCornerRadius
            power: tooltipOverlay.root.popupCornerPower
        }

        Text {
            id: tipLabel
            anchors.centerIn: parent
            text: tooltipOverlay.root.tooltipText
            color: tooltipOverlay.root.ink
            font.family: tooltipOverlay.root.mono
            font.pixelSize: 10
            font.letterSpacing: 1
        }
    }
}
