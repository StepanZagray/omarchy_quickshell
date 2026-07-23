import "../quick"
import QtQuick

// Quickshell presentation of Omarchy's system menu. QuickPowerBody is shared
// with Omni so both entry points expose the same action set and commands.
// Frame-attached like calendar/media — morphs into the top-left of the desktop
// frame instead of floating as a centred card.
CardWindow {
    id: powerMenuPopup

    required property var root
    property string shellScreenName: ""
    readonly property string wantedScreen: root.popupAnchorScreen || root.focusedScreenName()
    readonly property bool targetScreen: powerMenuPopup.wantedScreen.length === 0 || powerMenuPopup.shellScreenName.length === 0 || powerMenuPopup.wantedScreen === powerMenuPopup.shellScreenName

    theme: root
    revealed: root.powerMenuVisible && powerMenuPopup.targetScreen
    frameScreenName: powerMenuPopup.shellScreenName
    cardWidth: 256
    contentOpenDelayFactor: 1
    contentOpenDurationFactor: 1
    contentCloseDurationFactor: 0.6
    bodyPaddingTop: 16
    bodyPaddingBottom: 16
    bodyPaddingLeft: 4
    bodyPaddingRight: 8
    layerNamespace: "omarchy-power"
    frameAttached: true
    frameAttachLeft: true
    onDismiss: powerMenuPopup.root.powerMenuVisible = false
    onRevealedChanged: {
        if (revealed) {
            powerBody.kbdIndex = 0;
            powerBody.refreshAvailability();
        }
    }
    onKeyPressed: function(event) {
        if (event.key === Qt.Key_Q) {
            powerMenuPopup.root.powerMenuVisible = false;
            event.accepted = true;
        } else if (powerBody.kbdHandle(event)) {
            event.accepted = true;
        }
    }

    QuickPowerBody {
        id: powerBody

        width: parent.width
        root: powerMenuPopup.root
        shell: powerMenuPopup.root
        opacity: powerMenuPopup.contentReveal
        onClose: powerMenuPopup.root.powerMenuVisible = false

        transform: Translate {
            y: (1 - powerMenuPopup.contentReveal) * -powerMenuPopup.contentTravel
        }

    }

}
