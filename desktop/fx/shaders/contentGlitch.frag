#version 440

// Popup source reveal. Surfaces construct in binary sections that resolve from
// coarse blocks to native pixels. Free-standing menus grow centre-out; frame-
// attached widgets travel along uDirection so open/close keep their established
// sweep. Every output colour comes from the source texture, and source alpha
// remains the coverage ceiling.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 uSize;
    float uProgress;
    float uQuality;
    float uSectionReveal;
    float uSectionDirectional;
    float uSectionRandomness;
    vec2 uDirection;
    float uSeed;
    float uSplitStrength;
    float uSplitPixels;
    float uResolutionPixels;
    float uVisualScale;
    float uFadeWidth;
    float uSteps;
    float uCorner;
    float uCornerPower;
    vec4 uAccent;
};

layout(binding = 1) uniform sampler2D source;

float hash21(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

vec3 straightRgb(vec4 premultiplied) {
    return premultiplied.a > 0.0001
        ? premultiplied.rgb / premultiplied.a
        : vec3(0.0);
}

float squircleMask(vec2 px, vec2 size, float radius, float power) {
    if (radius <= 0.001)
        return 1.0;

    vec2 halfSize = size * 0.5;
    float r = min(radius, min(halfSize.x, halfSize.y));
    vec2 q = abs(px - halfSize) - (halfSize - vec2(r));
    vec2 corner = max(q, vec2(0.0));
    float n = max(2.0, power);
    float distance = pow(pow(corner.x, n) + pow(corner.y, n),
                         1.0 / n) - r;
    return 1.0 - smoothstep(-0.5, 0.5, distance);
}

// Projection normalized over all four texture corners. A positive Y vector
// therefore starts at the top and travels downward; negative Y starts at the
// bottom, and the same rule applies horizontally or diagonally.
float directionalCoordinate(vec2 uv, vec2 direction) {
    float p0 = dot(vec2(0.0, 0.0), direction);
    float p1 = dot(vec2(1.0, 0.0), direction);
    float p2 = dot(vec2(0.0, 1.0), direction);
    float p3 = dot(vec2(1.0, 1.0), direction);
    float lo = min(min(p0, p1), min(p2, p3));
    float hi = max(max(p0, p1), max(p2, p3));
    return (dot(uv, direction) - lo) / max(hi - lo, 0.0001);
}

void main() {
    vec2 size = max(uSize, vec2(1.0));
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * size;

    float progress = clamp(uProgress, 0.0, 1.0);
    vec2 direction = length(uDirection) > 0.0001
        ? normalize(uDirection)
        : vec2(0.0, 1.0);
    float frame = floor(progress * max(1.0, uSteps));

    // Resolution is supplied directly by the one shared popup ladder. Edge
    // noise can still tear and split pixels, but it cannot choose a different
    // tier or schedule for frame-attached and free-standing surfaces.
    float quality = clamp(uQuality, 0.0, 1.0);
    // The layer texture is transformed with its popup after this shader runs.
    // Counter-scale all pixel distances so they remain constant in screen
    // space instead of vanishing while the popup constructs from the centre.
    float visualScale = max(clamp(uVisualScale, 0.0, 1.0), 0.05);
    float block = max(1.0, uResolutionPixels / visualScale);

    float coverage = 0.0;
    float revealEdge = 0.0;
    float revealCarrier = 0.0;

    if (uSectionReveal > 0.5) {
        // Every block receives one stable activation threshold. Binary alpha:
        // a section is entirely absent or retains the sampled source pixel's
        // original alpha. No smoothstep or progress multiplier.
        vec2 sectionId = floor(px / block);
        vec2 sectionCentre = (sectionId + vec2(0.5)) * block;
        float randomOrder = hash21(sectionId + vec2(uSeed * 17.0,
                                                    uSeed * 41.0));
        const float ringCount = 18.0;
        float randomness = clamp(uSectionRandomness, 0.0, 0.75);
        float order = 0.001;

        if (uSectionDirectional > 0.5) {
            // Frame widgets: construct along the established open direction so
            // the sweep matches the old directional fade, with Omni's binary
            // section mask and resolution ladder.
            float coordinate = directionalCoordinate(sectionCentre / size,
                                                     direction);
            order = clamp(coordinate
                          + (randomOrder - 0.5) * randomness,
                          0.001, 0.999);
            if (coordinate * ringCount < 1.0)
                order = 0.001;
        } else {
            // Free-standing menus: square distance from the true surface
            // centre keeps the overall construction centred, while a broad
            // seeded band lets neighbouring rings interleave.
            vec2 halfSize = max(size * 0.5, vec2(1.0));
            vec2 centreOffset = (sectionCentre - halfSize) / halfSize;
            float squareOrder = clamp(max(abs(centreOffset.x),
                                          abs(centreOffset.y)),
                                      0.0, 1.0);
            // The area enclosed by a square radius grows with radius². Using
            // that area coordinate makes progress describe the approximate
            // percentage of popup sections already present.
            float areaOrder = squareOrder * squareOrder;
            float ringIndex = floor(squareOrder * ringCount);
            order = clamp(areaOrder
                          + (randomOrder - 0.5) * randomness,
                          0.001, 0.999);
            if (ringIndex < 0.5)
                order = 0.001;
        }

        coverage = step(order, progress);
        revealEdge = coverage * (1.0 - step(order + 0.10, progress));
        revealCarrier = coverage;
    } else {
        // Legacy directional fade kept for any host that opts out of sections.
        float coordinate = directionalCoordinate(uv, direction);
        float fadeWidth = clamp(uFadeWidth, 0.01, 0.45);
        float front = progress;
        float insideFront = 1.0 - step(front, coordinate);
        float directionalFade = 1.0
            - smoothstep(front - fadeWidth, front, coordinate);
        directionalFade *= insideFront;
        coverage = progress * directionalFade;

        float age = front - coordinate;
        revealEdge = directionalFade
            * (1.0 - smoothstep(0.015, 0.30, max(age, 0.0)));
        revealCarrier = directionalFade;
    }

    // `uQuality` follows the independent late-resolve schedule. Visible
    // sections stay coarse, displaced, and split until that schedule resolves.
    float resolutionDegrade = 1.0 - quality;
    float glitchAmount = revealCarrier
        * max(revealEdge, resolutionDegrade);

    // Quantize to whole source pixels and shift occasional strips along the
    // edge. Clamp every lookup to this same texture: no synthetic pixels and
    // no sampling beyond the popup-content layer.
    //
    // Strip orientation stays axis-aligned even when the reveal direction is
    // diagonal (corner frame widgets). Keying strips to a diagonal direction
    // paints visible diagonal seam lines across the whole surface while
    // resolution is still resolving.
    vec2 samplePx = (floor(px / block) + vec2(0.5)) * block;
    vec2 majorAxis = abs(direction.y) >= abs(direction.x)
        ? vec2(0.0, 1.0) : vec2(1.0, 0.0);
    vec2 tearAxis = vec2(-majorAxis.y, majorAxis.x);
    float strip = floor(dot(px, majorAxis) / (5.0 / visualScale));
    float tearGate = step(0.78, hash21(vec2(strip, frame + uSeed * 31.0)));
    float tearCells = round((hash21(vec2(strip * 1.7,
                                        frame + uSeed)) - 0.5) * 2.0);
    samplePx += tearAxis * tearCells * block * tearGate * glitchAmount;
    vec2 sampleUv = clamp(samplePx / size, vec2(0.5) / size,
                          vec2(1.0) - vec2(0.5) / size);

    vec4 centreSample = texture(source, sampleUv);
    vec3 centre = straightRgb(centreSample);

    // Split channels by resampling neighbouring source pixels.
    float splitPx = max(0.0, uSplitPixels) / visualScale * glitchAmount;
    vec2 splitUv = tearAxis * splitPx / size;
    vec3 positive = straightRgb(texture(source, clamp(sampleUv + splitUv,
        vec2(0.5) / size, vec2(1.0) - vec2(0.5) / size)));
    vec3 negative = straightRgb(texture(source, clamp(sampleUv - splitUv,
        vec2(0.5) / size, vec2(1.0) - vec2(0.5) / size)));
    vec3 split = vec3(positive.r, centre.g, negative.b);
    // Concentrate the subtle source-channel split on pixels already close to
    // Quickshell's accent. The accent is only a mask reference; output colour
    // still comes entirely from sampled source channels.
    float accentMask = 1.0 - smoothstep(0.16, 0.58,
                                       distance(centre, uAccent.rgb));
    float splitMix = clamp(uSplitStrength, 0.0, 1.0)
        * glitchAmount * mix(0.45, 1.0, accentMask);
    vec3 rgb = mix(centre, split,
                   splitMix);

    // Alpha travels with the displaced source sample, making the glitch an
    // actual reposition rather than a colour change locked inside the old
    // silhouette. It remains source-only: no synthetic coverage is generated.
    float alpha = centreSample.a * coverage
                * squircleMask(px, size, uCorner, uCornerPower);
    fragColor = vec4(rgb * alpha, alpha) * qt_Opacity;
}
