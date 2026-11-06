extends Node3D

## Full-body Cowardly Lion — mane, heavy body, tail, limb walk.
## Book beast + original spin (not MGM).

var _leg_fl: Node3D
var _leg_fr: Node3D
var _leg_bl: Node3D
var _leg_br: Node3D
var _body: Node3D
var _tail: Node3D
var _phase: float = 0.0
var _speed_amt: float = 0.0
var cowering: bool = true

func _ready() -> void:
	for c in get_children():
		c.free()
	_build()

func set_cowering(on: bool) -> void:
	cowering = on
	if _body:
		_body.rotation.x = 0.35 if on else 0.0

func set_locomotion(horizontal_speed: float, delta: float) -> void:
	_speed_amt = clampf(horizontal_speed / 5.5, 0.0, 1.4)
	if _speed_amt > 0.08:
		_phase += delta * (9.0 + _speed_amt * 6.0)
	else:
		_phase = move_toward(_phase, 0.0, delta * 4.0)
	_apply_pose()

func _apply_pose() -> void:
	if _leg_fl == null:
		return
	var swing := sin(_phase) * 0.55 * _speed_amt
	_leg_fl.rotation.x = swing
	_leg_fr.rotation.x = -swing
	_leg_bl.rotation.x = -swing
	_leg_br.rotation.x = swing
	if _tail:
		_tail.rotation.y = sin(_phase * 1.2) * 0.4 * maxf(_speed_amt, 0.2)
	if _body:
		_body.position.y = 0.55 + absf(sin(_phase)) * 0.03 * _speed_amt
		if cowering:
			_body.rotation.x = 0.35

func _mat(c: Color, r: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = r
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

func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s

func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b

func _build() -> void:
	var fur := _mat(Color(0.72, 0.48, 0.22), 0.88)
	var mane := _mat(Color(0.55, 0.28, 0.1), 0.9)
	var dark := _mat(Color(0.2, 0.12, 0.08), 0.7)
	var eye := _mat(Color(0.15, 0.35, 0.12), 0.35)

	_body = Node3D.new()
	_body.position = Vector3(0, 0.55, 0)
	if cowering:
		_body.rotation.x = 0.35
	add_child(_body)

	_mi(_body, _cyl(0.28, 0.32, 0.7), fur, Vector3(0, 0.1, 0.05), Vector3(1.0, 1.0, 1.35))
	# Mane + head
	var head := Node3D.new()
	head.position = Vector3(0, 0.25, -0.45)
	_body.add_child(head)
	_mi(head, _sph(0.22), mane, Vector3(0, 0.05, 0), Vector3(1.3, 1.2, 1.2))
	_mi(head, _sph(0.16), fur, Vector3(0, 0.0, -0.12))
	_mi(head, _sph(0.035), eye, Vector3(-0.07, 0.04, -0.24))
	_mi(head, _sph(0.035), eye, Vector3(0.07, 0.04, -0.24))
	_mi(head, _sph(0.05), dark, Vector3(0, -0.04, -0.28), Vector3(1.2, 0.7, 1.0))

	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.15, 0.45)
	_body.add_child(_tail)
	_mi(_tail, _cyl(0.04, 0.03, 0.45), fur, Vector3(0, 0.0, 0.2))
	_mi(_tail, _sph(0.07), mane, Vector3(0, 0.0, 0.45))

	_leg_fl = _leg(_body, -1, -1, fur, dark)
	_leg_fr = _leg(_body, 1, -1, fur, dark)
	_leg_bl = _leg(_body, -1, 1, fur, dark)
	_leg_br = _leg(_body, 1, 1, fur, dark)

func _leg(parent: Node3D, x_sign: float, z_sign: float, fur: Material, dark: Material) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.18 * x_sign, -0.15, 0.22 * z_sign)
	parent.add_child(root)
	_mi(root, _cyl(0.07, 0.055, 0.45), fur, Vector3(0, -0.22, 0))
	_mi(root, _box(Vector3(0.12, 0.06, 0.16)), dark, Vector3(0, -0.48, -0.02))
	return root
