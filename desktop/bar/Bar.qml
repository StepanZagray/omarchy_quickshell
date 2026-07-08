import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar

    required property var root
    property string shellScreenName: ""
    // Cloud mode: horizontal+round only. Vertical bars keep the original
    // slab geometry to avoid breaking the proven layout.
    readonly property int cloudPad: 2
    readonly property int cloudAir: 5
    readonly property int cloudInnerAir: 2
    readonly property bool cloudMode: false
    readonly property int extraThickness: cloudMode ? 2 * cloudPad + cloudAir + cloudInnerAir : 0
    // innerSign tells which side gets the extra outer air (away from screen).
    readonly property int innerSign: bar.root.barEdge === "top" ? 1 : (bar.root.barEdge === "bottom" ? -1 : 0)
    readonly property color dim: Qt.rgba(bar.root.ink.r, bar.root.ink.g, bar.root.ink.b, 0.45)

    color: "transparent"
    implicitHeight: bar.root.isHorizontal ? bar.root.barInset + extraThickness : 0
    implicitWidth: bar.root.isHorizontal ? 0 : bar.root.barInset
    exclusiveZone: bar.root.isHorizontal ? bar.root.barInset + extraThickness : bar.root.barInset
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-menu"
    // Re-claim popup anchors when the bar becomes visible. Popups read these
    // at open time, so the mapped bar must own them.
    onVisibleChanged: {
        if (visible)
            bar.root.calendarAnchorItem = clockItem;

    }

    // Anchors track barEdge — three sides anchored, the side opposite
    // the bar's edge is left free for the bar's thickness to extend.
    anchors {
        top: bar.root.barEdge !== "bottom"
        bottom: bar.root.barEdge !== "top"
        left: bar.root.barEdge !== "right"
        right: bar.root.barEdge !== "left"
    }

    // In cloud mode the slab bg is replaced by a single rounded backdrop
    // sized to match the inner bar (barHeight tall, with cloudAir margins
    // on each side along the bar axis, sliding toward the inner edge so
    // outer-side air sits between cloud and screen edge).
    Rectangle {
        id: cloudBg

        visible: bar.cloudMode
        x: bar.cloudAir
        y: bar.innerSign === 1 ? bar.cloudAir : bar.cloudInnerAir
        width: parent.width - 2 * bar.cloudAir
        height: bar.root.barHeight + 2 * bar.cloudPad
        radius: bar.root.cornerRadius
        color: bar.root.bg
        z: 0
        // Idle dim, slow 6s ease both ways. Driven by states/transitions rather
        // than a Behavior with an isIdle-bound duration: that bound duration is
        // re-evaluated in the same notify pass as the opacity write and lags one
        // toggle behind, so each direction could inherit the other's speed.
        // from/to pins each direction's duration.
        opacity: 1
        transitions: [
            Transition {
                to: "idle"

                NumberAnimation {
                    property: "opacity"
                    duration: 6000
                    easing.type: Easing.InOutCubic
                }

            },
            Transition {
                from: "idle"

                NumberAnimation {
                    property: "opacity"
                    duration: 6000
                    easing.type: Easing.InOutCubic
                }

            }
        ]

        states: State {
            name: "idle"
            when: bar.root.isIdle

            PropertyChanges {
                target: cloudBg
                opacity: 0.7
            }

        }

    }

    // Container for clock + modules + hairlines. In cloud mode the bg
    // becomes transparent so the cloud rectangle above shows through;
    // in slab mode this acts as the bar background.
    Rectangle {
        id: slabBg

        anchors.fill: parent
        color: "transparent"

        // Inner-edge hairline for vertical bars only (horizontal top bar has no
        // bottom border — frame handles the desktop edge).
        Rectangle {
            visible: !bar.cloudMode && !bar.root.isHorizontal
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: bar.root.barEdge === "left" ? parent.right : undefined
            anchors.left: bar.root.barEdge === "right" ? parent.left : undefined
            width: 1
            color: bar.root.sep
        }

        // Centre cluster: clock only, clickable. Horizontal bars show
        // "HH:MM" on one line; vertical bars stack HH and MM.
        Item {
            id: clockItem

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            z: 10
            Component.onCompleted: bar.root.calendarAnchorItem = clockItem
            implicitWidth: bar.root.isHorizontal ? clockOneLine.implicitWidth + 14 : Math.max(clockHH.implicitWidth, clockMM.implicitWidth) + 8
            implicitHeight: bar.root.isHorizontal ? clockOneLine.implicitHeight + 8 : (clockHH.implicitHeight + clockMM.implicitHeight + 6)

            Bloom {
                id: clockBloom

                root: bar.root
            }

            Text {
                id: clockOneLine

                visible: bar.root.isHorizontal
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

            Text {
                id: clockHH

                visible: !bar.root.isHorizontal
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
                anchors.bottomMargin: 1
                text: bar.root.hh
                color: clockMouse.containsMouse ? bar.root.seal : bar.root.ink
                font.family: bar.root.mono
                font.pixelSize: 11
                font.weight: Font.Light

                Behavior on color {
                    ColorAnimation {
                        duration: 180
                        easing.type: Easing.InOutCubic
                    }

                }

            }

            Text {
                id: clockMM

                visible: !bar.root.isHorizontal
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.verticalCenter
                anchors.topMargin: 1
                text: bar.root.mm
                color: clockMouse.containsMouse ? bar.root.seal : bar.root.ink
                font.family: bar.root.mono
                font.pixelSize: 11
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
            anchors.leftMargin: bar.root.isHorizontal ? (bar.cloudMode ? bar.cloudAir + bar.cloudPad : 10) : 0
            anchors.rightMargin: bar.root.isHorizontal ? (bar.cloudMode ? bar.cloudAir + bar.cloudPad : 10) : 0
            anchors.topMargin: bar.root.isHorizontal ? (bar.cloudMode ? (bar.root.barEdge === "top" ? bar.cloudAir + bar.cloudPad : bar.cloudInnerAir + bar.cloudPad) : 0) : 10
            anchors.bottomMargin: bar.root.isHorizontal ? (bar.cloudMode ? (bar.root.barEdge === "top" ? bar.cloudInnerAir + bar.cloudPad : bar.cloudAir + bar.cloudPad) : 0) : 10
            flow: bar.root.isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
            rowSpacing: 4
            columnSpacing: 4
            columns: bar.root.isHorizontal ? -1 : 1
            rows: bar.root.isHorizontal ? 1 : -1

            Module {
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

            Item {
                Layout.fillWidth: bar.root.isHorizontal
                Layout.fillHeight: !bar.root.isHorizontal
            }

            Separator {
                root: bar.root
            }

            Stat {
                id: mediaMod

                root: bar.root
                Component.onCompleted: bar.root.mediaAnchorItem = mediaMod
                glyph: bar.root.musicPlaying ? bar.root.icoPause : bar.root.icoMusic
                value: "MEDIA"
                valueColor: bar.root.musicTitle.length > 0 ? bar.root.seal : bar.root.ink
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

            Stat {
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

            Stat {
                root: bar.root
                visible: bar.root.layoutCount > 1
                glyph: bar.root.icoKbd
                value: bar.root.layoutLabel
                valueColor: bar.root.layoutLabel === bar.root.layoutCodes[0].toUpperCase() ? bar.root.ink : bar.root.seal
                tooltip: bar.root.layoutTooltip
                onActivated: bar.root.cycleLayout()
            }

            Stat {
                root: bar.root
                glyph: bar.root.audioIcon
                value: bar.root.audioMuted ? "MUTE" : bar.root.audioVol + "%"
                valueColor: bar.root.audioMuted ? bar.root.seal : bar.root.ink
                tooltip: bar.root.audioMuted ? "Audio muted · " + bar.root.audioVol + "%" : "Audio " + bar.root.audioVol + "%"
                onActivated: bar.root.run("omarchy-launch-audio")
                onRightActivated: bar.root.run("pamixer -t")
            }

            Stat {
                root: bar.root
                glyph: bar.root.btIcon
                value: bar.root.btPowered ? (bar.root.btCount > 0 ? bar.root.btCount + "DEV" : "ON") : "OFF"
                valueColor: bar.root.btPowered ? bar.root.ink : bar.dim
                tooltip: {
                    if (!bar.root.btPowered)
                        return "Bluetooth off";

                    return bar.root.btCount > 0 ? "Bluetooth · " + bar.root.btCount + " connected" : "Bluetooth on";
                }
                onActivated: bar.root.run("omarchy-launch-bluetooth")
            }

            Module {
                root: bar.root
                glyph: "󰍛"
                tooltip: "CPU " + Math.round(bar.root.cpuVal) + "%"
                color: bar.root.cpuVal > 80 ? bar.root.seal : bar.root.ink
                onActivated: bar.root.run("omarchy-launch-or-focus-tui btop")
            }

            Stat {
                root: bar.root
                visible: bar.root.omarchyUpdateAvailable
                value: "UPD"
                valueColor: bar.root.seal
                blink: true
                tooltip: bar.root.omarchyLatestTag ? "Omarchy update available · " + bar.root.omarchyLatestTag : "Omarchy update available"
                onActivated: bar.root.openOmarchyUpdate()
            }

            Stat {
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

            Stat {
                root: bar.root
                glyph: bar.root.edgeArrow()
                tooltip: "Move bar"
                onActivated: bar.root.cycleBarEdge()
            }

        }

    }

}
