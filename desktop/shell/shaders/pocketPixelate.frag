#version 440

// Full-frame capture with Omni-style section construction over each popup's
// chrome region (pocket fill + shadow + inverted-join flares). Geometry is
// already at full size; this pass starts every chrome pixel at alpha 0 and
// reveals binary blocks along the pocket's open direction while resolution
// climbs 32 → 1. Section order is keyed to the core pocket so the halo
// constructs on the same sweep as the body.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 uSize;
    vec4 uRectA;   // expanded chrome region (xywh)
    vec4 uRectB;
    float uPixelsA;
    float uPixelsB;
    float uProgressA;
    float uProgressB;
    float uQualityA;
    float uQualityB;
    float uSeedA;
    float uSeedB;
    vec2 uDirectionA;
    vec2 uDirectionB;
    vec4 uCoreA;   // exact pocket body (xywh)
    vec4 uCoreB;
};

layout(binding = 1) uniform sampler2D source;

bool insideRect(vec2 px, vec4 rect) {
    return rect.z > 0.0 && rect.w > 0.0
        && px.x >= rect.x && px.y >= rect.y
        && px.x < rect.x + rect.z && px.y < rect.y + rect.w;
}

float hash21(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

float directionalCoordinate(vec2 uv, vec2 direction) {
    float p0 = dot(vec2(0.0, 0.0), direction);
    float p1 = dot(vec2(1.0, 0.0), direction);
    float p2 = dot(vec2(0.0, 1.0), direction);
    float p3 = dot(vec2(1.0, 1.0), direction);
    float lo = min(min(p0, p1), min(p2, p3));
    float hi = max(max(p0, p1), max(p2, p3));
    return (dot(uv, direction) - lo) / max(hi - lo, 0.0001);
}

float sectionCoverage(vec2 localPx, vec2 rectSize, float progress,
                      float seed, vec2 direction) {
    float p = clamp(progress, 0.0, 1.0);
    if (p <= 0.0001)
        return 0.0;
    if (p >= 0.9999)
        return 1.0;

    vec2 dir = length(direction) > 0.0001
        ? normalize(direction)
        : vec2(0.0, 1.0);
    // Fixed coarse lattice so activation order does not reshuffle as the
    // shared resolution ladder climbs from 32 px down to native.
    float block = 8.0;
    vec2 sectionId = floor(localPx / block);
    vec2 sectionCentre = (sectionId + vec2(0.5)) * block;
    vec2 uv = clamp(sectionCentre / max(rectSize, vec2(1.0)), vec2(0.0), vec2(1.0));
    float coordinate = directionalCoordinate(uv, dir);
    float randomOrder = hash21(sectionId + vec2(seed * 17.0, seed * 41.0));
    const float ringCount = 18.0;
    float order = clamp(coordinate + (randomOrder - 0.5) * 0.5,
                        0.001, 0.999);
    if (coordinate * ringCount < 1.0)
        order = 0.001;
    return step(order, p);
}

void main() {
    vec2 px = qt_TexCoord0 * uSize;
    vec4 rect = vec4(0.0);
    vec4 core = vec4(0.0);
    float block = 1.0;
    float progress = 1.0;
    float quality = 1.0;
    float seed = 0.0;
    vec2 direction = vec2(0.0, 1.0);
    bool inChrome = false;

    if (insideRect(px, uRectA)) {
        rect = uRectA;
        core = uCoreA.z > 0.0 ? uCoreA : uRectA;
        block = max(1.0, uPixelsA);
        progress = uProgressA;
        quality = uQualityA;
        seed = uSeedA;
        direction = uDirectionA;
        inChrome = true;
    } else if (insideRect(px, uRectB)) {
        rect = uRectB;
        core = uCoreB.z > 0.0 ? uCoreB : uRectB;
        block = max(1.0, uPixelsB);
        progress = uProgressB;
        quality = uQualityB;
        seed = uSeedB;
        direction = uDirectionB;
        inChrome = true;
    }

    if (!inChrome) {
        fragColor = texture(source, qt_TexCoord0) * qt_Opacity;
        return;
    }

    // Halo pixels map onto the nearest core edge so shadow/joins share the
    // body's directional activation order instead of getting their own sweep.
    vec2 coreLocal = clamp(px - core.xy, vec2(0.0), max(core.zw, vec2(1.0)));
    float coverage = sectionCoverage(coreLocal, max(core.zw, vec2(1.0)),
                                     progress, seed, direction);
    if (coverage < 0.5) {
        fragColor = vec4(0.0);
        return;
    }

    bool inCore = insideRect(px, core);
    vec2 samplePx = px;
    // Block resampling stays inside the core body — pulling coarse samples
    // across the chrome halo would copy pocket fill into the shadow/joins or
    // the other way around.
    if (inCore && block > 1.001) {
        vec2 local = px - core.xy;
        samplePx = core.xy + (floor(local / block) + vec2(0.5)) * block;
        samplePx = clamp(samplePx, core.xy + vec2(0.5),
                         core.xy + core.zw - vec2(0.5));
    }

    vec4 sampleColour = texture(source, samplePx / uSize);

    float resolutionDegrade = 1.0 - clamp(quality, 0.0, 1.0);
    if (inCore && resolutionDegrade > 0.001 && block > 1.001) {
        // Cardinal tear strips — same reason as contentGlitch: diagonal
        // direction must not imprint diagonal seams into the pocket fill.
        vec2 dir = length(direction) > 0.0001
            ? normalize(direction)
            : vec2(0.0, 1.0);
        vec2 majorAxis = abs(dir.y) >= abs(dir.x)
            ? vec2(0.0, 1.0) : vec2(1.0, 0.0);
        vec2 tearAxis = vec2(-majorAxis.y, majorAxis.x);
        float frame = floor(clamp(progress, 0.0, 1.0) * 18.0);
        vec2 local = px - core.xy;
        float strip = floor(dot(local, majorAxis) / 5.0);
        float tearGate = step(0.78, hash21(vec2(strip, frame + seed * 31.0)));
        float tearCells = round((hash21(vec2(strip * 1.7, frame + seed)) - 0.5) * 2.0);
        vec2 torn = samplePx + tearAxis * tearCells * block * tearGate
                    * resolutionDegrade;
        torn = clamp(torn, core.xy + vec2(0.5),
                     core.xy + core.zw - vec2(0.5));
        sampleColour = texture(source, torn / uSize);
    }

    fragColor = sampleColour * coverage * qt_Opacity;
}
