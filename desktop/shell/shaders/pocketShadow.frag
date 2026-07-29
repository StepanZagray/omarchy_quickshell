#version 440

// Shadow for one frame-attached pocket, in a single pass.
//
// The silhouette that casts it is the union of the pocket body and the frame
// (everything outside the workspace hole), filleted where they meet — which is
// exactly what the frame paints. So the whole thing is one distance field:
//
//   d = roundUnion(pocket, frame, joinRadius)
//
// with the L4 norm standing in for length(), because Hyprland's rounding_power
// is 4 and the frame samples the same superellipse. Corners, straight edges and
// inverted joins are then the same two lines of code, and there are no piece
// boundaries left to seam: alpha is a continuous function of position.
//
// The frame's own edge must not rim the whole workspace, so its share of the
// field is weighted down as it leaves the pocket — that weighting is the fade
// out of the join, and it is why the shadow keeps full density around the
// fillet and lets go a little way along the rail.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 uSize;       // item size, logical px
    vec2 uOrigin;     // item top-left, frame coords
    vec4 uPocket;     // pocket rect: left, top, right, bottom
    vec4 uRadii;      // convex corner radii: TL, TR, BR, BL (0 where a rail is glued)
    vec4 uHole;       // workspace hole: left, top, right, bottom
    float uHoleRadius;
    float uJoinRadius;
    float uDepth;     // how far the shadow reaches
    float uMaxAlpha;  // contact density (already scaled by reveal)
    float uRailNear;  // rail keeps full weight until this far from the pocket
    float uRailFar;   // ... and none beyond here
    float uPixel;     // one device pixel, logical units
    float uFalloffStrength;
};

// Superellipse norm, n = 4.
float n4(vec2 v) {
    vec2 q = v * v;
    q = q * q;
    return pow(q.x + q.y, 0.25);
}

// Signed distance to a box whose corners are superellipse arcs. Radii are
// ordered TL, TR, BR, BL; a zero radius is a square corner.
float sdBoxN4(vec2 p, vec4 rect, vec4 radii) {
    vec2 centre = 0.5 * (rect.xy + rect.zw);
    vec2 extent = 0.5 * (rect.zw - rect.xy);
    vec2 q = p - centre;
    float top = q.x < 0.0 ? radii.x : radii.y;
    float bottom = q.x < 0.0 ? radii.w : radii.z;
    float r = q.y < 0.0 ? top : bottom;
    vec2 d = abs(q) - extent + r;
    return min(max(d.x, d.y), 0.0) + n4(max(d, vec2(0.0))) - r;
}

// Union of two fields with a superellipse fillet of radius r at the reentrant
// corner — the join. Degenerates to min() wherever the two are further apart
// than r, so it costs nothing along the free edges.
float roundUnionN4(float a, float b, float r) {
    vec2 u = max(vec2(r - a, r - b), vec2(0.0));
    return max(r, min(a, b)) - n4(u);
}

// Gaussian density against normalised distance:
//
//   f(t) = (e^(-k t²) - e^(-k)) / (1 - e^(-k))
//
// Its slope starts at zero, becomes strongest after a few pixels, then eases
// into a long faint tail. Subtracting the value at t=1 makes it land on zero.
float falloff(float t) {
    t = clamp(t, 0.0, 1.0);
    float k = max(uFalloffStrength, 0.001);
    float edge = exp(-k);
    return max((exp(-k * t * t) - edge) / (1.0 - edge), 0.0);
}

void main() {
    vec2 p = uOrigin + qt_TexCoord0 * uSize;

    float dPocket = sdBoxN4(p, uPocket, uRadii);
    float dHole = sdBoxN4(p, uHole, vec4(uHoleRadius));
    float dFrame = -dHole;

    // The silhouette as painted — what the shadow must not be drawn on.
    float dSolid = roundUnionN4(dPocket, dFrame, uJoinRadius);

    // What actually casts. The frame's edge recedes as it leaves the pocket, so
    // the fixed rails do not rim the whole workspace: at the join the fillet is
    // exact, a little way along the rail the frame is too far to cast anything.
    // Receding the border rather than weighting its alpha keeps this a single
    // continuous field — weighting left a ray along the locus where pocket and
    // frame are equidistant, which is open space the pocket alone should own.
    // Ramping the recession to exactly the shadow depth spreads the dissolve
    // across the whole zone and lands it on zero at the end of it. The ramp is
    // linear on purpose: an eased one compounds with the falloff below and the
    // shadow is gone by the middle of the zone, well before the outline is.
    float recede = clamp((dPocket - uRailNear) / max(uRailFar - uRailNear, 0.001), 0.0, 1.0) * uDepth;
    float dMaterial = roundUnionN4(dPocket, dFrame + recede, uJoinRadius);

    // Sub-pixel coverage of the material at this pixel — the field already goes
    // negative inside the frame as well as the pocket, so this is the only mask
    // needed. Masking by the plain complement would leave the boundary pixel
    // lighter than either side, because the panel fill above is translucent and
    // two partial translucent layers compose to less than their areas; squaring
    // the coverage is what that compositing actually asks for.
    float cover = clamp(0.5 - dSolid / uPixel, 0.0, 1.0);
    float outside = 1.0 - cover * cover;

    float alpha = uMaxAlpha * falloff(dMaterial / uDepth) * outside;
    fragColor = vec4(0.0, 0.0, 0.0, alpha) * qt_Opacity;
}
