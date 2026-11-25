shader_type canvas_item;

// Phase P7.2: Alice-Class Rapture / Hysteria Desperation Vignette Shader
// Keeps center screen crystal-clear for combat while pulsing thorny crimson-rose
// & molten-gold veins along the perimeter.

uniform vec4 crimson_col : source_color = vec4(0.86, 0.08, 0.28, 1.0);
uniform vec4 gold_col    : source_color = vec4(0.98, 0.78, 0.36, 1.0);

void fragment() {
	vec2 p = UV - vec2(0.5);
	float dist = length(p * vec2(1.18, 1.0));
	float pulse = 0.5 + 0.5 * sin(TIME * 5.2);

	// Perimeter-only radial mask so center combat view stays 100% unobstructed
	float edge = smoothstep(0.34, 0.74, dist);

	// Procedural radial thorn/briar striations
	float ang = atan(p.y, p.x);
	float veins = pow(0.5 + 0.5 * sin(ang * 18.0 + sin(dist * 16.0 - TIME * 3.4) * 2.2), 4.0);
	float sub_veins = pow(0.5 + 0.5 * cos(ang * 31.0 - dist * 12.0 + TIME * 2.1), 5.0);

	vec3 col = mix(crimson_col.rgb * 0.55, crimson_col.rgb * 1.25, veins);
	col += gold_col.rgb * sub_veins * 0.45 * pulse;

	float alpha = edge * (0.28 + 0.16 * pulse + veins * 0.22);
	COLOR = vec4(col, clamp(alpha, 0.0, 0.68));
}
