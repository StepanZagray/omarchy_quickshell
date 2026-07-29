#version 440

// Identity filter: sample the wallpaper and draw it unchanged.
// Use this to verify Image → ShaderEffect wiring before adding effects.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D src;

layout(std140, binding = 0) uniform buf {
	mat4 qt_Matrix;
	float qt_Opacity;
	float iTime;
	vec2 iResolution;
};

void main() {
	vec2 uv = qt_TexCoord0;
	fragColor = texture(src, uv) * qt_Opacity;
}
