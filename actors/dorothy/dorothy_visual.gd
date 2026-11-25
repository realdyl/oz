extends Node3D

## 2026 Flagship Character Benchmark — Dorothy Gale ("The Seeker")
## Sculpted facial anatomy (blinking eyelids, iris/pupil/catchlights, arched brows, nose, lips, ears, freckles),
## multi-joint spring-physics twin braids & silk ribbons, articulated hands with fingers,
## dynamic pleated skirt & bow physics, 4 bespoke Couture outfits + Kansas monochrome pinafore,
## 3-stage martial arts stiletto kicks, Silver-Shoe Blink dash pose, Armament cast choreography,
## and whimsical Silver-Shoe Heel-Click idle flourish.

const WorldKit := preload("res://systems/world_kit.gd")

@export var greyscale: bool = false
@export var show_silver_shoes: bool = false
@export var mature_silhouette: bool = true
@export var outfit_id: String = "dorothy_gingham"

static var _gingham_shader: Shader = null
static var _velvet_shader: Shader = null
static var _satin_shader: Shader = null

var _hip: Node3D
var _skirt_piv: Node3D
var _bow_tails_piv: Node3D
var _torso: Node3D
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _eyelid_l: Node3D
var _eyelid_r: Node3D
var _brow_l: Node3D
var _brow_r: Node3D
var _braid_l_joints: Array[Node3D] = []
var _braid_r_joints: Array[Node3D] = []

var _phase: float = 0.0
var _idle_t: float = 0.0
var _still_t: float = 0.0
var _speed_amt: float = 0.0
var _kick_t: float = 0.0
var _kick_step: int = 1
var _interact_t: float = 0.0
var _blink_pose_t: float = 0.0
var _cast_t: float = 0.0
var _cast_kind: int = 0
var _heel_click_t: float = 0.0
var _next_heel_click: float = 5.8
var _eye_blink_cd: float = 2.9
var _eye_blink_t: float = 0.0
var _air_vy: float = 0.0
var _on_floor: bool = true
var _land_squash: float = 0.0
var _turn_rate: float = 0.0
var _braid_sway_x: float = 0.0
var _braid_sway_z: float = 0.0
var _skirt_flare: float = 0.0
var sleeping: bool = false

const KICK_DUR := 0.36
const INTERACT_DUR := 0.36
const BLINK_POSE_DUR := 0.20
const CAST_DUR := 0.42
const HEEL_CLICK_DUR := 0.68

func _ready() -> void:
	if not greyscale:
		var sm := get_node_or_null("/root/SaveManager")
		if sm and "equipped_outfits" in sm:
			var eq: String = str(sm.equipped_outfits.get("dorothy", ""))
			if eq != "":
				outfit_id = eq
	_rebuild_character()

func set_outfit(new_outfit_id: String) -> void:
	var clean_id := new_outfit_id.strip_edges()
	if clean_id == "":
		clean_id = "dorothy_gingham"
	outfit_id = clean_id
	_rebuild_character()

func _rebuild_character() -> void:
	# Preserve BasketMount children (e.g. Toto's basket attached at runtime!)
	var saved_basket_children: Array[Node] = []
	var old_mount := find_child("BasketMount", true, false)
	if old_mount:
		for ch in old_mount.get_children():
			old_mount.remove_child(ch)
			saved_basket_children.append(ch)

	_braid_l_joints.clear()
	_braid_r_joints.clear()
	for c in get_children():
		c.free()

	_build()

	var new_mount := find_child("BasketMount", true, false)
	if new_mount:
		for ch in saved_basket_children:
			new_mount.add_child(ch)
	_apply_pose(0.016)

func play_kick() -> void:
	play_combo_kick(1)

func play_combo_kick(step: int = 1) -> void:
	_kick_step = clampi(step, 1, 3)
	_kick_t = KICK_DUR + (0.08 if _kick_step == 3 else (0.04 if _kick_step == 2 else 0.0))
	_still_t = 0.0

func play_blink() -> void:
	_blink_pose_t = BLINK_POSE_DUR
	_still_t = 0.0

func play_cast(kind: int = 0) -> void:
	_cast_kind = kind
	_cast_t = CAST_DUR
	_still_t = 0.0

func play_heel_click() -> void:
	_heel_click_t = HEEL_CLICK_DUR
	_still_t = 0.0

func play_interact() -> void:
	_interact_t = INTERACT_DUR
	_still_t = 0.0

func set_sleeping(on: bool) -> void:
	sleeping = on
	_apply_pose(0.016)

func set_airborne(vel_y: float, floor_flag: bool, turn_vel: float = 0.0) -> void:
	if not _on_floor and floor_flag and _air_vy < -3.5:
		_land_squash = clampf(-_air_vy / 16.0, 0.12, 0.42)
	_air_vy = vel_y
	_on_floor = floor_flag
	_turn_rate = clampf(turn_vel, -8.0, 8.0)

func set_locomotion(horizontal_speed: float, delta: float) -> void:
	_idle_t += delta
	_kick_t = maxf(_kick_t - delta, 0.0)
	_interact_t = maxf(_interact_t - delta, 0.0)
	_blink_pose_t = maxf(_blink_pose_t - delta, 0.0)
	_cast_t = maxf(_cast_t - delta, 0.0)
	_heel_click_t = maxf(_heel_click_t - delta, 0.0)
	_land_squash = move_toward(_land_squash, 0.0, delta * 3.2)

	# Natural human eye blink cycle
	_eye_blink_cd -= delta
	if _eye_blink_cd <= 0.0:
		_eye_blink_t = 0.13
		_eye_blink_cd = randf_range(2.6, 5.1)
	if _eye_blink_t > 0.0:
		_eye_blink_t = maxf(_eye_blink_t - delta, 0.0)

	_speed_amt = clampf(horizontal_speed / 5.0, 0.0, 1.55) if not sleeping else 0.0
	if _speed_amt > 0.08:
		_phase += delta * (8.8 + _speed_amt * 5.8)
		_still_t = 0.0
	else:
		_phase = move_toward(_phase, 0.0, delta * 5.0)
		_speed_amt = move_toward(_speed_amt, 0.0, delta * 4.2)
		if not sleeping and _on_floor and _kick_t <= 0.0 and _cast_t <= 0.0 and show_silver_shoes:
			_still_t += delta
			if _still_t >= _next_heel_click:
				_still_t = 0.0
				_next_heel_click = randf_range(6.5, 10.5)
				_heel_click_t = HEEL_CLICK_DUR

	_apply_pose(delta)

