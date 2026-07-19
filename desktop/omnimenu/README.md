# Omni menu structure

The public component remains `../OmniMenu.qml`, so `shell.qml` has one stable
entry point. Implementation details are grouped here by responsibility:

```text
omnimenu/
├── ActionDispatcher.qml  # launching rows and Quick-tile actions
├── KeyRouter.qml         # keyboard navigation and preview shortcuts
├── MenuSurface.qml       # layer-shell windows, card layout, keyboard routing
├── SearchModel.qml       # search index, filtering, and ranking
├── components/           # reusable visual sections of the menu
├── data/                 # pure JavaScript tile data and preview formatting
└── services/             # Omni-only search and state backends
```

Common edits:

- Change the overall window/card in `MenuSurface.qml`.
- Change key handling and navigation in `KeyRouter.qml`.
- Change search behaviour or result order in `SearchModel.qml`.
- Change commands and launch handling in `ActionDispatcher.qml`.
- Change a visible section in `components/`.
- Change Quick-tile definitions in `data/Tiles.js`.
- Change menu rows and categories in `../data/OmniData.js`.

Desktop-wide services stay in `../services/`. For example, `Themes.qml` is
shared by Omni and the Aether Quick panel, while `NotificationService.qml` is
unrelated to Omni.
