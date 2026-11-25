shader_type canvas_item;

// Phase P7.2: Anti-Aliased Circular Portrait & Armament Medallion Shader
// Clips square icons/portraits into a convex glass-domed circular brass medallion
// with animated metallic rim sweep, locked silhouette dimming, and Kansas monochrome support.

uniform float is_active : hint_range(0.0, 1.0) = 0.0;
uniform float is_locked : hint_range(0.0, 1.0) = 0.0;
uniform float greyscale : hint_range(0.0, 1.0) = 0.0;
uniform float cooldown_ratio : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rim_color : source_color = vec4(0.910, 0.776, 0.478, 1.0);

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	// Crisp anti-aliased outer circle mask with 0.022 safe margin so rim NEVER clips against quad edges!
	float alpha = 1.0 - smoothstep(0.460, 0.478, r);
	if (alpha <= 0.001) {
		discard;
	}

	vec4 tex = texture(TEXTURE, UV);
	vec3 col = tex.rgb;

	// Optional greyscale / locked desaturation
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float gray_amt = clamp(greyscale + is_locked * 0.82, 0.0, 1.0);
	col = mix(col, vec3(luma), gray_amt);
	col *= mix(1.0, 0.36, is_locked);

	// Inner dark-velvet edge vignette for depth
	float inner_vig = smoothstep(0.26, 0.42, r);
	col *= mix(1.0, 0.55, inner_vig);

	// Subtle convex glass dome diagonal sheen
	float glass_sheen = smoothstep(0.22, -0.35, p.x + p.y * 1.15) * (1.0 - smoothstep(0.0, 0.42, r)) * 0.14 * (1.0 - is_locked);
	col += vec3(glass_sheen);

	// Radial cooldown clock wipe overlay (for Armaments)
	if (cooldown_ratio > 0.001 && r < 0.415) {
		float ang = atan(p.x, -p.y); // -PI..PI clockwise from top
		float norm_ang = fract((ang / 6.2831853) + 1.0);
		if (norm_ang < cooldown_ratio) {
			col *= 0.28;
		}
	}

	// Metallic brass / burnished-gold double bezel ring cleanly inset (0.405..0.470)
	float ring_band = smoothstep(0.402, 0.416, r) * (1.0 - smoothstep(0.460, 0.476, r));
	if (ring_band > 0.01) {
		float sweep = 0.5 + 0.5 * sin((p.x * 5.0 - p.y * 4.0) + TIME * (2.6 * is_active));
		vec3 base_brass = mix(rim_color.rgb * 0.68, rim_color.rgb * 1.24, sweep * (0.45 + 0.55 * is_active));
		if (is_locked > 0.5) {
			base_brass = vec3(0.32, 0.28, 0.34);
		}
		col = mix(col, base_brass, ring_band);
	}

	COLOR = vec4(col, alpha * tex.a);
}
