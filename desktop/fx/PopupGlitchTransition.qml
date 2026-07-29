import QtQuick
import "PopupResolution.js" as PopupResolution
import "PopupTiming.js" as PopupTiming

// Shared source-glitch timeline for every popup/widget.
//
// `phase` is linear animation time. Section coverage is intentionally
// front-loaded: 60% is constructed at phase 40% while resolution is still
// held at 32 px. Over the remaining 60% of time, the final 40% constructs
// while resolution resolves through 16 → 8 → 4 → 2 → 1 px.
//
// ContentGlitch owns the actual source resampling, RGB separation, and strip
// displacement. Hosts only bind its inputs to this controller.
Item {
    id: transition

    property int duration: 200
    property real closeDurationFactor: 0.6
    // Omni-strength content treatment. Frame-attached hosts still skip the
    // open delay so pocket and glyphs share one beat.
    property bool freeStanding: false
    property real openDelayFactor: freeStanding ? 0.1 : 0
    property real splitStrength: freeStanding ? 0.52 : 0.22
    property real splitPixels: freeStanding ? 3 : 1.25
    property real phase: 0
    property real seed: 0
    property real _pendingDurationFactor: 1
    property bool _pendingResetSeed: false

    readonly property real progress: PopupTiming.visibilityAt(phase)
    readonly property real quality: PopupResolution.qualityAt(phase)
    readonly property real resolutionPixels: PopupResolution.pixelsAt(phase)
    readonly property bool running: phaseAnim.running || openDelay.running
    readonly property bool effectActive: running
                                         || (phase > 0.0001 && phase < 0.9999)
    // `effectActive` answers whether the surface is transitioning.
    // `layerRequired` answers whether raw source content may be shown. They
    // intentionally differ at phase 0: hosts remain alive briefly after close,
    // so the zero-progress shader must stay attached until the host hides.
    readonly property bool layerRequired: running || phase < 0.9999
    signal opened()
    signal closed()

    function clamp01(value) {
        return Math.max(0, Math.min(1, value));
    }

    function animateTo(value, durationFactor, resetSeed) {
        const target = clamp01(value);
        const distance = Math.abs(target - phase);
        openDelay.stop();
        phaseAnim.stop();

        if (resetSeed)
            seed = Math.random() * 997;

        if (distance < 0.0001) {
            phase = target;
            if (target > 0.9999)
                opened();
            else if (target < 0.0001)
                closed();
            return;
        }

        phaseAnim.from = phase;
        phaseAnim.to = target;
        // Distance scaling keeps the phase velocity constant when an
        // interrupted close reverses into open (or vice versa).
        phaseAnim.duration = Math.max(1, duration * durationFactor * distance);
        phaseAnim.start();
    }

    function stopAt(value) {
        openDelay.stop();
        phaseAnim.stop();
        phase = clamp01(value);
    }

    function open(resetSeed, durationFactor) {
        const factor = durationFactor === undefined ? 1 : durationFactor;
        const freshOpen = resetSeed === undefined ? phase < 0.0001 : resetSeed;
        openDelay.stop();

        // Only a genuinely fresh open waits. Reversing an interrupted close
        // continues immediately from the current pixels without a dead frame.
        if (freshOpen && phase < 0.0001 && openDelayFactor > 0) {
            phaseAnim.stop();
            _pendingDurationFactor = factor;
            _pendingResetSeed = true;
            openDelay.interval = Math.max(1,
                                          Math.round(duration * factor
                                                     * openDelayFactor));
            openDelay.restart();
            return;
        }

        animateTo(1, factor, freshOpen);
    }

    function close(durationFactor) {
        openDelay.stop();
        animateTo(0,
                  durationFactor === undefined ? closeDurationFactor : durationFactor,
                  false);
    }

    Timer {
        id: openDelay

        repeat: false
        onTriggered: transition.animateTo(1, transition._pendingDurationFactor,
                                          transition._pendingResetSeed)
    }

    NumberAnimation {
        id: phaseAnim

        target: transition
        property: "phase"
        easing.type: Easing.Linear
        onFinished: {
            if (transition.phase > 0.9999)
                transition.opened();
            else if (transition.phase < 0.0001)
                transition.closed();
        }
    }
}
