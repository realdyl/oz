extends Node3D

## 2026 Flagship Character — The Tin Woodman ("The Clockwork Heart")
## Matches char_02_tin_woodman.jpg & Boutique Couture (tinman_classic, tinman_velvet).
## Anisotropic brushed-steel / oxidized-rust shader, glowing amber clockwork eyes & hinged jaw,
## living pulsing crimson Clockwork Heart inside a gilded filigree chest cage, spinning waist/elbow
## brass gears, twin steam exhaust tanks, articulated 4-finger gauntlets, sculpted crescent axe,
## 2-stage axe cleave choreography, and whimsical heart-tap idle flourish.

@export var outfit_id: String = "tinman_classic"

static var _tin_shader: Shader = null

var _hip: Node3D
var _torso: Node3D
var _head: Node3D
var _jaw: Node3D
var _heart_piv: Node3D
var _sash_tail: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _gears: Array[Node3D] = []

var _phase: float = 0.0
var _idle_t: float = 0.0
var _still_t: float = 0.0
var _speed_amt: float = 0.0
var _swing_t: float = 0.0
var _swing_step: int = 1
var _flourish_t: float = 0.0
var _next_flourish: float = 6.8
var _air_vy: float = 0.0
var _on_floor: bool = true
var _land_squash: float = 0.0
var _turn_rate: float = 0.0
var rusted: bool = false

const SWING_DUR := 0.44
const FLOURISH_DUR := 0.72

func _ready() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm and "equipped_outfits" in sm:
		var eq: String = str(sm.equipped_outfits.get("tinman", ""))
		if eq != "":
			outfit_id = eq
	_rebuild_character()

func set_outfit(new_outfit_id: String) -> void:
	var clean_id := new_outfit_id.strip_edges()
	if clean_id == "":
		clean_id = "tinman_classic"
	outfit_id = clean_id
	_rebuild_character()

func set_rusted(on: bool) -> void:
	rusted = on
	_rebuild_character()

func _rebuild_character() -> void:
	_gears.clear()
	for c in get_children():
		c.free()
	_build()
	_apply_pose(0.016)

func play_axe_swing(step: int = 1) -> void:
	if rusted:
		return
	_swing_step = clampi(step, 1, 2)
	_swing_t = SWING_DUR
	_still_t = 0.0

func play_flourish() -> void:
	if rusted:
		return
	_flourish_t = FLOURISH_DUR
	_still_t = 0.0

func set_airborne(vel_y: float, floor_flag: bool, turn_vel: float = 0.0) -> void:
	if not _on_floor and floor_flag and _air_vy < -3.5:
		_land_squash = clampf(-_air_vy / 15.0, 0.14, 0.40)
	_air_vy = vel_y
	_on_floor = floor_flag
	_turn_rate = clampf(turn_vel, -8.0, 8.0)

func set_locomotion(horizontal_speed: float, delta: float) -> void:
	_idle_t += delta
	_swing_t = maxf(_swing_t - delta, 0.0)
	_flourish_t = maxf(_flourish_t - delta, 0.0)
	_land_squash = move_toward(_land_squash, 0.0, delta * 3.0)
	if rusted:
		_speed_amt = 0.0
		_apply_pose(delta)
		return
	_speed_amt = clampf(horizontal_speed / 3.9, 0.0, 1.35)
	if _speed_amt > 0.08:
		_phase += delta * (6.4 + _speed_amt * 4.4)
		_still_t = 0.0
	else:
		_phase = move_toward(_phase, 0.0, delta * 3.8)
		_speed_amt = move_toward(_speed_amt, 0.0, delta * 3.4)
		if _on_floor and _swing_t <= 0.0:
			_still_t += delta
			if _still_t >= _next_flourish:
				_still_t = 0.0
				_next_flourish = randf_range(7.2, 11.8)
				_flourish_t = FLOURISH_DUR
	_apply_pose(delta)

