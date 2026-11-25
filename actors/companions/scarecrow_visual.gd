extends Node3D

## 2026 Flagship Character — The Scarecrow ("The Unbound Mind")
## Matches char_01_scarecrow.jpg & Boutique Couture (scarecrow_classic, scarecrow_leather, scarecrow_obsidian).
## Woven burlap shader, cross-stitched button eyes & multi-stitch grin, physics-swaying bent witch hat
## with brass gear badge & raven feather, articulated multi-joint limbs & fingers, gnarled staff with
## swinging brass key, split swallowtail coat physics, and whimsical tip-hat flourish.

@export var outfit_id: String = "scarecrow_classic"

static var _burlap_shader: Shader = null
static var _crow_velvet_shader: Shader = null

var _hip: Node3D
var _torso: Node3D
var _coat_piv: Node3D
var _head: Node3D
var _hat_piv: Node3D
var _hat_peak: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _key_piv: Node3D

var _phase: float = 0.0
var _idle_t: float = 0.0
var _still_t: float = 0.0
var _speed_amt: float = 0.0
var _caw_t: float = 0.0
var _flourish_t: float = 0.0
var _next_flourish: float = 6.2
var _air_vy: float = 0.0
var _on_floor: bool = true
var _land_squash: float = 0.0
var _turn_rate: float = 0.0
var _sway_x: float = 0.0
var _sway_z: float = 0.0

const CAW_DUR := 0.48
const FLOURISH_DUR := 0.78

func _ready() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm and "equipped_outfits" in sm:
		var eq: String = str(sm.equipped_outfits.get("scarecrow", ""))
		if eq != "":
			outfit_id = eq
	_rebuild_character()

func set_outfit(new_outfit_id: String) -> void:
	var clean_id := new_outfit_id.strip_edges()
	if clean_id == "":
		clean_id = "scarecrow_classic"
	outfit_id = clean_id
	_rebuild_character()

func _rebuild_character() -> void:
	for c in get_children():
		c.free()
	_build()
	_apply_pose(0.016)

func play_caw() -> void:
	_caw_t = CAW_DUR
	_still_t = 0.0

func play_flourish() -> void:
	_flourish_t = FLOURISH_DUR
	_still_t = 0.0

func set_airborne(vel_y: float, floor_flag: bool, turn_vel: float = 0.0) -> void:
	if not _on_floor and floor_flag and _air_vy < -3.5:
		_land_squash = clampf(-_air_vy / 15.0, 0.12, 0.42)
	_air_vy = vel_y
	_on_floor = floor_flag
	_turn_rate = clampf(turn_vel, -8.0, 8.0)

func set_locomotion(horizontal_speed: float, delta: float) -> void:
	_idle_t += delta
	_caw_t = maxf(_caw_t - delta, 0.0)
	_flourish_t = maxf(_flourish_t - delta, 0.0)
	_land_squash = move_toward(_land_squash, 0.0, delta * 3.0)
	_speed_amt = clampf(horizontal_speed / 4.5, 0.0, 1.45)
	if _speed_amt > 0.08:
		_phase += delta * (7.8 + _speed_amt * 5.6)
		_still_t = 0.0
	else:
		_phase = move_toward(_phase, 0.0, delta * 4.5)
		_speed_amt = move_toward(_speed_amt, 0.0, delta * 3.6)
		if _on_floor and _caw_t <= 0.0:
			_still_t += delta
			if _still_t >= _next_flourish:
				_still_t = 0.0
				_next_flourish = randf_range(7.0, 11.5)
				_flourish_t = FLOURISH_DUR
	_apply_pose(delta)

