shader_type canvas_item;

// Phase P7.2: Obsidian-Plum Damask & Drifting Golden Dust Backdrop Shader
// Used behind Tailor of Vices Boutique, Oz Grimoire, Pause Shell, and Quick-Wheel.

uniform vec4 base_color : source_color = vec4(0.055, 0.024, 0.068, 0.90);
uniform vec4 edge_color : source_color = vec4(0.018, 0.008, 0.025, 0.97);
uniform vec4 gold_tint  : source_color = vec4(0.910, 0.776, 0.478, 1.0);
uniform float kansas_mix : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv - vec2(0.5);
	float dist = length(centered * vec2(1.35, 1.0));
	float vig = smoothstep(0.18, 0.88, dist);

	// Subtle woven diagonal damask diamond lattice
	vec2 grid_uv = uv * vec2(44.0, 26.0);
	float d1 = abs(fract(grid_uv.x + grid_uv.y) - 0.5);
	float d2 = abs(fract(grid_uv.x - grid_uv.y) - 0.5);
	float damask = smoothstep(0.46, 0.50, max(d1, d2)) * 0.028 * (1.0 - vig * 0.65);

	// Gentle drifting golden/silver dust motes
	float sparks = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i) + 1.0;
		vec2 p_uv = uv * (12.0 + fi * 6.0) + vec2(TIME * 0.018 * fi, -TIME * 0.032 * fi);
		vec2 id = floor(p_uv);
		vec2 gv = fract(p_uv) - 0.5;
		float rnd = hash21(id + fi * 19.7);
		if (rnd > 0.90) {
			vec2 offset = (vec2(rnd, fract(rnd * 31.7)) - 0.5) * 0.55;
			float r = length(gv - offset);
			float twinkle = 0.5 + 0.5 * sin(TIME * (1.8 + rnd * 3.0) + rnd * 6.2831);
			sparks += smoothstep(0.075, 0.008, r) * twinkle * 0.22;
		}
	}

	vec4 oz_col = mix(base_color, edge_color, vig);
	vec3 ks_base = mix(vec3(0.075, 0.080, 0.088), vec3(0.022, 0.024, 0.028), vig);
	vec3 rgb = mix(oz_col.rgb, ks_base, kansas_mix);
	vec3 accent = mix(gold_tint.rgb, vec3(0.86, 0.88, 0.92), kansas_mix);
	rgb += accent * (damask + sparks);

	// Subtle warm golden inner border aura at screen perimeter
	float border_glow = smoothstep(0.46, 0.50, max(abs(centered.x), abs(centered.y))) * 0.10;
	rgb += accent * border_glow;

	COLOR = vec4(rgb, oz_col.a);
}
