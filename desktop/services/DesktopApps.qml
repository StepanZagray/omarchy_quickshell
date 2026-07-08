import QtQuick
import "../data/Data.js" as Data

// Surfaces desktop shell popup widgets as palette rows.
Item {
    id: desktopApps

    readonly property var candidates: [
        { target: "display",     title: "Display",     icon: "󰍹", category: "Toggle",
          keywords: "display brightness warmth gamma night light monitor screen panel" },
        { target: "calendar",    title: "Calendar",    icon: "󰃭", category: "Toggle",
          keywords: "calendar date month day year week schedule planner today" },
        { target: "system",      title: "System",      icon: "󰍛", category: "Toggle",
          keywords: "system cpu memory mem load pressure btop process monitor" },
        { target: "screenshots", title: "Screenshots", icon: "󰄀", category: "Capture",
          keywords: "screenshots browse view gallery thumbnails recent" },
        { target: "videos",      title: "Videos",      icon: "󰕧", category: "Capture",
          keywords: "videos browse view gallery thumbnails recordings recent screen record" }
    ]

    readonly property var items: Data.annotate(candidates.map(c => ({
        title: c.title,
        icon: c.icon,
        category: c.category,
        keywords: c.keywords,
        exec: "qs -c desktop ipc call " + c.target + " " + (c.verb || "open")
    })))

    function probe() {}
}