func _apply_pose(delta: float = 0.016) -> void:
	if _leg_l == null or _hip == null:
		return

	# Priority 1: Dramatic Crow-Scatter Staff Slam & Arms-Wide Caw!
	if _caw_t > 0.0:
		var u := clampf(1.0 - (_caw_t / CAW_DUR), 0.0, 1.0)
		var arc := sin(u * PI)
		_hip.position.y = 0.82 + 0.11 * arc
		_hip.rotation = Vector3(-0.10 * arc, sin(u * TAU) * 0.24, 0.0)
		_torso.rotation = Vector3(-0.24 * arc, 0.0, sin(u * PI * 2.0) * 0.14)
		_arm_l.rotation = Vector3(-0.62 * arc, 0.0, -1.42 * arc)
		_arm_r.rotation = Vector3(-0.78 * arc, 0.0, 1.32 * arc)
		_set_forearm(_arm_l, -0.25 * arc)
		_set_forearm(_arm_r, -0.35 * arc)
		_leg_l.rotation = Vector3(-0.18 * arc, 0.0, -0.14 * arc)
		_leg_r.rotation = Vector3(0.18 * arc, 0.0, 0.14 * arc)
		if _head:
			_head.rotation = Vector3(0.45 * arc, sin(u * TAU) * 0.22, 0.14 * arc)
		_update_secondary_physics(delta, 1.65)
		return

	# Priority 2: Airborne Loose-Limbed Straw Float Pose
	if not _on_floor and absf(_air_vy) > 1.2:
		_hip.position.y = 0.84
		_hip.rotation = Vector3.ZERO
		_torso.rotation = Vector3(-0.14, 0.0, sin(_idle_t * 6.0) * 0.08)
		_leg_l.rotation = Vector3(-0.46, 0.0, -0.12)
		_leg_r.rotation = Vector3(0.32, 0.0, 0.12)
		_set_calf(_leg_l, 0.72)
		_set_calf(_leg_r, 0.56)
		_arm_l.rotation = Vector3(-0.45, 0.0, -0.82)
		_arm_r.rotation = Vector3(-0.35, 0.0, 0.75)
		_update_secondary_physics(delta, 1.25)
		return

	# Priority 3: Whimsical Hat-Tip & Jaunty Head-Tilt Flourish!
	if _flourish_t > 0.0:
		var fu := 1.0 - (_flourish_t / FLOURISH_DUR)
		var farc := sin(fu * PI)
		_hip.position.y = 0.82 + 0.02 * farc
		_hip.rotation = Vector3(0.0, 0.14 * farc, 0.0)
		_torso.rotation = Vector3(-0.08 * farc, -0.12 * farc, 0.09 * farc)
		_arm_l.rotation = Vector3(-1.85 * farc, 0.25 * farc, -0.28 * farc) # left hand tips hat brim!
		_set_forearm(_arm_l, -0.95 * farc)
		_arm_r.rotation = Vector3(-0.18 * farc, 0.0, 0.34 * farc) # right hand leans on gnarled staff
		_set_forearm(_arm_r, -0.28 * farc)
		if _head:
			_head.rotation = Vector3(-0.16 * farc, 0.18 * farc, -0.18 * farc)
		_update_secondary_physics(delta, 0.55)
		return

	# Jaunty, loose-limbed Scarecrow stride + breathing idle
	var squash := _land_squash * 0.12
	var swing := sin(_phase) * 0.64 * _speed_amt
	var swing_a := sin(_phase + PI) * 0.60 * _speed_amt
	var still_blend := 1.0 - clampf(_speed_amt, 0.0, 1.0)

	_hip.rotation = Vector3(0.0, sin(_phase) * 0.10 * _speed_amt, sin(_phase) * 0.04 * _speed_amt)
	_hip.position.y = 0.82 - squash + absf(sin(_phase)) * 0.042 * _speed_amt + sin(_idle_t * 2.1) * 0.012 * still_blend
	_torso.rotation = Vector3(
		-0.14 * clampf(_speed_amt - 0.2, 0.0, 1.0) + _land_squash * 0.22,
		-sin(_phase) * 0.11 * _speed_amt,
		sin(_phase) * 0.07 * _speed_amt - _turn_rate * 0.028
	)

	_leg_l.rotation = Vector3(swing - _land_squash * 0.32, 0.0, -0.04)
	_leg_r.rotation = Vector3(-swing - _land_squash * 0.32, 0.0, 0.04)
	_set_calf(_leg_l, maxf(-swing, 0.0) * 0.85 + 0.08 * _speed_amt + _land_squash * 0.65)
	_set_calf(_leg_r, maxf(swing, 0.0) * 0.85 + 0.08 * _speed_amt + _land_squash * 0.65)

	_arm_l.rotation = Vector3(-swing_a * 0.95, 0.0, -0.24 - 0.08 * _speed_amt + sin(_idle_t * 2.0) * 0.04 * still_blend)
	_arm_r.rotation = Vector3(swing_a * 0.55 - 0.12 * still_blend, 0.0, 0.22 + 0.06 * _speed_amt)
	_set_forearm(_arm_l, -0.28 - maxf(-swing_a, 0.0) * 0.45)
	_set_forearm(_arm_r, -0.34 - maxf(swing_a, 0.0) * 0.28)

	if _head:
		_head.rotation = Vector3(
			sin(_idle_t * 1.3) * 0.05 * still_blend,
			sin(_idle_t * 0.85) * 0.14 * still_blend - _turn_rate * 0.03,
			sin(_idle_t * 1.65) * 0.11 * still_blend + sin(_phase) * 0.06 * _speed_amt
		)

	_update_secondary_physics(delta, _speed_amt)

