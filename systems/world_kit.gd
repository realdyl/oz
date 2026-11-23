extends RefCounted

## Master 2026 Storybook 3D World, Shader, Architecture, Foliage, Interior & Character Kit.
## Eliminates flat Minecraft boxes, horizon billboard spam, uncollided hills, and stiff cones
## across Oz while keeping all gameplay colliders, Area3Ds, and headless sims 100% intact.

static var _grass_shader: Shader = null
static var _leaf_shader: Shader = null
static var _fishnet_shader: Shader = null
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
	# Brass corner rivets
	for rx in [-0.46, 0.96]:
		for ry in [-0.12, 0.12]:
			_mi(plank_holder, _sph(0.025, 0.05, 6), brass, Vector3(float(rx), float(ry), 0.055))
			_mi(plank_holder, _sph(0.025, 0.05, 6), brass, Vector3(float(rx), float(ry), -0.055))
	# Hanging jewel-lantern finial off the back of the plank
	_mi(plank_holder, _cyl(0.015, 0.015, 0.18, 6), brass, Vector3(-0.52, -0.10, 0))
	_mi(plank_holder, _sph(0.085, 0.15, 10), glow, Vector3(-0.52, -0.24, 0))

	# Double-sided engraved parchment lettering mounted FLUSH onto the arrow board
	var clean_txt := label_text.replace("YBR → ", "").replace("YBR -> ", "").strip_edges()
	for face_z in [0.062, -0.062]:
		var lab := Label3D.new()
		lab.set_meta("styled_plaque", true)
		lab.text = "✦  %s  ➔" % clean_txt
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
		if float(face_z) < 0.0:
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

## Adds a vast continuous under-meadow slab so no sky-void drop-off is ever visible at map borders.
static func add_ground_apron(parent: Node3D, width: float, depth: float, grass_col: Color, y_pos: float = -0.10) -> void:
	var apron := _mi(parent, _box(Vector3(width, 0.14, depth)), _mat(grass_col, 0.96), Vector3(0, y_pos, 0))
	apron.name = "HorizonGroundApron"
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Outer horizon hills placed cleanly just outside the MapBorder tree line (zero void gap, never inside playable rim).
static func add_horizon_hills(parent: Node3D, half_x: float, half_z: float, hill_col: Color) -> void:
	var hroot := Node3D.new()
	hroot.name = "HorizonHills"
	parent.add_child(hroot)

	# Seamless ground apron under the entire horizon ring so the sky never peeks underneath
	add_ground_apron(hroot, (half_x + 140.0) * 2.0, (half_z + 140.0) * 2.0, hill_col.darkened(0.06), -0.12)

	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var m_near := _mat(hill_col, 0.94)
	var m_far := _mat(hill_col.darkened(0.20), 0.96)

	for i in range(32):
		var ang := float(i) / 32.0 * TAU
		var rad := rng.randf_range(22.0, 34.0)
		var margin := rad * 0.85 + 6.0
		var rx := (half_x + margin + rng.randf_range(0.0, 10.0)) * cos(ang)
		var rz := (half_z + margin + rng.randf_range(0.0, 10.0)) * sin(ang)
		var ht := rng.randf_range(14.0, 26.0)
		var mat := m_near if i % 2 == 0 else m_far
		_mi(hroot, _sph(rad, ht, 16), mat, Vector3(rx, -ht * 0.16, rz), Vector3.ZERO, Vector3(1.35, 0.72, 1.35))

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

	for wx_sign in [-1.0, 1.0]:
		var wx: float = float(wx_sign) * (half_w * 0.56)
		_add_window(trim_root, Vector3(wx, 1.95, half_d + 0.17), 0.0, window_glow, timber_mat, shutter_mat, flower_pink, flower_gold)
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
		# Round tea table
		_mi(fit, _cyl(0.62, 0.62, 0.08, 14), timber, Vector3(0.2, 0.82, -0.35))
		_mi(fit, _cyl(0.10, 0.18, 0.76, 10), timber, Vector3(0.2, 0.42, -0.35))
		_mi(fit, _sph(0.14, 0.22, 10), brass, Vector3(0.15, 0.96, -0.35))

	# Framed wall painting / brass title plaque on back wall (NO giant overlapping ceiling text!)
	_mi(fit, _box(Vector3(1.85, 0.78, 0.08)), brass, Vector3(0.65, 2.15, -half_d + 0.18))
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

	var curb_mat := _mat(Color(0.86, 0.68, 0.22), 0.62, 0.18)
	var z := z_start
	var idx := 0
	while z <= z_end:
		for sx in [-1.0, 1.0]:
			var cx: float = float(sx) * (road_half_w + 0.18)
			_mi(yroot, _box(Vector3(0.32, 0.14, 3.6)), curb_mat, Vector3(cx, 0.06, z))
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

	# Smooth pleated ballgown skirt (24 segments) + vertical silk pleats + scalloped hem
	_mi(parent, _cyl(0.16, 0.56, 1.02, 24), gown, Vector3(0, 0.51, 0))
	for pi in range(8):
		var pa := float(pi) / 8.0 * TAU
		_mi(parent, _cyl(0.05, 0.13, 0.98, 10), silk, Vector3(cos(pa) * 0.28, 0.50, sin(pa) * 0.28), Vector3(sin(pa) * 14.0, 0, -cos(pa) * 14.0))
	_mi(parent, _cyl(0.55, 0.58, 0.05, 24), gold, Vector3(0, 0.04, 0))

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
	# Dark iron umbrella/staff in right hand
	_mi(parent, _cyl(0.02, 0.026, 1.75, 10), obsidian, Vector3(0.38, 1.15, -0.26), Vector3(14, 0, -6))
	_mi(parent, _cyl(0.015, 0.14, 0.34, 10), crimson, Vector3(0.42, 1.85, -0.42), Vector3(14, 0, -6))

	# Gaunt head + ONE fierce glowing ember eye + black eye-patch (Baum book canon!)
	_mi(parent, _sph(0.14, 0.31, 18), pale_skin, Vector3(0, 1.72, 0))
	_mi(parent, _sph(0.15, 0.29, 18), hair, Vector3(0, 1.76, 0.03))
	_mi(parent, _sph(0.026, 0.052, 10), eye_ember, Vector3(-0.048, 1.74, -0.125)) # fierce single eye
	_mi(parent, _box(Vector3(0.075, 0.055, 0.03)), obsidian, Vector3(0.048, 1.74, -0.13)) # eye-patch
	_mi(parent, _box(Vector3(0.28, 0.02, 0.02)), obsidian, Vector3(0.0, 1.76, -0.12), Vector3(0, 0, -14)) # patch strap

	# Sweeping buckled gothic witch hat (wide curved brim + bent spire)
	_mi(parent, _cyl(0.46, 0.48, 0.04, 22), obsidian, Vector3(0, 1.86, 0), Vector3(-8, 0, 6))
	_mi(parent, _cyl(0.165, 0.175, 0.06, 18), crimson, Vector3(0, 1.91, 0), Vector3(-8, 0, 6))
	_mi(parent, _box(Vector3(0.08, 0.08, 0.04)), brass, Vector3(0, 1.91, -0.17))
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

