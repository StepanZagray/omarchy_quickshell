import QtQuick
import Quickshell.Io

Item {
    id: root

    required property var shell
    required property var osd

    IpcHandler {
        target: "screenshots"
        function toggle(): void {
            if (root.shell.screenshotsVisible) root.shell.screenshotsVisible = false;
            else root.shell.openScreenshots();
        }
        function open(): void { root.shell.openScreenshots(); }
        function close(): void { root.shell.screenshotsVisible = false; }
    }

    IpcHandler {
        target: "videos"
        function toggle(): void {
            if (root.shell.videosVisible) root.shell.videosVisible = false;
            else root.shell.openVideos();
        }
        function open(): void { root.shell.openVideos(); }
        function close(): void { root.shell.videosVisible = false; }
    }

    IpcHandler {
        target: "aether"
        function toggle(): void {
            if (root.shell.aetherVisible) root.shell.aetherVisible = false;
            else root.shell.openAether();
        }
        function open(): void { root.shell.openAether(); }
        function close(): void { root.shell.aetherVisible = false; }
    }

    IpcHandler {
        target: "display"
        function toggle(): void {
            if (root.shell.displayVisible) root.shell.displayVisible = false;
            else root.shell.openDisplay();
        }
        function open(): void { root.shell.openDisplay(); }
        function close(): void { root.shell.displayVisible = false; }
        function reset(): void { root.shell.resetDisplay(); }
        function blank(): void { root.shell.blankScreen(); }
    }

    IpcHandler {
        target: "calendar"
        function toggle(): void {
            if (root.shell.calendarVisible) root.shell.calendarVisible = false;
            else root.shell.openCalendar();
        }
        function open(): void { root.shell.openCalendar(); }
        function close(): void { root.shell.calendarVisible = false; }
    }

    IpcHandler {
        target: "media"
        function toggle(): void {
            if (root.shell.mediaVisible) root.shell.mediaVisible = false;
            else root.shell.openMedia();
        }
        function open(): void { root.shell.openMedia(); }
        function close(): void { root.shell.mediaVisible = false; }
    }

    IpcHandler {
        target: "system"
        function toggle(): void {
            if (root.shell.systemVisible) root.shell.systemVisible = false;
            else root.shell.openSystem();
        }
        function open(): void { root.shell.openSystem(); }
        function close(): void { root.shell.systemVisible = false; }
        function btop(): void { root.shell.run("omarchy-launch-or-focus-tui btop"); }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { root.shell.togglePowerMenu(); }
        function open(): void { root.shell.openPowerMenu(); }
        function close(): void { root.shell.powerMenuVisible = false; }
    }

    IpcHandler {
        target: "notifications"
        function dismiss(): void { root.shell.dismissLastNotification(); }
        function dismissAll(): void { root.shell.dismissAllNotifications(); }
        function invoke(): void { root.shell.invokeLastNotification(); }
        function restore(): void { root.shell.restoreLastNotification(); }
        function toggleSilent(): void { root.shell.toggleNotificationSilence(); }
        function count(): int { return root.shell.notificationCount; }
        function isSilent(): bool { return root.shell.notificationsSilent; }
    }

    IpcHandler {
        target: "osd"
        function volumeRaise(): void { root.osd.volumeRaise(); }
        function volumeLower(): void { root.osd.volumeLower(); }
        function volumeMute(): void { root.osd.volumeMute(); }
        function volumeUp1(): void { root.osd.volumeUp1(); }
        function volumeDown1(): void { root.osd.volumeDown1(); }
        function brightnessUp5(): void { root.osd.brightnessUp(5); }
        function brightnessDown5(): void { root.osd.brightnessDown(5); }
        function brightnessUp1(): void { root.osd.brightnessUp(1); }
        function brightnessDown1(): void { root.osd.brightnessDown(1); }
        function brightnessMax(): void { root.osd.brightnessMax(); }
        function brightnessMin(): void { root.osd.brightnessMin(); }
        function kbdBrightnessUp(): void { root.osd.kbdBrightnessUp(); }
        function kbdBrightnessDown(): void { root.osd.kbdBrightnessDown(); }
        function kbdBrightnessCycle(): void { root.osd.kbdBrightnessCycle(); }
        function micMuteToggle(): void { root.osd.micMuteToggle(); }
        function touchpadToggle(): void { root.osd.touchpadToggle(); }
        function touchpadOn(): void { root.osd.touchpadOn(); }
        function touchpadOff(): void { root.osd.touchpadOff(); }
    }
}