func _update_secondary_physics(delta: float, energy: float) -> void:
	var tx := clampf(energy * 0.26 + maxf(-_air_vy, 0.0) * 0.05, -0.25, 0.62)
	var tz := clampf(_turn_rate * 0.09 + sin(_phase) * 0.10 * _speed_amt, -0.45, 0.45)
	_sway_x = lerpf(_sway_x, tx, clampf(delta * 9.0, 0.0, 1.0))
	_sway_z = lerpf(_sway_z, tz, clampf(delta * 9.0, 0.0, 1.0))

	if _hat_peak:
		_hat_peak.rotation.x = -0.22 + _sway_x * 0.55 + sin(_idle_t * 2.6) * 0.04
		_hat_peak.rotation.z = 0.26 + _sway_z * 0.65
	if _coat_piv:
		var flare := clampf(energy * 0.12 + absf(_turn_rate) * 0.03, 0.0, 0.28)
		_coat_piv.scale = Vector3(1.0 + flare, 1.0, 1.0 + flare)
		_coat_piv.rotation.x = _sway_x * 0.42
		_coat_piv.rotation.z = -_sway_z * 0.38
	if _key_piv:
		_key_piv.rotation.z = sin(_idle_t * 3.4 + _phase) * (0.14 + energy * 0.35) + _sway_z * 0.55
		_key_piv.rotation.x = _sway_x * 0.45

func _set_calf(leg: Node3D, rx: float) -> void:
	if leg and leg.has_node("Thigh/Calf"):
		(leg.get_node("Thigh/Calf") as Node3D).rotation.x = rx

func _set_forearm(arm: Node3D, rx: float) -> void:
	if arm and arm.has_node("Upper/Lower"):
		(arm.get_node("Upper/Lower") as Node3D).rotation.x = rx

# ============================================================================
# MATERIAL & PRIMITIVE HELPERS
# ============================================================================

func _mat(
	c: Color,
	rough: float = 0.85,
	metal: float = 0.0,
	emit_col: Color = Color.BLACK,
	emit_e: float = 0.0,
	rim_amt: float = 0.22
) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if rim_amt > 0.01:
		m.rim_enabled = true
		m.rim = rim_amt
		m.rim_tint = 0.40
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit_col
		m.emission_energy_multiplier = emit_e
	return m

