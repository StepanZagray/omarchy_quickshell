import QtQuick

// Source-only rendering half of Glitch.qml. Quickshell supplies `source` when
// this component is assigned to an Item's layer.effect.
ShaderEffect {
    id: fx

    property var source
    property real beat: 1
    property real quality: 1
    property real duration: 1
    property real seed: 0
    property real originX: 0
    property real originY: 0
    property real splitStrength: 0.20
    property real accentMix: 0.21
    property color accent: "transparent"

    property real uTime: fx.beat * fx.duration / 1000
    property real uProgress: fx.beat
    property real uQuality: fx.quality
    property real uSeed: fx.seed
    property vector2d uSize: Qt.vector2d(width, height)
    property vector2d uOrigin: Qt.vector2d(fx.originX, fx.originY)
    property real uFps: 18
    property real uSplitStrength: fx.splitStrength
    property real uAccentMix: fx.accentMix
    property color uAccent: fx.accent

    fragmentShader: Qt.resolvedUrl("shaders/hoverGlitch.frag.qsb")
}
