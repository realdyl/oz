extends RefCounted

## Master 2026 Storybook 3D World, Shader, Architecture, Foliage, Interior & Character Kit.
## Eliminates flat Minecraft boxes, horizon billboard spam, uncollided hills, and stiff cones
## across Oz while keeping all gameplay colliders, Area3Ds, and headless sims 100% intact.

static var _grass_shader: Shader = null
static var _leaf_shader: Shader = null
static var _fishnet_shader: Shader = null
static var _holo_shader: Shader = null
static var _grass_mats: Array[ShaderMaterial] = []

static func _mat(
	col: Color,
	rough: float = 0.82,
	metal: float = 0.0,
	emit_col: Color = Color(0, 0, 0),
	emit_energy: float = 0.0
) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emit_energy > 0.0:
		m.emission_enabled = true
		m.emission = emit_col
		m.emission_energy_multiplier = emit_energy
	return m

static func _mi(
	parent: Node3D,
	mesh: Mesh,
	mat: Material,
	pos: Vector3,
	rot_deg: Vector3 = Vector3.ZERO,
	scl: Vector3 = Vector3.ONE
) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	n.rotation_degrees = rot_deg
	n.scale = scl
	parent.add_child(n)
	return n

static func _box(sz: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = sz
	return b

static func _cyl(t: float, b: float, h: float, segs: int = 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = t
	c.bottom_radius = b
	c.height = h
	c.radial_segments = segs
	return c

static func _sph(r: float, h: float = -1.0, segs: int = 18) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0.0 else h
	s.radial_segments = segs
	s.rings = 10
	return s

# ============================================================================
# SHADERS: Wind-Swaying Grass + Character Rustle, Tree Leaf Breeze, Fishnets
# ============================================================================

static func make_wind_grass_material(base_col: Color) -> ShaderMaterial:
	if _grass_shader == null:
		_grass_shader = Shader.new()
		_grass_shader.code = """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo_color : source_color = vec4(0.32, 0.58, 0.26, 1.0);
uniform float wind_strength = 0.14;
uniform float wind_speed = 2.4;
uniform vec3 rustle_pos = vec3(0.0, -100.0, 0.0);
uniform float rustle_radius = 1.65;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h_factor = clamp((VERTEX.y + 0.25) * 1.8, 0.0, 1.0);
	float sway = sin(TIME * wind_speed + world_pos.x * 0.7 + world_pos.z * 0.5) * wind_strength;
	float gust = cos(TIME * (wind_speed * 0.65) + world_pos.z * 0.9) * (wind_strength * 0.45);
	VERTEX.x += (sway + gust) * h_factor;
	VERTEX.z += (gust * 0.8) * h_factor;

	vec2 to_blade = world_pos.xz - rustle_pos.xz;
	float d = length(to_blade);
	if (d < rustle_radius && d > 0.01) {
		float push = (1.0 - d / rustle_radius) * 0.48 * h_factor;
		vec2 dir = normalize(to_blade);
		VERTEX.x += dir.x * push;
		VERTEX.z += dir.y * push;
		VERTEX.y -= push * 0.28;
	}
}

void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = 0.88;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _grass_shader
	sm.set_shader_parameter("albedo_color", base_col)
	_grass_mats.append(sm)
	return sm

## Call once per frame from PlayHUD or a region to push nearby grass away from the active Lead.
static func update_grass_rustle(actor_pos: Vector3) -> void:
	for i in range(_grass_mats.size() - 1, -1, -1):
		var m := _grass_mats[i]
		if m == null:
			_grass_mats.remove_at(i)
			continue
		m.set_shader_parameter("rustle_pos", actor_pos)

static func make_leaf_wind_material(base_col: Color) -> ShaderMaterial:
	if _leaf_shader == null:
		_leaf_shader = Shader.new()
		_leaf_shader.code = """
shader_type spatial;

uniform vec4 albedo_color : source_color = vec4(0.22, 0.48, 0.26, 1.0);
uniform float wind_strength = 0.08;
uniform float wind_speed = 1.7;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * wind_speed + world_pos.x * 0.45 + world_pos.y * 0.8 + world_pos.z * 0.45) * wind_strength;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.65;
}

void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = 0.86;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _leaf_shader
	sm.set_shader_parameter("albedo_color", base_col)
	return sm

static func make_fishnet_material(skin_col: Color, greyscale: bool = false) -> ShaderMaterial:
	if _fishnet_shader == null:
		_fishnet_shader = Shader.new()
		_fishnet_shader.code = """
shader_type spatial;

uniform vec4 skin_color : source_color = vec4(0.94, 0.74, 0.62, 1.0);
uniform vec4 net_color : source_color = vec4(0.06, 0.04, 0.08, 1.0);
uniform float tile_u = 14.0;
uniform float tile_v = 18.0;
uniform float line_width = 0.16;

void fragment() {
	vec2 uv = vec2(UV.x * tile_u, UV.y * tile_v);
	float d1 = abs(fract(uv.x + uv.y) - 0.5) * 2.0;
	float d2 = abs(fract(uv.x - uv.y) - 0.5) * 2.0;
	float net = max(
		smoothstep(1.0 - line_width, 1.0 - line_width * 0.35, d1),
		smoothstep(1.0 - line_width, 1.0 - line_width * 0.35, d2)
	);
	vec3 tinted_skin = mix(skin_color.rgb, net_color.rgb, 0.14);
	ALBEDO = mix(tinted_skin, net_color.rgb, net * 0.92);
	ROUGHNESS = mix(0.46, 0.32, net);
	SPECULAR = mix(0.35, 0.65, net);
}
"""
	var sc := skin_col
	if greyscale:
		var l := sc.r * 0.3 + sc.g * 0.5 + sc.b * 0.2
		sc = Color(l, l, l)
	var sm := ShaderMaterial.new()
	sm.shader = _fishnet_shader
	sm.set_shader_parameter("skin_color", sc)
	sm.set_shader_parameter("net_color", Color(0.08, 0.08, 0.09) if greyscale else Color(0.06, 0.04, 0.08))
	return sm

# ============================================================================
# LABEL3D CULLING, CARVED SIGNPOSTS, BUILDING CRESTS & WORLD BADGES
# (Conforms to obsidian-oz: Typography & Signpost Style Guide)
# ============================================================================

static func apply_label3d_culling(root: Node, max_dist: float = 12.0, fade_margin: float = 3.5) -> void:
	if root == null or not is_instance_valid(root):
		return
	var labels := root.find_children("*", "Label3D", true, false)
	for n in labels:
		var lab := n as Label3D
		if lab == null:
			continue
		if lab.has_meta("styled_plaque"):
			continue
		lab.no_depth_test = false
		lab.fixed_size = false
		if lab.pixel_size > 0.006:
			lab.pixel_size = 0.0052
		if lab.font_size > 32:
			lab.font_size = 28
		# Replace raw stark white with cohesive storybook parchment ink + deep walnut outline
		if lab.modulate.r > 0.92 and lab.modulate.g > 0.92 and lab.modulate.b > 0.92:
			lab.modulate = Color(0.98, 0.93, 0.80)
		lab.outline_size = maxi(lab.outline_size, 7)
		lab.outline_modulate = Color(0.11, 0.06, 0.05, 0.95)
		lab.visibility_range_end = max_dist
		lab.visibility_range_end_margin = fade_margin
		lab.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

