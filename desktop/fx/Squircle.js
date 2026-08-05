// Shared n-power superellipse helpers. Matches Hyprland rounding.glsl and
// FrameBorder.strokeSquircleCorner (decoration:rounding_power = 4).
.pragma library

function squircleOffset(t, power) {
    const ang = t * Math.PI / 2;
    const dx = Math.sin(ang);
    const dy = -Math.cos(ang);
    const n = Math.max(2, power);
    const s = 1 / Math.pow(Math.pow(Math.abs(dx), n) + Math.pow(Math.abs(dy), n), 1 / n);
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

function traceCorner(ctx, sx, sy, r, rot, clockwise, power, steps) {
    if (r <= 0.001)
        return;

    const count = steps || Math.max(24, Math.min(64, Math.ceil(r * 2)));
    for (let i = 1; i <= count; i++) {
        const t = clockwise ? i / count : 1 - i / count;
        const o = squircleOffset(t, power);
        const local = rotateCorner(o[0] * r, o[1] * r, rot);
        const cx = sx + (rot === 0 || rot === 1 ? -r : r);
        const cy = sy + (rot === 0 || rot === 3 ? r : -r);
        ctx.lineTo(cx + local[0], cy + local[1]);
    }
}

function traceRect(ctx, inset, requestedRadius, power, w, h) {
    const left = inset;
    const top = inset;
    const right = Math.max(left, w - inset);
    const bottom = Math.max(top, h - inset);
    const width = Math.max(0, right - left);
    const height = Math.max(0, bottom - top);
    const radius = Math.max(0, Math.min(requestedRadius, width / 2, height / 2));

    ctx.beginPath();
    if (radius <= 0.001) {
        ctx.rect(left, top, width, height);
        ctx.closePath();
        return radius;
    }

    ctx.moveTo(left + radius, top);
    ctx.lineTo(right - radius, top);
    traceCorner(ctx, right, top, radius, 0, true, power);
    ctx.lineTo(right, bottom - radius);
    traceCorner(ctx, right, bottom, radius, 1, true, power);
    ctx.lineTo(left + radius, bottom);
    traceCorner(ctx, left, bottom, radius, 2, true, power);
    ctx.lineTo(left, top + radius);
    traceCorner(ctx, left, top, radius, 3, true, power);
    ctx.closePath();
    return radius;
}
