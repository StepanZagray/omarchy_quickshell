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
        const easter = root.easterDate(year);
        const cells = [];
        for (let i = 0; i < startDay; i++) cells.push({
            "day": 0,
            "today": false,
            "holiday": ""
        })
        for (let d = 1; d <= lastDay; d++) {
            cells.push({
                "day": d,
                "today": isCurrentMonth && d === today.getDate(),
                "holiday": root.norwegianHoliday(year, month, d, easter)
            });
        }
        while (cells.length < 42)cells.push({
            "day": 0,
            "today": false,
            "holiday": ""
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
        return days[d.getDay()] + " · " + root.selectedDay + " " + months[d.getMonth()] + " " + d.getFullYear();
    }
    readonly property string selectedDayHoliday: {
        if (root.selectedDay <= 0)
            return "";

        const cells = root.calendarCells;
        for (let i = 0; i < cells.length; i++) {
            if (cells[i].day === root.selectedDay)
                return cells[i].holiday;

        }
        return "";
    }

    function easterDate(year) {
        const a = year % 19;
        const b = Math.floor(year / 100);
        const c = year % 100;
        const d = Math.floor(b / 4);
        const e = b % 4;
        const f = Math.floor((b + 8) / 25);
        const g = Math.floor((b - f + 1) / 3);
        const h = (19 * a + b - d - g + 15) % 30;
        const i = Math.floor(c / 4);
        const k = c % 4;
        const l = (32 + 2 * e + 2 * i - h - k) % 7;
        const mm = Math.floor((a + 11 * h + 22 * l) / 451);
        const month = Math.floor((h + l - 7 * mm + 114) / 31);
        const day = ((h + l - 7 * mm + 114) % 31) + 1;
        return new Date(year, month - 1, day);
    }

    function norwegianHoliday(year, month, day, easter) {
        if (month === 0 && day === 1)
            return "Nyttårsdag";

        if (month === 4 && day === 1)
            return "Arbeidernes dag";

        if (month === 4 && day === 17)
            return "Grunnlovsdagen";

        if (month === 11 && day === 25)
            return "Første juledag";

        if (month === 11 && day === 26)
            return "Andre juledag";

        const target = new Date(year, month, day);
        const offset = Math.round((target.getTime() - easter.getTime()) / 8.64e+07);
        if (offset === -3)
            return "Skjærtorsdag";

        if (offset === -2)
            return "Langfredag";

        if (offset === 0)
            return "Første påskedag";

        if (offset === 1)
            return "Andre påskedag";

        if (offset === 39)
            return "Kristi himmelfartsdag";

        if (offset === 49)
            return "Første pinsedag";

        if (offset === 50)
            return "Andre pinsedag";

        return "";
    }

    function openCalendar() {
        if (shell.calendarAnchorItem)
            shell.anchorPopupTo(shell.calendarAnchorItem);

        if (!shell.popupAnchorScreen)
            shell.popupAnchorScreen = shell.focusedScreenName();

        shell.frameWidgetScreen = shell.popupAnchorScreen;
        root.calendarMonthOffset = 0;
        root.calendarTick++;
        root.selectedDay = (new Date()).getDate();
        root.calendarVisible = true;
    }

}
