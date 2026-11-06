extends Node3D

## Full-body Dorothy — M-rated adult (18+). Feminine, alluring farm-girl silhouette with limb walk cycle.
## Procedural stand-in until authored meshes. Not a capsule blob.

@export var greyscale: bool = false
@export var show_silver_shoes: bool = false
@export var mature_silhouette: bool = true

var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _hip: Node3D
var _torso: Node3D
var _phase: float = 0.0
var _speed_amt: float = 0.0

func _ready() -> void:
	for c in get_children():
		c.free()
	_build()

func set_locomotion(horizontal_speed: float, delta: float) -> void:
	_speed_amt = clampf(horizontal_speed / 5.0, 0.0, 1.4)
	if _speed_amt > 0.08:
		_phase += delta * (8.5 + _speed_amt * 6.0)
	else:
		_phase = move_toward(_phase, 0.0, delta * 4.0)
		_speed_amt = move_toward(_speed_amt, 0.0, delta * 3.0)
	_apply_pose()

func _apply_pose() -> void:
	if _leg_l == null:
		return
	var swing := sin(_phase) * 0.58 * _speed_amt
	var swing_a := sin(_phase + PI) * 0.5 * _speed_amt
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	if _leg_l.has_node("Thigh/Calf"):
		(_leg_l.get_node("Thigh/Calf") as Node3D).rotation.x = maxf(-swing, 0.0) * 0.65
	if _leg_r.has_node("Thigh/Calf"):
		(_leg_r.get_node("Thigh/Calf") as Node3D).rotation.x = maxf(swing, 0.0) * 0.65
	_arm_l.rotation.x = -swing_a * 0.9
	_arm_r.rotation.x = swing_a * 0.9
	if _hip:
		_hip.position.y = 0.78 + absf(sin(_phase)) * 0.028 * _speed_amt
		_hip.rotation.y = sin(_phase * 0.5) * 0.05 * _speed_amt
	if _torso:
		_torso.rotation.z = sin(_phase) * 0.035 * _speed_amt

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
		m.emission = _col(Color(0.75, 0.82, 0.95))
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
	return s

