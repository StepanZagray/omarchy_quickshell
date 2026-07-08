import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var shell
    readonly property string weatherLocationPath: Quickshell.env("HOME") + "/.config/omarchy/weather/location"
    property string weatherLocation: ""
    property bool weatherLoaded: false
    property bool weatherUnavailable: false
    property string weatherPlace: ""
    property real weatherTempC: 0
    property real weatherFeelsC: 0
    property int weatherWindKmh: 0
    property string weatherWindDir: ""
    property int weatherHumidity: 0
    property int weatherUv: 0
    property string weatherDesc: ""
    property int weatherCode: 0
    property string weatherSunrise: ""
    property string weatherSunset: ""
    property real weatherHighC: 0
    property real weatherLowC: 0
    property var weatherForecast: []
    property string weatherUpdatedAt: ""
    readonly property bool weatherIsNight: {
        shell.mm;
        const sr = root.parseClock(root.weatherSunrise);
        const ss = root.parseClock(root.weatherSunset);
        if (sr < 0 || ss < 0)
            return false;

        const now = new Date();
        const cur = now.getHours() * 60 + now.getMinutes();
        return cur < sr || cur >= ss;
    }
    readonly property string weatherIcon: root.weatherLoaded ? root.weatherGlyph(root.weatherCode, root.weatherIsNight) : ""
    readonly property string weatherUrl: {
        const loc = root.weatherLocation;
        return "https://wttr.in/" + (loc ? encodeURIComponent(loc) : "") + "?format=j1";
    }

    function weatherGlyph(code, night) {
        const n = parseInt(code) || 0;
        if (n === 113)
            return String.fromCodePoint(night ? 58155 : 58125);

        if (n === 116)
            return String.fromCodePoint(night ? 58158 : 58114);

        if (n === 119 || n === 122)
            return String.fromCodePoint(58173);

        if (n === 143 || n === 248 || n === 260)
            return String.fromCodePoint(58131);

        if (n === 176 || n === 263 || n === 353)
            return String.fromCodePoint(night ? 58163 : 58120);

        if ([179, 227, 230, 323, 326, 368].indexOf(n) !== -1)
            return String.fromCodePoint(night ? 58151 : 58122);

        if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].indexOf(n) !== -1)
            return String.fromCodePoint(58285);

        if ([200, 386, 389, 392, 395].indexOf(n) !== -1)
            return String.fromCodePoint(58141);

        if ([266, 293, 296, 299, 302, 305, 308, 356, 359].indexOf(n) !== -1)
            return String.fromCodePoint(58136);

        if ([329, 332, 335, 338, 371].indexOf(n) !== -1)
            return String.fromCodePoint(58138);

        return String.fromCodePoint(58173);
    }

    function parseClock(s) {
        const m = String(s).match(/^(\d{1,2}):(\d{2})\s*(AM|PM)?\s*$/i);
        if (!m)
            return -1;

        let h = parseInt(m[1]);
        const min = parseInt(m[2]);
        if (m[3]) {
            const pm = m[3].toUpperCase() === "PM";
            if (h === 12)
                h = pm ? 12 : 0;
            else if (pm)
                h += 12;
        }
        return h * 60 + min;
    }

    function fmtTemp(c) {
        const v = Math.round(c);
        return (v > 0 ? "+" : "") + v + "°";
    }

    function refreshWeather() {
        weatherProbe.running = false;
        weatherProbe.running = true;
    }

    FileView {
        id: weatherLocFile

        path: root.weatherLocationPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.weatherLocation = weatherLocFile.text().trim();
            weatherProbe.running = false;
            weatherProbe.running = true;
        }
    }

    Process {
        id: weatherProbe

        running: false
        command: ["bash", "-lc", "URL=" + JSON.stringify(root.weatherUrl) + ";" + " j=$(curl -fsS --max-time 5 \"$URL\" 2>/dev/null);" + " if [ -z \"$j\" ]; then printf 'ERR'; exit 0; fi;" + " data=$(printf '%s' \"$j\" | jq -r '" + "  .current_condition[0] as $c" + "  | .weather as $w" + "  | .nearest_area[0] as $a" + "  | [$a.areaName[0].value, $c.temp_C, $c.FeelsLikeC," + "     $c.windspeedKmph, $c.winddir16Point, $c.humidity, $c.uvIndex," + "     $c.weatherDesc[0].value, $c.weatherCode," + "     $w[0].astronomy[0].sunrise, $w[0].astronomy[0].sunset," + "     $w[0].maxtempC, $w[0].mintempC," + "     $w[1].date, $w[1].maxtempC, $w[1].mintempC, $w[1].hourly[4].weatherCode," + "     $w[2].date, $w[2].maxtempC, $w[2].mintempC, $w[2].hourly[4].weatherCode]" + "  | map(tostring) | join(\"|\")');" + " printf 'OK|%s' \"$data\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const txt = this.text.trim();
                if (!txt.startsWith("OK|")) {
                    root.weatherUnavailable = true;
                    return;
                }
                const p = txt.substring(3).split("|");
                if (p.length < 21) {
                    root.weatherUnavailable = true;
                    return;
                }
                root.weatherPlace = p[0];
                root.weatherTempC = parseFloat(p[1]);
                root.weatherFeelsC = parseFloat(p[2]);
                root.weatherWindKmh = parseInt(p[3]);
                root.weatherWindDir = p[4];
                root.weatherHumidity = parseInt(p[5]);
                root.weatherUv = parseInt(p[6]);
                root.weatherDesc = p[7];
                root.weatherCode = parseInt(p[8]);
                root.weatherSunrise = p[9];
                root.weatherSunset = p[10];
                root.weatherHighC = parseFloat(p[11]);
                root.weatherLowC = parseFloat(p[12]);
                const days = [];
                for (let i = 0; i < 2; i++) {
                    const off = 13 + i * 4;
                    days.push({
                        "day": Qt.formatDate(new Date(p[off]), "ddd").toUpperCase(),
                        "high": parseFloat(p[off + 1]),
                        "low": parseFloat(p[off + 2]),
                        "code": parseInt(p[off + 3])
                    });
                }
                root.weatherForecast = days;
                const now = new Date();
                root.weatherUpdatedAt = String(now.getHours()).padStart(2, "0") + ":" + String(now.getMinutes()).padStart(2, "0");
                root.weatherLoaded = true;
                root.weatherUnavailable = false;
            }
        }

    }

    Timer {
        interval: 1.8e+06
        running: true
        repeat: true
        onTriggered: root.refreshWeather()
    }

}