## Sculpted mossy boulder & gnarled-root forest sanctuary for the Cowardly Lion in Munchkinland.
static func build_lion_sanctuary(parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "LionDen"
	root.position = at
	parent.add_child(root)

	var stone := _mat(Color(0.36, 0.35, 0.38), 0.94)
	var moss := _mat(Color(0.22, 0.44, 0.22), 0.92)
	var bark := _mat(Color(0.26, 0.17, 0.11), 0.92)
	var fern_m := make_wind_grass_material(Color(0.20, 0.48, 0.22))
	var berry_m := _mat(Color(1.0, 0.62, 0.18), 0.3, 0.0, Color(1.0, 0.55, 0.15), 1.4)

	# Mossy forest floor mound (walkable visual bed)
	_mi(root, _cyl(2.6, 2.9, 0.14, 18), moss, Vector3(0, 0.05, 0.15))

	# Horseshoe of sculpted mossy boulders forming a natural stone hollow (open toward +Z south)
	var rocks := [
		{"p": Vector3(0.0, 0.85, -1.75), "r": 1.35, "s": Vector3(1.5, 0.95, 0.85)},
		{"p": Vector3(-1.85, 0.72, -0.95), "r": 1.15, "s": Vector3(0.95, 0.95, 1.2)},
		{"p": Vector3(1.85, 0.72, -0.95), "r": 1.15, "s": Vector3(0.95, 0.95, 1.2)},
		{"p": Vector3(-2.15, 0.52, 0.65), "r": 0.90, "s": Vector3(0.85, 0.8, 1.1)},
		{"p": Vector3(2.15, 0.52, 0.65), "r": 0.90, "s": Vector3(0.85, 0.8, 1.1)},
	]
	for rk in rocks:
		var rp: Vector3 = rk["p"]
		var rr: float = float(rk["r"])
		var rs: Vector3 = rk["s"]
		_mi(root, _sph(rr, rr * 1.8, 12), stone, rp, Vector3.ZERO, rs)
		_mi(root, _sph(rr * 0.82, rr * 0.9, 10), moss, rp + Vector3(0, rr * 0.55, 0), Vector3.ZERO, rs)

	# Arching gnarled forest roots curving over the hollow
	for sx in [-1.0, 1.0]:
		var s: float = float(sx)
		_mi(root, _cyl(0.14, 0.24, 2.6, 8), bark, Vector3(s * 1.65, 1.35, -0.45), Vector3(14, 0, -s * 28))
		_mi(root, _cyl(0.10, 0.15, 1.8, 8), bark, Vector3(s * 0.65, 2.45, -0.75), Vector3(8, 0, -s * 72))
		# Amber forest lantern-berries hanging from the root arch
		_mi(root, _sph(0.10, 0.14, 8), berry_m, Vector3(s * 1.15, 2.10, -0.15))

	# Swaying fern fronds ringing the entrance
	var frond := PrismMesh.new()
	frond.size = Vector3(0.28, 0.95, 0.04)
	for fi in range(12):
		var a := -PI * 0.15 + float(fi) / 11.0 * (PI * 1.3)
		_mi(root, frond, fern_m, Vector3(cos(a) * 2.35, 0.42, -sin(a) * 1.75 + 0.4), Vector3(38, rad_to_deg(a), 0))

	make_world_badge(root, Vector3(0, 2.95, 0.1), "✦  A Trembling Thicket", Color(1.0, 0.82, 0.48), 11.0)
	return root

## Pristine octagonal carved stone & copper courtyard Water Cistern for L4 Winkie Castle.
static func build_water_cistern(parent: Node3D) -> void:
	var stone := _mat(Color(0.32, 0.34, 0.38), 0.86)
	var stone_hi := _mat(Color(0.46, 0.48, 0.54), 0.78)
	var copper := _mat(Color(0.42, 0.62, 0.56), 0.36, 0.72)
	var iron := _mat(Color(0.14, 0.14, 0.18), 0.44, 0.82)
	var wood := _mat(Color(0.38, 0.24, 0.14), 0.85)
	var water := _mat(Color(0.22, 0.68, 0.98, 0.92), 0.08, 0.15, Color(0.25, 0.72, 1.0), 1.35)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Stepped octagonal stone well basin + copper coping rim
	_mi(parent, _cyl(1.95, 2.15, 0.24, 8), stone, Vector3(0, 0.12, 0))
	_mi(parent, _cyl(1.75, 1.82, 0.92, 8), stone_hi, Vector3(0, 0.58, 0))
	_mi(parent, _cyl(1.86, 1.86, 0.12, 8), copper, Vector3(0, 1.08, 0))
	# Shimmering crystalline water surface + subtle spilled puddles on courtyard stones
	_mi(parent, _cyl(1.52, 1.52, 0.08, 16), water, Vector3(0, 0.98, 0))
	_mi(parent, _cyl(0.65, 0.65, 0.02, 12), water, Vector3(1.85, 0.03, 0.95))
	_mi(parent, _cyl(0.42, 0.42, 0.02, 10), water, Vector3(-1.45, 0.03, 1.55))

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
	return rotor

## Sculpted woven wicker Toto Basket (replaces plain brown box in Kansas).
static func build_wicker_basket(parent: Node3D) -> void:
	for c in parent.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	var wicker := _mat(Color(0.52, 0.50, 0.48), 0.92)
	var wicker_dark := _mat(Color(0.34, 0.33, 0.32), 0.94)
	var cloth := _mat(Color(0.84, 0.84, 0.86), 0.86)

	var b := Node3D.new()
	b.name = "WickerBasketVisual"
	parent.add_child(b)
	_mi(b, _cyl(0.34, 0.26, 0.36, 16), wicker, Vector3(0, 0.18, 0), Vector3.ZERO, Vector3(1.25, 1.0, 0.88))
	for ry in [0.09, 0.19, 0.29]:
		_mi(b, _cyl(0.35, 0.35, 0.03, 16), wicker_dark, Vector3(0, float(ry), 0), Vector3.ZERO, Vector3(1.26, 1.0, 0.90))
	# Checkered cloth liner peeking over rim + hinged double lids
	_mi(b, _cyl(0.36, 0.34, 0.06, 16), cloth, Vector3(0, 0.36, 0), Vector3.ZERO, Vector3(1.22, 1.0, 0.86))
	_mi(b, _box(Vector3(0.38, 0.04, 0.56)), wicker_dark, Vector3(-0.20, 0.40, 0), Vector3(0, 0, 10))
	_mi(b, _box(Vector3(0.38, 0.04, 0.56)), wicker_dark, Vector3(0.20, 0.40, 0), Vector3(0, 0, -10))
	# Arched braided carry handle
	var handle := TorusMesh.new()
	handle.inner_radius = 0.28
	handle.outer_radius = 0.33
	_mi(b, handle, wicker_dark, Vector3(0, 0.38, 0), Vector3(0, 0, 0), Vector3(1.0, 1.05, 0.5))

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
