extends CharacterBody3D

## Sculpted 3D Cairn Terrier Toto — accompanies Dorothy across all Oz levels (L2–L7),
## shares his visual builder with Kansas L1, and is fully playable via Tab / Key 5!
## F = BARK superpower (sonic startle/knockback ring + objective scent pulse).

@export var move_speed: float = 6.4
@export var gravity: float = 24.0
@export var bark_cooldown: float = 0.85
@export var bark_radius: float = 3.6

var greyscale: bool = false
var leading: bool = false
var bark_timer: float = 0.0
var _bark_anim_t: float = 0.0
var _parts: Dictionary = {}
var _phase: float = 0.0
var _wag_t: float = 0.0
var _follow_offset := Vector3(1.15, 0.0, 0.75)

func _ready() -> void:
	name = "TotoCompanion"
	add_to_group("toto")
	add_to_group("party")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.25

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.22
	cap.height = 0.48
	col.shape = cap
	col.position = Vector3(0, 0.24, 0)
	add_child(col)

	var cam_anchor := Node3D.new()
	cam_anchor.name = "CameraAnchor"
	cam_anchor.position = Vector3(0, 0.88, 0)
	add_child(cam_anchor)

	var vis := Node3D.new()
	vis.name = "Visual"
	add_child(vis)
	_parts = build_dog_visual(vis, greyscale)

	var party := get_node_or_null("/root/Party")
	if party and party.has_method("register"):
		party.call("register", &"toto", self, true)

func can_take_lead() -> bool:
	return visible

func set_leading(on: bool) -> void:
	leading = on

func set_player_controlled(on: bool) -> void:
	set_leading(on)

func play_bark() -> void:
	_bark_anim_t = 0.36

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

	_mi(body_root, _sph(0.14, 0.24), fur_dark, Vector3(0, 0.0, 0.02), Vector3.ZERO, Vector3(0.92, 0.88, 1.65))
	_mi(body_root, _sph(0.135, 0.24), fur_brindle, Vector3(0, 0.02, -0.11), Vector3.ZERO, Vector3(1.02, 0.95, 1.05))
	_mi(body_root, _sph(0.11, 0.20), fur_ruff, Vector3(0, -0.02, -0.17))

	_mi(body_root, _cyl(0.095, 0.10, 0.045), collar_m, Vector3(0, 0.07, -0.17), Vector3(38, 0, 0))
	_mi(body_root, _sph(0.025, 0.045), tag_m, Vector3(0, 0.02, -0.24))

	var head := Node3D.new()
	head.position = Vector3(0, 0.14, -0.22)
	body_root.add_child(head)
	_mi(head, _sph(0.115, 0.22), fur_brindle, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1.0, 0.95, 1.05))
	_mi(head, _sph(0.075, 0.13), fur_ruff, Vector3(0, -0.02, -0.10), Vector3.ZERO, Vector3(1.15, 0.82, 1.1))
	_mi(head, _sph(0.032, 0.05), nose_m, Vector3(0, 0.005, -0.18), Vector3.ZERO, Vector3(1.2, 0.85, 0.9))
	_mi(head, _sph(0.024, 0.04), tongue_m, Vector3(0, -0.055, -0.13), Vector3(25, 0, 0), Vector3(0.9, 1.2, 0.6))
	for ex in [-0.048, 0.048]:
		var s: float = float(ex)
		_mi(head, _sph(0.022, 0.044), eye_m, Vector3(s, 0.045, -0.105))
		_mi(head, _sph(0.008, 0.016), shine_m, Vector3(s * 0.92, 0.054, -0.122))
	for sx in [-1.0, 1.0]:
		var s: float = float(sx)
		_mi(head, _cyl(0.008, 0.048, 0.12), fur_dark, Vector3(s * 0.075, 0.13, -0.01), Vector3(-12, 0, -s * 18))

	var tail := Node3D.new()
	tail.position = Vector3(0, 0.06, 0.22)
	body_root.add_child(tail)
	_mi(tail, _cyl(0.022, 0.038, 0.20), fur_dark, Vector3(0, 0.09, 0.04), Vector3(-28, 0, 0))

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
	bark_timer = maxf(bark_timer - delta, 0.0)
	_bark_anim_t = maxf(_bark_anim_t - delta, 0.0)

	var spd := 0.0
	var vis := get_node_or_null("Visual") as Node3D

	if global_position.y < -3.5:
		global_position = Vector3(clampf(global_position.x, -30.0, 30.0), 0.2, clampf(global_position.z, -50.0, 120.0))
		velocity = Vector3.ZERO

	if leading:
		if not is_on_floor():
			velocity.y -= gravity * delta
		elif velocity.y < 0.0:
			velocity.y = -1.0
		var move_dir := Vector3.ZERO
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
			if inp.length() > 0.05:
				var party := get_node_or_null("/root/Party")
				var basis_node: Node3D = party.call("camera_basis_node") as Node3D if (party and party.has_method("camera_basis_node")) else self
				var basis: Basis = basis_node.global_transform.basis if basis_node else global_transform.basis
				move_dir = basis * Vector3(inp.x, 0.0, inp.y)
				move_dir.y = 0.0
				if move_dir.length() > 0.01:
					move_dir = move_dir.normalized()
		var sprint_mult := 1.75 if Input.is_action_pressed("blink") else 1.0
		var target_spd := move_speed * sprint_mult
		if move_dir.length() > 0.05:
			var loco := get_node_or_null("/root/Locomotion")
			var steered := move_dir
			if loco and loco.has_method("steer"):
				var s: Vector3 = loco.call("steer", self, move_dir)
				if s.length() > 0.05:
					steered = s
			velocity.x = move_toward(velocity.x, steered.x * target_spd, 24.0 * delta)
			velocity.z = move_toward(velocity.z, steered.z * target_spd, 24.0 * delta)
			if vis:
				vis.rotation.y = lerp_angle(vis.rotation.y, atan2(-steered.x, -steered.z), 12.0 * delta)
			if loco and loco.has_method("try_step"):
				loco.call("try_step", self, steered, 1.15)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		if Input.is_action_just_pressed("blink") and is_on_floor():
			velocity.y = 7.6
		move_and_slide()
		spd = Vector2(velocity.x, velocity.z).length()

		if Input.is_action_just_pressed("kick") and bark_timer <= 0.0:
			_do_bark()
	else:
		var party := get_node_or_null("/root/Party")
		var target_body: Node3D = party.call("follow_body") as Node3D if (party and party.has_method("follow_body")) else null
		if target_body == null or target_body == self:
			target_body = get_tree().get_first_node_in_group("player") as Node3D
		if target_body == null or not is_instance_valid(target_body):
			return
		var parked := bool(target_body.get("parked")) if "parked" in target_body else false
		var target_pos := target_body.global_position + _follow_offset
		if parked:
			target_pos = target_body.global_position + Vector3(0.75, 0.0, 0.45)
		var to := target_pos - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > 18.0:
			global_position = target_pos
		elif dist > 0.45:
			var dir := to / dist
			spd = clampf(dist * 2.8, 1.8, 6.4)
			global_position += dir * spd * delta
			global_position.y = lerpf(global_position.y, target_body.global_position.y, clampf(8.0 * delta, 0.0, 1.0))
			if vis:
				vis.rotation.y = lerp_angle(vis.rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)

	_animate_dog(spd, delta)

