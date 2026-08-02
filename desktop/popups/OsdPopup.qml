import QtQuick
import "../fx"

// Frame-attached volume/brightness/caps OSD. Same CardWindow + FrameBorder
// morph path as MediaPopup / CalendarPopup / PowerMenuPopup — the desktop frame
// redraws into a bottom-right pocket; this file only supplies the chip content.
CardWindow {
    id: osdPopup

    required property var root
    required property var osd
    property string shellScreenName: ""
    readonly property int chipPad: 12
    readonly property int chipGap: 16
    readonly property int iconSlot: 16
    readonly property int barSlot: 120
    readonly property int valueSlot: 16
    readonly property int chipHeight: 32
    readonly property int barChipWidth: chipPad * 2 + iconSlot + chipGap + barSlot + chipGap + valueSlot
    readonly property bool barMode: osd.osdKind === "volume" || osd.osdKind === "brightness" || osd.osdKind === "kbd-brightness"
    readonly property bool showIcon: osd.osdKind !== "caps"
    readonly property int statusChipWidth: Math.max(120, Math.ceil(statusMeasure.implicitWidth) + chipPad * 2)
    readonly property int chipWidth: barMode ? barChipWidth : statusChipWidth
    readonly property bool targetScreen: osd.osdVisible && (osd.osdScreen.length === 0 || osd.osdScreen === osdPopup.shellScreenName)
    readonly property string osdIcon: {
        switch (osd.osdKind) {
        case "volume":
            return osd.osdMuted ? osdPopup.root.icoMute : osdPopup.root.audioIcon;
        case "brightness":
            return osdPopup.root.icoSun;
        case "kbd-brightness":
            return osdPopup.root.icoKbd;
        case "mic":
            return osd.osdActive ? osdPopup.root.icoMic : osdPopup.root.icoMicMute;
        case "touchpad":
            return osd.osdActive ? osdPopup.root.icoTouchpad : osdPopup.root.icoTouchpadOff;
        default:
            return "";
        }
    }
    readonly property color osdIconColor: {
        if (osd.osdKind === "volume" && osd.osdMuted)
            return osdPopup.root.seal;

        if ((osd.osdKind === "mic" || osd.osdKind === "touchpad") && !osd.osdActive)
            return osdPopup.root.seal;

        return osdPopup.root.ink;
    }

    theme: root
    revealed: targetScreen
    // Same sizing model as MediaPopup: content height + free-edge body padding.
    cardWidth: chipWidth
    cardHeight: chipHeight + bodyPaddingTop + bodyPaddingBottom
    contentOpenDelayFactor: 0
    contentOpenDurationFactor: 1
    contentCloseDurationFactor: 0.5
    layerNamespace: "omarchy-osd"
    frameAttached: true
    frameAttachRight: true
    frameAttachBottom: true
    frameScreenName: shellScreenName
    exclusiveFocus: false
    captureInput: false
    bodyPaddingTop: 8
    bodyPaddingBottom: 0
    bodyPaddingLeft: 16
    bodyPaddingRight: 8
    bodySpacing: 0

    Item {
        width: parent.width
        height: osdPopup.chipHeight

        Item {
            id: osdContent

            width: parent.width
            height: parent.height
            Text {
                id: statusMeasure

                visible: false
                text: osdPopup.osd.osdLabel
                font.family: osdPopup.root.mono
                font.pixelSize: 15
                font.letterSpacing: 1
            }

            Row {
                id: barRow

                visible: osdPopup.barMode
                anchors.centerIn: parent
                spacing: osdPopup.chipGap
                height: parent.height

                Item {
                    width: osdPopup.iconSlot
                    height: barRow.height

                    Text {
                        anchors.centerIn: parent
                        text: osdPopup.osdIcon
                        color: osdPopup.osdIconColor
                        font.family: osdPopup.root.mono
                        font.pixelSize: 18
                    }

                }

                Item {
                    width: osdPopup.barSlot
                    height: barRow.height

                    Item {
                        width: parent.width
                        height: 8
                        anchors.verticalCenter: parent.verticalCenter

                        SquircleRect {
                            anchors.fill: parent
                            root: osdPopup.root
                            color: Qt.rgba(osdPopup.root.ink.r, osdPopup.root.ink.g, osdPopup.root.ink.b, 0.12)
                        }

                        SquircleRect {
                            height: parent.height
                            width: parent.width * Math.max(0, Math.min(1, osdPopup.osd.osdValue / 100))
                            root: osdPopup.root
                            color: osdPopup.root.seal
                        }

                    }

                }

                Item {
                    width: osdPopup.valueSlot
                    height: barRow.height

                    Text {
                        anchors.centerIn: parent
                        text: osdPopup.osd.osdValue
                        color: osdPopup.root.inkDeep
                        font.family: osdPopup.root.mono
                        font.pixelSize: 14
                        font.letterSpacing: 1
                    }

                }

            }

            Row {
                visible: !osdPopup.barMode && osdPopup.showIcon
                anchors.centerIn: parent
                spacing: osdPopup.chipGap
                height: parent.height

                Item {
                    width: osdPopup.iconSlot
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        text: osdPopup.osdIcon
                        color: osdPopup.osdIconColor
                        font.family: osdPopup.root.mono
                        font.pixelSize: 15
                    }

                }

                Item {
                    height: parent.height
                    width: statusMeasure.implicitWidth

                    Text {
                        anchors.centerIn: parent
                        text: osdPopup.osd.osdLabel
                        color: osdPopup.root.inkDeep
                        font.family: osdPopup.root.mono
                        font.pixelSize: 15
                        font.letterSpacing: 1
                    }

                }

            }

            Text {
                visible: !osdPopup.barMode && !osdPopup.showIcon
                anchors.centerIn: parent
                text: osdPopup.osd.osdLabel
                color: osdPopup.root.inkDeep
                font.family: osdPopup.root.mono
                font.pixelSize: 15
                font.letterSpacing: 1
            }

        }

    }

}
