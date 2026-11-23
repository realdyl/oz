extends RefCounted

## Reusable 2026 Storybook 3D Architecture, Foliage, Lantern, Horizon & Diegetic Label Kit.
## Eliminates the "flat Minecraft box + giant horizon billboard text" look across all Oz regions
## while leaving gameplay colliders, Area3Ds, and beat logic completely untouched.

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

static func _cyl(t: float, b: float, h: float, segs: int = 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = t
	c.bottom_radius = b
	c.height = h
	c.radial_segments = segs
	return c

static func _sph(r: float, h: float = -1.0, segs: int = 14) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0.0 else h
	s.radial_segments = segs
	s.rings = 8
	return s

## Eliminates giant overlapping Label3D billboard pile-ups down the horizon.
## Applies distance fade-out, depth testing, and restrained readable scale.
static func apply_label3d_culling(root: Node, max_dist: float = 15.0, fade_margin: float = 4.0) -> void:
	if root == null or not is_instance_valid(root):
		return
	var labels := root.find_children("*", "Label3D", true, false)
	for n in labels:
		var lab := n as Label3D
		if lab == null:
			continue
		lab.no_depth_test = false
		lab.fixed_size = false
		if lab.pixel_size > 0.0085:
			lab.pixel_size = 0.0075
		if lab.font_size > 44:
			lab.font_size = 38
		lab.outline_size = maxi(lab.outline_size, 6)
		lab.visibility_range_end = max_dist
		lab.visibility_range_end_margin = fade_margin
		lab.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

## Replaces flat shipping-container cottage roofs & bare walls with a storybook crooked-gable
## cottage: pitched gable roof, eaves, timber framing, stone plinth, glowing paned windows
## with shutters & flower boxes, porch awning, crooked chimney, and subtle stitch seams.
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
	# Hide the old flat 0.35m BoxMesh roof slab if present
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

	# 1. Stone plinth foundation skirt
	_mi(trim_root, _box(Vector3(full_w + 0.55, 0.42, full_d + 0.55)), stone_mat, Vector3(0, 0.21, 0))

	# 2. Half-timbered corner posts & horizontal eaves/mid beams
	for sx in [-1.0, 1.0]:
		var px: float = float(sx) * (half_w + 0.08)
		for sz in [-1.0, 1.0]:
			var pz: float = float(sz) * (half_d + 0.08)
			_mi(trim_root, _box(Vector3(0.26, wall_h + 0.1, 0.26)), timber_mat, Vector3(px, wall_h * 0.5, pz))

	# Horizontal timber belt + top frieze
	for bh in [wall_h * 0.52, wall_h - 0.12]:
		var by: float = float(bh)
		_mi(trim_root, _box(Vector3(full_w + 0.34, 0.18, 0.20)), timber_mat, Vector3(0, by, half_d + 0.12))
		_mi(trim_root, _box(Vector3(full_w + 0.34, 0.18, 0.20)), timber_mat, Vector3(0, by, -half_d - 0.12))
		_mi(trim_root, _box(Vector3(0.20, 0.18, full_d + 0.34)), timber_mat, Vector3(-half_w - 0.12, by, 0))
		_mi(trim_root, _box(Vector3(0.20, 0.18, full_d + 0.34)), timber_mat, Vector3(half_w + 0.12, by, 0))

	# 3. Steep Pitched Storybook Gable Roof (Prism gable wall + overhanging pitched roof planes)
	var roof_h := 2.75 if not is_hall else 3.4
	var gable := PrismMesh.new()
	gable.left_to_right = 0.5
	gable.size = Vector3(full_w + 0.28, roof_h, full_d + 0.16)
	_mi(trim_root, gable, _mat(wall_col.darkened(0.06), 0.85), Vector3(0, wall_h + roof_h * 0.5, 0))

	# Two overhanging pitched roof slabs along left and right slopes
	var slope_len := sqrt((half_w + 0.85) * (half_w + 0.85) + (roof_h + 0.15) * (roof_h + 0.15))
	var slope_ang := rad_to_deg(atan2(roof_h, half_w + 0.15))
	var roof_z := full_d + 1.45
	var mid_x := (half_w + 0.42) * 0.5
	var mid_y := wall_h + roof_h * 0.5 + 0.08
	_mi(trim_root, _box(Vector3(slope_len, 0.24, roof_z)), roof_mat, Vector3(-mid_x, mid_y, 0), Vector3(0, 0, slope_ang))
	_mi(trim_root, _box(Vector3(slope_len, 0.24, roof_z)), roof_mat, Vector3(mid_x, mid_y, 0), Vector3(0, 0, -slope_ang))

	# Ornate Ridge Beam & Gable Finials
	_mi(trim_root, _box(Vector3(0.28, 0.28, roof_z + 0.2)), ridge_mat, Vector3(0, wall_h + roof_h + 0.14, 0))
	for fz in [-1.0, 1.0]:
		var fpos := Vector3(0, wall_h + roof_h + 0.45, float(fz) * (roof_z * 0.5 + 0.05))
		_mi(trim_root, _cyl(0.03, 0.08, 0.65, 8), ridge_mat, fpos)

	# 4. Crooked Storybook Brick Chimney
	var chim_x := half_w * 0.52
	var chim_z := -half_d * 0.35
	var chim_mat := _mat(Color(0.46, 0.24, 0.22), 0.90)
	_mi(trim_root, _box(Vector3(0.75, roof_h + 1.2, 0.75)), chim_mat, Vector3(chim_x, wall_h + roof_h * 0.55, chim_z), Vector3(0, 0, -4.5))
	_mi(trim_root, _box(Vector3(0.95, 0.22, 0.95)), stone_mat, Vector3(chim_x + 0.1, wall_h + roof_h + 0.62, chim_z), Vector3(0, 0, -4.5))

	# 5. Front Porch Awning, Turned Posts & Entry Step (clear of DoorSeal collider)
	var porch_z := half_d + 0.75
	_mi(trim_root, _box(Vector3(2.4, 0.16, 1.35)), stone_mat, Vector3(0, 0.08, porch_z))
	_mi(trim_root, _box(Vector3(2.55, 0.18, 1.45)), roof_mat, Vector3(0, 2.58, porch_z), Vector3(14, 0, 0))
	for px_sign in [-1.0, 1.0]:
		_mi(trim_root, _cyl(0.08, 0.10, 2.45, 8), timber_mat, Vector3(float(px_sign) * 1.12, 1.28, half_d + 1.25))

	# 6. Glowing Paned Windows + Shutters + Flower Boxes (front flanks & side walls)
	for wx_sign in [-1.0, 1.0]:
		var wx: float = float(wx_sign) * (half_w * 0.56)
		_add_window(trim_root, Vector3(wx, 1.95, half_d + 0.17), 0.0, window_glow, timber_mat, shutter_mat, flower_pink, flower_gold)
	for side_sign in [-1.0, 1.0]:
		var sx: float = float(side_sign) * (half_w + 0.17)
		var rot_y: float = 90.0 if side_sign > 0.0 else -90.0
		_add_window(trim_root, Vector3(sx, 1.95, 0.0), rot_y, window_glow, timber_mat, shutter_mat, flower_pink, flower_gold)

	# 7. Subtle "Alice: Madness Returns" corruption stitches on the rear/back wall
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

	# Glowing glass pane + timber frame + cross mullions
	_mi(wroot, _box(Vector3(0.95, 1.05, 0.06)), glow_mat, Vector3.ZERO)
	_mi(wroot, _box(Vector3(1.12, 0.12, 0.12)), frame_mat, Vector3(0, 0.56, 0.02))
	_mi(wroot, _box(Vector3(1.16, 0.14, 0.18)), frame_mat, Vector3(0, -0.56, 0.04))
	_mi(wroot, _box(Vector3(0.08, 1.05, 0.10)), frame_mat, Vector3(0, 0, 0.04))
	_mi(wroot, _box(Vector3(0.95, 0.08, 0.10)), frame_mat, Vector3(0, 0.06, 0.04))

	# Wooden shutters on both sides
	_mi(wroot, _box(Vector3(0.36, 1.04, 0.08)), shutter_mat, Vector3(-0.72, 0, 0.03), Vector3(0, 12, 0))
	_mi(wroot, _box(Vector3(0.36, 1.04, 0.08)), shutter_mat, Vector3(0.72, 0, 0.03), Vector3(0, -12, 0))

	# Flower box below sill
	_mi(wroot, _box(Vector3(1.05, 0.22, 0.26)), frame_mat, Vector3(0, -0.72, 0.12))
	_mi(wroot, _sph(0.11, 0.16, 8), fl1, Vector3(-0.30, -0.56, 0.14))
	_mi(wroot, _sph(0.12, 0.16, 8), fl2, Vector3(0.0, -0.55, 0.16))
	_mi(wroot, _sph(0.11, 0.16, 8), fl1, Vector3(0.30, -0.56, 0.14))

## Sculpted storybook gnarled tree with flared roots, tilted trunk, branches, and 4-5 layered canopy clusters.
static func make_gnarled_tree(at: Vector3, rng: RandomNumberGenerator, scale_mult: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.scale = Vector3.ONE * scale_mult

	var bark := _mat(Color(0.26, 0.17, 0.12).lerp(Color(0.18, 0.13, 0.14), rng.randf() * 0.45), 0.94)
	var th := rng.randf_range(2.2, 3.6)
	var lean_x := rng.randf_range(-7.0, 7.0)
	var lean_z := rng.randf_range(-7.0, 7.0)

	# Flared base roots
	for r_i in range(4):
		var ang := float(r_i) * PI * 0.5 + rng.randf_range(-0.3, 0.3)
		var rpos := Vector3(cos(ang) * 0.32, 0.24, sin(ang) * 0.32)
		_mi(root, _cyl(0.06, 0.16, 0.7, 7), bark, rpos, Vector3(sin(ang) * 35.0, 0, -cos(ang) * 35.0))

	# Main tapered trunk
	_mi(root, _cyl(0.16, 0.30, th, 9), bark, Vector3(0, th * 0.5, 0), Vector3(lean_x, 0, lean_z))

	# 3 Spreading limbs + layered organic foliage clusters
	var base_leaf := Color(0.16, 0.42, 0.26).lerp(Color(0.28, 0.52, 0.22), rng.randf())
	var hi_leaf := base_leaf.lightened(0.16)
	var dark_leaf := base_leaf.darkened(0.22)

	var top_p := Vector3(0, th, 0)
	_mi(root, _sph(rng.randf_range(1.15, 1.55), rng.randf_range(1.7, 2.2), 12), _mat(base_leaf, 0.88), top_p + Vector3(0, 0.55, 0))

	for b_i in range(3):
		var bang := float(b_i) * (TAU / 3.0) + rng.randf_range(-0.35, 0.35)
		var bdir := Vector3(cos(bang), 0.55, sin(bang)).normalized()
		var blen := rng.randf_range(1.1, 1.7)
		var bmid := top_p + Vector3(0, -0.35, 0) + bdir * (blen * 0.5)
		_mi(root, _cyl(0.06, 0.12, blen, 7), bark, bmid, Vector3(sin(bang) * 42.0, 0, -cos(bang) * 42.0))

		var tip := top_p + Vector3(0, -0.25, 0) + bdir * blen
		var lmat := _mat(hi_leaf if b_i == 0 else (dark_leaf if b_i == 2 else base_leaf), 0.88)
		var cr := rng.randf_range(0.85, 1.25)
		_mi(root, _sph(cr, cr * 1.45, 10), lmat, tip)

	return root

## Ornate crooked wrought-iron & brass storybook street lantern for the Yellow Brick Road.
static func make_street_lantern(at: Vector3, glow_col: Color = Color(1.0, 0.86, 0.45), with_light: bool = false) -> Node3D:
	var root := Node3D.new()
	root.position = at

	var iron := _mat(Color(0.14, 0.13, 0.16), 0.52, 0.72)
	var brass := _mat(Color(0.78, 0.62, 0.28), 0.34, 0.82)
	var glass := _mat(glow_col, 0.2, 0.0, glow_col, 1.8)

	# Stone/iron plinth + fluted pole
	_mi(root, _cyl(0.18, 0.24, 0.45, 8), iron, Vector3(0, 0.22, 0))
	_mi(root, _cyl(0.055, 0.085, 3.1, 8), iron, Vector3(0, 1.85, 0), Vector3(0, 0, 2.5))
	_mi(root, _cyl(0.11, 0.11, 0.12, 8), brass, Vector3(0.04, 2.85, 0))

	# Curved gooseneck bracket arm
	_mi(root, _box(Vector3(0.75, 0.06, 0.06)), iron, Vector3(0.36, 3.38, 0), Vector3(0, 0, -8.0))
	# Lantern cap & glowing glass cage
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

## Rolling distant storybook hill berms outside the map rim so the ground never cuts
## sharply into a flat empty horizon.
static func add_horizon_hills(parent: Node3D, half_x: float, half_z: float, hill_col: Color) -> void:
	var hroot := Node3D.new()
	hroot.name = "HorizonHills"
	parent.add_child(hroot)

	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var m_near := _mat(hill_col, 0.94)
	var m_far := _mat(hill_col.darkened(0.24), 0.96)

	for i in range(28):
		var ang := float(i) / 28.0 * TAU
		var rx := (half_x + 18.0 + rng.randf_range(0.0, 22.0)) * cos(ang)
		var rz := (half_z + 18.0 + rng.randf_range(0.0, 22.0)) * sin(ang)
		var rad := rng.randf_range(24.0, 44.0)
		var ht := rng.randf_range(12.0, 26.0)
		var mat := m_near if i % 2 == 0 else m_far
		_mi(hroot, _sph(rad, ht, 14), mat, Vector3(rx, -ht * 0.18, rz), Vector3.ZERO, Vector3(1.3, 0.65, 1.3))

## Adds beveled gold curb stones & alternating storybook street lanterns along the YBR spine.
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
		# Alternating crooked street lanterns every 22m
		if idx % 5 == 0:
			var side: float = -1.0 if (idx / 5) % 2 == 0 else 1.0
			var lpos := Vector3(side * (road_half_w + 1.15), 0.0, z)
			var lantern := make_street_lantern(lpos, Color(1.0, 0.88, 0.52), idx % 10 == 0)
			lantern.rotation_degrees.y = 0.0 if side < 0.0 else 180.0
			yroot.add_child(lantern)
		z += 4.2
		idx += 1

## Sculpted Good Witch of the North (Locasta) visual — layered starlight gown, capelet,
## silver hair, filigree star crown, and glowing crystal wand.
static func build_locasta_visual(parent: Node3D) -> void:
	var gown := _mat(Color(0.88, 0.92, 0.99), 0.45, 0.08, Color(0.55, 0.65, 0.90), 0.18)
	var trim := _mat(Color(0.96, 0.84, 0.45), 0.28, 0.82, Color(0.95, 0.80, 0.35), 0.25)
	var cape := _mat(Color(0.76, 0.84, 0.98), 0.55, 0.05)
	var skin := _mat(Color(0.95, 0.82, 0.74), 0.48)
	var hair := _mat(Color(0.86, 0.88, 0.94), 0.60, 0.12)
	var eye := _mat(Color(0.24, 0.46, 0.78), 0.22)
	var crystal := _mat(Color(1.0, 0.95, 0.65), 0.12, 0.2, Color(1.0, 0.92, 0.55), 1.8)

	# Layered flowing gown + gold trim bands
	_mi(parent, _cyl(0.24, 0.66, 1.05, 16), gown, Vector3(0, 0.52, 0))
	_mi(parent, _cyl(0.65, 0.68, 0.07, 16), trim, Vector3(0, 0.06, 0))
	_mi(parent, _cyl(0.20, 0.38, 0.34, 14), cape, Vector3(0, 0.94, 0)) # peplum skirt
	# Sculpted bodice + silver-gold sash
	_mi(parent, _cyl(0.19, 0.16, 0.42, 14), gown, Vector3(0, 1.24, 0))
	_mi(parent, _cyl(0.17, 0.18, 0.08, 14), trim, Vector3(0, 1.06, 0))
	# Flowing shoulder mantle / capelet
	_mi(parent, _cyl(0.16, 0.42, 0.46, 12), cape, Vector3(0, 1.26, 0.06), Vector3(8, 0, 0))

	# Arms & Crystalline Star Wand
	for sx in [-1.0, 1.0]:
		var s: float = float(sx)
		_mi(parent, _cyl(0.06, 0.05, 0.48, 10), gown, Vector3(s * 0.26, 1.22, -0.05), Vector3(18, 0, -s * 18))
		_mi(parent, _sph(0.045, 0.09, 8), skin, Vector3(s * 0.32, 0.98, -0.14))
	# Wand in right hand
	_mi(parent, _cyl(0.018, 0.024, 1.35, 8), trim, Vector3(0.36, 1.12, -0.22), Vector3(10, 0, -6))
	_mi(parent, _sph(0.09, 0.18, 10), crystal, Vector3(0.42, 1.80, -0.32))

	# Head, serene face, silver hair & filigree star crown
	_mi(parent, _sph(0.155, 0.33, 14), skin, Vector3(0, 1.62, 0))
	_mi(parent, _sph(0.168, 0.32, 14), hair, Vector3(0, 1.66, 0.03))
	_mi(parent, _cyl(0.08, 0.12, 0.42, 10), hair, Vector3(0, 1.42, 0.11), Vector3(14, 0, 0))
	for ex in [-0.055, 0.055]:
		_mi(parent, _sph(0.022, 0.044, 8), eye, Vector3(float(ex), 1.64, -0.135))

	# Filigree Crown circlet + 5 star spires
	_mi(parent, _cyl(0.16, 0.16, 0.06, 14), trim, Vector3(0, 1.77, 0))
	for i in range(5):
		var a := float(i) / 5.0 * TAU
		var spire_h := 0.22 if i == 0 else 0.14
		_mi(parent, _cyl(0.01, 0.04, spire_h, 6), trim, Vector3(sin(a) * 0.14, 1.80 + spire_h * 0.5, -cos(a) * 0.14))
	_mi(parent, _sph(0.055, 0.11, 10), crystal, Vector3(0, 2.05, -0.14))
