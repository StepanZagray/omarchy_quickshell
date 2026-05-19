import QtQuick
import Quickshell
import Quickshell.Io

// Live results from wallhaven.cc. Driven by `query` (empty -> SFW toplist
// of the last month, otherwise -> relevance search). Picking an item
// uses the cached thumbnail (not the full wallpaper) as the input to
// `aether --generate`, so the previewed colours match what's applied —
// aether sees the same source bytes either way.
//
// Each result's thumbnail is cached at
//   ~/.cache/quickshell-desktop/wallhaven/<id>.jpg
// and aether's extracted palette at
//   ~/.cache/quickshell-desktop/wallhaven/<id>.palette
// (one #hex per line, 16 lines). Cell delegates FileView that .palette
// file and render the swatches as soon as extraction completes.
//
// Parameters mirror the omarchy-theme-from-wallhaven defaults: purity=100
// (SFW), categories=100 (General). Anonymous API access — no key needed.
Item {
    id: source

    required property var navbar  // for navbar.run(cmd) and HOME env

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell-desktop/wallhaven"

    property var  items: []
    property int  page: 1
    property int  selectedIndex: -1
    property bool loading: false
    property string query: ""

    // Toggled by AetherPopup so this source only fetches while in
    // wallhaven mode. First flip from false→true kicks the cold-open.
    property bool active: false

    readonly property string url: {
        const q = source.query.trim();
        const base = "https://wallhaven.cc/api/v1/search"
                   + "?sorting=" + (q === "" ? "toplist" : "relevance")
                   + "&topRange=1M&purity=100&categories=100"
                   + "&page=" + source.page;
        return q === "" ? base : base + "&q=" + encodeURIComponent(q);
    }

    function loadPage(n) {
        source.page = Math.max(1, n);
        source.loading = true;
        probe.running = false;
        probe.running = true;
    }

    // Append the next page's results onto the existing items list. Used
    // by the infinite-scroll handler in AetherPopup so the user doesn't
    // have to step through pages manually.
    function loadNextPage() {
        if (source.loading) return;
        source.appendMode = true;
        source.loadPage(source.page + 1);
    }
    property bool appendMode: false

    function refresh() {
        source.appendMode = false;
        source.loadPage(source.page);
    }

    function thumbPathFor(item) {
        if (!item) return "";
        return source.cacheDir + "/" + item.id + ".jpg";
    }

    function palettePathFor(item) {
        if (!item) return "";
        return source.cacheDir + "/" + item.id + ".palette";
    }

    function moveSelection(delta) {
        const n = source.items.length;
        if (n === 0) { source.selectedIndex = -1; return; }
        const cur = source.selectedIndex < 0 ? 0 : source.selectedIndex;
        let next = cur + delta;
        if (next < 0) next = 0;
        else if (next >= n) next = n - 1;
        source.selectedIndex = next;
    }

    // Apply the cached thumbnail (not the full wallpaper). The thumbnail
    // is the same image bytes that drove the preview palette, so aether
    // sees exactly what the user saw. Side benefit: no extra 1-4 MB
    // download per apply. The cached thumb also gets copied into
    // aether's wallpaper dir so it shows up in --list-wallpapers.
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

    // 300ms debounce so each keystroke doesn't fire a wallhaven request.
    Timer {
        id: queryDebounce
        interval: 300
        repeat: false
        onTriggered: {
            source.page = 1;
            source.loadPage(1);
        }
    }

    onQueryChanged: {
        if (source.active) queryDebounce.restart();
    }

    onActiveChanged: {
        if (active && items.length === 0 && !loading) source.loadPage(1);
    }

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

                if (source.appendMode) {
                    // Dedupe by id when appending — wallhaven's toplist
                    // can return overlapping pages near the cutoff.
                    const seen = {};
                    for (const e of source.items) seen[e.id] = true;
                    source.items = source.items.concat(arr.filter(e => !seen[e.id]));
                } else {
                    source.items = arr;
                    source.selectedIndex = arr.length > 0 ? 0 : -1;
                }
                source.appendMode = false;
                source.kickExtraction();
            }
        }
    }

    function kickExtraction() {
        if (source.items.length === 0) return;
        // Inline the id/url pairs as bash positional args. Sequential
        // serial loop — cache hits skip both download and aether call,
        // so re-opening a recently-browsed page is instant. One job at a
        // time keeps CPU pressure reasonable while users scroll.
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
        for (const it of source.items) {
            if (it.id && it.thumb) {
                argv.push(it.id);
                argv.push(it.thumb);
            }
        }
        extractor.command = argv;
        extractor.running = false;
        extractor.running = true;
    }

    Process {
        id: extractor
        running: false
    }
}