func _apply_pose(delta: float = 0.016) -> void:
	if _leg_l == null or _hip == null:
		return

	# Eyelid blink & expressive brow state
	var blink_u := sin((_eye_blink_t / 0.13) * PI) if _eye_blink_t > 0.0 else 0.0
	if sleeping:
		blink_u = 1.0
	if _eyelid_l and _eyelid_r:
		var lid_sy := lerpf(0.12, 1.05, blink_u)
		_eyelid_l.scale.y = lid_sy
		_eyelid_r.scale.y = lid_sy
		_eyelid_l.visible = blink_u > 0.05
		_eyelid_r.visible = blink_u > 0.05
	var fierce := 1.0 if (_kick_t > 0.0 or _cast_t > 0.0 or _blink_pose_t > 0.0) else 0.0
	if _brow_l and _brow_r:
		_brow_l.rotation.z = lerpf(0.08, -0.14, fierce)
		_brow_r.rotation.z = lerpf(-0.08, 0.14, fierce)

	if sleeping:
		var breath_s := sin(_idle_t * 1.9) * 0.012
		_hip.position = Vector3(0, 0.20 + breath_s, 0)
		_hip.rotation = Vector3(-1.46, 0.15, 0.45)
		_torso.rotation = Vector3(0.18, 0.0, 0.12)
		_leg_l.rotation = Vector3(-0.45, 0.0, 0.08)
		_leg_r.rotation = Vector3(-0.68, 0.0, -0.08)
		_set_calf(_leg_l, 0.72)
		_set_calf(_leg_r, 0.88)
		_arm_l.rotation = Vector3(-0.65, 0.0, 0.25)
		_arm_r.rotation = Vector3(-0.85, 0.0, -0.35)
		return

	_hip.rotation.x = 0.0
	_hip.rotation.z = 0.0
	_leg_l.rotation.z = 0.0
	_leg_r.rotation.z = 0.0

	# Priority 1: 3-Stage Martial Arts Stiletto Kicks!
	if _kick_t > 0.0:
		var total_d := KICK_DUR + (0.08 if _kick_step == 3 else (0.04 if _kick_step == 2 else 0.0))
		var u := clampf(1.0 - (_kick_t / total_d), 0.0, 1.0)
		var arc := sin(clampf(u * 1.18, 0.0, 1.0) * PI)
		if _kick_step == 1:
			# Step 1: Crisp Martial High Front-Roundhouse Snap Kick
			_hip.position.y = 0.80 + arc * 0.07
			_hip.rotation.y = -0.62 * arc
			_torso.rotation = Vector3(0.30 * arc, 0.34 * arc, -0.20 * arc)
			_leg_r.rotation = Vector3(-1.72 * arc, 0.0, 0.34 * arc)
			_set_calf(_leg_r, 0.14 * (1.0 - arc))
			_leg_l.rotation = Vector3(0.20 * arc, 0.0, -0.06 * arc)
			_set_calf(_leg_l, 0.26 * arc)
			_arm_l.rotation = Vector3(-0.95 * arc, 0.0, -0.48 * arc)
			_arm_r.rotation = Vector3(0.68 * arc, 0.0, 0.52 * arc)
		elif _kick_step == 2:
			# Step 2: 360° Balletic Spinning Back-Heel Sweep!
			_hip.position.y = 0.80 + arc * 0.09
			_hip.rotation.y = u * TAU
			_torso.rotation = Vector3(0.36 * arc, -0.25 * arc, 0.24 * arc)
			_leg_l.rotation = Vector3(-1.52 * arc, 0.0, -0.58 * arc)
			_set_calf(_leg_l, 0.10)
			_leg_r.rotation = Vector3(0.18 * arc, 0.0, 0.08 * arc)
			_set_calf(_leg_r, 0.32 * arc)
			_arm_l.rotation = Vector3(-0.45 * arc, 0.0, -1.05 * arc)
			_arm_r.rotation = Vector3(-0.45 * arc, 0.0, 1.05 * arc)
		else:
			# Step 3: Leaping Starlight Pirouette Crescent Finisher!
			_hip.position.y = 0.80 + sin(u * PI) * 0.26
			_hip.rotation.y = -u * TAU
			_hip.rotation.x = -0.22 * arc
			_torso.rotation = Vector3(-0.26 * arc, 0.30 * arc, -0.24 * arc)
			_leg_r.rotation = Vector3(-1.88 * arc, 0.0, 0.42 * arc)
			_set_calf(_leg_r, 0.06)
			_leg_l.rotation = Vector3(0.58 * arc, 0.0, -0.18 * arc)
			_set_calf(_leg_l, 0.78 * arc)
			_arm_l.rotation = Vector3(-1.35 * arc, 0.0, -0.68 * arc)
			_arm_r.rotation = Vector3(-1.15 * arc, 0.0, 0.72 * arc)
		_update_secondary_physics(delta, 1.35 + float(_kick_step) * 0.25)
		return

	# Priority 2: Silver-Shoe Blink Aerodynamic Dash Pose
	if _blink_pose_t > 0.0:
		var bu := sin((1.0 - _blink_pose_t / BLINK_POSE_DUR) * PI)
		_hip.position.y = 0.84 + bu * 0.08
		_hip.rotation.y = 0.0
		_torso.rotation = Vector3(-0.38 * bu, 0.0, 0.0)
		_leg_l.rotation = Vector3(-0.75 * bu, 0.0, 0.0)
		_set_calf(_leg_l, 0.65 * bu)
		_leg_r.rotation = Vector3(0.68 * bu, 0.0, 0.0)
		_set_calf(_leg_r, 0.42 * bu)
		_arm_l.rotation = Vector3(0.75 * bu, 0.0, -0.35 * bu)
		_arm_r.rotation = Vector3(0.75 * bu, 0.0, 0.35 * bu)
		_update_secondary_physics(delta, 1.6)
		return

	# Priority 3: Rated-M Armament Cast Choreography (Whip / Silk / Perfume / Chain)
	if _cast_t > 0.0:
		var cu := 1.0 - (_cast_t / CAST_DUR)
		var carc := sin(cu * PI)
		_hip.position.y = 0.80 + carc * 0.04
		if _cast_kind == 0:
			# Lace Whip: wind-up then sharp forward snap with right arm
			var snap := sin(clampf(cu * 1.4, 0.0, 1.0) * PI)
			_hip.rotation.y = lerpf(0.42, -0.48, smoothstep(0.15, 0.65, cu)) * carc
			_torso.rotation = Vector3(-0.18 * snap, 0.28 * snap, 0.0)
			_arm_r.rotation = Vector3(lerpf(0.85, -1.65, smoothstep(0.12, 0.55, cu)) * carc, 0.0, 0.35 * carc)
			_set_forearm(_arm_r, -0.20 * (1.0 - snap))
			_arm_l.rotation = Vector3(0.42 * carc, 0.0, -0.38 * carc)
		elif _cast_kind == 2:
			# Hypnotic Perfume: graceful 360° ballerina pirouette
			_hip.rotation.y = cu * TAU
			_hip.position.y = 0.80 + carc * 0.08
			_torso.rotation = Vector3(-0.14 * carc, 0.0, 0.12 * carc)
			_arm_l.rotation = Vector3(-0.95 * carc, 0.0, -0.85 * carc)
			_arm_r.rotation = Vector3(-0.95 * carc, 0.0, 0.85 * carc)
		else:
			# Silk Bindings / Gilded Chain: sweeping twin-arm arcane tether gesture
			_hip.rotation.y = 0.0
			_torso.rotation = Vector3(-0.22 * carc, 0.0, 0.0)
			_arm_l.rotation = Vector3(-1.25 * carc, 0.25 * carc, -0.52 * carc)
			_arm_r.rotation = Vector3(-1.25 * carc, -0.25 * carc, 0.52 * carc)
		_update_secondary_physics(delta, 1.25)
		return

	# Priority 4: Airborne Jump / Cyclone Float Pose
	if not _on_floor and absf(_air_vy) > 1.2:
		var rise := clampf(_air_vy / 8.0, -1.0, 1.0)
		_hip.position.y = 0.82
		_hip.rotation.y = 0.0
		_torso.rotation = Vector3(-0.16 * rise, 0.0, 0.0)
		_leg_l.rotation = Vector3(-0.48, 0.0, -0.06)
		_set_calf(_leg_l, 0.72)
		_leg_r.rotation = Vector3(0.24, 0.0, 0.06)
		_set_calf(_leg_r, 0.58)
		_arm_l.rotation = Vector3(-0.42, 0.0, -0.52)
		_arm_r.rotation = Vector3(-0.42, 0.0, 0.52)
		_update_secondary_physics(delta, 1.15)
		return

	# Priority 5: Whimsical Silver-Shoe Heel-Click Flourish!
	if _heel_click_t > 0.0:
		var hu := 1.0 - (_heel_click_t / HEEL_CLICK_DUR)
		var rise_h := sin(hu * PI)
		var click_tap := absf(sin(hu * PI * 3.0)) * rise_h
		_hip.position.y = 0.80 + rise_h * 0.065
		_hip.rotation.y = sin(hu * TAU) * 0.10
		_torso.rotation = Vector3(-0.06 * rise_h, 0.0, sin(hu * TAU) * 0.06)
		_leg_l.rotation = Vector3(-0.10 * rise_h, 0.0, 0.16 * click_tap - 0.06 * rise_h)
		_leg_r.rotation = Vector3(-0.10 * rise_h, 0.0, -0.16 * click_tap + 0.06 * rise_h)
		_set_calf(_leg_l, 0.18 * rise_h)
		_set_calf(_leg_r, 0.18 * rise_h)
		_arm_l.rotation = Vector3(-0.22 * rise_h, 0.0, -0.34 * rise_h)
		_arm_r.rotation = Vector3(-0.22 * rise_h, 0.0, 0.34 * rise_h)
		if _head:
			_head.rotation = Vector3(0.08 * rise_h, sin(hu * PI) * 0.14, 0.05 * rise_h)
		_update_secondary_physics(delta, 0.65)
		return

	# Standard Feminine Walk / Sprint / Breathing Idle + Landing Cushion
	var squash_drop := _land_squash * 0.11
	_hip.rotation.y = sin(_phase) * 0.085 * _speed_amt
	_torso.rotation.x = -0.15 * clampf(_speed_amt - 0.25, 0.0, 1.1) + _land_squash * 0.18
	_torso.rotation.y = -sin(_phase) * 0.095 * _speed_amt
	_torso.rotation.z = sin(_phase) * 0.048 * _speed_amt - _turn_rate * 0.025

	var swing := sin(_phase) * 0.66 * _speed_amt
	var swing_a := sin(_phase + PI) * 0.56 * _speed_amt
	_leg_l.rotation.x = swing - _land_squash * 0.35
	_leg_r.rotation.x = -swing - _land_squash * 0.35
	_set_calf(_leg_l, maxf(-swing, 0.0) * 0.82 + 0.06 * _speed_amt + _land_squash * 0.65)
	_set_calf(_leg_r, maxf(swing, 0.0) * 0.82 + 0.06 * _speed_amt + _land_squash * 0.65)

	_arm_l.rotation.x = -swing_a * 0.90
	_arm_r.rotation.x = swing_a * 0.90
	_arm_l.rotation.z = -0.10 - 0.06 * _speed_amt
	_arm_r.rotation.z = 0.10 + 0.06 * _speed_amt
	_set_forearm(_arm_l, -0.24 - maxf(-swing_a, 0.0) * 0.48)
	_set_forearm(_arm_r, -0.24 - maxf(swing_a, 0.0) * 0.48)

	var breath := sin(_idle_t * 2.5) * 0.012
	var still_blend := 1.0 - clampf(_speed_amt, 0.0, 1.0)
	_hip.position.y = 0.80 - squash_drop + absf(sin(_phase)) * 0.036 * _speed_amt + breath * still_blend
	if _head:
		_head.rotation.y = sin(_idle_t * 0.95) * 0.10 * still_blend - _turn_rate * 0.03
		_head.rotation.x = sin(_idle_t * 1.45) * 0.035 * still_blend + 0.08 * clampf(_speed_amt - 0.3, 0.0, 1.0)
		_head.rotation.z = sin(_idle_t * 0.72) * 0.03 * still_blend

	if _interact_t > 0.0:
		var iu := sin((1.0 - _interact_t / INTERACT_DUR) * PI)
		_arm_r.rotation.x = -1.18 * iu
		_set_forearm(_arm_r, -0.36 * iu)

	_update_secondary_physics(delta, _speed_amt)