func _mi(p: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl := Vector3.ONE, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	n.rotation_degrees = rot_deg
	n.scale = scl
	p.add_child(n)
	return n

func _cyl(t: float, b: float, h: float, segs: int = 22) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = t
	c.bottom_radius = b
	c.height = h
	c.radial_segments = segs
	return c

func _sph(r: float, segs: int = 20, rings_n: int = 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = rings_n
	return s

func _cap(r: float, h: float, segs: int = 16) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.02)
	c.radial_segments = segs
	return c

func _torus(ir: float, orad: float, rings_n: int = 20) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = ir
	t.outer_radius = orad
	t.rings = rings_n
	return t

# ============================================================================
# 2026 SCARECROW GEOMETRY & 3 COUTURE BUILDS
# ============================================================================

func _build() -> void:
	var is_leather := (outfit_id == "scarecrow_leather")
	var is_obsidian := (outfit_id == "scarecrow_obsidian")

	var burlap_head := _make_burlap_material(Color(0.76, 0.62, 0.39), Color(0.54, 0.42, 0.25))
	var coat_mat: Material
	var patch_a: Material
	var patch_b: Material
	var hat_mat: Material
	var pant_mat: Material
	var rope_mat: Material
	var leather_mat: Material
	var feather_mat: Material
	var brass_mat := _mat(Color(0.88, 0.70, 0.30), 0.28, 0.88, Color(0.80, 0.60, 0.20), 0.12)
	var straw_mat := _mat(Color(0.88, 0.75, 0.42), 0.88, 0.0, Color.BLACK, 0.0, 0.35)
	var stitch_mat := _mat(Color(0.16, 0.10, 0.08), 0.75)
	var btn_eye_mat := _mat(Color(0.11, 0.08, 0.07), 0.34, 0.15)
	var wood_mat := _mat(Color(0.32, 0.20, 0.12), 0.80)

	if is_obsidian:
		# Obsidian Crowmaster (scarecrow_obsidian.png)
		coat_mat = _make_crow_velvet_material(Color(0.10, 0.08, 0.16), Color(0.30, 0.22, 0.48))
		patch_a = _mat(Color(0.16, 0.14, 0.24), 0.55, 0.12, Color.BLACK, 0.0, 0.45)
		patch_b = _mat(Color(0.24, 0.16, 0.34), 0.48, 0.18)
		hat_mat = coat_mat
		pant_mat = _mat(Color(0.09, 0.08, 0.13), 0.74)
		rope_mat = _mat(Color(0.26, 0.22, 0.34), 0.55, 0.35)
		leather_mat = _mat(Color(0.08, 0.07, 0.10), 0.40, 0.15)
		feather_mat = _mat(Color(0.10, 0.12, 0.18), 0.34, 0.28, Color(0.16, 0.26, 0.32), 0.20, 0.65)
		btn_eye_mat = _mat(Color(0.68, 0.24, 0.96), 0.18, 0.20, Color(0.68, 0.24, 0.96), 1.45)
	elif is_leather:
		# Burlap & Leather
		coat_mat = _mat(Color(0.28, 0.17, 0.12), 0.48, 0.08, Color.BLACK, 0.0, 0.32)
		patch_a = _make_burlap_material(Color(0.64, 0.50, 0.32), Color(0.42, 0.32, 0.18))
		patch_b = _mat(Color(0.20, 0.13, 0.09), 0.42, 0.12)
		hat_mat = _mat(Color(0.20, 0.13, 0.09), 0.52)
		pant_mat = _mat(Color(0.22, 0.20, 0.18), 0.78)
		rope_mat = _mat(Color(0.24, 0.14, 0.09), 0.46)
		leather_mat = _mat(Color(0.18, 0.11, 0.08), 0.42, 0.10)
		feather_mat = _mat(Color(0.12, 0.11, 0.15), 0.45, 0.15)
	else:
		# Cornfield Straw (char_01_scarecrow.jpg)
		coat_mat = _make_burlap_material(Color(0.64, 0.48, 0.28), Color(0.44, 0.32, 0.18))
		patch_a = _mat(Color(0.36, 0.44, 0.32), 0.88)
		patch_b = _mat(Color(0.52, 0.34, 0.24), 0.88)
		hat_mat = _mat(Color(0.26, 0.22, 0.19), 0.84)
		pant_mat = _mat(Color(0.30, 0.32, 0.28), 0.86)
		rope_mat = _mat(Color(0.62, 0.48, 0.28), 0.88)
		leather_mat = _mat(Color(0.26, 0.16, 0.10), 0.56)
		feather_mat = _mat(Color(0.14, 0.13, 0.18), 0.42, 0.20)

	# ========================================================================
	# 1. HIP, CINCHED BELT & DYNAMIC SPLIT SWALLOWTAIL COAT RIG
	# ========================================================================
	_hip = Node3D.new()
	_hip.name = "Hip"
	_hip.position = Vector3(0, 0.82, 0)
	add_child(_hip)

	_mi(_hip, _cyl(0.145, 0.175, 0.15, 22), pant_mat, Vector3(0, -0.02, 0))
	# Cinched leather belt + sculpted brass buckle + side pouch
	_mi(_hip, _cyl(0.158, 0.165, 0.062, 24), leather_mat, Vector3(0, 0.055, 0))
	_mi(_hip, _torus(0.022, 0.036, 16), brass_mat, Vector3(0, 0.055, -0.168), Vector3(1.15, 0.88, 0.45), Vector3(90, 0, 0))
	_mi(_hip, _sph(0.058, 14, 10), leather_mat, Vector3(-0.165, -0.02, 0.02), Vector3(0.75, 1.15, 0.95)) # hip leather pouch

	# Dynamic Split Swallowtail Coat Tails (sways & flares with motion!)
	_coat_piv = Node3D.new()
	_coat_piv.name = "CoatTails"
	_coat_piv.position = Vector3(0, 0.03, 0)
	_hip.add_child(_coat_piv)
	for ci in range(7):
		var ca := lerpf(-2.15, 2.15, float(ci) / 6.0)
		var cx := sin(ca) * 0.185
		var cz := cos(ca) * 0.185
		var tail_len := 0.36 if absf(ca) < 1.0 else 0.30
		var flap := _mi(_coat_piv, _cap(0.052, tail_len, 12), coat_mat, Vector3(cx, -tail_len * 0.52, cz), Vector3(1.0, 1.0, 0.48))
		flap.rotation = Vector3(cos(ca) * 0.24, ca, -sin(ca) * 0.24)
		if is_obsidian:
			# Raven feather hem fringe along cloak edge!
			_mi(_coat_piv, _cap(0.018, 0.11, 8), feather_mat, Vector3(cx * 1.18, -tail_len * 0.98, cz * 1.18), Vector3(1.0, 1.0, 0.4), Vector3(cos(ca) * 28.0, rad_to_deg(ca), -sin(ca) * 28.0))

	# ========================================================================
	# 2. TORSO, ROPE HARNESS, PATCHWORK / FEATHER MANTLE & STRAW COLLAR
	# ========================================================================
	_torso = Node3D.new()
	_torso.name = "Torso"
	_torso.position = Vector3(0, 0.08, 0)
	_hip.add_child(_torso)

	_mi(_torso, _cyl(0.175, 0.142, 0.42, 24), coat_mat, Vector3(0, 0.22, 0))
	# Sculpted cloth patches & safety pin detail on chest/back
	_mi(_torso, _sph(0.065, 14, 10), patch_a, Vector3(0.095, 0.27, -0.135), Vector3(1.05, 1.15, 0.22), Vector3(0, 24, 8))
	_mi(_torso, _sph(0.058, 14, 10), patch_b, Vector3(-0.092, 0.18, 0.132), Vector3(1.0, 1.10, 0.22), Vector3(0, -20, -10))
	# Safety pin charm at hip
	_mi(_torso, _torus(0.014, 0.019, 12), brass_mat, Vector3(0.155, 0.08, -0.06), Vector3(0.7, 1.5, 0.4), Vector3(0, 65, 18))

	# Crossed hemp rope / leather chest harness (char_01_scarecrow.jpg!)
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		_mi(_torso, _cap(0.014, 0.46, 10), rope_mat, Vector3(0.0, 0.23, -0.158), Vector3.ONE, Vector3(0, 0, s * 36.0))
		_mi(_torso, _cap(0.014, 0.46, 10), rope_mat, Vector3(0.0, 0.23, 0.155), Vector3.ONE, Vector3(0, 0, s * 36.0))

	# Ruffled Collar / Obsidian Raven-Feather Shoulder Mantle + Amethyst Brooch!
	if is_obsidian:
		for fi in range(14):
			var fa := float(fi) / 14.0 * TAU
			_mi(_torso, _cap(0.028, 0.17, 10), feather_mat, Vector3(sin(fa) * 0.21, 0.39, cos(fa) * 0.18), Vector3(0.9, 1.0, 0.42), Vector3(cos(fa) * 52.0, rad_to_deg(fa), -sin(fa) * 52.0))
		# Glowing faceted Amethyst-Violet Crowmaster Brooch (scarecrow_obsidian.png!)
		var gem_m := _mat(Color(0.72, 0.26, 1.0), 0.10, 0.25, Color(0.74, 0.28, 1.0), 2.4)
		var silv_m := _mat(Color(0.84, 0.88, 0.94), 0.22, 0.92)
		_mi(_torso, _sph(0.036, 14, 10), gem_m, Vector3(0, 0.37, -0.185), Vector3(0.75, 1.25, 0.55))
		for sx in [-1.0, 1.0]:
			_mi(_torso, _cap(0.016, 0.085, 8), silv_m, Vector3(float(sx) * 0.048, 0.375, -0.178), Vector3(1.0, 1.0, 0.4), Vector3(0, 0, float(sx) * -58.0))
	else:
		# Jagged burlap collar + knotted rope necktie + golden straw bursts
		_mi(_torso, _cyl(0.095, 0.225, 0.095, 22), coat_mat, Vector3(0, 0.415, 0))
		_mi(_torso, _torus(0.072, 0.092, 18), rope_mat, Vector3(0, 0.445, 0))
		for si in range(8):
			var sa := float(si) / 8.0 * TAU
			_mi(_torso, _cyl(0.006, 0.022, 0.14, 8), straw_mat, Vector3(cos(sa) * 0.145, 0.43, sin(sa) * 0.145), Vector3.ONE, Vector3(sin(sa) * 48.0, 0, -cos(sa) * 48.0))

	# ========================================================================
	# 3. SCULPTED SACK HEAD, BUTTON EYES, STITCHED GRIN & PHYSICS WITCH HAT
	# ========================================================================
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.49, 0)
	_torso.add_child(_head)

	# Contoured burlap sack head + tapered jaw
	_mi(_head, _sph(0.145, 24, 16), burlap_head, Vector3(0, 0.12, 0), Vector3(1.02, 1.12, 0.96))
	_mi(_head, _sph(0.105, 18, 12), burlap_head, Vector3(0, 0.055, -0.02), Vector3(0.95, 0.85, 0.90))

	# Cross-stitched leather button eyes (char_01_scarecrow.jpg!)
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		var ex := s * 0.054
		var ey := 0.142 if s < 0 else 0.134 # slight playful asymmetry!
		var ez := -0.132
		_mi(_head, _cyl(0.036, 0.036, 0.016, 18), btn_eye_mat, Vector3(ex, ey, ez), Vector3.ONE, Vector3(90, 0, 0))
		_mi(_head, _torus(0.028, 0.036, 16), stitch_mat, Vector3(ex, ey, ez - 0.006), Vector3.ONE, Vector3(90, 0, 0))
		# Diagonal X-stitch threads inside each button eye
		_mi(_head, _cap(0.0045, 0.044, 6), straw_mat, Vector3(ex, ey, ez - 0.010), Vector3.ONE, Vector3(0, 0, 45))
		_mi(_head, _cap(0.0045, 0.044, 6), straw_mat, Vector3(ex, ey, ez - 0.010), Vector3.ONE, Vector3(0, 0, -45))

	# Stitched triangular nose hollow
	_mi(_head, _cyl(0.004, 0.026, 0.042, 3), stitch_mat, Vector3(0, 0.102, -0.142), Vector3(1.0, 1.0, 0.35))

	# Curved multi-stitch grin (7 curved mouth segments + vertical cross-stitches!)
	for mi_i in range(-3, 4):
		var t := float(mi_i) / 3.0
		var mx := t * 0.088
		var my := 0.048 + t * t * 0.028
		var mz := -0.134 + absf(t) * 0.026
		_mi(_head, _cap(0.0045, 0.032, 6), stitch_mat, Vector3(mx, my, mz), Vector3.ONE, Vector3(0, t * -26.0, 90.0 - t * 22.0))
		_mi(_head, _cap(0.0038, 0.030, 6), stitch_mat, Vector3(mx, my, mz - 0.003), Vector3.ONE, Vector3(0, t * -26.0, t * 14.0))

	# Straw tufts bursting from both sides of head under hat brim
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		for ti in range(4):
			var ty := 0.05 + float(ti) * 0.036
			_mi(_head, _cyl(0.005, 0.018, 0.14, 8), straw_mat, Vector3(s * 0.145, ty, -0.02 + float(ti) * 0.02), Vector3.ONE, Vector3(float(ti) * 8.0, 0, -s * (58.0 - float(ti) * 8.0)))

	# Physics-Swaying Bent Witch-Farm Hat + Brass Gear Badge + Swept Raven Feather!
	_hat_piv = Node3D.new()
	_hat_piv.name = "HatPivot"
	_hat_piv.position = Vector3(0, 0.225, 0.01)
	_hat_piv.rotation_degrees = Vector3(-6, 0, 7)
	_head.add_child(_hat_piv)

	# Curved wide floppy brim + twisted hemp hatband + brass gear badge + raven feather
	_mi(_hat_piv, _cyl(0.32, 0.38, 0.026, 28), hat_mat, Vector3(0, 0.0, 0), Vector3(1.06, 1.0, 0.98))
	_mi(_hat_piv, _torus(0.145, 0.172, 22), rope_mat, Vector3(0, 0.028, 0))
	_mi(_hat_piv, _cyl(0.036, 0.036, 0.018, 12), brass_mat, Vector3(0.105, 0.042, -0.145), Vector3.ONE, Vector3(80, 0, -28))
	_mi(_hat_piv, _cap(0.018, 0.21, 10), feather_mat, Vector3(0.155, 0.135, -0.08), Vector3(0.85, 1.0, 0.30), Vector3(12, 24, -36))

	# Bent pointed crown peak (secondary physics pivot!)
	_hat_peak = Node3D.new()
	_hat_peak.name = "HatPeak"
	_hat_peak.position = Vector3(0, 0.04, 0)
	_hat_piv.add_child(_hat_peak)
	_mi(_hat_peak, _cyl(0.085, 0.165, 0.18, 22), hat_mat, Vector3(0, 0.085, 0))
	_mi(_hat_peak, _cyl(0.014, 0.085, 0.22, 18), hat_mat, Vector3(0.045, 0.24, 0.035), Vector3.ONE, Vector3(-24, 0, -28))

	# ========================================================================
	# 4. ARTICULATED ARMS, FINGERS, GNARLED STAFF + SWINGING KEY, AND LEGS
	# ========================================================================
	_arm_l = _make_arm(_torso, true, coat_mat, burlap_head, straw_mat, rope_mat)
	_arm_r = _make_arm(_torso, false, coat_mat, burlap_head, straw_mat, rope_mat)

	# Gnarled wooden walking staff + swinging antique brass skeleton key in right hand!
	var r_hand := _arm_r.get_node("Upper/Lower/Hand") as Node3D
	if r_hand:
		var staff_piv := Node3D.new()
		staff_piv.name = "GnarledStaff"
		staff_piv.position = Vector3(0.02, -0.02, -0.03)
		r_hand.add_child(staff_piv)
		_mi(staff_piv, _cyl(0.020, 0.025, 1.12, 14), wood_mat, Vector3(0, -0.14, 0))
		_mi(staff_piv, _torus(0.032, 0.052, 16), wood_mat, Vector3(0, 0.42, -0.02), Vector3(0.8, 1.1, 1.0), Vector3(0, 90, 22))
		_mi(staff_piv, _torus(0.024, 0.032, 12), rope_mat, Vector3(0, 0.22, 0))
		_key_piv = Node3D.new()
		_key_piv.name = "BrassKeyPivot"
		_key_piv.position = Vector3(0.025, 0.21, -0.025)
		staff_piv.add_child(_key_piv)
		_mi(_key_piv, _torus(0.012, 0.020, 12), brass_mat, Vector3(0, -0.035, 0), Vector3.ONE, Vector3(0, 90, 0))
		_mi(_key_piv, _cap(0.006, 0.075, 8), brass_mat, Vector3(0, -0.085, 0))
		_mi(_key_piv, _cap(0.005, 0.026, 6), brass_mat, Vector3(0, -0.105, -0.012), Vector3.ONE, Vector3(90, 0, 0))

	_leg_l = _make_leg(_hip, true, pant_mat, patch_a, leather_mat, straw_mat, rope_mat)
	_leg_r = _make_leg(_hip, false, pant_mat, patch_b, leather_mat, straw_mat, rope_mat)