func _do_bark() -> void:
	bark_timer = bark_cooldown
	play_bark()
	var vis := get_node_or_null("Visual") as Node3D
	var forward := -vis.global_transform.basis.z if vis else Vector3(0, 0, -1)
	var fx := get_node_or_null("/root/CombatFx")
	if fx and fx.has_method("bark_wave"):
		fx.call("bark_wave", self, global_position, forward)
	# Startle & knock back nearby enemies (non-lethal terrier scatter + brief fear/confuse!)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e is Node3D):
			continue
		if e.is_in_group("enemies_dead"):
			continue
		var d: float = global_position.distance_to((e as Node3D).global_position)
		if d <= bark_radius:
			if e.has_method("apply_fear"):
				e.call("apply_fear", 1.8, global_position)
			elif e.has_method("take_damage"):
				e.call("take_damage", 4, global_position, {"bark": true})

func _animate_dog(spd: float, delta: float) -> void:
	if _parts.is_empty():
		return
	var body_root: Node3D = _parts["body"] as Node3D
	var head: Node3D = _parts["head"] as Node3D
	var tail: Node3D = _parts["tail"] as Node3D
	var fl: Node3D = _parts["leg_fl"] as Node3D
	var fr: Node3D = _parts["leg_fr"] as Node3D
	var bl: Node3D = _parts["leg_bl"] as Node3D
	var br: Node3D = _parts["leg_br"] as Node3D

	if _bark_anim_t > 0.0:
		var u := sin((1.0 - _bark_anim_t / 0.36) * PI)
		body_root.position.y = 0.26 + 0.14 * u
		body_root.rotation.x = -0.35 * u
		head.rotation.x = 0.28 * u
		tail.rotation.z = sin(_wag_t * 18.0) * 0.55
		return

	body_root.rotation.x = 0.0
	if spd > 0.2:
		_phase += delta * (12.0 + spd * 2.2)
		var sw := sin(_phase) * 0.55
		fl.rotation.x = sw
		br.rotation.x = sw
		fr.rotation.x = -sw
		bl.rotation.x = -sw
		body_root.position.y = 0.26 + absf(sin(_phase)) * 0.035
	else:
		_phase = move_toward(_phase, 0.0, delta * 8.0)
		fl.rotation.x = 0.0
		fr.rotation.x = 0.0
		bl.rotation.x = 0.0
		br.rotation.x = 0.0
		body_root.position.y = 0.26 + sin(_wag_t * 3.0) * 0.008

	tail.rotation.z = sin(_wag_t * (11.0 if spd > 0.2 else 6.5)) * 0.42
	head.rotation.x = sin(_wag_t * 2.4) * 0.06
