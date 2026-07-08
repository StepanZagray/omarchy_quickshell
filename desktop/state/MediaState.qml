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

    function openMedia() {
        if (shell.mediaAnchorItem)
            shell.anchorPopupTo(shell.mediaAnchorItem);

        if (!shell.popupAnchorScreen)
            shell.popupAnchorScreen = shell.focusedScreenName();

        shell.frameWidgetScreen = shell.popupAnchorScreen;
        root.refreshMusic();
        root.mediaVisible = true;
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
        root.musicArtUrl = best ? (best.trackArtUrl || "") : "";
        root.musicPlaying = best ? !!best.isPlaying : false;
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

                Component.onCompleted: root.refreshMusic()
                Component.onDestruction: root.refreshMusic()

                Connections {
                    function onPostTrackChanged() {
                        root.refreshMusic();
                    }

                    function onPlaybackStateChanged() {
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
