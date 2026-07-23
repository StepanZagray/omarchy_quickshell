import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services" as Services
import "shell" as Shell
import "state" as State

// Desktop shell facade. The taskbar lives in bar/Bar.qml; this file owns
// shared state, popups, OSD, and layer wiring. Bars and popups bind to `root.*`.
Item {
    id: root

    required property var theme
    readonly property color paper: theme.paper
    readonly property color ink: theme.ink
    readonly property color inkDeep: theme.inkDeep
    readonly property color sumi: theme.inkDeep
    readonly property color indigo: theme.indigo
    readonly property color green: theme.green
    readonly property color seal: theme.seal
    readonly property color bg: theme.bg
    readonly property color fg: theme.fg
    readonly property color muted: theme.muted
    readonly property color accent: theme.accent
    readonly property color warn: theme.warn
    readonly property color sep: theme.sep
    readonly property string serif: theme.serif
    readonly property string mono: theme.mono
    readonly property int cornerRadius: theme.cornerRadius
    readonly property bool round: theme.round
    readonly property int animationDuration: theme.animationDuration
    // Native system menu visibility. The actions themselves continue to use
    // Omarchy's system commands so only the presentation layer lives here.
    property bool powerMenuVisible: false
    readonly property var notificationModel: notificationService.notifications
    readonly property int notificationCount: notificationService.notifications.values.length
    readonly property bool notificationsSilent: notificationService.silent
    readonly property string icoOmarchy: String.fromCodePoint(59648)
    readonly property string icoBtOn: String.fromCodePoint(62100)
    readonly property string icoVol1: String.fromCodePoint(61478)
    readonly property string icoVol2: String.fromCodePoint(61479)
    readonly property string icoVol3: String.fromCodePoint(61480)
    readonly property string icoMute: String.fromCodePoint(61160)
    readonly property string icoCamera: String.fromCodePoint(983296)
    readonly property string icoRefresh: String.fromCodePoint(984144)
    readonly property string icoDisplay: String.fromCodePoint(983929)
    readonly property string icoSun: String.fromCodePoint(984473)
    readonly property string icoPower: String.fromCodePoint(984101)
    readonly property string icoAether: String.fromCodePoint(984024)
    readonly property string icoFilm: String.fromCodePoint(983601)
    readonly property string icoSearch: String.fromCodePoint(983881)
    readonly property string icoUpdate: String.fromCodePoint(61473)
    readonly property string icoPlug: String.fromCodePoint(984741)
    readonly property string icoMusic: String.fromCodePoint(61441)
    readonly property string icoPlay: String.fromCodePoint(61515)
    readonly property string icoPause: String.fromCodePoint(61516)
    readonly property string icoCaps: String.fromCodePoint(983822)
    readonly property string icoLanguage: String.fromCodePoint(984522)
    readonly property string icoMic: String.fromCodePoint(61744)
    readonly property string icoMicMute: String.fromCodePoint(61745)
    readonly property string icoTouchpad: String.fromCodePoint(983833)
    readonly property string icoTouchpadOff: String.fromCodePoint(983832)
    readonly property string icoKbd: String.fromCodePoint(61724)
    // Bar thickness and the matching frame cutout on the bar edge. Keep these
    // in sync — Bar.exclusiveZone and FrameBorder bar-side cuts both read this.
    readonly property int barHeight: 28
    readonly property int barInset: barHeight
    readonly property alias frameThickness: chrome.frameThickness
    readonly property alias frameRounding: chrome.frameRounding
    readonly property alias frameBg: chrome.frameBg
    readonly property alias frameAnimationDuration: chrome.frameAnimationDuration
    property alias frameWidgetVisible: chrome.frameWidgetVisible
    property alias frameWidgetOwner: chrome.frameWidgetOwner
    property alias frameWidgetX: chrome.frameWidgetX
    property alias frameWidgetY: chrome.frameWidgetY
    property alias frameWidgetWidth: chrome.frameWidgetWidth
    property alias frameWidgetHeight: chrome.frameWidgetHeight
    property alias frameWidgetAttachRight: chrome.frameWidgetAttachRight
    property alias frameWidgetAttachLeft: chrome.frameWidgetAttachLeft
    property alias frameWidgetAttachBottom: chrome.frameWidgetAttachBottom
    property alias frameWidgetScreen: chrome.frameWidgetScreen
    property alias tooltipText: chrome.tooltipText
    property alias tooltipBarX: chrome.tooltipBarX
    property alias tooltipBarY: chrome.tooltipBarY
    property alias tooltipShown: chrome.tooltipShown
    property alias popupAnchorX: chrome.popupAnchorX
    property alias popupAnchorY: chrome.popupAnchorY
    property alias popupAnchorScreen: chrome.popupAnchorScreen
    readonly property alias focusedMonitorName: chrome.focusedMonitorName
    property alias calendarAnchorItem: chrome.calendarAnchorItem
    property alias mediaAnchorItem: chrome.mediaAnchorItem
    property alias displayAnchorItem: chrome.displayAnchorItem
    property alias systemAnchorItem: chrome.systemAnchorItem
    property alias activeWs: workspaces.activeWs
    property alias existingWs: workspaces.existingWs
    property alias lastDirection: workspaces.lastDirection
    property alias batVal: power.batVal
    property alias batState: power.batState
    property alias batPower: power.batPower
    property alias hh: power.hh
    property alias mm: power.mm
    property alias dd: power.dd
    property alias mon: power.mon
    property alias powerProfile: power.powerProfile
    property alias powerProfiles: power.powerProfiles
    property alias cpuVal: systemState.cpuVal
    property alias memVal: systemState.memVal
    property alias systemVisible: systemState.systemVisible
    property alias omarchyUpdateAvailable: systemState.omarchyUpdateAvailable
    property alias omarchyLatestTag: systemState.omarchyLatestTag
    property alias netIcon: connectivity.netIcon
    property alias netKind: connectivity.netKind
    property alias wifiSsid: connectivity.wifiSsid
    property alias wifiSignal: connectivity.wifiSignal
    property alias wifiNetworks: connectivity.wifiNetworks
    property alias wifiRadioOn: connectivity.wifiRadioOn
    property alias wifiScanning: connectivity.wifiScanning
    property alias btIcon: connectivity.btIcon
    property alias btPowered: connectivity.btPowered
    property alias btCount: connectivity.btCount
    property alias btDevices: connectivity.btDevices
    property alias btScanning: connectivity.btScanning
    property alias netPrevBytes: connectivity.netPrevBytes
    property alias burstArmed: connectivity.burstArmed
    property alias audioIcon: audio.audioIcon
    property alias audioVol: audio.audioVol
    property alias audioMuted: audio.audioMuted
    property alias audioSinks: audio.audioSinks
    property alias audioDefaultSink: audio.audioDefaultSink
    property alias layoutLabel: input.layoutLabel
    property alias layoutKeymap: input.layoutKeymap
    property alias layoutCodes: input.layoutCodes
    property alias layoutCount: input.layoutCount
    readonly property alias layoutTooltip: input.layoutTooltip
    property alias displayVisible: display.displayVisible
    property alias warmthK: display.warmthK
    property alias brightnessPct: display.brightnessPct
    property alias gammaPct: display.gammaPct
    property alias monitorName: display.monitorName
    property alias monitorRes: display.monitorRes
    property alias monitorRate: display.monitorRate
    property alias monitorScale: display.monitorScale
    readonly property alias displayPresets: display.displayPresets
    property alias selectedPreset: display.selectedPreset
    property alias displayRow: display.displayRow
    property alias sunsetReady: display.sunsetReady
    readonly property alias ensureSunset: display.ensureSunset
    property alias mediaVisible: media.mediaVisible
    property alias musicPlayer: media.musicPlayer
    property alias musicTitle: media.musicTitle
    property alias musicArtist: media.musicArtist
    property alias musicArtUrl: media.musicArtUrl
    property alias musicPlaying: media.musicPlaying
    property alias screenshotsVisible: capture.screenshotsVisible
    property alias screenshotPage: capture.screenshotPage
    readonly property alias screenshotsPerPage: capture.screenshotsPerPage
    property alias screenshotFiles: capture.screenshotFiles
    property alias selectedScreenshot: capture.selectedScreenshot
    readonly property alias visibleScreenshots: capture.visibleScreenshots
    readonly property alias selectedScreenshotEntry: capture.selectedScreenshotEntry
    readonly property alias screenshotPageCount: capture.screenshotPageCount
    property alias copiedPath: capture.copiedPath
    property alias videosVisible: capture.videosVisible
    property alias videoPage: capture.videoPage
    readonly property alias videosPerPage: capture.videosPerPage
    property alias videoFiles: capture.videoFiles
    property alias selectedVideo: capture.selectedVideo
    readonly property alias visibleVideos: capture.visibleVideos
    readonly property alias selectedVideoEntry: capture.selectedVideoEntry
    readonly property alias videoPageCount: capture.videoPageCount
    property alias copiedVideo: capture.copiedVideo
    property alias copiedVideoMode: capture.copiedVideoMode
    property alias aetherVisible: aether.aetherVisible
    property alias aetherBlueprints: aether.aetherBlueprints
    property alias selectedAether: aether.selectedAether
    property alias aetherLoading: aether.aetherLoading
    property alias aetherQuery: aether.aetherQuery
    readonly property alias aetherFiltered: aether.aetherFiltered
    property alias calendarVisible: calendar.calendarVisible
    property alias calendarMonthOffset: calendar.calendarMonthOffset
    property alias calendarTick: calendar.calendarTick
    property alias selectedDay: calendar.selectedDay
    readonly property alias calendarCells: calendar.calendarCells
    readonly property alias calendarMonthName: calendar.calendarMonthName
    readonly property alias calendarYear: calendar.calendarYear
    readonly property alias selectedDayDetail: calendar.selectedDayDetail
    readonly property alias selectedDayHoliday: calendar.selectedDayHoliday
    readonly property alias weatherLocationPath: weather.weatherLocationPath
    property alias weatherLocation: weather.weatherLocation
    property alias weatherLoaded: weather.weatherLoaded
    property alias weatherUnavailable: weather.weatherUnavailable
    property alias weatherPlace: weather.weatherPlace
    property alias weatherTempC: weather.weatherTempC
    property alias weatherFeelsC: weather.weatherFeelsC
    property alias weatherWindKmh: weather.weatherWindKmh
    property alias weatherWindDir: weather.weatherWindDir
    property alias weatherHumidity: weather.weatherHumidity
    property alias weatherUv: weather.weatherUv
    property alias weatherDesc: weather.weatherDesc
    property alias weatherCode: weather.weatherCode
    property alias weatherSunrise: weather.weatherSunrise
    property alias weatherSunset: weather.weatherSunset
    property alias weatherHighC: weather.weatherHighC
    property alias weatherLowC: weather.weatherLowC
    property alias weatherForecast: weather.weatherForecast
    property alias weatherUpdatedAt: weather.weatherUpdatedAt
    readonly property alias weatherIsNight: weather.weatherIsNight
    readonly property alias weatherIcon: weather.weatherIcon
    readonly property alias weatherUrl: weather.weatherUrl
    readonly property bool isIdle: idleMonitor.isIdle

    signal paletteToggleRequested()
    signal popupOpening()
    signal netBurst()

    // One user-invoked popup at a time. OSD, notifications, and tooltips are
    // transient overlays rather than interactive popups, so they are excluded.
    function closePopupsExcept(keep) {
        if (keep !== "calendar")
            calendarVisible = false;

        if (keep !== "media")
            mediaVisible = false;

        if (keep !== "power")
            powerMenuVisible = false;

        if (keep !== "system")
            systemVisible = false;

        if (keep !== "screenshots")
            screenshotsVisible = false;

        if (keep !== "videos")
            videosVisible = false;

        if (keep !== "display")
            displayVisible = false;

        if (keep !== "aether")
            aetherVisible = false;

    }

    function closeAllPopups() {
        closePopupsExcept("");
    }

    function preparePopup(kind) {
        closePopupsExcept(kind);
        popupOpening();
    }

    function openPowerMenu() {
        preparePopup("power");
        // Always pin to the focused monitor — power opens via IPC/keybind, not
        // a bar click, so a leftover popupAnchorScreen from calendar/media would
        // otherwise keep it on the wrong display.
        const screen = focusedScreenName();
        popupAnchorScreen = screen;
        frameWidgetScreen = screen;
        powerMenuVisible = true;
    }

    function togglePowerMenu() {
        if (powerMenuVisible)
            powerMenuVisible = false;
        else
            openPowerMenu();
    }

    function workspaceLabel(n) {
        return String(n);
    }

    function dismissLastNotification() {
        notificationService.dismissLast();
    }

    function dismissAllNotifications() {
        notificationService.dismissAll();
    }

    function invokeLastNotification() {
        notificationService.invokeLast();
    }

    function restoreLastNotification() {
        notificationService.restoreLast();
    }

    function toggleNotificationSilence() {
        notificationService.toggleSilent();
    }

    function invokeNotification(notification) {
        notificationService.invoke(notification);
    }

    function showTooltip(text, x, y) {
        chrome.showTooltip(text, x, y);
    }

    function hideTooltip(text) {
        chrome.hideTooltip(text);
    }

    function focusedScreenName() {
        return chrome.focusedScreenName();
    }

    function anchorPopupTo(item) {
        chrome.anchorPopupTo(item);
    }

    function setPowerProfile(name) {
        power.setPowerProfile(name);
    }

    function refreshPowerProfile() {
        power.refreshPowerProfile();
    }

    function batteryIcon() {
        return power.batteryIcon();
    }

    function openSystem() {
        preparePopup("system");
        systemState.openSystem();
    }

    function refreshSystemStats() {
        systemState.refreshSystemStats();
    }

    function openOmarchyUpdate() {
        systemState.openOmarchyUpdate();
    }

    function refreshOmarchyUpdateCheck() {
        systemState.refreshOmarchyUpdateCheck();
    }

    function refreshWifi() {
        connectivity.refreshWifi();
    }

    function connectWifi(ssid) {
        connectivity.connectWifi(ssid);
    }

    function disconnectWifi() {
        connectivity.disconnectWifi();
    }

    function toggleWifiRadio() {
        connectivity.toggleWifiRadio();
    }

    function refreshBluetooth() {
        connectivity.refreshBluetooth();
    }

    function btConnect(mac) {
        connectivity.btConnect(mac);
    }

    function btDisconnect(mac) {
        connectivity.btDisconnect(mac);
    }

    function btTogglePower() {
        connectivity.btTogglePower();
    }

    function btToggleScan() {
        connectivity.btToggleScan();
    }

    function wifiBarsGlyph(pct) {
        return connectivity.wifiBarsGlyph(pct);
    }

    function setDefaultSink(id) {
        audio.setDefaultSink(id);
    }

    function refreshAudioSinks() {
        audio.refreshAudioSinks();
    }

    function setVolume(pct) {
        audio.setVolume(pct);
    }

    function toggleMute() {
        audio.toggleMute();
    }

    function cycleLayout() {
        input.cycleLayout();
    }

    function openDisplay() {
        preparePopup("display");
        display.openDisplay();
    }

    function runSunset(verb) {
        display.runSunset(verb);
    }

    function setWarmth(k) {
        display.setWarmth(k);
    }

    function setBrightness(pct) {
        display.setBrightness(pct);
    }

    function setGamma(pct) {
        display.setGamma(pct);
    }

    function applyPreset(p) {
        display.applyPreset(p);
    }

    function blankScreen() {
        display.blankScreen();
    }

    function resetDisplay() {
        display.resetDisplay();
    }

    function openMedia(screenName) {
        preparePopup("media");
        media.openMedia(screenName);
    }

    function refreshMusic() {
        media.refreshMusic();
    }

    function musicToggle() {
        media.musicToggle();
    }

    function musicNext() {
        media.musicNext();
    }

    function musicPrev() {
        media.musicPrev();
    }

    function openScreenshots() {
        preparePopup("screenshots");
        capture.openScreenshots();
    }

    function refreshScreenshots() {
        capture.refreshScreenshots();
    }

    function moveScreenshotSelection(delta) {
        capture.moveScreenshotSelection(delta);
    }

    function moveScreenshotRow(delta) {
        capture.moveScreenshotRow(delta);
    }

    function pageScreenshots(delta) {
        capture.pageScreenshots(delta);
    }

    function formatScreenshotLabel(path) {
        return capture.formatScreenshotLabel(path);
    }

    function copyScreenshotToClipboard(path) {
        capture.copyScreenshotToClipboard(path);
    }

    function openVideos() {
        preparePopup("videos");
        capture.openVideos();
    }

    function refreshVideos() {
        capture.refreshVideos();
    }

    function moveVideoSelection(delta) {
        capture.moveVideoSelection(delta);
    }

    function moveVideoRow(delta) {
        capture.moveVideoRow(delta);
    }

    function pageVideos(delta) {
        capture.pageVideos(delta);
    }

    function formatVideoLabel(path) {
        return capture.formatVideoLabel(path);
    }

    function formatVideoDuration(secs) {
        return capture.formatVideoDuration(secs);
    }

    function formatVideoSize(bytes) {
        return capture.formatVideoSize(bytes);
    }

    function formatVideoMtime(secs) {
        return capture.formatVideoMtime(secs);
    }

    function copyVideoUri(path) {
        capture.copyVideoUri(path);
    }

    function copyVideoBytes(path) {
        capture.copyVideoBytes(path);
    }

    function openAether() {
        preparePopup("aether");
        aether.openAether();
    }

    function refreshAetherBlueprints() {
        aether.refreshAetherBlueprints();
    }

    function moveAetherSelection(delta, wrap) {
        aether.moveAetherSelection(delta, wrap);
    }

    function applyAetherBlueprint(name) {
        aether.applyAetherBlueprint(name);
    }

    function easterDate(year) {
        return calendar.easterDate(year);
    }

    function norwegianHoliday(year, month, day, easter) {
        return calendar.norwegianHoliday(year, month, day, easter);
    }

    function openCalendar(screenName) {
        preparePopup("calendar");
        calendar.openCalendar(screenName);
    }

    function weatherGlyph(code, night) {
        return weather.weatherGlyph(code, night);
    }

    function parseClock(s) {
        return weather.parseClock(s);
    }

    function fmtTemp(c) {
        return weather.fmtTemp(c);
    }

    function refreshWeather() {
        weather.refreshWeather();
    }

    function run(cmd) {
        console.log("[RUN-DIAG] " + cmd);
        runner.command = ["bash", "-lc", cmd];
        runner.running = false;
        runner.running = true;
    }

    // ---------- Notifications ----------
    Services.NotificationService {
        id: notificationService
    }

    // ---------- Placement / chrome ----------
    State.ChromeState {
        id: chrome

        shell: root
    }

    // ---------- Workspace state ----------
    State.WorkspaceState {
        id: workspaces
    }

    // ---------- Telemetry / system ----------
    State.PowerState {
        id: power

        shell: root
    }

    State.SystemState {
        id: systemState

        shell: root
    }

    // ---------- Connectivity ----------
    State.ConnectivityState {
        id: connectivity

        shell: root
    }

    // ---------- Audio ----------
    State.AudioState {
        id: audio

        shell: root
    }

    // ---------- OSD (volume / brightness toasts; see popups/OsdPopup.qml) ----------
    State.OsdState {
        id: osd

        shell: root
    }

    // ---------- Input / keyboard layout ----------
    State.InputState {
        id: input

        shell: root
    }

    // ---------- Display ----------
    State.DisplayState {
        id: display

        shell: root
    }

    // ---------- Media ----------
    State.MediaState {
        id: media

        shell: root
    }

    // ---------- Screenshots / videos ----------
    State.CaptureState {
        id: capture
    }

    // ---------- Aether ----------
    State.AetherState {
        id: aether

        shell: root
    }

    // ---------- Calendar ----------
    State.CalendarState {
        id: calendar

        shell: root
    }

    // ---------- Weather ----------
    State.WeatherState {
        id: weather

        shell: root
    }

    // ---------- Idle dim ----------
    IdleMonitor {
        id: idleMonitor

        enabled: true
        timeout: 60
        respectInhibitors: true
    }

    // ---------- Generic launcher ----------
    Process {
        id: runner

        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text) {
                    console.log("[RUN-DIAG stderr] " + this.text);
                }
            }
        }

    }

    Shell.DesktopSurfaces {
        shell: root
        osd: osd
    }

    Shell.DesktopIpc {
        shell: root
        osd: osd
    }

}
