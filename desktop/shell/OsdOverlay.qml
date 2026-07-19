import QtQuick
import Quickshell
import Quickshell.Wayland

// Fullscreen layer per monitor — same approach as the original port. A compact
// PanelWindow clips transform-based slide; the full surface gives the chip room
// to travel below its resting position before sliding up into view.
PanelWindow {
    id: osdWin

    required property var osd
    required property var theme
    required property var screen
    property string shellScreenName: ""
    readonly property int chipPad: 16
    readonly property int chipGap: 16
    readonly property int iconSlot: 16
    readonly property int barSlot: 120
    readonly property int valueSlot: 16
    readonly property int chipHeight: 44
    readonly property int slideDistance: 24
    readonly property int chipMarginBottom: 70
    // Match PowerMenu shell reveal: grow from this scale → 1 as `reveal` goes 0→1.
    readonly property real revealScaleFrom: 0.9
    readonly property int barChipWidth: chipPad * 2 + iconSlot + chipGap + barSlot + chipGap + valueSlot
    readonly property bool barMode: osd.osdKind === "volume" || osd.osdKind === "brightness" || osd.osdKind === "kbd-brightness"
    readonly property bool showIcon: osd.osdKind !== "caps"
    readonly property int statusChipWidth: Math.max(120, statusMeasure.implicitWidth + chipPad * 2)
    readonly property int chipWidth: barMode ? barChipWidth : statusChipWidth
    readonly property bool targetScreen: osd.osdVisible && (osd.osdScreen.length === 0 || osd.osdScreen === osdWin.shellScreenName)
    readonly property string osdIcon: {
        switch (osd.osdKind) {
        case "volume":
            return osd.osdMuted ? osdWin.theme.icoMute : osdWin.theme.audioIcon;
        case "brightness":
            return osdWin.theme.icoSun;
        case "kbd-brightness":
            return osdWin.theme.icoKbd;
        case "mic":
            return osd.osdActive ? osdWin.theme.icoMic : osdWin.theme.icoMicMute;
        case "touchpad":
            return osd.osdActive ? osdWin.theme.icoTouchpad : osdWin.theme.icoTouchpadOff;
        default:
            return "";
        }
    }
    readonly property color osdIconColor: {
        if (osd.osdKind === "volume" && osd.osdMuted)
            return osdWin.theme.seal;

        if ((osd.osdKind === "mic" || osd.osdKind === "touchpad") && !osd.osdActive)
            return osdWin.theme.seal;

        return osdWin.theme.ink;
    }
    property real reveal: targetScreen ? 1 : 0

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-osd"
    visible: reveal > 0.001

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Text {
        id: statusMeasure

        visible: false
        text: osdWin.osd.osdLabel
        font.family: osdWin.theme.mono
        font.pixelSize: 14
        font.letterSpacing: 1
    }

    Rectangle {
        id: chip

        width: osdWin.chipWidth
        height: osdWin.chipHeight
        x: Math.round((parent.width - width) / 2)
        y: parent.height - osdWin.chipHeight - osdWin.chipMarginBottom
        radius: osdWin.theme.cornerRadius
        color: osdWin.theme.bg
        border.color: osdWin.theme.sep
        border.width: 1
        opacity: osdWin.reveal
        transform: [
            Scale {
                origin.x: chip.width / 2
                origin.y: chip.height / 2
                xScale: osdWin.revealScaleFrom + (1 - osdWin.revealScaleFrom) * osdWin.reveal
                yScale: osdWin.revealScaleFrom + (1 - osdWin.revealScaleFrom) * osdWin.reveal
            },
            Translate {
                y: (1 - osdWin.reveal) * osdWin.slideDistance
            }
        ]

        Item {
            id: pad

            anchors.fill: parent
            anchors.margins: osdWin.chipPad

            Row {
                id: barRow

                visible: osdWin.barMode
                anchors.centerIn: parent
                spacing: osdWin.chipGap
                height: pad.height

                Item {
                    width: osdWin.iconSlot
                    height: barRow.height

                    Text {
                        anchors.centerIn: parent
                        text: osdWin.osdIcon
                        color: osdWin.osdIconColor
                        font.family: osdWin.theme.mono
                        font.pixelSize: 16
                    }

                }

                Item {
                    width: osdWin.barSlot
                    height: barRow.height

                    Item {
                        width: parent.width
                        height: 6
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: Qt.rgba(osdWin.theme.ink.r, osdWin.theme.ink.g, osdWin.theme.ink.b, 0.12)
                        }

                        Rectangle {
                            height: parent.height
                            width: parent.width * Math.max(0, Math.min(1, osdWin.osd.osdValue / 100))
                            radius: 3
                            color: osdWin.theme.seal
                        }

                    }

                }

                Item {
                    width: osdWin.valueSlot
                    height: barRow.height

                    Text {
                        anchors.centerIn: parent
                        text: osdWin.osd.osdValue
                        color: osdWin.theme.inkDeep
                        font.family: osdWin.theme.mono
                        font.pixelSize: 13
                        font.letterSpacing: 1
                    }

                }

            }

            Row {
                visible: !osdWin.barMode && osdWin.showIcon
                anchors.centerIn: parent
                spacing: osdWin.chipGap
                height: pad.height

                Item {
                    width: osdWin.iconSlot
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        text: osdWin.osdIcon
                        color: osdWin.osdIconColor
                        font.family: osdWin.theme.mono
                        font.pixelSize: 14
                    }

                }

                Item {
                    height: parent.height
                    width: statusMeasure.implicitWidth

                    Text {
                        anchors.centerIn: parent
                        text: osdWin.osd.osdLabel
                        color: osdWin.theme.inkDeep
                        font.family: osdWin.theme.mono
                        font.pixelSize: 14
                        font.letterSpacing: 1
                    }

                }

            }

            Text {
                visible: !osdWin.barMode && !osdWin.showIcon
                anchors.centerIn: parent
                text: osdWin.osd.osdLabel
                color: osdWin.theme.inkDeep
                font.family: osdWin.theme.mono
                font.pixelSize: 14
                font.letterSpacing: 1
            }

        }

    }

    Behavior on reveal {
        NumberAnimation {
            duration: osdWin.theme.animationDuration
            easing.type: Easing.InOutCubic
        }

    }

    mask: Region {
    }

}