## Tier 1: Authored 3D crooked wooden signpost with text ENGRAVED directly on both faces
## of the arrow plank (zero floating billboard text above the post).
static func make_wooden_signpost(at: Vector3, label_text: String, accent: Color, toward: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "WoodenSignpost"
	root.position = at

	var wood := _mat(Color(0.32, 0.20, 0.11), 0.88)
	var wood_dark := _mat(Color(0.19, 0.11, 0.07), 0.90)
	var brass := _mat(Color(0.84, 0.68, 0.30), 0.30, 0.84)
	var glow := _mat(accent.lightened(0.35), 0.30, 0.0, accent, 1.1)

	# Carved cobblestone base + gently leaning timber post + brass finial
	_mi(root, _cyl(0.22, 0.28, 0.26, 10), _mat(Color(0.40, 0.38, 0.42), 0.92), Vector3(0, 0.13, 0))
	_mi(root, _cyl(0.068, 0.095, 2.38, 10), wood, Vector3(0, 1.26, 0), Vector3(0, 0, 2.0))
	_mi(root, _sph(0.10, 0.16, 10), brass, Vector3(-0.04, 2.48, 0))

	# Directional arrow plank oriented toward destination
	var plank_holder := Node3D.new()
	plank_holder.position = Vector3(0, 1.98, 0)
	root.add_child(plank_holder)
	var flat := toward - at
	flat.y = 0.0
	if flat.length() > 0.1:
		plank_holder.rotation.y = atan2(-flat.x, -flat.z) + PI * 0.5

	# Carved dark-walnut arrow board + gilded brass trim strips
	_mi(plank_holder, _box(Vector3(1.62, 0.42, 0.10)), wood_dark, Vector3(0.26, 0, 0))
	_mi(plank_holder, _box(Vector3(1.56, 0.035, 0.115)), brass, Vector3(0.26, 0.19, 0))
	_mi(plank_holder, _box(Vector3(1.56, 0.035, 0.115)), brass, Vector3(0.26, -0.19, 0))
	var tip := PrismMesh.new()
	tip.size = Vector3(0.42, 0.36, 0.10)
	_mi(plank_holder, tip, wood_dark, Vector3(1.25, 0, 0), Vector3(0, 0, -90))
	# Hammered brass arrowhead cap on the 3D pointed tip so direction is unmistakable!
	var tip_cap := PrismMesh.new()
	tip_cap.size = Vector3(0.32, 0.24, 0.12)
	_mi(plank_holder, tip_cap, brass, Vector3(1.30, 0, 0), Vector3(0, 0, -90))
	# Brass corner rivets
	for rx in [-0.46, 0.96]:
		for ry in [-0.12, 0.12]:
			_mi(plank_holder, _sph(0.025, 0.05, 6), brass, Vector3(float(rx), float(ry), 0.055))
			_mi(plank_holder, _sph(0.025, 0.05, 6), brass, Vector3(float(rx), float(ry), -0.055))
	# Hanging jewel-lantern finial off the back of the plank
	_mi(plank_holder, _cyl(0.015, 0.015, 0.18, 6), brass, Vector3(-0.52, -0.10, 0))
	_mi(plank_holder, _sph(0.085, 0.15, 10), glow, Vector3(-0.52, -0.24, 0))

	# Double-sided engraved parchment lettering: BOTH faces point their arrow toward the +X wooden tip!
	var clean_txt := label_text.replace("YBR → ", "").replace("YBR -> ", "").strip_edges()
	for face_z in [0.062, -0.062]:
		var lab := Label3D.new()
		lab.set_meta("styled_plaque", true)
		var is_front := float(face_z) > 0.0
		lab.text = ("✦  %s  ➔" % clean_txt) if is_front else ("⬅  %s  ✦" % clean_txt)
		lab.font_size = 28
		lab.pixel_size = 0.0046
		lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		lab.shaded = false
		lab.modulate = Color(0.99, 0.94, 0.80)
		lab.outline_size = 6
		lab.outline_modulate = Color(0.12, 0.06, 0.03)
		lab.visibility_range_end = 15.0
		lab.visibility_range_end_margin = 3.5
		lab.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		lab.position = Vector3(0.24, 0.0, float(face_z))
		if not is_front:
			lab.rotation_degrees.y = 180.0
		plank_holder.add_child(lab)
	return root

## Tier 2: Ornate scrolled wrought-iron & walnut architectural crest plaque for buildings.
static func make_building_crest_sign(parent: Node3D, local_pos: Vector3, title: String, accent: Color, greyscale: bool = false) -> MeshInstance3D:
	var root := Node3D.new()
	root.name = "BuildingCrestSign"
	root.position = local_pos
	parent.add_child(root)

	var iron := _mat(Color(0.16, 0.15, 0.18) if not greyscale else Color(0.20, 0.20, 0.22), 0.45, 0.78)
	var walnut := _mat(Color(0.20, 0.12, 0.08) if not greyscale else Color(0.26, 0.26, 0.28), 0.82)
	var brass := _mat(Color(0.86, 0.70, 0.30) if not greyscale else Color(0.68, 0.68, 0.72), 0.28, 0.86)
	var face_col := accent.darkened(0.55) if not greyscale else Color(0.18, 0.18, 0.20)
	var enamel := _mat(face_col, 0.55, 0.12)

	# Wrought-iron bracket arm + hanging chains
	_mi(root, _box(Vector3(0.10, 0.10, 0.85)), iron, Vector3(0, 0.48, -0.18))
	_mi(root, _cyl(0.025, 0.025, 0.26, 6), iron, Vector3(-0.72, 0.36, 0.22))
	_mi(root, _cyl(0.025, 0.025, 0.26, 6), iron, Vector3(0.72, 0.36, 0.22))

	# Chamfered walnut crest board (returned so caller can gently sway it)
	var board := _mi(root, _box(Vector3(2.45, 0.86, 0.12)), walnut, Vector3(0, 0.0, 0.24))
	_mi(board, _box(Vector3(2.32, 0.74, 0.13)), brass, Vector3(0, 0, 0.01))
	_mi(board, _box(Vector3(2.18, 0.60, 0.14)), enamel, Vector3(0, 0, 0.015))
	for ox in [-1.06, 1.06]:
		for oy in [-0.28, 0.28]:
			_mi(board, _sph(0.045, 0.08, 8), brass, Vector3(float(ox), float(oy), 0.08))

	var lab := Label3D.new()
	lab.set_meta("styled_plaque", true)
	lab.text = "✦  %s  ✦" % title.to_upper()
	lab.font_size = 54
	lab.pixel_size = 0.0062
	lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lab.shaded = false
	lab.modulate = Color(0.99, 0.92, 0.72) if not greyscale else Color(0.92, 0.92, 0.95)
	lab.outline_size = 10
	lab.outline_modulate = Color(0.10, 0.05, 0.04)
	lab.visibility_range_end = 20.0
	lab.visibility_range_end_margin = 4.0
	lab.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	lab.position = Vector3(0, 0.0, 0.10)
	board.add_child(lab)
	return board

## Tier 3: Compact diegetic storybook world badge (replaces raw floating white text on props).
static func make_world_badge(parent: Node3D, local_pos: Vector3, text: String, accent: Color = Color(0.96, 0.84, 0.48), max_dist: float = 10.5) -> Node3D:
	var holder := Node3D.new()
	holder.name = "WorldBadge"
	holder.position = local_pos
	parent.add_child(holder)

	var lab := Label3D.new()
	lab.set_meta("styled_plaque", true)
	lab.text = text
	lab.font_size = 28
	lab.pixel_size = 0.0050
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.shaded = false
	lab.modulate = accent.lerp(Color(0.99, 0.95, 0.85), 0.55)
	lab.outline_size = 9
	lab.outline_modulate = Color(0.09, 0.06, 0.08, 0.96)
	lab.visibility_range_end = max_dist
	lab.visibility_range_end_margin = 2.8
	lab.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	holder.add_child(lab)
	return holder

# ============================================================================
# CONTINUOUS GROUND APRON, WALKABLE HILLS, HORIZON SKYLINE & SWAYING GRASS
# ============================================================================

## Adds a vast SOLID COLLIDABLE under-meadow slab (100% WYSIWYG — zero invisible ledge drop-offs!).
static func add_ground_apron(parent: Node3D, width: float, depth: float, grass_col: Color, y_pos: float = -0.08) -> void:
	var body := StaticBody3D.new()
	body.name = "HorizonGroundApron"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(0, y_pos, 0)
	parent.add_child(body)
	var apron := _mi(body, _box(Vector3(width, 0.16, depth)), _mat(grass_col, 0.96), Vector3.ZERO)
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(width, 0.16, depth)
	cs.shape = sh
	body.add_child(cs)

## Outer horizon hills placed cleanly outside the MapBorder tree line WITH solid WYSIWYG colliders.
static func add_horizon_hills(parent: Node3D, half_x: float, half_z: float, hill_col: Color) -> void:
	var hroot := Node3D.new()
	hroot.name = "HorizonHills"
	parent.add_child(hroot)

	# Seamless SOLID collidable ground apron under the entire world + horizon ring!
	add_ground_apron(hroot, (half_x + 140.0) * 2.0, (half_z + 140.0) * 2.0, hill_col.darkened(0.04), -0.09)

	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var m_near := _mat(hill_col, 0.94)
	var m_far := _mat(hill_col.darkened(0.20), 0.96)

	for i in range(32):
		var ang := float(i) / 32.0 * TAU
		var rad := rng.randf_range(22.0, 34.0)
		# Keep the ENTIRE scaled hill skirt strictly OUTSIDE the playable MapBorder so characters NEVER get buried!
		var visual_r := rad * 1.35
		var margin := visual_r + 14.0
		var rx := (half_x + margin + rng.randf_range(0.0, 12.0)) * cos(ang)
		var rz := (half_z + margin + rng.randf_range(0.0, 12.0)) * sin(ang)
		var ht := rng.randf_range(14.0, 26.0)
		var mat := m_near if i % 2 == 0 else m_far
		var hbody := StaticBody3D.new()
		hbody.collision_layer = 1
		hbody.collision_mask = 0
		hbody.position = Vector3(rx, -ht * 0.16, rz)
		hroot.add_child(hbody)
		_mi(hbody, _sph(rad, ht, 16), mat, Vector3.ZERO, Vector3.ZERO, Vector3(1.35, 0.72, 1.35))
		var hcs := CollisionShape3D.new()
		var hsh := SphereShape3D.new()
		hsh.radius = visual_r
		hcs.shape = hsh
		hbody.add_child(hcs)

## Animated flowing water shader (scrolling dual-layer wave ripples, shimmering caustics & Fresnel sky reflection).
static func make_flowing_water_material(base_col: Color = Color(0.18, 0.62, 0.90), foam_col: Color = Color(0.76, 0.94, 1.0), flow_speed: float = 1.0) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, cull_back, specular_schlick_ggx;

uniform vec3 water_color : source_color = vec3(0.18, 0.62, 0.90);
uniform vec3 foam_color : source_color = vec3(0.76, 0.94, 1.0);
uniform float flow_speed = 1.0;

void vertex() {
	float t = TIME * flow_speed;
	float wave = sin(VERTEX.x * 2.4 + t * 2.2) * cos(VERTEX.z * 1.8 - t * 1.9) * 0.018;
	VERTEX.y += wave;
}

void fragment() {
	float t = TIME * flow_speed;
	vec2 uv1 = UV * vec2(5.0, 14.0) + vec2(0.0, -t * 0.42);
	vec2 uv2 = UV * vec2(8.0, 20.0) + vec2(t * 0.16, -t * 0.65);
	float r1 = sin(uv1.x * 6.28 + sin(uv1.y * 6.28)) * 0.5 + 0.5;
	float r2 = cos(uv2.y * 6.28 + cos(uv2.x * 4.5)) * 0.5 + 0.5;
	float caustic = smoothstep(0.68, 0.95, r1 * r2);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.8);
	vec3 col = mix(water_color, foam_color, caustic * 0.55 + fresnel * 0.35);
	ALBEDO = col;
	ROUGHNESS = 0.08;
	METALLIC = 0.18;
	EMISSION = foam_color * (caustic * 0.35 + fresnel * 0.25);
	ALPHA = 0.88;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("water_color", Vector3(base_col.r, base_col.g, base_col.b))
	mat.set_shader_parameter("foam_color", Vector3(foam_col.r, foam_col.g, foam_col.b))
	mat.set_shader_parameter("flow_speed", flow_speed)
	return mat

## Walkable, COLLIDABLE gentle grassy hills in the side meadows (characters physically climb up them!).
static func add_walkable_meadow_hills(parent: Node3D, specs: Array, grass_col: Color) -> void:
	var root := Node3D.new()
	root.name = "WalkableHills"
	parent.add_child(root)
	var mat := _mat(grass_col, 0.92)
	for s in specs:
		var pos: Vector3 = s["pos"]
		var radius: float = float(s["radius"])
		var height: float = float(s["height"])
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = pos
		root.add_child(body)
		# Gentle stepped/domed hill using a wide flattened sphere mesh + matching convex cylinder/sphere collision
		# Sink sphere center so only the gentle climbable crown (<28 deg slope) protrudes above ground!
		var big_r := (radius * radius + height * height) / (2.0 * maxf(height, 0.25))
		var center_y := height - big_r
		var mi := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = big_r
		sph.height = big_r * 2.0
		sph.radial_segments = 24
		sph.rings = 14
		mi.mesh = sph
		mi.material_override = mat
		mi.position = Vector3(0, center_y, 0)
		body.add_child(mi)

		var cs := CollisionShape3D.new()
		var csh := SphereShape3D.new()
		csh.radius = big_r
		cs.shape = csh
		cs.position = Vector3(0, center_y, 0)
		body.add_child(cs)

## Distant multi-spire crystalline Emerald City skyline silhouette far outside the north rim.
static func add_emerald_skyline(parent: Node3D, at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "EmeraldSkyline"
	root.position = at
	parent.add_child(root)
	var glass := _mat(Color(0.14, 0.72, 0.44), 0.18, 0.42, Color(0.12, 0.85, 0.48), 0.75)
	var spire_hi := _mat(Color(0.32, 0.95, 0.62), 0.12, 0.55, Color(0.28, 1.0, 0.62), 1.1)
	var spires := [
		{"x": 0.0, "r": 5.5, "h": 42.0},
		{"x": -11.0, "r": 3.8, "h": 28.0},
		{"x": 10.5, "r": 4.2, "h": 31.0},
		{"x": -20.0, "r": 3.0, "h": 20.0},
		{"x": 19.5, "r": 3.2, "h": 22.0},
	]
	for sp in spires:
		var sx: float = float(sp["x"])
		var sr: float = float(sp["r"])
		var sh: float = float(sp["h"])
		_mi(root, _cyl(sr * 0.55, sr, sh * 0.7, 10), glass, Vector3(sx, sh * 0.35, 0))
		_mi(root, _cyl(0.2, sr * 0.58, sh * 0.35, 10), spire_hi, Vector3(sx, sh * 0.87, 0))

## Replaces random ground pegs with clustered multi-blade swaying grass tufts & wildflowers
## strictly outside the Yellow Brick Road corridor.
static func scatter_swaying_grass(parent: Node3D, center: Vector3, radius: float, count: int, road_half_clear: float = 4.5) -> void:
	var groot := Node3D.new()
	groot.name = "SwayingGrass"
	parent.add_child(groot)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(center.z) * 13.0) + 42
	var m1 := make_wind_grass_material(Color(0.24, 0.54, 0.24))
	var m2 := make_wind_grass_material(Color(0.32, 0.60, 0.22))
	var m_fl_pink := make_wind_grass_material(Color(0.95, 0.42, 0.64))
	var m_fl_gold := make_wind_grass_material(Color(0.98, 0.84, 0.28))

	var blade_mesh := PrismMesh.new()
	blade_mesh.size = Vector3(0.08, 0.42, 0.025)
	var fl_mesh := _sph(0.075, 0.11, 7)

	for i in range(count):
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius
		var p := center + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		# Keep Yellow Brick Road corridor and immediate spawn spotless
		if absf(p.x) < road_half_clear:
			continue
		var tuft := Node3D.new()
		tuft.position = p
		tuft.rotation.y = rng.randf() * TAU
		groot.add_child(tuft)
		var gmat := m1 if i % 2 == 0 else m2
		var sc := rng.randf_range(0.75, 1.35)
		for b in range(3):
			var ba := float(b) * (TAU / 3.0)
			_mi(tuft, blade_mesh, gmat, Vector3(cos(ba) * 0.09, 0.20 * sc, sin(ba) * 0.09), Vector3(12.0, rad_to_deg(ba), 0), Vector3(1.0, sc, 1.0))
		if i % 4 == 0:
			var fmat := m_fl_pink if (i / 4) % 2 == 0 else m_fl_gold
			_mi(tuft, fl_mesh, fmat, Vector3(0, 0.42 * sc, 0))

# ============================================================================
# STORYBOOK COTTAGES, RICH INTERIORS, GNARLED TREES & STREET LANTERNS
# ============================================================================

static func dress_cottage_exterior(
	exterior: Node3D,
	half_w: float,
	half_d: float,
	wall_h: float,
	wall_col: Color,
	roof_col: Color,
	is_hall: bool = false
) -> void:
	if exterior == null:
		return
	var old_roof := exterior.get_node_or_null("Roof") as Node3D
	if old_roof:
		old_roof.visible = false

	var trim_root := Node3D.new()
	trim_root.name = "StorybookArchitecture"
	exterior.add_child(trim_root)

	var stone_mat := _mat(Color(0.38, 0.36, 0.40), 0.92)
	var timber_mat := _mat(Color(0.24, 0.14, 0.10), 0.85)
	var roof_mat := _mat(roof_col, 0.72)
	var ridge_mat := _mat(roof_col.darkened(0.32), 0.65, 0.15)
	var window_glow := _mat(Color(1.0, 0.90, 0.62), 0.25, 0.0, Color(1.0, 0.85, 0.48), 1.35)
	var shutter_mat := _mat(wall_col.darkened(0.38), 0.78)
	var flower_pink := _mat(Color(0.95, 0.32, 0.56), 0.65)
	var flower_gold := _mat(Color(0.98, 0.80, 0.24), 0.65)
	var stitch_mat := _mat(Color(0.30, 0.08, 0.18), 0.5, 0.0, Color(0.75, 0.18, 0.42), 0.75)

	var full_w := half_w * 2.0
	var full_d := half_d * 2.0

	_mi(trim_root, _box(Vector3(full_w + 0.55, 0.42, full_d + 0.55)), stone_mat, Vector3(0, 0.21, 0))

	for sx in [-1.0, 1.0]:
		var px: float = float(sx) * (half_w + 0.08)
		for sz in [-1.0, 1.0]:
			var pz: float = float(sz) * (half_d + 0.08)
			_mi(trim_root, _box(Vector3(0.26, wall_h + 0.1, 0.26)), timber_mat, Vector3(px, wall_h * 0.5, pz))

	for bh in [wall_h * 0.52, wall_h - 0.12]:
		var by: float = float(bh)
		_mi(trim_root, _box(Vector3(full_w + 0.34, 0.18, 0.20)), timber_mat, Vector3(0, by, half_d + 0.12))
		_mi(trim_root, _box(Vector3(full_w + 0.34, 0.18, 0.20)), timber_mat, Vector3(0, by, -half_d - 0.12))
		_mi(trim_root, _box(Vector3(0.20, 0.18, full_d + 0.34)), timber_mat, Vector3(-half_w - 0.12, by, 0))
		_mi(trim_root, _box(Vector3(0.20, 0.18, full_d + 0.34)), timber_mat, Vector3(half_w + 0.12, by, 0))

	var roof_h := 2.75 if not is_hall else 3.4
	var gable := PrismMesh.new()
	gable.left_to_right = 0.5
	gable.size = Vector3(full_w + 0.28, roof_h, full_d + 0.16)
	_mi(trim_root, gable, _mat(wall_col.darkened(0.06), 0.85), Vector3(0, wall_h + roof_h * 0.5, 0))

	var slope_len := sqrt((half_w + 0.85) * (half_w + 0.85) + (roof_h + 0.15) * (roof_h + 0.15))
	var slope_ang := rad_to_deg(atan2(roof_h, half_w + 0.15))
	var roof_z := full_d + 1.45
	var mid_x := (half_w + 0.42) * 0.5
	var mid_y := wall_h + roof_h * 0.5 + 0.08
	_mi(trim_root, _box(Vector3(slope_len, 0.24, roof_z)), roof_mat, Vector3(-mid_x, mid_y, 0), Vector3(0, 0, slope_ang))
	_mi(trim_root, _box(Vector3(slope_len, 0.24, roof_z)), roof_mat, Vector3(mid_x, mid_y, 0), Vector3(0, 0, -slope_ang))

	_mi(trim_root, _box(Vector3(0.28, 0.28, roof_z + 0.2)), ridge_mat, Vector3(0, wall_h + roof_h + 0.14, 0))
	for fz in [-1.0, 1.0]:
		var fpos := Vector3(0, wall_h + roof_h + 0.45, float(fz) * (roof_z * 0.5 + 0.05))
		_mi(trim_root, _cyl(0.03, 0.08, 0.65, 8), ridge_mat, fpos)

	var chim_x := half_w * 0.52
	var chim_z := -half_d * 0.35
	var chim_mat := _mat(Color(0.46, 0.24, 0.22), 0.90)
	_mi(trim_root, _box(Vector3(0.75, roof_h + 1.2, 0.75)), chim_mat, Vector3(chim_x, wall_h + roof_h * 0.55, chim_z), Vector3(0, 0, -4.5))
	_mi(trim_root, _box(Vector3(0.95, 0.22, 0.95)), stone_mat, Vector3(chim_x + 0.1, wall_h + roof_h + 0.62, chim_z), Vector3(0, 0, -4.5))

	var porch_z := half_d + 0.75
	_mi(trim_root, _box(Vector3(2.4, 0.16, 1.35)), stone_mat, Vector3(0, 0.08, porch_z))
	_mi(trim_root, _box(Vector3(2.55, 0.18, 1.45)), roof_mat, Vector3(0, 2.58, porch_z), Vector3(14, 0, 0))
	for px_sign in [-1.0, 1.0]:
		_mi(trim_root, _cyl(0.08, 0.10, 2.45, 8), timber_mat, Vector3(float(px_sign) * 1.12, 1.28, half_d + 1.25))
	# Leaning spoked wooden wagon wheel beside porch (bldg_01_gale_farmhouse.jpg)
	var wheel_pos := Vector3(1.75, 0.56, half_d + 0.35)
	_mi(trim_root, _torus(0.46, 0.52, 14), timber_mat, wheel_pos, Vector3(78, 14, 0))
	for wi in range(4):
		_mi(trim_root, _cyl(0.024, 0.024, 0.96, 6), timber_mat, wheel_pos, Vector3(-12, 14, float(wi) * 45.0))

	for wx_sign in [-1.0, 1.0]:
		var wx: float = float(wx_sign) * (half_w * 0.56)
		_add_window(trim_root, Vector3(wx, 1.95, half_d + 0.17), 0.0, window_glow, timber_mat, shutter_mat, flower_pink, flower_gold)
	# Glowing circular stained-glass rosette gable window (munch_04_cottage_exterior.jpg)
	_mi(trim_root, _cyl(0.56, 0.56, 0.12, 16), timber_mat, Vector3(0, wall_h + roof_h * 0.42, half_d + 0.12), Vector3(90, 0, 0))
	_mi(trim_root, _cyl(0.46, 0.46, 0.14, 16), window_glow, Vector3(0, wall_h + roof_h * 0.42, half_d + 0.13), Vector3(90, 0, 0))
	for side_sign in [-1.0, 1.0]:
		var sx: float = float(side_sign) * (half_w + 0.17)
		var rot_y: float = 90.0 if side_sign > 0.0 else -90.0
		_add_window(trim_root, Vector3(sx, 1.95, 0.0), rot_y, window_glow, timber_mat, shutter_mat, flower_pink, flower_gold)

	for i in range(4):
		var st_x: float = -half_w * 0.6 + float(i) * (half_w * 0.4)
		_mi(trim_root, _box(Vector3(0.08, 0.55, 0.08)), stitch_mat, Vector3(st_x, wall_h * 0.68, -half_d - 0.18), Vector3(0, 0, 22.0 if i % 2 == 0 else -22.0))

static func _add_window(
	parent: Node3D,
	pos: Vector3,
	rot_y_deg: float,
	glow_mat: Material,
	frame_mat: Material,
	shutter_mat: Material,
	fl1: Material,
	fl2: Material
) -> void:
	var wroot := Node3D.new()
	wroot.position = pos
	wroot.rotation_degrees = Vector3(0, rot_y_deg, 0)
	parent.add_child(wroot)

	_mi(wroot, _box(Vector3(0.95, 1.05, 0.06)), glow_mat, Vector3.ZERO)
	_mi(wroot, _box(Vector3(1.12, 0.12, 0.12)), frame_mat, Vector3(0, 0.56, 0.02))
	_mi(wroot, _box(Vector3(1.16, 0.14, 0.18)), frame_mat, Vector3(0, -0.56, 0.04))
	_mi(wroot, _box(Vector3(0.08, 1.05, 0.10)), frame_mat, Vector3(0, 0, 0.04))
	_mi(wroot, _box(Vector3(0.95, 0.08, 0.10)), frame_mat, Vector3(0, 0.06, 0.04))
	_mi(wroot, _box(Vector3(0.36, 1.04, 0.08)), shutter_mat, Vector3(-0.72, 0, 0.03), Vector3(0, 12, 0))
	_mi(wroot, _box(Vector3(0.36, 1.04, 0.08)), shutter_mat, Vector3(0.72, 0, 0.03), Vector3(0, -12, 0))
	_mi(wroot, _box(Vector3(1.05, 0.22, 0.26)), frame_mat, Vector3(0, -0.72, 0.12))
	_mi(wroot, _sph(0.11, 0.16, 8), fl1, Vector3(-0.30, -0.56, 0.14))
	_mi(wroot, _sph(0.12, 0.16, 8), fl2, Vector3(0.0, -0.55, 0.16))
	_mi(wroot, _sph(0.11, 0.16, 8), fl1, Vector3(0.30, -0.56, 0.14))

## Richly furnished storybook interior replacing empty boxes + double floating text.
static func build_rich_interior(parent: Node3D, half_w: float, half_d: float, wall_h: float, wall_col: Color, title: String) -> Node3D:
	var fit := Node3D.new()
	fit.name = "InteriorFitout"
	parent.add_child(fit)

	var wood_floor := _mat(Color(0.38, 0.25, 0.16), 0.78)
	var timber := _mat(Color(0.24, 0.15, 0.09), 0.84)
	var plaster := _mat(wall_col.lerp(Color(0.94, 0.89, 0.80), 0.55), 0.90)
	var wainscot := _mat(Color(0.32, 0.21, 0.14), 0.82)
	var rug_mat := _mat(Color(0.56, 0.14, 0.24), 0.94)
	var rug_trim := _mat(Color(0.88, 0.72, 0.32), 0.85)
	var brass := _mat(Color(0.86, 0.70, 0.30), 0.3, 0.85)
	var stone := _mat(Color(0.36, 0.34, 0.38), 0.92)
	var fire_glow := _mat(Color(1.0, 0.55, 0.14), 0.2, 0.0, Color(1.0, 0.45, 0.10), 2.4)
	var candle_glow := _mat(Color(1.0, 0.92, 0.65), 0.2, 0.0, Color(1.0, 0.88, 0.52), 2.0)
	var parchment := _mat(Color(0.95, 0.90, 0.78), 0.82)

	var fw := half_w * 2.0 - 0.25
	var fd := half_d * 2.0 - 0.25

	# Planked floor + woven parlor rug
	_mi(fit, _box(Vector3(fw, 0.10, fd)), wood_floor, Vector3(0, 0.05, 0))
	_mi(fit, _cyl(minf(half_w, half_d) * 0.58, minf(half_w, half_d) * 0.58, 0.03, 20), rug_trim, Vector3(0, 0.11, 0.2))
	_mi(fit, _cyl(minf(half_w, half_d) * 0.50, minf(half_w, half_d) * 0.50, 0.035, 20), rug_mat, Vector3(0, 0.115, 0.2))

	# Warm plaster walls + wood wainscoting skirt + FULL 4th front wall (+Z) with Exit Door + ceiling slab
	_mi(fit, _box(Vector3(fw, wall_h - 0.1, 0.08)), plaster, Vector3(0, wall_h * 0.5, -half_d + 0.12))
	_mi(fit, _box(Vector3(0.08, wall_h - 0.1, fd)), plaster, Vector3(-half_w + 0.12, wall_h * 0.5, 0))
	_mi(fit, _box(Vector3(0.08, wall_h - 0.1, fd)), plaster, Vector3(half_w - 0.12, wall_h * 0.5, 0))
	_mi(fit, _box(Vector3(fw, 0.12, fd)), timber, Vector3(0, wall_h - 0.06, 0)) # solid ceiling above rafters

	# 4th Front Wall (+Z) flanking the interior Exit Doorway so turning around never shows the outside!
	var front_z := half_d - 0.12
	var door_w := 1.25
	var door_h := 2.25
	var side_w := maxf(0.4, (fw - door_w) * 0.5)
	_mi(fit, _box(Vector3(side_w, wall_h - 0.1, 0.08)), plaster, Vector3(-(door_w * 0.5 + side_w * 0.5), wall_h * 0.5, front_z))
	_mi(fit, _box(Vector3(side_w, wall_h - 0.1, 0.08)), plaster, Vector3(door_w * 0.5 + side_w * 0.5, wall_h * 0.5, front_z))
	_mi(fit, _box(Vector3(door_w + 0.2, maxf(0.3, wall_h - door_h), 0.08)), plaster, Vector3(0, door_h + (wall_h - door_h) * 0.5, front_z))
	# Ornate closed interior Exit Door + timber jambs + iron hinges + glowing brass handle + lintel plaque
	_mi(fit, _box(Vector3(door_w, door_h, 0.10)), timber, Vector3(0, door_h * 0.5, front_z - 0.02))
	_mi(fit, _box(Vector3(0.14, door_h + 0.12, 0.16)), wainscot, Vector3(-door_w * 0.5 - 0.05, door_h * 0.5, front_z - 0.04))
	_mi(fit, _box(Vector3(0.14, door_h + 0.12, 0.16)), wainscot, Vector3(door_w * 0.5 + 0.05, door_h * 0.5, front_z - 0.04))
	_mi(fit, _box(Vector3(door_w + 0.28, 0.16, 0.18)), wainscot, Vector3(0, door_h + 0.08, front_z - 0.04))
	_mi(fit, _sph(0.065, 0.13, 10), brass, Vector3(0.42, 1.05, front_z - 0.10)) # brass doorknob
	_mi(fit, _box(Vector3(0.35, 0.06, 0.04)), _mat(Color(0.12, 0.12, 0.14), 0.4, 0.8), Vector3(-0.42, 1.75, front_z - 0.08))
	_mi(fit, _box(Vector3(0.35, 0.06, 0.04)), _mat(Color(0.12, 0.12, 0.14), 0.4, 0.8), Vector3(-0.42, 0.55, front_z - 0.08))
	var exit_plaque := Label3D.new()
	exit_plaque.set_meta("styled_plaque", true)
	exit_plaque.text = "EXIT (E)"
	exit_plaque.font_size = 24
	exit_plaque.pixel_size = 0.0045
	exit_plaque.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	exit_plaque.shaded = false
	exit_plaque.modulate = Color(0.98, 0.88, 0.58)
	exit_plaque.outline_size = 5
	exit_plaque.position = Vector3(0, door_h + 0.32, front_z - 0.12)
	exit_plaque.rotation_degrees.y = 180.0
	fit.add_child(exit_plaque)

	_mi(fit, _box(Vector3(fw, 0.95, 0.12)), wainscot, Vector3(0, 0.52, -half_d + 0.16))
	_mi(fit, _box(Vector3(0.12, 0.95, fd)), wainscot, Vector3(-half_w + 0.16, 0.52, 0))
	_mi(fit, _box(Vector3(0.12, 0.95, fd)), wainscot, Vector3(half_w - 0.16, 0.52, 0))
	_mi(fit, _box(Vector3(side_w, 0.95, 0.12)), wainscot, Vector3(-(door_w * 0.5 + side_w * 0.5), 0.52, front_z - 0.04))
	_mi(fit, _box(Vector3(side_w, 0.95, 0.12)), wainscot, Vector3(door_w * 0.5 + side_w * 0.5, 0.52, front_z - 0.04))

	# Ceiling beams + hanging wrought-iron candelabrum
	for bi in range(3):
		var bz := -half_d * 0.55 + float(bi) * (half_d * 0.55)
		_mi(fit, _box(Vector3(fw, 0.18, 0.22)), timber, Vector3(0, wall_h - 0.25, bz))
	_mi(fit, _cyl(0.03, 0.03, 0.75, 8), timber, Vector3(0, wall_h - 0.62, 0))
	_mi(fit, _cyl(0.55, 0.55, 0.06, 14), brass, Vector3(0, wall_h - 0.98, 0))
	for ci in range(4):
		var ca := float(ci) * PI * 0.5
		_mi(fit, _cyl(0.035, 0.04, 0.18, 8), parchment, Vector3(cos(ca) * 0.48, wall_h - 0.88, sin(ca) * 0.48))
		_mi(fit, _sph(0.045, 0.09, 8), candle_glow, Vector3(cos(ca) * 0.48, wall_h - 0.76, sin(ca) * 0.48))

	# Stone brick hearth & crackling 3D fire on right wall
	var hx := half_w - 0.75
	_mi(fit, _box(Vector3(0.95, 1.45, 1.65)), stone, Vector3(hx, 0.78, -0.6))
	_mi(fit, _box(Vector3(1.15, 0.16, 1.95)), timber, Vector3(hx - 0.05, 1.56, -0.6)) # mantelpiece
	_mi(fit, _box(Vector3(0.55, 0.75, 0.95)), _mat(Color(0.08, 0.06, 0.07), 0.95), Vector3(hx - 0.25, 0.46, -0.6))
	_mi(fit, _cyl(0.07, 0.08, 0.65, 8), timber, Vector3(hx - 0.30, 0.24, -0.6), Vector3(80, 20, 0))
	_mi(fit, _sph(0.22, 0.48, 10), fire_glow, Vector3(hx - 0.30, 0.44, -0.6))

	# Stocked bookshelf / ledger cabinet against back-left wall
	var bx := -half_w + 1.15
	var bz_back := -half_d + 0.52
	_mi(fit, _box(Vector3(1.65, 2.25, 0.48)), timber, Vector3(bx, 1.18, bz_back))
	var book_cols := [Color(0.65, 0.16, 0.22), Color(0.18, 0.42, 0.28), Color(0.22, 0.30, 0.58), Color(0.76, 0.58, 0.20)]
	for sh_i in range(3):
		var sy := 0.65 + float(sh_i) * 0.55
		for bk in range(5):
			var bcol: Color = book_cols[(sh_i + bk) % book_cols.size()]
			_mi(fit, _box(Vector3(0.18, 0.34, 0.26)), _mat(bcol, 0.75), Vector3(bx - 0.52 + float(bk) * 0.25, sy, bz_back + 0.12))

	# Hero centerpiece furniture by building type
	var tlow := title.to_lower()
	if "debt" in tlow or "mayor" in tlow or "hall" in tlow:
		# Mahogany counting desk + open ledger + gold coin stacks + chair
		_mi(fit, _box(Vector3(2.1, 0.12, 1.05)), timber, Vector3(0.2, 0.88, -half_d + 1.35))
		for lx in [-0.88, 0.88]:
			for lz in [-0.4, 0.4]:
				_mi(fit, _box(Vector3(0.12, 0.82, 0.12)), timber, Vector3(0.2 + float(lx), 0.44, -half_d + 1.35 + float(lz)))
		_mi(fit, _box(Vector3(0.62, 0.06, 0.42)), parchment, Vector3(0.1, 0.97, -half_d + 1.35))
		_mi(fit, _cyl(0.08, 0.08, 0.16, 10), brass, Vector3(0.68, 1.02, -half_d + 1.28))
		_mi(fit, _cyl(0.07, 0.07, 0.11, 10), brass, Vector3(0.84, 0.99, -half_d + 1.42))
	else:
		# Quilted cottage bed + pillows + carved tea table
		_mi(fit, _box(Vector3(1.85, 0.52, 1.35)), timber, Vector3(-half_w + 1.35, 0.32, 0.85))
		_mi(fit, _box(Vector3(1.70, 0.22, 1.22)), _mat(wall_col.lightened(0.25), 0.88), Vector3(-half_w + 1.35, 0.66, 0.85))
		_mi(fit, _box(Vector3(0.45, 0.16, 0.85)), parchment, Vector3(-half_w + 0.72, 0.82, 0.85))
		# Round tea table + braided oval parlor rug + cast-iron pot-belly stove (bldg_05_farmhouse_interior.jpg)
		_mi(fit, _cyl(1.45, 1.48, 0.025, 20), _mat(wall_col.darkened(0.22), 0.94), Vector3(0.2, 0.055, -0.35), Vector3.ZERO, Vector3(1.25, 1.0, 0.92))
		_mi(fit, _cyl(0.62, 0.62, 0.08, 14), timber, Vector3(0.2, 0.82, -0.35))
		_mi(fit, _cyl(0.10, 0.18, 0.76, 10), timber, Vector3(0.2, 0.42, -0.35))
		_mi(fit, _sph(0.14, 0.22, 10), brass, Vector3(0.15, 0.96, -0.35))
		var stove_iron := _mat(Color(0.16, 0.15, 0.17), 0.42, 0.72)
		var stove_pos := Vector3(half_w - 0.95, 0.0, -half_d + 0.95)
		_mi(fit, _cyl(0.32, 0.36, 0.95, 14), stove_iron, stove_pos + Vector3(0, 0.52, 0))
		_mi(fit, _sph(0.34, 0.42, 12), stove_iron, stove_pos + Vector3(0, 0.62, 0))
		_mi(fit, _cyl(0.11, 0.11, wall_h - 1.1, 10), stove_iron, stove_pos + Vector3(0, 1.0 + (wall_h - 1.1) * 0.5, 0)) # tall stovepipe

	# Framed wall painting / brass title plaque + 3 gilded smiling porcelain wall masks (munch_01_cottage_interior.jpg)
	_mi(fit, _box(Vector3(1.85, 0.78, 0.08)), brass, Vector3(0.65, 2.15, -half_d + 0.18))
	var mask_porc := _mat(Color(0.96, 0.94, 0.92), 0.25)
	var rose_velvet := _mat(Color(0.62, 0.24, 0.36), 0.78)
	for mi_i in range(3):
		var mx := 0.05 + float(mi_i) * 0.58
		_mi(fit, _torus(0.16, 0.20, 12), brass, Vector3(mx, 1.48, -half_d + 0.18), Vector3(90, 0, 0))
		_mi(fit, _sph(0.14, 0.22, 10), mask_porc, Vector3(mx, 1.48, -half_d + 0.20), Vector3.ZERO, Vector3(0.9, 1.15, 0.45))
	# Tufted rose-velvet parlor settee along left-center wall
	_mi(fit, _box(Vector3(1.85, 0.42, 0.72)), rose_velvet, Vector3(-0.35, 0.28, -half_d + 0.95))
	_mi(fit, _box(Vector3(1.85, 0.62, 0.18)), rose_velvet, Vector3(-0.35, 0.66, -half_d + 0.65))
	_mi(fit, _box(Vector3(1.92, 0.08, 0.20)), brass, Vector3(-0.35, 0.98, -half_d + 0.65))
	_mi(fit, _box(Vector3(1.68, 0.62, 0.09)), _mat(Color(0.14, 0.10, 0.12), 0.7), Vector3(0.65, 2.15, -half_d + 0.20))
	var plaque := Label3D.new()
	plaque.text = title.to_upper()
	plaque.font_size = 26
	plaque.pixel_size = 0.005
	plaque.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	plaque.modulate = Color(0.98, 0.88, 0.58)
	plaque.outline_size = 4
	plaque.position = Vector3(0.65, 2.15, -half_d + 0.26)
	fit.add_child(plaque)

	# Interactive interior activities: Gilded Desire Chest + Shattered Memory Keepsake!
	var mem_id := "munchkin_silver_ledger" if ("debt" in tlow or "mayor" in tlow or "hall" in tlow) else "munchkin_porcelain_mask"
	add_interior_activities(fit, "cottage_%s" % tlow.replace(" ", "_"), mem_id, Vector3(half_w - 1.5, 0.08, 0.9), Vector3(-0.3, 0.08, -half_d + 1.8), false)

	# Warm interior lighting
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.90, 0.70)
	lamp.light_energy = 2.4
	lamp.omni_range = 12.0
	lamp.position = Vector3(0, wall_h - 1.05, 0)
	fit.add_child(lamp)

	var hearth_light := OmniLight3D.new()
	hearth_light.light_color = Color(1.0, 0.58, 0.24)
	hearth_light.light_energy = 1.8
	hearth_light.omni_range = 7.0
	hearth_light.position = Vector3(hx - 0.6, 0.75, -0.6)
	fit.add_child(hearth_light)

	return fit