func _cyl(t: float, b: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = t
	c.bottom_radius = b
	c.height = h
	return c

func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _build() -> void:
	var skin := _mat(Color(0.94, 0.73, 0.6), 0.48)
	var dress := _mat(Color(0.32, 0.46, 0.72), 0.74)
	var apron := _mat(Color(0.96, 0.93, 0.88), 0.65)
	var gingham := _mat(Color(0.46, 0.54, 0.78), 0.72)
	var hair := _mat(Color(0.16, 0.08, 0.04), 0.8)
	var boot := _mat(Color(0.18, 0.12, 0.09), 0.76)
	var shoe_s := _mat(Color(0.84, 0.88, 0.95), 0.2, 0.9, 0.6 if show_silver_shoes else 0.0)
	var eye := _mat(Color(0.18, 0.28, 0.42), 0.28)
	var white := _mat(Color(0.96, 0.96, 0.98), 0.35)
	var lip := _mat(Color(0.7, 0.25, 0.34), 0.45)
	var cheek := _mat(Color(0.92, 0.52, 0.5), 0.55)

	_hip = Node3D.new()
	_hip.name = "Hip"
	_hip.position = Vector3(0, 0.78, 0)
	add_child(_hip)

	var hip_w := 0.21 if mature_silhouette else 0.16
	var waist := 0.125 if mature_silhouette else 0.14
	_mi(_hip, _cyl(hip_w, hip_w * 0.92, 0.17), dress, Vector3(0, -0.04, 0))
	# Shorter flared skirt (adult farm hem)
	_mi(_hip, _cyl(0.26, 0.38, 0.36), dress, Vector3(0, -0.28, 0))
	_mi(_hip, _box(Vector3(0.3, 0.32, 0.05)), apron, Vector3(0, -0.2, -0.18))

	_torso = Node3D.new()
	_torso.name = "Torso"
	_torso.position = Vector3(0, 0.1, 0)
	_hip.add_child(_torso)
	_mi(_torso, _cyl(waist, 0.155, 0.2), dress, Vector3(0, 0.1, 0))
	if mature_silhouette:
		_mi(_torso, _sphere(0.105), dress, Vector3(-0.095, 0.26, -0.05), Vector3(1.2, 0.88, 1.05))
		_mi(_torso, _sphere(0.105), dress, Vector3(0.095, 0.26, -0.05), Vector3(1.2, 0.88, 1.05))
		_mi(_torso, _cyl(0.155, 0.14, 0.12), dress, Vector3(0, 0.28, 0))
	else:
		_mi(_torso, _cyl(0.15, 0.16, 0.3), dress, Vector3(0, 0.18, 0))
	_mi(_torso, _sphere(0.115), dress, Vector3(-0.17, 0.34, 0), Vector3(1.25, 0.62, 0.85))
	_mi(_torso, _sphere(0.115), dress, Vector3(0.17, 0.34, 0), Vector3(1.25, 0.62, 0.85))
	_mi(_torso, _box(Vector3(0.2, 0.07, 0.15)), gingham, Vector3(0, 0.18, -0.03))
	_mi(_torso, _box(Vector3(0.14, 0.04, 0.08)), apron, Vector3(0, 0.34, -0.09))

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.5, 0)
	_torso.add_child(head)
	_mi(head, _cyl(0.045, 0.055, 0.09), skin, Vector3(0, 0.02, 0))
	_mi(head, _sphere(0.128), skin, Vector3(0, 0.15, 0), Vector3(1.0, 1.14, 0.95))
	_mi(head, _sphere(0.135), hair, Vector3(0, 0.2, -0.01), Vector3(1.14, 0.9, 1.12))
	_mi(head, _sphere(0.085), hair, Vector3(-0.14, 0.05, 0.02), Vector3(0.85, 1.85, 0.85))
	_mi(head, _sphere(0.085), hair, Vector3(0.14, 0.05, 0.02), Vector3(0.85, 1.85, 0.85))
	_mi(head, _sphere(0.065), hair, Vector3(-0.15, -0.1, 0.0), Vector3(0.7, 1.4, 0.7))
	_mi(head, _sphere(0.065), hair, Vector3(0.15, -0.1, 0.0), Vector3(0.7, 1.4, 0.7))
	_mi(head, _sphere(0.03), white, Vector3(-0.042, 0.16, -0.108))
	_mi(head, _sphere(0.03), white, Vector3(0.042, 0.16, -0.108))
	_mi(head, _sphere(0.017), eye, Vector3(-0.042, 0.16, -0.122))
	_mi(head, _sphere(0.017), eye, Vector3(0.042, 0.16, -0.122))
	_mi(head, _sphere(0.038), cheek, Vector3(-0.075, 0.118, -0.08), Vector3(1.0, 0.7, 0.55))
	_mi(head, _sphere(0.038), cheek, Vector3(0.075, 0.118, -0.08), Vector3(1.0, 0.7, 0.55))
	_mi(head, _sphere(0.02), lip, Vector3(0, 0.098, -0.118), Vector3(1.9, 0.55, 0.75))

	_arm_l = _make_arm(_torso, true, skin, dress)
	_arm_r = _make_arm(_torso, false, skin, dress)
	_leg_l = _make_leg(_hip, true, skin, boot if not show_silver_shoes else shoe_s)
	_leg_r = _make_leg(_hip, false, skin, boot if not show_silver_shoes else shoe_s)

	var mount := Marker3D.new()
	mount.name = "BasketMount"
	mount.position = Vector3(0.32, 0.02, 0.06)
	_hip.add_child(mount)

func _make_arm(parent: Node3D, left: bool, skin: Material, sleeve: Material) -> Node3D:
	var sign := -1.0 if left else 1.0
	var root := Node3D.new()
	root.name = "ArmL" if left else "ArmR"
	root.position = Vector3(0.21 * sign, 0.34, 0)
	parent.add_child(root)
	var upper := Node3D.new()
	upper.name = "Upper"
	root.add_child(upper)
	_mi(upper, _cyl(0.05, 0.055, 0.32), sleeve, Vector3(0, -0.16, 0))
	var lower := Node3D.new()
	lower.name = "Lower"
	lower.position = Vector3(0, -0.32, 0)
	upper.add_child(lower)
	_mi(lower, _cyl(0.038, 0.042, 0.3), skin, Vector3(0, -0.15, 0))
	_mi(lower, _sphere(0.045), skin, Vector3(0, -0.32, 0))
	return root

func _make_leg(parent: Node3D, left: bool, skin: Material, shoe: Material) -> Node3D:
	var sign := -1.0 if left else 1.0
	var root := Node3D.new()
	root.name = "LegL" if left else "LegR"
	root.position = Vector3(0.11 * sign, -0.1, 0)
	parent.add_child(root)
	var thigh := Node3D.new()
	thigh.name = "Thigh"
	root.add_child(thigh)
	_mi(thigh, _cyl(0.085, 0.068, 0.38), skin, Vector3(0, -0.19, 0))
	var calf := Node3D.new()
	calf.name = "Calf"
	calf.position = Vector3(0, -0.38, 0)
	thigh.add_child(calf)
	_mi(calf, _cyl(0.058, 0.046, 0.36), skin, Vector3(0, -0.18, 0))
	_mi(calf, _box(Vector3(0.12, 0.07, 0.22)), shoe, Vector3(0, -0.38, -0.03))
	return root