func _apply_pose(delta: float = 0.016) -> void:
	if _leg_l == null or _hip == null:
		return

	# Living Clockwork Heartbeat + Spinning Brass Gears!
	if not rusted:
		var beat := pow(maxf(0.0, sin(_idle_t * 3.8)), 4.0)
		if _heart_piv:
			var hs := 1.0 + beat * 0.16
			_heart_piv.scale = Vector3(hs, hs, hs)
		var gear_spd := (1.8 + _speed_amt * 3.6 + (5.0 if _swing_t > 0.0 else 0.0)) * delta
		for gi in range(_gears.size()):
			var g := _gears[gi]
			if g:
				g.rotate_z(gear_spd * (1.0 if gi % 2 == 0 else -1.0))
	else:
		# Frozen mid-chop rusted statue pose!
		_hip.position = Vector3(0, 0.88, 0)
		_torso.rotation = Vector3(-0.08, 0.14, 0.05)
		_arm_r.rotation = Vector3(-1.25, 0.0, 0.35)
		_arm_l.rotation = Vector3(-0.55, 0.0, -0.22)
		return

	# Priority 1: 2-Stage Heavy Woodsman Axe Cleave!
	if _swing_t > 0.0:
		var u := clampf(1.0 - (_swing_t / SWING_DUR), 0.0, 1.0)
		var wind := sin(clampf(u * 2.2, 0.0, 1.0) * PI * 0.5)
		var chop := smoothstep(0.28, 0.66, u)
		var rec := 1.0 - smoothstep(0.68, 1.0, u)
		if _swing_step == 1:
			# Stage 1: Heavy Overhead Armor-Breaking Chop
			_hip.position.y = 0.88 + sin(u * PI) * 0.04
			_hip.rotation.y = lerpf(-0.32, 0.38, chop) * rec
			_torso.rotation = Vector3(lerpf(0.26, -0.34, chop) * rec, lerpf(-0.28, 0.32, chop) * rec, 0.0)
			_arm_r.rotation = Vector3(lerpf(-2.15 * wind, 1.38, chop) * rec, -0.18 * chop * rec, lerpf(0.45, -0.15, chop) * rec)
			_set_forearm(_arm_r, lerpf(-0.75, -0.15, chop) * rec)
			_arm_l.rotation = Vector3(-0.65 * rec, 0.25 * rec, -0.42 * rec)
		else:
			# Stage 2: Sweeping Horizontal Reverse Cleave
			_hip.position.y = 0.88 + sin(u * PI) * 0.03
			_hip.rotation.y = lerpf(0.55, -0.68, chop) * rec
			_torso.rotation = Vector3(-0.18 * rec, lerpf(0.42, -0.48, chop) * rec, 0.12 * rec)
			_arm_r.rotation = Vector3(-1.15 * rec, lerpf(0.75, -1.25, chop) * rec, 1.15 * rec)
			_set_forearm(_arm_r, -0.22 * rec)
			_arm_l.rotation = Vector3(-0.45 * rec, 0.0, -0.65 * rec)
		if _jaw:
			_jaw.rotation.x = 0.18 * sin(u * PI)
		return

	# Priority 2: Whimsical Clockwork Heart-Tap & Chest-Listen Flourish!
	if _flourish_t > 0.0:
		var fu := 1.0 - (_flourish_t / FLOURISH_DUR)
		var farc := sin(fu * PI)
		var tap := absf(sin(fu * PI * 4.0)) * farc
		_hip.position.y = 0.88
		_hip.rotation = Vector3.ZERO
		_torso.rotation = Vector3(-0.04 * farc, 0.08 * farc, 0.0)
		_arm_l.rotation = Vector3(-1.05 * farc - 0.12 * tap, 0.62 * farc, 0.18 * farc) # taps heart cage!
		_set_forearm(_arm_l, -1.25 * farc)
		_arm_r.rotation = Vector3(0.08 * farc, 0.0, 0.18 * farc)
		if _head:
			_head.rotation = Vector3(0.20 * farc, -0.12 * farc, 0.10 * farc)
		return

	# Weighty Armored March & Clockwork Idle
	var squash := _land_squash * 0.09
	var swing := sin(_phase) * 0.44 * _speed_amt
	var still_blend := 1.0 - clampf(_speed_amt, 0.0, 1.0)

	_hip.rotation = Vector3(0.0, sin(_phase) * 0.06 * _speed_amt, sin(_phase) * 0.035 * _speed_amt)
	_hip.position.y = 0.88 - squash + absf(sin(_phase)) * 0.024 * _speed_amt + sin(_idle_t * 2.2) * 0.008 * still_blend
	_torso.rotation = Vector3(
		-0.09 * clampf(_speed_amt - 0.2, 0.0, 1.0) + _land_squash * 0.14,
		-sin(_phase) * 0.07 * _speed_amt,
		- _turn_rate * 0.018
	)

	_leg_l.rotation = Vector3(swing - _land_squash * 0.25, 0.0, 0.0)
	_leg_r.rotation = Vector3(-swing - _land_squash * 0.25, 0.0, 0.0)
	_set_calf(_leg_l, maxf(-swing, 0.0) * 0.68 + 0.04 * _speed_amt + _land_squash * 0.50)
	_set_calf(_leg_r, maxf(swing, 0.0) * 0.68 + 0.04 * _speed_amt + _land_squash * 0.50)

	_arm_l.rotation = Vector3(-swing * 0.65, 0.0, -0.12)
	_arm_r.rotation = Vector3(swing * 0.45 - 0.15 * still_blend, 0.0, 0.14)
	_set_forearm(_arm_l, -0.22 - maxf(-swing, 0.0) * 0.30)
	_set_forearm(_arm_r, -0.32 - maxf(swing, 0.0) * 0.22)

	if _head:
		_head.rotation = Vector3(sin(_idle_t * 1.1) * 0.03 * still_blend, sin(_idle_t * 0.7) * 0.10 * still_blend - _turn_rate * 0.025, 0.0)
	if _jaw:
		_jaw.rotation.x = 0.0
	if _sash_tail:
		_sash_tail.rotation.x = 0.10 + _speed_amt * 0.28 + sin(_idle_t * 2.5) * 0.04

