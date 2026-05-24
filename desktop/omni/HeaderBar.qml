import QtQuick

// Top section of the OmniMenu card: title with breadcrumb, live result
// count, and the keyboard-hint footer hint on the right.
Item {
    id: header

    required property var omni
    property var processes: null
    property var themes:    null
    property var bookmarks: null

    width: parent ? parent.width : 0
    height: 43

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            text: header.omni.categoryFilter === ""
                  ? "OMNI"
                  : "OMNI › " + header.omni.sectionIcon + "  " + header.omni.categoryFilter.toUpperCase()
            color: header.omni.ink
            font.family: header.omni.mono
            font.pixelSize: 19 * header.omni.fontScale
            font.letterSpacing: 4
            font.weight: Font.Medium
        }
        Text {
            text: {
                const o = header.omni;
                if (!o.appsLoaded) return "LOADING APPS…";
                if (o.fileMode) {
                    if (o.query.length === 0) return "TYPE TO SEARCH ~";
                    if (o.fdRunning) return "SEARCHING…";
                    const total = o.filteredItems.length;
                    return total === 0
                        ? "NO FILES MATCH"
                        : total + " FILE" + (total === 1 ? "" : "S");
                }
                if (o.ghMode) {
                    const total = o.filteredItems.length;
                    if (o.query.length === 0) {
                        if (o.ghRunning && total === 0) return "LOADING PRS…";
                        return total === 0
                            ? "NO OPEN PRS"
                            : total + " OPEN PR" + (total === 1 ? "" : "S");
                    }
                    if (o.ghRunning) return "SEARCHING GITHUB…";
                    return total === 0
                        ? "NO REPOS MATCH"
                        : total + " REPO" + (total === 1 ? "" : "S");
                }
                if (o.favMode) {
                    const total = o.filteredItems.length;
                    return total === 0
                        ? "NO FAVOURITES YET  ·  CTRL+S TO STAR"
                        : total + " FAVOURITE" + (total === 1 ? "" : "S");
                }
                if (o.histMode) {
                    const total = o.filteredItems.length;
                    return total === 0
                        ? "NO HISTORY YET"
                        : total + " RECENT" + (total === 1 ? "" : "S");
                }
                if (o.procMode) {
                    const total = o.filteredItems.length;
                    if (header.processes && header.processes.running && total === 0) return "LOADING PROCESSES…";
                    return total === 0
                        ? "NO PROCESSES"
                        : total + " PROCESS" + (total === 1 ? "" : "ES");
                }
                if (o.themeMode) {
                    const total = o.filteredItems.length;
                    if (header.themes && !header.themes.loaded && total === 0) return "LOADING THEMES…";
                    return total === 0
                        ? "NO THEMES FOUND"
                        : total + " THEME" + (total === 1 ? "" : "S");
                }
                const total = o.filteredItems.length;
                if (o.query.length === 0) {
                    return total + " ENTRIES  ·  " + o.allItems.length + " TOTAL";
                }
                return total === 0
                    ? "NO MATCHES"
                    : total + " MATCH" + (total === 1 ? "" : "ES");
            }
            color: header.omni.inkDeep
            font.family: header.omni.mono
            font.pixelSize: 11 * header.omni.fontScale
            font.letterSpacing: 2
        }
    }

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: {
            const o = header.omni;
            if (o.quickMode) {
                return o.quickExpanded
                    ? "HJKL / ↑↓←→  ·  TAB SECT  ·  ↵ APPLY  ·  ESC BACK"
                    : "HJKL / ↑↓←→  ·  ↵ OPEN  ·  ESC BACK";
            }
            if (o.categoryFilter === "")
                return "↑↓ / TAB  ·  ↵ OPEN  ·  ^S STAR  ·  ESC CLOSE";
            let verb = "RUN";
            if (o.fileMode)       verb = "OPEN FILE";
            else if (o.ghMode)    verb = "OPEN";
            else if (o.procMode)  verb = "KILL";
            else if (o.themeMode) verb = "APPLY";
            return "↑↓ / TAB  ·  ↵ " + verb + "  ·  ^S STAR  ·  ESC BACK";
        }
        color: header.omni.inkDeep
        font.family: header.omni.mono
        font.pixelSize: 10 * header.omni.fontScale
        font.letterSpacing: 2
        opacity: 0.6
    }
}
