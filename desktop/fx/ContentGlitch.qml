import QtQuick

// Source-only popup reveal. Frame-attached content keeps the directional fade;
// free-standing surfaces use a binary, centre-out section construction.
ShaderEffect {
    id: fx

    property var source
    property real progress: 1
    property real quality: 1
    property bool sectionReveal: false
    // Width of the randomized activation band around the centre-out order.
    // 0 is a strict geometric wave; 0.5 lets neighbouring rings interleave.
    property real sectionRandomness: 0.5
    // Travel direction. Open reveals along this vector; close is the same
    // animation in reverse. Cardinal examples:
    //   ( 1, 0) left -> right       (-1, 0) right -> left
    //   ( 0, 1) top  -> bottom      ( 0,-1) bottom -> top
    property vector2d direction: Qt.vector2d(0, 1)
    property real seed: 0
    property real splitStrength: 0.18
    property real splitPixels: 1.25
    // Exact source-sampling block size supplied by PopupGlitchTransition.
    property real resolutionPixels: 1
    // Parent popup scale. The shader compensates source-pixel distances so
    // blocks, tears, and channel separation retain their screen-space size.
    property real visualScale: 1
    property real fadeWidth: 0.16
    property real steps: 18
    // Final output clip. Free-standing popup hosts pass their shared outer
    // squircle here so displaced samples cannot square off its corners.
    property real corner: 0
    property real cornerPower: 4
    property color accent: "transparent"
    property vector2d uSize: Qt.vector2d(width, height)
    property real uProgress: fx.progress
    property real uQuality: fx.quality
    property real uSectionReveal: fx.sectionReveal ? 1 : 0
    property real uSectionRandomness: fx.sectionRandomness
    property vector2d uDirection: fx.direction
    property real uSeed: fx.seed
    property real uSplitStrength: fx.splitStrength
    property real uSplitPixels: fx.splitPixels
    property real uResolutionPixels: fx.resolutionPixels
    property real uVisualScale: fx.visualScale
    property real uFadeWidth: fx.fadeWidth
    property real uSteps: fx.steps
    property real uCorner: fx.corner
    property real uCornerPower: fx.cornerPower
    property color uAccent: fx.accent

    fragmentShader: Qt.resolvedUrl("shaders/contentGlitch.frag.qsb")
}
