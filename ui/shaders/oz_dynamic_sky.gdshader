shader_type sky;

// 2026 Dynamic Volumetric Cloud, Cirrus, Celestial Halo & Weather Sky Shader
// Supports seasonal biome palettes, self-shadowed FBM cumulus, high-altitude cirrus streaks,
// organic weather coverage drift, twilight stars, aurora ribbons, and internal storm lightning.

uniform vec3 zenith_col : source_color = vec3(0.10, 0.18, 0.38);
uniform vec3 mid_col : source_color = vec3(0.24, 0.36, 0.62);
uniform vec3 horizon_col : source_color = vec3(0.76, 0.58, 0.48);
uniform vec3 ground_col : source_color = vec3(0.14, 0.12, 0.16);

uniform vec3 cloud_lit_col : source_color = vec3(0.98, 0.94, 0.90);
uniform vec3 cloud_shadow_col : source_color = vec3(0.32, 0.28, 0.40);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.90, 0.72);
uniform vec3 aurora_col : source_color = vec3(0.20, 0.95, 0.58);

uniform vec3 sun_dir = vec3(0.32, 0.48, -0.82);
uniform float sun_size : hint_range(0.002, 0.12) = 0.022;
uniform float sun_halo : hint_range(0.0, 2.0) = 0.65;

uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.42;
uniform float cloud_softness : hint_range(0.05, 0.65) = 0.28;
uniform float cloud_scale : hint_range(0.3, 4.0) = 1.15;
uniform float cirrus_amount : hint_range(0.0, 1.0) = 0.35;
uniform vec2 wind_vel = vec2(0.028, 0.014);

uniform float weather_variance : hint_range(0.0, 0.30) = 0.08;
uniform float weather_cycle_speed : hint_range(0.0, 0.5) = 0.045;
uniform float star_intensity : hint_range(0.0, 1.5) = 0.0;
uniform float aurora_intensity : hint_range(0.0, 1.5) = 0.0;
uniform float lightning_flash : hint_range(0.0, 2.0) = 0.0;
uniform float monochrome_mix : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm4(vec2 p) {
	float v = 0.0;
	float amp = 0.52;
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int i = 0; i < 4; i++) {
		v += amp * vnoise(p);
		p = rot * p * 2.07 + vec2(17.3, 9.2);
		amp *= 0.50;
	}
	return v;
}

float fbm5(vec2 p) {
	float v = 0.0;
	float amp = 0.52;
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int i = 0; i < 5; i++) {
		v += amp * vnoise(p);
		p = rot * p * 2.03 + vec2(11.7, 23.1);
		amp *= 0.50;
	}
	return v;
}

