import QtQuick

// Shared outer surface for popups. Its fourth-power superellipse matches the
// free corners drawn by FrameBorder instead of Qt Rectangle's circular arcs.
Item {
    id: surface

    property color color: "transparent"
    property color borderColor: "transparent"
    property real borderWidth: 0
    property real radius: 0
    property real power: 4

    function signedPower(value, exponent) {
        if (Math.abs(value) < 0.000001)
            return 0;

        return (value < 0 ? -1 : 1)
             * Math.pow(Math.abs(value), exponent);
    }

    function addCorner(ctx, centerX, centerY, radius, startAngle, endAngle) {
        const steps = 24;
        const exponent = 2 / Math.max(2, surface.power);
        for (let i = 1; i <= steps; i++) {
            const angle = startAngle + (endAngle - startAngle) * i / steps;
            const x = centerX + radius
                    * surface.signedPower(Math.cos(angle), exponent);
            const y = centerY + radius
                    * surface.signedPower(Math.sin(angle), exponent);
            ctx.lineTo(x, y);
        }
    }

    function trace(ctx, inset, requestedRadius) {
        const left = inset;
        const top = inset;
        const right = Math.max(left, surface.width - inset);
        const bottom = Math.max(top, surface.height - inset);
        const width = Math.max(0, right - left);
        const height = Math.max(0, bottom - top);
        const radius = Math.max(0, Math.min(requestedRadius,
                                            width / 2, height / 2));

        ctx.beginPath();
        if (radius <= 0.001) {
            ctx.rect(left, top, width, height);
            ctx.closePath();
            return;
        }

        ctx.moveTo(left + radius, top);
        ctx.lineTo(right - radius, top);
        surface.addCorner(ctx, right - radius, top + radius, radius,
                          -Math.PI / 2, 0);
        ctx.lineTo(right, bottom - radius);
        surface.addCorner(ctx, right - radius, bottom - radius, radius,
                          0, Math.PI / 2);
        ctx.lineTo(left + radius, bottom);
        surface.addCorner(ctx, left + radius, bottom - radius, radius,
                          Math.PI / 2, Math.PI);
        ctx.lineTo(left, top + radius);
        surface.addCorner(ctx, left + radius, top + radius, radius,
                          Math.PI, Math.PI * 1.5);
        ctx.closePath();
    }

    onColorChanged: canvas.requestPaint()
    onBorderColorChanged: canvas.requestPaint()
    onBorderWidthChanged: canvas.requestPaint()
    onRadiusChanged: canvas.requestPaint()
    onPowerChanged: canvas.requestPaint()

    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
        onAvailableChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (width <= 0 || height <= 0)
                return;

            surface.trace(ctx, 0, surface.radius);
            ctx.fillStyle = surface.color;
            ctx.fill();

            if (surface.borderWidth > 0 && surface.borderColor.a > 0) {
                const inset = surface.borderWidth / 2;
                surface.trace(ctx, inset,
                              Math.max(0, surface.radius - inset));
                ctx.strokeStyle = surface.borderColor;
                ctx.lineWidth = surface.borderWidth;
                ctx.stroke();
            }
        }
    }
}
