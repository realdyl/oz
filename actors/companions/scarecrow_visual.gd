extends Node3D

## Full-body Scarecrow — burlap, hat, patches, pole-scar, limb walk.
## Book straw man + original spin (not MGM).

var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _hip: Node3D
var _phase: float = 0.0
var _speed_amt: float = 0.0

func _ready() -> void:
	for c in get_children():
		c.free()
	_build()

func set_locomotion(horizontal_speed: float, delta: float) -> void:
	_speed_amt = clampf(horizontal_speed / 4.5, 0.0, 1.3)
	if _speed_amt > 0.08:
		_phase += delta * (7.5 + _speed_amt * 5.5)
	else:
		_phase = move_toward(_phase, 0.0, delta * 4.0)
		_speed_amt = move_toward(_speed_amt, 0.0, delta * 3.0)
	_apply_pose()

func _apply_pose() -> void:
	if _leg_l == null:
		return
	var swing := sin(_phase) * 0.5 * _speed_amt
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_l.rotation.x = -swing * 0.85
	_arm_r.rotation.x = swing * 0.85
	# Floppy straw arms hang a bit
	_arm_l.rotation.z = -0.25
	_arm_r.rotation.z = 0.25
	if _hip:
		_hip.position.y = 0.82 + absf(sin(_phase)) * 0.02 * _speed_amt

func _mat(c: Color, r: float = 0.9, e: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = r
	if e > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = e
	return m

func _mi(p: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	n.scale = scl
	p.add_child(n)
	return n

func _cyl(t: float, b: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = t
	c.bottom_radius = b
	c.height = h
	return c

func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b

func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s

func _build() -> void:
	var burlap := _mat(Color(0.72, 0.58, 0.34), 0.95)
	var patch := _mat(Color(0.42, 0.52, 0.36), 0.88)
	var hat := _mat(Color(0.32, 0.2, 0.1), 0.9)
	var stitch := _mat(Color(0.28, 0.1, 0.12), 0.7, 0.2)
	var eye := _mat(Color(0.1, 0.08, 0.06), 0.45)
	var pole := _mat(Color(0.38, 0.26, 0.16), 0.75)
	var straw := _mat(Color(0.85, 0.72, 0.4), 0.92)

	_hip = Node3D.new()
	_hip.name = "Hip"
	_hip.position = Vector3(0, 0.82, 0)
	add_child(_hip)

	_mi(_hip, _cyl(0.2, 0.24, 0.22), burlap, Vector3(0, -0.05, 0))
	_mi(_hip, _cyl(0.18, 0.2, 0.42), burlap, Vector3(0, 0.28, 0))
	_mi(_hip, _box(Vector3(0.2, 0.2, 0.05)), patch, Vector3(0.1, 0.3, -0.18))
	# Pole scar through chest
	_mi(_hip, _cyl(0.04, 0.04, 0.55), pole, Vector3(0, 0.25, 0.12))

	var head := Node3D.new()
	head.position = Vector3(0, 0.58, 0)
	_hip.add_child(head)
	_mi(head, _sph(0.16), burlap, Vector3(0, 0.08, 0), Vector3(1.05, 1.1, 1.0))
	_mi(head, _cyl(0.06, 0.28, 0.22), hat, Vector3(0, 0.28, 0))
	_mi(head, _sph(0.04), eye, Vector3(-0.06, 0.1, -0.14))
	_mi(head, _sph(0.04), eye, Vector3(0.07, 0.09, -0.14))
	_mi(head, _box(Vector3(0.03, 0.22, 0.03)), stitch, Vector3(0, 0.08, -0.15))
	# Straw tufts
	_mi(head, _cyl(0.02, 0.04, 0.12), straw, Vector3(-0.14, 0.0, 0.0))
	_mi(head, _cyl(0.02, 0.04, 0.12), straw, Vector3(0.14, 0.0, 0.0))

	_arm_l = _limb(_hip, true, true, burlap, straw)
	_arm_r = _limb(_hip, false, true, burlap, straw)
	_leg_l = _limb(_hip, true, false, burlap, straw)
	_leg_r = _limb(_hip, false, false, burlap, straw)

func _limb(parent: Node3D, left: bool, is_arm: bool, cloth: Material, straw: Material) -> Node3D:
	var sign := -1.0 if left else 1.0
	var root := Node3D.new()
	if is_arm:
		root.position = Vector3(0.26 * sign, 0.35, 0)
	else:
		root.position = Vector3(0.1 * sign, -0.12, 0)
	parent.add_child(root)
	var len := 0.55 if is_arm else 0.7
	var rad := 0.05 if is_arm else 0.07
	_mi(root, _cyl(rad, rad * 0.85, len), cloth, Vector3(0, -len * 0.5, 0))
	_mi(root, _cyl(0.02, 0.035, 0.1), straw, Vector3(0, -len - 0.02, 0))
	return root
