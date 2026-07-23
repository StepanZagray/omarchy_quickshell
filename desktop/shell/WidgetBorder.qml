import QtQuick
import QtQuick.Shapes

// Shared outline for every frame-attached popup. Calendar, media, power, and
// OSD all use the same sampled n=4 superellipse, vector stroke, and rail fades;
// only the edge-attachment geometry changes. Geometry comes from a PocketHost
// slot so each popup morphs independently.
Item {
    id: border

    required property var frame
    required property var pocket
    readonly property real lineWidth: frame.widgetBorderWidth
    readonly property real reveal: pocket.reveal
    readonly property real widgetLeft: pocket.widgetLeft
    readonly property real widgetRight: pocket.widgetRight
    readonly property real widgetTop: pocket.widgetTop
    readonly property real widgetBottom: pocket.widgetBottom
    readonly property real widgetFullTop: pocket.fullTop
    readonly property real radius: Math.max(0, pocket.widgetCorner)
    readonly property real topJoinRadius: Math.min(radius, Math.max(0, (widgetRight - widgetLeft) / 2))
    readonly property real fadeLength: frame.widgetBorderFadeLength * Math.max(0, Math.min(1, reveal))
    readonly property bool attachBottomRight: pocket.attachBottom && pocket.attachRight
    readonly property bool attachRight: !attachBottomRight && pocket.attachRight
    readonly property bool attachLeft: pocket.attachLeft
    readonly property real borderAlpha: pocket.borderAlpha
    readonly property color lineColor: Qt.rgba(frame.widgetBorderColor.r, frame.widgetBorderColor.g, frame.widgetBorderColor.b, borderAlpha)
    readonly property bool drawCut: pocket.drawCut
    readonly property var outlinePoints: buildOutline()
    readonly property var fadeSegments: buildFades()

    function cssColorWithAlpha(color, alpha) {
        return "rgba(" + Math.round(color.r * 255) + ", " + Math.round(color.g * 255) + ", " + Math.round(color.b * 255) + ", " + alpha + ")";
    }

    function requestFadePaint() {
        if (fadeCanvas.available)
            fadeCanvas.requestPaint();

    }

    function requestPaints() {
        border.requestFadePaint();
    }

    function appendLine(points, x, y) {
        points.push(Qt.point(x, y));
    }

    // Same corner construction as FrameBorder.strokeSquircleCorner(), emitted
    // as points for Qt Quick Shapes instead of a raster Canvas path.
    function appendCorner(points, sx, sy, r, rot, clockwise) {
        if (r <= 0.001) {
            border.appendLine(points, sx, sy);
            return ;
        }
        const power = border.frame.roundingPower;
        const steps = border.frame.cornerSteps;
        for (let i = 1; i <= steps; i++) {
            const t = clockwise ? i / steps : 1 - i / steps;
            const offset = border.frame.squircleOffset(t, power);
            const local = border.frame.rotateCorner(offset[0] * r, offset[1] * r, rot);
            const cx = sx + (rot === 0 || rot === 1 ? -r : r);
            const cy = sy + (rot === 0 || rot === 3 ? r : -r);
            border.appendLine(points, cx + local[0], cy + local[1]);
        }
    }

    function buildOutline() {
        const points = [];
        if (!border.drawCut)
            return points;

        const r = border.radius;
        const joinR = border.topJoinRadius;
        const L = border.widgetLeft;
        const R = border.widgetRight;
        const T = border.widgetFullTop;
        const B = border.widgetBottom;
        if (border.attachBottomRight) {
            border.appendLine(points, border.frame.holeRight, border.widgetTop - r);
            border.appendCorner(points, border.frame.holeRight, border.widgetTop, r, 1, true);
            border.appendLine(points, L + r, border.widgetTop);
            border.appendCorner(points, L, border.widgetTop, r, 3, false);
            border.appendLine(points, L, B - r);
            border.appendCorner(points, L, B, r, 1, true);
        } else if (border.attachRight) {
            const topStartX = Math.max(border.frame.holeX + border.frame.holeR, L - r);
            border.appendLine(points, topStartX, T);
            border.appendCorner(points, L, T, r, 0, true);
            border.appendLine(points, L, B - r);
            border.appendCorner(points, L, B, r, 2, false);
            border.appendLine(points, border.frame.holeRight - r, B);
            border.appendCorner(points, border.frame.holeRight, B, r, 0, true);
        } else if (border.attachLeft) {
            border.appendLine(points, border.frame.holeX, B + r);
            border.appendCorner(points, border.frame.holeX, B, r, 3, true);
            border.appendLine(points, R - r, B);
            border.appendCorner(points, R, B, r, 1, false);
            border.appendLine(points, R, T + joinR);
            border.appendCorner(points, R, T, joinR, 3, true);
        } else {
            const topStartX = Math.max(border.frame.holeX + border.frame.holeR, L - joinR);
            border.appendLine(points, topStartX, T);
            border.appendCorner(points, L, T, joinR, 0, true);
            border.appendLine(points, L, B - r);
            border.appendCorner(points, L, B, r, 2, false);
            border.appendLine(points, R - r, B);
            border.appendCorner(points, R, B, r, 1, false);
            border.appendLine(points, R, T + joinR);
            border.appendCorner(points, R, T, joinR, 3, true);
        }
        return points;
    }

    // Fade descriptors use increasing screen coordinates. startSolid selects
    // whether the low-coordinate end begins opaque or transparent.
    function segment(vertical, position, start, end, startSolid) {
        return {
            "vertical": vertical,
            "position": position,
            "start": Math.min(start, end),
            "length": Math.max(0, Math.abs(end - start)),
            "startSolid": start <= end ? startSolid : !startSolid
        };
    }

    function buildFades() {
        const segments = [];
        if (!border.drawCut || border.fadeLength <= 0)
            return segments;

        const r = border.radius;
        const joinR = border.topJoinRadius;
        const fade = border.fadeLength;
        const L = border.widgetLeft;
        const R = border.widgetRight;
        const T = border.widgetFullTop;
        const B = border.widgetBottom;
        if (border.attachBottomRight) {
            segments.push(border.segment(true, border.frame.holeRight, border.widgetTop - r - fade, border.widgetTop - r, false));
            segments.push(border.segment(false, B, L - r - fade, L - r, false));
        } else if (border.attachRight) {
            const topStartX = Math.max(border.frame.holeX + border.frame.holeR, L - r);
            segments.push(border.segment(false, T, Math.max(border.frame.holeX + border.frame.holeR, topStartX - fade), topStartX, false));
            segments.push(border.segment(true, border.frame.holeRight, B + r, Math.min(border.frame.holeBottom - border.frame.holeR, B + r + fade), true));
        } else if (border.attachLeft) {
            const topEndX = R + joinR;
            segments.push(border.segment(false, T, topEndX, Math.min(border.frame.holeRight - border.frame.holeR, topEndX + fade), true));
            segments.push(border.segment(true, border.frame.holeX, B + r, Math.min(border.frame.holeBottom - border.frame.holeR, B + r + fade), true));
        } else {
            const topStartX = Math.max(border.frame.holeX + border.frame.holeR, L - joinR);
            const topEndX = R + joinR;
            segments.push(border.segment(false, T, Math.max(border.frame.holeX + border.frame.holeR, topStartX - fade), topStartX, false));
            segments.push(border.segment(false, T, topEndX, Math.min(border.frame.holeRight - border.frame.holeR, topEndX + fade), true));
        }
        return segments;
    }

    anchors.fill: parent
    visible: drawCut
    onWidthChanged: border.requestPaints()
    onHeightChanged: border.requestPaints()
    onVisibleChanged: border.requestPaints()
    onFadeSegmentsChanged: border.requestPaints()
    onLineColorChanged: border.requestFadePaint()
    onLineWidthChanged: border.requestFadePaint()
    Component.onCompleted: border.requestPaints()

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: border.lineColor
            strokeWidth: border.lineWidth
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"
            startX: border.outlinePoints.length > 0 ? border.outlinePoints[0].x : 0
            startY: border.outlinePoints.length > 0 ? border.outlinePoints[0].y : 0

            PathPolyline {
                path: border.outlinePoints
            }

        }

    }

    // Keep the long rail continuations as real stroked gradients. A 1px
    // Rectangle gradient can disappear after layer blur/alpha composition;
    // Canvas preserves line coverage and changes only the border alpha.
    Canvas {
        id: fadeCanvas

        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
        onAvailableChanged: border.requestFadePaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const solid = border.lineColor.a;
            for (let i = 0; i < border.fadeSegments.length; ++i) {
                const segment = border.fadeSegments[i];
                const x1 = segment.vertical ? segment.position : segment.start;
                const y1 = segment.vertical ? segment.start : segment.position;
                const x2 = segment.vertical ? segment.position : segment.start + segment.length;
                const y2 = segment.vertical ? segment.start + segment.length : segment.position;
                const gradient = ctx.createLinearGradient(x1, y1, x2, y2);
                gradient.addColorStop(0, border.cssColorWithAlpha(border.lineColor, segment.startSolid ? solid : 0));
                gradient.addColorStop(1, border.cssColorWithAlpha(border.lineColor, segment.startSolid ? 0 : solid));
                ctx.strokeStyle = gradient;
                ctx.lineWidth = border.lineWidth;
                ctx.lineCap = "butt";
                ctx.beginPath();
                ctx.moveTo(x1, y1);
                ctx.lineTo(x2, y2);
                ctx.stroke();
            }
        }
    }

}