func _update_secondary_physics(delta: float, motion_energy: float) -> void:
	# Multi-segment spring-lagging twin braids & fluttering silk ribbons
	var target_bx := clampf(motion_energy * 0.24 + maxf(-_air_vy, 0.0) * 0.05, -0.25, 0.62)
	var target_bz := clampf(_turn_rate * 0.08 + sin(_phase) * 0.08 * _speed_amt, -0.45, 0.45)
	_braid_sway_x = lerpf(_braid_sway_x, target_bx, clampf(delta * 10.0, 0.0, 1.0))
	_braid_sway_z = lerpf(_braid_sway_z, target_bz, clampf(delta * 10.0, 0.0, 1.0))

	for i in range(_braid_l_joints.size()):
		var w := float(i + 1) * 0.34
		var wave := sin(_idle_t * 2.4 + float(i) * 0.75) * 0.028 + sin(_phase * 2.0 + float(i)) * 0.045 * motion_energy
		var jl := _braid_l_joints[i]
		var jr := _braid_r_joints[i]
		if jl:
			jl.rotation.x = _braid_sway_x * w + wave
			jl.rotation.z = -0.06 + _braid_sway_z * w - motion_energy * 0.04 * w
		if jr:
			jr.rotation.x = _braid_sway_x * w + wave
			jr.rotation.z = 0.06 + _braid_sway_z * w + motion_energy * 0.04 * w

	# Dynamic skirt flare + back bow sash flutter
	var target_flare := clampf(motion_energy * 0.11 + absf(_turn_rate) * 0.03, 0.0, 0.26)
	_skirt_flare = lerpf(_skirt_flare, target_flare, clampf(delta * 9.0, 0.0, 1.0))
	if _skirt_piv:
		_skirt_piv.scale = Vector3(1.0 + _skirt_flare, 1.0 - _skirt_flare * 0.18, 1.0 + _skirt_flare)
		_skirt_piv.rotation.x = _braid_sway_x * 0.28
		_skirt_piv.rotation.z = -_braid_sway_z * 0.35
	if _bow_tails_piv:
		_bow_tails_piv.rotation.x = 0.18 + _braid_sway_x * 0.85 + sin(_idle_t * 2.8) * 0.04
		_bow_tails_piv.rotation.z = _braid_sway_z * 0.55

func _set_calf(leg: Node3D, rx: float) -> void:
	if leg and leg.has_node("Thigh/Calf"):
		(leg.get_node("Thigh/Calf") as Node3D).rotation.x = rx

func _set_forearm(arm: Node3D, rx: float) -> void:
	if arm and arm.has_node("Upper/Lower"):
		(arm.get_node("Upper/Lower") as Node3D).rotation.x = rx

# ============================================================================
# MATERIAL & PRIMITIVE SCULPTING HELPERS
# ============================================================================

func _col(rgb: Color) -> Color:
	if greyscale:
		var l := rgb.r * 0.30 + rgb.g * 0.50 + rgb.b * 0.20
		return Color(l * 1.02, l * 1.00, l * 0.97)
	return rgb

func _mat(
	color: Color,
	rough: float = 0.68,
	metal: float = 0.0,
	emit_col: Color = Color(0, 0, 0),
	emit_energy: float = 0.0,
	rim_amt: float = 0.18
) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = _col(color)
	m.roughness = rough
	m.metallic = metal
	if rim_amt > 0.01:
		m.rim_enabled = true
		m.rim = rim_amt
		m.rim_tint = 0.45
	if emit_energy > 0.0:
		m.emission_enabled = true
		m.emission = _col(emit_col)
		m.emission_energy_multiplier = emit_energy
	return m

func _mi(
	parent: Node3D,
	mesh: Mesh,
	mat: Material,
	pos: Vector3,
	scl: Vector3 = Vector3.ONE,
	rot_deg: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	n.rotation_degrees = rot_deg
	n.scale = scl
	parent.add_child(n)
	return n

func _sphere(r: float, segs: int = 24, rings_n: int = 14) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = rings_n
	return s

func _capsule(r: float, h: float, segs: int = 20) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.02)
	c.radial_segments = segs
	c.rings = 8
	return c

func _cyl(t: float, b: float, h: float, segs: int = 28) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = t
	c.bottom_radius = b
	c.height = h
	c.radial_segments = segs
	c.rings = 2
	return c

func _torus(inner_r: float, outer_r: float, rings_n: int = 24) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner_r
	t.outer_radius = outer_r
	t.rings = rings_n
	t.ring_segments = 14
	return t

# ============================================================================
# 2026 CHARACTER & COUTURE GEOMETRY BUILDER
# ============================================================================

