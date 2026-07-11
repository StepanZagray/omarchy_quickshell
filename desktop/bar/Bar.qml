import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar

    required property var root
    property string shellScreenName: ""
    readonly property color dim: Qt.rgba(bar.root.ink.r, bar.root.ink.g, bar.root.ink.b, 0.45)

    color: "transparent"
    implicitHeight: bar.root.barInset
    exclusiveZone: bar.root.barInset
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-menu"
    // Re-claim popup anchors when the bar becomes visible. Popups read these
    // at open time, so the mapped bar must own them.
    onVisibleChanged: {
        if (visible)
            bar.root.calendarAnchorItem = clockItem;

    }

    anchors {
        top: true
        left: true
        right: true
    }

    // Container for clock + modules + hairlines.
    Rectangle {
        id: slabBg

        anchors.fill: parent
        color: "transparent"

        // Centre cluster: clock only, clickable.
        Item {
            id: clockItem

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            z: 10
            Component.onCompleted: bar.root.calendarAnchorItem = clockItem
            implicitWidth: clockOneLine.implicitWidth + 14
            implicitHeight: clockOneLine.implicitHeight + 8

            Bloom {
                id: clockBloom

                root: bar.root
            }

            Text {
                id: clockOneLine

                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: bar.root.hh + ":" + bar.root.mm + " " + bar.root.dd + " " + bar.root.mon
                color: clockMouse.containsMouse ? bar.root.seal : bar.root.ink
                font.family: bar.root.mono
                font.pixelSize: 12
                font.letterSpacing: 2
                font.weight: Font.Light

                Behavior on color {
                    ColorAnimation {
                        duration: 180
                        easing.type: Easing.InOutCubic
                    }

                }

            }

            Timer {
                id: clockTipDelay

                interval: 320
                onTriggered: {
                    const p = clockItem.mapToItem(null, clockItem.width / 2, clockItem.height / 2);
                    bar.root.showTooltip("Calendar", p.x, p.y);
                }
            }

            MouseArea {
                id: clockMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    clockBloom.fire(mouseX, mouseY);
                    clockTipDelay.restart();
                }
                onExited: {
                    clockTipDelay.stop();
                    bar.root.hideTooltip("Calendar");
                }
                onClicked: {
                    clockTipDelay.stop();
                    bar.root.hideTooltip("Calendar");
                    bar.root.popupAnchorScreen = bar.shellScreenName;
                    bar.root.frameWidgetScreen = bar.root.popupAnchorScreen;
                    if (bar.root.calendarVisible)
                        bar.root.calendarVisible = false;
                    else
                        bar.root.openCalendar();
                }
            }

        }

        GridLayout {
            // Aether / Display / Screenshots / Videos moved into the
            // OmniMenu Quick panel (Alt+Space). The bar keeps only the
            // always-glanced status indicators on the right.

            anchors.fill: parent
            anchors.leftMargin: 2
            anchors.rightMargin: 2
            flow: GridLayout.LeftToRight
            rowSpacing: 0
            columnSpacing: 0

            BarButton {
                root: bar.root
                glyph: bar.root.icoOmarchy
                tooltip: "Menu"
                color: bar.root.seal
                fontFamily: "omarchy"
                fontSize: 14
                onActivated: bar.root.paletteToggleRequested()
                onRightActivated: bar.root.run("xdg-terminal-exec")
            }

            Separator {
                root: bar.root
            }

            RowLayout {
                Layout.leftMargin: 3
                Layout.rightMargin: 3
                spacing: 0

                Repeater {
                    model: 10

                    delegate: Workspace {
                        required property int index

                        root: bar.root
                        wsId: index + 1
                        active: bar.root.activeWs === (index + 1)
                        present: bar.root.existingWs.indexOf(index + 1) !== -1
                        onActivated: bar.root.run("hyprctl dispatch workspace " + (index + 1))
                    }

                }

            }

            Item {
                Layout.fillWidth: true
            }

            Separator {
                root: bar.root
            }

            BarButton {
                id: mediaMod

                root: bar.root
                Component.onCompleted: bar.root.mediaAnchorItem = mediaMod
                glyph: bar.root.musicPlaying ? bar.root.icoPause : (bar.root.musicTitle.length > 0 ? bar.root.icoPlay : bar.root.icoMusic)
                value: "MEDIA"
                valueColor: bar.root.musicPlaying ? bar.root.seal : bar.root.ink
                tooltip: bar.root.musicTitle.length > 0 ? (bar.root.musicArtist.length > 0 ? bar.root.musicTitle + " - " + bar.root.musicArtist : "Media · " + bar.root.musicTitle) : "Media"
                onActivated: {
                    bar.root.mediaAnchorItem = mediaMod;
                    bar.root.popupAnchorScreen = bar.shellScreenName;
                    bar.root.frameWidgetScreen = bar.root.popupAnchorScreen;
                    if (bar.root.mediaVisible)
                        bar.root.mediaVisible = false;
                    else
                        bar.root.openMedia();
                }
                onRightActivated: bar.root.musicNext()
            }

            BarButton {
                root: bar.root
                glyph: bar.root.audioIcon
                value: bar.root.audioMuted ? "MUTE" : bar.root.audioVol + "%"
                valueColor: bar.root.audioMuted ? bar.root.seal : bar.root.ink
                tooltip: bar.root.audioMuted ? "Audio muted · " + bar.root.audioVol + "%" : "Audio " + bar.root.audioVol + "%"
                onActivated: bar.root.run("omarchy-launch-audio")
                onRightActivated: bar.root.run("pamixer -t")
            }

            BarButton {
                root: bar.root
                glyph: bar.root.netIcon
                value: bar.root.netKind === "none" ? "OFFLINE" : ""
                valueColor: bar.root.netKind === "none" ? bar.root.seal : bar.root.ink
                tooltip: {
                    if (bar.root.netKind === "eth")
                        return "Ethernet";

                    if (bar.root.netKind === "wifi") {
                        const name = bar.root.wifiSsid || "(hidden)";
                        return "Wi-Fi · " + name + " · " + bar.root.wifiSignal + "%";
                    }
                    return "Offline";
                }
                onActivated: bar.root.run("omarchy-launch-wifi")
            }

            BarButton {
                root: bar.root
                glyph: bar.root.btIcon
                valueColor: bar.root.btPowered ? bar.root.ink : bar.dim
                tooltip: {
                    if (!bar.root.btPowered)
                        return "Bluetooth off";

                    return bar.root.btCount > 0 ? "Bluetooth · " + bar.root.btCount + " connected" : "Bluetooth on";
                }
                onActivated: bar.root.run("omarchy-launch-bluetooth")
            }

            BarButton {
                root: bar.root
                visible: bar.root.layoutCount > 1
                value: bar.root.layoutLabel
                valueColor: bar.root.layoutLabel === bar.root.layoutCodes[0].toUpperCase() ? bar.root.ink : bar.root.seal
                tooltip: bar.root.layoutTooltip
                onActivated: bar.root.cycleLayout()
            }

            BarButton {
                root: bar.root
                glyph: "󰍛"
                tooltip: "CPU " + Math.round(bar.root.cpuVal) + "%"
                color: bar.root.cpuVal > 80 ? bar.root.seal : bar.root.ink
                onActivated: bar.root.run("omarchy-launch-or-focus-tui btop")
            }

            BarButton {
                root: bar.root
                visible: bar.root.omarchyUpdateAvailable
                value: "UPD"
                valueColor: bar.root.seal
                blink: true
                tooltip: bar.root.omarchyLatestTag ? "Omarchy update available · " + bar.root.omarchyLatestTag : "Omarchy update available"
                onActivated: bar.root.openOmarchyUpdate()
            }

            BarButton {
                root: bar.root
                label: "BAT"
                value: bar.root.batVal + "%"
                valueColor: bar.root.batVal <= 10 ? bar.root.seal : bar.root.batVal <= 20 ? bar.root.indigo : bar.root.ink
                gaugeColor: bar.root.batState === "Charging" || bar.root.batState === "Full" ? bar.root.indigo : (bar.root.batVal <= 20 ? bar.root.seal : bar.root.ink)
                tooltip: {
                    let s = "Battery " + bar.root.batVal + "%";
                    if (bar.root.batPower >= 0.05) {
                        const sign = bar.root.batState === "Charging" ? "+" : bar.root.batState === "Discharging" ? "-" : "";
                        s += "  " + sign + bar.root.batPower.toFixed(1) + " W";
                    }
                    return s;
                }
                onActivated: bar.root.run("omarchy-menu power")
            }

        }

    }

}