func _set_calf(leg: Node3D, rx: float) -> void:
	if leg and leg.has_node("Thigh/Calf"):
		(leg.get_node("Thigh/Calf") as Node3D).rotation.x = rx

func _set_forearm(arm: Node3D, rx: float) -> void:
	if arm and arm.has_node("Upper/Lower"):
		(arm.get_node("Upper/Lower") as Node3D).rotation.x = rx

# ============================================================================
# MATERIAL & PRIMITIVE HELPERS
# ============================================================================

func _mat(c: Color, metal: float = 0.85, rough: float = 0.30, emit_col: Color = Color.BLACK, emit_e: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
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

func _cyl(t: float, b: float, h: float, segs: int = 24) -> CylinderMesh:
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
# 2026 TIN WOODMAN GEOMETRY & COUTURE BUILDS
# ============================================================================

func _build() -> void:
	var is_velvet := (outfit_id == "tinman_velvet") and not rusted
	var tin: Material
	if rusted:
		tin = _make_tin_material(Color(0.46, 0.28, 0.16), Color(0.28, 0.18, 0.12), 0.35, 0.80)
	elif is_velvet:
		tin = _make_tin_material(Color(0.36, 0.40, 0.46), Color(0.18, 0.20, 0.26), 0.96, 0.18)
	else:
		tin = _make_tin_material(Color(0.74, 0.79, 0.85), Color(0.48, 0.54, 0.60), 0.92, 0.24)

	var dark_iron := _mat(Color(0.20, 0.22, 0.26), 0.80, 0.38)
	var brass := _mat(Color(0.88, 0.68, 0.28), 0.90, 0.24)
	var leather := _mat(Color(0.28, 0.16, 0.10), 0.08, 0.62)
	var wood := _mat(Color(0.36, 0.22, 0.13), 0.04, 0.82)
	var blade_steel := _mat(Color(0.84, 0.88, 0.94), 0.96, 0.16)
	var crimson_velvet := _mat(Color(0.56, 0.05, 0.12), 0.06, 0.72, Color(0.22, 0.02, 0.05), 0.15)
	var eye_mat := _mat(Color(1.0, 0.72, 0.22), 0.2, 0.15, Color(1.0, 0.68, 0.18), 1.9 if not rusted else 0.15)
	var heart_mat := _mat(Color(0.96, 0.14, 0.22), 0.15, 0.14, Color(1.0, 0.18, 0.24), 2.4 if not rusted else 0.10)

	# ========================================================================
	# 1. HIP, SEGMENTED TASSETS, LEATHER BELT & EXPOSED WAIST GEARS
	# ========================================================================
	_hip = Node3D.new()
	_hip.name = "Hip"
	_hip.position = Vector3(0, 0.88, 0)
	add_child(_hip)

	_mi(_hip, _cyl(0.185, 0.22, 0.20, 24), tin, Vector3(0, -0.04, 0))
	# Overlapping articulated lobster-tail armor tassets
	for ti in range(4):
		var ta := float(ti) * PI * 0.5 + PI * 0.25
		_mi(_hip, _sph(0.105, 16, 10), tin, Vector3(sin(ta) * 0.17, -0.10, cos(ta) * 0.16), Vector3(1.15, 0.95, 0.42), Vector3(cos(ta) * 16.0, rad_to_deg(ta), -sin(ta) * 16.0))
	# Leather belt + brass buckle + spinning exposed clockwork waist gears!
	_mi(_hip, _cyl(0.205, 0.212, 0.065, 24), leather, Vector3(0, 0.06, 0))
	_mi(_hip, _torus(0.024, 0.038, 16), brass, Vector3(0, 0.06, -0.215), Vector3(1.2, 0.88, 0.45), Vector3(90, 0, 0))
	for gx in [-0.08, 0.0, 0.08]:
		var gear := _make_gear(_hip, 0.042, brass, Vector3(float(gx), 0.135, 0.19))
		_gears.append(gear)

	# ========================================================================
	# 2. DOMED BOILER CUIRASS, FILIGREE CLOCKWORK HEART & STEAM TANKS
	# ========================================================================
	_torso = Node3D.new()
	_torso.name = "Torso"
	_torso.position = Vector3(0, 0.10, 0)
	_hip.add_child(_torso)

	_mi(_torso, _cyl(0.235, 0.188, 0.46, 28), tin, Vector3(0, 0.24, 0))
	_mi(_torso, _sph(0.245, 24, 14), tin, Vector3(0, 0.34, -0.02), Vector3(1.04, 0.78, 0.96)) # contoured chest dome
	_mi(_torso, _torus(0.185, 0.202, 24), brass, Vector3(0, 0.04, 0))
	_mi(_torso, _torus(0.228, 0.244, 24), brass, Vector3(0, 0.44, 0)) # gorget collar rim

	# Rivet studs across breastplate
	for sx in [-1.0, 1.0]:
		for ry in [0.16, 0.28, 0.40]:
			_mi(_torso, _sph(0.015, 10, 8), dark_iron, Vector3(float(sx) * 0.165, float(ry), -0.185))

	# Chrome & Crimson Velvet Couture Sash (tinman_royal.png!)
	if is_velvet:
		_mi(_torso, _torus(0.225, 0.268, 24), crimson_velvet, Vector3(0, 0.24, 0), Vector3(1.08, 0.55, 1.06), Vector3(12, 0, -42))
		_mi(_torso, _torus(0.222, 0.272, 24), brass, Vector3(0, 0.23, 0), Vector3(1.09, 0.14, 1.07), Vector3(12, 0, -42))
		_sash_tail = Node3D.new()
		_sash_tail.position = Vector3(0.21, 0.02, -0.02)
		_torso.add_child(_sash_tail)
		_mi(_sash_tail, _sph(0.052, 14, 10), crimson_velvet, Vector3.ZERO)
		_mi(_sash_tail, _cap(0.036, 0.34, 12), crimson_velvet, Vector3(0.02, -0.17, 0.01), Vector3(1.1, 1.0, 0.38))
		_mi(_sash_tail, _cyl(0.042, 0.048, 0.04, 12), brass, Vector3(0.02, -0.35, 0.01))

	# Living Pulsing Clockwork Heart inside Gilded Filigree Chest Cage (char_02 & tinman_royal!)
	_mi(_torso, _torus(0.088, 0.106, 20), brass, Vector3(0, 0.31, -0.222), Vector3(0.92, 1.08, 0.45), Vector3(90, 0, 0))
	_mi(_torso, _cyl(0.086, 0.086, 0.03, 20), dark_iron, Vector3(0, 0.31, -0.215), Vector3(0.92, 1.0, 1.08), Vector3(90, 0, 0))
	_heart_piv = Node3D.new()
	_heart_piv.name = "ClockworkHeart"
	_heart_piv.position = Vector3(0, 0.31, -0.236)
	_torso.add_child(_heart_piv)
	var h_mat: Material = brass if is_velvet else heart_mat
	_mi(_heart_piv, _sph(0.044, 16, 12), h_mat, Vector3(-0.020, 0.016, 0))
	_mi(_heart_piv, _sph(0.044, 16, 12), h_mat, Vector3(0.020, 0.016, 0))
	_mi(_heart_piv, _cyl(0.042, 0.008, 0.068, 16), h_mat, Vector3(0, -0.026, 0))
	if is_velvet:
		_gears.append(_make_gear(_heart_piv, 0.028, heart_mat, Vector3(0, 0.0, -0.032)))
	else:
		_mi(_torso, _cap(0.006, 0.17, 8), brass, Vector3(0, 0.31, -0.262))
		_mi(_torso, _cap(0.006, 0.15, 8), brass, Vector3(0, 0.31, -0.262), Vector3.ONE, Vector3(0, 0, 90))

	# Twin Back Brass Steam Boiler Tanks & Angled Exhaust Pipes (char_02_tin_woodman.jpg!)
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		_mi(_torso, _cyl(0.048, 0.052, 0.24, 16), brass, Vector3(s * 0.105, 0.30, 0.22))
		_mi(_torso, _cyl(0.024, 0.028, 0.20, 12), dark_iron, Vector3(s * 0.125, 0.46, 0.22), Vector3.ONE, Vector3(0, 0, -s * 24.0))

	# Multi-Tier Riveted Shoulder Pauldrons with Brass Spikes
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		_mi(_torso, _sph(0.135, 20, 12), tin, Vector3(s * 0.265, 0.40, 0), Vector3(1.18, 0.78, 1.08), Vector3(0, 0, -s * 16.0))
		_mi(_torso, _torus(0.105, 0.118, 18), brass, Vector3(s * 0.265, 0.36, 0), Vector3(1.15, 0.5, 1.05), Vector3(0, 0, -s * 16.0))
		_mi(_torso, _cyl(0.006, 0.024, 0.088, 10), brass, Vector3(s * 0.34, 0.45, 0), Vector3.ONE, Vector3(0, 0, -s * 44.0))

	# ========================================================================
	# 3. SCULPTED AUTOMATON HEAD, GLOWING AMBER EYES, HINGED JAW & FUNNEL HELM
	# ========================================================================
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.50, 0)
	_torso.add_child(_head)

	_mi(_head, _cyl(0.068, 0.082, 0.10, 18), dark_iron, Vector3(0, 0.02, 0)) # articulated neck piston
	_mi(_head, _cyl(0.132, 0.125, 0.22, 24), tin, Vector3(0, 0.15, 0))
	_mi(_head, _sph(0.134, 22, 14), tin, Vector3(0, 0.23, 0), Vector3(1.0, 0.72, 1.0))
	# Brow visor ridge + angular sculpted tin nose
	_mi(_head, _torus(0.105, 0.124, 20), tin, Vector3(0, 0.20, -0.02), Vector3(1.0, 0.48, 0.92))
	_mi(_head, _cyl(0.012, 0.032, 0.088, 12), tin, Vector3(0, 0.15, -0.155), Vector3.ONE, Vector3(-86, 0, 0))

	# Hinged metallic jaw
	_jaw = Node3D.new()
	_jaw.name = "Jaw"
	_jaw.position = Vector3(0, 0.072, -0.04)
	_head.add_child(_jaw)
	_mi(_jaw, _cyl(0.108, 0.095, 0.072, 18), dark_iron, Vector3(0, -0.01, -0.03), Vector3(0.95, 1.0, 0.92))

	# Recessed Amber-Gold Clockwork Eyes with Brass Aperture Rings
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		_mi(_head, _torus(0.024, 0.032, 14), dark_iron, Vector3(s * 0.052, 0.172, -0.124), Vector3.ONE, Vector3(90, 0, 0))
		_mi(_head, _sph(0.024, 14, 10), eye_mat, Vector3(s * 0.052, 0.172, -0.130))

	# Iconic Riveted Oil-Funnel Helm + Spout + Side Handle + Spikes
	var helm := Node3D.new()
	helm.position = Vector3(0.015, 0.27, 0)
	helm.rotation_degrees = Vector3(0, 0, -10)
	_head.add_child(helm)
	_mi(helm, _torus(0.145, 0.172, 22), brass, Vector3(0, 0.0, 0))
	_mi(helm, _cyl(0.036, 0.165, 0.22, 24), tin, Vector3(0, 0.11, 0))
	_mi(helm, _cyl(0.018, 0.032, 0.15, 16), tin, Vector3(0, 0.28, 0))
	_mi(helm, _torus(0.038, 0.048, 14), tin, Vector3(0.145, 0.08, 0), Vector3(0.85, 1.25, 0.75)) # funnel loop handle
	for sx in [-1.0, 1.0]:
		_mi(helm, _cyl(0.005, 0.018, 0.07, 8), brass, Vector3(float(sx) * 0.135, 0.07, -0.05), Vector3.ONE, Vector3(0, 0, -float(sx) * 58.0))

	# ========================================================================
	# 4. ARTICULATED ARMS, SPINNING ELBOW GEARS, GAUNTLET FINGERS & CRESCENT AXE
	# ========================================================================
	_arm_l = _make_arm(_torso, true, tin, dark_iron, brass)
	_arm_r = _make_arm(_torso, false, tin, dark_iron, brass)

	# Sculpted Etched Woodsman Crescent Axe in right gauntlet!
	if not rusted:
		var r_hand := _arm_r.get_node("Upper/Lower/Hand") as Node3D
		if r_hand:
			var axe_piv := Node3D.new()
			axe_piv.name = "WoodsmanAxe"
			axe_piv.position = Vector3(0.03, -0.02, -0.04)
			axe_piv.rotation_degrees = Vector3(82, 0, 0)
			r_hand.add_child(axe_piv)
			_mi(axe_piv, _cyl(0.022, 0.028, 0.96, 14), wood, Vector3(0, 0.18, 0))
			_mi(axe_piv, _cyl(0.032, 0.034, 0.10, 14), brass, Vector3(0, 0.56, 0)) # engraved ferrule collar
			# Curved double-bevel crescent steel axe head + rear armor-piercing pick!
			_mi(axe_piv, _cyl(0.15, 0.15, 0.032, 20), blade_steel, Vector3(0, 0.62, -0.14), Vector3(0.32, 1.0, 1.15), Vector3(0, 0, 90))
			_mi(axe_piv, _cyl(0.008, 0.038, 0.16, 10), blade_steel, Vector3(0, 0.62, 0.09), Vector3.ONE, Vector3(95, 0, 0)) # rear spike

	_leg_l = _make_leg(_hip, true, tin, dark_iron, brass)
	_leg_r = _make_leg(_hip, false, tin, dark_iron, brass)

