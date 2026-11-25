shader_type canvas_item;

// Baum-Canon Locked Green-Tinted Spectacles Optical Lens Overlay ([G] in Emerald City!)
uniform float intensity : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	vec2 uv = UV;
	vec2 c = (uv - vec2(0.5)) * vec2(1.18, 1.0);
	float r = length(c);
	// Subtle twin-spectacle brass rim vignette + emerald optical prism tint
	float rim = smoothstep(0.46, 0.76, r);
	float shimmer = 0.5 + 0.5 * sin(TIME * 1.6 + uv.x * 8.0 - uv.y * 5.0);
	vec3 lens = mix(vec3(0.06, 0.48, 0.28), vec3(0.02, 0.22, 0.14), rim);
	lens += vec3(0.25, 0.85, 0.52) * shimmer * 0.06;
	float alpha = mix(0.11, 0.42, rim) * intensity;
	// Delicate golden spectacle rim arc near corners
	float brass_ring = smoothstep(0.015, 0.0, abs(r - 0.66)) * 0.45 * intensity;
	vec3 final_col = mix(lens, vec3(0.88, 0.74, 0.38), brass_ring);
	COLOR = vec4(final_col, clamp(alpha + brass_ring, 0.0, 0.65));
}
