#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uCorner;
    float uCornerPower;
    vec2 uSize;
};

layout(binding = 1) uniform sampler2D source;

float squircleMask(vec2 px, vec2 size, float radius, float power) {
    if (radius <= 0.001)
        return 1.0;

    vec2 halfSize = size * 0.5;
    float r = min(radius, min(halfSize.x, halfSize.y));
    vec2 q = abs(px - halfSize) - (halfSize - vec2(r));
    vec2 corner = max(q, vec2(0.0));
    float n = max(2.0, power);
    float distance = pow(pow(corner.x, n) + pow(corner.y, n), 1.0 / n) - r;
    return 1.0 - smoothstep(-0.5, 0.5, distance);
}

void main() {
    vec2 px = qt_TexCoord0 * uSize;
    vec4 color = texture(source, qt_TexCoord0);
    float mask = squircleMask(px, uSize, uCorner, uCornerPower);
    fragColor = color * mask * qt_Opacity;
}
