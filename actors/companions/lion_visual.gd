extends Node3D

## Sculpted 2026 Cowardly Lion — horizontal organic feline anatomy (ribcage, waist,
## muscular haunches, 2-tier 18-tuft windswept mane, articulated legs/paws, S-tail),
## rearing roar choreography, and realistic lying-down sleeping pose.

var _leg_fl: Node3D
var _leg_fr: Node3D
var _leg_bl: Node3D
var _leg_br: Node3D
var _body: Node3D
var _head: Node3D
var _jaw: Node3D
var _tail: Node3D
var _phase: float = 0.0
var _idle_t: float = 0.0
var _speed_amt: float = 0.0
var _roar_t: float = 0.0
var cowering: bool = true
var sleeping: bool = false

func _ready() -> void:
	for c in get_children():
		c.free()
	_build()

func play_roar() -> void:
	_roar_t = 0.54

func set_cowering(on: bool) -> void:
	cowering = on
	_apply_pose()

func set_sleeping(on: bool) -> void:
	sleeping = on
	_apply_pose()

func set_locomotion(horizontal_speed: float, delta: float) -> void:
	_idle_t += delta
	_roar_t = maxf(_roar_t - delta, 0.0)
	_speed_amt = clampf(horizontal_speed / 5.5, 0.0, 1.4) if not sleeping else 0.0
	if _speed_amt > 0.08:
		_phase += delta * (9.0 + _speed_amt * 6.0)
	else:
		_phase = move_toward(_phase, 0.0, delta * 4.0)
	_apply_pose()

func _apply_pose() -> void:
	if _leg_fl == null or _body == null:
		return
	if sleeping:
		# Curled peacefully on his side on the ground / cart bed with slow breathing
		var breath := sin(_idle_t * 1.8) * 0.015
		_body.position = Vector3(0, 0.24 + breath, 0)
		_body.rotation = Vector3(0.0, 0.0, 1.38) # lying on side
		_leg_fl.rotation.x = 0.55
		_leg_fr.rotation.x = 0.35
		_leg_bl.rotation.x = -0.45
		_leg_br.rotation.x = -0.65
		if _head:
			_head.rotation = Vector3(0.25, 0.2, -0.3)
			_head.scale = Vector3.ONE
		if _jaw:
			_jaw.rotation.x = 0.08 + absf(sin(_idle_t * 1.8)) * 0.14
		if _tail:
			_tail.rotation.y = 0.45
		return

	_body.rotation.z = 0.0
	if _roar_t > 0.0:
		var u := sin((1.0 - _roar_t / 0.54) * PI)
		_body.position = Vector3(0, 0.56 + 0.34 * u, 0)
		_body.rotation.x = -0.58 * u
		_leg_fl.rotation.x = -0.95 * u
		_leg_fr.rotation.x = -0.95 * u
		_leg_bl.rotation.x = 0.45 * u
		_leg_br.rotation.x = 0.45 * u
		if _head:
			_head.rotation = Vector3(0.32 * u, 0.0, 0.0)
			_head.scale = Vector3.ONE * (1.0 + 0.12 * u)
		if _jaw:
			_jaw.rotation.x = 0.55 * u
		return

	if _head:
		_head.rotation = Vector3(sin(_idle_t * 1.9) * 0.04, 0.0, 0.0)
		_head.scale = Vector3.ONE
	if _jaw:
		_jaw.rotation.x = 0.0
	var swing := sin(_phase) * 0.56 * _speed_amt
	_leg_fl.rotation.x = swing
	_leg_fr.rotation.x = -swing
	_leg_bl.rotation.x = -swing
	_leg_br.rotation.x = swing
	if _tail:
		_tail.rotation.y = sin(_idle_t * 4.2 + _phase) * 0.40
	_body.position = Vector3(0, 0.56 + absf(sin(_phase)) * 0.035 * _speed_amt + sin(_idle_t * 2.4) * 0.01, 0)
	_body.rotation.x = 0.28 if cowering else 0.0

