extends CharacterBody3D

## 2026 Flagship Character — Toto ("The Faithful Companion")
## Matches char_06_toto.jpg & Boutique Couture (toto_classic, toto_silver_collar).
## Shaggy brindle Cairn Terrier fur shader, expressive blinking amber eyes with catchlights,
## perking/twitching pointed ears, shaggy whisker ruff, articulated 2-joint legs & 3-toe paws,
## sterling-silver star collar OR 8-spike engraved silver collar, playful bark & play-bow flourish.

@export var move_speed: float = 6.4
@export var gravity: float = 24.0
@export var bark_cooldown: float = 0.85
@export var bark_radius: float = 3.6

static var _brindle_shader: Shader = null

var greyscale: bool = false
var outfit_id: String = "toto_classic"
var leading: bool = false
var bark_timer: float = 0.0
var _bark_anim_t: float = 0.0
var _flourish_t: float = 0.0
var _still_t: float = 0.0
var _next_flourish: float = 5.5
var _eye_blink_cd: float = 2.8
var _eye_blink_t: float = 0.0
var _prev_vis_yaw: float = 0.0
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

	var sm := get_node_or_null("/root/SaveManager")
	if sm and "equipped_outfits" in sm:
		var eq: String = str(sm.equipped_outfits.get("toto", ""))
		if eq != "":
			outfit_id = eq

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
	_parts = build_dog_visual(vis, greyscale, outfit_id)

	var party := get_node_or_null("/root/Party")
	if party and party.has_method("register"):
		party.call("register", &"toto", self, true)

func set_outfit(new_outfit_id: String) -> void:
	outfit_id = new_outfit_id if new_outfit_id != "" else "toto_classic"
	var vis := get_node_or_null("Visual") as Node3D
	if vis:
		_parts = build_dog_visual(vis, greyscale, outfit_id)

func can_take_lead() -> bool:
	return visible

func set_leading(on: bool) -> void:
	leading = on

func set_player_controlled(on: bool) -> void:
	set_leading(on)

func play_bark() -> void:
	_bark_anim_t = 0.40
	_still_t = 0.0

func play_flourish() -> void:
	_flourish_t = 0.72
	_still_t = 0.0

static func _m(c: Color, rough: float = 0.88, metal: float = 0.0, grey: bool = false, rim_amt: float = 0.22) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if grey:
		var l := c.r * 0.3 + c.g * 0.5 + c.b * 0.2
		m.albedo_color = Color(l, l, l)
	else:
		m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if rim_amt > 0.01:
		m.rim_enabled = true
		m.rim = rim_amt
		m.rim_tint = 0.40
	return m