func _make_arm(parent: Node3D, left: bool, cloth: Material, glove: Material, straw: Material, rope: Material) -> Node3D:
	var s := -1.0 if left else 1.0
	var root := Node3D.new()
	root.name = "ArmL" if left else "ArmR"
	root.position = Vector3(0.22 * s, 0.37, 0)
	parent.add_child(root)

	var upper := Node3D.new()
	upper.name = "Upper"
	root.add_child(upper)
	_mi(upper, _sph(0.062, 16, 12), cloth, Vector3(0, -0.02, 0))
	_mi(upper, _cap(0.048, 0.30, 16), cloth, Vector3(0, -0.15, 0))
	_mi(upper, _cyl(0.006, 0.018, 0.09, 6), straw, Vector3(s * 0.048, -0.08, 0), Vector3.ONE, Vector3(0, 0, -s * 68.0))

	var lower := Node3D.new()
	lower.name = "Lower"
	lower.position = Vector3(0, -0.28, 0)
	upper.add_child(lower)
	_mi(lower, _cyl(0.045, 0.036, 0.27, 16), cloth, Vector3(0, -0.135, 0))
	_mi(lower, _torus(0.034, 0.044, 14), rope, Vector3(0, -0.245, 0))
	for si in range(4):
		var sa := float(si) * PI * 0.5
		_mi(lower, _cyl(0.005, 0.014, 0.08, 6), straw, Vector3(cos(sa) * 0.036, -0.265, sin(sa) * 0.036), Vector3.ONE, Vector3(sin(sa) * 38.0, 0, -cos(sa) * 38.0))

	# Articulated Burlington/Gloved Hand + Thumb + 4 Fingers
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0, -0.285, 0)
	lower.add_child(hand)
	_mi(hand, _sph(0.030, 14, 10), glove, Vector3(0, -0.015, 0), Vector3(0.90, 1.12, 0.58))
	_mi(hand, _cap(0.008, 0.038, 8), glove, Vector3(-s * 0.024, -0.02, -0.012), Vector3.ONE, Vector3(24, 0, s * 34.0))
	for fi in range(4):
		var fx := (float(fi) - 1.5) * 0.011 * s
		_mi(hand, _cap(0.0065, 0.044, 8), glove, Vector3(fx, -0.046, -0.004), Vector3.ONE, Vector3(14, 0, 0))
	return root

