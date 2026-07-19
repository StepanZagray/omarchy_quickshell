import QtQuick

// Paints the thin outline that joins a frame-attached popup to DesktopFrame.
//
// This component is deliberately separate from FrameBorder.qml: use this file
// for redraw triggers, stroke colour/width, fade length, and the calendar vs.
// right-attached-media outline. FrameBorder.qml owns only the frame geometry.
Canvas {
    id: canvas

    required property var frame

    function cssColorWithAlpha(c, alpha) {
        return "rgba(" + Math.round(c.r * 255) + ", " + Math.round(c.g * 255) + ", " + Math.round(c.b * 255) + ", " + alpha + ")";
    }

    function strokeFade(ctx, x1, y1, x2, y2, awayFromWidget) {
        const gradient = ctx.createLinearGradient(x1, y1, x2, y2);
        if (awayFromWidget) {
            gradient.addColorStop(0, cssColorWithAlpha(frame.widgetBorderColor, frame.widgetBorderAlpha));
            gradient.addColorStop(1, cssColorWithAlpha(frame.widgetBorderColor, 0));
        } else {
            gradient.addColorStop(0, cssColorWithAlpha(frame.widgetBorderColor, 0));
            gradient.addColorStop(1, cssColorWithAlpha(frame.widgetBorderColor, frame.widgetBorderAlpha));
        }
        ctx.save();
        ctx.strokeStyle = gradient;
        ctx.lineWidth = frame.widgetBorderWidth;
        ctx.lineCap = "butt";
        ctx.beginPath();
        ctx.moveTo(x1, y1);
        ctx.lineTo(x2, y2);
        ctx.stroke();
        ctx.restore();
    }

    anchors.fill: parent
    antialiasing: true
    renderTarget: Canvas.Image
    renderStrategy: Canvas.Immediate
    visible: frame.drawWidgetCut

    // Repaint after Canvas becomes usable and whenever the popup is shown or
    // hidden. Geometry changes are observed by FrameBorder.qml.
    onAvailableChanged: frame.requestWidgetBorderPaint()
    onVisibleChanged: frame.requestWidgetBorderPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (!frame.drawWidgetCut)
            return ;

        const k = frame.arcK;
        const r = Math.max(0, frame.widgetCorner);
        const topJoinR = Math.min(frame.widgetTopJoin, Math.max(0, frame.widgetRight - frame.widgetLeft) / 2);
        ctx.save();
        ctx.strokeStyle = cssColorWithAlpha(frame.widgetBorderColor, frame.widgetBorderAlpha);
        ctx.lineWidth = frame.widgetBorderWidth;
        ctx.lineCap = "butt";
        ctx.lineJoin = "round";
        ctx.beginPath();
        if (frame.root.frameWidgetAttachRight) {
            const topStartX = Math.max(frame.holeX + frame.holeR, frame.widgetLeft - r);
            ctx.moveTo(topStartX, frame.widgetFullTop);
            ctx.bezierCurveTo(topStartX + r * k, frame.widgetFullTop, frame.widgetLeft, frame.widgetFullTop + r * (1 - k), frame.widgetLeft, frame.widgetFullTop + r);
            ctx.lineTo(frame.widgetLeft, frame.widgetBottom - r);
            ctx.bezierCurveTo(frame.widgetLeft, frame.widgetBottom - r * (1 - k), frame.widgetLeft + r * (1 - k), frame.widgetBottom, frame.widgetLeft + r, frame.widgetBottom);
            ctx.lineTo(frame.holeRight - r, frame.widgetBottom);
            ctx.bezierCurveTo(frame.holeRight - r * (1 - k), frame.widgetBottom, frame.holeRight, frame.widgetBottom + r * (1 - k), frame.holeRight, frame.widgetBottom + r);
        } else {
            const topStartX = Math.max(frame.holeX + frame.holeR, frame.widgetLeft - topJoinR);
            ctx.moveTo(topStartX, frame.widgetFullTop);
            ctx.bezierCurveTo(topStartX + topJoinR * k, frame.widgetFullTop, frame.widgetLeft, frame.widgetFullTop + topJoinR * (1 - k), frame.widgetLeft, frame.widgetFullTop + topJoinR);
            ctx.lineTo(frame.widgetLeft, frame.widgetBottom - r);
            ctx.bezierCurveTo(frame.widgetLeft, frame.widgetBottom - r * (1 - k), frame.widgetLeft + r * (1 - k), frame.widgetBottom, frame.widgetLeft + r, frame.widgetBottom);
            ctx.lineTo(frame.widgetRight - r, frame.widgetBottom);
            ctx.bezierCurveTo(frame.widgetRight - r * (1 - k), frame.widgetBottom, frame.widgetRight, frame.widgetBottom - r * (1 - k), frame.widgetRight, frame.widgetBottom - r);
            ctx.lineTo(frame.widgetRight, frame.widgetFullTop + topJoinR);
            ctx.bezierCurveTo(frame.widgetRight, frame.widgetFullTop + topJoinR * (1 - k), frame.widgetRight + topJoinR * (1 - k), frame.widgetFullTop, frame.widgetRight + topJoinR, frame.widgetFullTop);
        }
        ctx.stroke();
        ctx.restore();

        const fade = frame.widgetBorderFadeLength * Math.max(0, Math.min(1, frame._widgetReveal));
        if (fade <= 0)
            return ;

        if (frame.root.frameWidgetAttachRight) {
            const topStartX = Math.max(frame.holeX + frame.holeR, frame.widgetLeft - r);
            strokeFade(ctx, Math.max(frame.holeX + frame.holeR, topStartX - fade), frame.widgetFullTop, topStartX, frame.widgetFullTop, false);
            strokeFade(ctx, frame.holeRight, frame.widgetBottom + r, frame.holeRight, Math.min(frame.holeBottom - frame.holeR, frame.widgetBottom + r + fade), true);
        } else {
            const topStartX = Math.max(frame.holeX + frame.holeR, frame.widgetLeft - topJoinR);
            const topEndX = frame.widgetRight + topJoinR;
            strokeFade(ctx, Math.max(frame.holeX + frame.holeR, topStartX - fade), frame.widgetFullTop, topStartX, frame.widgetFullTop, false);
            strokeFade(ctx, topEndX, frame.widgetFullTop, Math.min(frame.holeRight - frame.holeR, topEndX + fade), frame.widgetFullTop, true);
        }
    }
}
