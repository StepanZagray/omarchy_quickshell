// Desktop frame as one filled path (visual only).
// Attached widget backgrounds are cut into the workspace hole so the frame
// itself changes form instead of drawing a separate widget shell.
// Each frame-attached popup owns an independent pocket slot. Geometry snaps
// to full size immediately; open/close construct the pocket with the same
// binary section + resolution ladder as Omni, swept along the widget's
// established direction. The hole boundary walks every open pocket silhouette
// in a single even-odd fill (no overlay), so the old rectangular hole edge
// cannot seam through an attached popup.

import "../fx"
import "../fx/PopupTiming.js" as PopupTiming
import "../fx/PopupResolution.js" as PopupResolution
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
    // Soft outward shadow, drawn entirely by WidgetBorder's one ShaderEffect
    // (shaders/pocketShadow.frag) — nothing else in the shell draws shadow.
    // Peak stays BELOW hypr ignore_alpha 0.65 on omarchy-shell-visual, so no
    // shadow pixel is ever re-blurred into a solid rim.
    readonly property real widgetShadowWidth: 14
    readonly property real widgetShadowMaxAlpha: 0.3
    // Gaussian falloff: slow at contact, strongest after the first few pixels,
    // then a faint tail to widgetShadowWidth. Higher strength makes the middle
    // drop stricter; width controls how long the tail remains visible.
    readonly property real widgetShadowFalloffStrength: 8
    // Where the shadow starts letting go, as a share of the join — 0 is the
    // join's start, at the panel edge. The fade then runs the same length the
    // outline's rail fade does (widgetBorderFadeLength), so shadow and border
    // dissolve over one zone.
    readonly property real widgetShadowJoinHold: 0
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
    readonly property bool pixelatingPockets: pocketA.pixelating || pocketB.pixelating
    // Full-display capture is intentional. A cropped replacement needs a hard
    // compositing boundary, which remains visible against the translucent frame
    // during coarse pixel stages.
    layer.enabled: fb.pixelatingPockets
    layer.smooth: false
    layer.effect: ShaderEffect {
        property var source
        property vector2d uSize: Qt.vector2d(fb.width, fb.height)
        property vector4d uRectA: pocketA.pixelating
            ? Qt.vector4d(pocketA.pixelLeft, pocketA.pixelTop,
                          pocketA.pixelWidth, pocketA.pixelHeight)
            : Qt.vector4d(0, 0, 0, 0)
        property vector4d uRectB: pocketB.pixelating
            ? Qt.vector4d(pocketB.pixelLeft, pocketB.pixelTop,
                          pocketB.pixelWidth, pocketB.pixelHeight)
            : Qt.vector4d(0, 0, 0, 0)
        property real uPixelsA: pocketA.pixelSize
        property real uPixelsB: pocketB.pixelSize
        property real uProgressA: pocketA.visibleReveal
        property real uProgressB: pocketB.visibleReveal
        property real uQualityA: pocketA.constructQuality
        property real uQualityB: pocketB.constructQuality
        property real uSeedA: pocketA.constructSeed
        property real uSeedB: pocketB.constructSeed
        property vector2d uDirectionA: pocketA.constructDirection
        property vector2d uDirectionB: pocketB.constructDirection
        property vector4d uCoreA: pocketA.pixelating
            ? Qt.vector4d(pocketA.coreLeft, pocketA.coreTop,
                          pocketA.coreWidth, pocketA.coreHeight)
            : Qt.vector4d(0, 0, 0, 0)
        property vector4d uCoreB: pocketB.pixelating
            ? Qt.vector4d(pocketB.coreLeft, pocketB.coreTop,
                          pocketB.coreWidth, pocketB.coreHeight)
            : Qt.vector4d(0, 0, 0, 0)

        fragmentShader: "shaders/pocketPixelate.frag.qsb"
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

    function activePockets() {
        const list = [];
        if (pocketA.drawCut)
            list.push(pocketA);

        if (pocketB.drawCut)
            list.push(pocketB);

        return list;
    }

    function pocketKind(pocket) {
        if (pocket.attachBottom && pocket.attachRight)
            return "bottomRight";

        if (pocket.attachRight)
            return "right";

        if (pocket.attachLeft)
            return "left";

        return "top";
    }

    // Free silhouette of a top-attached pocket, walked so a clockwise hole
    // path can splice it into the top edge (enter at left join, exit at right).
    function strokeTopPocketDetour(ctx, pocket) {
        const L = pocket.widgetLeft;
        const R = pocket.widgetRight;
        const T = pocket.fullTop;
        const B = pocket.widgetBottom;
        const r = pocket.widgetCorner;
        const joinR = Math.min(r, Math.max(0, (R - L) / 2));
        fb.strokeSquircleCorner(ctx, L, T, joinR, 0, true);
        ctx.lineTo(L, B - r);
        fb.strokeSquircleCorner(ctx, L, B, r, 2, false);
        ctx.lineTo(R - r, B);
        fb.strokeSquircleCorner(ctx, R, B, r, 1, false);
        ctx.lineTo(R, T + joinR);
        fb.strokeSquircleCorner(ctx, R, T, joinR, 3, true);
    }

    // attachLeft: top+left rails glued. Clockwise hole hits the left rail at
    // the BL join, walks free bottom→right→TR, and returns on the top edge.
    function strokeLeftPocketDetour(ctx, pocket) {
        const R = pocket.widgetRight;
        const T = pocket.fullTop;
        const B = pocket.widgetBottom;
        const r = pocket.widgetCorner;
        const joinR = Math.min(r, Math.max(0, (R - pocket.widgetLeft) / 2));
        fb.strokeSquircleCorner(ctx, fb.holeX, B, r, 3, true);
        ctx.lineTo(R - r, B);
        fb.strokeSquircleCorner(ctx, R, B, r, 1, false);
        ctx.lineTo(R, T + joinR);
        fb.strokeSquircleCorner(ctx, R, T, joinR, 3, true);
    }

    // attachRight: top+right rails glued. Clockwise hole leaves the top edge
    // at the TL join, walks free left→bottom→BR, and resumes on the right rail.
    function strokeRightPocketDetour(ctx, pocket) {
        const L = pocket.widgetLeft;
        const T = pocket.fullTop;
        const B = pocket.widgetBottom;
        const r = pocket.widgetCorner;
        fb.strokeSquircleCorner(ctx, L, T, r, 0, true);
        ctx.lineTo(L, B - r);
        fb.strokeSquircleCorner(ctx, L, B, r, 2, false);
        ctx.lineTo(fb.holeRight - r, B);
        fb.strokeSquircleCorner(ctx, fb.holeRight, B, r, 0, true);
    }

    // OSD: bottom+right rails glued. Clockwise hole leaves the right rail at
    // the top join, walks free top→left→BL, and resumes on the bottom edge.
    function strokeBottomRightPocketDetour(ctx, pocket) {
        const L = pocket.widgetLeft;
        const B = pocket.widgetBottom;
        const topY = pocket.widgetTop;
        const r = pocket.widgetCorner;
        fb.strokeSquircleCorner(ctx, fb.holeRight, topY, r, 1, true);
        ctx.lineTo(L + r, topY);
        fb.strokeSquircleCorner(ctx, L, topY, r, 3, false);
        ctx.lineTo(L, B - r);
        fb.strokeSquircleCorner(ctx, L, B, r, 1, true);
    }

    // One even-odd path: outer rect minus a hole whose boundary already walks
    // every open pocket silhouette. No second fill — that was the seam along
    // the old rectangular hole edge through attached popups.
    function traceFrame(ctx) {
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

        const pockets = fb.activePockets();
        let leftPocket = null;
        let rightPocket = null;
        let bottomRightPocket = null;
        const topPockets = [];
        for (let i = 0; i < pockets.length; i++) {
            const pocket = pockets[i];
            const kind = fb.pocketKind(pocket);
            if (kind === "left")
                leftPocket = pocket;
            else if (kind === "right")
                rightPocket = pocket;
            else if (kind === "bottomRight")
                bottomRightPocket = pocket;
            else
                topPockets.push(pocket);
        }
        topPockets.sort(function(a, b) {
            return a.widgetLeft - b.widgetLeft;
        });
        // Clockwise hole. Each pocket replaces the rectangular span it owns.
        if (leftPocket) {
            const R = leftPocket.widgetRight;
            const joinR = Math.min(leftPocket.widgetCorner, Math.max(0, (R - leftPocket.widgetLeft) / 2));
            // Start on the top edge just past the pocket's TR join.
            ctx.moveTo(R + joinR, iy);
            ctx.lineTo(ix + iw - ir, iy);
            fb.strokeOffsetCorner(ctx, ix + iw, iy, 0, true);
            if (bottomRightPocket) {
                ctx.lineTo(ix + iw, bottomRightPocket.widgetTop - bottomRightPocket.widgetCorner);
                fb.strokeBottomRightPocketDetour(ctx, bottomRightPocket);
            } else {
                ctx.lineTo(ix + iw, iy + ih - ir);
                fb.strokeOffsetCorner(ctx, ix + iw, iy + ih, 1, true);
            }
            ctx.lineTo(ix + ir, iy + ih);
            fb.strokeOffsetCorner(ctx, ix, iy + ih, 2, true);
            ctx.lineTo(ix, leftPocket.widgetBottom + leftPocket.widgetCorner);
            fb.strokeLeftPocketDetour(ctx, leftPocket);
            ctx.closePath();
            return ;
        }
        ctx.moveTo(ix + ir, iy);
        let topX = ix + ir;
        for (let t = 0; t < topPockets.length; t++) {
            const pocket = topPockets[t];
            const joinR = Math.min(pocket.widgetCorner, Math.max(0, (pocket.widgetRight - pocket.widgetLeft) / 2));
            const enterX = Math.max(ix + ir, pocket.widgetLeft - joinR);
            ctx.lineTo(enterX, iy);
            fb.strokeTopPocketDetour(ctx, pocket);
            topX = pocket.widgetRight + joinR;
        }
        if (rightPocket) {
            const enterX = Math.max(topX, Math.max(ix + ir, rightPocket.widgetLeft - rightPocket.widgetCorner));
            ctx.lineTo(enterX, iy);
            fb.strokeRightPocketDetour(ctx, rightPocket);
            if (bottomRightPocket) {
                ctx.lineTo(ix + iw, bottomRightPocket.widgetTop - bottomRightPocket.widgetCorner);
                fb.strokeBottomRightPocketDetour(ctx, bottomRightPocket);
            } else {
                ctx.lineTo(ix + iw, iy + ih - ir);
                fb.strokeOffsetCorner(ctx, ix + iw, iy + ih, 1, true);
            }
        } else {
            ctx.lineTo(Math.max(topX, ix + iw - ir), iy);
            fb.strokeOffsetCorner(ctx, ix + iw, iy, 0, true);
            if (bottomRightPocket) {
                ctx.lineTo(ix + iw, bottomRightPocket.widgetTop - bottomRightPocket.widgetCorner);
                fb.strokeBottomRightPocketDetour(ctx, bottomRightPocket);
            } else {
                ctx.lineTo(ix + iw, iy + ih - ir);
                fb.strokeOffsetCorner(ctx, ix + iw, iy + ih, 1, true);
            }
        }
        ctx.lineTo(ix + ir, iy + ih);
        fb.strokeOffsetCorner(ctx, ix, iy + ih, 2, true);
        ctx.lineTo(ix, iy + ir);
        fb.strokeOffsetCorner(ctx, ix, iy, 3, true);
        ctx.closePath();
    }

    function requestFramePaint() {
        if (frameCanvas.available)
            frameCanvas.requestPaint();

    }

    function requestPaints() {
        fb.requestFramePaint();
    }

    function paintFrame(canvas) {
        const ctx = canvas.getContext("2d");
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        if (canvas.width <= 0 || canvas.height <= 0)
            return ;

        ctx.beginPath();
        fb.traceFrame(ctx);
        ctx.fillStyle = fb.frameFill;
        // Qt Canvas defaults to WindingFill. The HTML string "evenodd" is
        // ignored, so both CW subpaths filled solid and covered the display.
        ctx.fillRule = Qt.OddEvenFill;
        ctx.fill();
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

    // One presentation tree. When a pocket animates the root layer captures
    // this entire item once and applies the pocket-aware full-display shader.
    Canvas {
        id: frameCanvas

        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
        opacity: fb.frameColor.a
        onAvailableChanged: fb.requestFramePaint()
        onPaint: fb.paintFrame(frameCanvas)
    }

    // A is last so its chrome and the shader's `if A else if B` overlap
    // priority agree during interrupted popup handoffs.
    PocketHost {
        id: pocketB

        anchors.fill: parent
    }

    PocketHost {
        id: pocketA

        anchors.fill: parent
    }

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
        readonly property real visibleReveal: PopupTiming.visibilityAt(reveal)
        readonly property bool screenMatches: !screenName || !fb.shellScreenName || screenName === fb.shellScreenName
        readonly property real fullWidth: Math.max(0, fullRight - fullLeft)
        readonly property real fullHeight: Math.max(0, fullBottom - fullTop)
        // Full silhouette from the first visible frame — construction is alpha
        // + resolution, not a geometry morph.
        readonly property real revealWidth: fullWidth
        readonly property real widgetLeft: attachRight ? fullRight - revealWidth : attachLeft ? fullLeft : (fullLeft + fullRight - revealWidth) / 2
        readonly property real widgetRight: attachRight ? fullRight : attachLeft ? fullLeft + revealWidth : widgetLeft + revealWidth
        readonly property real widgetTop: attachBottom ? fullBottom - fullHeight : fullTop
        readonly property real widgetBottom: attachBottom ? fullBottom : fullTop + fullHeight
        readonly property real widgetCorner: Math.min(fb.joinR, Math.max(0, (widgetRight - widgetLeft) / 2), Math.max(0, (widgetBottom - widgetTop) / 2))
        readonly property bool drawCut: reveal > 0.001 && screenMatches && widgetRight - widgetLeft > 1 && widgetBottom - widgetTop > 1
        // Drawn at full density — the pocketPixelate pass owns open/close alpha
        // for fill, shadow, outline, and inverted joins together.
        readonly property real borderAlpha: drawCut ? fb.widgetBorderColor.a : 0
        property bool closing: false
        // Construction region covers the painted pocket plus the chrome the
        // silhouette casts: outward shadow into the hole, and the inverted-
        // join flares that run joinR along the attachment rail. Clamped to the
        // workspace hole so coarse blocks cannot spill into the outer frame.
        readonly property real joinPad: widgetCorner
        readonly property real chromePad: Math.max(fb.widgetShadowWidth, fb.widgetBorderFadeLength, joinPad) + 2
        readonly property real pixelLeft: Math.max(fb.holeX, widgetLeft - (attachLeft ? 0 : chromePad))
        readonly property real pixelTop: Math.max(fb.holeY, widgetTop - (attachBottom ? chromePad : 0))
        readonly property real pixelRight: Math.min(fb.holeRight, widgetRight + (attachRight ? 0 : chromePad))
        readonly property real pixelBottom: Math.min(fb.holeBottom, widgetBottom + (attachBottom ? 0 : chromePad))
        readonly property real pixelWidth: Math.max(0, pixelRight - pixelLeft)
        readonly property real pixelHeight: Math.max(0, pixelBottom - pixelTop)
        // Exact pocket body — section order stays keyed to this so the chrome
        // halo constructs on the same sweep as the fill.
        readonly property real coreLeft: widgetLeft
        readonly property real coreTop: widgetTop
        readonly property real coreWidth: Math.max(0, widgetRight - widgetLeft)
        readonly property real coreHeight: Math.max(0, widgetBottom - widgetTop)
        readonly property real pixelSize: drawCut ? PopupResolution.pixelsAt(reveal) : 1
        readonly property real constructQuality: PopupResolution.qualityAt(reveal)
        readonly property bool constructing: drawCut && (reveal < 0.999 || pocketGlitch.active || pixelSize > 1.001)
        readonly property bool pixelating: constructing
        readonly property real constructSeed: pocketGlitch.seed
        // Match CardWindow corner sweep (~42° off vertical).
        readonly property real cornerGlitchBias: 0.9
        readonly property vector2d constructDirection: {
            const v = attachBottom ? -1 : 1;
            if (attachLeft)
                return Qt.vector2d(cornerGlitchBias, v);
            if (attachRight)
                return Qt.vector2d(-cornerGlitchBias, v);
            return Qt.vector2d(0, v);
        }

        function setRevealInstant(value) {
            revealBehavior.enabled = false;
            pocket.reveal = value;
            revealBehavior.enabled = true;
            if (value <= 0.001) {
                pocket.closing = false;
                pocketGlitch.stopAt(0);
            }
        }

        function openFresh() {
            pocket.setRevealInstant(0);
            pocket.closing = false;
            pocketGlitch.open(true);
            pocket.reveal = 1;
        }

        function ensureOpen() {
            if (pocket.closing) {
                pocket.closing = false;
                pocketGlitch.open(false);
            }
            pocket.reveal = 1;
        }

        function closeAnim() {
            if (pocket.closing)
                return ;

            pocket.closing = true;
            pocketGlitch.close();
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

        // The frame surface owns an attached popup's background. Restrict the
        // overlay to that pocket's live rect; screen-space origin keeps the
        // lattice fixed over the full-size silhouette.
        BootGlitch {
            id: pocketGlitch

            x: pocket.widgetLeft
            y: pocket.widgetTop
            width: Math.max(0, pocket.widgetRight - pocket.widgetLeft)
            height: Math.max(0, pocket.widgetBottom - pocket.widgetTop)
            visible: pocket.drawCut
            theme: fb.root.theme
            corner: pocket.widgetCorner
            originX: x
            originY: y
            resolutionPixels: pocket.pixelSize
        }

        WidgetBorder {
            anchors.fill: parent
            frame: fb
            pocket: pocket
        }

        Behavior on reveal {
            id: revealBehavior

            NumberAnimation {
                duration: pocket.closing ? Math.round(fb.root.frameAnimationDuration * 0.6) : fb.root.frameAnimationDuration
                easing.type: Easing.Linear
            }

        }

    }

}
