import QtQuick
import QtQuick.Shapes

// Desktop frame as one morphing Shape path (visual only).
// Attached widget backgrounds are cut into the workspace hole so the frame
// itself changes form instead of drawing a separate widget shell.
Item {
    id: fb

    required property var root
    required property var screen
    // When set, widget geometry is only drawn on this monitor.
    property string shellScreenName: ""
    readonly property real pw: width
    readonly property real ph: height
    readonly property int thickness: root.frameThickness
    readonly property int rounding: root.frameRounding
    // 4px frame rail on every edge except the bar side (barInset there).
    readonly property int frameEdge: thickness
    readonly property int barInset: root.barInset
    readonly property int cutTop: root.barEdge === "top" ? barInset : frameEdge
    readonly property int cutBottom: root.barEdge === "bottom" ? barInset : frameEdge
    readonly property int cutLeft: root.barEdge === "left" ? barInset : frameEdge
    readonly property int cutRight: root.barEdge === "right" ? barInset : frameEdge
    readonly property color frameColor: root.frameBg
    readonly property color widgetBorderColor: Qt.rgba(0.4, 0.4, 0.5, 0.3)
    readonly property real widgetBorderWidth: 1
    readonly property real widgetBorderFadeLength: 30
    readonly property real widgetBorderAlpha: widgetBorderColor.a * Math.max(0, Math.min(1, _widgetReveal))
    readonly property real arcK: 0.552285
    readonly property real joinR: rounding * 1.75
    readonly property bool widgetRequested: root.frameWidgetVisible && root.frameWidgetWidth > 0 && root.frameWidgetHeight > 0
    readonly property bool widgetScreenMatches: !root.frameWidgetScreen || !fb.shellScreenName || root.frameWidgetScreen === fb.shellScreenName
    readonly property bool widgetOnScreen: widgetRequested && widgetScreenMatches
    property real _widgetReveal: 0
    readonly property real holeX: cutLeft
    readonly property real holeY: cutTop
    readonly property real holeW: Math.max(0, pw - cutLeft - cutRight)
    readonly property real holeH: Math.max(0, ph - cutTop - cutBottom)
    readonly property real holeR: Math.min(rounding, Math.min(holeW, holeH) / 2)
    readonly property real holeRight: holeX + holeW
    readonly property real holeBottom: holeY + holeH
    readonly property real widgetAnchorX: root.popupAnchorX > 0 ? root.popupAnchorX : root.frameWidgetX + root.frameWidgetWidth / 2
    readonly property real widgetFullLeft: Math.max(holeX + holeR, Math.min(holeRight - holeR, root.frameWidgetX))
    readonly property real widgetFullRight: root.frameWidgetAttachRight ? holeRight : Math.max(widgetFullLeft, Math.min(holeRight - holeR, root.frameWidgetX + root.frameWidgetWidth))
    readonly property real widgetFullTop: holeY
    readonly property real widgetFullBottom: Math.max(holeY, Math.min(holeBottom - holeR, root.frameWidgetY + root.frameWidgetHeight))
    readonly property real widgetMorphCenter: root.frameWidgetAttachRight ? widgetFullRight : (widgetFullLeft + widgetFullRight) / 2
    readonly property real widgetFullWidth: Math.max(0, widgetFullRight - widgetFullLeft)
    readonly property real widgetRevealWidth: root.frameWidgetAttachRight ? widgetFullWidth * _widgetReveal : widgetFullWidth * (0.95 + 0.05 * _widgetReveal)
    readonly property real widgetLeft: root.frameWidgetAttachRight ? widgetFullRight - (widgetFullRight - widgetFullLeft) * _widgetReveal : widgetMorphCenter - widgetRevealWidth / 2
    readonly property real widgetRight: root.frameWidgetAttachRight ? widgetFullRight : widgetMorphCenter + widgetRevealWidth / 2
    readonly property real widgetBottom: widgetFullTop + (widgetFullBottom - widgetFullTop) * _widgetReveal
    readonly property real widgetCorner: Math.min(joinR, Math.max(0, (widgetRight - widgetLeft) / 2), Math.max(0, (widgetBottom - widgetFullTop) / 2))
    readonly property real widgetTopJoin: widgetCorner
    readonly property bool drawWidgetCut: root.barEdge === "top" && _widgetReveal > 0.001 && widgetScreenMatches && widgetRight - widgetLeft > 1 && widgetBottom - widgetFullTop > 1

    function syncWidgetReveal() {
        fb._widgetReveal = fb.widgetOnScreen ? 1 : 0;
        fb.requestWidgetBorderPaint();
    }

    function requestWidgetBorderPaint() {
        if (widgetBorderCanvas.available)
            widgetBorderCanvas.requestPaint();

    }

    anchors.fill: parent
    onWidthChanged: fb.requestWidgetBorderPaint()
    onHeightChanged: fb.requestWidgetBorderPaint()
    on_WidgetRevealChanged: fb.requestWidgetBorderPaint()
    onDrawWidgetCutChanged: fb.requestWidgetBorderPaint()
    onWidgetLeftChanged: fb.requestWidgetBorderPaint()
    onWidgetRightChanged: fb.requestWidgetBorderPaint()
    onWidgetBottomChanged: fb.requestWidgetBorderPaint()
    onWidgetCornerChanged: fb.requestWidgetBorderPaint()
    onWidgetTopJoinChanged: fb.requestWidgetBorderPaint()
    Component.onCompleted: fb.syncWidgetReveal()

    Connections {
        function onFrameWidgetVisibleChanged() {
            fb.syncWidgetReveal();
        }

        function onFrameWidgetScreenChanged() {
            fb.syncWidgetReveal();
        }

        function onFrameWidgetWidthChanged() {
            fb.syncWidgetReveal();
        }

        function onFrameWidgetHeightChanged() {
            fb.syncWidgetReveal();
        }

        function onFrameWidgetAttachRightChanged() {
            fb.syncWidgetReveal();
        }

        target: root
    }

    Shape {
        anchors.fill: parent

        // Default/calendar: top-attached widget with both top joins inverted
        // into the bar and both bottom free corners rounded.
        ShapePath {
            id: desktopRing

            readonly property real ix: fb.holeX
            readonly property real iy: fb.holeY
            readonly property real iw: fb.holeW
            readonly property real ih: fb.holeH
            readonly property real ir: fb.holeR
            readonly property real notchLeft: fb.drawWidgetCut ? fb.widgetLeft : desktopRing.ix + desktopRing.iw - desktopRing.ir
            readonly property real notchRight: fb.drawWidgetCut ? fb.widgetRight : desktopRing.ix + desktopRing.iw - desktopRing.ir
            readonly property real notchBottom: fb.drawWidgetCut ? fb.widgetBottom : fb.holeY
            readonly property real notchR: fb.drawWidgetCut ? fb.widgetCorner : 0
            readonly property real topJoinR: Math.min(fb.widgetTopJoin, Math.max(0, notchRight - notchLeft) / 2)

            fillColor: (!fb.drawWidgetCut || !root.frameWidgetAttachRight) ? fb.frameColor : "transparent"
            fillRule: ShapePath.OddEvenFill
            strokeWidth: 0
            startX: 0
            startY: 0

            PathLine {
                x: fb.pw
                y: 0
            }

            PathLine {
                x: fb.pw
                y: fb.ph
            }

            PathLine {
                x: 0
                y: fb.ph
            }

            PathLine {
                x: 0
                y: 0
            }

            PathMove {
                x: desktopRing.ix + desktopRing.ir
                y: desktopRing.iy
            }

            PathLine {
                x: Math.max(desktopRing.ix + desktopRing.ir, desktopRing.notchLeft - desktopRing.topJoinR)
                y: desktopRing.iy
            }

            PathArc {
                x: desktopRing.notchLeft
                y: desktopRing.iy + desktopRing.topJoinR
                radiusX: desktopRing.topJoinR
                radiusY: desktopRing.topJoinR
                direction: PathArc.Clockwise
            }

            PathLine {
                x: desktopRing.notchLeft
                y: desktopRing.notchBottom - desktopRing.notchR
            }

            PathArc {
                x: desktopRing.notchLeft + desktopRing.notchR
                y: desktopRing.notchBottom
                radiusX: desktopRing.notchR
                radiusY: desktopRing.notchR
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: desktopRing.notchRight - desktopRing.notchR
                y: desktopRing.notchBottom
            }

            PathArc {
                x: desktopRing.notchRight
                y: desktopRing.notchBottom - desktopRing.notchR
                radiusX: desktopRing.notchR
                radiusY: desktopRing.notchR
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: desktopRing.notchRight
                y: desktopRing.iy + desktopRing.topJoinR
            }

            PathArc {
                x: desktopRing.notchRight + desktopRing.topJoinR
                y: desktopRing.iy
                radiusX: desktopRing.topJoinR
                radiusY: desktopRing.topJoinR
                direction: PathArc.Clockwise
            }

            PathLine {
                x: desktopRing.ix + desktopRing.iw - desktopRing.ir
                y: desktopRing.iy
            }

            PathArc {
                x: desktopRing.ix + desktopRing.iw
                y: desktopRing.iy + desktopRing.ir
                radiusX: desktopRing.ir
                radiusY: desktopRing.ir
                direction: PathArc.Clockwise
            }

            PathLine {
                x: desktopRing.ix + desktopRing.iw
                y: desktopRing.iy + desktopRing.ih - desktopRing.ir
            }

            PathArc {
                x: desktopRing.ix + desktopRing.iw - desktopRing.ir
                y: desktopRing.iy + desktopRing.ih
                radiusX: desktopRing.ir
                radiusY: desktopRing.ir
                direction: PathArc.Clockwise
            }

            PathLine {
                x: desktopRing.ix + desktopRing.ir
                y: desktopRing.iy + desktopRing.ih
            }

            PathArc {
                x: desktopRing.ix
                y: desktopRing.iy + desktopRing.ih - desktopRing.ir
                radiusX: desktopRing.ir
                radiusY: desktopRing.ir
                direction: PathArc.Clockwise
            }

            PathLine {
                x: desktopRing.ix
                y: desktopRing.iy + desktopRing.ir
            }

            PathArc {
                x: desktopRing.ix + desktopRing.ir
                y: desktopRing.iy
                radiusX: desktopRing.ir
                radiusY: desktopRing.ir
                direction: PathArc.Clockwise
            }

        }

        // Media: top-right corner widget. The frame joins are inverted at the
        // widget's top-left and bottom-right; the bottom-left is the free
        // rounded widget corner.
        ShapePath {
            id: mediaRing

            readonly property real ix: fb.holeX
            readonly property real iy: fb.holeY
            readonly property real iw: fb.holeW
            readonly property real ih: fb.holeH
            readonly property real ir: fb.holeR
            readonly property real notchLeft: fb.widgetLeft
            readonly property real notchRight: fb.holeRight
            readonly property real notchBottom: fb.widgetBottom
            readonly property real notchR: fb.widgetCorner

            fillColor: fb.drawWidgetCut && root.frameWidgetAttachRight ? fb.frameColor : "transparent"
            fillRule: ShapePath.OddEvenFill
            strokeWidth: 0
            startX: 0
            startY: 0

            PathLine {
                x: fb.pw
                y: 0
            }

            PathLine {
                x: fb.pw
                y: fb.ph
            }

            PathLine {
                x: 0
                y: fb.ph
            }

            PathLine {
                x: 0
                y: 0
            }

            PathMove {
                x: mediaRing.ix + mediaRing.ir
                y: mediaRing.iy
            }

            PathLine {
                x: Math.max(mediaRing.ix + mediaRing.ir, mediaRing.notchLeft - mediaRing.notchR)
                y: mediaRing.iy
            }

            PathArc {
                x: mediaRing.notchLeft
                y: mediaRing.iy + mediaRing.notchR
                radiusX: mediaRing.notchR
                radiusY: mediaRing.notchR
                direction: PathArc.Clockwise
            }

            PathLine {
                x: mediaRing.notchLeft
                y: mediaRing.notchBottom - mediaRing.notchR
            }

            PathArc {
                x: mediaRing.notchLeft + mediaRing.notchR
                y: mediaRing.notchBottom
                radiusX: mediaRing.notchR
                radiusY: mediaRing.notchR
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: mediaRing.notchRight - mediaRing.notchR
                y: mediaRing.notchBottom
            }

            PathArc {
                x: mediaRing.notchRight
                y: mediaRing.notchBottom + mediaRing.notchR
                radiusX: mediaRing.notchR
                radiusY: mediaRing.notchR
                direction: PathArc.Clockwise
            }

            PathLine {
                x: mediaRing.ix + mediaRing.iw
                y: mediaRing.iy + mediaRing.ih - mediaRing.ir
            }

            PathArc {
                x: mediaRing.ix + mediaRing.iw - mediaRing.ir
                y: mediaRing.iy + mediaRing.ih
                radiusX: mediaRing.ir
                radiusY: mediaRing.ir
                direction: PathArc.Clockwise
            }

            PathLine {
                x: mediaRing.ix + mediaRing.ir
                y: mediaRing.iy + mediaRing.ih
            }

            PathArc {
                x: mediaRing.ix
                y: mediaRing.iy + mediaRing.ih - mediaRing.ir
                radiusX: mediaRing.ir
                radiusY: mediaRing.ir
                direction: PathArc.Clockwise
            }

            PathLine {
                x: mediaRing.ix
                y: mediaRing.iy + mediaRing.ir
            }

            PathArc {
                x: mediaRing.ix + mediaRing.ir
                y: mediaRing.iy
                radiusX: mediaRing.ir
                radiusY: mediaRing.ir
                direction: PathArc.Clockwise
            }

        }

    }

    Canvas {
        id: widgetBorderCanvas

        function cssColor(c) {
            return "rgba(" + Math.round(c.r * 255) + ", " + Math.round(c.g * 255) + ", " + Math.round(c.b * 255) + ", " + c.a + ")";
        }

        function cssColorWithAlpha(c, alpha) {
            return "rgba(" + Math.round(c.r * 255) + ", " + Math.round(c.g * 255) + ", " + Math.round(c.b * 255) + ", " + alpha + ")";
        }

        function strokeFade(ctx, x1, y1, x2, y2, awayFromWidget) {
            const gradient = ctx.createLinearGradient(x1, y1, x2, y2);
            if (awayFromWidget) {
                gradient.addColorStop(0, cssColorWithAlpha(fb.widgetBorderColor, fb.widgetBorderAlpha));
                gradient.addColorStop(1, cssColorWithAlpha(fb.widgetBorderColor, 0));
            } else {
                gradient.addColorStop(0, cssColorWithAlpha(fb.widgetBorderColor, 0));
                gradient.addColorStop(1, cssColorWithAlpha(fb.widgetBorderColor, fb.widgetBorderAlpha));
            }
            ctx.save();
            ctx.strokeStyle = gradient;
            ctx.lineWidth = fb.widgetBorderWidth;
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
        visible: fb.drawWidgetCut
        onAvailableChanged: fb.requestWidgetBorderPaint()
        onVisibleChanged: fb.requestWidgetBorderPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (!fb.drawWidgetCut)
                return ;

            const k = fb.arcK;
            const r = Math.max(0, fb.widgetCorner);
            const topJoinR = Math.min(fb.widgetTopJoin, Math.max(0, fb.widgetRight - fb.widgetLeft) / 2);
            ctx.save();
            ctx.strokeStyle = cssColorWithAlpha(fb.widgetBorderColor, fb.widgetBorderAlpha);
            ctx.lineWidth = fb.widgetBorderWidth;
            ctx.lineCap = "butt";
            ctx.lineJoin = "round";
            ctx.beginPath();
            if (root.frameWidgetAttachRight) {
                const topStartX = Math.max(fb.holeX + fb.holeR, fb.widgetLeft - r);
                ctx.moveTo(topStartX, fb.widgetFullTop);
                ctx.bezierCurveTo(topStartX + r * k, fb.widgetFullTop, fb.widgetLeft, fb.widgetFullTop + r * (1 - k), fb.widgetLeft, fb.widgetFullTop + r);
                ctx.lineTo(fb.widgetLeft, fb.widgetBottom - r);
                ctx.bezierCurveTo(fb.widgetLeft, fb.widgetBottom - r * (1 - k), fb.widgetLeft + r * (1 - k), fb.widgetBottom, fb.widgetLeft + r, fb.widgetBottom);
                ctx.lineTo(fb.holeRight - r, fb.widgetBottom);
                ctx.bezierCurveTo(fb.holeRight - r * (1 - k), fb.widgetBottom, fb.holeRight, fb.widgetBottom + r * (1 - k), fb.holeRight, fb.widgetBottom + r);
            } else {
                const topStartX = Math.max(fb.holeX + fb.holeR, fb.widgetLeft - topJoinR);
                ctx.moveTo(topStartX, fb.widgetFullTop);
                ctx.bezierCurveTo(topStartX + topJoinR * k, fb.widgetFullTop, fb.widgetLeft, fb.widgetFullTop + topJoinR * (1 - k), fb.widgetLeft, fb.widgetFullTop + topJoinR);
                ctx.lineTo(fb.widgetLeft, fb.widgetBottom - r);
                ctx.bezierCurveTo(fb.widgetLeft, fb.widgetBottom - r * (1 - k), fb.widgetLeft + r * (1 - k), fb.widgetBottom, fb.widgetLeft + r, fb.widgetBottom);
                ctx.lineTo(fb.widgetRight - r, fb.widgetBottom);
                ctx.bezierCurveTo(fb.widgetRight - r * (1 - k), fb.widgetBottom, fb.widgetRight, fb.widgetBottom - r * (1 - k), fb.widgetRight, fb.widgetBottom - r);
                ctx.lineTo(fb.widgetRight, fb.widgetFullTop + topJoinR);
                ctx.bezierCurveTo(fb.widgetRight, fb.widgetFullTop + topJoinR * (1 - k), fb.widgetRight + topJoinR * (1 - k), fb.widgetFullTop, fb.widgetRight + topJoinR, fb.widgetFullTop);
            }
            ctx.stroke();
            ctx.restore();
            const fade = fb.widgetBorderFadeLength * Math.max(0, Math.min(1, fb._widgetReveal));
            if (fade <= 0)
                return ;

            if (root.frameWidgetAttachRight) {
                const topStartX = Math.max(fb.holeX + fb.holeR, fb.widgetLeft - r);
                strokeFade(ctx, Math.max(fb.holeX + fb.holeR, topStartX - fade), fb.widgetFullTop, topStartX, fb.widgetFullTop, false);
                strokeFade(ctx, fb.holeRight, fb.widgetBottom + r, fb.holeRight, Math.min(fb.holeBottom - fb.holeR, fb.widgetBottom + r + fade), true);
            } else {
                const topStartX = Math.max(fb.holeX + fb.holeR, fb.widgetLeft - topJoinR);
                const topEndX = fb.widgetRight + topJoinR;
                strokeFade(ctx, Math.max(fb.holeX + fb.holeR, topStartX - fade), fb.widgetFullTop, topStartX, fb.widgetFullTop, false);
                strokeFade(ctx, topEndX, fb.widgetFullTop, Math.min(fb.holeRight - fb.holeR, topEndX + fade), fb.widgetFullTop, true);
            }
        }
    }

    Behavior on _widgetReveal {
        NumberAnimation {
            duration: root.frameAnimationDuration
            easing.type: Easing.InOutCubic
        }

    }

}