func _build() -> void:
	var is_kansas_plain := greyscale and not show_silver_shoes
	var active_outfit := "kansas_pinafore" if is_kansas_plain else outfit_id

	# Shared anatomical materials
	var skin_rgb := Color(0.95, 0.77, 0.67)
	var skin := _mat(skin_rgb, 0.44, 0.0, Color.BLACK, 0.0, 0.32)
	var ear_inner := _mat(Color(0.88, 0.62, 0.54), 0.50)
	var freckle_mat := _mat(Color(0.72, 0.48, 0.38), 0.65, 0.0, Color.BLACK, 0.0, 0.0)
	var cheek_mat := _mat(Color(0.93, 0.56, 0.56), 0.50, 0.0, Color.BLACK, 0.0, 0.15)
	var hair_dark := _mat(Color(0.15, 0.085, 0.055), 0.52, 0.06, Color.BLACK, 0.0, 0.35)
	var hair_hi := _mat(Color(0.24, 0.14, 0.09), 0.46, 0.08, Color.BLACK, 0.0, 0.40)
	var sclera := _mat(Color(0.98, 0.98, 1.0), 0.18, 0.0, Color.BLACK, 0.0, 0.0)
	var iris_outer := _mat(Color(0.18, 0.34, 0.52), 0.16, 0.05)
	var iris_inner := _mat(Color(0.36, 0.58, 0.76), 0.14, 0.05, Color(0.28, 0.48, 0.68), 0.18)
	var pupil_mat := _mat(Color(0.03, 0.03, 0.05), 0.10, 0.0, Color.BLACK, 0.0, 0.0)
	var glint_mat := _mat(Color(1.0, 1.0, 1.0), 0.05, 0.0, Color(1.0, 1.0, 1.0), 1.4, 0.0)
	var lash_mat := _mat(Color(0.08, 0.05, 0.04), 0.45, 0.0, Color.BLACK, 0.0, 0.0)
	var lip_upper := _mat(Color(0.72, 0.25, 0.33), 0.34, 0.02)
	var lip_lower := _mat(Color(0.80, 0.31, 0.39), 0.28, 0.04)
	if active_outfit == "dorothy_velvet":
		lip_upper = _mat(Color(0.62, 0.09, 0.16), 0.26, 0.05)
		lip_lower = _mat(Color(0.72, 0.12, 0.20), 0.22, 0.06)

	# Outfit-specific couture palette & shaders
	var main_fabric: Material
	var secondary_fabric: Material
	var blouse_mat: Material
	var corset_mat: Material
	var lace_mat: Material
	var underskirt_mat: Material
	var trim_metal: Material
	var ribbon_mat: Material
	var sleeve_upper_mat: Material
	var sleeve_lower_mat: Material
	var stocking_mat: Material
	var shoe_mat: Material
	var show_whip_holster := false

	match active_outfit:
		"kansas_pinafore":
			main_fabric = _make_gingham_material(Color(0.38, 0.38, 0.40), Color(0.78, 0.78, 0.80), Color(0.56, 0.56, 0.58))
			secondary_fabric = _mat(Color(0.50, 0.50, 0.52), 0.78)
			blouse_mat = _mat(Color(0.88, 0.87, 0.85), 0.68)
			corset_mat = main_fabric
			lace_mat = _mat(Color(0.90, 0.89, 0.87), 0.72)
			underskirt_mat = _mat(Color(0.42, 0.42, 0.44), 0.80)
			trim_metal = _mat(Color(0.58, 0.58, 0.60), 0.45, 0.45)
			ribbon_mat = _mat(Color(0.68, 0.68, 0.70), 0.60)
			sleeve_upper_mat = blouse_mat
			sleeve_lower_mat = skin
			stocking_mat = _mat(Color(0.74, 0.74, 0.76), 0.75)
			shoe_mat = _mat(Color(0.24, 0.22, 0.21), 0.58, 0.12)
		"dorothy_velvet":
			# The Red Seeker — Dark Gothic Crimson & Obsidian Couture (char_03_dorothy_red_seeker.jpg)
			main_fabric = _make_velvet_material(Color(0.46, 0.04, 0.10), Color(0.82, 0.12, 0.22))
			secondary_fabric = _mat(Color(0.08, 0.06, 0.09), 0.62, 0.05, Color.BLACK, 0.0, 0.30)
			blouse_mat = secondary_fabric
			corset_mat = secondary_fabric
			lace_mat = _mat(Color(0.09, 0.07, 0.10), 0.74, 0.0, Color.BLACK, 0.0, 0.25)
			underskirt_mat = _mat(Color(0.24, 0.05, 0.12), 0.68)
			trim_metal = _mat(Color(0.90, 0.73, 0.32), 0.24, 0.90, Color(0.85, 0.66, 0.24), 0.15)
			ribbon_mat = main_fabric
			sleeve_upper_mat = main_fabric
			sleeve_lower_mat = secondary_fabric
			stocking_mat = WorldKit.make_fishnet_material(skin_rgb, false)
			shoe_mat = _mat(Color(0.86, 0.90, 0.96), 0.16, 0.94, Color(0.80, 0.88, 1.0), 0.45)
			show_whip_holster = true
		"dorothy_sovereign":
			# Silver-Lace Sovereign — Iridescent Lavender-Silver Satin & High Scalloped Silver Lace (shop_dorothy_sovereign.png)
			main_fabric = _make_satin_material(Color(0.62, 0.54, 0.76), Color(0.92, 0.88, 1.0))
			secondary_fabric = _make_satin_material(Color(0.48, 0.40, 0.64), Color(0.84, 0.80, 0.96))
			blouse_mat = _mat(Color(0.90, 0.88, 0.96), 0.38, 0.18, Color(0.82, 0.80, 0.98), 0.18, 0.45)
			corset_mat = main_fabric
			lace_mat = _mat(Color(0.92, 0.93, 0.98), 0.28, 0.35, Color(0.86, 0.90, 1.0), 0.25, 0.50)
			underskirt_mat = secondary_fabric
			trim_metal = _mat(Color(0.94, 0.96, 1.0), 0.14, 0.95, Color(0.85, 0.92, 1.0), 0.35)
			ribbon_mat = lace_mat
			sleeve_upper_mat = lace_mat
			sleeve_lower_mat = blouse_mat
			stocking_mat = WorldKit.make_fishnet_material(Color(0.95, 0.84, 0.88), false)
			shoe_mat = _mat(Color(0.94, 0.97, 1.0), 0.10, 0.97, Color(0.86, 0.94, 1.0), 0.85)
		_:
			# "dorothy_gingham" & "dorothy_whip_plus" — Canonical Oz Seeker (char_05_dorothy_seeker.jpg)
			main_fabric = _make_gingham_material(Color(0.19, 0.36, 0.68), Color(0.94, 0.96, 0.99), Color(0.46, 0.63, 0.86))
			secondary_fabric = _mat(Color(0.15, 0.27, 0.54), 0.58)
			blouse_mat = _mat(Color(0.97, 0.95, 0.91), 0.52, 0.0, Color.BLACK, 0.0, 0.24)
			corset_mat = _make_velvet_material(Color(0.20, 0.10, 0.24), Color(0.38, 0.20, 0.44))
			lace_mat = _mat(Color(0.97, 0.96, 0.93), 0.58, 0.0, Color.BLACK, 0.0, 0.28)
			underskirt_mat = _mat(Color(0.21, 0.11, 0.26), 0.62)
			trim_metal = _mat(Color(0.90, 0.74, 0.36), 0.24, 0.88, Color(0.86, 0.68, 0.28), 0.14)
			ribbon_mat = _mat(Color(0.22, 0.38, 0.72), 0.42, 0.05)
			sleeve_upper_mat = main_fabric
			sleeve_lower_mat = main_fabric
			stocking_mat = WorldKit.make_fishnet_material(skin_rgb, greyscale)
			shoe_mat = _mat(Color(0.90, 0.94, 0.99), 0.12, 0.96, Color(0.82, 0.90, 1.0), 0.72 if show_silver_shoes else 0.15)
			show_whip_holster = (active_outfit == "dorothy_whip_plus")

	# ========================================================================
	# 1. HIP, CONTOURED CORSET WAIST & MULTI-TIER PLEATED SKIRT RIG
	# ========================================================================
	_hip = Node3D.new()
	_hip.name = "Hip"
	_hip.position = Vector3(0, 0.80, 0)
	add_child(_hip)

	var hip_w := 0.195 if mature_silhouette else 0.165
	var waist_w := 0.116 if mature_silhouette else 0.136

	# Pelvis / upper hip yoke
	_mi(_hip, _cyl(waist_w * 1.12, hip_w, 0.15, 28), main_fabric, Vector3(0, -0.02, 0))

	# Dynamic Skirt Pivot (flares & sways smoothly with motion!)
	_skirt_piv = Node3D.new()
	_skirt_piv.name = "SkirtPivot"
	_skirt_piv.position = Vector3(0, -0.04, 0)
	_hip.add_child(_skirt_piv)

	# Core layered skirt bell + 12 sculpted godet pleat flutes around circumference (zero blocky edges!)
	_mi(_skirt_piv, _cyl(hip_w * 0.96, 0.35, 0.31, 32), secondary_fabric if active_outfit == "dorothy_velvet" else main_fabric, Vector3(0, -0.16, 0))
	for pi in range(12):
		var ang := float(pi) / 12.0 * TAU
		var px := sin(ang) * 0.255
		var pz := cos(ang) * 0.255
		var pleat_mat := main_fabric if (active_outfit != "dorothy_velvet" or pi % 2 == 0) else secondary_fabric
		var pleat := _mi(_skirt_piv, _capsule(0.052, 0.34, 14), pleat_mat, Vector3(px, -0.175, pz), Vector3(0.95, 1.0, 0.68))
		pleat.rotation = Vector3(cos(ang) * 0.34, ang, -sin(ang) * 0.34)

	if active_outfit == "kansas_pinafore":
		# Kansas front pinafore apron panel + stitched patch pocket + prairie hem ruffle (char_07)
		_mi(_skirt_piv, _cyl(hip_w * 0.99, 0.33, 0.27, 24), lace_mat, Vector3(0, -0.145, -0.018), Vector3(0.88, 1.0, 0.96))
		_mi(_skirt_piv, _sphere(0.045, 14, 10), blouse_mat, Vector3(-0.095, -0.12, -0.235), Vector3(1.15, 1.25, 0.32))
		_mi(_skirt_piv, _cyl(0.345, 0.39, 0.065, 32), main_fabric, Vector3(0, -0.335, 0))
	elif active_outfit == "dorothy_velvet":
		# Red Seeker: Draped crimson velvet bustle swags + twin golden roses + double black scalloped lace tiers (char_03)
		for sx in [-1.0, 1.0]:
			var s := float(sx)
			_mi(_skirt_piv, _sphere(0.145, 20, 12), main_fabric, Vector3(s * 0.145, -0.11, -0.04), Vector3(1.05, 0.92, 1.25), Vector3(0, 0, s * -18.0))
			# Sculpted golden rose clasp & swagged chain on hip drape
			_mi(_skirt_piv, _sphere(0.032, 14, 10), trim_metal, Vector3(s * 0.155, -0.13, -0.19), Vector3(1.1, 1.1, 0.55))
			_mi(_skirt_piv, _torus(0.055, 0.064, 16), trim_metal, Vector3(s * 0.17, -0.16, 0.06), Vector3.ONE, Vector3(72, s * 25, 0))
		_mi(_skirt_piv, _sphere(0.17, 20, 12), main_fabric, Vector3(0, -0.15, 0.14), Vector3(1.35, 1.10, 0.95))
		_mi(_skirt_piv, _cyl(0.34, 0.395, 0.055, 32), lace_mat, Vector3(0, -0.325, 0))
		_mi(_skirt_piv, _cyl(0.355, 0.415, 0.045, 32), underskirt_mat, Vector3(0, -0.365, 0))
		_mi(_skirt_piv, _cyl(0.37, 0.435, 0.040, 32), lace_mat, Vector3(0, -0.395, 0))
	elif active_outfit == "dorothy_sovereign":
		# Sovereign: High-low starlight silver-lace overskirt panels + moonlit satin center drape (shop_dorothy_sovereign)
		for sx in [-1.0, 1.0]:
			var s := float(sx)
			_mi(_skirt_piv, _capsule(0.12, 0.40, 18), lace_mat, Vector3(s * 0.18, -0.20, 0.03), Vector3(0.95, 1.05, 1.25), Vector3(10, 0, s * -20.0))
		_mi(_skirt_piv, _cyl(0.33, 0.41, 0.055, 32), trim_metal, Vector3(0, -0.33, 0))
		_mi(_skirt_piv, _cyl(0.35, 0.44, 0.055, 32), lace_mat, Vector3(0, -0.37, 0))
	else:
		# Oz Seeker: Parted gingham peplum overskirt swags edged in white lace + gold trim + plum petticoat (char_05)
		for sx in [-1.0, 1.0]:
			var s := float(sx)
			_mi(_skirt_piv, _sphere(0.135, 20, 12), main_fabric, Vector3(s * 0.135, -0.095, -0.02), Vector3(1.02, 0.84, 1.28), Vector3(0, 0, s * -18.0))
			_mi(_skirt_piv, _torus(0.115, 0.132, 18), lace_mat, Vector3(s * 0.145, -0.155, -0.02), Vector3(0.95, 0.55, 1.22), Vector3(74, 0, s * -20.0))
		_mi(_skirt_piv, _cyl(0.335, 0.365, 0.038, 32), secondary_fabric, Vector3(0, -0.315, 0))
		_mi(_skirt_piv, _cyl(0.348, 0.402, 0.050, 32), lace_mat, Vector3(0, -0.352, 0))
		_mi(_skirt_piv, _cyl(0.362, 0.418, 0.040, 32), underskirt_mat, Vector3(0, -0.388, 0))
		_mi(_skirt_piv, _cyl(0.372, 0.432, 0.032, 32), lace_mat, Vector3(0, -0.414, 0))

	# Scalloped lace hem beadlets (20 soft lace scallops so the hem reads like hand-stitched Victorian lace!)
	for li in range(20):
		var la := float(li) / 20.0 * TAU
		var lr := 0.398 if active_outfit != "kansas_pinafore" else 0.375
		var ly := -0.365 if active_outfit != "kansas_pinafore" else -0.355
		_mi(_skirt_piv, _sphere(0.028, 10, 8), lace_mat, Vector3(sin(la) * lr, ly, cos(la) * lr), Vector3(1.2, 0.72, 0.85))

	# Sculpted Hourglass Corset / Waist Sash + Back Bow Rig
	if active_outfit == "kansas_pinafore":
		_mi(_hip, _cyl(waist_w * 1.06, waist_w * 1.12, 0.055, 24), lace_mat, Vector3(0, 0.065, 0))
	else:
		_mi(_hip, _cyl(waist_w * 1.06, hip_w * 0.82, 0.165, 28), corset_mat, Vector3(0, 0.075, 0))
		_mi(_hip, _torus(waist_w * 1.02, waist_w * 1.11, 24), trim_metal, Vector3(0, 0.155, 0), Vector3(1.0, 0.45, 1.0))
		_mi(_hip, _torus(hip_w * 0.76, hip_w * 0.84, 24), trim_metal, Vector3(0, -0.002, 0), Vector3(1.0, 0.45, 1.0))
		if active_outfit == "dorothy_velvet":
			# Front crimson panel + gold X-lacing across corset
			_mi(_hip, _cyl(waist_w * 1.08, hip_w * 0.83, 0.16, 20), main_fabric, Vector3(0, 0.075, -0.015), Vector3(0.55, 1.0, 0.98))
			for xi in range(3):
				var xy := 0.03 + float(xi) * 0.045
				_mi(_hip, _capsule(0.006, 0.085, 8), trim_metal, Vector3(0, xy, -0.132), Vector3.ONE, Vector3(0, 0, 58))
				_mi(_hip, _capsule(0.006, 0.085, 8), trim_metal, Vector3(0, xy, -0.132), Vector3.ONE, Vector3(0, 0, -58))
		elif active_outfit == "dorothy_sovereign":
			# Pearl-and-silver corset buttons
			for bi in range(4):
				_mi(_hip, _sphere(0.010, 10, 8), trim_metal, Vector3(0, 0.02 + float(bi) * 0.038, -0.134))
		else:
			# Ornate antique-gold filigree buckle + corset boning ribs (char_05 inset!)
			_mi(_hip, _torus(0.024, 0.038, 16), trim_metal, Vector3(0, 0.075, -0.136), Vector3(1.25, 0.95, 0.55), Vector3(90, 0, 0))
			_mi(_hip, _sphere(0.014, 12, 8), trim_metal, Vector3(0, 0.075, -0.142))
			for s_bone in [-1.0, 1.0]:
				_mi(_hip, _capsule(0.005, 0.14, 8), trim_metal, Vector3(float(s_bone) * 0.055, 0.075, -0.122), Vector3.ONE, Vector3(0, 0, float(s_bone) * -6.0))
			# Back corset crisscross lacing
			for bi in range(3):
				var by := 0.04 + float(bi) * 0.04
				_mi(_hip, _capsule(0.005, 0.065, 8), trim_metal, Vector3(0, by, 0.132), Vector3.ONE, Vector3(0, 0, 55))
				_mi(_hip, _capsule(0.005, 0.065, 8), trim_metal, Vector3(0, by, 0.132), Vector3.ONE, Vector3(0, 0, -55))

	# Lush Sculpted Back Bow + Physics-Swaying Ribbon Sashes
	var bow_mat := lace_mat if active_outfit == "kansas_pinafore" else corset_mat
	_bow_tails_piv = Node3D.new()
	_bow_tails_piv.name = "BowTailsPivot"
	_bow_tails_piv.position = Vector3(0, 0.055, 0.148)
	_hip.add_child(_bow_tails_piv)
	_mi(_bow_tails_piv, _sphere(0.032, 14, 10), bow_mat, Vector3(0, 0.01, 0.01))
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		_mi(_bow_tails_piv, _torus(0.032, 0.052, 16), bow_mat, Vector3(s * 0.068, 0.018, 0.018), Vector3(1.25, 0.78, 0.52), Vector3(12, s * -16, s * 18))
		_mi(_bow_tails_piv, _capsule(0.022, 0.24, 12), bow_mat, Vector3(s * 0.052, -0.115, 0.028), Vector3(1.15, 1.0, 0.35), Vector3(10, 0, s * -14))

	# Holstered Coiled Crimson Lace Whip + Engraved Brass Hilt & Ruby Tip (dorothy_velvet & dorothy_whip_plus!)
	if show_whip_holster:
		var whip_holster := Node3D.new()
		whip_holster.name = "WhipHolster"
		whip_holster.position = Vector3(0.165, 0.01, -0.02)
		whip_holster.rotation_degrees = Vector3(14, 12, -68)
		_hip.add_child(whip_holster)
		var whip_cord := _mat(Color(0.62, 0.08, 0.16), 0.42, 0.08)
		var ruby_glow := _mat(Color(0.96, 0.10, 0.24), 0.08, 0.20, Color(1.0, 0.14, 0.30), 1.85)
		for ci in range(3):
			var cr := 0.072 - float(ci) * 0.016
			_mi(whip_holster, _torus(cr - 0.011, cr, 20), whip_cord, Vector3(0, float(ci) * 0.008, 0))
		# Engraved brass hilt + knuckle guard + faceted ruby tip (shop_dorothy_whip_plus.png)
		_mi(whip_holster, _capsule(0.013, 0.14, 12), trim_metal, Vector3(-0.065, 0.02, -0.04), Vector3.ONE, Vector3(90, 28, 0))
		_mi(whip_holster, _torus(0.024, 0.030, 12), trim_metal, Vector3(-0.045, 0.025, -0.01), Vector3(1.0, 0.6, 1.0))
		_mi(whip_holster, _sphere(0.018, 12, 10), ruby_glow, Vector3(0.01, 0.02, 0.01), Vector3(0.85, 0.85, 1.45))

	# ========================================================================
	# 2. TORSO, BODICE, TUCKED PLASTRON, CHOKER & HIGH COLLAR
	# ========================================================================
	_torso = Node3D.new()
	_torso.name = "Torso"
	_torso.position = Vector3(0, 0.10, 0)
	_hip.add_child(_torso)

	# Ribcage & upper bodice contour
	_mi(_torso, _cyl(0.138, waist_w * 1.04, 0.22, 28), main_fabric, Vector3(0, 0.12, 0))
	if mature_silhouette:
		for sx in [-1.0, 1.0]:
			_mi(_torso, _sphere(0.094, 20, 14), main_fabric, Vector3(float(sx) * 0.074, 0.235, -0.052), Vector3(1.06, 0.92, 1.02))

	# Ivory tucked front blouse yoke / plastron + tiny buttons + gold V-trim
	if active_outfit == "dorothy_sovereign":
		# Exposed collarbone + celestial silver starburst necklace + high standing scalloped lace collar!
		_mi(_torso, _cyl(0.118, 0.135, 0.11, 24), skin, Vector3(0, 0.30, -0.01))
		_mi(_torso, _sphere(0.018, 12, 10), trim_metal, Vector3(0, 0.285, -0.118), Vector3(1.2, 1.2, 0.45))
		for ri in range(4):
			_mi(_torso, _capsule(0.003, 0.055, 6), trim_metal, Vector3(0, 0.285, -0.118), Vector3.ONE, Vector3(0, 0, float(ri) * 45.0))
		# Standing Elizabethan/Victorian silver-lace fan collar behind neck & shoulders (shop_dorothy_sovereign)
		for ci in range(-4, 5):
			var ca := float(ci) * 0.28
			_mi(_torso, _sphere(0.042, 12, 10), lace_mat, Vector3(sin(ca) * 0.115, 0.41 + cos(ca) * 0.02, cos(ca) * 0.095 + 0.03), Vector3(0.75, 1.35, 0.25), Vector3(-22, rad_to_deg(ca), 0))
	elif active_outfit == "dorothy_velvet":
		# Sweetheart neckline skin decolletage + crimson velvet choker + dangling gold key charm (char_03!)
		_mi(_torso, _cyl(0.112, 0.132, 0.10, 24), skin, Vector3(0, 0.305, -0.01))
		for sx in [-1.0, 1.0]:
			_mi(_torso, _capsule(0.014, 0.16, 10), trim_metal, Vector3(float(sx) * 0.075, 0.24, -0.098), Vector3.ONE, Vector3(12, 0, float(sx) * -18.0))
	else:
		# Oz Seeker / Kansas tucked ivory plastron with pearl buttons & ruffled lace high collar (char_05 & char_07)
		_mi(_torso, _cyl(0.118, 0.136, 0.14, 24), blouse_mat, Vector3(0, 0.285, -0.012), Vector3(0.86, 1.0, 1.04))
		for bi in range(4):
			_mi(_torso, _sphere(0.0075, 10, 8), trim_metal, Vector3(0, 0.235 + float(bi) * 0.034, -0.132))
		if active_outfit != "kansas_pinafore":
			for sx in [-1.0, 1.0]:
				_mi(_torso, _capsule(0.006, 0.15, 8), trim_metal, Vector3(float(sx) * 0.058, 0.275, -0.118), Vector3.ONE, Vector3(14, 0, float(sx) * -22.0))
		else:
			# Kansas ruffled pinafore shoulder straps
			for sx in [-1.0, 1.0]:
				_mi(_torso, _torus(0.055, 0.075, 16), main_fabric, Vector3(float(sx) * 0.115, 0.31, 0.0), Vector3(0.45, 1.25, 1.15), Vector3(0, 90, 0))
		# High Victorian ruffled ivory lace collar
		_mi(_torso, _cyl(0.062, 0.078, 0.048, 24), lace_mat, Vector3(0, 0.375, 0))

	# Signature Velvet Choker + Gold Cameo / Key Pendant (Oz Seeker & Red Seeker!)
	if not is_kansas_plain:
		var choker_col := corset_mat if active_outfit != "dorothy_sovereign" else trim_metal
		_mi(_torso, _torus(0.050, 0.058, 20), choker_col, Vector3(0, 0.392, 0))
		_mi(_torso, _sphere(0.012, 12, 10), trim_metal, Vector3(0, 0.388, -0.058), Vector3(0.9, 1.2, 0.5))
		if active_outfit == "dorothy_velvet":
			_mi(_torso, _capsule(0.004, 0.032, 8), trim_metal, Vector3(0, 0.362, -0.062))

	# Gathered Victorian Puff Shoulders
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		_mi(_torso, _sphere(0.092, 20, 14), sleeve_upper_mat, Vector3(s * 0.168, 0.325, 0), Vector3(1.08, 0.92, 0.96))
		if active_outfit == "dorothy_velvet":
			# Gold bullion fringe ring beneath crimson puff sleeve (char_03!)
			_mi(_torso, _torus(0.064, 0.074, 18), trim_metal, Vector3(s * 0.182, 0.265, 0), Vector3.ONE, Vector3(0, 0, s * -12.0))

	# ========================================================================
	# 3. SCULPTED 2026 HEAD, FACIAL ANATOMY & SPRING-PHYSICS TWIN BRAIDS
	# ========================================================================
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.44, 0)
	_torso.add_child(_head)

	# Slender neck
	_mi(_head, _cyl(0.043, 0.050, 0.11, 20), skin, Vector3(0, 0.015, 0))

	# Heart-shaped sculpted feminine cranium + tapered jawline & delicate chin
	_mi(_head, _sphere(0.116, 28, 18), skin, Vector3(0, 0.158, -0.004), Vector3(0.96, 1.08, 0.98))
	_mi(_head, _sphere(0.086, 24, 14), skin, Vector3(0, 0.105, -0.026), Vector3(0.90, 0.92, 0.92))
	_mi(_head, _sphere(0.038, 16, 12), skin, Vector3(0, 0.058, -0.068), Vector3(0.92, 0.78, 0.95)) # chin contour

	# Delicate ears + silver/ruby stud earrings
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		_mi(_head, _sphere(0.026, 12, 10), skin, Vector3(s * 0.110, 0.145, -0.005), Vector3(0.42, 0.95, 0.68), Vector3(0, s * -14.0, s * -8.0))
		_mi(_head, _sphere(0.014, 10, 8), ear_inner, Vector3(s * 0.113, 0.145, -0.008), Vector3(0.35, 0.75, 0.50))
		if not is_kansas_plain:
			_mi(_head, _sphere(0.007, 10, 8), trim_metal, Vector3(s * 0.114, 0.122, -0.008))

	# Sculpted Nose Bridge + Upturned Tip + Subtle Nostril Wings
	_mi(_head, _capsule(0.011, 0.048, 12), skin, Vector3(0, 0.145, -0.112), Vector3(0.85, 1.0, 0.95), Vector3(-16, 0, 0))
	_mi(_head, _sphere(0.0145, 14, 10), skin, Vector3(0, 0.126, -0.126), Vector3(0.95, 0.82, 1.05))

	# Rosy Cheekbones + Delicate Sun-Kissed Prairie Freckles across nose & cheeks (char_05 & char_07!)
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		_mi(_head, _sphere(0.032, 14, 10), cheek_mat, Vector3(s * 0.064, 0.125, -0.092), Vector3(1.05, 0.68, 0.42))
		for fi in range(3):
			var fx := s * (0.032 + float(fi) * 0.016)
			var fy := 0.132 - float(fi % 2) * 0.007
			_mi(_head, _sphere(0.0028, 6, 6), freckle_mat, Vector3(fx, fy, -0.114 + float(fi) * 0.005))

	# Sculpted Cupid's-Bow Upper Lip & Full Lower Lip
	for sx in [-1.0, 1.0]:
		_mi(_head, _sphere(0.011, 12, 8), lip_upper, Vector3(float(sx) * 0.009, 0.097, -0.114), Vector3(1.35, 0.52, 0.75), Vector3(0, 0, float(sx) * -10.0))
	_mi(_head, _sphere(0.0135, 14, 10), lip_lower, Vector3(0, 0.089, -0.113), Vector3(1.65, 0.58, 0.80))

	# Expressive Almond Eyes: Sclera + Dual-Tone Iris + Obsidian Pupil + Twin Catchlights + Upper Lash + Animated Eyelids + Brows!
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		var ex := s * 0.041
		var ey := 0.158
		var ez := -0.102
		_mi(_head, _sphere(0.022, 16, 12), sclera, Vector3(ex, ey, ez), Vector3(1.12, 0.88, 0.68))
		_mi(_head, _sphere(0.0135, 14, 10), iris_outer, Vector3(ex, ey, ez - 0.011), Vector3(1.0, 1.02, 0.35))
		_mi(_head, _sphere(0.0098, 12, 8), iris_inner, Vector3(ex, ey - 0.001, ez - 0.0135), Vector3(1.0, 1.0, 0.30))
		_mi(_head, _sphere(0.0058, 10, 8), pupil_mat, Vector3(ex, ey, ez - 0.0152), Vector3(1.0, 1.05, 0.25))
		# Primary & secondary specular catchlights (brings instant 2026 soul to the gaze!)
		_mi(_head, _sphere(0.0032, 8, 6), glint_mat, Vector3(ex - s * 0.004, ey + 0.0045, ez - 0.017))
		_mi(_head, _sphere(0.0018, 6, 6), glint_mat, Vector3(ex + s * 0.0035, ey - 0.0035, ez - 0.0168))
		# Curved dark upper lash line
		_mi(_head, _torus(0.017, 0.0205, 14), lash_mat, Vector3(ex, ey + 0.003, ez - 0.006), Vector3(1.18, 0.72, 0.45), Vector3(78, 0, s * -8.0))

		# Blinking Eyelid shell
		var lid := Node3D.new()
		lid.name = "EyelidL" if s < 0.0 else "EyelidR"
		lid.position = Vector3(ex, ey + 0.002, ez - 0.002)
		lid.visible = false
		_head.add_child(lid)
		_mi(lid, _sphere(0.023, 14, 10), skin, Vector3.ZERO, Vector3(1.14, 0.88, 0.72))
		if s < 0.0:
			_eyelid_l = lid
		else:
			_eyelid_r = lid

		# Sculpted Arched Chestnut Eyebrow
		var brow := Node3D.new()
		brow.name = "BrowL" if s < 0.0 else "BrowR"
		brow.position = Vector3(ex, ey + 0.026, ez - 0.008)
		_head.add_child(brow)
		_mi(brow, _capsule(0.0042, 0.038, 10), hair_dark, Vector3.ZERO, Vector3(1.0, 1.0, 0.55), Vector3(0, s * -12.0, 90.0 + s * 8.0))
		if s < 0.0:
			_brow_l = brow
		else:
			_brow_r = brow

	# Crown-Parted Chestnut Hair Waves & Face-Framing Wisps (char_05 & dorothy_bust_hd!)
	_mi(_head, _sphere(0.124, 28, 18), hair_dark, Vector3(0, 0.176, 0.016), Vector3(1.04, 1.02, 1.08))
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		# Swept crown wave lobes creating a clean center part!
		_mi(_head, _sphere(0.078, 20, 12), hair_hi if s > 0 else hair_dark, Vector3(s * 0.056, 0.218, -0.028), Vector3(1.05, 0.68, 1.18), Vector3(14, s * -18, s * -16))
		_mi(_head, _capsule(0.032, 0.135, 14), hair_dark, Vector3(s * 0.098, 0.168, -0.022), Vector3(0.75, 1.0, 1.08), Vector3(18, 0, s * 16))
		# Delicate temple curl wisp framing cheekbones
		_mi(_head, _capsule(0.008, 0.068, 10), hair_dark, Vector3(s * 0.098, 0.125, -0.068), Vector3.ONE, Vector3(16, 0, s * 12))

	# Articulated 4-Segment Woven Twin Braids Draping Over Her Shoulders + Silk Ribbon Bows!
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		var parent_j: Node3D = _head
		var anchor_pos := Vector3(s * 0.106, 0.105, -0.015)
		for ji in range(4):
			var j := Node3D.new()
			j.name = "%s_%d" % [("BraidL" if s < 0 else "BraidR"), ji]
			j.position = anchor_pos if ji == 0 else Vector3(s * 0.006, -0.068, -0.012 if ji < 2 else 0.004)
			parent_j.add_child(j)
			var r_plait := lerpf(0.028, 0.017, float(ji) / 3.0)
			# Overlapping diagonal woven plait lobes (reads as true braided hair, never balls-on-a-string!)
			_mi(j, _sphere(r_plait, 14, 10), hair_dark, Vector3(-0.005, -0.020, 0), Vector3(0.95, 1.35, 0.88), Vector3(0, 0, 22))
			_mi(j, _sphere(r_plait * 0.96, 14, 10), hair_hi, Vector3(0.005, -0.046, -0.002), Vector3(0.95, 1.35, 0.88), Vector3(0, 0, -22))
			if ji == 3:
				# Curved Silk Ribbon Bow + Twin Fluttering Tails + Tapered Brush Tip!
				_mi(j, _sphere(0.012, 10, 8), ribbon_mat, Vector3(0, -0.060, -0.008))
				for bs in [-1.0, 1.0]:
					_mi(j, _torus(0.011, 0.019, 12), ribbon_mat, Vector3(float(bs) * 0.022, -0.058, -0.010), Vector3(1.2, 0.75, 0.50), Vector3(0, float(bs) * -15, float(bs) * 18))
					_mi(j, _capsule(0.0055, 0.052, 8), ribbon_mat, Vector3(float(bs) * 0.016, -0.088, -0.010), Vector3(1.1, 1.0, 0.4), Vector3(8, 0, float(bs) * -18))
				_mi(j, _cyl(0.014, 0.003, 0.062, 12), hair_dark, Vector3(0, -0.095, 0))
			if s < 0.0:
				_braid_l_joints.append(j)
			else:
				_braid_r_joints.append(j)
			parent_j = j

	# ========================================================================
	# 4. ARTICULATED ARMS, CUFFS, HANDS & SCULPTED FINGERS
	# ========================================================================
	_arm_l = _make_arm(_torso, true, skin, sleeve_lower_mat, corset_mat, lace_mat, trim_metal, is_kansas_plain)
	_arm_r = _make_arm(_torso, false, skin, sleeve_lower_mat, corset_mat, lace_mat, trim_metal, is_kansas_plain)

	# ========================================================================
	# 5. LEGS, FISHNET/SPARKLE STOCKINGS & SILVER SHOES / BOOTS
	# ========================================================================
	_leg_l = _make_leg(_hip, true, stocking_mat, shoe_mat, trim_metal, active_outfit)
	_leg_r = _make_leg(_hip, false, stocking_mat, shoe_mat, trim_metal, active_outfit)

	var mount := Marker3D.new()
	mount.name = "BasketMount"
	mount.position = Vector3(0.32, 0.02, 0.06)
	_hip.add_child(mount)

