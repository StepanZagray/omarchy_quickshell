import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "data/OmniData.js" as Data
import "omnimenu" as Omni
import "omnimenu/data/Tiles.js" as Tiles
import "omnimenu/services" as OmniServices
import "services" as Services

// Omni-menu palette. Fuses installed apps (.desktop scan) with every
// `omarchy-menu` action, scored against title, category, and per-entry
// synonyms (so "wallpaper" finds Background, "reboot" finds Restart).
// Drill-down rows pivot the list to a category, fd file search, gh repo
// search, processes, or themes. Toggle via:
//   qs -c desktop ipc call palette toggle
//
// This is the public state coordinator. Search/ranking, action dispatch,
// layer-shell surfaces, reusable view components, and feature data each live
// in a named file below omnimenu/.
Item {
    id: root

    required property var theme
    // Desktop shell instance from shell.qml. Quick mode reads live telemetry
    // from it; when absent (headless config) tiles fall back to "—".
    property var desktop: null

    readonly property color paper:   theme.paper
    readonly property color ink:     theme.ink
    readonly property color inkDeep: theme.inkDeep
    readonly property color sumi:    theme.inkDeep
    readonly property color indigo:  theme.indigo
    readonly property color seal:    theme.seal
    readonly property color bg:      theme.bg
    readonly property color fg:      theme.fg
    readonly property color muted:   theme.muted
    readonly property color sep:     theme.sep
    readonly property color rowHi:   theme.rowHi
    readonly property color rowSel:  theme.rowSel

    readonly property string mono:  theme.mono
    readonly property string serif: theme.serif

    readonly property int cornerRadius: theme.cornerRadius
    readonly property int animationDuration: theme.animationDuration

    // Sources that feed `allItems`. AppScan reads .desktop files;
    // DesktopApps surfaces shell popup widgets as palette rows.
    OmniServices.AppScan { id: appScan }
    OmniServices.DesktopApps { id: desktopApps }
    OmniServices.Tuis { id: tuis }
    readonly property alias appsLoaded: appScan.loaded

    // ---------- Visibility / state ----------
    // Trailing underscore avoids shadowing Item.visible — read by the
    // PanelWindow's visibility binding below.
    property bool visible_: false
    property string query: ""
    property int selectedIndex: 0
    // Active drill-down. "" means root (category navigators + everything
    // searchable); any other value pins the list to that category. Set by
    // activating a category nav row; cleared by Esc / Backspace-on-empty.
    property string categoryFilter: ""

    // File and GitHub search drills reuse the category machinery: the
    // Files/GitHub nav rows set categoryFilter to one of Data's sentinels,
    // filteredItems pivots to the matching results array, and goUp/Esc
    // unwind via the same path as any other category.
    readonly property bool fileMode: root.categoryFilter === Data.fileCategory
    readonly property bool ghMode:   root.categoryFilter === Data.ghCategory
    readonly property bool favMode:  root.categoryFilter === Data.favCategory
    readonly property bool histMode: root.categoryFilter === Data.histCategory
    readonly property bool procMode:  root.categoryFilter === Data.procCategory
    readonly property bool themeMode: root.categoryFilter === Data.themeCategory
    // Quick mode swaps the result list for a live-tile grid. Tiles bind
    // to nav telemetry for instantaneous state; clicking one drops an
    // expanded detail panel below the grid with that tile's adjustments.
    readonly property bool quickMode: root.categoryFilter === "Quick"
    // Query-shape modes. Each triggers off the query string directly,
    // so the user can pivot in from any drill without going back to
    // root.
    //   `tldr <name>` -> inline tldr preview
    //   `? <q>`       -> local Ollama chat preview (qwen3.5:0.8b)
    //   `$ <task>`    -> same model, but constrained to emit a shell
    //                    command for the described task
    readonly property bool tldrMode:
        root.query === "tldr" || root.query.substring(0, 5) === "tldr "
    readonly property bool chatMode: root.query.charAt(0) === "?"
    readonly property bool cmdMode:  root.query.charAt(0) === "$"
    // Either of the two LLM-backed modes - share the single OllamaChat
    // instance below, differing only by system prompt.
    readonly property bool llmMode:  root.chatMode || root.cmdMode
    // Live font multiplier — every `font.pixelSize` binding in this
    // file multiplies its base by this value. Ctrl++ / Ctrl+- nudge
    // it in 0.1 steps; Ctrl+= resets to 1.0. Clamped to keep the
    // panel usable at extremes.
    property real fontScale: 1.0
    function bumpFontScale(delta) {
        const next = Math.max(0.7, Math.min(2.0, root.fontScale + delta));
        // Snap to one decimal so successive bumps don't drift on
        // floating-point round-off.
        root.fontScale = Math.round(next * 10) / 10;
    }
    // null = no expansion; otherwise the tile object whose detail panel
    // is currently revealed under the grid.
    property var expandedTile: null
    // Single source of truth for "in Quick mode with a tile open" — the
    // grid column count, the compressed-tile flag, and the side-panel
    // visibility all key off it.
    readonly property bool quickExpanded: quickMode && expandedTile !== null
    readonly property int  quickGridCols: quickExpanded ? 1 : 4
    function expandTile(t) {
        if (!t) { root.expandedTile = null; return; }
        // Click same tile to collapse; click a different tile to swap.
        root.expandedTile = (root.expandedTile && root.expandedTile.key === t.key)
                            ? null : t;
    }
    function collapseTile() { root.expandedTile = null; }

    OmniServices.Bookmarks { id: bookmarks }

    // ---------- Quick tiles ----------
    // Split into a *static* base array (the Repeater's model) and a
    // *dynamic* dict of per-tile live data, indexed by tile.key. The
    // base never changes, so the Repeater's 12 delegates are built once
    // and never torn down — clicks and hover state survive across
    // navbar ticks. Dynamic fields (glyph/label/sub/tone) read out of
    // `quickTilesDyn` via the `tileDyn()` helper; when the dict swaps,
    // only the delegate's text/color bindings re-evaluate. Order
    // matches the Samsung-style quick panel — most glanced
    // (battery/audio/wifi/bt) first.
    readonly property var quickTilesBase: Tiles.base

    // Dynamic per-tile data — keyed by tile.key. Gated on `visible_`
    // so navbar ticks don't wake the rebuild while the palette is
    // closed (the previous snapshot keeps the Repeater happy when the
    // user re-opens, before this binding re-evaluates).
    property var _quickTilesDynCache: ({})
    readonly property var quickTilesDyn: {
        if (!root.visible_) return root._quickTilesDynCache;
        // No navbar yet (shell reload, hot-swap, or a tick before the
        // sibling Navbar wires up): return an empty snapshot but do NOT
        // store it, so the cached previous-good values survive the gap
        // and the close-fade never flashes blank tiles.
        if (!root.desktop) return ({});
        const dyn = Tiles.buildDyn(root.desktop);
        root._quickTilesDynCache = dyn;
        return dyn;
    }

    // Resolve the dynamic side of a base tile. Returns an empty object
    // (not undefined) so delegate bindings can chain `.glyph` / `.sub`
    // without an `?.` chain on every read.
    function tileDyn(t) { return (t && root.quickTilesDyn[t.key]) || ({}); }

    // No search field in quickMode — tiles are always the full set so
    // grid arithmetic (gridCols * row) stays predictable. Kept as a
    // separate property so non-quick code paths don't need to branch.
    readonly property var filteredQuickTiles: root.quickTilesBase

    function activateQuickTile(tile) { actions.activateQuickTile(tile); }
    function longQuickTile(tile) { actions.longActivateQuickTile(tile); }

    // gh CLI-backed repo search + README preview.
    OmniServices.GhSearch {
        id: ghSearch
        query: root.query
        active: root.ghMode && !root.tldrMode && !root.llmMode
        selectedItem: root.filteredItems[root.selectedIndex] || null
    }
    readonly property alias ghReady:        ghSearch.ready
    readonly property alias ghItems:        ghSearch.items
    readonly property alias ghRunning:      ghSearch.running
    readonly property alias previewRepo:    ghSearch.previewRepo
    readonly property alias previewRepoUrl: ghSearch.previewRepoUrl
    readonly property alias previewReadme:  ghSearch.previewReadme

    readonly property string sectionIcon: {
        if (root.categoryFilter === "") return "";
        for (let i = 0; i < Data.categoryNav.length; i++) {
            if (Data.categoryNav[i].target === root.categoryFilter)
                return Data.categoryNav[i].icon;
        }
        return "";
    }

    // fd-backed file search + file preview. Aliases mirror the prior root
    // properties so the panel UI doesn't have to change wholesale.
    OmniServices.FileSearch {
        id: fileSearch
        query: root.query
        queryTokens: root.queryTokens
        active: root.fileMode && !root.tldrMode && !root.llmMode
        selectedItem: root.filteredItems[root.selectedIndex] || null
    }
    readonly property alias fileItems:    fileSearch.items
    readonly property alias fdRunning:    fileSearch.running
    readonly property alias previewPath:  fileSearch.previewPath
    readonly property alias previewText:  fileSearch.previewText
    readonly property alias previewMeta:  fileSearch.previewMeta
    readonly property alias previewKind:  fileSearch.previewKind

    OmniServices.Processes {
        id: processes
        active: root.procMode && !root.tldrMode && !root.llmMode
        selectedItem: root.filteredItems[root.selectedIndex] || null
    }
    readonly property alias procItems:    processes.items
    readonly property alias procRunning:  processes.running
    readonly property alias procPreviewText: processes.previewText
    readonly property alias procPreviewPid:  processes.previewPid

    Services.Themes {
        id: themes
        active: root.themeMode && !root.tldrMode && !root.llmMode
    }
    readonly property alias themeItems:   themes.items
    readonly property alias themeLoaded:  themes.loaded

    // tldr-backed CLI help preview. Triggered by `$ <name>` in the query.
    OmniServices.TldrSearch {
        id: tldrSearch
        query: root.query
        active: root.tldrMode
    }
    readonly property alias tldrItems:    tldrSearch.items
    readonly property alias tldrRunning:  tldrSearch.running
    readonly property alias tldrPreview:  tldrSearch.previewText
    readonly property alias tldrTool:     tldrSearch.toolName

    // Local-LLM preview. Triggered by `? <question>` (chat) or
    // `$ <task>` (command). The mode property steers the system
    // prompt and the placeholder copy; everything else (probe,
    // streaming, unload-on-leave) is shared.
    OmniServices.OllamaChat {
        id: ollamaChat
        query: root.query
        active: root.llmMode
        mode: root.cmdMode ? "command" : "chat"
    }
    readonly property alias chatItems:     ollamaChat.items
    readonly property alias chatRunning:   ollamaChat.running
    readonly property alias chatPreview:   ollamaChat.previewText
    readonly property alias chatStatus:    ollamaChat.status
    readonly property alias chatPrompt:    ollamaChat.prompt
    readonly property alias chatSubmitted: ollamaChat.submitted
    readonly property alias chatModel:     ollamaChat.model_

    readonly property bool previewActive: root.tldrMode || root.llmMode || root.fileMode || root.ghMode || root.procMode || root.themeMode
    readonly property bool previewHasContent: {
        if (root.tldrMode) return root.tldrPreview !== "";
        if (root.llmMode) {
            // Probing: no content yet. Status != "ok": show the
            // install/start/pull hint as content. OK + not submitted:
            // empty (the placeholder hint shows). OK + submitted:
            // there's a streaming or completed answer.
            if (root.chatStatus === "") return false;
            if (root.chatStatus !== "ok") return true;
            if (!root.chatSubmitted) return false;
            return root.chatPreview !== "";
        }
        if (root.fileMode || root.ghMode)
            return root.previewPath !== "" || root.previewRepoUrl !== "";
        if (root.procMode) return processes.previewPid !== "";
        if (root.themeMode) {
            const it = root.filteredItems[root.selectedIndex];
            return !!(it && it.swatches && it.swatches.length > 0);
        }
        return false;
    }

    readonly property string homeDir: Quickshell.env("HOME")

    function open() {
        if (root.desktop)
            root.desktop.closeAllPopups();

        root.query = "";
        root.selectedIndex = 0;
        root.categoryFilter = "";
        root.visible_ = true;
        desktopApps.probe();
    }
    function close() {
        root.visible_ = false;
        // Cancel any in-flight stream and zero chat state so the next
        // session starts fresh. The ollama daemon itself is left
        // running — we don't manage its lifecycle, only our use of it.
        ollamaChat.clear();
    }
    function toggle() { if (root.visible_) close(); else open(); }
    function goUp() {
        // Step back one level. At root this is a no-op so the caller can
        // chain "goUp or close" without a branch.
        if (root.categoryFilter !== "") {
            root.categoryFilter = "";
            root.query = "";
            root.selectedIndex = 0;
            return true;
        }
        return false;
    }

    // Entering or leaving file mode resets fd state. Other category drills
    // share the same handler — clearing both is a free no-op for other drills.
    onCategoryFilterChanged: {
        fileSearch.clear();
        ghSearch.clear();
        tldrSearch.clear();
        ollamaChat.clear();
        // Processes/Themes own their own clear()-on-deactivate via their
        // `active` binding, so the shell doesn't have to nudge them when
        // the filter changes — they react automatically.
    }

    // ---------- Icon resolution ----------
    // `.desktop` Icon field is either an absolute path or an icon-theme
    // name. Qt's QQmlEngine doesn't know about XDG themes, so theme names
    // get pushed through Quickshell.iconPath for resolution; absolute paths
    // just need a file:// prefix. Returns "" when nothing resolves so the
    // delegate can fall back to its nerd-font glyph.
    function resolveIconUrl(raw) {
        if (!raw) return "";
        if (raw.charAt(0) === "/") return "file://" + raw;
        return Quickshell.iconPath(raw, "");
    }

    // Selected rows and Quick tiles share the same detached launch policy.
    Omni.ActionDispatcher {
        id: actions
        omni: root
        processes: processes
        bookmarks: bookmarks
        ollamaChat: ollamaChat
    }

    function activate(item) { actions.activate(item); }

    // Search indexing and ranking are isolated from UI and launch state.
    Omni.SearchModel {
        id: searchModel

        query: root.query
        categoryFilter: root.categoryFilter

        ghReady: root.ghReady
        tldrMode: root.tldrMode
        llmMode: root.llmMode
        fileMode: root.fileMode
        ghMode: root.ghMode
        favouriteMode: root.favMode
        historyMode: root.histMode
        processMode: root.procMode
        themeMode: root.themeMode

        appItems: appScan.apps
        desktopItems: desktopApps.items
        tuiItems: tuis.items
        themeItems: themes.items
        favouriteItems: bookmarks.favouriteItems
        historyItems: bookmarks.historyItems
        processItems: processes.items
        fileItems: fileSearch.items
        ghItems: ghSearch.items
        tldrItems: tldrSearch.items
        chatItems: ollamaChat.items
    }

    readonly property alias queryTokens: searchModel.queryTokens
    readonly property alias allItems: searchModel.allItems
    readonly property alias filteredItems: searchModel.filteredItems

    onFilteredItemsChanged: {
        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex,
                                                  root.filteredItems.length - 1));
    }

    // ---------- Selection movement ----------
    // Single entry point for keyboard nav so arrow/Tab/Page bindings stay
    // one-liners. `wrap` toggles modulo behaviour vs. clamp — arrow + Tab
    // wrap, paging clamps (matches list-widget convention everywhere else).
    function moveSelection(delta, wrap) {
        const n = root.filteredItems.length;
        if (n === 0) return;
        let next = root.selectedIndex + delta;
        next = wrap ? ((next % n) + n) % n
                    : Math.max(0, Math.min(n - 1, next));
        root.selectedIndex = next;
        menuSurface.positionResultAtIndex(next, ListView.Contain);
    }

    // Grid-aware step for Quick mode. `delta` may exceed ±1 (arrow Up/Down
    // moves by gridCols). Clamps rather than wraps so Up from the top row
    // doesn't jump to the last row of a partial bottom row.
    function moveQuickSelection(delta) {
        const n = root.filteredQuickTiles.length;
        if (n === 0) return;
        const next = Math.max(0, Math.min(n - 1, root.selectedIndex + delta));
        root.selectedIndex = next;
    }

    // ---------- IPC ----------
    IpcHandler {
        target: "palette"
        function toggle(): void { root.toggle() }
        function open(): void { root.open() }
        function close(): void { root.close() }
        function refresh(): void { appScan.refresh(); }
        // Open OmniMenu pre-pivoted to a drill-down category (e.g. "Quick").
        // Lets Hyprland bind a shortcut straight into a category without
        // exposing the visual grid as a separate surface.
        function openCategory(cat: string): void {
            root.open();
            root.categoryFilter = cat;
        }
    }

    // ---------- Global shortcuts ----------
    // Direct wlroots global-shortcut binding. Hyprland delivers the
    // keypress over its socket straight to this running shell, so
    // SUPER+SPACE no longer pays for a fresh `qs` client process (the
    // dominant ~50-150ms of perceived "boot" before any pixel changes).
    // Bind in Hyprland with:
    //   bind = SUPER, SPACE, global, quickshell:palette-toggle
    //   bind = ALT,   SPACE, global, quickshell:palette-quick
    GlobalShortcut {
        appid: "quickshell"
        name: "palette-toggle"
        description: "Toggle omni-menu palette"
        onPressed: root.toggle()
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "palette-quick"
        description: "Open omni-menu pivoted to Quick"
        onPressed: { root.open(); root.categoryFilter = "Quick"; }
    }

    // Layer-shell windows, card composition, and keyboard routing.
    Omni.MenuSurface {
        id: menuSurface
        omni: root
        processes: processes
        themes: themes
        bookmarks: bookmarks
        ollamaChat: ollamaChat
    }
}