void sky() {
	vec3 rd = normalize(EYEDIR);
	vec3 sdir = normalize(LIGHT0_ENABLED ? LIGHT0_DIRECTION : sun_dir);
	float up = clamp(rd.y, 0.0, 1.0);

	// 1. Multi-stop atmospheric sky gradient
	vec3 sky_col = mix(horizon_col, mid_col, smoothstep(0.0, 0.34, up));
	sky_col = mix(sky_col, zenith_col, smoothstep(0.28, 0.92, up));

	// Sun / Moon Mie scattering & crisp celestial disk
	float mu = max(dot(rd, sdir), 0.0);
	float mie = pow(mu, 6.0) * 0.32 + pow(mu, 32.0) * 0.45;
	sky_col += sun_tint * mie * sun_halo * smoothstep(-0.08, 0.18, rd.y);

	if (!AT_CUBEMAP_PASS) {
		float disk = smoothstep(1.0 - sun_size, 1.0 - sun_size * 0.35, mu);
		sky_col += sun_tint * disk * 1.85 * smoothstep(-0.02, 0.08, rd.y);
	}

	if (rd.y > 0.001) {
		// Curved dome projection prevents horizon pinching and gives deep aerial perspective
		float dome_y = rd.y + 0.20;
		vec2 dome_uv = (rd.xz / dome_y) * cloud_scale;
		float horizon_fade = smoothstep(0.005, 0.16, rd.y);

		// Subtle twilight stars in clear upper-sky gaps
		if (!AT_CUBEMAP_PASS && star_intensity > 0.01 && rd.y > 0.12) {
			vec2 suv = floor(rd.xz / (rd.y + 0.35) * 190.0);
			float sh = hash21(suv);
			if (sh > 0.9935) {
				float twinkle = 0.60 + 0.40 * sin(TIME * 2.8 + sh * 90.0);
				sky_col += vec3(0.92, 0.95, 1.0) * twinkle * star_intensity * smoothstep(0.12, 0.55, rd.y);
			}
		}

		// Optional Emerald / Mystical Aurora curtains
		if (aurora_intensity > 0.01) {
			float aur_wave = fbm4(vec2(dome_uv.x * 0.85 + TIME * 0.02, dome_uv.y * 0.35 - TIME * 0.015));
			float aur_band = smoothstep(0.46, 0.68, aur_wave) * smoothstep(0.84, 0.56, aur_wave);
			sky_col += aurora_col * aur_band * aurora_intensity * smoothstep(0.08, 0.55, rd.y);
		}

		// 2. High-altitude swept Cirrus wisps (drifting slower & stretched)
		if (cirrus_amount > 0.01) {
			vec2 cir_uv = dome_uv * vec2(0.85, 2.65) + wind_vel * TIME * 0.42;
			float cir_n = fbm4(cir_uv + vec2(fbm4(cir_uv * 0.6) * 0.9, 0.0));
			float cir_mask = smoothstep(0.54, 0.86, cir_n) * cirrus_amount * horizon_fade * 0.62;
			vec3 cir_col = mix(cloud_lit_col, sun_tint, pow(mu, 3.0) * 0.45);
			sky_col = mix(sky_col, cir_col, cir_mask);
		}

		// 3. Lower billowing volumetric Cumulus / Stratocumulus with seasonal weather tide
		float live_cov = clamp(
			cloud_coverage + sin(TIME * weather_cycle_speed) * weather_variance,
			0.04,
			0.96
		);
		vec2 cld_uv = dome_uv * 1.15 + wind_vel * TIME;
		// Domain-warped FBM for organic, non-repetitive billowing cumulus silhouettes
		vec2 warp = vec2(
			fbm4(cld_uv * 0.65 + vec2(3.1, 7.4)),
			fbm4(cld_uv * 0.65 + vec2(12.8, 2.9))
		);
		float base_n = AT_CUBEMAP_PASS
			? fbm4(cld_uv + (warp - 0.5) * 0.65)
			: fbm5(cld_uv + (warp - 0.5) * 0.72);

		float thresh = 1.0 - live_cov;
		float density = smoothstep(thresh - cloud_softness * 0.35, thresh + cloud_softness, base_n);

		if (density > 0.002) {
			// Directional self-shadowing sample offset toward sun
			vec2 sun_step = normalize(sdir.xz + vec2(0.0001)) * 0.16;
			float shadow_n = fbm4(cld_uv + sun_step + (warp - 0.5) * 0.60);
			float thickness = clamp((shadow_n - base_n) * 2.4 + 0.48, 0.0, 1.0);
			float height_bright = smoothstep(thresh, thresh + cloud_softness * 1.35, base_n);
			float lit_factor = clamp(height_bright * 0.72 + (1.0 - thickness) * 0.48, 0.0, 1.0);

			vec3 c_col = mix(cloud_shadow_col, cloud_lit_col, lit_factor);
			// Silver / golden lining along thinner cloud rims near the sun
			float silver_edge = (1.0 - density * 0.72) * pow(mu, 4.0) * 0.85;
			c_col += sun_tint * silver_edge;

			// Internal storm-cloud sheet lightning pulse
			if (lightning_flash > 0.005) {
				float bolt_cell = vnoise(cld_uv * 1.9 + vec2(floor(TIME * 7.0), 0.0));
				float inner_glow = smoothstep(0.42, 0.85, bolt_cell) * lightning_flash;
				c_col += vec3(0.82, 0.86, 1.0) * inner_glow * 1.35;
			}

			// Aerial perspective blends distant horizon clouds softly into horizon haze
			c_col = mix(horizon_col, c_col, smoothstep(0.01, 0.24, rd.y));
			sky_col = mix(sky_col, c_col, density * horizon_fade);
		}
	} else {
		// Lower hemisphere bounce
		sky_col = mix(horizon_col * 0.75, ground_col, smoothstep(0.0, 0.45, -rd.y));
	}

	if (monochrome_mix > 0.001) {
		float luma = dot(sky_col, vec3(0.299, 0.587, 0.114));
		vec3 sepia_grey = vec3(luma * 1.01, luma * 1.00, luma * 0.99);
		sky_col = mix(sky_col, sepia_grey, monochrome_mix);
	}

	COLOR = max(sky_col, vec3(0.0));
}