func _make_arm(
	parent: Node3D,
	left: bool,
	skin: Material,
	sleeve_mat: Material,
	cuff_mat: Material,
	lace_mat: Material,
	trim_metal: Material,
	is_kansas_plain: bool
) -> Node3D:
	var sign_f := -1.0 if left else 1.0
	var root := Node3D.new()
	root.name = "ArmL" if left else "ArmR"
	root.position = Vector3(0.185 * sign_f, 0.33, 0)
	parent.add_child(root)

	var upper := Node3D.new()
	upper.name = "Upper"
	root.add_child(upper)
	_mi(upper, _capsule(0.042, 0.29, 18), sleeve_mat if not is_kansas_plain else lace_mat, Vector3(0, -0.135, 0))
	if is_kansas_plain:
		# Rolled-up prairie blouse sleeve cuff at elbow (char_07!)
		_mi(upper, _torus(0.038, 0.050, 16), lace_mat, Vector3(0, -0.245, 0))

	var lower := Node3D.new()
	lower.name = "Lower"
	lower.position = Vector3(0, -0.265, 0)
	upper.add_child(lower)
	_mi(lower, _cyl(0.035, 0.027, 0.24, 18), sleeve_mat, Vector3(0, -0.12, 0))

	if not is_kansas_plain:
		# Fitted Victorian wrist cuff + gold trim + delicate white/black lace frill!
		_mi(lower, _cyl(0.032, 0.030, 0.048, 18), cuff_mat, Vector3(0, -0.215, 0))
		_mi(lower, _torus(0.028, 0.033, 16), trim_metal, Vector3(0, -0.192, 0))
		_mi(lower, _cyl(0.029, 0.038, 0.024, 18), lace_mat, Vector3(0, -0.244, 0))

	# Sculpted Feminine Hand: Contoured Palm + Thumb + 4 Tapered Fingers!
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0, -0.268, 0)
	lower.add_child(hand)
	_mi(hand, _sphere(0.026, 14, 10), skin, Vector3(0, -0.012, 0), Vector3(0.88, 1.12, 0.56))
	# Thumb
	_mi(hand, _capsule(0.0068, 0.034, 8), skin, Vector3(-sign_f * 0.020, -0.018, -0.010), Vector3.ONE, Vector3(22, 0, sign_f * 32.0))
	# 4 Articulated-silhouette fingers (Index, Middle, Ring, Pinky)
	var finger_lens := [0.038, 0.042, 0.039, 0.032]
	for fi in range(4):
		var fx := (float(fi) - 1.5) * 0.0095 * sign_f
		var fl: float = finger_lens[fi]
		_mi(hand, _capsule(0.0052, fl, 8), skin, Vector3(fx, -0.034 - fl * 0.32, -0.003), Vector3.ONE, Vector3(10, 0, 0))
	return root

