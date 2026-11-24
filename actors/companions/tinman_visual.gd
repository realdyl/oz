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
	var eye := _mat(Color(0.98, 0.72, 0.24), 0.15, 0.15) # glowing amber-gold clockwork eyes (char_02_tin_woodman.jpg)
	eye.emission_enabled = true
	eye.emission = Color(1.0, 0.68, 0.18)
	eye.emission_energy_multiplier = 1.6 if not rusted else 0.15

	_hip = Node3D.new()
	_hip.position = Vector3(0, 0.88, 0)
	add_child(_hip)

	var brass := _mat(Color(0.82, 0.65, 0.30), 0.88, 0.28)
	var wood := _mat(Color(0.36, 0.22, 0.12), 0.05, 0.85)
	_mi(_hip, _cyl(0.21, 0.24, 0.22), tin, Vector3(0, -0.05, 0))
	# Rounded riveted boiler chest + brass trim bands + heart-latch plate
	_mi(_hip, _cyl(0.24, 0.20, 0.52), tin, Vector3(0, 0.29, 0))
	_mi(_hip, _cyl(0.245, 0.245, 0.05), dark, Vector3(0, 0.12, 0))
	_mi(_hip, _cyl(0.25, 0.25, 0.05), dark, Vector3(0, 0.48, 0))
	# Center gilded filigree clockwork heart cage + glowing crimson heart (char_02_tin_woodman.jpg)
	_mi(_hip, _box(Vector3(0.18, 0.20, 0.05)), brass, Vector3(0.0, 0.34, -0.22))
	_mi(_hip, _box(Vector3(0.14, 0.16, 0.055)), dark, Vector3(0.0, 0.34, -0.23))
	var heart_glow := _mat(Color(0.95, 0.16, 0.24), 0.12, 0.15)
	heart_glow.emission_enabled = true
	heart_glow.emission = Color(1.0, 0.18, 0.24)
	heart_glow.emission_energy_multiplier = 2.2 if not rusted else 0.15
	_mi(_hip, _sph(0.056), heart_glow, Vector3(0.0, 0.34, -0.248))
	_mi(_hip, _cyl(0.008, 0.008, 0.18), brass, Vector3(0.0, 0.34, -0.265)) # vertical filigree bar
	_mi(_hip, _cyl(0.008, 0.008, 0.16), brass, Vector3(0.0, 0.34, -0.265)).rotation_degrees = Vector3(0, 0, 90)
	# Twin brass-and-iron steam exhaust pipes on his back
	for ex in [-0.11, 0.11]:
		_mi(_hip, _cyl(0.032, 0.036, 0.36), brass, Vector3(float(ex), 0.40, 0.23))
		_mi(_hip, _cyl(0.044, 0.044, 0.06), dark, Vector3(float(ex), 0.56, 0.23))
	# Layered riveted shoulder pauldrons with brass spikes
	for px in [-1.0, 1.0]:
		_mi(_hip, _sph(0.13), tin, Vector3(float(px) * 0.28, 0.48, 0), Vector3(1.18, 0.80, 1.08))
		_mi(_hip, _cyl(0.005, 0.025, 0.09), brass, Vector3(float(px) * 0.34, 0.54, 0)).rotation_degrees = Vector3(0, 0, -float(px) * 42.0)
	# Rivets
	for x in [-0.14, 0.14]:
		for y in [0.18, 0.38]:
			_mi(_hip, _sph(0.024), dark, Vector3(float(x), float(y), -0.22))

	var head := Node3D.new()
	head.position = Vector3(0, 0.62, 0)
	_hip.add_child(head)
	_mi(head, _cyl(0.14, 0.15, 0.24), tin, Vector3(0, 0.09, 0))
	_mi(head, _cyl(0.02, 0.04, 0.09), tin, Vector3(0, 0.08, -0.17)).rotation_degrees = Vector3(-90, 0, 0) # pointed tin nose
	_mi(head, _box(Vector3(0.16, 0.04, 0.12)), dark, Vector3(0, -0.01, -0.10)) # hinged jaw
	# Angled oil-funnel hat + spout + handle
	var funnel := _mi(head, _cyl(0.035, 0.17, 0.22), tin, Vector3(0.02, 0.29, 0))
	funnel.rotation_degrees = Vector3(0, 0, -14)
	var spout := _mi(head, _cyl(0.02, 0.03, 0.12), tin, Vector3(0.05, 0.42, 0))
	spout.rotation_degrees = Vector3(0, 0, -14)
	_mi(head, _sph(0.03), eye, Vector3(-0.05, 0.12, -0.14))
	_mi(head, _sph(0.03), eye, Vector3(0.05, 0.12, -0.14))

	_arm_l = _arm(_hip, true, tin)
	_arm_r = _arm(_hip, false, tin)
	# Sculpted Woodsman Axe on right arm
	if not rusted:
		_mi(_arm_r, _cyl(0.028, 0.032, 0.82), wood, Vector3(0.05, -0.62, -0.04))
		_mi(_arm_r, _box(Vector3(0.05, 0.24, 0.34)), axe, Vector3(0.05, -0.96, -0.14))
		_mi(_arm_r, _box(Vector3(0.07, 0.12, 0.10)), dark, Vector3(0.05, -0.96, -0.02))
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
	_mi(root, _cyl(0.062, 0.052, 0.28), tin, Vector3(0, -0.14, 0))
	_mi(root, _sph(0.062), tin, Vector3(0, -0.28, 0)) # articulated elbow ball-joint
	_mi(root, _cyl(0.056, 0.048, 0.28), tin, Vector3(0, -0.42, 0))
	_mi(root, _sph(0.052), tin, Vector3(0, -0.56, 0)) # tin gauntlet hand
	return root

func _leg(parent: Node3D, left: bool, tin: Material) -> Node3D:
	var sign := -1.0 if left else 1.0
	var root := Node3D.new()
	root.position = Vector3(0.11 * sign, -0.1, 0)
	parent.add_child(root)
	_mi(root, _cyl(0.082, 0.072, 0.36), tin, Vector3(0, -0.18, 0))
	_mi(root, _sph(0.078), tin, Vector3(0, -0.37, 0)) # articulated knee ball-joint
	_mi(root, _cyl(0.072, 0.064, 0.36), tin, Vector3(0, -0.56, 0))
	_mi(root, _box(Vector3(0.14, 0.08, 0.24)), tin, Vector3(0, -0.78, -0.02))
	return root
