import QtQuick
import "PopupResolution.js" as PopupResolution

// Glitch pass for popup open and close. It keeps the hover glitch's normalized
// 18-step linear beat, compressed into the popup's native open/close durations.
//
// A popup is made of two layer-shell surfaces: frame-attached ones get their
// background from FrameBorder's pocket (omarchy-shell-visual) and only their
// glyphs from CardWindow (omarchy-card); free-standing ones draw both in
// CardWindow. A shader cannot sample across wl_surfaces, so this is a pure
// overlay with no source texture — which lets whichever surface actually owns
// the popup's background host it, and only that one.
//
// Declared before the host's content so the cells sit underneath it, same as
// bar/Glitch.qml.
Item {
    id: fx

    required property var theme

    // This item's top-left in screen coordinates. The lattice is laid out in
    // screen space so the pattern stays put while the pocket morphs open —
    // an item-space grid would swim sideways as the item resizes.
    property real originX: 0
    property real originY: 0
    // Scale applied by the popup parent. Shader coordinates are converted back
    // to physical screen space so the overlay lattice does not shrink with it.
    property real visualScale: 1

    property real corner: 0
    property real cornerPower: 4
    property real strength: 0.35
    property size cell: Qt.size(5, 4)
    // Defaults to this pass's own linear transition progress. Hosts with a
    // shared ContentGlitch controller bind this property to the controller's
    // value so both passes sample the exact same blocks on every frame.
    property real resolutionPixels: PopupResolution.pixelsAt(fx.quality)
    readonly property size resolvedCell: Qt.size(
        Math.max(1, resolutionPixels), Math.max(1, resolutionPixels))

    property int openDuration: fx.theme.animationDuration
    property real closeDurationFactor: 0.6
    readonly property int closeDuration: Math.round(fx.openDuration * fx.closeDurationFactor)
    property int currentDuration: openDuration

    // `quality` is raw linear popup progress: 0 = closed, 1 = open. The shared
    // helper turns it into the ease-in quality / pixel curve.
    property real quality: 1
    property real phase: 1
    property real seed: 0
    property bool closing: false
    readonly property bool active: qualityOpenAnim.running
        || qualityCloseAnim.running || phaseAnim.running

    function start(toValue, resetValue, durationMs) {
        qualityOpenAnim.stop();
        qualityCloseAnim.stop();
        phaseAnim.stop();
        if (resetValue >= 0)
            fx.quality = resetValue;

        fx.currentDuration = Math.max(1, durationMs);
        fx.closing = toValue < fx.quality;
        fx.seed = Math.random() * 997;
        fx.phase = 0;
        const qualityAnimation = fx.closing ? qualityCloseAnim : qualityOpenAnim;
        qualityAnimation.from = fx.quality;
        qualityAnimation.to = toValue;
        qualityAnimation.duration = fx.currentDuration;
        phaseAnim.duration = fx.currentDuration;
        qualityAnimation.start();
        phaseAnim.start();
    }

    function open(reset) {
        fx.start(1, reset ? 0 : -1, fx.openDuration);
    }

    function close() {
        fx.start(0, -1, fx.closeDuration);
    }

    function stopAt(value) {
        qualityOpenAnim.stop();
        qualityCloseAnim.stop();
        phaseAnim.stop();
        fx.quality = value;
        fx.phase = 1;
        fx.closing = false;
    }

    // Compatibility for existing callers: a fresh open.
    function fire() {
        fx.open(true);
    }

    ShaderEffect {
        anchors.fill: parent
        // Nothing to draw outside the beat, and an idle ShaderEffect sitting on
        // the frame surface is not free.
        visible: fx.active
        fragmentShader: "shaders/bootGlitch.frag.qsb"

        property real uQuality: PopupResolution.qualityAt(fx.quality)
        property real uTime: fx.phase * fx.currentDuration / 1000
        property real uSeed: fx.seed
        property real uVisualScale: fx.visualScale
        property vector2d uSize: Qt.vector2d(width, height)
        property vector2d uOrigin: Qt.vector2d(fx.originX, fx.originY)
        property vector2d uCell: Qt.vector2d(fx.resolvedCell.width,
                                             fx.resolvedCell.height)
        // Preserve the hover's 18 stepped redraws per beat even though this
        // entire beat is compressed into 200ms open / 120ms close.
        property real uFps: 18 / Math.max(0.001, fx.currentDuration / 1000)
        property real uCorner: fx.corner
        property real uCornerPower: fx.cornerPower
        property real uSplit: 0.30
        property real uAlpha: fx.strength
        property color uInk: fx.theme.ink
        property color uAccent: fx.theme.accent
    }

    // Linear raw progress lets PopupResolution apply the same ease-in curve
    // as ContentGlitch. Close traverses the same function backwards.
    NumberAnimation {
        id: qualityOpenAnim

        target: fx
        property: "quality"
        duration: fx.currentDuration
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: qualityCloseAnim

        target: fx
        property: "quality"
        duration: fx.currentDuration
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: phaseAnim

        target: fx
        property: "phase"
        from: 0
        to: 1
        duration: fx.currentDuration
        easing.type: Easing.InOutCubic
    }

}
