import QtQuick

CardWindow {
    id: calendarPopup

    required property var root
    property string shellScreenName: ""
    readonly property string wantedScreen: root.popupAnchorScreen || root.focusedScreenName()
    readonly property bool targetScreen: calendarPopup.wantedScreen.length === 0 || calendarPopup.shellScreenName.length === 0 || calendarPopup.wantedScreen === calendarPopup.shellScreenName

    theme: root
    revealed: root.calendarVisible && calendarPopup.targetScreen
    frameScreenName: calendarPopup.shellScreenName
    cardWidth: 322
    contentOpenDelayFactor: 1
    contentOpenDurationFactor: 1
    contentCloseDurationFactor: 0.6
    bodyPaddingBottom: 16
    bodyPaddingTop: 0
    bodyPaddingLeft: 8
    bodyPaddingRight: 8
    layerNamespace: "omarchy-calendar"
    frameAttached: true
    onDismiss: calendarPopup.root.calendarVisible = false
    onKeyPressed: function(event) {
        if (event.key === Qt.Key_Q) {
            calendarPopup.root.calendarVisible = false;
            event.accepted = true;
        }
    }

    Column {
        width: parent.width
        spacing: 12
        opacity: calendarPopup.contentReveal

        PopupHeader {
            root: calendarPopup.root
            title: calendarPopup.root.calendarMonthName
            subtitle: calendarPopup.root.calendarYear

            rightContent: Row {
                spacing: 12

                CalendarChevron {
                    root: calendarPopup.root
                    text: "‹"
                    hotColor: calendarPopup.root.seal
                    font.pixelSize: 24
                    onTriggered: {
                        calendarPopup.root.calendarMonthOffset--;
                        calendarPopup.root.calendarTick++;
                        calendarPopup.root.selectedDay = 0;
                    }
                }

                CalendarChevron {
                    root: calendarPopup.root
                    text: "•"
                    restColor: calendarPopup.root.inkDeep
                    hotColor: calendarPopup.root.seal
                    font.pixelSize: 19
                    font.letterSpacing: 0
                    onTriggered: {
                        calendarPopup.root.calendarMonthOffset = 0;
                        calendarPopup.root.calendarTick++;
                        calendarPopup.root.selectedDay = (new Date()).getDate();
                    }
                }

                CalendarChevron {
                    root: calendarPopup.root
                    text: "›"
                    hotColor: calendarPopup.root.seal
                    font.pixelSize: 24
                    onTriggered: {
                        calendarPopup.root.calendarMonthOffset++;
                        calendarPopup.root.calendarTick++;
                        calendarPopup.root.selectedDay = 0;
                    }
                }

            }

        }

        Rectangle {
            visible: false
            width: parent.width
            height: 1
            color: calendarPopup.root.sep
        }

        Row {
            width: parent.width
            spacing: 0

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
                        opacity: index >= 5 ? 0.85 : 0.7
                        font.family: calendarPopup.root.mono
                        font.pixelSize: 12
                        font.letterSpacing: 2
                    }

                }

            }

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
                    readonly property color textColor: {
                        if (isToday)
                            return calendarPopup.root.seal.hsvValue < 0.5 ? calendarPopup.root.ink : calendarPopup.root.paper;

                        if (!isCurrentMonth)
                            return calendarPopup.root.inkDeep;

                        return (isWeekend || isHoliday) ? calendarPopup.root.seal : calendarPopup.root.ink;
                    }

                    width: parent.width / 7
                    height: 34

                    Rectangle {
                        anchors.centerIn: parent
                        width: 29
                        height: 29
                        radius: 14
                        color: calendarPopup.root.seal
                        visible: dayCell.isToday
                        antialiasing: true
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 29
                        height: 29
                        radius: 14
                        color: Qt.rgba(calendarPopup.root.ink.r, calendarPopup.root.ink.g, calendarPopup.root.ink.b, 0.08)
                        visible: dayMouse.containsMouse && !dayCell.isToday && dayCell.isCurrentMonth
                        antialiasing: true

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                                easing.type: calendarPopup.animationEasing
                            }

                        }

                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 29
                        height: 29
                        radius: 14
                        color: "transparent"
                        border.color: calendarPopup.root.seal
                        border.width: 1
                        visible: dayCell.isSelected && !dayCell.isToday
                        antialiasing: true
                    }

                    Text {
                        anchors.centerIn: parent
                        text: dayCell.modelData.day === 0 ? "" : dayCell.modelData.day
                        color: dayCell.textColor
                        opacity: dayCell.isCurrentMonth ? 1 : 0.35
                        font.family: calendarPopup.root.mono
                        font.pixelSize: 15
                        font.weight: dayCell.isToday ? Font.Medium : Font.Light
                    }

                    MouseArea {
                        id: dayMouse

                        anchors.fill: parent
                        hoverEnabled: dayCell.isCurrentMonth
                        enabled: dayCell.isCurrentMonth
                        cursorShape: dayCell.isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: calendarPopup.root.selectedDay = dayCell.modelData.day
                    }

                }

            }

        }

        Rectangle {
            visible: false
            width: parent.width
            height: 1
            color: calendarPopup.root.sep
        }

        Item {
            width: parent.width
            height: selectedDetailText.implicitHeight
            visible: calendarPopup.root.selectedDay > 0

            Rectangle {
                visible: false
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: calendarPopup.root.sep
            }

            Text {
                id: selectedDetailText

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: undefined
                anchors.topMargin: 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 0
                anchors.rightMargin: 0
                text: calendarPopup.root.selectedDayDetail
                color: calendarPopup.root.ink
                elide: Text.ElideRight
                font.family: calendarPopup.root.mono
                font.pixelSize: 11
                font.letterSpacing: 2
                font.weight: Font.Normal
            }

        }

        Text {
            width: parent.width
            visible: calendarPopup.root.selectedDayHoliday.length > 0
            text: calendarPopup.root.selectedDayHoliday.toUpperCase()
            color: calendarPopup.root.seal
            font.family: calendarPopup.root.mono
            font.pixelSize: 11
            font.letterSpacing: 2
        }

        transform: Translate {
            y: (1 - calendarPopup.contentReveal) * -calendarPopup.contentTravel
        }

    }

}
