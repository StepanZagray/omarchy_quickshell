import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool screenshotsVisible: false
    property int screenshotPage: 0
    readonly property int screenshotsPerPage: 12
    property var screenshotFiles: []
    property int selectedScreenshot: -1
    property string copiedPath: ""
    property bool videosVisible: false
    property int videoPage: 0
    readonly property int videosPerPage: 12
    property var videoFiles: []
    property int selectedVideo: -1
    property string copiedVideo: ""
    property string copiedVideoMode: ""
    readonly property var visibleScreenshots: {
        if (!root.screenshotsVisible)
            return [];

        const start = root.screenshotPage * root.screenshotsPerPage;
        return root.screenshotFiles.slice(start, start + root.screenshotsPerPage);
    }
    readonly property var selectedScreenshotEntry: root.selectedScreenshot >= 0 ? (root.visibleScreenshots[root.selectedScreenshot] || null) : null
    readonly property int screenshotPageCount: {
        if (root.screenshotFiles.length === 0)
            return 1;

        return Math.ceil(root.screenshotFiles.length / root.screenshotsPerPage);
    }
    readonly property var visibleVideos: {
        if (!root.videosVisible)
            return [];

        const start = root.videoPage * root.videosPerPage;
        return root.videoFiles.slice(start, start + root.videosPerPage);
    }
    readonly property var selectedVideoEntry: root.selectedVideo >= 0 ? (root.visibleVideos[root.selectedVideo] || null) : null
    readonly property int videoPageCount: {
        if (root.videoFiles.length === 0)
            return 1;

        return Math.ceil(root.videoFiles.length / root.videosPerPage);
    }

    function openScreenshots() {
        root.screenshotPage = 0;
        root.selectedScreenshot = 0;
        screenshotProbe.running = false;
        screenshotProbe.running = true;
        root.screenshotsVisible = true;
    }

    function refreshScreenshots() {
        screenshotProbe.running = false;
        screenshotProbe.running = true;
    }

    function moveScreenshotSelection(delta) {
        if (root.screenshotFiles.length === 0)
            return;

        const visible = root.visibleScreenshots;
        const next = root.selectedScreenshot + delta;
        if (next < 0 && root.screenshotPage > 0) {
            root.screenshotPage--;
            root.selectedScreenshot = Math.min(root.screenshotsPerPage - 1, root.screenshotFiles.length - root.screenshotPage * root.screenshotsPerPage - 1);
        } else if (next >= visible.length && root.screenshotPage < root.screenshotPageCount - 1) {
            root.screenshotPage++;
            root.selectedScreenshot = 0;
        } else if (next >= 0 && next < visible.length) {
            root.selectedScreenshot = next;
        }
    }

    function moveScreenshotRow(delta) {
        const visible = root.visibleScreenshots;
        const next = root.selectedScreenshot + delta * 4;
        if (next >= 0 && next < visible.length)
            root.selectedScreenshot = next;

    }

    function pageScreenshots(delta) {
        const next = root.screenshotPage + delta;
        if (next >= 0 && next < root.screenshotPageCount) {
            root.screenshotPage = next;
            root.selectedScreenshot = 0;
        }
    }

    function formatScreenshotLabel(path) {
        const m = String(path).match(/screenshot-(\d{4}-\d{2}-\d{2})_(\d{2})-(\d{2})-\d{2}\.[A-Za-z0-9]+$/);
        if (m)
            return m[1] + " " + m[2] + ":" + m[3];

        const parts = String(path).split("/");
        return parts[parts.length - 1];
    }

    function openVideos() {
        root.videoPage = 0;
        root.selectedVideo = 0;
        videoProbe.running = false;
        videoProbe.running = true;
        root.videosVisible = true;
    }

    function refreshVideos() {
        videoProbe.running = false;
        videoProbe.running = true;
    }

    function moveVideoSelection(delta) {
        if (root.videoFiles.length === 0)
            return;

        const visible = root.visibleVideos;
        const next = root.selectedVideo + delta;
        if (next < 0 && root.videoPage > 0) {
            root.videoPage--;
            root.selectedVideo = Math.min(root.videosPerPage - 1, root.videoFiles.length - root.videoPage * root.videosPerPage - 1);
        } else if (next >= visible.length && root.videoPage < root.videoPageCount - 1) {
            root.videoPage++;
            root.selectedVideo = 0;
        } else if (next >= 0 && next < visible.length) {
            root.selectedVideo = next;
        }
    }

    function moveVideoRow(delta) {
        const visible = root.visibleVideos;
        const next = root.selectedVideo + delta * 4;
        if (next >= 0 && next < visible.length)
            root.selectedVideo = next;

    }

    function pageVideos(delta) {
        const next = root.videoPage + delta;
        if (next >= 0 && next < root.videoPageCount) {
            root.videoPage = next;
            root.selectedVideo = 0;
        }
    }

    function formatVideoLabel(path) {
        const parts = String(path).split("/");
        return parts[parts.length - 1];
    }

    function formatVideoDuration(secs) {
        const s = Math.max(0, Math.floor(Number(secs) || 0));
        if (s <= 0)
            return "";

        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const ss = s % 60;
        const pad = (n) => {
            return String(n).padStart(2, "0");
        };
        return h > 0 ? (h + ":" + pad(m) + ":" + pad(ss)) : (m + ":" + pad(ss));
    }

    function formatVideoSize(bytes) {
        const b = Number(bytes) || 0;
        if (b >= 1073741824)
            return (b / 1073741824).toFixed(1) + " GB";

        if (b >= 1048576)
            return (b / 1048576).toFixed(0) + " MB";

        if (b >= 1024)
            return (b / 1024).toFixed(0) + " KB";

        return b + " B";
    }

    function formatVideoMtime(secs) {
        if (!secs)
            return "";

        return Qt.formatDateTime(new Date(Number(secs) * 1000), "yyyy-MM-dd hh:mm");
    }

    function copyScreenshotToClipboard(path) {
        shotCopier.command = ["sh", "-c", "wl-copy -t image/png < " + JSON.stringify(path)];
        shotCopier.running = false;
        shotCopier.running = true;
        root.copiedPath = path;
        copiedReset.restart();
        if (root.screenshotsVisible)
            copiedDismiss.restart();

    }

    function _runVideoCopy(cmd, path, mode) {
        vidCopier.command = ["sh", "-c", cmd];
        vidCopier.running = false;
        vidCopier.running = true;
        root.copiedVideo = path;
        root.copiedVideoMode = mode;
        copiedVideoReset.restart();
        if (root.videosVisible)
            copiedVideoDismiss.restart();

    }

    function copyVideoUri(path) {
        const uri = "file://" + encodeURI(path);
        root._runVideoCopy("printf '%s\\r\\n' " + JSON.stringify(uri) + " | wl-copy -n --type text/uri-list", path, "file");
    }

    function copyVideoBytes(path) {
        root._runVideoCopy("wl-copy < " + JSON.stringify(path), path, "bytes");
    }

    Process {
        id: screenshotProbe

        running: false
        command: ["sh", "-c", "ls -t " + Quickshell.env("HOME") + "/Pictures/screenshot-*.png 2>/dev/null | head -60"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter((s) => {
                    return s.length > 0;
                });
                root.screenshotFiles = lines.map((p) => {
                    return ({
                        "path": p,
                        "label": root.formatScreenshotLabel(p)
                    });
                });
                if (root.screenshotPage >= root.screenshotPageCount)
                    root.screenshotPage = 0;

                root.selectedScreenshot = root.visibleScreenshots.length > 0 ? 0 : -1;
            }
        }

    }

    Process {
        id: shotCopier

        running: false
    }

    Timer {
        id: copiedReset

        interval: 1400
        repeat: false
        onTriggered: root.copiedPath = ""
    }

    Timer {
        id: copiedDismiss

        interval: 260
        repeat: false
        onTriggered: root.screenshotsVisible = false
    }

    Process {
        id: videoProbe

        running: false
        command: ["bash", "-c", "CDIR=\"$HOME/.cache/quickshell-desktop/video-thumbs\"; " + "mkdir -p \"$CDIR\" 2>/dev/null; " + "PATHS=$(find \"$HOME/Videos\" -maxdepth 3 -type f " + "\\( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' " + "  -o -iname '*.mov' -o -iname '*.avi' -o -iname '*.m4v' \\) " + "-printf '%T@\\t%p\\n' 2>/dev/null | sort -rn | head -60 | cut -f2-); " + "printf '%s\\n' \"$PATHS\" | xargs -r -d '\\n' -P \"$(nproc 2>/dev/null || echo 4)\" -I{} " + "sh -c '" + "path=\"$1\"; cdir=\"$2\"; " + "key=$(printf %s \"$path\" | md5sum | cut -c1-32); " + "thumb=\"$cdir/$key.jpg\"; meta=\"$cdir/$key.meta\"; " + "if [ ! -f \"$thumb\" ] || [ \"$path\" -nt \"$thumb\" ]; then " + "command -v ffmpeg >/dev/null 2>&1 && " + "ffmpeg -y -ss 1 -i \"$path\" -frames:v 1 -vf scale=320:-1 -q:v 6 \"$thumb\" </dev/null >/dev/null 2>&1 || true; " + "fi; " + "if [ ! -f \"$meta\" ] || [ \"$path\" -nt \"$meta\" ]; then " + "dur=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 \"$path\" 2>/dev/null | awk \"{printf \\\"%d\\\",\\$1+0}\"); " + "printf %s \"${dur:-0}\" > \"$meta\"; " + "fi" + "' _ {} \"$CDIR\"; " + "printf '%s\\n' \"$PATHS\" | while IFS= read -r path; do " + "[ -z \"$path\" ] && continue; " + "key=$(printf %s \"$path\" | md5sum | cut -c1-32); " + "thumb=\"$CDIR/$key.jpg\"; " + "dur=$(cat \"$CDIR/$key.meta\" 2>/dev/null); " + "mtime=$(stat -c %Y \"$path\" 2>/dev/null); " + "size=$(stat -c %s \"$path\" 2>/dev/null); " + "printf '%s\\t%s\\t%s\\t%s\\t%s\\n' \"$path\" \"$thumb\" \"${dur:-0}\" \"${mtime:-0}\" \"${size:-0}\"; " + "done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter((s) => {
                    return s.length > 0;
                });
                root.videoFiles = lines.map((line) => {
                    const f = line.split("\t");
                    return {
                        "path": f[0] || "",
                        "thumb": f[1] || "",
                        "duration": parseInt(f[2] || "0", 10),
                        "mtime": parseInt(f[3] || "0", 10),
                        "size": parseInt(f[4] || "0", 10),
                        "label": root.formatVideoLabel(f[0] || "")
                    };
                });
                if (root.videoPage >= root.videoPageCount)
                    root.videoPage = 0;

                root.selectedVideo = root.visibleVideos.length > 0 ? 0 : -1;
            }
        }

    }

    Process {
        id: vidCopier

        running: false
    }

    Timer {
        id: copiedVideoReset

        interval: 1400
        repeat: false
        onTriggered: {
            root.copiedVideo = "";
            root.copiedVideoMode = "";
        }
    }

    Timer {
        id: copiedVideoDismiss

        interval: 260
        repeat: false
        onTriggered: root.videosVisible = false
    }

}