## Populates a building interior with an interactive Gilded Desire Chest (+15 Desire) & Shattered Memory Crystal (Codex Lore).
static func add_interior_activities(fit: Node3D, room_id: String, memory_id: String, chest_pos: Vector3, mem_pos: Vector3, monochrome: bool = false) -> void:
	var pickup_script := preload("res://systems/interior_pickup.gd")
	var gold_c := Color(0.75, 0.75, 0.78) if monochrome else Color(0.95, 0.78, 0.30)
	var wood_c := Color(0.28, 0.28, 0.31) if monochrome else Color(0.32, 0.16, 0.14)
	var rose_c := Color(0.92, 0.92, 0.96) if monochrome else Color(0.98, 0.32, 0.58)

	# 1) Curved-lid Ornate Gilded Desire Chest (vaulted barrel lid + brass bands + inner crimson velvet)
	var chest := Area3D.new()
	chest.set_script(pickup_script)
	chest.name = "DesireChest"
	chest.set("kind", "chest")
	chest.set("item_id", "%s_chest" % room_id)
	chest.set("reward_amount", 15)
	chest.position = chest_pos
	fit.add_child(chest)
	var ccol := CollisionShape3D.new()
	var csh := SphereShape3D.new()
	csh.radius = 1.3
	ccol.shape = csh
	chest.add_child(ccol)
	var cvis := Node3D.new()
	cvis.name = "Visual"
	chest.add_child(cvis)
	var brass_m := _mat(gold_c, 0.20, 0.92, gold_c, 0.40)
	_mi(cvis, _box(Vector3(0.90, 0.44, 0.56)), _mat(wood_c, 0.62), Vector3(0, 0.22, 0))
	for bx in [-0.42, 0.0, 0.42]:
		_mi(cvis, _box(Vector3(0.075, 0.47, 0.62)), brass_m, Vector3(float(bx), 0.235, 0))
	_mi(cvis, _box(Vector3(0.97, 0.06, 0.63)), brass_m, Vector3(0, 0.45, 0))
	# Glowing jewels inside chest
	_mi(cvis, _sph(0.18, 0.14, 10), _mat(rose_c, 0.12, 0.3, rose_c, 1.8), Vector3(0, 0.44, 0))
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.47, -0.28)
	cvis.add_child(lid)
	_mi(lid, _cyl(0.26, 0.26, 0.88, 12), _mat(wood_c.lightened(0.08), 0.58), Vector3(0, 0.02, 0.28), Vector3(0, 0, 90))
	for bx in [-0.42, 0.0, 0.42]:
		_mi(lid, _cyl(0.295, 0.295, 0.075, 12), brass_m, Vector3(float(bx), 0.02, 0.28), Vector3(0, 0, 90))
	_mi(lid, _box(Vector3(0.16, 0.16, 0.07)), brass_m, Vector3(0, 0.0, 0.59))
	make_world_badge(chest, Vector3(0, 1.15, 0), "♦  Gilded Treasure Chest (+15 Desire)", gold_c.lightened(0.15), 8.0)

	# 2) Floating Shattered Memory Keepsake
	if memory_id != "":
		var mem := Area3D.new()
		mem.set_script(pickup_script)
		mem.name = "ShatteredMemory"
		mem.set("kind", "memory")
		mem.set("item_id", memory_id)
		mem.position = mem_pos
		fit.add_child(mem)
		var mcol := CollisionShape3D.new()
		var msh := SphereShape3D.new()
		msh.radius = 1.25
		mcol.shape = msh
		mem.add_child(mcol)
		var mvis := Node3D.new()
		mvis.name = "Visual"
		mvis.position = Vector3(0, 0.95, 0)
		mem.add_child(mvis)
		var crystal_m := _mat(rose_c, 0.14, 0.30, rose_c, 1.8)
		_mi(mvis, _cyl(0.02, 0.18, 0.32, 6), crystal_m, Vector3(0, 0.16, 0))
		_mi(mvis, _cyl(0.18, 0.02, 0.32, 6), crystal_m, Vector3(0, -0.16, 0))
		make_world_badge(mem, Vector3(0, 1.65, 0), "✦  Shattered Memory", rose_c.lightened(0.20), 8.0)

