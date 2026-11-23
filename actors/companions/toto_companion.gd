extends Node3D

## Sculpted 3D Cairn Terrier Toto companion — accompanies Dorothy across all Oz levels (L2–L7)
## and shares his visual builder with Kansas L1 (regions/kansas/toto.gd).

var greyscale: bool = false
var _parts: Dictionary = {}
var _phase: float = 0.0
var _wag_t: float = 0.0
var _follow_offset := Vector3(1.15, 0.0, 0.75)

func _ready() -> void:
	name = "TotoCompanion"
	add_to_group("toto")
	var vis := Node3D.new()
	vis.name = "Visual"
	add_child(vis)
	_parts = build_dog_visual(vis, greyscale)

static func _m(c: Color, rough: float = 0.88, metal: float = 0.0, grey: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if grey:
		var l := c.r * 0.3 + c.g * 0.5 + c.b * 0.2
		m.albedo_color = Color(l, l, l)
	else:
		m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

static func _mi(p: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	n.rotation_degrees = rot_deg
	n.scale = scl
	p.add_child(n)
	return n

static func _sph(r: float, h: float = -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0.0 else h
	s.radial_segments = 14
	s.rings = 8
	return s

static func _cyl(t: float, b: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = t
	c.bottom_radius = b
	c.height = h
	c.radial_segments = 10
	return c

## Builds a detailed, articulated Cairn Terrier dog under `parent`.
static func build_dog_visual(parent: Node3D, is_grey: bool = false) -> Dictionary:
	for c in parent.get_children():
		c.queue_free()

	var fur_dark := _m(Color(0.16, 0.14, 0.13), 0.92, 0.0, is_grey)
	var fur_brindle := _m(Color(0.28, 0.23, 0.19), 0.90, 0.0, is_grey)
	var fur_ruff := _m(Color(0.34, 0.28, 0.23), 0.92, 0.0, is_grey)
	var nose_m := _m(Color(0.04, 0.04, 0.05), 0.22, 0.1, is_grey)
	var eye_m := _m(Color(0.05, 0.04, 0.04), 0.12, 0.15, is_grey)
	var shine_m := _m(Color(0.98, 0.98, 1.0), 0.1, 0.0, is_grey)
	var tongue_m := _m(Color(0.88, 0.42, 0.48), 0.45, 0.0, is_grey)
	var collar_m := _m(Color(0.62, 0.16, 0.20), 0.55, 0.05, is_grey)
	var tag_m := _m(Color(0.92, 0.78, 0.30), 0.25, 0.85, is_grey)

	var body_root := Node3D.new()
	body_root.name = "BodyRoot"
	body_root.position = Vector3(0, 0.26, 0)
	parent.add_child(body_root)

	# Shaggy elongated terrier torso + chest ruff + hind haunches
	_mi(body_root, _sph(0.14, 0.24), fur_dark, Vector3(0, 0.0, 0.02), Vector3.ZERO, Vector3(0.92, 0.88, 1.65))
	_mi(body_root, _sph(0.135, 0.24), fur_brindle, Vector3(0, 0.02, -0.11), Vector3.ZERO, Vector3(1.02, 0.95, 1.05))
	_mi(body_root, _sph(0.11, 0.20), fur_ruff, Vector3(0, -0.02, -0.17)) # scruffy chest fluff

	# Red/leather collar + tiny gleaming brass name-tag
	_mi(body_root, _cyl(0.095, 0.10, 0.045), collar_m, Vector3(0, 0.07, -0.17), Vector3(38, 0, 0))
	_mi(body_root, _sph(0.025, 0.045), tag_m, Vector3(0, 0.02, -0.24))

	# Articulated Head: scruffy skull, bearded terrier muzzle, wet black nose, bright eyes, pointed ears
	var head := Node3D.new()
	head.position = Vector3(0, 0.14, -0.22)
	body_root.add_child(head)
	_mi(head, _sph(0.115, 0.22), fur_brindle, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1.0, 0.95, 1.05))
	# Scruffy terrier beard/cheeks + snout
	_mi(head, _sph(0.075, 0.13), fur_ruff, Vector3(0, -0.02, -0.10), Vector3.ZERO, Vector3(1.15, 0.82, 1.1))
	_mi(head, _sph(0.032, 0.05), nose_m, Vector3(0, 0.005, -0.18), Vector3.ZERO, Vector3(1.2, 0.85, 0.9))
	_mi(head, _sph(0.024, 0.04), tongue_m, Vector3(0, -0.055, -0.13), Vector3(25, 0, 0), Vector3(0.9, 1.2, 0.6))
	# Bright eyes with specular catchlights
	for ex in [-0.048, 0.048]:
		var s: float = float(ex)
		_mi(head, _sph(0.022, 0.044), eye_m, Vector3(s, 0.045, -0.105))
		_mi(head, _sph(0.008, 0.016), shine_m, Vector3(s * 0.92, 0.054, -0.122))
	# Perky triangular Cairn Terrier ears
	for sx in [-1.0, 1.0]:
		var s: float = float(sx)
		_mi(head, _cyl(0.008, 0.048, 0.12), fur_dark, Vector3(s * 0.075, 0.13, -0.01), Vector3(-12, 0, -s * 18))

	# Happy upright wagging tail
	var tail := Node3D.new()
	tail.position = Vector3(0, 0.06, 0.22)
	body_root.add_child(tail)
	_mi(tail, _cyl(0.022, 0.038, 0.20), fur_dark, Vector3(0, 0.09, 0.04), Vector3(-28, 0, 0))

	# 4 Articulated trotting legs with paws
	var leg_fl := _make_paw_leg(body_root, Vector3(-0.08, -0.06, -0.13), fur_dark, fur_brindle)
	var leg_fr := _make_paw_leg(body_root, Vector3(0.08, -0.06, -0.13), fur_dark, fur_brindle)
	var leg_bl := _make_paw_leg(body_root, Vector3(-0.085, -0.06, 0.14), fur_dark, fur_brindle)
	var leg_br := _make_paw_leg(body_root, Vector3(0.085, -0.06, 0.14), fur_dark, fur_brindle)

	return {
		"body": body_root,
		"head": head,
		"tail": tail,
		"leg_fl": leg_fl,
		"leg_fr": leg_fr,
		"leg_bl": leg_bl,
		"leg_br": leg_br,
	}

static func _make_paw_leg(parent: Node3D, pos: Vector3, fur: Material, paw: Material) -> Node3D:
	var leg := Node3D.new()
	leg.position = pos
	parent.add_child(leg)
	_mi(leg, _cyl(0.036, 0.028, 0.18), fur, Vector3(0, -0.09, 0))
	_mi(leg, _sph(0.036, 0.05), paw, Vector3(0, -0.18, -0.02), Vector3.ZERO, Vector3(0.95, 0.7, 1.3))
	return leg

func _physics_process(delta: float) -> void:
	_wag_t += delta
	var dorothy := get_tree().get_first_node_in_group("player") as Node3D
	if dorothy == null or not is_instance_valid(dorothy):
		return

	var parked := bool(dorothy.get("parked")) if "parked" in dorothy else false
	var target_pos := dorothy.global_position + _follow_offset
	if parked:
		target_pos = dorothy.global_position + Vector3(0.75, 0.0, 0.45)

	var to := target_pos - global_position
	to.y = 0.0
	var dist := to.length()
	var spd := 0.0

	if dist > 18.0:
		global_position = target_pos
	elif dist > 0.45:
		var dir := to / dist
		spd = clampf(dist * 2.8, 1.8, 6.2)
		global_position += dir * spd * delta
		global_position.y = lerpf(global_position.y, dorothy.global_position.y, clampf(8.0 * delta, 0.0, 1.0))
		var vis := get_node_or_null("Visual") as Node3D
		if vis:
			vis.rotation.y = lerp_angle(vis.rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
	else:
		global_position.y = lerpf(global_position.y, dorothy.global_position.y, clampf(8.0 * delta, 0.0, 1.0))

	_animate(spd, parked, delta)

func _animate(spd: float, sleeping: bool, delta: float) -> void:
	if _parts.is_empty():
		return
	var body: Node3D = _parts["body"]
	var head: Node3D = _parts["head"]
	var tail: Node3D = _parts["tail"]
	var fl: Node3D = _parts["leg_fl"]
	var fr: Node3D = _parts["leg_fr"]
	var bl: Node3D = _parts["leg_bl"]
	var br: Node3D = _parts["leg_br"]

	if sleeping:
		body.position.y = 0.14
		head.rotation.x = 0.35
		tail.rotation.z = 0.0
		fl.rotation.x = -0.7
		fr.rotation.x = -0.7
		bl.rotation.x = 0.7
		br.rotation.x = 0.7
		return

	var wag_speed := 12.0 if spd > 0.2 else 6.5
	tail.rotation.z = sin(_wag_t * wag_speed) * 0.42

	if spd > 0.2:
		_phase += delta * (12.0 + spd * 1.4)
		var sw := sin(_phase) * 0.65
		fl.rotation.x = sw
		br.rotation.x = sw
		fr.rotation.x = -sw
		bl.rotation.x = -sw
		body.position.y = 0.26 + absf(sin(_phase)) * 0.045
		head.rotation.x = -0.08 + sin(_phase * 0.5) * 0.06
	else:
		body.position.y = 0.26 + sin(_wag_t * 3.0) * 0.008
		fl.rotation.x = lerp_angle(fl.rotation.x, 0.0, 8.0 * delta)
		fr.rotation.x = lerp_angle(fr.rotation.x, 0.0, 8.0 * delta)
		bl.rotation.x = lerp_angle(bl.rotation.x, 0.0, 8.0 * delta)
		br.rotation.x = lerp_angle(br.rotation.x, 0.0, 8.0 * delta)
		head.rotation.y = sin(_wag_t * 1.4) * 0.18
