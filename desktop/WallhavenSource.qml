import QtQuick
import Quickshell
import Quickshell.Io

// Wallhaven.cc backend for the aether popup. Anonymous API, SFW only
// (purity=100, categories=100). Picking an item applies the cached
// thumbnail (not the full wallpaper) so aether's `--generate` sees the
// same bytes that drove the preview palette — preview matches result.
//
// Cache layout under cacheDir:
//   <id>.jpg      — thumbnail
//   <id>.palette  — 16 lines of #hex extracted by `aether --extract-palette`
Item {
    id: source

    required property var navbar

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell-desktop/wallhaven"

    property var  items: []
    property int  page: 1
    property int  selectedIndex: -1
    property bool loading: false
    property string query: ""
    property bool active: false

    // Index up to which kickExtraction has already enqueued items. Lets
    // each appended page only enqueue its new tail rather than re-walking
    // the full accumulated list.
    property int extractedCount: 0

    // Captures the "append" intent for the in-flight probe so a refresh
    // racing a loadNextPage can't get its mode flipped under it.
    property bool _appendNext: false

    readonly property string url: {
        const q = source.query.trim();
        const base = "https://wallhaven.cc/api/v1/search"
                   + "?sorting=" + (q === "" ? "toplist" : "relevance")
                   + "&topRange=1M&purity=100&categories=100"
                   + "&page=" + source.page;
        return q === "" ? base : base + "&q=" + encodeURIComponent(q);
    }

    function loadPage(n, append) {
        source.page = Math.max(1, n);
        source._appendNext = !!append;
        source.loading = true;
        probe.running = false;
        probe.running = true;
    }

    function loadNextPage() {
        if (source.loading) return;
        source.loadPage(source.page + 1, true);
    }

    function refresh() {
        source.extractedCount = 0;
        source.loadPage(source.page, false);
    }

    function thumbPathFor(item)   { return item ? source.cacheDir + "/" + item.id + ".jpg"     : ""; }
    function palettePathFor(item) { return item ? source.cacheDir + "/" + item.id + ".palette" : ""; }

    function moveSelection(delta) {
        const n = source.items.length;
        if (n === 0) { source.selectedIndex = -1; return; }
        const cur = source.selectedIndex < 0 ? 0 : source.selectedIndex;
        source.selectedIndex = Math.max(0, Math.min(n - 1, cur + delta));
    }

    function applyItem(item) {
        if (!item || !item.id || !item.thumb) return;
        const thumb = source.thumbPathFor(item);
        const wallpaperDir = Quickshell.env("HOME") + "/.local/share/aether/wallpapers";
        const dest = wallpaperDir + "/wallhaven-" + item.id + ".jpg";
        source.navbar.run(
            "mkdir -p " + JSON.stringify(wallpaperDir)
            + " && { [ -f " + JSON.stringify(thumb) + " ]"
            + "       || curl -fsSL --max-time 30 -o " + JSON.stringify(thumb) + " " + JSON.stringify(item.thumb) + "; }"
            + " && cp -f " + JSON.stringify(thumb) + " " + JSON.stringify(dest)
            + " && aether --generate " + JSON.stringify(dest)
        );
    }

    Timer {
        id: queryDebounce
        interval: 300
        repeat: false
        onTriggered: {
            source.extractedCount = 0;
            source.loadPage(1, false);
        }
    }

    onQueryChanged: if (source.active) queryDebounce.restart()
    onActiveChanged: if (active && items.length === 0 && !loading) source.loadPage(1, false)

    Process {
        id: probe
        running: false
        command: ["curl", "-fsS", "--max-time", "15", source.url]
        stdout: StdioCollector {
            onStreamFinished: {
                source.loading = false;
                let arr = [];
                try {
                    const obj = JSON.parse(this.text);
                    arr = (obj.data || []).map(d => ({
                        id: d.id,
                        path: d.path,
                        thumb: (d.thumbs && d.thumbs.large) || "",
                        colors: d.colors || [],
                        resolution: d.resolution || "",
                        ratio: d.ratio || ""
                    })).filter(d => d.thumb && d.path);
                } catch (_) { arr = []; }

                if (source._appendNext) {
                    // Dedupe by id — wallhaven's toplist can return
                    // overlapping pages near the cutoff.
                    const seen = {};
                    for (const e of source.items) seen[e.id] = true;
                    source.items = source.items.concat(arr.filter(e => !seen[e.id]));
                } else {
                    source.items = arr;
                    source.selectedIndex = arr.length > 0 ? 0 : -1;
                    source.extractedCount = 0;
                }
                source._appendNext = false;
                source.kickExtraction();
            }
        }
    }

    // Spawn aether --extract-palette for items added since the last
    // call. Cache hits short-circuit before any network or aether call,
    // so re-visiting a page is instant.
    function kickExtraction() {
        const items = source.items;
        if (items.length <= source.extractedCount) return;

        const argv = ["bash", "-c",
            "CACHE=" + JSON.stringify(source.cacheDir) + ";"
            + " mkdir -p \"$CACHE\";"
            + " while [ $# -ge 2 ]; do"
            + "   id=$1; url=$2; shift 2;"
            + "   pal=\"$CACHE/$id.palette\";"
            + "   [ -f \"$pal\" ] && continue;"
            + "   thumb=\"$CACHE/$id.jpg\";"
            + "   [ -f \"$thumb\" ] || curl -fsSL --max-time 20 -o \"$thumb\" \"$url\" || continue;"
            + "   aether --extract-palette \"$thumb\" 2>/dev/null"
            + "     | awk '{print $2}' > \"$pal.tmp\""
            + "     && mv \"$pal.tmp\" \"$pal\";"
            + " done",
            "extract"];
        for (let i = source.extractedCount; i < items.length; i++) {
            const it = items[i];
            if (it && it.id && it.thumb) {
                argv.push(it.id);
                argv.push(it.thumb);
            }
        }
        source.extractedCount = items.length;
        if (argv.length <= 4) return;

        extractor.command = argv;
        extractor.running = false;
        extractor.running = true;
    }

    Process {
        id: extractor
        running: false
    }
}