func _make_leg(parent: Node3D, left: bool, pant: Material, patch: Material, boot: Material, straw: Material, rope: Material) -> Node3D:
	var s := -1.0 if left else 1.0
	var root := Node3D.new()
	root.name = "LegL" if left else "LegR"
	root.position = Vector3(0.105 * s, -0.09, 0)
	parent.add_child(root)

	var thigh := Node3D.new()
	thigh.name = "Thigh"
	root.add_child(thigh)
	_mi(thigh, _cyl(0.074, 0.058, 0.36, 18), pant, Vector3(0, -0.18, 0))
	_mi(thigh, _sph(0.052, 12, 10), patch, Vector3(0, -0.20, -0.048), Vector3(0.95, 1.15, 0.38)) # stitched knee patch

	var calf := Node3D.new()
	calf.name = "Calf"
	calf.position = Vector3(0, -0.36, 0)
	thigh.add_child(calf)
	_mi(calf, _cyl(0.056, 0.044, 0.34, 18), pant, Vector3(0, -0.17, 0))
	_mi(calf, _torus(0.044, 0.054, 14), rope, Vector3(0, -0.22, 0))
	for si in range(5):
		var sa := float(si) / 5.0 * TAU
		_mi(calf, _cyl(0.005, 0.016, 0.09, 6), straw, Vector3(cos(sa) * 0.048, -0.23, sin(sa) * 0.048), Vector3.ONE, Vector3(sin(sa) * 45.0, 0, -cos(sa) * 45.0))

	# Sculpted Curled-Toe Leather Boot (char_01_scarecrow.jpg inset!)
	var foot := Node3D.new()
	foot.name = "Boot"
	foot.position = Vector3(0, -0.34, 0)
	calf.add_child(foot)
	_mi(foot, _cyl(0.052, 0.054, 0.14, 16), boot, Vector3(0, 0.055, 0))
	_mi(foot, _sph(0.058, 16, 12), boot, Vector3(0, -0.020, -0.062), Vector3(0.92, 0.64, 1.72))
	_mi(foot, _sph(0.032, 12, 10), boot, Vector3(0, 0.006, -0.145), Vector3(0.88, 0.80, 1.20), Vector3(-28, 0, 0)) # upturned boot toe!
	return root

