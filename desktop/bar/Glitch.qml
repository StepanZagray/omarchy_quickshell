import QtQuick

// Timing/controller half of the hover glitch. The host installs a separate
// HoverGlitchEffect as its layer effect so the shader can sample the host's
// already-composed pixels without this controller becoming recursive input.
Item {
    id: glitchRoot

    required property var root
    readonly property real dur: glitchRoot.root.animationDuration
    readonly property bool active: beatAnim.running || qualityAnim.running
    property real beat: 1
    property real quality: 1
    property real seed: 0
    property real ox: 0
    property real oy: 0
    property real split: 0.15
    // Previous synthetic overlay used 0.42 strength. The source-only tint is
    // intentionally half of that, and still cannot exceed source coverage.
    property real accentMix: 0.16
    property color accent: glitchRoot.root.accent

    function fire(x, y) {
        beatAnim.stop();
        qualityAnim.stop();
        glitchRoot.ox = x;
        glitchRoot.oy = y;
        glitchRoot.seed = Math.random() * 997;
        glitchRoot.beat = 0;
        glitchRoot.quality = 0;
        beatAnim.start();
        qualityAnim.start();
    }

    NumberAnimation {
        id: beatAnim

        target: glitchRoot
        property: "beat"
        from: 0
        to: 1
        duration: glitchRoot.dur
        easing.type: Easing.InOutCubic
    }

    NumberAnimation {
        id: qualityAnim

        target: glitchRoot
        property: "quality"
        from: 0
        to: 1
        duration: glitchRoot.dur
        easing.type: Easing.BezierSpline
        // Same curve as popup content/frame: 50% quality at 80% time.
        easing.bezierCurve: [0.6, 0, 0.85, 0.488287, 1, 1]
    }

}
