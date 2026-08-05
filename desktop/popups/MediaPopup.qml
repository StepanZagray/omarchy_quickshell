import "../fx"
import "../quick"
import QtQuick
import QtQuick.Layouts

CardWindow {
    id: mediaPopup

    required property var root
    property string shellScreenName: ""
    readonly property string wantedScreen: root.popupAnchorScreen || root.focusedScreenName()
    readonly property bool targetScreen: mediaPopup.wantedScreen.length === 0 || mediaPopup.shellScreenName.length === 0 || mediaPopup.wantedScreen === mediaPopup.shellScreenName

    theme: root
    revealed: root.mediaVisible && mediaPopup.targetScreen
    frameScreenName: mediaPopup.shellScreenName
    cardWidth: 448
    contentOpenDelayFactor: 0
    contentOpenDurationFactor: 1
    contentCloseDurationFactor: 0.6
    layerNamespace: "omarchy-media"
    frameAttached: true
    frameAttachRight: true
    bodyPaddingTop: 8
    bodyPaddingBottom: 16
    bodyPaddingLeft: 0
    bodyPaddingRight: -4
    onDismiss: mediaPopup.root.mediaVisible = false
    onRevealedChanged: {
        if (revealed)
            artFrame.reloadCoverArt();
    }
    onKeyPressed: function(event) {
        if (event.key === Qt.Key_Q) {
            mediaPopup.root.mediaVisible = false;
            event.accepted = true;
        } else if (event.key === Qt.Key_Space) {
            mediaPopup.root.musicToggle();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            mediaPopup.root.musicPrev();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            mediaPopup.root.musicNext();
            event.accepted = true;
        }
    }

    Connections {
        target: mediaPopup.root
        function onMusicArtUrlChanged() {
            artFrame.reloadCoverArt();
        }
    }

    Item {
        width: parent.width
        height: 144

        RowLayout {
            anchors.fill: parent
            spacing: 16

            SquircleRect {
                id: artFrame

                function reloadCoverArt() {
                    const url = mediaPopup.root.musicArtUrl;
                    coverArt.source = "";
                    if (url.length > 0)
                        coverArt.source = url;
                }

                Layout.preferredWidth: 144
                Layout.preferredHeight: 144
                Layout.alignment: Qt.AlignVCenter
                root: mediaPopup.root
                color: Qt.rgba(mediaPopup.root.ink.r, mediaPopup.root.ink.g, mediaPopup.root.ink.b, 0.08)
                borderWidth: 0
                borderColor: mediaPopup.root.sep
                clipContents: true

                Image {
                    id: coverArt

                    anchors.fill: parent
                    source: mediaPopup.root.musicArtUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: status === Image.Ready
                    onStatusChanged: {
                        if (status === Image.Ready || status === Image.Error)
                            artFrame.refreshClipLayer();
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: mediaPopup.root.musicArtUrl.length === 0
                        || coverArt.status !== Image.Ready
                    text: mediaPopup.root.icoMusic
                    color: mediaPopup.root.inkDeep
                    font.family: mediaPopup.root.mono
                    font.pixelSize: 42
                }

            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    Layout.fillWidth: true
                    text: mediaPopup.root.musicTitle.length > 0 ? mediaPopup.root.musicTitle : "Nothing playing"
                    color: mediaPopup.root.ink
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    font.family: mediaPopup.root.mono
                    font.pixelSize: 24
                    font.weight: Font.Medium
                }

                Text {
                    Layout.fillWidth: true
                    text: mediaPopup.root.musicArtist.length > 0 ? mediaPopup.root.musicArtist : "Start media in any MPRIS-capable app"
                    color: mediaPopup.root.inkDeep
                    elide: Text.ElideRight
                    font.family: mediaPopup.root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 1.5
                }

                Item {
                    Layout.fillHeight: true
                }

                Row {
                    spacing: 8

                    Repeater {
                        model: [{
                            "glyph": "󰒮",
                            "action": "prev"
                        }, {
                            "glyph": mediaPopup.root.musicPlaying ? mediaPopup.root.icoPause : mediaPopup.root.icoPlay,
                            "action": "toggle"
                        }, {
                            "glyph": "󰒭",
                            "action": "next"
                        }]

                        delegate: QuickButton {
                            required property var modelData

                            root: mediaPopup.root
                            glyph: modelData.glyph
                            label: ""
                            implicitHeight: 36
                            implicitWidth: modelData.action === "toggle" ? implicitHeight + 12 : implicitHeight + 4
                            enabled: mediaPopup.root.musicTitle.length > 0
                            onClicked: {
                                if (modelData.action === "prev")
                                    mediaPopup.root.musicPrev();
                                else if (modelData.action === "next")
                                    mediaPopup.root.musicNext();
                                else
                                    mediaPopup.root.musicToggle();
                            }
                        }

                    }

                }

            }

        }

    }

}
