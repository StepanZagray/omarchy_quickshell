import QtQuick

// Masks a layer texture to a squircle silhouette. Used by SquircleRect when
// clipContents is enabled (album art, thumbnails).
ShaderEffect {
    id: fx

    property var source
    property real corner: 0
    property real cornerPower: 4
    property vector2d uSize: Qt.vector2d(width, height)
    property real uCorner: fx.corner
    property real uCornerPower: fx.cornerPower

    fragmentShader: Qt.resolvedUrl("shaders/squircleClip.frag.qsb")
}