func _make_leg(
	parent: Node3D,
	left: bool,
	stocking_mat: Material,
	shoe_mat: Material,
	trim_metal: Material,
	active_outfit: String
) -> Node3D:
	var sign_f := -1.0 if left else 1.0
	var root := Node3D.new()
	root.name = "LegL" if left else "LegR"
	root.position = Vector3(0.098 * sign_f, -0.08, 0)
	parent.add_child(root)

	var thigh := Node3D.new()
	thigh.name = "Thigh"
	root.add_child(thigh)
	_mi(thigh, _cyl(0.078, 0.056, 0.36, 22), stocking_mat, Vector3(0, -0.18, 0))
	_mi(thigh, _sphere(0.055, 16, 12), stocking_mat, Vector3(0, -0.36, 0)) # smooth knee cap

	var calf := Node3D.new()
	calf.name = "Calf"
	calf.position = Vector3(0, -0.36, 0)
	thigh.add_child(calf)
	# Anatomically contoured calf muscle taper
	_mi(calf, _sphere(0.054, 18, 12), stocking_mat, Vector3(0, -0.105, 0.008), Vector3(0.92, 1.75, 1.02))
	_mi(calf, _cyl(0.048, 0.033, 0.33, 20), stocking_mat, Vector3(0, -0.17, 0))

	var shoe := Node3D.new()
	shoe.name = "StilettoShoe"
	shoe.position = Vector3(0, -0.345, 0)
	calf.add_child(shoe)

	if active_outfit == "kansas_pinafore":
		# Scuffed Ankle-High Lace-Up Leather Prairie Boots (char_07_dorothy_kansas.jpg!)
		_mi(shoe, _cyl(0.043, 0.046, 0.13, 18), shoe_mat, Vector3(0, 0.045, 0))
		_mi(shoe, _sphere(0.050, 18, 12), shoe_mat, Vector3(0, -0.022, -0.052), Vector3(0.95, 0.68, 1.65))
		_mi(shoe, _cyl(0.046, 0.048, 0.024, 18), _mat(Color(0.14, 0.13, 0.12), 0.85), Vector3(0, -0.044, -0.035), Vector3(0.96, 1.0, 1.65))
		_mi(shoe, _cyl(0.032, 0.034, 0.045, 14), _mat(Color(0.14, 0.13, 0.12), 0.85), Vector3(0, -0.035, 0.032))
		for li in range(3):
			_mi(shoe, _capsule(0.004, 0.042, 6), trim_metal, Vector3(0, 0.02 + float(li) * 0.028, -0.044), Vector3.ONE, Vector3(0, 0, 90))
	else:
		# Canonical Sculpted Silver Shoes / Victorian Heeled Silver Boots (char_05 & char_03!)
		if active_outfit == "dorothy_velvet":
			# High lace-up silver boot shaft!
			_mi(shoe, _cyl(0.044, 0.041, 0.145, 20), shoe_mat, Vector3(0, 0.055, 0))
			for li in range(4):
				_mi(shoe, _capsule(0.004, 0.038, 6), trim_metal, Vector3(0, 0.015 + float(li) * 0.028, -0.042), Vector3.ONE, Vector3(0, 0, 90))
		else:
			# Delicate arched silver instep Mary-Jane / Louis strap
			_mi(shoe, _torus(0.034, 0.042, 18), shoe_mat, Vector3(0, 0.016, -0.015), Vector3(0.95, 0.65, 1.15), Vector3(24, 0, 0))
		# Sleek pointed silver toe vamp & arched sole
		_mi(shoe, _sphere(0.048, 20, 14), shoe_mat, Vector3(0, -0.022, -0.062), Vector3(0.88, 0.56, 1.88), Vector3(14, 0, 0))
		_mi(shoe, _sphere(0.038, 16, 12), shoe_mat, Vector3(0, 0.002, 0.026), Vector3(0.92, 0.85, 1.05)) # heel cup
		# Sculpted curved Louis / stiletto silver heel!
		_mi(shoe, _cyl(0.020, 0.009, 0.095, 16), shoe_mat, Vector3(0, -0.032, 0.038), Vector3.ONE, Vector3(-8, 0, 0))
		# Ornate engraved filigree instep buckle (char_05 inset!)
		_mi(shoe, _torus(0.013, 0.020, 14), trim_metal, Vector3(0, 0.012, -0.048), Vector3(1.15, 0.85, 0.55), Vector3(68, 0, 0))

	return root

