#version 440

// Hover distortion over the host's own rendered texture. There is no colour
// overlay and no generated geometry: output coverage can never exceed the
// alpha of the original pixel at this location.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uTime;
    float uProgress;
    float uQuality;
    float uSeed;
    vec2 uSize;
    vec2 uOrigin;
    float uFps;
    float uSplitStrength;
    float uAccentMix;
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

void main() {
    vec2 size = max(uSize, vec2(1.0));
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * size;
    float progress = clamp(uProgress, 0.0, 1.0);
    float degrade = 1.0 - clamp(uQuality, 0.0, 1.0);
    float frame = floor(uTime * max(1.0, uFps));

    // Spread from the cursor quickly, then leave the button in an obviously
    // coarse state until the shared curve reaches 50% quality at 80% time.
    vec2 origin = clamp(uOrigin, vec2(0.0), size);
    float farthest = max(max(length(origin),
                            length(vec2(size.x - origin.x, origin.y))),
                         max(length(vec2(origin.x, size.y - origin.y)),
                             length(size - origin)));
    float distanceFromOrigin = length(px - origin);
    float front = smoothstep(0.0, 0.34, progress) * farthest;
    float sweep = 1.0 - smoothstep(front, front + 7.0,
                                   distanceFromOrigin);
    float startEnvelope = smoothstep(0.0, 0.06, progress);
    float amount = sweep * degrade * startEnvelope;

    float block = 1.0;
    if (amount > 0.72)
        block = 3.0;
    else if (amount > 0.16)
        block = 2.0;

    // Whole-pixel block sampling plus sparse row repositioning. Both colour and
    // alpha come from the displaced source coordinate, so glyph pixels really
    // move instead of merely changing colour inside the original silhouette.
    vec2 samplePx = (floor(px / block) + vec2(0.5)) * block;
    float row = floor(px.y / 4.0);
    float gate = step(0.88, hash21(vec2(row * 2.7,
                                       frame + uSeed * 19.0)));
    float shift = round((hash21(vec2(row, frame + uSeed)) - 0.5)
                        * 2.0) * block;
    samplePx.x += shift * gate * amount;
    vec2 sampleUv = clamp(samplePx / size, vec2(0.5) / size,
                          vec2(1.0) - vec2(0.5) / size);

    vec4 centreSample = texture(source, sampleUv);
    vec3 centre = straightRgb(centreSample);
    vec2 splitUv = vec2(0.75 * amount / size.x, 0.0);
    vec3 positive = straightRgb(texture(source, clamp(sampleUv + splitUv,
        vec2(0.5) / size, vec2(1.0) - vec2(0.5) / size)));
    vec3 negative = straightRgb(texture(source, clamp(sampleUv - splitUv,
        vec2(0.5) / size, vec2(1.0) - vec2(0.5) / size)));
    vec3 split = vec3(positive.r, centre.g, negative.b);
    vec3 rgb = mix(centre, split,
                   clamp(uSplitStrength, 0.0, 1.0) * amount);
    // A restrained theme-purple cast, at half the old overlay strength.
    // It modifies colour only where the relocated source pixel has coverage.
    rgb = mix(rgb, uAccent.rgb,
              clamp(uAccentMix, 0.0, 1.0) * amount);

    // Coverage travels with the sampled source pixel. This can reposition a
    // glyph into a formerly transparent destination, but it still creates no
    // synthetic coverage: every output pixel and its alpha came from `source`.
    float alpha = centreSample.a;
    fragColor = vec4(rgb * alpha, alpha) * qt_Opacity;
}
