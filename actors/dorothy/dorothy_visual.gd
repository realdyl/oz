extends Node3D

## Full-body Dorothy — M-rated adult (18+). Feminine, badass farm-girl silhouette
## with diamond-lattice fishnet stockings, high-heeled silver stilettos,
## multi-joint walk/run/idle breathing, high roundhouse stiletto kick, and interact reach.

const WorldKit := preload("res://systems/world_kit.gd")

@export var greyscale: bool = false
@export var show_silver_shoes: bool = false
@export var mature_silhouette: bool = true

var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _hip: Node3D
var _torso: Node3D
var _head: Node3D
var _phase: float = 0.0
var _idle_t: float = 0.0
var _speed_amt: float = 0.0
var _kick_t: float = 0.0
var _interact_t: float = 0.0
var sleeping: bool = false

const KICK_DUR := 0.34
const INTERACT_DUR := 0.36

func _ready() -> void:
	for c in get_children():
		c.free()
	_build()

func play_kick() -> void:
	_kick_t = KICK_DUR

func play_interact() -> void:
	_interact_t = INTERACT_DUR

func set_sleeping(on: bool) -> void:
	sleeping = on
	_apply_pose()

func set_locomotion(horizontal_speed: float, delta: float) -> void:
	_idle_t += delta
	_kick_t = maxf(_kick_t - delta, 0.0)
	_interact_t = maxf(_interact_t - delta, 0.0)
	_speed_amt = clampf(horizontal_speed / 5.0, 0.0, 1.45) if not sleeping else 0.0
	if _speed_amt > 0.08:
		_phase += delta * (8.8 + _speed_amt * 5.8)
	else:
		_phase = move_toward(_phase, 0.0, delta * 5.0)
		_speed_amt = move_toward(_speed_amt, 0.0, delta * 4.0)
	_apply_pose()

func _apply_pose() -> void:
	if _leg_l == null:
		return

	if sleeping:
		# Smoothly curled up lying down on her side in the poppies
		var breath := sin(_idle_t * 1.9) * 0.012
		_hip.position = Vector3(0, 0.20 + breath, 0)
		_hip.rotation = Vector3(-1.46, 0.15, 0.45) # lying down on ground
		_torso.rotation = Vector3(0.18, 0.0, 0.12)
		_leg_l.rotation = Vector3(-0.45, 0.0, 0.08)
		_leg_r.rotation = Vector3(-0.68, 0.0, -0.08)
		if _leg_l.has_node("Thigh/Calf"):
			(_leg_l.get_node("Thigh/Calf") as Node3D).rotation.x = 0.72
		if _leg_r.has_node("Thigh/Calf"):
			(_leg_r.get_node("Thigh/Calf") as Node3D).rotation.x = 0.88
		_arm_l.rotation = Vector3(-0.65, 0.0, 0.25)
		_arm_r.rotation = Vector3(-0.85, 0.0, -0.35)
		return

	_hip.rotation.x = 0.0
	_hip.rotation.z = 0.0

	# Priority 1: Choreographed High-Heel Roundhouse / Snap Kick
	if _kick_t > 0.0:
		var u := 1.0 - (_kick_t / KICK_DUR) # 0 -> 1
		var kick_arc := sin(clampf(u * 1.25, 0.0, 1.0) * PI)
		# Pivot hips, counter-lean torso, whip right fishnet leg & stiletto high!
		_hip.position.y = 0.80 + kick_arc * 0.06
		_hip.rotation.y = -0.58 * kick_arc
		_torso.rotation.x = 0.28 * kick_arc
		_torso.rotation.z = -0.18 * kick_arc
		_leg_r.rotation.x = -1.65 * kick_arc # high forward/roundhouse kick!
		_leg_r.rotation.z = 0.32 * kick_arc
		if _leg_r.has_node("Thigh/Calf"):
			(_leg_r.get_node("Thigh/Calf") as Node3D).rotation.x = 0.12 * kick_arc
		_leg_l.rotation.x = 0.22 * kick_arc
		if _leg_l.has_node("Thigh/Calf"):
			(_leg_l.get_node("Thigh/Calf") as Node3D).rotation.x = 0.28 * kick_arc
		_arm_l.rotation.x = -0.85 * kick_arc
		_arm_r.rotation.x = 0.65 * kick_arc
		_arm_l.rotation.z = -0.45 * kick_arc
		_arm_r.rotation.z = 0.45 * kick_arc
		return

	# Reset kick twist smoothly
	_hip.rotation.y = sin(_phase * 0.5) * 0.06 * _speed_amt
	_torso.rotation.x = -0.12 * clampf(_speed_amt - 0.3, 0.0, 1.0)
	_torso.rotation.z = sin(_phase) * 0.04 * _speed_amt
	_leg_r.rotation.z = 0.0
	_arm_l.rotation.z = -0.08
	_arm_r.rotation.z = 0.08

	# Multi-joint Walk / Run / Idle Breathing
	var swing := sin(_phase) * 0.64 * _speed_amt
	var swing_a := sin(_phase + PI) * 0.55 * _speed_amt
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	if _leg_l.has_node("Thigh/Calf"):
		(_leg_l.get_node("Thigh/Calf") as Node3D).rotation.x = maxf(-swing, 0.0) * 0.78 + 0.06 * _speed_amt
	if _leg_r.has_node("Thigh/Calf"):
		(_leg_r.get_node("Thigh/Calf") as Node3D).rotation.x = maxf(swing, 0.0) * 0.78 + 0.06 * _speed_amt

	_arm_l.rotation.x = -swing_a * 0.92
	_arm_r.rotation.x = swing_a * 0.92
	if _arm_l.has_node("Upper/Lower"):
		(_arm_l.get_node("Upper/Lower") as Node3D).rotation.x = -0.25 - maxf(-swing_a, 0.0) * 0.45
	if _arm_r.has_node("Upper/Lower"):
		(_arm_r.get_node("Upper/Lower") as Node3D).rotation.x = -0.25 - maxf(swing_a, 0.0) * 0.45

	# Subtle idle breathing & head curiosity
	var breath := sin(_idle_t * 2.6) * 0.012
	_hip.position.y = 0.80 + absf(sin(_phase)) * 0.032 * _speed_amt + breath * (1.0 - clampf(_speed_amt, 0.0, 1.0))
	if _head:
		_head.rotation.y = sin(_idle_t * 1.1) * 0.08 * (1.0 - clampf(_speed_amt, 0.0, 1.0))

	# Natural E-interact hand reach gesture
	if _interact_t > 0.0:
		var iu := sin((1.0 - _interact_t / INTERACT_DUR) * PI)
		_arm_r.rotation.x = -1.15 * iu
		if _arm_r.has_node("Upper/Lower"):
			(_arm_r.get_node("Upper/Lower") as Node3D).rotation.x = -0.35 * iu

