#version 440

// Sample the wallpaper with a soft radial ripple in UV space.
// The photo is the input — this only warps where you look it up.

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

	// Aspect-correct distance from centre.
	vec2 p = uv - 0.5;
	p.x *= iResolution.x / max(iResolution.y, 1.0);
	float r = length(p);

	// Expanding rings; strength falls off toward the edges.
	float wave = sin(r * 32.0 - iTime * 3.0) * 0.02;
	wave *= smoothstep(0.85, 0.05, r);

	vec2 dir = (r > 1e-4) ? normalize(p) : vec2(0.0);
	// Convert aspect-corrected offset back into UV space.
	vec2 offset = dir * wave;
	offset.x /= iResolution.x / max(iResolution.y, 1.0);

	vec4 tex = texture(src, uv + offset);
	fragColor = tex * qt_Opacity;
}
