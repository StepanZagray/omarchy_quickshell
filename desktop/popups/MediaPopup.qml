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
    cardWidth: 460
    contentOpenDelayFactor: 1
    contentOpenDurationFactor: 1
    contentCloseDurationFactor: 0.6
    layerNamespace: "omarchy-media"
    frameAttached: true
    frameAttachRight: true
    bodyPaddingBottom: 16
    bodyPaddingLeft: 8
    bodyPaddingRight: 0
    onDismiss: mediaPopup.root.mediaVisible = false
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

    Item {
        width: parent.width
        height: 150
        opacity: mediaPopup.contentReveal

        RowLayout {
            anchors.fill: parent
            spacing: 18

            Rectangle {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 150
                Layout.alignment: Qt.AlignVCenter
                radius: mediaPopup.root.cornerRadius
                color: Qt.rgba(mediaPopup.root.ink.r, mediaPopup.root.ink.g, mediaPopup.root.ink.b, 0.08)
                border.width: 0
                border.color: mediaPopup.root.sep
                clip: true

                Image {
                    anchors.fill: parent
                    source: mediaPopup.root.musicArtUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: mediaPopup.root.musicArtUrl.length === 0
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
                    spacing: 10

                    Repeater {
                        model: [{
                            "glyph": "󰒮",
                            "action": "prev"
                        }, {
                            "glyph": mediaPopup.root.musicPlaying ? mediaPopup.root.icoPause : "󰐊",
                            "action": "toggle"
                        }, {
                            "glyph": "󰒭",
                            "action": "next"
                        }]

                        delegate: Rectangle {
                            required property var modelData

                            width: modelData.action === "toggle" ? 54 : 42
                            height: 34
                            radius: mediaPopup.root.cornerRadius
                            color: controlMouse.containsMouse ? Qt.rgba(mediaPopup.root.ink.r, mediaPopup.root.ink.g, mediaPopup.root.ink.b, 0.12) : Qt.rgba(mediaPopup.root.ink.r, mediaPopup.root.ink.g, mediaPopup.root.ink.b, 0.05)
                            border.width: 0
                            border.color: mediaPopup.root.sep

                            Text {
                                anchors.centerIn: parent
                                text: modelData.glyph
                                color: mediaPopup.root.musicTitle.length > 0 ? mediaPopup.root.ink : mediaPopup.root.inkDeep
                                font.family: mediaPopup.root.mono
                                font.pixelSize: modelData.action === "toggle" ? 18 : 16
                            }

                            MouseArea {
                                id: controlMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: mediaPopup.root.musicTitle.length > 0
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
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

        transform: Translate {
            y: (1 - mediaPopup.contentReveal) * -mediaPopup.contentTravel
        }

    }

}