static func make_gnarled_tree(at: Vector3, rng: RandomNumberGenerator, scale_mult: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.scale = Vector3.ONE * scale_mult

	var bark := _mat(Color(0.26, 0.17, 0.12).lerp(Color(0.18, 0.13, 0.14), rng.randf() * 0.45), 0.94)
	var th := rng.randf_range(2.2, 3.6)
	var lean_x := rng.randf_range(-7.0, 7.0)
	var lean_z := rng.randf_range(-7.0, 7.0)

	for r_i in range(4):
		var ang := float(r_i) * PI * 0.5 + rng.randf_range(-0.3, 0.3)
		var rpos := Vector3(cos(ang) * 0.32, 0.24, sin(ang) * 0.32)
		_mi(root, _cyl(0.06, 0.16, 0.7, 7), bark, rpos, Vector3(sin(ang) * 35.0, 0, -cos(ang) * 35.0))

	_mi(root, _cyl(0.16, 0.30, th, 10), bark, Vector3(0, th * 0.5, 0), Vector3(lean_x, 0, lean_z))

	var base_leaf := Color(0.16, 0.42, 0.26).lerp(Color(0.28, 0.52, 0.22), rng.randf())
	var hi_leaf := base_leaf.lightened(0.16)
	var dark_leaf := base_leaf.darkened(0.22)

	var top_p := Vector3(0, th, 0)
	_mi(root, _sph(rng.randf_range(1.15, 1.55), rng.randf_range(1.7, 2.2), 14), make_leaf_wind_material(base_leaf), top_p + Vector3(0, 0.55, 0))

	for b_i in range(3):
		var bang := float(b_i) * (TAU / 3.0) + rng.randf_range(-0.35, 0.35)
		var bdir := Vector3(cos(bang), 0.55, sin(bang)).normalized()
		var blen := rng.randf_range(1.1, 1.7)
		var bmid := top_p + Vector3(0, -0.35, 0) + bdir * (blen * 0.5)
		_mi(root, _cyl(0.06, 0.12, blen, 7), bark, bmid, Vector3(sin(bang) * 42.0, 0, -cos(bang) * 42.0))

		var tip := top_p + Vector3(0, -0.25, 0) + bdir * blen
		var lmat := make_leaf_wind_material(hi_leaf if b_i == 0 else (dark_leaf if b_i == 2 else base_leaf))
		var cr := rng.randf_range(0.85, 1.25)
		_mi(root, _sph(cr, cr * 1.45, 12), lmat, tip)

	return root

static func make_street_lantern(at: Vector3, glow_col: Color = Color(1.0, 0.86, 0.45), with_light: bool = false) -> Node3D:
	var root := Node3D.new()
	root.position = at

	var iron := _mat(Color(0.14, 0.13, 0.16), 0.52, 0.72)
	var brass := _mat(Color(0.78, 0.62, 0.28), 0.34, 0.82)
	var glass := _mat(glow_col, 0.2, 0.0, glow_col, 1.8)

	_mi(root, _cyl(0.18, 0.24, 0.45, 8), iron, Vector3(0, 0.22, 0))
	_mi(root, _cyl(0.055, 0.085, 3.1, 8), iron, Vector3(0, 1.85, 0), Vector3(0, 0, 2.5))
	_mi(root, _cyl(0.11, 0.11, 0.12, 8), brass, Vector3(0.04, 2.85, 0))
	_mi(root, _box(Vector3(0.75, 0.06, 0.06)), iron, Vector3(0.36, 3.38, 0), Vector3(0, 0, -8.0))
	var lpos := Vector3(0.68, 3.06, 0)
	_mi(root, _cyl(0.04, 0.24, 0.22, 6), brass, lpos + Vector3(0, 0.24, 0))
	_mi(root, _cyl(0.16, 0.12, 0.34, 6), glass, lpos)
	_mi(root, _cyl(0.14, 0.05, 0.12, 6), brass, lpos + Vector3(0, -0.22, 0))
	# Hanging glowing Northern Star charm beneath lantern arm (munch_02_signpost_lantern.jpg)
	_mi(root, _cyl(0.008, 0.008, 0.26, 6), brass, Vector3(0.28, 3.16, 0))
	_mi(root, _sph(0.055, 0.11, 8), glass, Vector3(0.28, 3.00, 0))

	if with_light:
		var light := OmniLight3D.new()
		light.light_color = glow_col
		light.light_energy = 1.6
		light.omni_range = 10.0
		light.shadow_enabled = false
		light.position = lpos
		root.add_child(light)

	return root

static func dress_ybr_spine(parent: Node3D, z_start: float, z_end: float, road_half_w: float = 2.75) -> void:
	var yroot := Node3D.new()
	yroot.name = "YBRAdornments"
	parent.add_child(yroot)

	# Continuous flush golden-stone YBR curb rails (NO random gaps/pegs!) + street lanterns
	var curb_mat := _mat(Color(0.86, 0.68, 0.22), 0.52, 0.22)
	var z := z_start
	var idx := 0
	while z <= z_end:
		for sx in [-1.0, 1.0]:
			var cx: float = float(sx) * (road_half_w + 0.16)
			_mi(yroot, _box(Vector3(0.28, 0.06, 4.25)), curb_mat, Vector3(cx, 0.03, z))
		if idx % 5 == 0:
			var side: float = -1.0 if (idx / 5) % 2 == 0 else 1.0
			var lpos := Vector3(side * (road_half_w + 1.15), 0.0, z)
			var lantern := make_street_lantern(lpos, Color(1.0, 0.88, 0.52), idx % 10 == 0)
			lantern.rotation_degrees.y = 0.0 if side < 0.0 else 180.0
			yroot.add_child(lantern)
		z += 4.2
		idx += 1

# ============================================================================
# SCULPTED CHARACTERS: LOCASTA & WICKED WITCH OF THE WEST
# ============================================================================

## Contoured, high-fashion fairytale Good Witch of the North (smooth curves, gossamer veil, braids).
static func build_locasta_visual(parent: Node3D) -> void:
	var gown := _mat(Color(0.92, 0.95, 1.0), 0.42, 0.08, Color(0.55, 0.68, 0.95), 0.16)
	var silk := _mat(Color(0.80, 0.87, 0.99), 0.36, 0.12)
	var gold := _mat(Color(0.96, 0.82, 0.42), 0.24, 0.88, Color(0.96, 0.80, 0.34), 0.22)
	var veil := _mat(Color(0.88, 0.93, 1.0, 0.55), 0.35, 0.05)
	veil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var skin := _mat(Color(0.95, 0.81, 0.72), 0.44)
	var hair := _mat(Color(0.88, 0.90, 0.96), 0.52, 0.15)
	var eye := _mat(Color(0.22, 0.46, 0.82), 0.20)
	var lip := _mat(Color(0.76, 0.34, 0.44), 0.42)
	var crystal := _mat(Color(1.0, 0.95, 0.68), 0.10, 0.2, Color(1.0, 0.92, 0.55), 1.9)

	# Smooth tiered royal ballgown (NO protruding waist-poles!) + gilded scallops & satin sash
	_mi(parent, _cyl(0.16, 0.62, 1.04, 28), gown, Vector3(0, 0.52, 0))
	_mi(parent, _cyl(0.19, 0.46, 0.52, 24), silk, Vector3(0, 0.78, 0))
	_mi(parent, _cyl(0.58, 0.64, 0.06, 28), gold, Vector3(0, 0.04, 0))
	_mi(parent, _cyl(0.45, 0.48, 0.04, 24), gold, Vector3(0, 0.53, 0))

	# Contoured hourglass corset bodice + bust silhouette + gold waist filigree
	_mi(parent, _cyl(0.15, 0.12, 0.24, 20), silk, Vector3(0, 1.12, 0))
	_mi(parent, _cyl(0.17, 0.15, 0.20, 20), gown, Vector3(0, 1.32, 0))
	_mi(parent, _sph(0.088, 0.16, 14), gown, Vector3(-0.072, 1.30, -0.075))
	_mi(parent, _sph(0.088, 0.16, 14), gown, Vector3(0.072, 1.30, -0.075))
	_mi(parent, _cyl(0.13, 0.14, 0.06, 20), gold, Vector3(0, 1.03, 0))

	# Translucent gossamer shoulder veil flowing down the back
	_mi(parent, _cyl(0.14, 0.44, 0.95, 16), veil, Vector3(0, 1.06, 0.16), Vector3(14, 0, 0))

	# Slender articulated arms + crystal wand
	for sx in [-1.0, 1.0]:
		var s: float = float(sx)
		_mi(parent, _sph(0.075, 0.14, 12), gown, Vector3(s * 0.20, 1.38, 0))
		_mi(parent, _cyl(0.046, 0.036, 0.30, 12), gown, Vector3(s * 0.24, 1.24, -0.02), Vector3(12, 0, -s * 14))
		_mi(parent, _cyl(0.035, 0.028, 0.26, 12), skin, Vector3(s * 0.29, 1.02, -0.10), Vector3(28, 0, -s * 8))
		_mi(parent, _sph(0.038, 0.076, 10), skin, Vector3(s * 0.31, 0.92, -0.16))
	_mi(parent, _cyl(0.015, 0.022, 1.42, 10), gold, Vector3(0.35, 1.18, -0.22), Vector3(10, 0, -5))
	_mi(parent, _sph(0.085, 0.17, 14), crystal, Vector3(0.41, 1.90, -0.34))

	# Neck, sculpted head, expressive face, braided silver hair, star filigree crown
	_mi(parent, _cyl(0.046, 0.056, 0.12, 14), skin, Vector3(0, 1.46, 0))
	_mi(parent, _sph(0.132, 0.29, 20), skin, Vector3(0, 1.62, 0))
	_mi(parent, _sph(0.142, 0.27, 20), hair, Vector3(0, 1.66, 0.025))
	_mi(parent, _cyl(0.07, 0.095, 0.46, 14), hair, Vector3(0, 1.38, 0.12), Vector3(16, 0, 0))
	for ex in [-0.046, 0.046]:
		_mi(parent, _sph(0.018, 0.036, 10), eye, Vector3(float(ex), 1.64, -0.118))
	_mi(parent, _sph(0.018, 0.012, 10), lip, Vector3(0, 1.56, -0.122), Vector3.ZERO, Vector3(1.8, 0.7, 0.8))

	_mi(parent, _cyl(0.145, 0.145, 0.045, 20), gold, Vector3(0, 1.76, 0))
	for i in range(5):
		var a := float(i) / 5.0 * TAU
		var sh := 0.20 if i == 0 else 0.12
		_mi(parent, _cyl(0.008, 0.03, sh, 8), gold, Vector3(sin(a) * 0.13, 1.78 + sh * 0.5, -cos(a) * 0.13))
	_mi(parent, _sph(0.045, 0.09, 12), crystal, Vector3(0, 2.02, -0.13))
	# High scalloped Victorian lace ruff collar + celestial Northern Star halo ring (npc_06_locasta.jpg)
	_mi(parent, _cyl(0.24, 0.14, 0.14, 18), gown, Vector3(0, 1.50, 0.06), Vector3(-22, 0, 0))
	var halo_m := _mat(Color(0.88, 0.96, 1.0), 0.10, 0.2, Color(0.75, 0.92, 1.0), 2.4)
	_mi(parent, _torus(0.32, 0.34, 16), halo_m, Vector3(0, 1.72, 0.12), Vector3(90, 0, 0))
	for hi in range(6):
		var ha := float(hi) * TAU / 6.0
		_mi(parent, _sph(0.028, 0.056, 8), halo_m, Vector3(cos(ha) * 0.33, 1.72 + sin(ha) * 0.33, 0.12))

## High-fashion dark-storybook Wicked Witch of the West (Baum book canon: eye-patch, umbrella/staff, obsidian & crimson velvet).
static func build_west_witch_visual(parent: Node3D) -> void:
	var obsidian := _mat(Color(0.07, 0.05, 0.09), 0.48, 0.18)
	var crimson := _mat(Color(0.58, 0.08, 0.16), 0.42, 0.12, Color(0.45, 0.04, 0.10), 0.35)
	var brass := _mat(Color(0.84, 0.65, 0.26), 0.28, 0.85)
	var pale_skin := _mat(Color(0.82, 0.78, 0.74), 0.55) # Baum PD: gaunt pale, NOT MGM green-skin trade dress
	var hair := _mat(Color(0.06, 0.05, 0.08), 0.65)
	var eye_ember := _mat(Color(1.0, 0.32, 0.14), 0.15, 0.0, Color(1.0, 0.28, 0.10), 2.2)

	# Layered tattered obsidian & crimson corset gown
	_mi(parent, _cyl(0.16, 0.62, 1.18, 22), obsidian, Vector3(0, 0.59, 0))
	_mi(parent, _cyl(0.22, 0.52, 0.96, 18), crimson, Vector3(0, 0.54, -0.05))
	# Sculpted corset bodice + high spiked gothic collar + tattered storm cape
	_mi(parent, _cyl(0.17, 0.13, 0.46, 20), obsidian, Vector3(0, 1.32, 0))
	_mi(parent, _cyl(0.18, 0.14, 0.08, 18), crimson, Vector3(0, 1.14, 0))
	_mi(parent, _cyl(0.28, 0.16, 0.24, 16), crimson, Vector3(0, 1.56, 0.06), Vector3(-16, 0, 0)) # high gothic collar
	_mi(parent, _cyl(0.20, 0.58, 1.25, 16), obsidian, Vector3(0, 0.96, 0.22), Vector3(16, 0, 0)) # storm cloak

	# Articulated arms + Baum's iron umbrella-staff
	for sx in [-1.0, 1.0]:
		var s: float = float(sx)
		_mi(parent, _sph(0.095, 0.16, 12), obsidian, Vector3(s * 0.24, 1.48, 0)) # dramatic puffed gothic shoulders
		_mi(parent, _cyl(0.05, 0.036, 0.54, 12), obsidian, Vector3(s * 0.28, 1.22, -0.08), Vector3(24, 0, -s * 16))
		_mi(parent, _sph(0.042, 0.084, 10), pale_skin, Vector3(s * 0.34, 0.98, -0.20))
	# Dark iron-ribbed umbrella-staff topped with a sculpted raven head (enemy_04_wicked_witch.jpg)
	_mi(parent, _cyl(0.022, 0.028, 1.82, 10), obsidian, Vector3(0.38, 1.15, -0.26), Vector3(14, 0, -6))
	_mi(parent, _cyl(0.018, 0.16, 0.42, 10), obsidian, Vector3(0.41, 1.52, -0.34), Vector3(14, 0, -6)) # folded dark umbrella canopy
	_mi(parent, _sph(0.055, 0.10, 10), obsidian, Vector3(0.44, 2.02, -0.46)) # raven pommel head
	_mi(parent, _cyl(0.006, 0.022, 0.11, 6), brass, Vector3(0.44, 2.01, -0.54), Vector3(-90, 0, 0)) # raven beak

	# Gaunt chalk-pale head + silver-grey braid + ONE fierce amber eye + forged-iron eyepatch (Baum book canon!)
	var silver_hair := _mat(Color(0.56, 0.58, 0.62), 0.65)
	_mi(parent, _sph(0.14, 0.31, 18), pale_skin, Vector3(0, 1.72, 0))
	_mi(parent, _sph(0.15, 0.29, 18), silver_hair, Vector3(0, 1.76, 0.03))
	_mi(parent, _cyl(0.036, 0.022, 0.46, 10), silver_hair, Vector3(0.0, 1.45, 0.15), Vector3(12, 0, 0)) # silver braid
	_mi(parent, _sph(0.026, 0.052, 10), eye_ember, Vector3(-0.048, 1.74, -0.125)) # fierce single eye
	_mi(parent, _box(Vector3(0.075, 0.055, 0.03)), obsidian, Vector3(0.048, 1.74, -0.13)) # forged-iron eyepatch
	_mi(parent, _box(Vector3(0.28, 0.02, 0.02)), obsidian, Vector3(0.0, 1.76, -0.12), Vector3(0, 0, -14)) # patch strap

	# Sweeping crown-banded gothic witch hat (wide curved brim + dark iron crown + bent spire)
	_mi(parent, _cyl(0.46, 0.48, 0.04, 22), obsidian, Vector3(0, 1.86, 0), Vector3(-8, 0, 6))
	_mi(parent, _cyl(0.17, 0.18, 0.07, 18), brass, Vector3(0, 1.91, 0), Vector3(-8, 0, 6))
	_mi(parent, _cyl(0.025, 0.17, 0.52, 18), obsidian, Vector3(0.04, 2.15, 0.04), Vector3(-16, 0, 16))

# ============================================================================
# LUSH CORNFIELD, POPPY FLOWER BEDS & HARNESSED MICE CART
# ============================================================================

static func build_lush_cornfield(parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Cornfield"
	root.position = at
	parent.add_child(root)

	# Tilled soil bed
	_mi(root, _box(Vector3(12.5, 0.06, 11.5)), _mat(Color(0.36, 0.26, 0.16), 0.96), Vector3(0, 0.03, 0))

	var stalk_m := make_wind_grass_material(Color(0.38, 0.56, 0.20))
	var leaf_m := make_wind_grass_material(Color(0.46, 0.64, 0.24))
	var cob_m := _mat(Color(0.92, 0.78, 0.24), 0.72)
	var wood_m := _mat(Color(0.36, 0.24, 0.14), 0.88)

	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var leaf_mesh := PrismMesh.new()
	leaf_mesh.size = Vector3(0.14, 0.55, 0.025)

	for row in range(-4, 5):
		for col in range(-4, 5):
			# Clear center circle around Scarecrow's pole + west entrance path from YBR
			if absf(float(row)) <= 1.2 and absf(float(col)) <= 1.2:
				continue
			if col <= -2 and absf(float(row)) <= 1.1:
				continue
			var h := 1.45 + rng.randf() * 0.55
			var ox := float(col) * 1.25 + rng.randf_range(-0.15, 0.15)
			var oz := float(row) * 1.15 + rng.randf_range(-0.15, 0.15)
			var stalk := Node3D.new()
			stalk.position = Vector3(ox, 0.0, oz)
			stalk.rotation.y = rng.randf() * TAU
			root.add_child(stalk)
			_mi(stalk, _cyl(0.035, 0.065, h, 7), stalk_m, Vector3(0, h * 0.5, 0))
			# Arching corn leaves
			for li in range(3):
				var la := float(li) * (TAU / 3.0)
				_mi(stalk, leaf_mesh, leaf_m, Vector3(cos(la) * 0.18, h * (0.45 + float(li) * 0.16), sin(la) * 0.18), Vector3(48, rad_to_deg(la), 0))
			# Golden corn cob + tassel
			_mi(stalk, _sph(0.075, 0.22, 8), cob_m, Vector3(0.09, h * 0.62, 0), Vector3(0, 0, -25))
			_mi(stalk, _cyl(0.015, 0.04, 0.22, 6), cob_m, Vector3(0, h + 0.08, 0))

	# Rustic wooden entrance arch facing the Yellow Brick Road (-X)
	_mi(root, _cyl(0.08, 0.10, 2.5, 8), wood_m, Vector3(-5.8, 1.25, -1.4))
	_mi(root, _cyl(0.08, 0.10, 2.5, 8), wood_m, Vector3(-5.8, 1.25, 1.4))
	_mi(root, _box(Vector3(0.18, 0.22, 3.3)), wood_m, Vector3(-5.8, 2.48, 0))
	return root

## Hardware-instanced MultiMesh carpet of 2,400+ lush swaying scarlet poppies + foliage
## flanking both sides of the Yellow Brick Road in L3 Deadly Poppy Field.
static func build_poppy_beds(parent: Node3D, z_start: float, z_end: float) -> Node3D:
	var root := Node3D.new()
	root.name = "PoppyFlowerBeds"
	parent.add_child(root)

	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	var stem_m := make_wind_grass_material(Color(0.18, 0.42, 0.19))
	var petal_a := make_wind_grass_material(Color(0.92, 0.10, 0.18))
	var petal_b := make_wind_grass_material(Color(0.76, 0.06, 0.16))
	var core_m := make_wind_grass_material(Color(0.08, 0.05, 0.07))

	var total_flowers := 2400
	var stem_mm := MultiMesh.new()
	stem_mm.transform_format = MultiMesh.TRANSFORM_3D
	stem_mm.mesh = _cyl(0.018, 0.030, 0.68, 5)
	stem_mm.instance_count = total_flowers

	var cap_a_mm := MultiMesh.new()
	cap_a_mm.transform_format = MultiMesh.TRANSFORM_3D
	cap_a_mm.mesh = _sph(0.24, 0.16, 7)
	cap_a_mm.instance_count = total_flowers / 2

	var cap_b_mm := MultiMesh.new()
	cap_b_mm.transform_format = MultiMesh.TRANSFORM_3D
	cap_b_mm.mesh = _sph(0.21, 0.14, 7)
	cap_b_mm.instance_count = total_flowers / 2

	var core_mm := MultiMesh.new()
	core_mm.transform_format = MultiMesh.TRANSFORM_3D
	core_mm.mesh = _sph(0.075, 0.08, 5)
	core_mm.instance_count = total_flowers

	var idx_a := 0
	var idx_b := 0
	for i in range(total_flowers):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var fx: float = side * rng.randf_range(3.25, 36.0)
		var fz: float = rng.randf_range(z_start - 2.0, z_end + 2.0)
		var sc: float = rng.randf_range(0.65, 1.38)
		var tilt_x := deg_to_rad(rng.randf_range(-10.0, 10.0))
		var tilt_z := deg_to_rad(rng.randf_range(-10.0, 10.0))
		var yaw := rng.randf() * TAU

		var stem_b := Basis.from_euler(Vector3(tilt_x, yaw, tilt_z)).scaled(Vector3(sc, sc, sc))
		stem_mm.set_instance_transform(i, Transform3D(stem_b, Vector3(fx, 0.32 * sc, fz)))

		var head_pos := Vector3(fx, 0.66 * sc, fz)
		var head_b := Basis.from_euler(Vector3(tilt_x * 1.4, yaw, tilt_z * 1.4)).scaled(Vector3(sc * 1.15, sc * 0.72, sc * 1.15))
		if i % 2 == 0 and idx_a < cap_a_mm.instance_count:
			cap_a_mm.set_instance_transform(idx_a, Transform3D(head_b, head_pos))
			idx_a += 1
		elif idx_b < cap_b_mm.instance_count:
			cap_b_mm.set_instance_transform(idx_b, Transform3D(head_b, head_pos))
			idx_b += 1

		var core_b := Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(sc, sc, sc))
		core_mm.set_instance_transform(i, Transform3D(core_b, head_pos + Vector3(0, 0.05 * sc, 0)))

	for pair in [[stem_mm, stem_m, "PoppyStems"], [cap_a_mm, petal_a, "PoppyPetalsBright"], [cap_b_mm, petal_b, "PoppyPetalsDeep"], [core_mm, core_m, "PoppyCores"]]:
		var mmi := MultiMeshInstance3D.new()
		mmi.name = str(pair[2])
		mmi.multimesh = pair[0] as MultiMesh
		mmi.material_override = pair[1] as Material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)

	return root

# ============================================================================
# LION SANCTUARY, PRISTINE WATER CISTERN & KANSAS 3D STORYBOOK PROPS
# ============================================================================