# ============================================================================
# COUTURE SPATIAL SHADERS
# ============================================================================

func _make_burlap_material(c_light: Color, c_dark: Color) -> ShaderMaterial:
	if _burlap_shader == null:
		_burlap_shader = Shader.new()
		_burlap_shader.code = """
shader_type spatial;
uniform vec4 col_light : source_color = vec4(0.72, 0.56, 0.34, 1.0);
uniform vec4 col_dark : source_color = vec4(0.46, 0.34, 0.20, 1.0);
void fragment() {
	float wx = sin(UV.x * 180.0);
	float wy = sin(UV.y * 180.0);
	float weave = clamp((wx * wy) * 0.35 + 0.5, 0.0, 1.0);
	ALBEDO = mix(col_dark.rgb, col_light.rgb, weave);
	ROUGHNESS = 0.90;
	RIM = 0.26;
	RIM_TINT = 0.32;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _burlap_shader
	sm.set_shader_parameter("col_light", c_light)
	sm.set_shader_parameter("col_dark", c_dark)
	return sm

func _make_crow_velvet_material(c_core: Color, c_rim: Color) -> ShaderMaterial:
	if _crow_velvet_shader == null:
		_crow_velvet_shader = Shader.new()
		_crow_velvet_shader.code = """
shader_type spatial;
uniform vec4 core_col : source_color = vec4(0.10, 0.08, 0.16, 1.0);
uniform vec4 rim_col : source_color = vec4(0.32, 0.24, 0.52, 1.0);
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	ALBEDO = mix(core_col.rgb, rim_col.rgb, f * 0.72);
	ROUGHNESS = mix(0.74, 0.34, f);
	RIM = 0.55;
	RIM_TINT = 0.65;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _crow_velvet_shader
	sm.set_shader_parameter("core_col", c_core)
	sm.set_shader_parameter("rim_col", c_rim)
	return sm
