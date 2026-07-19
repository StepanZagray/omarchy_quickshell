import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "state" as State
import "shell" as Shell
import "services" as Services

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

    signal paletteToggleRequested()
    signal netBurst()

    // Native system menu visibility. The actions themselves continue to use
    // Omarchy's system commands so only the presentation layer lives here.
    property bool powerMenuVisible: false
    function openPowerMenu() { powerMenuVisible = true; }
    function togglePowerMenu() { powerMenuVisible = !powerMenuVisible; }

    function workspaceLabel(n) { return String(n); }

    // ---------- Notifications ----------
    Services.NotificationService { id: notificationService }

    readonly property var notificationModel: notificationService.notifications
    readonly property int notificationCount: notificationService.notifications.values.length
    readonly property bool notificationsSilent: notificationService.silent
    function dismissLastNotification() { notificationService.dismissLast(); }
    function dismissAllNotifications() { notificationService.dismissAll(); }
    function invokeLastNotification() { notificationService.invokeLast(); }
    function restoreLastNotification() { notificationService.restoreLast(); }
    function toggleNotificationSilence() { notificationService.toggleSilent(); }
    function invokeNotification(notification) { notificationService.invoke(notification); }

    readonly property string icoOmarchy: String.fromCodePoint(0xe900)
    readonly property string icoBtOn: String.fromCodePoint(0xf294)
    readonly property string icoVol1: String.fromCodePoint(0xf026)
    readonly property string icoVol2: String.fromCodePoint(0xf027)
    readonly property string icoVol3: String.fromCodePoint(0xf028)
    readonly property string icoMute: String.fromCodePoint(0xeee8)
    readonly property string icoCamera: String.fromCodePoint(0xf0100)
    readonly property string icoRefresh: String.fromCodePoint(0xf0450)
    readonly property string icoDisplay: String.fromCodePoint(0xf0379)
    readonly property string icoSun: String.fromCodePoint(0xf0599)
    readonly property string icoPower: String.fromCodePoint(0xf0425)
    readonly property string icoAether: String.fromCodePoint(0xf03d8)
    readonly property string icoFilm: String.fromCodePoint(0xf0231)
    readonly property string icoSearch: String.fromCodePoint(0xf0349)
    readonly property string icoUpdate: String.fromCodePoint(0xf021)
    readonly property string icoPlug: String.fromCodePoint(0xf06a5)
    readonly property string icoMusic: String.fromCodePoint(0xf001)
    readonly property string icoPlay: String.fromCodePoint(0xf04b)
    readonly property string icoPause: String.fromCodePoint(0xf04c)
    readonly property string icoCaps: String.fromCodePoint(0xf030e)
    readonly property string icoLanguage: String.fromCodePoint(0xf05ca)
    readonly property string icoMic: String.fromCodePoint(0xf130)
    readonly property string icoMicMute: String.fromCodePoint(0xf131)
    readonly property string icoTouchpad: String.fromCodePoint(0xf0319)
    readonly property string icoTouchpadOff: String.fromCodePoint(0xf0318)
    readonly property string icoKbd: String.fromCodePoint(0xf11c)

    // Bar thickness and the matching frame cutout on the bar edge. Keep these
    // in sync — Bar.exclusiveZone and FrameBorder bar-side cuts both read this.
    readonly property int barHeight: 28
    readonly property int barInset: barHeight

    // ---------- Placement / chrome ----------
    State.ChromeState { id: chrome; shell: root }

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
    property alias frameWidgetScreen: chrome.frameWidgetScreen

    property alias tooltipText: chrome.tooltipText
    property alias tooltipBarX: chrome.tooltipBarX
    property alias tooltipBarY: chrome.tooltipBarY
    property alias tooltipShown: chrome.tooltipShown
    function showTooltip(text, x, y) { chrome.showTooltip(text, x, y); }
    function hideTooltip(text) { chrome.hideTooltip(text); }

    property alias popupAnchorX: chrome.popupAnchorX
    property alias popupAnchorY: chrome.popupAnchorY
    property alias popupAnchorScreen: chrome.popupAnchorScreen
    readonly property alias focusedMonitorName: chrome.focusedMonitorName
    property alias calendarAnchorItem: chrome.calendarAnchorItem
    property alias mediaAnchorItem: chrome.mediaAnchorItem
    property alias displayAnchorItem: chrome.displayAnchorItem
    property alias systemAnchorItem: chrome.systemAnchorItem
    function focusedScreenName() { return chrome.focusedScreenName(); }
    function anchorPopupTo(item) { chrome.anchorPopupTo(item); }

    // ---------- Workspace state ----------
    State.WorkspaceState { id: workspaces }

    property alias activeWs: workspaces.activeWs
    property alias existingWs: workspaces.existingWs
    property alias lastDirection: workspaces.lastDirection

    // ---------- Telemetry / system ----------
    State.PowerState { id: power; shell: root }
    State.SystemState { id: systemState; shell: root }

    property alias batVal: power.batVal
    property alias batState: power.batState
    property alias batPower: power.batPower
    property alias hh: power.hh
    property alias mm: power.mm
    property alias dd: power.dd
    property alias mon: power.mon
    property alias powerProfile: power.powerProfile
    property alias powerProfiles: power.powerProfiles
    function setPowerProfile(name) { power.setPowerProfile(name); }
    function refreshPowerProfile() { power.refreshPowerProfile(); }
    function batteryIcon() { return power.batteryIcon(); }

    property alias cpuVal: systemState.cpuVal
    property alias memVal: systemState.memVal
    property alias systemVisible: systemState.systemVisible
    property alias omarchyUpdateAvailable: systemState.omarchyUpdateAvailable
    property alias omarchyLatestTag: systemState.omarchyLatestTag
    function openSystem() { systemState.openSystem(); }
    function refreshSystemStats() { systemState.refreshSystemStats(); }
    function openOmarchyUpdate() { systemState.openOmarchyUpdate(); }
    function refreshOmarchyUpdateCheck() { systemState.refreshOmarchyUpdateCheck(); }

    // ---------- Connectivity ----------
    State.ConnectivityState { id: connectivity; shell: root }

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
    function refreshWifi() { connectivity.refreshWifi(); }
    function connectWifi(ssid) { connectivity.connectWifi(ssid); }
    function disconnectWifi() { connectivity.disconnectWifi(); }
    function toggleWifiRadio() { connectivity.toggleWifiRadio(); }
    function refreshBluetooth() { connectivity.refreshBluetooth(); }
    function btConnect(mac) { connectivity.btConnect(mac); }
    function btDisconnect(mac) { connectivity.btDisconnect(mac); }
    function btTogglePower() { connectivity.btTogglePower(); }
    function btToggleScan() { connectivity.btToggleScan(); }
    function wifiBarsGlyph(pct) { return connectivity.wifiBarsGlyph(pct); }

    // ---------- Audio ----------
    State.AudioState { id: audio; shell: root }

    property alias audioIcon: audio.audioIcon
    property alias audioVol: audio.audioVol
    property alias audioMuted: audio.audioMuted
    property alias audioSinks: audio.audioSinks
    property alias audioDefaultSink: audio.audioDefaultSink
    function setDefaultSink(id) { audio.setDefaultSink(id); }
    function refreshAudioSinks() { audio.refreshAudioSinks(); }
    function setVolume(pct) { audio.setVolume(pct); }
    function toggleMute() { audio.toggleMute(); }

    // ---------- OSD (volume / brightness toasts; see shell/OsdSurfaces.qml) ----------
    State.OsdState { id: osd; shell: root }

    // ---------- Input / keyboard layout ----------
    State.InputState { id: input; shell: root }

    property alias layoutLabel: input.layoutLabel
    property alias layoutKeymap: input.layoutKeymap
    property alias layoutCodes: input.layoutCodes
    property alias layoutCount: input.layoutCount
    readonly property alias layoutTooltip: input.layoutTooltip
    function cycleLayout() { input.cycleLayout(); }

    // ---------- Display ----------
    State.DisplayState { id: display; shell: root }

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
    function openDisplay() { display.openDisplay(); }
    function runSunset(verb) { display.runSunset(verb); }
    function setWarmth(k) { display.setWarmth(k); }
    function setBrightness(pct) { display.setBrightness(pct); }
    function setGamma(pct) { display.setGamma(pct); }
    function applyPreset(p) { display.applyPreset(p); }
    function blankScreen() { display.blankScreen(); }
    function resetDisplay() { display.resetDisplay(); }

    // ---------- Media ----------
    State.MediaState { id: media; shell: root }

    property alias mediaVisible: media.mediaVisible
    property alias musicPlayer: media.musicPlayer
    property alias musicTitle: media.musicTitle
    property alias musicArtist: media.musicArtist
    property alias musicArtUrl: media.musicArtUrl
    property alias musicPlaying: media.musicPlaying
    function openMedia() { media.openMedia(); }
    function refreshMusic() { media.refreshMusic(); }
    function musicToggle() { media.musicToggle(); }
    function musicNext() { media.musicNext(); }
    function musicPrev() { media.musicPrev(); }

    // ---------- Screenshots / videos ----------
    State.CaptureState { id: capture }

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
    function openScreenshots() { capture.openScreenshots(); }
    function refreshScreenshots() { capture.refreshScreenshots(); }
    function moveScreenshotSelection(delta) { capture.moveScreenshotSelection(delta); }
    function moveScreenshotRow(delta) { capture.moveScreenshotRow(delta); }
    function pageScreenshots(delta) { capture.pageScreenshots(delta); }
    function formatScreenshotLabel(path) { return capture.formatScreenshotLabel(path); }
    function copyScreenshotToClipboard(path) { capture.copyScreenshotToClipboard(path); }
    function openVideos() { capture.openVideos(); }
    function refreshVideos() { capture.refreshVideos(); }
    function moveVideoSelection(delta) { capture.moveVideoSelection(delta); }
    function moveVideoRow(delta) { capture.moveVideoRow(delta); }
    function pageVideos(delta) { capture.pageVideos(delta); }
    function formatVideoLabel(path) { return capture.formatVideoLabel(path); }
    function formatVideoDuration(secs) { return capture.formatVideoDuration(secs); }
    function formatVideoSize(bytes) { return capture.formatVideoSize(bytes); }
    function formatVideoMtime(secs) { return capture.formatVideoMtime(secs); }
    function copyVideoUri(path) { capture.copyVideoUri(path); }
    function copyVideoBytes(path) { capture.copyVideoBytes(path); }

    // ---------- Aether ----------
    State.AetherState { id: aether; shell: root }

    property alias aetherVisible: aether.aetherVisible
    property alias aetherBlueprints: aether.aetherBlueprints
    property alias selectedAether: aether.selectedAether
    property alias aetherLoading: aether.aetherLoading
    property alias aetherQuery: aether.aetherQuery
    readonly property alias aetherFiltered: aether.aetherFiltered
    function openAether() { aether.openAether(); }
    function refreshAetherBlueprints() { aether.refreshAetherBlueprints(); }
    function moveAetherSelection(delta, wrap) { aether.moveAetherSelection(delta, wrap); }
    function applyAetherBlueprint(name) { aether.applyAetherBlueprint(name); }

    // ---------- Calendar ----------
    State.CalendarState { id: calendar; shell: root }

    property alias calendarVisible: calendar.calendarVisible
    property alias calendarMonthOffset: calendar.calendarMonthOffset
    property alias calendarTick: calendar.calendarTick
    property alias selectedDay: calendar.selectedDay
    readonly property alias calendarCells: calendar.calendarCells
    readonly property alias calendarMonthName: calendar.calendarMonthName
    readonly property alias calendarYear: calendar.calendarYear
    readonly property alias selectedDayDetail: calendar.selectedDayDetail
    readonly property alias selectedDayHoliday: calendar.selectedDayHoliday
    function easterDate(year) { return calendar.easterDate(year); }
    function norwegianHoliday(year, month, day, easter) {
        return calendar.norwegianHoliday(year, month, day, easter);
    }
    function openCalendar() { calendar.openCalendar(); }

    // ---------- Weather ----------
    State.WeatherState { id: weather; shell: root }

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
    function weatherGlyph(code, night) { return weather.weatherGlyph(code, night); }
    function parseClock(s) { return weather.parseClock(s); }
    function fmtTemp(c) { return weather.fmtTemp(c); }
    function refreshWeather() { weather.refreshWeather(); }

    // ---------- Idle dim ----------
    IdleMonitor {
        id: idleMonitor
        enabled: true
        timeout: 60
        respectInhibitors: true
    }
    readonly property bool isIdle: idleMonitor.isIdle

    // ---------- Generic launcher ----------
    Process {
        id: runner
        running: false
        stderr: StdioCollector {
            onStreamFinished: if (this.text) console.log("[RUN-DIAG stderr] " + this.text)
        }
    }

    function run(cmd) {
        console.log("[RUN-DIAG] " + cmd);
        runner.command = ["bash", "-lc", cmd];
        runner.running = false;
        runner.running = true;
    }

    Shell.DesktopSurfaces { shell: root }
    Shell.OsdSurfaces { shell: root; osd: osd }
    Shell.DesktopIpc { shell: root; osd: osd }
}