func _make_gear(parent: Node3D, rad: float, mat: Material, pos: Vector3) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	parent.add_child(g)
	_mi(g, _torus(rad * 0.52, rad, 14), mat, Vector3.ZERO, Vector3.ONE, Vector3(90, 0, 0))
	for ti in range(6):
		var ta := float(ti) / 6.0 * TAU
		_mi(g, _cap(rad * 0.18, rad * 0.55, 6), mat, Vector3(cos(ta) * rad, sin(ta) * rad, 0), Vector3.ONE, Vector3(0, 0, rad_to_deg(ta) + 90.0))
	return g

func _make_arm(parent: Node3D, left: bool, tin: Material, dark: Material, brass: Material) -> Node3D:
	var s := -1.0 if left else 1.0
	var root := Node3D.new()
	root.name = "ArmL" if left else "ArmR"
	root.position = Vector3(0.285 * s, 0.36, 0)
	parent.add_child(root)

	var upper := Node3D.new()
	upper.name = "Upper"
	root.add_child(upper)
	_mi(upper, _cyl(0.064, 0.056, 0.28, 18), tin, Vector3(0, -0.14, 0))
	_mi(upper, _sph(0.062, 16, 12), dark, Vector3(0, -0.28, 0))
	_gears.append(_make_gear(upper, 0.044, brass, Vector3(s * 0.062, -0.28, 0)))

	var lower := Node3D.new()
	lower.name = "Lower"
	lower.position = Vector3(0, -0.28, 0)
	upper.add_child(lower)
	_mi(lower, _cyl(0.060, 0.048, 0.27, 18), tin, Vector3(0, -0.135, 0))
	_mi(lower, _torus(0.048, 0.058, 16), brass, Vector3(0, -0.24, 0))

	# Articulated Steel Gauntlet + Thumb + 4 Armored Fingers
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0, -0.28, 0)
	lower.add_child(hand)
	_mi(hand, _sph(0.038, 14, 10), tin, Vector3(0, -0.018, 0), Vector3(0.95, 1.15, 0.65))
	_mi(hand, _cap(0.010, 0.042, 8), dark, Vector3(-s * 0.030, -0.022, -0.015), Vector3.ONE, Vector3(24, 0, s * 36.0))
	for fi in range(4):
		var fx := (float(fi) - 1.5) * 0.014 * s
		_mi(hand, _cap(0.008, 0.050, 8), tin, Vector3(fx, -0.052, -0.005), Vector3.ONE, Vector3(16, 0, 0))
	return root

