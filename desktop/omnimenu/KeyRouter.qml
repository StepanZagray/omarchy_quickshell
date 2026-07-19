import QtQuick

// Central keyboard router for search, Quick mode, preview scrolling, and
// clipboard shortcuts. MenuSurface only forwards key events here.
Item {
    id: router

    required property var omni
    required property var quickContainer
    required property var resultList
    required property var previewPane
    required property var bookmarks

    function handle(event) {
        // hjkl → arrow translation (Vim-style nav). Only active
        // in quickMode, where there is no typing buffer and the
        // tile grid is the sole input surface. In the main omni
        // search h/j/k/l are letters first; remapping them — even
        // conditionally on empty query — surprised users who
        // expected to start typing immediately.
        const _hjklMap = {};
        _hjklMap[Qt.Key_H] = Qt.Key_Left;
        _hjklMap[Qt.Key_J] = Qt.Key_Down;
        _hjklMap[Qt.Key_K] = Qt.Key_Up;
        _hjklMap[Qt.Key_L] = Qt.Key_Right;
        const _wrap = (e) => {
            if (_hjklMap[e.key] === undefined) return e;
            if (!router.omni.quickMode) return e;
            return { key: _hjklMap[e.key], modifiers: e.modifiers, text: e.text };
        };
        const e2 = _wrap(event);

        // When a quick tile is expanded, give its body first crack
        // at the key so arrow/Tab/Enter drive the body's own focus
        // chain (volume slider, wi-fi list, bluetooth list, …)
        // instead of the tile grid. Bodies return true from
        // kbdHandle() to swallow the event; anything they leave
        // unhandled (e.g. Esc) bubbles to the cascade below.
        const bodyItem = router.quickContainer.bodyLoaderItem.item;
        if (router.omni.quickExpanded
            && bodyItem
            && typeof bodyItem.kbdHandle === "function"
            && bodyItem.kbdHandle(e2)) {
            event.accepted = true;
            return;
        }
        if (e2.key === Qt.Key_Escape) {
            // Esc cascade: collapse the quick-tile detail panel
            // first (if open), then clear the typed query, then
            // unwind drill-down, then close. Each Esc undoes
            // exactly one layer of state so the palette never
            // exits with a half-typed query on screen.
            if (router.omni.quickExpanded) {
                router.omni.expandedTile = null;
            } else if (router.omni.query.length > 0) {
                router.omni.query = "";
                router.omni.selectedIndex = 0;
            } else if (!router.omni.goUp()) {
                router.omni.close();
            }
            event.accepted = true;
        } else if (router.omni.quickMode && e2.key === Qt.Key_Left) {
            router.omni.moveQuickSelection(-1);
            event.accepted = true;
        } else if (router.omni.quickMode && e2.key === Qt.Key_Right) {
            router.omni.moveQuickSelection(1);
            event.accepted = true;
        } else if (router.omni.quickMode && e2.key === Qt.Key_Up) {
            router.omni.moveQuickSelection(-router.omni.quickGridCols);
            event.accepted = true;
        } else if (router.omni.quickMode && e2.key === Qt.Key_Down) {
            router.omni.moveQuickSelection(router.omni.quickGridCols);
            event.accepted = true;
        } else if (router.omni.quickMode
                   && (e2.key === Qt.Key_Tab && !(e2.modifiers & Qt.ShiftModifier))) {
            router.omni.moveQuickSelection(1);
            event.accepted = true;
        } else if (router.omni.quickMode
                   && (e2.key === Qt.Key_Backtab
                       || (e2.key === Qt.Key_Tab && (e2.modifiers & Qt.ShiftModifier)))) {
            router.omni.moveQuickSelection(-1);
            event.accepted = true;
        } else if (router.omni.llmMode && router.omni.previewHasContent
                   && (e2.key === Qt.Key_Up || e2.key === Qt.Key_Down
                       || e2.key === Qt.Key_PageUp || e2.key === Qt.Key_PageDown
                       || e2.key === Qt.Key_Home || e2.key === Qt.Key_End
                       || e2.key === Qt.Key_Tab || e2.key === Qt.Key_Backtab)) {
            // chat / command mode: same scroll routing as
            // tldr mode below.
            // List nav is a no-op here (single synthetic row).
            const f = router.previewPane.chatFlickable;
            const max = Math.max(0, f.contentHeight - f.height);
            const line = 18;
            const page = Math.max(line, f.height * 0.9);
            let dy = 0;
            if (e2.key === Qt.Key_Up
                || (e2.key === Qt.Key_Tab && (e2.modifiers & Qt.ShiftModifier))
                || e2.key === Qt.Key_Backtab) dy = -line;
            else if (e2.key === Qt.Key_Down
                     || (e2.key === Qt.Key_Tab && !(e2.modifiers & Qt.ShiftModifier))) dy = line;
            else if (e2.key === Qt.Key_PageUp)   dy = -page;
            else if (e2.key === Qt.Key_PageDown) dy = page;
            else if (e2.key === Qt.Key_Home) { f.contentY = 0; event.accepted = true; return; }
            else if (e2.key === Qt.Key_End)  { f.contentY = max; event.accepted = true; return; }
            f.contentY = Math.max(0, Math.min(max, f.contentY + dy));
            event.accepted = true;
        } else if (router.omni.tldrMode && router.omni.tldrPreview !== ""
                   && (e2.key === Qt.Key_Up || e2.key === Qt.Key_Down
                       || e2.key === Qt.Key_PageUp || e2.key === Qt.Key_PageDown
                       || e2.key === Qt.Key_Home || e2.key === Qt.Key_End
                       || e2.key === Qt.Key_Tab || e2.key === Qt.Key_Backtab)) {
            // tldr mode has a single synthetic row, so list nav is
            // a no-op. Route arrow/page/home/end (and Tab/Shift+Tab,
            // which would otherwise wrap the same row to itself) to
            // the preview Flickable instead.
            const f = router.previewPane.tldrFlickable;
            const max = Math.max(0, f.contentHeight - f.height);
            const line = 18;
            const page = Math.max(line, f.height * 0.9);
            let dy = 0;
            if (e2.key === Qt.Key_Up
                || (e2.key === Qt.Key_Tab && (e2.modifiers & Qt.ShiftModifier))
                || e2.key === Qt.Key_Backtab) dy = -line;
            else if (e2.key === Qt.Key_Down
                     || (e2.key === Qt.Key_Tab && !(e2.modifiers & Qt.ShiftModifier))) dy = line;
            else if (e2.key === Qt.Key_PageUp)   dy = -page;
            else if (e2.key === Qt.Key_PageDown) dy = page;
            else if (e2.key === Qt.Key_Home) { f.contentY = 0; event.accepted = true; return; }
            else if (e2.key === Qt.Key_End)  { f.contentY = max; event.accepted = true; return; }
            f.contentY = Math.max(0, Math.min(max, f.contentY + dy));
            event.accepted = true;
        } else if (e2.key === Qt.Key_Down
                   || (e2.key === Qt.Key_Tab && !(e2.modifiers & Qt.ShiftModifier))) {
            // Tab + Down step forward, Shift+Tab + Up step backward,
            // both wrap. Paging clamps (see Key_PageDown). Matches
            // launcher convention everywhere else.
            router.omni.moveSelection(1, true);
            event.accepted = true;
        } else if (e2.key === Qt.Key_Up
                   || e2.key === Qt.Key_Backtab
                   || (e2.key === Qt.Key_Tab && (e2.modifiers & Qt.ShiftModifier))) {
            router.omni.moveSelection(-1, true);
            event.accepted = true;
        } else if (e2.key === Qt.Key_PageDown) {
            router.omni.moveSelection(8, false);
            event.accepted = true;
        } else if (e2.key === Qt.Key_PageUp) {
            router.omni.moveSelection(-8, false);
            event.accepted = true;
        } else if (e2.key === Qt.Key_Home) {
            router.omni.selectedIndex = 0;
            router.resultList.list.positionViewAtIndex(0, ListView.Beginning);
            event.accepted = true;
        } else if (e2.key === Qt.Key_End) {
            router.omni.selectedIndex = Math.max(0, router.omni.filteredItems.length - 1);
            router.resultList.list.positionViewAtIndex(router.omni.selectedIndex, ListView.End);
            event.accepted = true;
        } else if (e2.key === Qt.Key_Return || e2.key === Qt.Key_Enter) {
            if (router.omni.quickMode) {
                const t = router.omni.filteredQuickTiles[router.omni.selectedIndex];
                if (t) router.omni.expandTile(t);
            } else {
                const it = router.omni.filteredItems[router.omni.selectedIndex];
                if (it) router.omni.activate(it);
            }
            event.accepted = true;
        } else if (e2.key === Qt.Key_Backspace) {
            // Backspace deletes a char first; once the query is
            // empty it walks back up one level so the same key
            // unwinds both the typed query and the breadcrumb.
            if (router.omni.query.length > 0) router.omni.query = router.omni.query.slice(0, -1);
            else router.omni.goUp();
            event.accepted = true;
        } else if (e2.key === Qt.Key_S && (e2.modifiers & Qt.ControlModifier)) {
            const it = router.omni.filteredItems[router.omni.selectedIndex];
            if (it && !it.isCategory && !it.isTldr && !it.isOllama)
                router.bookmarks.toggleFavourite(it);
            event.accepted = true;
        } else if ((e2.modifiers & Qt.ControlModifier)
                   && (e2.key === Qt.Key_Plus || e2.key === Qt.Key_Equal
                       || e2.key === Qt.Key_Minus)) {
            // Ctrl++ / Ctrl+- nudge the omni-menu font scale;
            // Ctrl+= resets to default. Plus is reached via
            // Shift+= on US layouts (Qt delivers Qt.Key_Plus),
            // and via a dedicated key on numpads / EU layouts.
            if (e2.key === Qt.Key_Plus) router.omni.bumpFontScale(+0.1);
            else if (e2.key === Qt.Key_Minus) router.omni.bumpFontScale(-0.1);
            else /* Key_Equal without Shift */ router.omni.fontScale = 1.0;
            event.accepted = true;
        } else if (e2.key === Qt.Key_C && (e2.modifiers & Qt.ControlModifier)
                   && router.omni.llmMode && router.omni.chatPreview !== "") {
            // Ctrl+C: if the user dragged a selection in the
            // rendered RichText edit, copy that (lossy — Qt
            // strips inline `code` backticks during conversion,
            // but it's what they asked for). With no selection,
            // copy the full raw markdown from the hidden plain-
            // text shadow so pasted commands keep their syntax.
            if (router.previewPane.chatEdit.selectedText.length > 0) {
                router.previewPane.chatEdit.copy();
            } else {
                router.previewPane.chatPlain.selectAll();
                router.previewPane.chatPlain.copy();
                router.previewPane.chatPlain.deselect();
            }
            event.accepted = true;
        } else if (e2.key === Qt.Key_C && (e2.modifiers & Qt.ControlModifier)
                   && router.omni.tldrMode && router.omni.tldrPreview !== "") {
            // Ctrl+C in tldr mode: copy the active selection if
            // there is one, otherwise copy the whole rendered
            // preview. The TextEdit's `copy()` works without
            // active focus, so the search input keeps keystrokes.
            if (router.previewPane.tldrEdit.selectedText.length > 0) {
                router.previewPane.tldrEdit.copy();
            } else {
                router.previewPane.tldrEdit.selectAll();
                router.previewPane.tldrEdit.copy();
                router.previewPane.tldrEdit.deselect();
            }
            event.accepted = true;
        } else if (!router.omni.quickMode && event.text && event.text.length === 1) {
            const ch = event.text;
            // Printable range; lets letters, digits, and spaces in,
            // keeps modifier-driven control codes out. Skipped in
            // quickMode — there's no search field to feed.
            if (ch.charCodeAt(0) >= 32 && ch.charCodeAt(0) !== 127) {
                router.omni.query += ch;
                router.omni.selectedIndex = 0;
                event.accepted = true;
            }
        }
    }
}
