import "../quick"
import QtQuick

CardWindow {
    id: calendarPopup

    required property var root
    property string shellScreenName: ""
    property bool keyboardNavigation: false
    property int preferredDay: 0
    readonly property string wantedScreen: root.popupAnchorScreen || root.focusedScreenName()
    readonly property bool targetScreen: calendarPopup.wantedScreen.length === 0 || calendarPopup.shellScreenName.length === 0 || calendarPopup.wantedScreen === calendarPopup.shellScreenName

    function selectRelative(delta) {
        const cells = calendarPopup.root.calendarCells;
        let firstDay = 0;
        let lastDay = 0;
        for (let i = 0; i < cells.length; i++) {
            if (cells[i].day === 0)
                continue;

            if (firstDay === 0)
                firstDay = cells[i].day;

            lastDay = cells[i].day;
        }
        if (lastDay === 0)
            return ;

        let selected = calendarPopup.root.selectedDay;
        if (selected <= 0)
            selected = calendarPopup.root.calendarMonthOffset === 0 ? (new Date()).getDate() : firstDay;

        const nextDay = Math.max(firstDay, Math.min(lastDay, selected + delta));
        calendarPopup.root.selectedDay = nextDay;
        calendarPopup.preferredDay = nextDay;
    }

    function changeMonth(delta) {
        const wantedDay = calendarPopup.preferredDay > 0 ? calendarPopup.preferredDay : Math.max(1, calendarPopup.root.selectedDay);
        calendarPopup.root.calendarMonthOffset += delta;
        calendarPopup.root.calendarTick++;
        const cells = calendarPopup.root.calendarCells;
        let lastDay = 1;
        for (let i = 0; i < cells.length; i++) {
            if (cells[i].day > lastDay)
                lastDay = cells[i].day;

        }
        calendarPopup.preferredDay = wantedDay;
        calendarPopup.root.selectedDay = Math.min(wantedDay, lastDay);
    }

    function selectToday() {
        calendarPopup.root.calendarMonthOffset = 0;
        calendarPopup.root.calendarTick++;
        const today = (new Date()).getDate();
        calendarPopup.preferredDay = today;
        calendarPopup.root.selectedDay = today;
    }

    theme: root
    revealed: root.calendarVisible && calendarPopup.targetScreen
    frameScreenName: calendarPopup.shellScreenName
    cardWidth: 356
    contentOpenDelayFactor: 0
    contentOpenDurationFactor: 1
    contentCloseDurationFactor: 0.6
    bodyPaddingTop: 8
    bodyPaddingBottom: 16
    bodyPaddingLeft: 10
    bodyPaddingRight: 10
    layerNamespace: "omarchy-calendar"
    frameAttached: true
    onDismiss: calendarPopup.root.calendarVisible = false
    onRevealedChanged: {
        if (revealed) {
            calendarPopup.keyboardNavigation = false;
            calendarPopup.preferredDay = calendarPopup.root.selectedDay > 0 ? calendarPopup.root.selectedDay : (new Date()).getDate();
        }
    }
    onKeyPressed: function(event) {
        if (event.key === Qt.Key_Q) {
            calendarPopup.root.calendarVisible = false;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            calendarPopup.keyboardNavigation = true;
            calendarPopup.selectRelative(-1);
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            calendarPopup.keyboardNavigation = true;
            calendarPopup.selectRelative(1);
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            calendarPopup.keyboardNavigation = true;
            calendarPopup.selectRelative(-7);
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            calendarPopup.keyboardNavigation = true;
            calendarPopup.selectRelative(7);
        } else if (event.key === Qt.Key_PageUp) {
            calendarPopup.keyboardNavigation = true;
            calendarPopup.changeMonth(-1);
        } else if (event.key === Qt.Key_PageDown) {
            calendarPopup.keyboardNavigation = true;
            calendarPopup.changeMonth(1);
        } else if (event.key === Qt.Key_Home) {
            calendarPopup.keyboardNavigation = true;
            calendarPopup.selectToday();
        } else {
            return ;
        }
        event.accepted = true;
    }

    Column {
        width: parent.width
        spacing: 10

        Rectangle {
            width: parent.width
            height: 48
            radius: calendarPopup.root.cornerRadius
            color: Qt.rgba(calendarPopup.root.ink.r, calendarPopup.root.ink.g, calendarPopup.root.ink.b, 0.04)
            border.width: 1
            border.color: calendarPopup.root.sep

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: monthControls.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: calendarPopup.root.selectedDay > 0 ? calendarPopup.root.selectedDayDetail : "SELECT A DAY"
                color: calendarPopup.root.selectedDayHoliday.length > 0 ? calendarPopup.root.seal : calendarPopup.root.ink
                font.family: calendarPopup.root.mono
                font.pixelSize: 12
                font.letterSpacing: 0.25
                font.weight: Font.Medium
            }

            Row {
                id: monthControls

                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                QuickButton {
                    root: calendarPopup.root
                    width: 32
                    height: 32
                    padH: 8
                    glyph: "‹"
                    onClicked: {
                        calendarPopup.keyboardNavigation = false;
                        calendarPopup.changeMonth(-1);
                    }
                }

                QuickButton {
                    root: calendarPopup.root
                    width: 32
                    height: 32
                    padH: 8
                    glyph: "•"
                    selected: calendarPopup.root.calendarMonthOffset === 0
                    onClicked: {
                        calendarPopup.keyboardNavigation = false;
                        calendarPopup.selectToday();
                    }
                }

                QuickButton {
                    root: calendarPopup.root
                    width: 32
                    height: 32
                    padH: 8
                    glyph: "›"
                    onClicked: {
                        calendarPopup.keyboardNavigation = false;
                        calendarPopup.changeMonth(1);
                    }
                }

            }

        }

        Rectangle {
            width: parent.width
            height: calendarPlate.implicitHeight + 16
            radius: calendarPopup.root.cornerRadius
            color: Qt.rgba(calendarPopup.root.ink.r, calendarPopup.root.ink.g, calendarPopup.root.ink.b, 0.025)
            border.width: 1
            border.color: calendarPopup.root.sep

            Column {
                id: calendarPlate

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 4

                Row {
                    width: parent.width

                    Repeater {
                        model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]

                        delegate: Item {
                            required property string modelData
                            required property int index

                            width: parent.width / 7
                            height: 22

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: index >= 5 ? calendarPopup.root.seal : calendarPopup.root.inkDeep
                                opacity: index >= 5 ? 0.9 : 0.68
                                font.family: calendarPopup.root.mono
                                font.pixelSize: 10
                                font.letterSpacing: 1.6
                                font.weight: Font.Medium
                            }

                        }

                    }

                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: calendarPopup.root.sep
                }

                Grid {
                    columns: 7
                    rowSpacing: 2
                    columnSpacing: 0
                    width: parent.width

                    Repeater {
                        model: calendarPopup.root.calendarCells

                        delegate: Item {
                            id: dayCell

                            required property var modelData
                            required property int index
                            readonly property int dayOfWeek: index % 7
                            readonly property bool isWeekend: dayOfWeek >= 5
                            readonly property bool isCurrentMonth: modelData.day !== 0
                            readonly property bool isToday: modelData.today
                            readonly property bool isHoliday: modelData.holiday !== ""
                            readonly property bool isSelected: isCurrentMonth && calendarPopup.root.selectedDay === modelData.day
                            readonly property bool isHovered: dayMouse.containsMouse && isCurrentMonth
                            readonly property bool isEmphasized: isSelected && (isHovered || calendarPopup.keyboardNavigation)
                            readonly property color textColor: {
                                if (isToday)
                                    return calendarPopup.root.seal.hsvValue < 0.5 ? calendarPopup.root.ink : calendarPopup.root.paper;

                                if (!isCurrentMonth)
                                    return calendarPopup.root.inkDeep;

                                return (isWeekend || isHoliday) ? calendarPopup.root.seal : calendarPopup.root.ink;
                            }

                            width: parent.width / 7
                            height: 32

                            Rectangle {
                                anchors.centerIn: parent
                                width: dayCell.isEmphasized ? 40 : 36
                                height: dayCell.isEmphasized ? 30 : 28
                                radius: calendarPopup.root.cornerRadius
                                color: {
                                    if (dayCell.isToday && dayCell.isEmphasized)
                                        return Qt.lighter(calendarPopup.root.seal, 1.18);

                                    if (dayCell.isToday)
                                        return calendarPopup.root.seal;

                                    if (dayCell.isEmphasized)
                                        return Qt.rgba(calendarPopup.root.seal.r, calendarPopup.root.seal.g, calendarPopup.root.seal.b, 0.32);

                                    if (dayCell.isSelected)
                                        return Qt.rgba(calendarPopup.root.seal.r, calendarPopup.root.seal.g, calendarPopup.root.seal.b, 0.18);

                                    if (dayCell.isHovered)
                                        return Qt.rgba(calendarPopup.root.ink.r, calendarPopup.root.ink.g, calendarPopup.root.ink.b, 0.06);

                                    return "transparent";
                                }
                                border.color: dayCell.isSelected && !dayCell.isToday ? calendarPopup.root.seal : "transparent"
                                border.width: dayCell.isSelected && !dayCell.isToday ? 2 : 0
                                antialiasing: true

                                Behavior on color {
                                    ColorAnimation {
                                        duration: calendarPopup.animationDuration
                                        easing.type: calendarPopup.animationEasing
                                    }

                                }

                                Behavior on width {
                                    NumberAnimation {
                                        duration: calendarPopup.animationDuration
                                        easing.type: calendarPopup.animationEasing
                                    }

                                }

                                Behavior on height {
                                    NumberAnimation {
                                        duration: calendarPopup.animationDuration
                                        easing.type: calendarPopup.animationEasing
                                    }

                                }

                            }

                            Text {
                                anchors.centerIn: parent
                                text: dayCell.modelData.day === 0 ? "" : dayCell.modelData.day
                                color: dayCell.textColor
                                opacity: dayCell.isCurrentMonth ? 1 : 0.35
                                font.family: calendarPopup.root.mono
                                font.pixelSize: 13
                                font.weight: dayCell.isToday || dayCell.isSelected ? Font.Medium : Font.Light
                            }

                            Rectangle {
                                visible: dayCell.isHoliday && !dayCell.isToday
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 1
                                width: 3
                                height: 3
                                radius: 2
                                color: calendarPopup.root.seal
                            }

                            MouseArea {
                                id: dayMouse

                                anchors.fill: parent
                                hoverEnabled: dayCell.isCurrentMonth
                                enabled: dayCell.isCurrentMonth
                                cursorShape: dayCell.isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onEntered: calendarPopup.keyboardNavigation = false
                                onClicked: {
                                    calendarPopup.keyboardNavigation = false;
                                    calendarPopup.root.selectedDay = dayCell.modelData.day;
                                    calendarPopup.preferredDay = dayCell.modelData.day;
                                }
                            }

                        }

                    }

                }

            }

        }

        PopupFooter {
            root: calendarPopup.root
            text: "HJKL / ARROWS  ·  PGUP/DN MONTH  ·  HOME TODAY  ·  ESC"
        }

    }

}