func _make_leg(parent: Node3D, left: bool, tin: Material, dark: Material, brass: Material) -> Node3D:
	var s := -1.0 if left else 1.0
	var root := Node3D.new()
	root.name = "LegL" if left else "LegR"
	root.position = Vector3(0.115 * s, -0.10, 0)
	parent.add_child(root)

	var thigh := Node3D.new()
	thigh.name = "Thigh"
	root.add_child(thigh)
	_mi(thigh, _cyl(0.084, 0.072, 0.36, 20), tin, Vector3(0, -0.18, 0))
	_mi(thigh, _sph(0.076, 16, 12), dark, Vector3(0, -0.36, 0))
	_mi(thigh, _sph(0.055, 14, 10), tin, Vector3(0, -0.36, -0.055), Vector3(1.0, 1.18, 0.55)) # knee couter plate
	_gears.append(_make_gear(thigh, 0.045, brass, Vector3(s * 0.078, -0.36, 0)))

	var calf := Node3D.new()
	calf.name = "Calf"
	calf.position = Vector3(0, -0.36, 0)
	thigh.add_child(calf)
	_mi(calf, _cyl(0.074, 0.058, 0.36, 20), tin, Vector3(0, -0.18, 0))

	# Sculpted Armored Sabaton Boot (zero blocky boxes!)
	var boot := Node3D.new()
	boot.name = "Sabaton"
	boot.position = Vector3(0, -0.38, 0)
	calf.add_child(boot)
	_mi(boot, _sph(0.072, 18, 12), tin, Vector3(0, -0.015, -0.055), Vector3(1.02, 0.65, 1.72))
	_mi(boot, _torus(0.054, 0.066, 16), brass, Vector3(0, 0.025, 0))
	return root

