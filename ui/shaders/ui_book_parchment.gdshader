shader_type canvas_item;

// 2026 Royal Purple-Velvet Aged Parchment Spread Shader (ref_01 Grimoire Open Book)
uniform float is_left_page : hint_range(0.0, 1.0) = 1.0;
uniform float kansas_mix : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(234.17, 567.89));
	p += dot(p, p + 33.41);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	// Aged royal-plum parchment base (#2B1936 -> #1B0F24)
	float fiber = vnoise(uv * vec2(18.0, 24.0)) * 0.5 + vnoise(uv * vec2(64.0, 82.0)) * 0.5;
	vec3 parch = mix(vec3(0.148, 0.088, 0.184), vec3(0.205, 0.125, 0.245), fiber);

	// Deckle-edge wear darkening around outer borders
	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float edge_vig = smoothstep(0.0, 0.11, min(edge_x, edge_y));
	parch *= mix(0.72, 1.0, edge_vig);

	// Deep central book-spine crease shadow (right edge of left page, left edge of right page)
	float spine_dist = mix(uv.x, 1.0 - uv.x, is_left_page);
	float spine_shadow = smoothstep(0.0, 0.14, spine_dist);
	parch *= mix(0.46, 1.0, spine_shadow);

	// Subtle warm candlelight pool near top-center of page
	float candle = 1.0 - smoothstep(0.0, 0.65, length((uv - vec2(0.5, 0.36)) * vec2(1.1, 0.9)));
	parch += vec3(0.06, 0.038, 0.025) * candle;

	float luma = dot(parch, vec3(0.299, 0.587, 0.114));
	parch = mix(parch, vec3(luma * 0.96, luma * 0.97, luma * 1.0), kansas_mix);

	COLOR = vec4(parch, 0.99);
}