# ============================================================================
# COUTURE SPATIAL SHADERS (WOVEN GINGHAM, CRUSHED VELVET, IRIDESCENT SATIN)
# ============================================================================

func _make_gingham_material(c_dark: Color, c_light: Color, c_mid: Color) -> ShaderMaterial:
	if _gingham_shader == null:
		_gingham_shader = Shader.new()
		_gingham_shader.code = """
shader_type spatial;
uniform vec4 col_dark : source_color = vec4(0.19, 0.36, 0.68, 1.0);
uniform vec4 col_mid : source_color = vec4(0.46, 0.63, 0.86, 1.0);
uniform vec4 col_light : source_color = vec4(0.94, 0.96, 0.99, 1.0);
void fragment() {
	vec2 uv = UV * 18.0;
	float sx = smoothstep(0.46, 0.54, fract(uv.x));
	float sy = smoothstep(0.46, 0.54, fract(uv.y));
	// Authentic 3-tone woven gingham check (dark intersection, mid warp/weft, ivory ground)
	vec3 base = mix(col_dark.rgb, col_mid.rgb, clamp(sx + sy, 0.0, 1.0));
	base = mix(base, col_light.rgb, sx * sy);
	// Micro linen thread weave
	float thread = sin(UV.x * 260.0) * sin(UV.y * 260.0) * 0.028;
	ALBEDO = clamp(base + thread, vec3(0.0), vec3(1.0));
	ROUGHNESS = 0.68;
	RIM = 0.24;
	RIM_TINT = 0.35;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _gingham_shader
	sm.set_shader_parameter("col_dark", _col(c_dark))
	sm.set_shader_parameter("col_mid", _col(c_mid))
	sm.set_shader_parameter("col_light", _col(c_light))
	return sm

func _make_velvet_material(c_core: Color, c_rim: Color) -> ShaderMaterial:
	if _velvet_shader == null:
		_velvet_shader = Shader.new()
		_velvet_shader.code = """
