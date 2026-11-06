extends Node3D

## Full-body Tin Woodman — riveted tin, funnel/axe silhouette, heavy walk.
## Book woodman + original spin (not MGM).

var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _hip: Node3D
var _phase: float = 0.0
var _speed_amt: float = 0.0
var rusted: bool = false

func _ready() -> void:
	for c in get_children():
		c.free()
	_build()

func set_rusted(on: bool) -> void:
	rusted = on
	for c in get_children():
		c.free()
	_build()

func set_locomotion(horizontal_speed: float, delta: float) -> void:
	if rusted:
		_speed_amt = 0.0
		return
	_speed_amt = clampf(horizontal_speed / 3.8, 0.0, 1.1)
	if _speed_amt > 0.08:
		_phase += delta * (6.0 + _speed_amt * 4.0)
	else:
		_phase = move_toward(_phase, 0.0, delta * 3.0)
	_apply_pose()

func _apply_pose() -> void:
	if _leg_l == null or rusted:
		return
	var swing := sin(_phase) * 0.35 * _speed_amt
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_l.rotation.x = -swing * 0.5
	_arm_r.rotation.x = swing * 0.7 # axe arm
	if _hip:
		_hip.position.y = 0.88 + absf(sin(_phase)) * 0.015 * _speed_amt

func _mat(c: Color, metal: float = 0.85, rough: float = 0.35) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
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
	var tin_c := Color(0.35, 0.42, 0.48) if rusted else Color(0.62, 0.68, 0.74)
	var rust_c := Color(0.45, 0.28, 0.16)
	var tin := _mat(tin_c if not rusted else rust_c, 0.9 if not rusted else 0.4, 0.3 if not rusted else 0.75)
	var dark := _mat(Color(0.25, 0.28, 0.32), 0.7, 0.4)
	var axe := _mat(Color(0.55, 0.58, 0.62), 0.95, 0.25)
	var eye := _mat(Color(0.15, 0.35, 0.45), 0.2, 0.2)

	_hip = Node3D.new()
	_hip.position = Vector3(0, 0.88, 0)
	add_child(_hip)

	_mi(_hip, _cyl(0.2, 0.22, 0.2), tin, Vector3(0, -0.05, 0))
	_mi(_hip, _box(Vector3(0.42, 0.5, 0.28)), tin, Vector3(0, 0.28, 0))
	# Rivets
	for x in [-0.12, 0.12]:
		for y in [0.15, 0.35]:
			_mi(_hip, _sph(0.025), dark, Vector3(x, y, -0.15))

	var head := Node3D.new()
	head.position = Vector3(0, 0.62, 0)
	_hip.add_child(head)
	_mi(head, _cyl(0.14, 0.15, 0.22), tin, Vector3(0, 0.08, 0))
	_mi(head, _cyl(0.04, 0.16, 0.18), tin, Vector3(0, 0.28, 0)) # funnel hat
	_mi(head, _sph(0.03), eye, Vector3(-0.05, 0.1, -0.14))
	_mi(head, _sph(0.03), eye, Vector3(0.05, 0.1, -0.14))

	_arm_l = _arm(_hip, true, tin)
	_arm_r = _arm(_hip, false, tin)
	# Axe on right
	if not rusted:
		_mi(_arm_r, _box(Vector3(0.06, 0.55, 0.06)), dark, Vector3(0.05, -0.55, 0))
		_mi(_arm_r, _box(Vector3(0.35, 0.12, 0.04)), axe, Vector3(0.05, -0.85, 0))
	_leg_l = _leg(_hip, true, tin)
	_leg_r = _leg(_hip, false, tin)

func play_axe_swing() -> void:
	## Readable overhead chop on the right (axe) arm — not a torso headbutt.
	if _arm_r == null or rusted:
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	# Wind-up: axe back and high.
	tw.tween_property(_arm_r, "rotation", Vector3(-1.35, 0.15, 0.55), 0.11)
	# Strike: axe arcs down/forward through the target plane.
	tw.tween_property(_arm_r, "rotation", Vector3(1.25, -0.35, -0.25), 0.13).set_trans(Tween.TRANS_BACK)
	# Recover.
	tw.tween_property(_arm_r, "rotation", Vector3.ZERO, 0.22)
	if _hip:
		var tw2 := create_tween()
		tw2.tween_property(_hip, "rotation:y", -0.18, 0.12)
		tw2.tween_property(_hip, "rotation:y", 0.12, 0.12)
		tw2.tween_property(_hip, "rotation:y", 0.0, 0.18)

func _arm(parent: Node3D, left: bool, tin: Material) -> Node3D:
	var sign := -1.0 if left else 1.0
	var root := Node3D.new()
	root.position = Vector3(0.28 * sign, 0.4, 0)
	parent.add_child(root)
	_mi(root, _cyl(0.06, 0.055, 0.55), tin, Vector3(0, -0.28, 0))
	return root

func _leg(parent: Node3D, left: bool, tin: Material) -> Node3D:
	var sign := -1.0 if left else 1.0
	var root := Node3D.new()
	root.position = Vector3(0.11 * sign, -0.1, 0)
	parent.add_child(root)
	_mi(root, _cyl(0.08, 0.07, 0.75), tin, Vector3(0, -0.38, 0))
	_mi(root, _box(Vector3(0.14, 0.08, 0.22)), tin, Vector3(0, -0.78, -0.02))
	return root