func _col(rgb: Color) -> Color:
	if greyscale:
		var l := rgb.r * 0.3 + rgb.g * 0.5 + rgb.b * 0.2
		return Color(l, l, l)
	return rgb

func _mat(color: Color, rough: float = 0.72, metal: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = _col(color)
	m.roughness = rough
	m.metallic = metal
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = _col(Color(0.82, 0.88, 1.0))
		m.emission_energy_multiplier = emission
	return m

func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	n.scale = scl
	parent.add_child(n)
	return n

func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 22
	s.rings = 12
	return s

func _cyl(t: float, b: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = t
	c.bottom_radius = b
	c.height = h
	c.radial_segments = 24
	return c

func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _build() -> void:
	var skin_rgb := Color(0.94, 0.74, 0.62)
	var skin := _mat(skin_rgb, 0.46)
	var fishnet := WorldKit.make_fishnet_material(skin_rgb, greyscale)
	var dress := _mat(Color(0.28, 0.44, 0.74), 0.70)
	var apron := _mat(Color(0.96, 0.94, 0.90), 0.62)
	var gingham := _mat(Color(0.42, 0.54, 0.80), 0.68)
	var hair := _mat(Color(0.16, 0.08, 0.05), 0.74)
	var heel_dark := _mat(Color(0.14, 0.10, 0.12), 0.36, 0.25)
	var shoe_s := _mat(Color(0.88, 0.92, 0.98), 0.14, 0.95, 0.75 if show_silver_shoes else 0.0)
	var eye := _mat(Color(0.18, 0.30, 0.48), 0.22)
	var white := _mat(Color(0.97, 0.97, 0.99), 0.30)
	var lip := _mat(Color(0.74, 0.24, 0.34), 0.40)
	var cheek := _mat(Color(0.92, 0.52, 0.52), 0.52)

	_hip = Node3D.new()
	_hip.name = "Hip"
	_hip.position = Vector3(0, 0.80, 0)
	add_child(_hip)

	var hip_w := 0.20 if mature_silhouette else 0.16
	var waist := 0.118 if mature_silhouette else 0.14
	var ribbon_mat := _mat(Color(0.20, 0.32, 0.64), 0.48)
	var trim_mat := _mat(Color(0.16, 0.26, 0.54), 0.62)

	_mi(_hip, _cyl(hip_w, hip_w * 0.92, 0.16), dress, Vector3(0, -0.04, 0))
	# Flared shorter gingham skirt (so fishnet stockings & silver stiletto heels are clearly visible!)
	_mi(_hip, _cyl(0.22, 0.36, 0.28), dress, Vector3(0, -0.22, 0))
	_mi(_hip, _cyl(0.35, 0.37, 0.038), trim_mat, Vector3(0, -0.35, 0))
	_mi(_hip, _cyl(0.33, 0.39, 0.05), apron, Vector3(0, -0.38, 0))

	# Front apron + wrap-around waist sash + sculpted storybook back bow & flowing ribbon tails
	_mi(_hip, _box(Vector3(0.26, 0.24, 0.045)), apron, Vector3(0, -0.17, -0.20))
	_mi(_hip, _cyl(0.15, 0.16, 0.06), apron, Vector3(0, 0.06, 0))
	_mi(_hip, _sphere(0.052), apron, Vector3(0, 0.06, 0.17))
	var bow_l := _mi(_hip, _sphere(0.075), apron, Vector3(-0.08, 0.07, 0.20), Vector3(1.15, 0.65, 0.45))
	bow_l.rotation_degrees = Vector3(0, 18, 16)
	var bow_r := _mi(_hip, _sphere(0.075), apron, Vector3(0.08, 0.07, 0.20), Vector3(1.15, 0.65, 0.45))
	bow_r.rotation_degrees = Vector3(0, -18, -16)
	var tail_l := _mi(_hip, _box(Vector3(0.06, 0.24, 0.022)), apron, Vector3(-0.055, -0.07, 0.22))
	tail_l.rotation_degrees = Vector3(14, 0, -12)
	var tail_r := _mi(_hip, _box(Vector3(0.06, 0.24, 0.022)), apron, Vector3(0.055, -0.07, 0.22))
	tail_r.rotation_degrees = Vector3(14, 0, 12)

	_torso = Node3D.new()
	_torso.name = "Torso"
	_torso.position = Vector3(0, 0.1, 0)
	_hip.add_child(_torso)
	_mi(_torso, _cyl(waist, 0.15, 0.2), dress, Vector3(0, 0.1, 0))
	if mature_silhouette:
		_mi(_torso, _sphere(0.105), dress, Vector3(-0.092, 0.26, -0.05), Vector3(1.18, 0.88, 1.05))
		_mi(_torso, _sphere(0.105), dress, Vector3(0.092, 0.26, -0.05), Vector3(1.18, 0.88, 1.05))
		_mi(_torso, _cyl(0.15, 0.135, 0.12), apron, Vector3(0, 0.28, 0))
	else:
		_mi(_torso, _cyl(0.15, 0.16, 0.3), apron, Vector3(0, 0.18, 0))
	_mi(_torso, _sphere(0.115), apron, Vector3(-0.175, 0.33, 0), Vector3(1.12, 0.82, 0.92))
	_mi(_torso, _sphere(0.115), apron, Vector3(0.175, 0.33, 0), Vector3(1.12, 0.82, 0.92))
	var strap_l := _mi(_torso, _box(Vector3(0.05, 0.34, 0.028)), dress, Vector3(-0.058, 0.20, 0.125))
	strap_l.rotation_degrees = Vector3(0, 0, 22)
	var strap_r := _mi(_torso, _box(Vector3(0.05, 0.34, 0.028)), dress, Vector3(0.058, 0.20, 0.125))
	strap_r.rotation_degrees = Vector3(0, 0, -22)
	_mi(_torso, _box(Vector3(0.19, 0.07, 0.14)), gingham, Vector3(0, 0.18, -0.03))
	_mi(_torso, _cyl(0.092, 0.12, 0.042), apron, Vector3(0, 0.36, 0))

	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.50, 0)
	_torso.add_child(_head)
	_mi(_head, _cyl(0.044, 0.054, 0.09), skin, Vector3(0, 0.02, 0))
	_mi(_head, _sphere(0.126), skin, Vector3(0, 0.15, 0), Vector3(1.0, 1.14, 0.95))
	_mi(_head, _sphere(0.136), hair, Vector3(0, 0.20, 0.01), Vector3(1.14, 0.94, 1.12))
	for sx in [-1.0, 1.0]:
		var s: float = float(sx)
		_mi(_head, _sphere(0.074), hair, Vector3(s * 0.142, 0.07, 0.04), Vector3(0.85, 1.55, 0.85))
		_mi(_head, _sphere(0.060), hair, Vector3(s * 0.152, -0.06, 0.05), Vector3(0.75, 1.35, 0.75))
		_mi(_head, _sphere(0.044), hair, Vector3(s * 0.152, -0.17, 0.05), Vector3(0.65, 1.15, 0.65))
		_mi(_head, _box(Vector3(0.088, 0.042, 0.038)), ribbon_mat, Vector3(s * 0.148, 0.12, 0.08))
		_mi(_head, _box(Vector3(0.062, 0.032, 0.032)), ribbon_mat, Vector3(s * 0.152, -0.14, 0.07))
	_mi(_head, _sphere(0.029), white, Vector3(-0.042, 0.16, -0.106))
	_mi(_head, _sphere(0.029), white, Vector3(0.042, 0.16, -0.106))
	_mi(_head, _sphere(0.016), eye, Vector3(-0.042, 0.16, -0.121))
	_mi(_head, _sphere(0.016), eye, Vector3(0.042, 0.16, -0.121))
	_mi(_head, _sphere(0.036), cheek, Vector3(-0.072, 0.118, -0.08), Vector3(1.0, 0.7, 0.55))
	_mi(_head, _sphere(0.036), cheek, Vector3(0.072, 0.118, -0.08), Vector3(1.0, 0.7, 0.55))
	_mi(_head, _sphere(0.019), lip, Vector3(0, 0.098, -0.116), Vector3(1.9, 0.55, 0.75))

	_arm_l = _make_arm(_torso, true, skin, apron)
	_arm_r = _make_arm(_torso, false, skin, apron)
	var heel_mat := shoe_s if show_silver_shoes else heel_dark
	_leg_l = _make_leg(_hip, true, fishnet, heel_mat)
	_leg_r = _make_leg(_hip, false, fishnet, heel_mat)

	var mount := Marker3D.new()
	mount.name = "BasketMount"
	mount.position = Vector3(0.32, 0.02, 0.06)
	_hip.add_child(mount)

func _make_arm(parent: Node3D, left: bool, skin: Material, sleeve: Material) -> Node3D:
	var sign := -1.0 if left else 1.0
	var root := Node3D.new()
	root.name = "ArmL" if left else "ArmR"
	root.position = Vector3(0.20 * sign, 0.34, 0)
	parent.add_child(root)
	var upper := Node3D.new()
	upper.name = "Upper"
	root.add_child(upper)
	_mi(upper, _cyl(0.048, 0.044, 0.28), sleeve, Vector3(0, -0.14, 0))
	var lower := Node3D.new()
	lower.name = "Lower"
	lower.position = Vector3(0, -0.28, 0)
	upper.add_child(lower)
	_mi(lower, _cyl(0.036, 0.032, 0.28), skin, Vector3(0, -0.14, 0))
	_mi(lower, _sphere(0.040), skin, Vector3(0, -0.29, 0))
	return root

func _make_leg(parent: Node3D, left: bool, stocking_mat: Material, heel_mat: Material) -> Node3D:
	var sign := -1.0 if left else 1.0
	var root := Node3D.new()
	root.name = "LegL" if left else "LegR"
	root.position = Vector3(0.105 * sign, -0.08, 0)
	parent.add_child(root)
	var thigh := Node3D.new()
	thigh.name = "Thigh"
	root.add_child(thigh)
	_mi(thigh, _cyl(0.082, 0.062, 0.36), stocking_mat, Vector3(0, -0.18, 0))
	var calf := Node3D.new()
	calf.name = "Calf"
	calf.position = Vector3(0, -0.36, 0)
	thigh.add_child(calf)
	_mi(calf, _cyl(0.056, 0.038, 0.34), stocking_mat, Vector3(0, -0.17, 0))

	# Sculpted High-Heeled Stiletto Pump (ankle strap, angled arch, pointed toe vamp, stiletto heel spike!)
	var shoe := Node3D.new()
	shoe.name = "StilettoShoe"
	shoe.position = Vector3(0, -0.35, 0)
	calf.add_child(shoe)
	_mi(shoe, _cyl(0.044, 0.044, 0.035), heel_mat, Vector3(0, 0.03, 0)) # ankle strap
	var vamp := _mi(shoe, _sphere(0.052), heel_mat, Vector3(0, -0.025, -0.065), Vector3(0.95, 0.58, 1.85))
	vamp.rotation_degrees = Vector3(14, 0, 0)
	var heel_spike := _mi(shoe, _cyl(0.016, 0.009, 0.115), heel_mat, Vector3(0, -0.035, 0.042))
	heel_spike.rotation_degrees = Vector3(-6, 0, 0)
	return root
