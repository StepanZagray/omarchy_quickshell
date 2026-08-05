import QtQuick
import Quickshell.Services.Mpris

Item {
    id: root

    required property var shell
    property bool mediaVisible: false
    property MprisPlayer musicPlayer: null
    property string musicTitle: ""
    property string musicArtist: ""
    property string musicArtUrl: ""
    property bool musicPlaying: false

    function openMedia(screenName) {
        if (shell.mediaAnchorItem)
            shell.anchorPopupTo(shell.mediaAnchorItem);

        // Prefer an explicit screen (bar click on that monitor); otherwise the
        // focused monitor. Never reuse a stale popupAnchorScreen from another
        // widget / earlier open.
        const screen = (screenName && screenName.length > 0) ? screenName : shell.focusedScreenName();
        shell.popupAnchorScreen = screen;
        shell.frameWidgetScreen = screen;
        root.refreshMusic();
        root.mediaVisible = true;
    }

    function applyMusicArtUrl(url) {
        const next = url || "";
        // Re-assigning the same URL does not notify bindings. Pulse empty→url so
        // the cover Image reloads after a Quickshell restart while the track is
        // unchanged (skip/prev works because the URL actually changes).
        if (next === root.musicArtUrl) {
            if (next.length === 0)
                return;
            root.musicArtUrl = "";
        }
        root.musicArtUrl = next;
    }

    function refreshMusic() {
        const players = Mpris.players ? Mpris.players.values : [];
        let best = null;
        let bestRank = -1;
        for (let i = 0; i < players.length; i++) {
            const p = players[i];
            if (!p)
                continue;

            const hasTitle = !!(p.trackTitle && p.trackTitle.length > 0);
            let rank = 0;
            if (hasTitle && p.isPlaying)
                rank = 2;
            else if (hasTitle)
                rank = 1;
            if (rank > bestRank) {
                best = p;
                bestRank = rank;
            }
        }
        root.musicPlayer = best;
        root.musicTitle = best ? (best.trackTitle || "") : "";
        root.musicArtist = best ? (best.trackArtist || "") : "";
        root.applyMusicArtUrl(best ? best.trackArtUrl : "");
        root.musicPlaying = best ? !!best.isPlaying : false;
    }

    Component.onCompleted: {
        root.refreshMusic();
        startupSync.restart();
    }

    Timer {
        id: startupSync

        interval: 250
        repeat: true
        property int ticks: 0
        onTriggered: {
            root.refreshMusic();
            ticks++;
            if (ticks >= 12) {
                root.applyMusicArtUrl(root.musicPlayer
                                      ? root.musicPlayer.trackArtUrl
                                      : "");
                stop();
            }
        }
    }

    function musicToggle() {
        if (root.musicPlayer && root.musicPlayer.canTogglePlaying)
            root.musicPlayer.togglePlaying();

    }

    function musicNext() {
        if (root.musicPlayer && root.musicPlayer.canGoNext)
            root.musicPlayer.next();

    }

    function musicPrev() {
        if (root.musicPlayer && root.musicPlayer.canGoPrevious)
            root.musicPlayer.previous();

    }

    Item {
        visible: false

        Repeater {
            model: Mpris.players

            delegate: Item {
                required property MprisPlayer modelData

                Component.onCompleted: {
                    root.refreshMusic();
                    Qt.callLater(root.refreshMusic);
                }
                Component.onDestruction: root.refreshMusic()

                Connections {
                    function onPostTrackChanged() {
                        root.refreshMusic();
                    }

                    function onPlaybackStateChanged() {
                        root.refreshMusic();
                    }

                    function onMetadataChanged() {
                        root.refreshMusic();
                    }

                    function onTrackArtUrlChanged() {
                        root.refreshMusic();
                    }

                    target: modelData
                }

            }

        }

    }

}
