// Desktop frame as one morphing filled path (visual only).
// Attached widget backgrounds are cut into the workspace hole so the frame
// itself changes form instead of drawing a separate widget shell.
//
// Each frame-attached popup owns an independent pocket slot. Geometry is
// snapshotted into that slot — never live-bound to root.frameWidget* — so two
// popups can open/close in parallel without lines jumping across the monitor.

import QtQuick
import QtQuick.Shapes

// Corner curves sample the same superellipse Hyprland uses
// (decoration:rounding_power = 4 → squircle). Drawn via Canvas so coverage
// AA stays clean under Hyprland blur + ignore_alpha (baked-in alpha on Shape
// fringes caused the bright edge speckles).
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
    readonly property int cutTop: barInset
    readonly property int cutBottom: frameEdge
    readonly property int cutLeft: frameEdge
    readonly property int cutRight: frameEdge
    readonly property color frameColor: root.frameBg
    // Opaque RGB — overall translucency is canvas.opacity so AA fringes are
    // opaque→transparent, then multiplied by opacity (blur-safe).
    readonly property color frameFill: Qt.rgba(frameColor.r, frameColor.g, frameColor.b, 1)
    readonly property color widgetBorderColor: Qt.rgba(0.4, 0.4, 0.5, 0.32)
    readonly property real widgetBorderWidth: 1
    readonly property real widgetBorderFadeLength: 48
    // Match hypr looknfeel (do not edit hypr from here): rounding=6, sides
    // gaps_out - frameThickness = 3. Hole edge span is windowR+gap; the curve
    // itself is a Euclidean offset of the window squircle so the gap stays
    // constant (a larger superellipse alone widens the corner gap for n>2).
    readonly property real windowRounding: 6
    readonly property real windowGap: 3
    readonly property real roundingPower: 4
    readonly property real joinR: Math.round(rounding * 1.75)
    readonly property int cornerSteps: 48
    readonly property bool widgetRequested: root.frameWidgetVisible && root.frameWidgetWidth > 0 && root.frameWidgetHeight > 0
    readonly property bool widgetScreenMatches: !root.frameWidgetScreen || !fb.shellScreenName || root.frameWidgetScreen === fb.shellScreenName
    readonly property bool widgetOnScreen: widgetRequested && widgetScreenMatches
    readonly property real holeX: cutLeft
    readonly property real holeY: cutTop
    readonly property real holeW: Math.max(0, pw - cutLeft - cutRight)
    readonly property real holeH: Math.max(0, ph - cutTop - cutBottom)
    readonly property real holeR: Math.min(rounding, Math.min(holeW, holeH) / 2)
    readonly property real holeRight: holeX + holeW
    readonly property real holeBottom: holeY + holeH
    readonly property bool drawWidgetCut: pocketA.drawCut || pocketB.drawCut

    // Independent morph slot. Geometry is written only when this slot is
    // assigned to a popup — never rebound to live root.frameWidget* props.
    component PocketHost: Item {
        id: pocket

        property string owner: ""
        property string screenName: ""
        property real fullLeft: 0
        property real fullRight: 0
        property real fullTop: 0
        property real fullBottom: 0
        property bool attachRight: false
        property bool attachLeft: false
        property bool attachBottom: false
        property real reveal: 0
        readonly property bool screenMatches: !screenName || !fb.shellScreenName || screenName === fb.shellScreenName
        readonly property real fullWidth: Math.max(0, fullRight - fullLeft)
        readonly property real fullHeight: Math.max(0, fullBottom - fullTop)
        readonly property real morphCenter: attachRight ? fullRight : attachLeft ? fullLeft : (fullLeft + fullRight) / 2
        readonly property bool edgeAttached: attachRight || attachLeft
        readonly property real mediaReveal: 0.8 + 0.2 * reveal
        readonly property real revealWidth: edgeAttached ? fullWidth * mediaReveal : fullWidth * (0.95 + 0.05 * reveal)
        readonly property real widgetLeft: attachRight ? fullRight - revealWidth : attachLeft ? fullLeft : morphCenter - revealWidth / 2
        readonly property real widgetRight: attachRight ? fullRight : attachLeft ? fullLeft + revealWidth : morphCenter + revealWidth / 2
        readonly property real widgetTop: attachBottom ? fullBottom - fullHeight * reveal : fullTop
        readonly property real widgetBottom: attachBottom ? fullBottom : fullTop + fullHeight * reveal
        readonly property real widgetCorner: Math.min(fb.joinR, Math.max(0, (widgetRight - widgetLeft) / 2), Math.max(0, (widgetBottom - widgetTop) / 2))
        readonly property bool drawCut: reveal > 0.001 && screenMatches && widgetRight - widgetLeft > 1 && widgetBottom - widgetTop > 1
        readonly property real borderAlpha: fb.widgetBorderColor.a * Math.max(0, Math.min(1, reveal))

        function setRevealInstant(value) {
            revealBehavior.enabled = false;
            pocket.reveal = value;
            revealBehavior.enabled = true;
        }

        function openFresh() {
            pocket.setRevealInstant(0);
            pocket.reveal = 1;
        }

        function ensureOpen() {
            pocket.reveal = 1;
        }

        function closeAnim() {
            pocket.reveal = 0;
        }

        function applyGeometry(geo) {
            pocket.fullLeft = geo.fullLeft;
            pocket.fullRight = geo.fullRight;
            pocket.fullTop = geo.fullTop;
            pocket.fullBottom = geo.fullBottom;
            pocket.attachRight = geo.attachRight;
            pocket.attachLeft = geo.attachLeft;
            pocket.attachBottom = geo.attachBottom;
            pocket.screenName = geo.screenName;
        }

        // Owner stays until overwritten. Reuse keys off reveal <= 0.001 so an
        // openFresh() instant-zero cannot wipe the owner mid-assign.
        onRevealChanged: fb.requestPaints()
        onDrawCutChanged: fb.requestPaints()
        onWidgetLeftChanged: fb.requestPaints()
        onWidgetRightChanged: fb.requestPaints()
        onWidgetTopChanged: fb.requestPaints()
        onWidgetBottomChanged: fb.requestPaints()

        Behavior on reveal {
            id: revealBehavior

            NumberAnimation {
                duration: fb.root.frameAnimationDuration
                easing.type: Easing.InOutCubic
            }
        }

        WidgetBorder {
            anchors.fill: parent
            frame: fb
            pocket: pocket
        }
    }

    // Unit quarter in local space: start (0,-1) → end (1,0), center at origin.
    // Matches Hyprland rounding.glsl: (x^n + y^n)^(1/n) = 1.
    function squircleOffset(t, power) {
        const ang = t * Math.PI / 2;
        const dx = Math.sin(ang);
        const dy = -Math.cos(ang);
        const s = 1 / Math.pow(Math.pow(Math.abs(dx), power) + Math.pow(Math.abs(dy), power), 1 / power);
        return [dx * s, dy * s];
    }

    function rotateCorner(dx, dy, rot) {
        if (rot === 1)
            return [-dy, dx];

        if (rot === 2)
            return [-dx, -dy];

        if (rot === 3)
            return [dy, -dx];

        return [dx, dy];
    }

    // Outward unit normal of an L_n ball at local point (lx, ly).
    function squircleNormal(lx, ly, power) {
        const ax = Math.abs(lx);
        const ay = Math.abs(ly);
        let nx = ax < 1e-09 ? 0 : Math.pow(ax, power - 1) * (lx < 0 ? -1 : 1);
        let ny = ay < 1e-09 ? 0 : Math.pow(ay, power - 1) * (ly < 0 ? -1 : 1);
        const len = Math.hypot(nx, ny) || 1;
        return [nx / len, ny / len];
    }

    // Hole corners: Euclidean offset of the window squircle by windowGap.
    // rot/cw match strokeSquircleCorner. sx,sy = frame sharp corner.
    function strokeOffsetCorner(ctx, sx, sy, rot, cw) {
        const Rw = fb.windowRounding;
        const G = fb.windowGap;
        const Rf = Rw + G;
        if (Rf <= 0.001) {
            ctx.lineTo(sx, sy);
            return ;
        }
        const power = fb.roundingPower;
        const steps = fb.cornerSteps;
        const inwardX = (rot === 0 || rot === 1) ? -1 : 1;
        const inwardY = (rot === 0 || rot === 3) ? 1 : -1;
        // Window corner center (concentric with the ideal parallel frame corner).
        const winCx = sx + inwardX * (G + Rw);
        const winCy = sy + inwardY * (G + Rw);
        for (let i = 1; i <= steps; i++) {
            const t = cw ? (i / steps) : (1 - i / steps);
            const o = fb.squircleOffset(t, power);
            const lx = o[0] * Rw;
            const ly = o[1] * Rw;
            const local = fb.rotateCorner(lx, ly, rot);
            const nLocal = fb.squircleNormal(lx, ly, power);
            const n = fb.rotateCorner(nLocal[0], nLocal[1], rot);
            ctx.lineTo(winCx + local[0] + G * n[0], winCy + local[1] + G * n[1]);
        }
    }

    // rot: 0=TR, 1=BR, 2=BL, 3=TL — clockwise around the hole.
    // cw=false walks the same quadrant counter-clockwise (free widget corners).
    function strokeSquircleCorner(ctx, sx, sy, r, rot, cw) {
        if (r <= 0.001) {
            ctx.lineTo(sx, sy);
            return ;
        }
        const power = fb.roundingPower;
        const steps = fb.cornerSteps;
        for (let i = 1; i <= steps; i++) {
            const t = cw ? (i / steps) : (1 - i / steps);
            const o = fb.squircleOffset(t, power);
            let lx = o[0] * r;
            let ly = o[1] * r;
            const local = fb.rotateCorner(lx, ly, rot);
            const cx = sx + (rot === 0 || rot === 1 ? -r : r);
            const cy = sy + (rot === 0 || rot === 3 ? r : -r);
            ctx.lineTo(cx + local[0], cy + local[1]);
        }
    }

    // Plain frame ring — pockets are filled independently on top so each popup
    // morphs without rewriting the shared hole path.
    function traceRing(ctx) {
        const ix = fb.holeX;
        const iy = fb.holeY;
        const iw = fb.holeW;
        const ih = fb.holeH;
        const ir = fb.holeR;
        const pw = fb.pw;
        const ph = fb.ph;
        ctx.moveTo(0, 0);
        ctx.lineTo(pw, 0);
        ctx.lineTo(pw, ph);
        ctx.lineTo(0, ph);
        ctx.closePath();
        if (iw <= 0 || ih <= 0)
            return ;

        ctx.moveTo(ix + ir, iy);
        ctx.lineTo(ix + iw - ir, iy);
        fb.strokeOffsetCorner(ctx, ix + iw, iy, 0, true);
        ctx.lineTo(ix + iw, iy + ih - ir);
        fb.strokeOffsetCorner(ctx, ix + iw, iy + ih, 1, true);
        ctx.lineTo(ix + ir, iy + ih);
        fb.strokeOffsetCorner(ctx, ix, iy + ih, 2, true);
        ctx.lineTo(ix, iy + ir);
        fb.strokeOffsetCorner(ctx, ix, iy, 3, true);
        ctx.closePath();
    }

    function fillPocket(ctx, pocket) {
        if (!pocket.drawCut)
            return ;

        const L = pocket.widgetLeft;
        const R = pocket.widgetRight;
        const T = pocket.fullTop;
        const B = pocket.widgetBottom;
        const r = pocket.widgetCorner;
        const joinR = Math.min(r, Math.max(0, (R - L) / 2));
        const attachBottomRight = pocket.attachBottom && pocket.attachRight;
        ctx.beginPath();
        if (attachBottomRight) {
            const widgetTop = pocket.widgetTop;
            ctx.moveTo(fb.holeRight, fb.holeBottom);
            ctx.lineTo(fb.holeRight, widgetTop - r);
            fb.strokeSquircleCorner(ctx, fb.holeRight, widgetTop, r, 1, true);
            ctx.lineTo(L + r, widgetTop);
            fb.strokeSquircleCorner(ctx, L, widgetTop, r, 3, false);
            ctx.lineTo(L, B - r);
            fb.strokeSquircleCorner(ctx, L, B, r, 1, true);
            ctx.closePath();
        } else if (pocket.attachRight) {
            const topStartX = Math.max(fb.holeX + fb.holeR, L - r);
            ctx.moveTo(topStartX, T);
            fb.strokeSquircleCorner(ctx, L, T, r, 0, true);
            ctx.lineTo(L, B - r);
            fb.strokeSquircleCorner(ctx, L, B, r, 2, false);
            ctx.lineTo(fb.holeRight - r, B);
            fb.strokeSquircleCorner(ctx, fb.holeRight, B, r, 0, true);
            ctx.lineTo(fb.holeRight, T);
            ctx.closePath();
        } else if (pocket.attachLeft) {
            // Top + left rails attached. Free edges: right + bottom.
            // Inverted joins flare into the top bar (TR) and left rail (BL);
            // BR is the only free convex corner. Mirror of attachRight.
            ctx.moveTo(R + joinR, T);
            fb.strokeSquircleCorner(ctx, R, T, joinR, 3, false);
            ctx.lineTo(R, B - r);
            fb.strokeSquircleCorner(ctx, R, B, r, 1, true);
            ctx.lineTo(fb.holeX + r, B);
            fb.strokeSquircleCorner(ctx, fb.holeX, B, r, 3, false);
            ctx.lineTo(fb.holeX, T);
            ctx.closePath();
        } else {
            const topStartX = Math.max(fb.holeX + fb.holeR, L - joinR);
            ctx.moveTo(topStartX, T);
            fb.strokeSquircleCorner(ctx, L, T, joinR, 0, true);
            ctx.lineTo(L, B - r);
            fb.strokeSquircleCorner(ctx, L, B, r, 2, false);
            ctx.lineTo(R - r, B);
            fb.strokeSquircleCorner(ctx, R, B, r, 1, false);
            ctx.lineTo(R, T + joinR);
            fb.strokeSquircleCorner(ctx, R, T, joinR, 3, true);
            ctx.closePath();
        }
        ctx.fillStyle = fb.frameFill;
        ctx.fill();
    }

    function requestFramePaint() {
        if (frameCanvas.available)
            frameCanvas.requestPaint();

    }

    function requestPaints() {
        fb.requestFramePaint();
    }

    // Snapshot the published CardWindow geometry into slot-local coords.
    function captureRootGeometry() {
        const attachLeft = root.frameWidgetAttachLeft;
        const attachRight = root.frameWidgetAttachRight;
        const attachBottom = root.frameWidgetAttachBottom;
        const fullLeft = attachLeft ? fb.holeX : Math.max(fb.holeX + fb.holeR, Math.min(fb.holeRight - fb.holeR, root.frameWidgetX));
        const fullRight = attachRight ? fb.holeRight : Math.max(fullLeft, Math.min(fb.holeRight - fb.holeR, root.frameWidgetX + root.frameWidgetWidth));
        const fullTop = attachBottom ? Math.max(fb.holeY + fb.holeR, Math.min(fb.holeBottom - fb.holeR, root.frameWidgetY)) : fb.holeY;
        const fullBottom = attachBottom ? fb.holeBottom : Math.max(fb.holeY, Math.min(fb.holeBottom - fb.holeR, root.frameWidgetY + root.frameWidgetHeight));
        return {
            "fullLeft": fullLeft,
            "fullRight": fullRight,
            "fullTop": fullTop,
            "fullBottom": fullBottom,
            "attachRight": attachRight,
            "attachLeft": attachLeft,
            "attachBottom": attachBottom,
            "screenName": root.frameWidgetScreen
        };
    }

    function slotForOwner(owner) {
        if (pocketA.owner === owner)
            return pocketA;

        if (pocketB.owner === owner)
            return pocketB;

        return null;
    }

    function canReuseSlot(slot, owner) {
        return slot.owner === "" || slot.owner === owner || slot.reveal <= 0.001;
    }

    function acquireSlot(owner) {
        const existing = fb.slotForOwner(owner);
        if (existing)
            return existing;

        if (fb.canReuseSlot(pocketA, owner))
            return pocketA;

        if (fb.canReuseSlot(pocketB, owner))
            return pocketB;

        // Both slots still morphing other owners (shouldn't happen with one
        // interactive popup). Snap the quieter close shut, then reuse — never
        // rewrite a live closing pocket's geometry in place.
        const victim = pocketA.reveal <= pocketB.reveal ? pocketA : pocketB;
        victim.setRevealInstant(0);
        victim.owner = "";
        victim.screenName = "";
        return victim;
    }

    function closeOtherSlots(keepOwner) {
        if (pocketA.owner !== keepOwner && pocketA.reveal > 0.001)
            pocketA.closeAnim();

        if (pocketB.owner !== keepOwner && pocketB.reveal > 0.001)
            pocketB.closeAnim();

    }

    // CardWindow publishes frameWidget*; each owner gets its own pocket slot.
    // Opening one never mutates another slot's geometry — both morph in parallel.
    function syncWidgetReveal() {
        if (fb.widgetOnScreen) {
            const owner = root.frameWidgetOwner;
            const geo = fb.captureRootGeometry();
            const slot = fb.acquireSlot(owner);
            const fresh = slot.owner !== owner || slot.reveal <= 0.001;
            slot.owner = owner;
            slot.applyGeometry(geo);
            if (fresh)
                slot.openFresh();
            else
                slot.ensureOpen();

            fb.closeOtherSlots(owner);
        } else {
            if (pocketA.reveal > 0.001)
                pocketA.closeAnim();

            if (pocketB.reveal > 0.001)
                pocketB.closeAnim();

        }
        fb.requestPaints();
        // frameWidgetVisible can land before geometry on the same publish;
        // retry next frame so the first open after reload still morphs.
        if (root.frameWidgetVisible && (root.frameWidgetWidth <= 0 || root.frameWidgetHeight <= 0))
            Qt.callLater(fb.syncWidgetReveal);

    }

    anchors.fill: parent
    onWidthChanged: fb.requestPaints()
    onHeightChanged: fb.requestPaints()
    onFrameColorChanged: fb.requestFramePaint()
    Component.onCompleted: fb.syncWidgetReveal()

    Connections {
        function onFrameWidgetVisibleChanged() {
            fb.syncWidgetReveal();
        }

        function onFrameWidgetOwnerChanged() {
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

        function onFrameWidgetAttachLeftChanged() {
            fb.syncWidgetReveal();
        }

        function onFrameWidgetAttachBottomChanged() {
            fb.syncWidgetReveal();
        }

        function onFrameWidgetXChanged() {
            fb.syncWidgetReveal();
        }

        function onFrameWidgetYChanged() {
            fb.syncWidgetReveal();
        }

        target: root
    }

    PocketHost {
        id: pocketA

        anchors.fill: parent
    }

    PocketHost {
        id: pocketB

        anchors.fill: parent
    }

    Canvas {
        id: frameCanvas

        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
        // Apply translucency here so edge coverage stays opaque→0 before blur.
        opacity: fb.frameColor.a
        onAvailableChanged: fb.requestFramePaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (width <= 0 || height <= 0)
                return ;

            ctx.beginPath();
            fb.traceRing(ctx);
            ctx.fillStyle = fb.frameFill;
            // Qt Canvas defaults to WindingFill. The HTML string "evenodd" is
            // ignored, so both CW subpaths filled solid and covered the display.
            ctx.fillRule = Qt.OddEvenFill;
            ctx.fill();
            // Each pocket is an independent fill — open and close never share a
            // hole path, so attachment-side switches cannot yank lines across.
            fb.fillPocket(ctx, pocketA);
            fb.fillPocket(ctx, pocketB);
        }
    }

}
