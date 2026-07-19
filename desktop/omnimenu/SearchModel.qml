import QtQuick
import "../data/OmniData.js" as Data

// Owns Omni's searchable index, query tokenisation, and result ranking.
// UI state stays in OmniMenu.qml; this object only turns source arrays and
// mode flags into the ordered list rendered by the menu.
Item {
    id: model

    required property string query
    required property string categoryFilter

    required property bool ghReady
    required property bool tldrMode
    required property bool llmMode
    required property bool fileMode
    required property bool ghMode
    required property bool favouriteMode
    required property bool historyMode
    required property bool processMode
    required property bool themeMode

    required property var appItems
    required property var desktopItems
    required property var tuiItems
    required property var themeItems
    required property var favouriteItems
    required property var historyItems
    required property var processItems
    required property var fileItems
    required property var ghItems
    required property var tldrItems
    required property var chatItems

    readonly property int maxResults: 250
    readonly property int prefixScore: 100
    readonly property int titleScore: 60
    readonly property int keywordScore: 20
    readonly property int categoryScore: 10

    readonly property var omarchyItems: Data.annotate(Data.omarchyItems)
    readonly property var navigationItems: Data.annotate(Data.categoryNav)
    readonly property var allItems: model.omarchyItems
        .concat(model.appItems)
        .concat(model.desktopItems)
        .concat(model.tuiItems)
        .concat(model.themeItems)

    readonly property var queryTokens: {
        const normalized = model.query.trim().toLowerCase();
        return normalized.length === 0 ? [] : normalized.split(/\s+/);
    }

    readonly property var navigationRows: model.ghReady
        ? model.navigationItems
        : model.navigationItems.filter(item => item.target !== Data.ghCategory)

    function primaryScore(item, tokens) {
        const title = item._t;
        let total = 0;
        for (let i = 0; i < tokens.length; i++) {
            const token = tokens[i];
            if (title.indexOf(token) === 0) total += model.prefixScore;
            else if (title.indexOf(token) >= 0) total += model.titleScore;
        }
        return total;
    }

    function kindRank(item) {
        const category = item.category;
        if (category === "App") return 1;
        if (category === "TUI") return 3;
        if (category === "THEME" || category === "ACTIVE") return 4;
        return 2;
    }

    function scoreItem(item, tokens) {
        const title = item._t;
        const keywords = item._k;
        const category = item._c;
        let total = 0;
        for (let i = 0; i < tokens.length; i++) {
            const token = tokens[i];
            let score = 0;
            if (title.indexOf(token) === 0) score += model.prefixScore;
            else if (title.indexOf(token) >= 0) score += model.titleScore;
            if (keywords.indexOf(token) >= 0) score += model.keywordScore;
            if (category.indexOf(token) >= 0) score += model.categoryScore;
            if (score === 0) return 0;
            total += score;
        }
        return total;
    }

    readonly property var filteredItems: {
        if (model.tldrMode) return model.tldrItems;
        if (model.llmMode) return model.chatItems;
        if (model.fileMode) return model.fileItems;
        if (model.ghMode) return model.ghItems;

        const tokens = model.queryTokens;
        const filter = model.categoryFilter;
        const cap = model.maxResults;

        let pool;
        if (model.favouriteMode) pool = model.favouriteItems;
        else if (model.historyMode) pool = model.historyItems;
        else if (model.processMode) pool = model.processItems;
        else if (model.themeMode) pool = model.themeItems;
        else if (filter !== "") pool = model.allItems.filter(item => item.category === filter);
        else pool = model.navigationRows.concat(model.allItems);

        if (tokens.length === 0) {
            if (model.favouriteMode || model.historyMode || model.processMode
                || model.themeMode || filter !== "") {
                return pool.length <= cap ? pool : pool.slice(0, cap);
            }

            const favourites = model.favouriteItems.slice(0, 5);
            const favouriteKeys = {};
            for (let i = 0; i < favourites.length; i++)
                favouriteKeys[Data.itemKey(favourites[i])] = true;

            const tail = [];
            for (let i = 0; i < model.allItems.length; i++) {
                const item = model.allItems[i];
                const category = item.category;
                if (category === "TUI" || category === "THEME" || category === "ACTIVE") continue;
                if (favouriteKeys[Data.itemKey(item)]) continue;
                tail.push(item);
            }

            const result = model.navigationRows.concat(favourites).concat(tail);
            return result.length <= cap ? result : result.slice(0, cap);
        }

        const scored = [];
        for (let i = 0; i < pool.length; i++) {
            const item = pool[i];
            const score = model.scoreItem(item, tokens);
            if (score > 0) {
                scored.push({
                    s: score,
                    p: model.primaryScore(item, tokens),
                    item: item
                });
            }
        }

        scored.sort((a, b) => {
            if (b.p !== a.p) return b.p - a.p;

            const aCategory = a.item.isCategory ? 0 : 1;
            const bCategory = b.item.isCategory ? 0 : 1;
            if (aCategory !== bCategory) return aCategory - bCategory;

            const aKind = model.kindRank(a.item);
            const bKind = model.kindRank(b.item);
            if (aKind !== bKind) return aKind - bKind;

            if (b.s !== a.s) return b.s - a.s;
            return a.item.title.localeCompare(b.item.title);
        });

        const limit = Math.min(scored.length, cap);
        const result = new Array(limit);
        for (let i = 0; i < limit; i++) result[i] = scored[i].item;
        return result;
    }
}
