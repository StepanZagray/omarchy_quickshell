import QtQuick
import Quickshell.Io
import "Data.js" as Data

// Probes the navbar shell's IPC surface at startup and exposes the
// widgets it owns as omni-menu items. Each item executes
// `qs -c navbar ipc call <target> open` to pop the corresponding panel.
//
// If navbar isn't running, or doesn't register a given target, that
// item is simply omitted — no error, no placeholder row.
Item {
    id: navbarApps

    // Per-target metadata. `category` slots each one into an existing
    // omarchy category so it shows up where the user would already
    // look: weather/display under Toggle, screenshots/videos under
    // Capture (next to the take-a-screenshot row).
    readonly property var candidates: [
        { target: "weather",     title: "Toggle Weather",     icon: "󰖐", category: "Toggle",
          keywords: "weather forecast temperature rain sun wind cloud wttr" },
        { target: "display",     title: "Toggle Display",     icon: "󰍹", category: "Toggle",
          keywords: "display brightness warmth gamma night light monitor screen panel" },
        { target: "screenshots", title: "Browse Screenshots", icon: "󰄀", category: "Capture",
          keywords: "screenshots browse view gallery thumbnails recent" },
        { target: "videos",      title: "Browse Videos",      icon: "󰕧", category: "Capture",
          keywords: "videos browse view gallery thumbnails recordings recent screen record" }
    ]

    property var items: []

    Process {
        id: probe
        running: false
        // Lists every IpcHandler on the navbar shell. Output looks like
        // `target weather\n  function open(): void\n  ...`.
        command: ["sh", "-c", "qs -c navbar ipc show 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text || "";
                const available = {};
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const m = lines[i].match(/^target (\S+)/);
                    if (m) available[m[1]] = true;
                }
                const out = [];
                const cs = navbarApps.candidates;
                for (let i = 0; i < cs.length; i++) {
                    if (!available[cs[i].target]) continue;
                    out.push({
                        title: cs[i].title,
                        icon: cs[i].icon,
                        category: cs[i].category,
                        keywords: cs[i].keywords,
                        exec: "qs -c navbar ipc call " + cs[i].target + " open"
                    });
                }
                navbarApps.items = Data.annotate(out);
            }
        }
    }

    Component.onCompleted: probe.running = true
}
