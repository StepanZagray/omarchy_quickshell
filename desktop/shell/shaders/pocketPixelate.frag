#version 440

// Full-frame passthrough with nearest-neighbour block sampling restricted to
// the two independently animated popup-pocket rectangles.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 uSize;
    vec4 uRectA;
    vec4 uRectB;
    float uPixelsA;
    float uPixelsB;
};

layout(binding = 1) uniform sampler2D source;

bool insideRect(vec2 px, vec4 rect) {
    return rect.z > 0.0 && rect.w > 0.0
        && px.x >= rect.x && px.y >= rect.y
        && px.x < rect.x + rect.z && px.y < rect.y + rect.w;
}

void main() {
    vec2 px = qt_TexCoord0 * uSize;
    vec4 rect = vec4(0.0);
    float block = 1.0;

    if (insideRect(px, uRectA)) {
        rect = uRectA;
        block = max(1.0, uPixelsA);
    } else if (insideRect(px, uRectB)) {
        rect = uRectB;
        block = max(1.0, uPixelsB);
    }

    vec2 uv = qt_TexCoord0;
    if (block > 1.0 && rect.z > 0.0) {
        vec2 local = px - rect.xy;
        vec2 samplePx = rect.xy + (floor(local / block) + vec2(0.5)) * block;
        samplePx = clamp(samplePx, rect.xy + vec2(0.5),
                         rect.xy + rect.zw - vec2(0.5));
        uv = samplePx / uSize;
    }

    fragColor = texture(source, uv) * qt_Opacity;
}