## Sculpted organic woodland Cave & Bramble Grotto for the Cowardly Lion (NO boxy bunker slabs!).
static func build_lion_sanctuary(parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "LionDen"
	root.position = at
	parent.add_child(root)

	var rock_dark := _mat(Color(0.24, 0.23, 0.27), 0.96)
	var rock_mid := _mat(Color(0.34, 0.33, 0.37), 0.92)
	var moss := _mat(Color(0.18, 0.42, 0.20), 0.90)
	var bark := _mat(Color(0.22, 0.14, 0.09), 0.94)
	var iron := _mat(Color(0.16, 0.16, 0.20), 0.42, 0.85)
	var vine_m := make_wind_grass_material(Color(0.16, 0.44, 0.20))
	var lantern_m := _mat(Color(1.0, 0.78, 0.30), 0.2, 0.0, Color(1.0, 0.72, 0.22), 2.0)

	# Flush mossy woodland cave floor
	_mi(root, _cyl(3.2, 3.6, 0.06, 20), moss, Vector3(0, 0.03, 0.2))

	# Naturalistic overlapping low-poly stone cave vault (18 organic sculpted rock formations curving into a real grotto!)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for i in range(13):
		var a := PI * 0.12 + float(i) / 12.0 * (PI * 0.76) # horseshoe open to +Z
		var rad := 2.65 + rng.randf_range(-0.25, 0.25)
		var rx := cos(a) * rad
		var rz := -sin(a) * rad + 0.35
		var bh := rng.randf_range(1.6, 2.8)
		var br := rng.randf_range(0.85, 1.35)
		var rm: StandardMaterial3D = rock_dark if (i % 2 == 0) else rock_mid
		_mi(root, _sph(br, bh, 7), rm, Vector3(rx, bh * 0.42, rz), Vector3(rng.randf_range(-12, 12), rad_to_deg(a), rng.randf_range(-12, 12)), Vector3(1.1, 1.0, 0.9))
		_mi(root, _sph(br * 0.78, bh * 0.45, 7), moss, Vector3(rx, bh * 0.82, rz), Vector3(0, rad_to_deg(a), 0))
	# Natural rocky cave-arch dome overhead
	for vi in range(5):
		var vx := -1.6 + float(vi) * 0.8
		var vy := 2.65 + (1.0 - absf(vx) / 2.2) * 0.85
		_mi(root, _sph(1.15, 1.45, 7), rock_mid, Vector3(vx, vy, -1.05), Vector3(14, float(vi) * 28.0, 0), Vector3(1.1, 0.72, 1.35))
		_mi(root, _sph(0.95, 0.75, 7), moss, Vector3(vx, vy + 0.45, -1.05), Vector3(10, float(vi) * 28.0, 0))

	# Weeping gnarled roots & hanging moss vines framing the cave mouth
	for sx in [-1.0, 1.0]:
		var s: float = float(sx)
		_mi(root, _cyl(0.14, 0.28, 3.2, 8), bark, Vector3(s * 2.2, 1.45, 0.35), Vector3(14, 0, -s * 18))
		_mi(root, _cyl(0.08, 0.16, 2.2, 8), bark, Vector3(s * 1.1, 2.95, 0.15), Vector3(8, 0, -s * 58))
		# Wrought-iron hunter's snare stake & floor chain links
		_mi(root, _cyl(0.05, 0.065, 1.15, 8), iron, Vector3(s * 1.75, 0.56, 1.65), Vector3(0, 0, -s * 14))
		for ci in range(4):
			_mi(root, _torus(0.045, 0.085, 8), iron, Vector3(s * (1.65 - float(ci) * 0.24), 0.18, 1.55 - float(ci) * 0.25), Vector3(45 * ci, 20, 0))
		# Glowing woodland firefly-lantern hanging from vine
		_mi(root, _sph(0.12, 0.18, 8), lantern_m, Vector3(s * 1.48, 2.25, 0.55))

	# Draping cave-mouth ivy tendrils & ferns
	var frond := PrismMesh.new()
	frond.size = Vector3(0.26, 0.95, 0.04)
	for fi in range(10):
		var fx := -1.5 + float(fi) * 0.33
		_mi(root, frond, vine_m, Vector3(fx, 2.55 - absf(fx) * 0.18, 0.38), Vector3(180, float(fi) * 18.0, 0))

	var den_light := OmniLight3D.new()
	den_light.light_color = Color(1.0, 0.72, 0.32)
	den_light.light_energy = 2.4
	den_light.omni_range = 10.0
	den_light.position = Vector3(0, 1.9, 0.2)
	root.add_child(den_light)
	return root

## Sculpted 3D Kansas Chicken (plump feathered body, tail fan, comb, beak, wings & legs — matches Toto's detail!).
static func build_chicken_visual(parent: Node3D, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var ch := Node3D.new()
	ch.set_script(preload("res://systems/chicken_actor.gd"))
	ch.name = "Chicken"
	ch.position = pos
	ch.rotation_degrees.y = yaw_deg
	parent.add_child(ch)
	var feather := _mat(Color(0.86, 0.86, 0.88), 0.85)
	var wing_m := _mat(Color(0.70, 0.70, 0.74), 0.88)
	var comb_m := _mat(Color(0.45, 0.45, 0.48), 0.75)
	var beak_m := _mat(Color(0.58, 0.58, 0.60), 0.70)
	var eye_m := _mat(Color(0.08, 0.08, 0.10), 0.2)
	# Legs
	for sx in [-0.055, 0.055]:
		_mi(ch, _cyl(0.012, 0.014, 0.18, 6), beak_m, Vector3(float(sx), 0.09, 0))
	# Plump body + tucked wings + upturned tail feathers
	_mi(ch, _sph(0.16, 0.26, 12), feather, Vector3(0, 0.24, 0), Vector3(0, 0, 0), Vector3(0.88, 0.85, 1.25))
	for sx in [-1.0, 1.0]:
		_mi(ch, _sph(0.11, 0.18, 10), wing_m, Vector3(float(sx) * 0.13, 0.24, 0.02), Vector3(0, 0, -float(sx) * 14), Vector3(0.45, 0.75, 1.1))
	_mi(ch, _cyl(0.04, 0.12, 0.22, 8), wing_m, Vector3(0, 0.34, -0.18), Vector3(-42, 0, 0))
	# Neck + Head + Comb + Beak + Eyes
	_mi(ch, _cyl(0.055, 0.075, 0.15, 8), feather, Vector3(0, 0.36, 0.14), Vector3(18, 0, 0))
	_mi(ch, _sph(0.075, 0.15, 10), feather, Vector3(0, 0.44, 0.18))
	_mi(ch, _box(Vector3(0.025, 0.055, 0.09)), comb_m, Vector3(0, 0.52, 0.18))
	_mi(ch, _cyl(0.005, 0.028, 0.08, 6), beak_m, Vector3(0, 0.43, 0.27), Vector3(90, 0, 0))
	for sx in [-0.045, 0.045]:
		_mi(ch, _sph(0.014, 0.028, 6), eye_m, Vector3(float(sx), 0.46, 0.23))
	return ch

## Distinct Kansas Timber-Slat Chicken Coop with sloped roof, ramp, nesting box, wire-mesh run & 5 sculpted 3D chickens!
static func build_chicken_coop(parent: Node3D) -> void:
	var timber := _mat(Color(0.38, 0.38, 0.41), 0.90)
	var trim := _mat(Color(0.26, 0.26, 0.29), 0.88)
	var roof_m := _mat(Color(0.22, 0.22, 0.25), 0.78, 0.25)
	var wire_m := _mat(Color(0.55, 0.55, 0.58, 0.36), 0.45, 0.65)
	wire_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Raised coop house on stilt legs + sloped shed roof + recessed coop door + chicken ramp
	for lx in [-1.45, 1.45]:
		for lz in [-1.05, 1.05]:
			_mi(parent, _box(Vector3(0.16, 0.55, 0.16)), trim, Vector3(float(lx), 0.28, float(lz)))
	_mi(parent, _box(Vector3(3.2, 1.55, 2.3)), timber, Vector3(0, 1.32, 0))
	_mi(parent, _box(Vector3(3.6, 0.14, 2.75)), roof_m, Vector3(0, 2.22, 0), Vector3(11, 0, 0))
	# Recessed built-in coop door + wooden chicken ramp
	_mi(parent, _box(Vector3(0.95, 1.35, 0.10)), trim, Vector3(0, 1.15, 1.15))
	_mi(parent, _box(Vector3(0.65, 0.08, 1.15)), timber, Vector3(0, 0.32, 1.55), Vector3(28, 0, 0))
	# Side nesting box bay
	_mi(parent, _box(Vector3(0.65, 0.62, 1.45)), trim, Vector3(1.85, 1.05, 0))
	# See-through wooden-post & wire-mesh fenced chicken run + SWINGING ENTRANCE GATE on south face!
	for px in [-2.6, 0.0, 2.6, 5.2]:
		_mi(parent, _cyl(0.055, 0.065, 1.25, 8), trim, Vector3(float(px), 0.62, 4.4))
		_mi(parent, _cyl(0.055, 0.065, 1.25, 8), trim, Vector3(float(px), 0.62, -2.4))
	# South fence left & right wings with 2.2m gap in center for swinging wooden gate!
	_mi(parent, _box(Vector3(2.8, 1.1, 0.04)), wire_m, Vector3(-1.2, 0.58, 4.4))
	_mi(parent, _box(Vector3(2.8, 1.1, 0.04)), wire_m, Vector3(3.8, 0.58, 4.4))
	_mi(parent, _box(Vector3(7.8, 1.1, 0.04)), wire_m, Vector3(1.3, 0.58, -2.4))
	_mi(parent, _box(Vector3(0.04, 1.1, 6.8)), wire_m, Vector3(5.2, 0.58, 1.0))
	_mi(parent, _box(Vector3(0.04, 1.1, 6.8)), wire_m, Vector3(-2.6, 0.58, 1.0))
	# Hinged swinging chicken-run gate (auto-opens 95 deg when Dorothy walks up!)
	var gate_piv := Node3D.new()
	gate_piv.name = "CoopGatePivot"
	gate_piv.position = Vector3(0.2, 0.0, 4.4)
	parent.add_child(gate_piv)
	_mi(gate_piv, _box(Vector3(2.1, 0.08, 0.06)), trim, Vector3(1.05, 1.05, 0))
	_mi(gate_piv, _box(Vector3(2.1, 0.08, 0.06)), trim, Vector3(1.05, 0.25, 0))
	_mi(gate_piv, _box(Vector3(2.0, 0.85, 0.03)), wire_m, Vector3(1.05, 0.65, 0))
	var gate_trig := Area3D.new()
	gate_trig.collision_layer = 0
	gate_trig.collision_mask = 2
	gate_trig.position = Vector3(1.3, 0.6, 4.4)
	parent.add_child(gate_trig)
	var gcs := CollisionShape3D.new()
	var gsh := SphereShape3D.new()
	gsh.radius = 2.4
	gcs.shape = gsh
	gate_trig.add_child(gcs)
	gate_trig.body_entered.connect(func(b):
		if b.is_in_group("player"):
			var tw := parent.create_tween()
			tw.tween_property(gate_piv, "rotation_degrees:y", 95.0, 0.42).set_trans(Tween.TRANS_CUBIC)
	)
	gate_trig.body_exited.connect(func(b):
		if b.is_in_group("player"):
			var tw := parent.create_tween()
			tw.tween_property(gate_piv, "rotation_degrees:y", 0.0, 0.55).set_trans(Tween.TRANS_CUBIC)
	)
	make_building_crest_sign(parent, Vector3(0, 2.55, 1.35), "CHICKEN COOP", Color(0.46, 0.46, 0.49), true)
	# 5 Sculpted 3D prairie chickens scratching & roosting inside the fenced run!
	build_chicken_visual(parent, Vector3(2.4, 0.0, 2.2), 35.0)
	build_chicken_visual(parent, Vector3(3.6, 0.0, 0.4), -70.0)
	build_chicken_visual(parent, Vector3(1.4, 0.0, 3.1), 140.0)
	build_chicken_visual(parent, Vector3(-1.3, 0.0, 2.8), 60.0)
	build_chicken_visual(parent, Vector3(3.2, 0.0, -1.2), -15.0)

static func _torus(inner_r: float, outer_r: float, rings: int = 10) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner_r
	t.outer_radius = outer_r
	t.rings = rings
	t.ring_segments = 8
	return t

## Pristine octagonal carved stone & copper courtyard Water Cistern for L4 Winkie Castle.
static func build_water_cistern(parent: Node3D) -> void:
	var stone := _mat(Color(0.32, 0.34, 0.38), 0.86)
	var stone_hi := _mat(Color(0.46, 0.48, 0.54), 0.78)
	var copper := _mat(Color(0.42, 0.62, 0.56), 0.36, 0.72)
	var iron := _mat(Color(0.14, 0.14, 0.18), 0.44, 0.82)
	var wood := _mat(Color(0.38, 0.24, 0.14), 0.85)
	var water := make_flowing_water_material(Color(0.20, 0.68, 0.98), Color(0.80, 0.96, 1.0), 1.35)

	# Stepped octagonal stone well basin + SOLID COLLIDER so characters NEVER walk through the cistern!
	var c_body := StaticBody3D.new()
	c_body.name = "CisternSolidCollider"
	c_body.collision_layer = 1
	c_body.collision_mask = 0
	parent.add_child(c_body)
	var c_col := CollisionShape3D.new()
	var c_sh := CylinderShape3D.new()
	c_sh.radius = 2.05
	c_sh.height = 1.25
	c_col.shape = c_sh
	c_col.position = Vector3(0, 0.62, 0)
	c_body.add_child(c_col)
	_mi(parent, _cyl(1.95, 2.15, 0.24, 8), stone, Vector3(0, 0.12, 0))
	_mi(parent, _cyl(1.75, 1.82, 0.92, 8), stone_hi, Vector3(0, 0.58, 0))
	_mi(parent, _cyl(1.86, 1.86, 0.12, 8), copper, Vector3(0, 1.08, 0))
	# Shimmering crystalline water surface + subtle spilled puddles on courtyard stones
	_mi(parent, _cyl(1.52, 1.52, 0.08, 16), water, Vector3(0, 0.98, 0))
	_mi(parent, _cyl(0.65, 0.65, 0.02, 12), water, Vector3(1.85, 0.03, 0.95))
	_mi(parent, _cyl(0.42, 0.42, 0.02, 10), water, Vector3(-1.45, 0.03, 1.55))
	# Arched forged-iron dome canopy, spoked winch wheel & twin hanging water buckets (we_04_winkie_courtyard.jpg)
	for ai in range(4):
		var aa := float(ai) * PI * 0.5
		_mi(parent, _cyl(0.06, 0.075, 2.25, 8), iron, Vector3(cos(aa) * 1.62, 2.15, sin(aa) * 1.62))
	_mi(parent, _torus(1.58, 1.66, 16), iron, Vector3(0, 3.25, 0))
	_mi(parent, _cyl(0.06, 0.20, 0.65, 8), iron, Vector3(0, 3.65, 0)) # spiked dome finial
	_mi(parent, _cyl(0.14, 0.14, 2.6, 10), wood, Vector3(0, 2.45, 0), Vector3(0, 0, 90)) # winch drum
	_mi(parent, _torus(0.42, 0.48, 12), iron, Vector3(1.45, 2.45, 0), Vector3(0, 0, 90)) # spoked winch wheel
	for bx in [-0.55, 0.55]:
		_mi(parent, _cyl(0.014, 0.014, 0.92, 6), iron, Vector3(float(bx), 1.98, 0))
		_mi(parent, _cyl(0.24, 0.18, 0.34, 10), wood, Vector3(float(bx), 1.48, 0)) # hanging bucket

	# Wrought-iron wellhead arch + windlass bar + hanging chain & wooden water bucket
	for sx in [-1.52, 1.52]:
		_mi(parent, _cyl(0.065, 0.085, 2.45, 8), iron, Vector3(float(sx), 2.15, 0))
	_mi(parent, _box(Vector3(3.25, 0.14, 0.16)), iron, Vector3(0, 3.35, 0))
	_mi(parent, _cyl(0.08, 0.08, 3.1, 10), wood, Vector3(0, 2.55, 0), Vector3(0, 0, 90))
	_mi(parent, _cyl(0.02, 0.02, 1.25, 6), iron, Vector3(0, 1.92, 0))
	_mi(parent, _cyl(0.28, 0.22, 0.42, 12), wood, Vector3(0, 1.32, 0))
	_mi(parent, _cyl(0.29, 0.29, 0.05, 12), iron, Vector3(0, 1.44, 0))
	_mi(parent, _cyl(0.24, 0.24, 0.05, 12), iron, Vector3(0, 1.18, 0))

	# Gentle aqua lantern glow above the arch
	var well_light := OmniLight3D.new()
	well_light.light_color = Color(0.45, 0.85, 1.0)
	well_light.light_energy = 2.6
	well_light.omni_range = 11.0
	well_light.position = Vector3(0, 2.6, 0)
	parent.add_child(well_light)

	make_world_badge(parent, Vector3(0, 3.85, 0), "✦  Ruptured Cistern  ·  Draw Water (E)", Color(0.55, 0.90, 1.0), 14.0)

## Kansas 3D Clothesline: cedar T-posts, sagging hemp rope, clothespins, and pinned billowing laundry.
static func build_clothesline(parent: Node3D, at: Vector3) -> Array:
	var root := Node3D.new()
	root.name = "PrairieClothesline"
	root.position = at
	parent.add_child(root)

	var wood := _mat(Color(0.30, 0.30, 0.32), 0.92)
	var rope := _mat(Color(0.46, 0.46, 0.48), 0.88)
	var pin_m := _mat(Color(0.22, 0.22, 0.24), 0.85)
	var span := 5.6

	# Two weathered wooden T-posts with crossbars & ground braces
	for px in [0.0, span]:
		var x: float = float(px)
		_mi(root, _cyl(0.06, 0.08, 2.35, 8), wood, Vector3(x, 1.17, 0))
		_mi(root, _box(Vector3(0.10, 0.10, 1.15)), wood, Vector3(x, 2.25, 0))
		_mi(root, _box(Vector3(0.08, 0.65, 0.08)), wood, Vector3(x, 1.98, 0.26), Vector3(-42, 0, 0))
		_mi(root, _box(Vector3(0.08, 0.65, 0.08)), wood, Vector3(x, 1.98, -0.26), Vector3(42, 0, 0))

	# Segmented sagging hemp rope between the two T-posts
	var segs := 8
	for si in range(segs):
		var t0 := float(si) / float(segs)
		var t1 := float(si + 1) / float(segs)
		var tm := (t0 + t1) * 0.5
		var sag := sin(tm * PI) * 0.22
		var seg_w := span / float(segs) + 0.04
		_mi(root, _cyl(0.014, 0.014, seg_w, 6), rope, Vector3(tm * span, 2.22 - sag, 0), Vector3(0, 0, 90))

	# Sculpted laundry garments hung from pivot nodes pinned directly to the rope
	var sway_nodes: Array = []
	var garment_specs := [
		{"t": 0.16, "w": 0.62, "h": 0.85, "c": Color(0.76, 0.76, 0.78), "shirt": false},
		{"t": 0.34, "w": 0.52, "h": 0.72, "c": Color(0.60, 0.60, 0.64), "shirt": true},
		{"t": 0.52, "w": 0.78, "h": 0.96, "c": Color(0.82, 0.82, 0.84), "shirt": false},
		{"t": 0.70, "w": 0.48, "h": 0.68, "c": Color(0.54, 0.54, 0.58), "shirt": true},
		{"t": 0.86, "w": 0.60, "h": 0.80, "c": Color(0.72, 0.72, 0.75), "shirt": false},
	]
	for g in garment_specs:
		var gt: float = float(g["t"])
		var gw: float = float(g["w"])
		var gh: float = float(g["h"])
		var sag_y: float = 2.22 - sin(gt * PI) * 0.22
		var pivot := Node3D.new()
		pivot.position = Vector3(gt * span, sag_y, 0)
		pivot.set_meta("wind_cloth", true)
		root.add_child(pivot)
		var gmat := _mat(g["c"] as Color, 0.88)
		# Clothespins on top edge
		_mi(pivot, _box(Vector3(0.035, 0.10, 0.045)), pin_m, Vector3(-gw * 0.35, 0.02, 0))
		_mi(pivot, _box(Vector3(0.035, 0.10, 0.045)), pin_m, Vector3(gw * 0.35, 0.02, 0))
		# Main cloth hanging DOWN from the rope pivot
		_mi(pivot, _box(Vector3(gw, gh, 0.035)), gmat, Vector3(0, -gh * 0.5, 0))
		if bool(g["shirt"]):
			_mi(pivot, _box(Vector3(0.24, 0.18, 0.035)), gmat, Vector3(-gw * 0.5 - 0.10, -0.14, 0), Vector3(0, 0, 22))
			_mi(pivot, _box(Vector3(0.24, 0.18, 0.035)), gmat, Vector3(gw * 0.5 + 0.10, -0.14, 0), Vector3(0, 0, -22))
		sway_nodes.append(pivot)
	return sway_nodes

## Kansas 3D Lattice Prairie Windmill with 4-leg timber tower, cross-braces, tail vane & 8-blade wheel.
static func build_lattice_windmill(parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "PrairieWindmill"
	root.position = at
	parent.add_child(root)

	var timber := _mat(Color(0.28, 0.28, 0.31), 0.90)
	var iron := _mat(Color(0.20, 0.20, 0.23), 0.52, 0.65)
	var vane_m := _mat(Color(0.46, 0.46, 0.50), 0.82)

	# 4 slanted corner legs + horizontal collar rings
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var s_x: float = float(sx)
			var s_z: float = float(sz)
			_mi(root, _cyl(0.07, 0.11, 8.6, 6), timber, Vector3(s_x * 0.88, 4.2, s_z * 0.88), Vector3(-s_z * 7.5, 0, s_x * 7.5))
	for level_y in [2.0, 4.2, 6.4, 8.1]:
		var ly: float = float(level_y)
		var span: float = lerpf(2.35, 0.95, ly / 8.5)
		_mi(root, _box(Vector3(span, 0.12, 0.12)), timber, Vector3(0, ly, span * 0.5))
		_mi(root, _box(Vector3(span, 0.12, 0.12)), timber, Vector3(0, ly, -span * 0.5))
		_mi(root, _box(Vector3(0.12, 0.12, span)), timber, Vector3(span * 0.5, ly, 0))
		_mi(root, _box(Vector3(0.12, 0.12, span)), timber, Vector3(-span * 0.5, ly, 0))

	# Gearbox head + tail rudder vane
	_mi(root, _box(Vector3(0.75, 0.55, 0.95)), iron, Vector3(0, 8.55, 0))
	_mi(root, _box(Vector3(0.08, 0.10, 2.4)), iron, Vector3(0, 8.62, -1.4))
	_mi(root, _box(Vector3(0.06, 1.15, 1.35)), vane_m, Vector3(0, 8.68, -2.45))

	# Spinning 8-blade slatted rotor wheel
	var rotor := Node3D.new()
	rotor.name = "WindRotor"
	rotor.position = Vector3(0, 8.62, 0.72)
	rotor.set_meta("spin", true)
	root.add_child(rotor)
	_mi(rotor, _cyl(0.24, 0.24, 0.26, 12), iron, Vector3.ZERO, Vector3(90, 0, 0))
	var rim := TorusMesh.new()
	rim.inner_radius = 2.35
	rim.outer_radius = 2.48
	_mi(rotor, rim, iron, Vector3.ZERO, Vector3(90, 0, 0))
	for bi in range(8):
		var a := float(bi) / 8.0 * TAU
		var spoke := Node3D.new()
		spoke.rotation.z = a
		rotor.add_child(spoke)
		_mi(spoke, _box(Vector3(0.08, 2.4, 0.05)), iron, Vector3(0, 1.2, 0))
		_mi(spoke, _box(Vector3(0.48, 1.45, 0.04)), vane_m, Vector3(0.14, 1.65, 0.04), Vector3(0, 18, 0))
	# Cast-iron hand water pump & wooden water trough at tower base (bldg_06_windmill_clothesline.jpg)
	_mi(root, _box(Vector3(1.55, 0.48, 0.72)), timber, Vector3(-1.85, 0.24, 0.45))
	_mi(root, _box(Vector3(1.38, 0.08, 0.56)), _mat(Color(0.26, 0.30, 0.34), 0.18), Vector3(-1.85, 0.44, 0.45)) # water surface
	_mi(root, _cyl(0.08, 0.11, 1.05, 10), iron, Vector3(-1.15, 0.52, 0.45)) # pump column
	_mi(root, _cyl(0.03, 0.03, 0.62, 6), iron, Vector3(-0.92, 0.85, 0.45), Vector3(0, 0, -48)) # pump lever handle
	return rotor

## Sculpted woven wicker Toto Basket (replaces plain brown box in Kansas).
static func build_wicker_basket(parent: Node3D) -> void:
	for c in parent.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	var wicker := _mat(Color(0.56, 0.54, 0.50), 0.90)
	var wicker_dark := _mat(Color(0.32, 0.31, 0.30), 0.92)
	var cloth := _mat(Color(0.88, 0.88, 0.90), 0.84)

	var b := Node3D.new()
	b.name = "WickerBasketVisual"
	parent.add_child(b)
	# Tapered oval woven picnic basket + horizontal wicker ribs + folded cloth liner + VERTICAL arched handle!
	_mi(b, _cyl(0.34, 0.24, 0.38, 20), wicker, Vector3(0, 0.19, 0), Vector3.ZERO, Vector3(1.22, 1.0, 0.88))
	for ry in [0.09, 0.19, 0.29, 0.36]:
		_mi(b, _cyl(0.355, 0.355, 0.025, 20), wicker_dark, Vector3(0, float(ry), 0), Vector3.ZERO, Vector3(1.24, 1.0, 0.90))
	_mi(b, _cyl(0.33, 0.31, 0.06, 20), cloth, Vector3(0, 0.38, 0), Vector3.ZERO, Vector3(1.16, 1.0, 0.82))
	# Vertical arched carry handle (rotated 90 deg on X so it arches UP over the basket!)
	var handle := TorusMesh.new()
	handle.inner_radius = 0.26
	handle.outer_radius = 0.31
	handle.rings = 18
	_mi(b, handle, wicker_dark, Vector3(0, 0.38, 0), Vector3(90, 0, 0), Vector3(1.15, 0.95, 1.0))

## Diegetic Kansas Storm-Lantern Waypoint Stake (replaces bare neon cylinder stick).
static func build_prairie_lantern_marker() -> Node3D:
	var root := Node3D.new()
	root.name = "PrairieLanternMarker"
	var iron := _mat(Color(0.18, 0.18, 0.20), 0.48, 0.78)
	var glow := _mat(Color(0.95, 0.95, 0.98), 0.15, 0.0, Color(0.95, 0.95, 1.0), 2.1)
	var halo_m := _mat(Color(0.90, 0.90, 0.95, 0.42), 0.2, 0.0, Color(0.90, 0.90, 0.96), 1.1)
	halo_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_mi(root, _cyl(0.032, 0.045, 1.65, 8), iron, Vector3(0, 0.82, 0))
	_mi(root, _box(Vector3(0.38, 0.04, 0.04)), iron, Vector3(0.18, 1.62, 0))
	_mi(root, _cyl(0.03, 0.13, 0.10, 6), iron, Vector3(0.34, 1.50, 0))
	_mi(root, _cyl(0.095, 0.08, 0.22, 6), glow, Vector3(0.34, 1.34, 0))
	_mi(root, _cyl(0.11, 0.04, 0.07, 6), iron, Vector3(0.34, 1.20, 0))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.65
	ring.outer_radius = 0.78
	_mi(root, ring, halo_m, Vector3(0, 0.06, 0), Vector3(90, 0, 0))
	return root

## Articulated monochrome Kansas Aunt Em or Uncle Henry character visual.
static func build_kansas_farmer(parent: Node3D, is_aunt_em: bool) -> void:
	var skin := _mat(Color(0.76, 0.76, 0.78), 0.52)
	var dark := _mat(Color(0.16, 0.16, 0.18), 0.75)
	var dress := _mat(Color(0.42, 0.42, 0.45), 0.86)
	var apron := _mat(Color(0.80, 0.80, 0.83), 0.88)
	var hair := _mat(Color(0.56, 0.56, 0.59) if is_aunt_em else Color(0.32, 0.32, 0.34), 0.78)

	if is_aunt_em:
		# Full pleated prairie skirt + crisp white apron + shawl + sculpted bodice
		_mi(parent, _cyl(0.16, 0.42, 0.92, 20), dress, Vector3(0, 0.46, 0))
		_mi(parent, _cyl(0.17, 0.34, 0.76, 14), apron, Vector3(0, 0.48, -0.05))
		_mi(parent, _cyl(0.16, 0.13, 0.40, 18), dress, Vector3(0, 1.12, 0))
		_mi(parent, _cyl(0.24, 0.19, 0.18, 16), apron, Vector3(0, 1.26, 0.02)) # knitted prairie shawl
	else:
		# Work boots, trousers, tucked shirt, suspenders
		for sx in [-0.11, 0.11]:
			_mi(parent, _cyl(0.075, 0.085, 0.76, 12), dark, Vector3(float(sx), 0.38, 0))
			_mi(parent, _box(Vector3(0.13, 0.10, 0.22)), _mat(Color(0.12, 0.12, 0.14), 0.6), Vector3(float(sx), 0.05, -0.03))
		_mi(parent, _cyl(0.19, 0.17, 0.56, 18), _mat(Color(0.62, 0.62, 0.65), 0.85), Vector3(0, 1.06, 0))
		for sx in [-0.09, 0.09]:
			_mi(parent, _box(Vector3(0.04, 0.52, 0.22)), dark, Vector3(float(sx), 1.06, 0)) # suspenders

	# Articulated arms + hands
	for sx in [-1.0, 1.0]:
		var s: float = float(sx)
		_mi(parent, _sph(0.072, 0.13, 10), dress if is_aunt_em else _mat(Color(0.62, 0.62, 0.65), 0.85), Vector3(s * 0.22, 1.26, 0))
		_mi(parent, _cyl(0.048, 0.038, 0.44, 10), skin, Vector3(s * 0.26, 1.04, -0.04), Vector3(14, 0, -s * 12))
		_mi(parent, _sph(0.04, 0.08, 8), skin, Vector3(s * 0.30, 0.84, -0.10))

	# Neck, sculpted head, eyes, hair bun or farmer hat + mustache
	_mi(parent, _cyl(0.045, 0.055, 0.12, 12), skin, Vector3(0, 1.38, 0))
	_mi(parent, _sph(0.135, 0.29, 18), skin, Vector3(0, 1.54, 0))
	for ex in [-0.045, 0.045]:
		_mi(parent, _sph(0.018, 0.036, 8), dark, Vector3(float(ex), 1.56, -0.12))
	if is_aunt_em:
		_mi(parent, _sph(0.142, 0.26, 16), hair, Vector3(0, 1.58, 0.02))
		_mi(parent, _sph(0.075, 0.13, 12), hair, Vector3(0, 1.60, 0.15)) # neat hair bun
	else:
		_mi(parent, _box(Vector3(0.11, 0.03, 0.04)), hair, Vector3(0, 1.48, -0.13)) # mustache
		_mi(parent, _cyl(0.32, 0.34, 0.035, 18), dark, Vector3(0, 1.67, 0)) # wide prairie hat brim
		_mi(parent, _cyl(0.14, 0.16, 0.18, 16), dark, Vector3(0, 1.76, 0))

## Carved wooden flatbed Mice Cart with spoked wheels, hitch shafts, and 6 harnessed 3D Field Mice.
static func build_mice_cart_visual(parent: Node3D) -> void:
	var wood := _mat(Color(0.46, 0.30, 0.16), 0.84)
	var wood_dark := _mat(Color(0.28, 0.18, 0.10), 0.88)
	var iron := _mat(Color(0.24, 0.24, 0.28), 0.45, 0.75)
	var rope := _mat(Color(0.92, 0.78, 0.36), 0.55, 0.25, Color(0.88, 0.72, 0.26), 0.35)
	var mouse_fur := _mat(Color(0.54, 0.52, 0.56), 0.88)
	var mouse_ear := _mat(Color(0.88, 0.64, 0.68), 0.75)

	# Planked wagon bed + slatted side rails
	_mi(parent, _box(Vector3(2.4, 0.18, 3.4)), wood, Vector3(0, 0.56, 0))
	for sx in [-1.14, 1.14]:
		_mi(parent, _box(Vector3(0.10, 0.45, 3.4)), wood_dark, Vector3(float(sx), 0.84, 0))
	_mi(parent, _box(Vector3(2.4, 0.45, 0.12)), wood_dark, Vector3(0, 0.84, -1.65))

	# 4 Spoked wooden wheels with iron rims
	for wx in [-1.28, 1.28]:
		for wz in [-1.15, 1.15]:
			var wnode := Node3D.new()
			wnode.position = Vector3(float(wx), 0.48, float(wz))
			parent.add_child(wnode)
			var rim := TorusMesh.new()
			rim.inner_radius = 0.36
			rim.outer_radius = 0.48
			_mi(wnode, rim, iron, Vector3.ZERO, Vector3(0, 0, 90))
			_mi(wnode, _cyl(0.10, 0.10, 0.16, 10), wood_dark, Vector3.ZERO, Vector3(0, 0, 90))
			for sp in range(4):
				_mi(wnode, _box(Vector3(0.06, 0.82, 0.06)), wood, Vector3.ZERO, Vector3(float(sp) * 45.0, 0, 0))

	# Hitch shafts + 6 sculpted 3D Field Mice in golden thread harnesses ahead (+Z)
	for hx in [-0.65, 0.65]:
		_mi(parent, _box(Vector3(0.08, 0.08, 2.4)), wood_dark, Vector3(float(hx), 0.54, 2.7))
		_mi(parent, _box(Vector3(0.03, 0.03, 2.6)), rope, Vector3(float(hx), 0.42, 2.8))

	for row in range(3):
		for col in [-0.65, 0.65]:
			var mpos := Vector3(float(col), 0.16, 2.0 + float(row) * 0.72)
			var mnode := Node3D.new()
			mnode.position = mpos
			parent.add_child(mnode)
			_mi(mnode, _sph(0.14, 0.24, 10), mouse_fur, Vector3.ZERO, Vector3.ZERO, Vector3(0.85, 0.75, 1.35))
			_mi(mnode, _sph(0.095, 0.16, 10), mouse_fur, Vector3(0, 0.04, 0.18))
			_mi(mnode, _sph(0.055, 0.09, 8), mouse_ear, Vector3(-0.07, 0.12, 0.14))
			_mi(mnode, _sph(0.055, 0.09, 8), mouse_ear, Vector3(0.07, 0.12, 0.14))
			_mi(mnode, _cyl(0.012, 0.022, 0.34, 6), mouse_ear, Vector3(0, 0.0, -0.24), Vector3(78, 0, 0))
			_mi(mnode, _cyl(0.12, 0.12, 0.04, 10), rope, Vector3(0, 0.02, 0.04), Vector3(90, 0, 0))

# ============================================================================
# PHASE P4: VINTAGE OIL CAN, EMERALD PALACE & OZ PROJECTION, GLINDA'S COURT
# ============================================================================

## Sculpted vintage polished-brass & copper oiler can on a carved stone plinth.
static func build_oil_can_visual(parent: Node3D) -> void:
	var stone := _mat(Color(0.42, 0.40, 0.44), 0.90)
	var brass := _mat(Color(0.88, 0.70, 0.28), 0.24, 0.88)
	var copper := _mat(Color(0.76, 0.42, 0.22), 0.30, 0.82)
	var oil_drop := _mat(Color(1.0, 0.82, 0.24), 0.12, 0.1, Color(1.0, 0.78, 0.18), 1.8)

	# Carved stone garden plinth
	_mi(parent, _cyl(0.32, 0.38, 0.14, 12), stone, Vector3(0, 0.07, 0))
	_mi(parent, _cyl(0.24, 0.28, 0.24, 12), stone, Vector3(0, 0.26, 0))
	# Domed brass oil reservoir + knurled copper collar + flared base rim
	var can := Node3D.new()
	can.position = Vector3(0, 0.38, 0)
	parent.add_child(can)
	_mi(can, _cyl(0.20, 0.23, 0.06, 18), copper, Vector3(0, 0.03, 0))
	_mi(can, _cyl(0.16, 0.21, 0.24, 18), brass, Vector3(0, 0.16, 0))
	_mi(can, _sph(0.165, 0.20, 18), brass, Vector3(0, 0.28, 0))
	_mi(can, _cyl(0.065, 0.075, 0.07, 14), copper, Vector3(0, 0.39, 0)) # knurled cap collar
	# Long graceful tapered swan-neck oiler spout + glowing golden oil droplet at tip
	_mi(can, _cyl(0.014, 0.048, 0.46, 12), brass, Vector3(0.12, 0.56, 0), Vector3(0, 0, -28))
	_mi(can, _sph(0.034, 0.062, 10), oil_drop, Vector3(0.24, 0.78, 0))
	# Curved thumb-pump handle on back
	var handle := TorusMesh.new()
	handle.inner_radius = 0.085
	handle.outer_radius = 0.115
	_mi(can, handle, copper, Vector3(-0.18, 0.20, 0))
	make_world_badge(parent, Vector3(0, 1.48, 0), "✦  Tin Man's Oil Can (E)", Color(1.0, 0.88, 0.42), 12.0)

## Crystalline multi-spire Emerald Palace architecture matching Munchkinland's horizon skyline!
static func build_emerald_palace_facade(parent: Node3D, at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "EmeraldPalaceFacade"
	root.position = at
	parent.add_child(root)

	var glass := _mat(Color(0.12, 0.68, 0.40), 0.16, 0.45, Color(0.10, 0.78, 0.42), 0.65)
	var spire_hi := _mat(Color(0.30, 0.96, 0.60), 0.10, 0.55, Color(0.24, 1.0, 0.58), 1.15)
	var gold := _mat(Color(0.94, 0.78, 0.34), 0.22, 0.88, Color(0.90, 0.72, 0.24), 0.25)

	# Clustered crystalline spires rising from the palace roof matching add_emerald_skyline
	var spires := [
		{"x": 0.0, "z": -6.0, "r": 4.4, "h": 34.0},
		{"x": -10.5, "z": -2.0, "r": 2.9, "h": 24.0},
		{"x": 10.5, "z": -2.0, "r": 2.9, "h": 24.0},
		{"x": -15.0, "z": 6.0, "r": 2.2, "h": 18.0},
		{"x": 15.0, "z": 6.0, "r": 2.2, "h": 18.0},
	]
	for sp in spires:
		var sx: float = float(sp["x"])
		var sz: float = float(sp["z"])
		var sr: float = float(sp["r"])
		var sh: float = float(sp["h"])
		_mi(root, _cyl(sr * 0.52, sr, sh * 0.65, 10), glass, Vector3(sx, 11.0 + sh * 0.32, sz))
		_mi(root, _cyl(0.18, sr * 0.55, sh * 0.38, 10), spire_hi, Vector3(sx, 11.0 + sh * 0.82, sz))
		# Gilded filigree collar rings around each emerald crystal spire
		_mi(root, _cyl(sr * 0.82, sr * 0.82, 0.45, 12), gold, Vector3(sx, 11.0 + sh * 0.34, sz))
		_mi(root, _cyl(sr * 0.56, sr * 0.56, 0.38, 12), gold, Vector3(sx, 11.0 + sh * 0.64, sz))
		_mi(root, _sph(0.55, 1.1, 10), gold, Vector3(sx, 11.0 + sh + 0.6, sz))

	# Grand gilded archway crest over the Palace entrance (+Z face)
	_mi(root, _cyl(0.42, 0.52, 9.5, 12), gold, Vector3(-4.2, 4.75, 15.8))
	_mi(root, _cyl(0.42, 0.52, 9.5, 12), gold, Vector3(4.2, 4.75, 15.8))
	var arch_ring := TorusMesh.new()
	arch_ring.inner_radius = 3.8
	arch_ring.outer_radius = 4.5
	_mi(root, arch_ring, gold, Vector3(0, 7.2, 15.8))

## Holographic Fresnel rim-glow + horizontal arcane scanlines spatial shader for Oz Projection.
static func make_hologram_material(base_col: Color, rim_col: Color, alpha: float = 0.84) -> ShaderMaterial:
	if _holo_shader == null:
		_holo_shader = Shader.new()
		_holo_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 base_color : source_color = vec4(0.05, 0.34, 0.20, 0.86);
uniform vec4 rim_color : source_color = vec4(0.32, 1.0, 0.62, 1.0);
uniform float alpha_val = 0.86;

void fragment() {
	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, 2.3);
	float scan = 0.88 + 0.12 * sin(FRAGCOORD.y * 0.45 + TIME * 5.0);
	vec3 col = mix(base_color.rgb * 0.55, rim_color.rgb, fresnel * 0.92) * scan;
	ALBEDO = col;
	EMISSION = mix(base_color.rgb * 0.45, rim_color.rgb * 2.1, fresnel) * scan;
	ALPHA = clamp(alpha_val + fresnel * 0.14, 0.0, 1.0);
	ROUGHNESS = 0.22;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _holo_shader
	sm.set_shader_parameter("base_color", base_col)
	sm.set_shader_parameter("rim_color", rim_col)
	sm.set_shader_parameter("alpha_val", alpha)
	return sm

## Multi-plane chiseled volumetric holographic visage of OZ THE GREAT AND POWERFUL!
static func build_oz_projection_head(parent: Node3D) -> void:
	var holo_face := make_hologram_material(Color(0.06, 0.44, 0.24), Color(0.34, 1.0, 0.62), 0.88)
	var holo_deep := make_hologram_material(Color(0.02, 0.20, 0.12), Color(0.18, 0.78, 0.44), 0.94)
	var holo_flame := make_hologram_material(Color(0.16, 0.75, 0.42), Color(0.55, 1.0, 0.72), 0.74)
	var cavity := _mat(Color(0.01, 0.04, 0.03), 0.95)
	var fire_eye := _mat(Color(1.0, 0.78, 0.18), 0.1, 0.0, Color(1.0, 0.56, 0.08), 3.8)
	var pupil := _mat(Color(0.05, 0.01, 0.01), 0.1)
	var gold := _mat(Color(0.95, 0.78, 0.28), 0.22, 0.90, Color(0.95, 0.72, 0.20), 0.85)
	var beam_mat := _mat(Color(0.22, 0.95, 0.55, 0.16), 0.2, 0.0, Color(0.22, 0.95, 0.55), 1.4)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# 1) REAR 16-Ray Golden-Emerald Sunburst Mandorla & Rotating Astrolabe (STRICTLY BEHIND HEAD at z = -1.8!)
	var halo_outer := Node3D.new()
	halo_outer.name = "HaloOuter"
	halo_outer.position = Vector3(0, 0.2, -1.85)
	parent.add_child(halo_outer)
	var r1 := TorusMesh.new()
	r1.inner_radius = 4.35
	r1.outer_radius = 4.65
	_mi(halo_outer, r1, gold, Vector3.ZERO)
	var r2 := TorusMesh.new()
	r2.inner_radius = 3.55
	r2.outer_radius = 3.78
	_mi(halo_outer, r2, holo_flame, Vector3(0, 0, 0.25))
	for ri in range(16):
		var a := float(ri) / 16.0 * TAU
		var rlen := 2.4 if ri % 2 == 0 else 1.45
		_mi(halo_outer, _cyl(0.03, 0.18, rlen, 6), gold if ri % 2 == 0 else holo_flame, Vector3(cos(a) * (4.5 + rlen * 0.45), sin(a) * (4.5 + rlen * 0.45), 0), Vector3(0, 0, rad_to_deg(a) - 90.0))

	# 2) Twin Flanking Coiled Brass Tesla Towers + Giant Interlocking Brass Projector Gears (enemy_02_oz_hologram.jpg)
	for sx in [-1.0, 1.0]:
		var s: float = float(sx)
		_mi(parent, _cyl(0.34, 0.54, 6.8, 12), gold, Vector3(s * 6.2, -3.6, 1.2))
		for ci in range(7):
			_mi(parent, _torus(0.56, 0.72, 12), gold, Vector3(s * 6.2, -5.8 + float(ci) * 0.72, 1.2))
		_mi(parent, _sph(0.55, 1.05, 12), holo_flame, Vector3(s * 6.2, 0.05, 1.2))
		_mi(parent, _cyl(1.85, 0.22, 6.2, 12), beam_mat, Vector3(s * 3.2, 0.05, 0.5), Vector3(0, 0, s * 84.0))
		# Giant interlocking brass projector gears flanking the dais
		_mi(parent, _torus(1.15, 1.45, 16), gold, Vector3(s * 3.2, -4.4, 0.4), Vector3(90, 0, 0))
		_mi(parent, _cyl(0.45, 0.52, 2.2, 12), gold, Vector3(s * 3.8, -4.4, 1.2), Vector3(90, s * -22, 0)) # projector lens barrel

	# 3) Multi-Plane Chiseled Titan Cranium & Face (NO single smooth egg sphere!)
	_mi(parent, _cyl(1.85, 2.15, 2.2, 12), holo_face, Vector3(0, 1.65, 0.0), Vector3.ZERO, Vector3(1.05, 1.0, 0.92)) # angular upper cranium
	_mi(parent, _sph(2.05, 2.2, 14), holo_face, Vector3(0, 2.75, -0.10), Vector3.ZERO, Vector3(0.95, 0.72, 0.88)) # domed crown
	_mi(parent, _box(Vector3(3.15, 2.45, 2.1)), holo_deep, Vector3(0, 0.15, -0.15)) # inner structural core
	# Fierce angled supraorbital brow arches (scowling inward over eyes)
	for sx in [-1.0, 1.0]:
		var s: float = float(sx)
		_mi(parent, _box(Vector3(1.55, 0.46, 1.15)), holo_face, Vector3(s * 0.86, 1.38, 1.48), Vector3(14, s * -16, s * 16))
		# High flared zygomatic cheekbones + hollow gaunt cheek planes
		_mi(parent, _box(Vector3(1.15, 0.75, 1.25)), holo_face, Vector3(s * 1.42, 0.10, 1.18), Vector3(-10, s * -28, s * -12))
		_mi(parent, _box(Vector3(0.85, 1.35, 1.15)), holo_deep, Vector3(s * 1.22, -0.78, 0.95), Vector3(0, s * -22, s * 14))
		# Temporal side-flanges (majestic sculptural framing)
		_mi(parent, _box(Vector3(0.45, 2.6, 1.45)), holo_deep, Vector3(s * 2.05, 0.85, 0.25), Vector3(0, s * -15, s * -8))

	# Chiseled aquiline nose bridge + nostrils
	var nose := PrismMesh.new()
	nose.size = Vector3(0.68, 1.85, 1.15)
	_mi(parent, nose, holo_face, Vector3(0, 0.35, 1.92), Vector3(-10, 0, 0))
	for nx in [-0.28, 0.28]:
		_mi(parent, _sph(0.24, 0.32, 8), holo_face, Vector3(float(nx), -0.45, 1.98))

	# Sweeping sculpted holographic mustache wings above the jaw
	for sx in [-1.0, 1.0]:
		var s: float = float(sx)
		_mi(parent, _cyl(0.08, 0.28, 1.65, 8), holo_flame, Vector3(s * 0.88, -0.78, 1.85), Vector3(12, s * -18, s * 74))

	# Deep dark orbital cavities + blazing golden-amber iris eyes with vertical slit pupils
	for ex in [-0.88, 0.88]:
		var x: float = float(ex)
		_mi(parent, _box(Vector3(1.15, 0.78, 0.75)), cavity, Vector3(x, 0.82, 1.45))
		_mi(parent, _sph(0.36, 0.62, 14), fire_eye, Vector3(x, 0.82, 1.72))
		_mi(parent, _box(Vector3(0.09, 0.46, 0.14)), pupil, Vector3(x, 0.82, 2.06))

	# 4) Hinged Articulated Lower Jaw ("Mouth") with chin cleft & layered pharaonic beard plates
	var jaw := Node3D.new()
	jaw.name = "Mouth"
	jaw.position = Vector3(0, -1.25, 1.35)
	parent.add_child(jaw)
	_mi(jaw, _box(Vector3(2.05, 0.52, 1.15)), cavity, Vector3(0, 0.0, 0.15))
	_mi(jaw, _box(Vector3(1.92, 0.62, 1.18)), holo_face, Vector3(0, -0.48, 0.38)) # chiseled chin
	for ti in range(5):
		var tx := -0.68 + float(ti) * 0.34
		_mi(jaw, _box(Vector3(0.18, 0.16, 0.14)), holo_flame, Vector3(tx, 0.12, 0.76))
		_mi(jaw, _box(Vector3(0.18, 0.16, 0.14)), holo_flame, Vector3(tx, -0.18, 0.76))
	# Stepped gilded-emerald pharaonic beard plates
	_mi(jaw, _box(Vector3(1.25, 0.95, 0.42)), holo_flame, Vector3(0, -1.15, 0.35))
	_mi(jaw, _box(Vector3(0.82, 0.85, 0.35)), holo_face, Vector3(0, -1.95, 0.30))
	_mi(jaw, _box(Vector3(1.32, 0.14, 0.48)), gold, Vector3(0, -1.52, 0.36))

## Builds colossal hinged Emerald & Gold Double Doors that completely seal an archway until E opens them.
static func build_palace_double_doors(parent: Node3D, at: Vector3, total_w: float, door_h: float) -> Dictionary:
	var root := Node3D.new()
	root.name = "PalaceDoubleDoors"
	root.position = at
	parent.add_child(root)

	var emerald := _mat(Color(0.06, 0.38, 0.22), 0.28, 0.35, Color(0.08, 0.55, 0.30), 0.35)
	var gold := _mat(Color(0.92, 0.76, 0.30), 0.24, 0.88, Color(0.90, 0.70, 0.22), 0.25)
	var crystal := _mat(Color(0.32, 1.0, 0.62), 0.12, 0.4, Color(0.28, 1.0, 0.58), 1.6)
	var leaf_w := total_w * 0.5 + 0.08

	var piv_l := Node3D.new()
	piv_l.name = "LeftDoorPivot"
	piv_l.position = Vector3(-total_w * 0.5, 0, 0)
	root.add_child(piv_l)

	var piv_r := Node3D.new()
	piv_r.name = "RightDoorPivot"
	piv_r.position = Vector3(total_w * 0.5, 0, 0)
	root.add_child(piv_r)

	for pair in [[piv_l, 1.0], [piv_r, -1.0]]:
		var piv: Node3D = pair[0] as Node3D
		var s: float = float(pair[1])
		var cx := s * (leaf_w * 0.5)
		_mi(piv, _box(Vector3(leaf_w, door_h, 0.42)), emerald, Vector3(cx, door_h * 0.5, 0))
		# Gilded outer border frame + decorative inset relief panels + glowing emerald rosette medallion
		_mi(piv, _box(Vector3(leaf_w, 0.28, 0.50)), gold, Vector3(cx, door_h - 0.14, 0))
		_mi(piv, _box(Vector3(leaf_w, 0.28, 0.50)), gold, Vector3(cx, 0.14, 0))
		_mi(piv, _box(Vector3(0.24, door_h, 0.50)), gold, Vector3(s * (leaf_w - 0.12), door_h * 0.5, 0))
		_mi(piv, _sph(0.68, 0.28, 14), gold, Vector3(cx, door_h * 0.56, 0.24), Vector3(90, 0, 0))
		_mi(piv, _sph(0.42, 0.22, 12), crystal, Vector3(cx, door_h * 0.56, 0.30), Vector3(90, 0, 0))
		# Ornate golden pull-ring handle near center seam
		var ring := TorusMesh.new()
		ring.inner_radius = 0.22
		ring.outer_radius = 0.30
		_mi(piv, ring, gold, Vector3(s * (leaf_w - 0.55), 2.15, 0.28))

	return {"root": root, "left": piv_l, "right": piv_r}

## Disney-World Fairy-Tale Emerald City Ramparts: 6 Crystal Turrets, Battlements, Glowing Stained-Glass Niches, Pennants & Fountains!
static func dress_emerald_city_wall(parent: Node3D, z_pos: float = -8.0) -> void:
	var root := Node3D.new()
	root.name = "EmeraldCastleRamparts"
	parent.add_child(root)

	var em_wall := _mat(Color(0.10, 0.56, 0.34), 0.24, 0.35, Color(0.08, 0.48, 0.28), 0.22)
	var crystal := _mat(Color(0.24, 0.94, 0.56), 0.10, 0.45, Color(0.20, 0.98, 0.58), 1.45)
	var gold := _mat(Color(0.95, 0.80, 0.32), 0.22, 0.92, Color(0.92, 0.74, 0.24), 0.28)
	var glass_glow := _mat(Color(0.55, 1.0, 0.78), 0.12, 0.2, Color(0.45, 1.0, 0.72), 2.1)
	var crimson := _mat(Color(0.76, 0.12, 0.24), 0.55, 0.1)
	var water := make_flowing_water_material(Color(0.18, 0.88, 0.62), Color(0.76, 1.0, 0.88), 1.4)

	# 1) Gilded cornice band & crenellated battlements spanning the entire castle curtain wall
	_mi(root, _box(Vector3(92.0, 0.48, 5.4)), gold, Vector3(0, 12.8, z_pos))
	for bi in range(-22, 23):
		var bx := float(bi) * 2.0
		if absf(bx) < 8.5:
			continue
		if bi % 2 == 0:
			_mi(root, _box(Vector3(1.15, 1.15, 5.3)), em_wall, Vector3(bx, 13.5, z_pos))
			_mi(root, _box(Vector3(1.22, 0.16, 5.38)), gold, Vector3(bx, 14.1, z_pos))

	# 2) Arched glowing stained-glass windows, gold Art-Deco pilasters & royal pennants along the front wall (+Z face)
	for wx in [-40.0, -34.0, -22.0, -16.0, 16.0, 22.0, 34.0, 40.0]:
		_mi(root, _box(Vector3(0.55, 12.6, 0.65)), gold, Vector3(wx - 2.4, 6.4, z_pos + 2.65))
		_mi(root, _box(Vector3(2.2, 5.6, 0.32)), glass_glow, Vector3(wx, 6.8, z_pos + 2.62))
		_mi(root, _cyl(1.1, 1.1, 0.36, 14), glass_glow, Vector3(wx, 9.6, z_pos + 2.62), Vector3(90, 0, 0))
		_mi(root, _box(Vector3(2.55, 0.22, 0.45)), gold, Vector3(wx, 3.9, z_pos + 2.70))
		# Royal emerald-and-crimson tapestry banner hanging beside each arch
		_mi(root, _box(Vector3(0.95, 3.8, 0.08)), crimson, Vector3(wx - 2.4, 8.8, z_pos + 3.05))
		_mi(root, _box(Vector3(1.05, 0.16, 0.12)), gold, Vector3(wx - 2.4, 10.7, z_pos + 3.05))

	# 3) 6 Soaring Fairy-Tale Castle Turrets with conical crystal roofs & gilded spires
	for tx in [-42.0, -28.0, -13.5, 13.5, 28.0, 42.0]:
		var th := 22.0 if absf(tx) < 18.0 else (18.5 if absf(tx) < 32.0 else 16.0)
		var tr := 3.1 if absf(tx) < 18.0 else 2.5
		_mi(root, _cyl(tr, tr * 1.08, th, 16), em_wall, Vector3(tx, th * 0.5, z_pos + 0.8))
		_mi(root, _cyl(tr + 0.25, tr + 0.25, 0.55, 16), gold, Vector3(tx, th + 0.1, z_pos + 0.8))
		_mi(root, _cyl(0.15, tr * 1.15, 7.8, 16), crystal, Vector3(tx, th + 4.1, z_pos + 0.8))
		_mi(root, _cyl(0.05, 0.18, 2.8, 10), gold, Vector3(tx, th + 9.2, z_pos + 0.8))
		# Glowing turret balcony window
		_mi(root, _box(Vector3(1.3, 3.2, 0.45)), glass_glow, Vector3(tx, th * 0.65, z_pos + 0.8 + tr))

	# 4) Flanking Emerald Crystal Fountains with animated flowing water right outside the Grand Gate Arch!
	for sx in [-1.0, 1.0]:
		var fx := float(sx) * 10.6
		var fz := z_pos + 7.2
		_mi(root, _cyl(2.2, 2.5, 0.72, 16), em_wall, Vector3(fx, 0.36, fz))
		_mi(root, _cyl(2.25, 2.25, 0.12, 16), gold, Vector3(fx, 0.74, fz))
		_mi(root, _cyl(1.95, 1.95, 0.08, 16), water, Vector3(fx, 0.66, fz))
		_mi(root, _cyl(0.32, 0.55, 2.2, 12), crystal, Vector3(fx, 1.45, fz))
		_mi(root, _sph(0.45, 0.75, 12), glass_glow, Vector3(fx, 2.85, fz))

## Grandiose Ornate Level-Exit Portal Archway (replaces mundane flat exit pads across Oz!).
static func build_grand_portal_arch(parent: Node3D, at: Vector3, accent_col: Color, title: String) -> Node3D:
	var root := Node3D.new()
	root.name = "GrandPortalArch"
	root.position = at
	parent.add_child(root)
	var gold := _mat(Color(0.95, 0.80, 0.32), 0.22, 0.92, Color(0.92, 0.74, 0.24), 0.28)
	var glow := _mat(accent_col, 0.12, 0.25, accent_col, 1.8)
	var stone := _mat(Color(0.88, 0.86, 0.90), 0.38, 0.08)
	# Glowing circular rune medallion on floor
	_mi(root, _cyl(3.1, 3.3, 0.06, 24), gold, Vector3(0, 0.04, 0))
	_mi(root, _cyl(2.7, 2.7, 0.07, 24), glow, Vector3(0, 0.05, 0))
	# Flanking fluted gilded columns + curved portal arch + 4 glowing Oz Realm Gemstones (quad_01_portal_arch.jpg)
	for sx in [-1.0, 1.0]:
		_mi(root, _cyl(0.42, 0.52, 0.45, 14), gold, Vector3(float(sx) * 3.1, 0.22, 0))
		_mi(root, _cyl(0.28, 0.34, 5.2, 14), stone, Vector3(float(sx) * 3.1, 2.85, 0))
		_mi(root, _cyl(0.48, 0.34, 0.42, 14), gold, Vector3(float(sx) * 3.1, 5.55, 0))
		_mi(root, _sph(0.32, 0.52, 12), glow, Vector3(float(sx) * 3.1, 6.15, 0))
	var realm_gems := [
		[-1.65, Color(0.22, 0.52, 1.0)],  # North/Blue
		[-0.55, Color(0.16, 0.92, 0.44)], # Emerald
		[0.55, Color(0.96, 0.18, 0.34)],  # South/Ruby
		[1.65, Color(1.0, 0.80, 0.20)],   # West/Topaz
	]
	for g in realm_gems:
		var gx: float = float(g[0])
		var gcol: Color = g[1]
		var gmat := _mat(gcol, 0.10, 0.2, gcol, 2.4)
		_mi(root, _box(Vector3(0.56, 0.72, 0.24)), gold, Vector3(gx, 6.25, 0.25))
		_mi(root, _box(Vector3(0.40, 0.56, 0.30)), gmat, Vector3(gx, 6.25, 0.27))
	_mi(root, _box(Vector3(6.8, 0.55, 0.65)), gold, Vector3(0, 5.85, 0))
	_mi(root, _sph(0.55, 0.95, 14), glow, Vector3(0, 6.75, 0))
	make_building_crest_sign(root, Vector3(0, 5.85, 0.45), title.to_upper(), accent_col, false)
	return root

## Phase P11: Forward+ ACES Filmic Tonemapping, Subtle Glow/Bloom & SSAO Post-Processing!
static func apply_aaa_post_processing(env: Environment, biome: String = "oz") -> void:
	if env == null:
		return
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.18
	env.glow_hdr_threshold = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.15
	if biome == "munchkin":
		env.fog_enabled = true
		env.fog_density = 0.0025

## Phase P11: Destructible Gilded Porcelain Urn — shatters on F/C hit & drops +5 Desire Fragments!
static func spawn_destructible_urn(parent: Node3D, at: Vector3) -> StaticBody3D:
	var urn := StaticBody3D.new()
	urn.set_script(preload("res://systems/destructible_prop.gd"))
	urn.name = "PorcelainUrn"
	parent.add_child(urn)
	urn.global_position = at
	var porc := _mat(Color(0.92, 0.88, 0.96), 0.18, 0.12)
	var gold := _mat(Color(0.95, 0.78, 0.30), 0.22, 0.90)
	_mi(urn, _cyl(0.28, 0.18, 0.22, 14), gold, Vector3(0, 0.11, 0))
	_mi(urn, _sph(0.36, 0.68, 14), porc, Vector3(0, 0.52, 0))
	_mi(urn, _cyl(0.24, 0.16, 0.22, 14), gold, Vector3(0, 0.92, 0))
	var col := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.38
	sh.height = 1.05
	col.shape = sh
	col.position = Vector3(0, 0.52, 0)
	urn.add_child(col)
	return urn

## Theatrical crimson-velvet parting curtain on gilded brass rod with pleated folds, rings & gold tassels.
## Returns {"root": Node3D, "left": Node3D, "right": Node3D} so callers can animate both drapes drawing back!
static func build_velvet_curtain(parent: Node3D, pos: Vector3, width: float = 5.4, height: float = 6.2) -> Dictionary:
	var root := Node3D.new()
	root.name = "VelvetCurtainRig"
	parent.add_child(root)
	root.global_position = pos

	var velvet := _mat(Color(0.54, 0.05, 0.10), 0.88, 0.04, Color(0.28, 0.02, 0.04), 0.14)
	var velvet_hi := _mat(Color(0.68, 0.08, 0.14), 0.82, 0.06, Color(0.32, 0.03, 0.05), 0.16)
	var gold := _mat(Color(0.92, 0.74, 0.26), 0.24, 0.88, Color(0.85, 0.65, 0.18), 0.22)
	var dark_wood := _mat(Color(0.18, 0.12, 0.09), 0.78)

	# Supporting side posts + gilded overhead brass rod + finials + valance
	for sx in [-1.0, 1.0]:
		_mi(root, _cyl(0.10, 0.12, height + 0.4, 12), dark_wood, Vector3(float(sx) * (width * 0.5 + 0.15), (height + 0.4) * 0.5, 0))
		_mi(root, _sph(0.20, 0.36, 12), gold, Vector3(float(sx) * (width * 0.5 + 0.25), height + 0.15, 0))
	_mi(root, _cyl(0.065, 0.065, width + 0.45, 14), gold, Vector3(0, height + 0.15, 0), Vector3(0, 0, 90))
	# Pelmet / scalloped valance across top
	_mi(root, _box(Vector3(width + 0.3, 0.55, 0.38)), velvet_hi, Vector3(0, height - 0.05, 0.12))
	_mi(root, _box(Vector3(width + 0.32, 0.09, 0.40)), gold, Vector3(0, height - 0.34, 0.12))
	# Colossal interlocking brass clockwork gears behind the crimson velvet curtain (we_01_wizard_throne_room.jpg)
	var gear_brass := _mat(Color(0.68, 0.52, 0.24), 0.36, 0.85)
	for gspec in [[Vector3(-1.1, 3.6, -1.8), 1.15], [Vector3(0.95, 2.4, -1.85), 1.35], [Vector3(-0.35, 1.5, -1.9), 0.88]]:
		var gp: Vector3 = gspec[0]
		var gr: float = float(gspec[1])
		_mi(root, _torus(gr * 0.78, gr, 16), gear_brass, gp, Vector3(90, 0, 0))
		_mi(root, _cyl(0.10, 0.10, gr * 1.9, 6), gear_brass, gp)
		_mi(root, _cyl(0.10, 0.10, gr * 1.9, 6), gear_brass, gp, Vector3(0, 0, 90))

	# Two parting drape panels (left & right), each pivoted at its outer edge so scaling X compresses folds!
	var half_w := width * 0.5
	var left_drape := Node3D.new()
	left_drape.name = "LeftDrape"
	left_drape.position = Vector3(-half_w, 0.0, 0.0)
	root.add_child(left_drape)

	var right_drape := Node3D.new()
	right_drape.name = "RightDrape"
	right_drape.position = Vector3(half_w, 0.0, 0.0)
	root.add_child(right_drape)

	var folds := 6
	var fold_w := half_w / float(folds)
	for side_idx in range(2):
		var drape: Node3D = left_drape if side_idx == 0 else right_drape
		var dir: float = 1.0 if side_idx == 0 else -1.0
		for fi in range(folds):
			var fx := dir * (float(fi) + 0.5) * fold_w
			var fz := 0.10 if (fi % 2 == 0) else -0.08
			var m: StandardMaterial3D = velvet if (fi % 2 == 0) else velvet_hi
			_mi(drape, _cyl(fold_w * 0.56, fold_w * 0.62, height, 12), m, Vector3(fx, height * 0.5, fz))
			# Brass curtain ring at top of each pleat
			_mi(drape, _cyl(0.09, 0.09, 0.05, 10), gold, Vector3(fx, height + 0.12, 0.0), Vector3(90, 0, 0))
		# Gold braided hem & tieback tassel
		_mi(drape, _box(Vector3(half_w, 0.12, 0.28)), gold, Vector3(dir * half_w * 0.5, 0.10, 0.02))
		_mi(drape, _cyl(0.08, 0.14, 0.52, 10), gold, Vector3(dir * (half_w - 0.18), height * 0.42, 0.18))

	return {"root": root, "left": left_drape, "right": right_drape}

## Sculpted 19th-century Omaha Humbug Inventor + Brass Voice-Horn & Geared Projector Console (facing +Z).
static func build_humbug_wizard(parent: Node3D) -> void:
	var coat := _mat(Color(0.24, 0.16, 0.22), 0.78)
	var vest := _mat(Color(0.62, 0.44, 0.16), 0.58)
	var shirt := _mat(Color(0.94, 0.92, 0.88), 0.72)
	var skin := _mat(Color(0.94, 0.78, 0.66), 0.46)
	var hair := _mat(Color(0.88, 0.88, 0.92), 0.72)
	var brass := _mat(Color(0.90, 0.72, 0.28), 0.24, 0.88, Color(0.85, 0.65, 0.20), 0.22)
	var iron := _mat(Color(0.24, 0.26, 0.30), 0.42, 0.75)
	var eye_m := _mat(Color(0.10, 0.10, 0.14), 0.2)

	# Small dapper bald inventor: boots, trousers, embroidered vest, coat, arms, sculpted face + spectacles
	for sx in [-0.11, 0.11]:
		_mi(parent, _cyl(0.072, 0.080, 0.74, 12), coat, Vector3(float(sx), 0.37, 0))
		_mi(parent, _box(Vector3(0.14, 0.10, 0.24)), iron, Vector3(float(sx), 0.05, 0.06))
	_mi(parent, _cyl(0.20, 0.22, 0.58, 16), vest, Vector3(0, 1.02, 0.03))
	_mi(parent, _cyl(0.08, 0.10, 0.24, 12), shirt, Vector3(0, 1.24, 0.14))
	_mi(parent, _cyl(0.24, 0.26, 0.70, 16), coat, Vector3(0, 0.98, -0.05))
	for sx in [-1.0, 1.0]:
		_mi(parent, _cyl(0.048, 0.042, 0.48, 10), coat, Vector3(float(sx) * 0.27, 1.06, 0.12), Vector3(-34, 0, -float(sx) * 14))
		_mi(parent, _sph(0.048, 0.095, 10), skin, Vector3(float(sx) * 0.30, 0.88, 0.26))
	# Head + dark tousled hair + silk top hat with tucked Omaha Fair ticket + spectacles facing +Z (npc_07_oscar_diggs.jpg)
	var dark_hair := _mat(Color(0.18, 0.14, 0.12), 0.72)
	var hat_m := _mat(Color(0.12, 0.11, 0.13), 0.58)
	var ticket_m := _mat(Color(0.92, 0.84, 0.66), 0.80)
	_mi(parent, _sph(0.165, 0.34, 18), skin, Vector3(0, 1.54, 0))
	_mi(parent, _sph(0.172, 0.18, 14), dark_hair, Vector3(0, 1.56, -0.04))
	_mi(parent, _cyl(0.24, 0.24, 0.028, 18), hat_m, Vector3(0, 1.69, 0), Vector3(-6, 0, 5)) # top hat brim
	_mi(parent, _cyl(0.16, 0.14, 0.26, 18), hat_m, Vector3(0, 1.83, -0.01), Vector3(-6, 0, 5)) # silk top hat crown
	_mi(parent, _cyl(0.146, 0.146, 0.045, 18), vest, Vector3(0, 1.72, -0.01), Vector3(-6, 0, 5)) # hat band
	_mi(parent, _box(Vector3(0.055, 0.085, 0.012)), ticket_m, Vector3(0.12, 1.78, 0.09), Vector3(-6, 28, -14)) # tucked Omaha Fair ticket
	_mi(parent, _sph(0.035, 0.06, 10), skin, Vector3(0, 1.52, 0.165)) # nose
	_mi(parent, _box(Vector3(0.14, 0.036, 0.04)), dark_hair, Vector3(0, 1.46, 0.155)) # dark showman moustache
	for sx in [-0.055, 0.055]:
		_mi(parent, _sph(0.022, 0.044, 10), eye_m, Vector3(float(sx), 1.56, 0.148))
		_mi(parent, _cyl(0.042, 0.042, 0.015, 12), brass, Vector3(float(sx), 1.56, 0.162), Vector3(90, 0, 0)) # gold spectacles
	# Brass & Iron Wizard Projector Console + Speaking Trumpet + Control Levers (beside him)
	_mi(parent, _box(Vector3(1.25, 1.35, 0.70)), iron, Vector3(-1.10, 0.68, -0.25))
	_mi(parent, _cyl(0.24, 0.24, 0.08, 14), brass, Vector3(-1.10, 1.10, 0.12), Vector3(90, 0, 0)) # spinning gear dial
	_mi(parent, _cyl(0.30, 0.06, 0.80, 14), brass, Vector3(-0.68, 1.56, -0.25), Vector3(0, 0, 52)) # voice megaphone horn
	for lx in [-1.35, -1.10, -0.85]:
		_mi(parent, _cyl(0.022, 0.022, 0.44, 6), brass, Vector3(float(lx), 1.54, -0.15), Vector3(-18, 0, 0))

## Sculpted 24-segment high-fashion Glinda, Good Witch of the South (Baum canon: auburn braids, snow-white & ruby silk, ruby-star crown).
static func build_glinda_visual(parent: Node3D) -> void:
	var gown_w := _mat(Color(0.98, 0.95, 0.96), 0.36, 0.08, Color(0.95, 0.72, 0.85), 0.16)
	var rose_silk := _mat(Color(0.92, 0.34, 0.56), 0.38, 0.12, Color(0.95, 0.32, 0.54), 0.20)
	var gold := _mat(Color(0.96, 0.82, 0.38), 0.22, 0.90, Color(0.96, 0.78, 0.32), 0.24)
	var skin := _mat(Color(0.96, 0.82, 0.73), 0.42)
	var auburn := _mat(Color(0.62, 0.18, 0.10), 0.52, 0.12)
	var ruby := _mat(Color(0.98, 0.16, 0.34), 0.12, 0.25, Color(1.0, 0.22, 0.42), 2.1)
	var veil := _mat(Color(1.0, 0.86, 0.92, 0.52), 0.32, 0.05)
	veil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Smooth tiered royal snow-white & rose-silk ballgown (NO protruding waist-poles!)
	_mi(parent, _cyl(0.16, 0.64, 1.06, 28), gown_w, Vector3(0, 0.53, 0))
	_mi(parent, _cyl(0.18, 0.48, 0.54, 26), rose_silk, Vector3(0, 0.78, 0))
	_mi(parent, _cyl(0.61, 0.65, 0.06, 28), gold, Vector3(0, 0.04, 0))
	_mi(parent, _cyl(0.46, 0.50, 0.04, 26), gold, Vector3(0, 0.52, 0))

	# Contoured bodice + bust silhouette + ruby brooch + gossamer cape
	_mi(parent, _cyl(0.15, 0.12, 0.26, 20), rose_silk, Vector3(0, 1.15, 0))
	_mi(parent, _cyl(0.17, 0.15, 0.22, 20), gown_w, Vector3(0, 1.36, 0))
	_mi(parent, _sph(0.09, 0.16, 14), gown_w, Vector3(-0.072, 1.34, -0.075))
	_mi(parent, _sph(0.09, 0.16, 14), gown_w, Vector3(0.072, 1.34, -0.075))
	_mi(parent, _sph(0.045, 0.07, 10), ruby, Vector3(0, 1.32, -0.14))
	_mi(parent, _cyl(0.16, 0.52, 1.08, 16), veil, Vector3(0, 1.08, 0.18), Vector3(16, 0, 0))

	# Slender articulated arms + golden ruby-star scepter
	for sx in [-1.0, 1.0]:
		var s: float = float(sx)
		_mi(parent, _sph(0.08, 0.15, 12), gown_w, Vector3(s * 0.21, 1.42, 0))
		_mi(parent, _cyl(0.044, 0.035, 0.32, 12), gown_w, Vector3(s * 0.25, 1.26, -0.02), Vector3(12, 0, -s * 14))
		_mi(parent, _cyl(0.034, 0.028, 0.28, 12), skin, Vector3(s * 0.30, 1.04, -0.10), Vector3(28, 0, -s * 8))
		_mi(parent, _sph(0.038, 0.076, 10), skin, Vector3(s * 0.32, 0.94, -0.16))
	_mi(parent, _cyl(0.016, 0.022, 1.52, 10), gold, Vector3(0.36, 1.24, -0.22), Vector3(10, 0, -5))
	_mi(parent, _sph(0.095, 0.18, 14), ruby, Vector3(0.42, 2.02, -0.35))

	# Neck, sculpted head with expressive eyes & lips, cascading auburn hair, ruby-star tiara
	_mi(parent, _cyl(0.046, 0.056, 0.12, 14), skin, Vector3(0, 1.50, 0))
	_mi(parent, _sph(0.135, 0.29, 20), skin, Vector3(0, 1.66, 0))
	var g_eye := _mat(Color(0.20, 0.52, 0.38), 0.18)
	var g_lip := _mat(Color(0.84, 0.24, 0.38), 0.38)
	for ex in [-0.046, 0.046]:
		_mi(parent, _sph(0.019, 0.036, 10), g_eye, Vector3(float(ex), 1.68, -0.120))
	_mi(parent, _sph(0.018, 0.012, 10), g_lip, Vector3(0, 1.60, -0.124), Vector3.ZERO, Vector3(1.8, 0.7, 0.8))
	_mi(parent, _sph(0.148, 0.28, 20), auburn, Vector3(0, 1.70, 0.025))
	_mi(parent, _cyl(0.09, 0.12, 0.56, 14), auburn, Vector3(0, 1.38, 0.12), Vector3(16, 0, 0))
	_mi(parent, _cyl(0.15, 0.15, 0.045, 20), gold, Vector3(0, 1.80, 0))
	for gi in range(5):
		var ga := float(gi) / 5.0 * TAU
		var gh := 0.18 if gi == 0 else 0.11
		_mi(parent, _cyl(0.008, 0.026, gh, 8), gold, Vector3(sin(ga) * 0.135, 1.82 + gh * 0.5, -cos(ga) * 0.135))
	_mi(parent, _sph(0.055, 0.10, 12), ruby, Vector3(0, 1.94, -0.13))
	# High Victorian lace ruff collar (npc_03_glinda.jpg)
	_mi(parent, _cyl(0.25, 0.14, 0.14, 18), gown_w, Vector3(0, 1.54, 0.06), Vector3(-22, 0, 0))

## Royal Quadling Country beautification: 8-column Alabaster Rotunda, Reflecting Pools, Rose Trees & Compass Altar.
static func dress_glinda_court(parent: Node3D, glinda_pos: Vector3, home_pad: Vector3) -> void:
	var root := Node3D.new()
	root.name = "GlindaCourtDecor"
	parent.add_child(root)

	var marble := _mat(Color(0.96, 0.92, 0.94), 0.32, 0.06)
	var rose_marble := _mat(Color(0.86, 0.44, 0.62), 0.36, 0.10)
	var gold := _mat(Color(0.94, 0.78, 0.34), 0.24, 0.88, Color(0.90, 0.72, 0.24), 0.22)
	var water := make_flowing_water_material(Color(0.32, 0.70, 0.96), Color(0.88, 0.96, 1.0), 0.95)
	var lotus := _mat(Color(1.0, 0.58, 0.78), 0.45, 0.0, Color(1.0, 0.55, 0.76), 0.55)
	var star_glow := _mat(Color(1.0, 0.92, 0.72), 0.15, 0.0, Color(1.0, 0.88, 0.62), 2.2)

	# 1) 8-Column Alabaster & Rose-Gold Temple Rotunda around Glinda (SOLID COLLIDABLE DAIS!)
	var pav := Node3D.new()
	pav.position = Vector3(glinda_pos.x, 0.0, glinda_pos.z)
	root.add_child(pav)
	# Collidable stepped marble dais (top at y = 0.10m so characters' feet stand cleanly ON TOP!)
	var dais_body := StaticBody3D.new()
	dais_body.name = "PavilionDaisCollider"
	dais_body.collision_layer = 1
	dais_body.collision_mask = 0
	pav.add_child(dais_body)
	_mi(dais_body, _cyl(9.2, 9.6, 0.06, 24), marble, Vector3(0, 0.03, 0))
	_mi(dais_body, _cyl(7.8, 8.1, 0.06, 24), rose_marble, Vector3(0, 0.08, 0))
	var dcol1 := CollisionShape3D.new()
	var dsh1 := CylinderShape3D.new()
	dsh1.radius = 9.4
	dsh1.height = 0.06
	dcol1.shape = dsh1
	dcol1.position = Vector3(0, 0.03, 0)
	dais_body.add_child(dcol1)
	var dcol2 := CollisionShape3D.new()
	var dsh2 := CylinderShape3D.new()
	dsh2.radius = 8.0
	dsh2.height = 0.06
	dcol2.shape = dsh2
	dcol2.position = Vector3(0, 0.08, 0)
	dais_body.add_child(dcol2)
	_mi(pav, _cyl(8.6, 8.6, 0.45, 24), gold, Vector3(0, 6.85, 0)) # crown cornice ring
	_mi(pav, _sph(8.4, 5.2, 24), rose_marble, Vector3(0, 7.1, 0), Vector3.ZERO, Vector3(1.0, 0.55, 1.0)) # ribbed rose dome
	_mi(pav, _cyl(0.12, 0.42, 2.2, 12), gold, Vector3(0, 10.6, 0)) # golden temple finial
	# Radiant golden 8-point starburst crown atop Glinda's dome (quad_02_glinda_pavilion.jpg)
	_mi(pav, _sph(0.42, 0.84, 12), star_glow, Vector3(0, 11.75, 0))
	for sri in range(4):
		_mi(pav, _cyl(0.03, 0.06, 2.2, 6), gold, Vector3(0, 11.75, 0), Vector3(0, 0, float(sri) * 45.0))
	for ci in range(8):
		var a := float(ci) / 8.0 * TAU + PI * 0.125
		var cx := cos(a) * 8.1
		var cz := sin(a) * 8.1
		_mi(pav, _cyl(0.46, 0.56, 0.42, 14), gold, Vector3(cx, 0.42, cz))
		_mi(pav, _cyl(0.34, 0.38, 6.2, 16), marble, Vector3(cx, 3.55, cz))
		_mi(pav, _cyl(0.54, 0.38, 0.42, 14), gold, Vector3(cx, 6.55, cz))
	# Hanging crystal star-chandelier
	_mi(pav, _cyl(0.04, 0.04, 1.8, 8), gold, Vector3(0, 6.2, 0))
	_mi(pav, _sph(0.45, 0.9, 12), star_glow, Vector3(0, 5.2, 0))
	# Ornate Ruby-Filigree Throne behind Glinda
	_mi(pav, _box(Vector3(2.2, 0.45, 1.6)), gold, Vector3(0, 0.52, -2.4))
	_mi(pav, _box(Vector3(1.9, 3.2, 0.28)), rose_marble, Vector3(0, 2.1, -3.05))
	_mi(pav, _sph(0.55, 0.55, 14), gold, Vector3(0, 3.75, -3.05))

	# 2) Mirror-water Reflecting Pools with SOLID COLLIDABLE surfaces (feet NEVER clip inside!)
	for sx in [-1.0, 1.0]:
		var px := float(sx) * 11.5
		var pool_body := StaticBody3D.new()
		pool_body.name = "ReflectingPool_%s" % ("L" if sx < 0 else "R")
		pool_body.collision_layer = 1
		pool_body.collision_mask = 0
		root.add_child(pool_body)
		pool_body.position = Vector3(px, 0.0, 12.0)
		# Flush shallow marble curb + mirror-glass water surface (top y = 0.08m — cleanly steppable & solid!)
		_mi(pool_body, _box(Vector3(6.8, 0.07, 34.0)), marble, Vector3(0, 0.035, 0))
		_mi(pool_body, _box(Vector3(5.8, 0.02, 33.0)), water, Vector3(0, 0.072, 0))
		var pcol := CollisionShape3D.new()
		var psh := BoxShape3D.new()
		psh.size = Vector3(6.8, 0.08, 34.0)
		pcol.shape = psh
		pcol.position = Vector3(0, 0.04, 0)
		pool_body.add_child(pcol)
		for li in range(7):
			var lz := -14.0 + float(li) * 4.8
			_mi(pool_body, _cyl(0.42, 0.42, 0.02, 10), _mat(Color(0.22, 0.58, 0.32), 0.8), Vector3(sin(lz) * 1.4, 0.088, lz))
			_mi(pool_body, _sph(0.20, 0.16, 8), lotus, Vector3(sin(lz) * 1.4, 0.15, lz))
		# Warm rose-gold glowing water lanterns lining pool edge (quad_02_glinda_pavilion.jpg)
		for wz in [-10.0, 0.0, 10.0]:
			var lpost_x := -float(sx) * 3.1
			_mi(pool_body, _cyl(0.14, 0.18, 0.95, 8), marble, Vector3(lpost_x, 0.50, float(wz)))
			_mi(pool_body, _cyl(0.16, 0.12, 0.36, 8), star_glow, Vector3(lpost_x, 1.15, float(wz)))
			_mi(pool_body, _cyl(0.04, 0.22, 0.20, 8), gold, Vector3(lpost_x, 1.42, float(wz)))

	# 3) Wind-swaying Rose-Blossom Trees & Golden-Rose Meadow Grass
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	var rose_leaf_a := make_leaf_wind_material(Color(0.92, 0.48, 0.68))
	var rose_leaf_b := make_leaf_wind_material(Color(0.84, 0.32, 0.52))
	var bark := _mat(Color(0.44, 0.34, 0.38), 0.88)
	for ti in range(18):
		var side: float = -1.0 if ti % 2 == 0 else 1.0
		var tx := side * rng.randf_range(18.5, 34.0)
		var tz := rng.randf_range(-38.0, 36.0)
		var tr := Node3D.new()
		tr.position = Vector3(tx, 0.0, tz)
		root.add_child(tr)
		_mi(tr, _cyl(0.18, 0.30, 3.2, 10), bark, Vector3(0, 1.6, 0))
		_mi(tr, _sph(1.65, 2.2, 14), rose_leaf_a if ti % 2 == 0 else rose_leaf_b, Vector3(0, 3.8, 0))
		_mi(tr, _sph(1.15, 1.5, 12), rose_leaf_b if ti % 2 == 0 else rose_leaf_a, Vector3(0.9, 3.2, 0.4))

	# 4) Sculpted Silver-Shoe Compass Rose Altar at RoadHomePad
	var altar := Node3D.new()
	altar.position = home_pad
	root.add_child(altar)
	var compass_ring := TorusMesh.new()
	compass_ring.inner_radius = 3.2
	compass_ring.outer_radius = 3.65
	_mi(altar, compass_ring, gold, Vector3(0, 0.14, 0), Vector3(90, 0, 0))
	for ai in range(4):
		var aa := float(ai) * PI * 0.5
		_mi(altar, _cyl(0.14, 0.18, 2.8, 10), marble, Vector3(cos(aa) * 3.5, 1.4, sin(aa) * 3.5))
		_mi(altar, _sph(0.24, 0.36, 10), star_glow, Vector3(cos(aa) * 3.5, 2.95, sin(aa) * 3.5))
