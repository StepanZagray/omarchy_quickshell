import QtQuick
import "Squircle.js" as Squircle

// Shared outer surface for popups. Its fourth-power superellipse matches the
// free corners drawn by FrameBorder instead of Qt Rectangle's circular arcs.
Item {
    id: surface

    property color color: "transparent"
    property color borderColor: "transparent"
    property real borderWidth: 0
    property real radius: 0
    property real power: 4

    // Keep stroke and AA inside the item bounds so small controls do not
    // bleed past their layout box (e.g. calendar day cells in a tight grid).
    readonly property real paintInset: surface.borderWidth > 0
                                         ? Math.ceil(surface.borderWidth * 0.5) + 0.5
                                         : 0.5

    onColorChanged: canvas.requestPaint()
    onBorderColorChanged: canvas.requestPaint()
    onBorderWidthChanged: canvas.requestPaint()
    onRadiusChanged: canvas.requestPaint()
    onPowerChanged: canvas.requestPaint()

    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Immediate
        onAvailableChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (surface.width <= 0 || surface.height <= 0)
                return;

            const inset = surface.paintInset;
            const drawRadius = Math.max(0, surface.radius - inset);
            Squircle.traceRect(ctx, inset, drawRadius, surface.power,
                               surface.width, surface.height);
            ctx.fillStyle = surface.color;
            ctx.fill();

            if (surface.borderWidth > 0 && surface.borderColor.a > 0) {
                const strokeInset = inset + surface.borderWidth / 2;
                Squircle.traceRect(ctx, strokeInset,
                                   Math.max(0, surface.radius - strokeInset),
                                   surface.power, surface.width, surface.height);
                ctx.strokeStyle = surface.borderColor;
                ctx.lineWidth = surface.borderWidth;
                ctx.stroke();
            }
        }
    }
}