# ============================================================================
# ANISOTROPIC BRUSHED TIN & PATINA SPATIAL SHADER
# ============================================================================

func _make_tin_material(c_hi: Color, c_lo: Color, metal: float, rough: float) -> ShaderMaterial:
	if _tin_shader == null:
		_tin_shader = Shader.new()
		_tin_shader.code = """
shader_type spatial;
uniform vec4 col_hi : source_color = vec4(0.74, 0.79, 0.85, 1.0);
uniform vec4 col_lo : source_color = vec4(0.48, 0.54, 0.60, 1.0);
uniform float metal_val = 0.92;
uniform float rough_val = 0.24;
void fragment() {
	float brush = sin(UV.y * 220.0 + sin(UV.x * 40.0) * 1.5) * 0.5 + 0.5;
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = mix(col_lo.rgb, col_hi.rgb, clamp(brush * 0.45 + 0.45 + f * 0.25, 0.0, 1.0));
	METALLIC = metal_val;
	ROUGHNESS = clamp(rough_val + (1.0 - brush) * 0.08, 0.10, 0.92);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _tin_shader
	sm.set_shader_parameter("col_hi", c_hi)
	sm.set_shader_parameter("col_lo", c_lo)
	sm.set_shader_parameter("metal_val", metal)
	sm.set_shader_parameter("rough_val", rough)
	return sm
