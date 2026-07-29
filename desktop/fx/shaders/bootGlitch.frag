#version 440

// Sparse popup glitch shared by open and close. uQuality is the actual resolve
// state: open drives 0→1, while close drives the exact reverse 1→0.
//
// Same vocabulary as bar/shaders/hoverGlitch.frag — a character-cell lattice, a
// stepped clock so the noise is redrawn rather than slid between frames, and a
// per-cell dropout resolve instead of a fade — but at a fraction of the density,
// because this one runs over a whole popup rather than one bar button.
//
// The lattice is laid out in SCREEN coordinates (uOrigin), not item ones. The
// pocket this is drawn over morphs open underneath it, so an item-space grid
// would swim sideways as the item resizes; a screen-space grid stays nailed down
// and the popup opens *through* it.
//
// Nothing is sampled: this is a pure overlay, which is why it can sit on either
// of the two layer-shell surfaces a popup is made of without either one needing
// to read the other's pixels.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uQuality;   // 0 = coarse/glitched, 1 = clean
    float uTime;      // seconds since fire(), drives the stepped flicker clock
    float uSeed;      // per-open, so no two opens land the same
    float uVisualScale; // parent popup scale, converted to screen coordinates
    vec2 uSize;       // item size, logical px
    vec2 uOrigin;     // item top-left in screen coords
    vec2 uCell;       // character cell, logical px
    float uFps;       // flicker steps per second
    float uCorner;    // popup corner radius, for the mask
    float uCornerPower; // popup superellipse power (FrameBorder uses 4)
    float uSplit;     // chromatic fringe weight
    float uAlpha;     // overall ceiling
    vec4 uInk;
    vec4 uAccent;
};

// Hash without trig: sin() based hashes band badly once the cell ids get large,
// and a screen-space id is already well into the hundreds.
float hash21(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

// Positive outside the popup's superellipse. p is measured from the centre.
float squircleBox(vec2 p, vec2 halfSize, float radius, float power) {
    float r = min(radius, min(halfSize.x, halfSize.y));
    vec2 q = abs(p) - (halfSize - vec2(r));
    vec2 corner = max(q, vec2(0.0));
    float n = max(2.0, power);
    return pow(pow(corner.x, n) + pow(corner.y, n), 1.0 / n) - r;
}

// Whether one cell is lit, 0 or 1. No partial coverage anywhere: a cell is on or
// it is off, or it stops reading as a pixel and starts reading as a smear.
float cellCharge(vec2 id, float frame, float density, float fade) {
    float lit = step(hash21(id * 1.37 + vec2(uSeed * 37.0, frame)), density);
    // Static per cell, compared against a falling threshold, so cells drop out
    // individually in a fixed order and none flickers back once it has gone.
    float keep = step(hash21(id * 0.71 + uSeed * 13.0), fade);
    return lit * keep;
}

void main() {
    vec2 g = max(uCell, vec2(2.0));
    vec2 px = qt_TexCoord0 * uSize;
    float visualScale = max(clamp(uVisualScale, 0.0, 1.0), 0.001);
    vec2 screenPx = px * visualScale + uOrigin;

    float quality = clamp(uQuality, 0.0, 1.0);
    float degrade = 1.0 - quality;
    float frame = floor(uTime * uFps);

    // Resolve follows the whole hover-length beat. On close the same threshold
    // rises in reverse, so cells return in the opposite temporal direction.
    float fade = smoothstep(0.02, 0.95, degrade);
    float density = 0.14 * fade;

    // Tear. Whole rows jump sideways by whole cells — never a fraction of one,
    // or the displacement shows up as blur instead of as a block that moved.
    // Sparse and front-loaded: this is punctuation, not the body of the effect.
    float row = floor(screenPx.y / g.y);
    float gate = step(0.86, hash21(vec2(row * 3.1, frame * 0.37 + uSeed)));
    float env = smoothstep(0.08, 0.62, degrade);
    float tear = floor((hash21(vec2(row, frame + uSeed * 91.0)) - 0.5) * 5.0) * g.x;

    vec2 sp = screenPx + vec2(tear * gate * env, 0.0);
    vec2 id = floor(sp / g);

    float c = cellCharge(id, frame, density, fade);

    // Fringe only beside cells that are themselves dark: laid over lit ones the
    // two tints just desaturate the accent to a pink mush, and the point of a
    // split is that you see it beside the block it came from.
    float gap = 1.0 - step(0.001, c);
    float cr = cellCharge(id + vec2(1.0, 0.0), frame, density, fade) * gap;
    float cb = cellCharge(id - vec2(1.0, 0.0), frame, density, fade) * gap;

    // One dropped scan row at a time, dashed on the cell lattice rather than
    // solid — a clean rectangle would be the one shape on screen not made of
    // cells. Rare, because on a popup-sized grid a frequent one reads as texture
    // rather than as a fault.
    float rows = max(1.0, floor(uSize.y * visualScale / g.y));
    float pick = floor(uOrigin.y / g.y) + floor(hash21(vec2(frame * 0.83, uSeed)) * rows);
    float dash = step(0.45, hash21(vec2(floor(sp.x / g.x), pick * 1.7 + uSeed)));
    float bar = step(0.92, hash21(vec2(frame, uSeed * 3.0)))
              * step(abs(row - pick), 0.5) * dash * fade;

    // Everything else here is a step(), so the mask gets the one smoothstep: a
    // stair-stepped corner on a curve is far more visible than a soft cell.
    float mask = uCorner <= 0.001
        ? 1.0
        : 1.0 - smoothstep(-0.5, 0.5,
                           squircleBox(px - uSize * 0.5, uSize * 0.5,
                                      uCorner, uCornerPower));

    // Premultiplied, and deliberately allowed to run brighter than its own alpha
    // so the surplus composites as additive bloom on the lit cells.
    vec3 col = uAccent.rgb * c
             + vec3(1.00, 0.10, 0.15) * cr * uSplit
             + vec3(0.15, 0.50, 1.00) * cb * uSplit
             + uInk.rgb * bar * 0.30;

    float a = clamp(c + (cr + cb) * uSplit * 0.5 + bar * 0.30, 0.0, 1.0);

    fragColor = vec4(min(col, vec3(1.0)), a) * uAlpha * qt_Opacity * mask;
}
