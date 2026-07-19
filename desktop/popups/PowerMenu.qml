import "../quick"
import QtQuick

// Quickshell presentation of Omarchy's system menu. QuickPowerBody is shared
// with Omni so both entry points expose the same action set and commands.
CardWindow {
    id: powerMenu

    required property var root

    theme: root
    revealed: root.powerMenuVisible
    anchored: false
    cardWidth: 256
    layerNamespace: "omarchy-power"
    bodyPaddingTop: 16
    bodyPaddingBottom: 16
    bodyPaddingLeft: 16
    bodyPaddingRight: 16
    revealScaleFrom: 0.8
    revealFades: true
    contentOpenDelayFactor: 0.85
    contentOpenDurationFactor: 1
    contentCloseDurationFactor: 0.6
    onDismiss: powerMenu.root.powerMenuVisible = false
    onRevealedChanged: {
        if (revealed) {
            powerBody.kbdIndex = 0;
            powerBody.refreshAvailability();
        }
    }
    onKeyPressed: function(event) {
        if (powerBody.kbdHandle(event))
            event.accepted = true;

    }

    QuickPowerBody {
        id: powerBody

        width: parent.width
        root: powerMenu.root
        shell: powerMenu.root
        opacity: powerMenu.contentReveal
        onClose: powerMenu.root.powerMenuVisible = false

        transform: Translate {
            y: (1 - powerMenu.contentReveal) * -powerMenu.contentTravel
        }

    }

}