static func _make_brindle_material(c_dark: Color, c_warm: Color, grey: bool) -> ShaderMaterial:
	if _brindle_shader == null:
		_brindle_shader = Shader.new()
		_brindle_shader.code = """
shader_type spatial;
uniform vec4 col_dark : source_color = vec4(0.14, 0.12, 0.11, 1.0);
uniform vec4 col_warm : source_color = vec4(0.32, 0.25, 0.19, 1.0);
void fragment() {
	float stripe = sin(UV.x * 55.0 + sin(UV.y * 120.0) * 1.8) * 0.5 + 0.5;
	float fuzz = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.9);
	ALBEDO = mix(col_dark.rgb, col_warm.rgb, clamp(stripe * 0.65 + fuzz * 0.40, 0.0, 1.0));
	ROUGHNESS = 0.90;
	RIM = 0.45;
	RIM_TINT = 0.40;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _brindle_shader
	if grey:
		var ld := c_dark.r * 0.3 + c_dark.g * 0.5 + c_dark.b * 0.2
		var lw := c_warm.r * 0.3 + c_warm.g * 0.5 + c_warm.b * 0.2
		sm.set_shader_parameter("col_dark", Color(ld, ld, ld))
		sm.set_shader_parameter("col_warm", Color(lw, lw, lw))
	else:
		sm.set_shader_parameter("col_dark", c_dark)
		sm.set_shader_parameter("col_warm", c_warm)
	return sm

static func _mi(p: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	n.rotation_degrees = rot_deg
	n.scale = scl
	p.add_child(n)
	return n

static func _sph(r: float, h: float = -1.0, segs: int = 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0.0 else h
	s.radial_segments = segs
	s.rings = 10
	return s

static func _cyl(t: float, b: float, h: float, segs: int = 14) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = t
	c.bottom_radius = b
	c.height = h
	c.radial_segments = segs
	return c

static func _torus(ir: float, orad: float, rings_n: int = 18) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = ir
	t.outer_radius = orad
	t.rings = rings_n
	return t

## Builds the 2026 sculpted Cairn Terrier Toto under `parent` (used in Kansas, Oz & Boutique!).
static func build_dog_visual(parent: Node3D, is_grey: bool = false, active_outfit: String = "toto_classic") -> Dictionary:
	for c in parent.get_children():
		c.queue_free()

	var is_spiked := (active_outfit == "toto_silver_collar" or active_outfit == "toto_spiked") and not is_grey
	var fur_brindle := _make_brindle_material(Color(0.14, 0.12, 0.11), Color(0.32, 0.25, 0.19), is_grey)
	var fur_dark := _m(Color(0.14, 0.12, 0.11), 0.90, 0.0, is_grey, 0.32)
	var fur_ruff := _m(Color(0.36, 0.29, 0.23), 0.90, 0.0, is_grey, 0.36)
	var nose_m := _m(Color(0.04, 0.04, 0.05), 0.18, 0.12, is_grey, 0.0)
	var iris_m := _m(Color(0.34, 0.18, 0.08), 0.12, 0.05, is_grey, 0.0)
	var pupil_m := _m(Color(0.03, 0.02, 0.02), 0.08, 0.0, is_grey, 0.0)
	var shine_m := _m(Color(1.0, 1.0, 1.0), 0.05, 0.0, is_grey, 0.0)
	shine_m.emission_enabled = true
	shine_m.emission = Color(1.0, 1.0, 1.0)
	shine_m.emission_energy_multiplier = 1.3
	var tongue_m := _m(Color(0.88, 0.40, 0.46), 0.38, 0.0, is_grey, 0.0)
	var silver_m := _m(Color(0.92, 0.95, 1.0), 0.14, 0.96, is_grey, 0.25)
	if not is_grey:
		silver_m.emission_enabled = true
		silver_m.emission = Color(0.84, 0.90, 1.0)
		silver_m.emission_energy_multiplier = 0.55 if is_spiked else 0.30
	var collar_m: Material = silver_m if is_spiked else _m(Color(0.28, 0.16, 0.10), 0.42, 0.12, is_grey)

	var body_root := Node3D.new()
	body_root.name = "BodyRoot"
	body_root.position = Vector3(0, 0.26, 0)
	parent.add_child(body_root)

	# Contoured shaggy terrier torso + chest ruff + feathery skirt fur
	_mi(body_root, _sph(0.14, 0.24, 20), fur_brindle, Vector3(0, 0.0, 0.02), Vector3.ZERO, Vector3(0.92, 0.90, 1.68))
	_mi(body_root, _sph(0.135, 0.24, 18), fur_brindle, Vector3(0, 0.025, -0.11), Vector3.ZERO, Vector3(1.05, 0.98, 1.08))
	_mi(body_root, _sph(0.115, 0.20, 16), fur_ruff, Vector3(0, -0.02, -0.16), Vector3.ZERO, Vector3(1.05, 0.85, 1.0))

	# Collar + Sculpted 5-Point Sterling Silver Star Charm (+ 8 Silver Spikes for toto_silver_collar!)
	var collar_piv := Node3D.new()
	collar_piv.position = Vector3(0, 0.072, -0.175)
	collar_piv.rotation_degrees = Vector3(38, 0, 0)
	body_root.add_child(collar_piv)
	_mi(collar_piv, _torus(0.088, 0.106, 20), collar_m, Vector3.ZERO)
	if is_spiked:
		for si in range(8):
			var sa := float(si) / 8.0 * TAU
			_mi(collar_piv, _cyl(0.002, 0.015, 0.044, 8), silver_m, Vector3(cos(sa) * 0.122, 0.0, sin(sa) * 0.122), Vector3(sin(sa) * 90.0, 0.0, -cos(sa) * 90.0))

	var star_scl := 1.32 if is_spiked else 1.0
	for s_rot in [0.0, 72.0, -72.0]:
		_mi(body_root, _cyl(0.006 * star_scl, 0.020 * star_scl, 0.056 * star_scl, 8), silver_m, Vector3(0, 0.012, -0.252), Vector3(0, 0, float(s_rot)))

	# Sculpted Expressive Cairn Terrier Head, Shaggy Whisker Beard, Blinking Eyes & Perking Ears!
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.145, -0.22)
	body_root.add_child(head)
	_mi(head, _sph(0.118, 0.22, 20), fur_brindle, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1.04, 0.96, 1.06))
	# Shaggy terrier cheek ruffs & bearded snout (char_06_toto.jpg!)
	for sx in [-1.0, 1.0]:
		_mi(head, _sph(0.062, 0.11, 14), fur_ruff, Vector3(float(sx) * 0.072, -0.015, -0.045), Vector3.ZERO, Vector3(1.15, 0.88, 0.92))
		_mi(head, _sph(0.036, 0.05, 10), fur_ruff, Vector3(float(sx) * 0.046, 0.075, -0.085), Vector3(0, 0, float(sx) * -18.0), Vector3(1.2, 0.65, 0.8)) # bushy terrier eyebrows!
	_mi(head, _sph(0.076, 0.13, 16), fur_ruff, Vector3(0, -0.022, -0.105), Vector3.ZERO, Vector3(1.16, 0.84, 1.12))
	_mi(head, _sph(0.032, 0.05, 14), nose_m, Vector3(0, 0.006, -0.185), Vector3.ZERO, Vector3(1.22, 0.85, 0.90))
	_mi(head, _sph(0.022, 0.038, 10), tongue_m, Vector3(0, -0.056, -0.135), Vector3(26, 0, 0), Vector3(0.88, 1.22, 0.58))

	var eyelid_l: Node3D = null
	var eyelid_r: Node3D = null
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		var ex := s * 0.048
		_mi(head, _sph(0.022, 0.044, 14), iris_m, Vector3(ex, 0.045, -0.105))
		_mi(head, _sph(0.014, 0.028, 10), pupil_m, Vector3(ex, 0.045, -0.116))
		_mi(head, _sph(0.007, 0.014, 8), shine_m, Vector3(ex - s * 0.005, 0.053, -0.125))
		_mi(head, _sph(0.0035, 0.007, 6), shine_m, Vector3(ex + s * 0.005, 0.039, -0.124))
		var lid := Node3D.new()
		lid.position = Vector3(ex, 0.046, -0.105)
		lid.visible = false
		head.add_child(lid)
		_mi(lid, _sph(0.024, 0.048, 10), fur_dark, Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 0.95, 0.95))
		if s < 0:
			eyelid_l = lid
		else:
			eyelid_r = lid

	# Expressive Pointed Terrier Ears (pivoted so they perk & twitch!)
	var ear_l := Node3D.new()
	ear_l.position = Vector3(-0.072, 0.095, -0.01)
	head.add_child(ear_l)
	_mi(ear_l, _cyl(0.006, 0.046, 0.125, 12), fur_dark, Vector3(-0.008, 0.055, 0), Vector3(-10, 0, 16))

	var ear_r := Node3D.new()
	ear_r.position = Vector3(0.072, 0.095, -0.01)
	head.add_child(ear_r)
	_mi(ear_r, _cyl(0.006, 0.046, 0.125, 12), fur_dark, Vector3(0.008, 0.055, 0), Vector3(-10, 0, -16))

	# Upright Feathered Cairn Terrier Tail
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.065, 0.22)
	body_root.add_child(tail)
	_mi(tail, _cyl(0.018, 0.040, 0.21, 12), fur_brindle, Vector3(0, 0.095, 0.035), Vector3(-24, 0, 0))
	_mi(tail, _sph(0.026, 0.06, 10), fur_ruff, Vector3(0, 0.185, 0.072))

	var leg_fl := _make_paw_leg(body_root, Vector3(-0.082, -0.06, -0.135), fur_brindle, fur_dark)
	var leg_fr := _make_paw_leg(body_root, Vector3(0.082, -0.06, -0.135), fur_brindle, fur_dark)
	var leg_bl := _make_paw_leg(body_root, Vector3(-0.086, -0.06, 0.145), fur_brindle, fur_dark)
	var leg_br := _make_paw_leg(body_root, Vector3(0.086, -0.06, 0.145), fur_brindle, fur_dark)

	return {
		"body": body_root,
		"head": head,
		"ear_l": ear_l,
		"ear_r": ear_r,
		"eyelid_l": eyelid_l,
		"eyelid_r": eyelid_r,
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
	_mi(leg, _cyl(0.038, 0.028, 0.175, 12), fur, Vector3(0, -0.088, 0))
	_mi(leg, _sph(0.036, 0.052, 12), paw, Vector3(0, -0.18, -0.022), Vector3.ZERO, Vector3(0.95, 0.68, 1.32))
	for tx in [-0.018, 0.0, 0.018]:
		_mi(leg, _sph(0.012, 0.022, 8), paw, Vector3(float(tx), -0.186, -0.058))
	return leg

## Shared animation helper (callable by both live TotoCompanion AND Boutique turntable preview!)
static func animate_parts(parts: Dictionary, spd: float, wag_t: float, phase: float, bark_t: float, flourish_t: float, blink_u: float) -> void:
	if parts.is_empty():
		return
	var body_root := parts.get("body") as Node3D
	var head := parts.get("head") as Node3D
	var tail := parts.get("tail") as Node3D
	var ear_l := parts.get("ear_l") as Node3D
	var ear_r := parts.get("ear_r") as Node3D
	var lid_l := parts.get("eyelid_l") as Node3D
	var lid_r := parts.get("eyelid_r") as Node3D
	var fl := parts.get("leg_fl") as Node3D
	var fr := parts.get("leg_fr") as Node3D
	var bl := parts.get("leg_bl") as Node3D
	var br := parts.get("leg_br") as Node3D
	if body_root == null or head == null or tail == null:
		return

	if lid_l and lid_r:
		lid_l.visible = blink_u > 0.05
		lid_r.visible = blink_u > 0.05

	if bark_t > 0.0:
		var u := sin((1.0 - bark_t / 0.40) * PI)
		body_root.position.y = 0.26 + 0.16 * u
		body_root.rotation.x = -0.38 * u
		head.rotation.x = 0.30 * u
		tail.rotation.z = sin(wag_t * 20.0) * 0.58
		if ear_l and ear_r:
			ear_l.rotation.z = -0.18 * u
			ear_r.rotation.z = 0.18 * u
		return

	# Playful terrier play-bow & curious head-tilt flourish!
	if flourish_t > 0.0:
		var fu := sin((1.0 - flourish_t / 0.72) * PI)
		body_root.position.y = 0.24 - 0.03 * fu
		body_root.rotation.x = 0.32 * fu # front paws low, hind high play-bow!
		head.rotation = Vector3(-0.24 * fu, 0.12 * fu, 0.28 * fu)
		tail.rotation.z = sin(wag_t * 22.0) * 0.65
		if ear_l and ear_r:
			ear_l.rotation.z = -0.22 * fu
			ear_r.rotation.z = 0.22 * fu
		return

	body_root.rotation.x = 0.0
	if spd > 0.2:
		var sw := sin(phase) * 0.58
		fl.rotation.x = sw
		br.rotation.x = sw
		fr.rotation.x = -sw
		bl.rotation.x = -sw
		body_root.position.y = 0.26 + absf(sin(phase)) * 0.042
	else:
		fl.rotation.x = 0.0
		fr.rotation.x = 0.0
		bl.rotation.x = 0.0
		br.rotation.x = 0.0
		body_root.position.y = 0.26 + sin(wag_t * 3.0) * 0.008

	tail.rotation.z = sin(wag_t * (12.0 if spd > 0.2 else 6.8)) * 0.46
	head.rotation = Vector3(sin(wag_t * 2.4) * 0.06, sin(wag_t * 1.1) * 0.12 if spd <= 0.2 else 0.0, sin(wag_t * 0.8) * 0.08 if spd <= 0.2 else 0.0)
	if ear_l and ear_r:
		ear_l.rotation.z = sin(wag_t * 3.6) * 0.08
		ear_r.rotation.z = -sin(wag_t * 3.1) * 0.08

func _unhandled_key_input(event: InputEvent) -> void:
	if not leading:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		play_flourish()

func _physics_process(delta: float) -> void:
	_wag_t += delta
	bark_timer = maxf(bark_timer - delta, 0.0)
	_bark_anim_t = maxf(_bark_anim_t - delta, 0.0)
	_flourish_t = maxf(_flourish_t - delta, 0.0)

	_eye_blink_cd -= delta
	if _eye_blink_cd <= 0.0:
		_eye_blink_t = 0.12
		_eye_blink_cd = randf_range(2.4, 4.8)
	if _eye_blink_t > 0.0:
		_eye_blink_t = maxf(_eye_blink_t - delta, 0.0)

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

	if vis:
		var yaw_d := angle_difference(_prev_vis_yaw, vis.rotation.y)
		_prev_vis_yaw = vis.rotation.y
		var bank := clampf(-(yaw_d / maxf(delta, 0.001)) * 0.018 * clampf(spd / 4.5, 0.0, 1.2), -0.16, 0.16)
		vis.rotation.z = lerp_angle(vis.rotation.z, bank, 10.0 * delta)

	if spd > 0.2:
		_phase += delta * (12.0 + spd * 2.2)
		_still_t = 0.0
	else:
		_phase = move_toward(_phase, 0.0, delta * 8.0)
		if _bark_anim_t <= 0.0:
			_still_t += delta
			if _still_t >= _next_flourish:
				_still_t = 0.0
				_next_flourish = randf_range(6.5, 10.5)
				_flourish_t = 0.72

	var blink_u := sin((_eye_blink_t / 0.12) * PI) if _eye_blink_t > 0.0 else 0.0
	animate_parts(_parts, spd, _wag_t, _phase, _bark_anim_t, _flourish_t, blink_u)

func _do_bark() -> void:
	bark_timer = bark_cooldown
	play_bark()
	var vis := get_node_or_null("Visual") as Node3D
	var forward := -vis.global_transform.basis.z if vis else Vector3(0, 0, -1)
	var fx := get_node_or_null("/root/CombatFx")
	if fx and fx.has_method("bark_wave"):
		fx.call("bark_wave", self, global_position, forward)
	var eff_rad := bark_radius + (1.4 if outfit_id == "toto_silver_collar" else 0.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e is Node3D):
			continue
		if e.is_in_group("enemies_dead"):
			continue
		var d: float = global_position.distance_to((e as Node3D).global_position)
		if d <= eff_rad:
			if e.has_method("apply_fear"):
				e.call("apply_fear", 1.8, global_position)
			elif e.has_method("take_damage"):
				e.call("take_damage", 4, global_position, {"bark": true})
