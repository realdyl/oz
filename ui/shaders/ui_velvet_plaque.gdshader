shader_type canvas_item;

// 2026 Smoked Bronzed-Obsidian & Velvet Glass Plaque Shader (ref_02 Main Menu & ref_05 Boutique)
uniform float hover_mix : hint_range(0.0, 1.0) = 0.0;
uniform float kansas_mix : hint_range(0.0, 1.0) = 0.0;
uniform float shimmer_speed : hint_range(0.0, 4.0) = 1.15;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv - vec2(0.5);
	float dist = length(centered * vec2(1.0, 1.35));

	// Deep smoked obsidian-plum base -> warm antique bronze-amber on hover
	vec3 base_oz = mix(vec3(0.095, 0.062, 0.110), vec3(0.245, 0.178, 0.125), hover_mix);
	vec3 center_glow = mix(vec3(0.145, 0.098, 0.155), vec3(0.380, 0.285, 0.175), hover_mix);
	vec3 col = mix(center_glow, base_oz, smoothstep(0.05, 0.72, dist));

	// Subtle woven velvet micro-grain
	float grain = (hash21(floor(uv * vec2(320.0, 96.0))) - 0.5) * 0.028;
	col += grain;

	// Top-edge bevel glass highlight + periodic golden light sweep when hovered
	float top_rim = smoothstep(0.18, 0.0, uv.y) * (0.06 + 0.10 * hover_mix);
	float sweep_pos = fract(TIME * shimmer_speed * 0.28);
	float sweep = smoothstep(0.16, 0.0, abs((uv.x * 0.75 + uv.y * 0.25) - sweep_pos)) * hover_mix * 0.16;
	col += vec3(0.95, 0.80, 0.46) * (top_rim + sweep);

	// Kansas monochrome film-noir parity
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 ks = vec3(luma * 0.95, luma * 0.97, luma * 1.02);
	col = mix(col, ks, kansas_mix);

	COLOR = vec4(col, 0.95);
}