func _mat(c: Color, r: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = r
	return m

func _mi(p: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	n.rotation_degrees = rot_deg
	n.scale = scl
	p.add_child(n)
	return n

func _cyl(t: float, b: float, h: float, segs: int = 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = t
	c.bottom_radius = b
	c.height = h
	c.radial_segments = segs
	return c

func _sph(r: float, segs: int = 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = 10
	return s

func _build() -> void:
	var fur := _mat(Color(0.76, 0.52, 0.24), 0.86)
	var fur_belly := _mat(Color(0.88, 0.72, 0.44), 0.88)
	var mane := _mat(Color(0.52, 0.26, 0.09), 0.90)
	var mane_hi := _mat(Color(0.68, 0.38, 0.14), 0.90)
	var dark := _mat(Color(0.18, 0.10, 0.06), 0.55)
	var eye := _mat(Color(0.18, 0.42, 0.16), 0.22)
	var shine := _mat(Color(0.98, 0.98, 1.0), 0.12)

	_body = Node3D.new()
	_body.position = Vector3(0, 0.56, 0)
	add_child(_body)

	# Horizontal sculpted feline torso: deep chest ribcage + tapered waist + muscular haunches (NO vertical drum!)
	_mi(_body, _sph(0.30, 18), fur, Vector3(0, 0.08, -0.22), Vector3.ZERO, Vector3(0.95, 0.96, 1.18)) # broad chest
	_mi(_body, _cyl(0.24, 0.26, 0.56, 18), fur, Vector3(0, 0.07, 0.08), Vector3(90, 0, 0), Vector3(0.92, 1.0, 0.92)) # horizontal lumbar waist
	_mi(_body, _sph(0.27, 18), fur, Vector3(0, 0.08, 0.34), Vector3.ZERO, Vector3(0.90, 0.94, 1.12)) # rounded haunches
	_mi(_body, _sph(0.22, 14), fur_belly, Vector3(0, -0.06, 0.04), Vector3.ZERO, Vector3(0.82, 0.65, 1.75)) # pale underbelly
	# Muscular shoulder & hip blades
	for sx in [-1.0, 1.0]:
		var s: float = float(sx)
		_mi(_body, _sph(0.15, 12), fur, Vector3(s * 0.20, 0.04, -0.24), Vector3.ZERO, Vector3(0.8, 1.1, 1.05))
		_mi(_body, _sph(0.16, 12), fur, Vector3(s * 0.19, 0.04, 0.32), Vector3.ZERO, Vector3(0.8, 1.15, 1.15))

	# Sculpted Head + 2-tier 18-tuft windswept mane + articulated jaw + whiskers
	var head := Node3D.new()
	head.position = Vector3(0, 0.24, -0.50)
	_body.add_child(head)
	_head = head

	_mi(head, _sph(0.24, 16), mane, Vector3(0, 0.04, 0.08), Vector3.ZERO, Vector3(1.26, 1.24, 1.12))
	for mi_i in range(12):
		var a := float(mi_i) / 12.0 * TAU
		var tmat := mane_hi if mi_i % 2 == 0 else mane
		_mi(head, _sph(0.115, 10), tmat, Vector3(cos(a) * 0.26, 0.05 + sin(a) * 0.25, 0.06), Vector3.ZERO, Vector3(1.0, 1.0, 1.15))
	for mi_j in range(6):
		var a2 := float(mi_j) / 6.0 * TAU + 0.3
		_mi(head, _sph(0.10, 10), mane_hi, Vector3(cos(a2) * 0.19, 0.06 + sin(a2) * 0.18, -0.03))

	# Face skull, brow ridge, cheeks, muzzle, articulated lower jaw
	_mi(head, _sph(0.175, 16), fur, Vector3(0, 0.03, -0.10), Vector3.ZERO, Vector3(1.02, 0.96, 1.08))
	_mi(head, _sph(0.085, 12), fur_belly, Vector3(-0.055, -0.03, -0.24)) # left muzzle pad
	_mi(head, _sph(0.085, 12), fur_belly, Vector3(0.055, -0.03, -0.24))  # right muzzle pad
	_mi(head, _sph(0.048, 10), dark, Vector3(0, 0.005, -0.31), Vector3.ZERO, Vector3(1.25, 0.72, 0.85)) # lion nose

	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.075, -0.16)
	head.add_child(_jaw)
	_mi(_jaw, _sph(0.072, 10), fur_belly, Vector3(0, -0.02, -0.09), Vector3.ZERO, Vector3(1.1, 0.65, 1.25))

	# Rounded lion ears with inner dark hollows
	for sx in [-1.0, 1.0]:
		var s: float = float(sx)
		_mi(head, _sph(0.068, 10), fur, Vector3(s * 0.155, 0.17, -0.04), Vector3.ZERO, Vector3(1.0, 0.9, 0.65))
		_mi(head, _sph(0.038, 8), dark, Vector3(s * 0.155, 0.17, -0.075), Vector3.ZERO, Vector3(0.9, 0.8, 0.5))
		# Expressive emerald-gold eyes with catchlights
		_mi(head, _sph(0.034, 10), eye, Vector3(s * 0.075, 0.065, -0.23))
		_mi(head, _sph(0.012, 6), shine, Vector3(s * 0.068, 0.076, -0.258))

	# Curved S-tail with fluffy mane tuft
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.14, 0.50)
	_body.add_child(_tail)
	_mi(_tail, _cyl(0.036, 0.044, 0.34, 10), fur, Vector3(0, -0.05, 0.14), Vector3(68, 0, 0))
	_mi(_tail, _cyl(0.028, 0.034, 0.32, 10), fur, Vector3(0, 0.02, 0.38), Vector3(112, 0, 0))
	_mi(_tail, _sph(0.082, 10), mane, Vector3(0, 0.10, 0.54), Vector3.ZERO, Vector3(0.9, 0.9, 1.35))

	_leg_fl = _leg(_body, -1.0, -1.0, fur, fur_belly, dark)
	_leg_fr = _leg(_body, 1.0, -1.0, fur, fur_belly, dark)
	_leg_bl = _leg(_body, -1.0, 1.0, fur, fur_belly, dark)
	_leg_br = _leg(_body, 1.0, 1.0, fur, fur_belly, dark)
	_apply_pose()

func _leg(parent: Node3D, x_sign: float, z_sign: float, fur: Material, belly: Material, dark: Material) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.19 * x_sign, -0.06, 0.26 * z_sign)
	parent.add_child(root)
	# Upper leg + knee joint + tapered lower leg + sculpted 3-toe paw
	_mi(root, _cyl(0.085, 0.065, 0.26, 12), fur, Vector3(0, -0.13, 0))
	_mi(root, _sph(0.066, 10), fur, Vector3(0, -0.26, 0))
	_mi(root, _cyl(0.062, 0.050, 0.24, 12), fur, Vector3(0, -0.38, 0))
	_mi(root, _sph(0.072, 10), belly, Vector3(0, -0.49, -0.03), Vector3.ZERO, Vector3(1.05, 0.62, 1.35))
	for tx in [-0.042, 0.0, 0.042]:
		_mi(root, _sph(0.024, 6), dark, Vector3(float(tx), -0.50, -0.11))
	return root
