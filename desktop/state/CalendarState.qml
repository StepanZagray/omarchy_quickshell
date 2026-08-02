import QtQuick

Item {
    id: root

    required property var shell
    property bool calendarVisible: false
    property int calendarMonthOffset: 0
    property int calendarTick: 0
    property int selectedDay: 0
    readonly property var calendarCells: {
        root.calendarTick;
        const now = new Date();
        const first = new Date(now.getFullYear(), now.getMonth() + root.calendarMonthOffset, 1);
        const year = first.getFullYear();
        const month = first.getMonth();
        const lastDay = new Date(year, month + 1, 0).getDate();
        const startDay = (first.getDay() + 6) % 7;
        const today = new Date();
        const isCurrentMonth = year === today.getFullYear() && month === today.getMonth();
        const cells = [];
        for (let i = 0; i < startDay; i++) cells.push({
            "day": 0,
            "today": false
        })
        for (let d = 1; d <= lastDay; d++) {
            cells.push({
                "day": d,
                "today": isCurrentMonth && d === today.getDate()
            });
        }
        while (cells.length < 42)cells.push({
            "day": 0,
            "today": false
        })
        return cells;
    }
    readonly property string calendarMonthName: {
        const months = ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"];
        const now = new Date();
        return months[(now.getMonth() + root.calendarMonthOffset + 12000) % 12];
    }
    readonly property string calendarYear: {
        const now = new Date();
        const d = new Date(now.getFullYear(), now.getMonth() + root.calendarMonthOffset, 1);
        return String(d.getFullYear());
    }
    readonly property string selectedDayDetail: {
        if (root.selectedDay <= 0)
            return "";

        const days = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"];
        const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
        const now = new Date();
        const d = new Date(now.getFullYear(), now.getMonth() + root.calendarMonthOffset, root.selectedDay);
        return root.selectedDay + " " + months[d.getMonth()] + " " + d.getFullYear();
    }

    function openCalendar(screenName) {
        if (shell.calendarAnchorItem)
            shell.anchorPopupTo(shell.calendarAnchorItem);

        // Prefer an explicit screen (bar click on that monitor); otherwise the
        // focused monitor. Never reuse a stale popupAnchorScreen from another
        // widget / earlier open.
        const screen = (screenName && screenName.length > 0) ? screenName : shell.focusedScreenName();
        shell.popupAnchorScreen = screen;
        shell.frameWidgetScreen = screen;
        root.calendarMonthOffset = 0;
        root.calendarTick++;
        root.selectedDay = (new Date()).getDate();
        root.calendarVisible = true;
    }

}