shader_type spatial;
uniform vec4 core_col : source_color = vec4(0.46, 0.04, 0.10, 1.0);
uniform vec4 sheen_col : source_color = vec4(0.84, 0.14, 0.24, 1.0);
void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	float nap = sin(UV.x * 95.0 + sin(UV.y * 45.0)) * 0.025;
	ALBEDO = mix(core_col.rgb + nap, sheen_col.rgb, fresnel * 0.72);
	ROUGHNESS = mix(0.76, 0.38, fresnel);
	RIM = 0.58;
	RIM_TINT = 0.65;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _velvet_shader
	sm.set_shader_parameter("core_col", _col(c_core))
	sm.set_shader_parameter("sheen_col", _col(c_rim))
	return sm

func _make_satin_material(c_base: Color, c_pearl: Color) -> ShaderMaterial:
	if _satin_shader == null:
		_satin_shader = Shader.new()
		_satin_shader.code = """
shader_type spatial;
uniform vec4 base_col : source_color = vec4(0.62, 0.54, 0.76, 1.0);
uniform vec4 pearl_col : source_color = vec4(0.92, 0.88, 1.0, 1.0);
void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.8);
	float star_speck = smoothstep(0.96, 1.0, sin(UV.x * 140.0) * cos(UV.y * 140.0));
	ALBEDO = mix(base_col.rgb, pearl_col.rgb, fresnel * 0.68) + vec3(star_speck * 0.25);
	METALLIC = 0.24;
	ROUGHNESS = 0.24;
	RIM = 0.52;
	RIM_TINT = 0.55;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _satin_shader
	sm.set_shader_parameter("base_col", _col(c_base))
	sm.set_shader_parameter("pearl_col", _col(c_pearl))
	return sm
