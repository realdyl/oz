extends CharacterBody3D

## 2026 Sculpted Enemy — The Winged Monkey ("The Sky-Stalker")
## Built directly from the user's Creature Concept Design Sheet:
## Charcoal-furred simian torso, snarling fang muzzle, glowing amber eyes,
## brass-trimmed spiked shoulder pauldrons & bracers, curved prehensile tail,
## and large articulated flapping bat-wings with feathered secondary ridges.
## Circles overhead in L4 Winkie Castle and executes swooping dive-bomb strikes!

@export var max_health: int = 38
var health: int = 38
var dead: bool = false
var _bound_t: float = 0.0
var _enamored_t: float = 0.0
var _confuse_t: float = 0.0
var _fear_t: float = 0.0
var _chain_partner: Node3D = null
var _chain_t: float = 0.0
var _flap_t: float = 0.0
var _dive_cd: float = 2.6
var _diving: bool = false
var _dive_target: Vector3 = Vector3.ZERO
var _orbit_angle: float = 0.0
var _orbit_radius: float = 8.5
var _hover_y: float = 2.6
var _anchor: Vector3 = Vector3(0, 0, -2)
var _play_bound_x: float = 44.0
var _play_bound_z: float = 52.0

var _visual: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _tail: Node3D

func _ready() -> void:
	health = max_health
	collision_layer = 4
	collision_mask = 1
	add_to_group("enemies")
	_orbit_angle = randf() * TAU
	_dive_cd = randf_range(1.8, 3.6)
	_build_sky_stalker_visual()
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.55
	cap.height = 1.5
	col.shape = cap
	col.position = Vector3(0, 0.75, 0)
	add_child(col)

func setup_patrol(anchor: Vector3, radius: float = 9.0, hover_h: float = 2.6) -> void:
	_anchor = anchor
	_orbit_radius = radius
	_hover_y = hover_h
	global_position = anchor + Vector3(cos(_orbit_angle) * radius, hover_h, sin(_orbit_angle) * radius)

func set_play_bounds(bx: float, bz: float) -> void:
	_play_bound_x = bx
	_play_bound_z = bz

func apply_bind(dur: float) -> void:
	_bound_t = maxf(_bound_t, dur)
	_diving = false
	CombatFx.silk_cocoon(self, global_position)

func apply_enamored(dur: float) -> void:
	_enamored_t = maxf(_enamored_t, dur)
	_diving = false
	CombatFx.label(self, global_position + Vector3(0, 1.3, 0), "♥ ENAMORED", Color(1.0, 0.42, 0.80))

func apply_confuse(dur: float) -> void:
	_confuse_t = maxf(_confuse_t, dur)
	_diving = false

func apply_fear(dur: float) -> void:
	_fear_t = maxf(_fear_t, dur)
	_diving = false

func set_chain_partner(partner: Node3D, dur: float) -> void:
	_chain_partner = partner
	_chain_t = maxf(_chain_t, dur)

func take_damage(amount: int, from_pos: Vector3, _tags: Dictionary = {}) -> void:
	if dead:
		return
	health -= amount
	_diving = false
	CombatFx.hit_sparks(self, global_position + Vector3(0, 0.8, 0), Color(1.0, 0.72, 0.25))
	var kb := global_position - from_pos
	kb.y = 0.0
	if kb.length() > 0.05:
		global_position += kb.normalized() * 0.65
	if _chain_t > 0.0 and _chain_partner and is_instance_valid(_chain_partner) and _chain_partner.has_method("take_damage") and not _tags.get("chain_echo", false):
		_chain_partner.call("take_damage", maxi(1, int(float(amount) * 0.75)), global_position, {"chain_echo": true})
	if health <= 0:
		_die()

func _die() -> void:
	dead = true
	remove_from_group("enemies")
	add_to_group("enemies_dead")
	collision_layer = 0
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("add_desire"):
		sm.add_desire(10, "Winged Monkey Slain")
	if sm and sm.has_method("register_style_action"):
		sm.register_style_action(14.0, "Sky-Stalker Down")
	CombatFx.flash_sphere(self, global_position + Vector3(0, 0.8, 0), Color(0.95, 0.52, 0.18), 1.0, 0.32)
	CombatFx.label(self, global_position + Vector3(0, 1.4, 0), "✦ SKY-STALKER DOWN!", Color(1.0, 0.82, 0.36))
	var scene := get_tree().current_scene
	if scene and scene.has_method("on_enemy_down"):
		scene.call("on_enemy_down", self)
	var tw := create_tween()
	tw.tween_property(self, "global_position:y", 0.1, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale", Vector3.ONE * 0.05, 0.48)
	tw.tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	if dead:
		return
	_bound_t = maxf(_bound_t - delta, 0.0)
	_enamored_t = maxf(_enamored_t - delta, 0.0)
	_confuse_t = maxf(_confuse_t - delta, 0.0)
	_fear_t = maxf(_fear_t - delta, 0.0)
	_chain_t = maxf(_chain_t - delta, 0.0)
	_flap_t += delta * (11.5 if _diving else 6.8)

	# Animate articulated bat-wings & prehensile tail!
	if _wing_l and _wing_r:
		var flap := sin(_flap_t) * (0.72 if _diving else 0.52)
		_wing_l.rotation.z = 0.25 + flap
		_wing_r.rotation.z = -0.25 - flap
	if _tail:
		_tail.rotation.y = sin(_flap_t * 0.45) * 0.35

	# If bound/enamored, drop low to ground so melee fighters can easily punish!
	if _bound_t > 0.0 or _enamored_t > 0.0:
		global_position.y = lerpf(global_position.y, 0.35, clampf(delta * 5.0, 0.0, 1.0))
		return

	var target := _find_target()
	if _fear_t > 0.0 and target:
		var away := global_position - target.global_position
		away.y = 0.0
		if away.length() > 0.1:
			global_position += away.normalized() * 6.5 * delta
		global_position.y = lerpf(global_position.y, _hover_y + 1.2, delta * 3.0)
		return

	_dive_cd -= delta
	if not _diving and _dive_cd <= 0.0 and target and _confuse_t <= 0.0:
		_diving = true
		_dive_target = target.global_position + Vector3(0, 0.85, 0)
		_dive_cd = randf_range(3.2, 5.0)
		CombatFx.label(self, global_position + Vector3(0, 1.3, 0), "✦ SWOOP!", Color(1.0, 0.58, 0.22))

	if _diving:
		var to_d := _dive_target - global_position
		if to_d.length() < 1.25:
			# Strike check at apex of dive!
			if target and target.global_position.distance_to(global_position) < 2.2:
				var sm := get_node_or_null("/root/SaveManager")
				if sm and sm.has_method("take_damage"):
					sm.take_damage(1)
				CombatFx.hit_sparks(self, target.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.35, 0.22))
			_diving = false
		else:
			var step := to_d.normalized() * 9.5 * delta
			global_position += step
			if _visual:
				_visual.rotation.y = atan2(-to_d.x, -to_d.z)
	else:
		_orbit_angle += delta * (0.95 if _confuse_t <= 0.0 else -1.4)
		var center := target.global_position if target else _anchor
		var desired := Vector3(
			clampf(center.x + cos(_orbit_angle) * _orbit_radius, -_play_bound_x, _play_bound_x),
			_hover_y + sin(_flap_t * 0.4) * 0.35,
			clampf(center.z + sin(_orbit_angle) * _orbit_radius, -_play_bound_z, _play_bound_z)
		)
		var move_v := desired - global_position
		global_position += move_v.limit_length(5.8 * delta)
		if _visual and move_v.length() > 0.15:
			_visual.rotation.y = atan2(-move_v.x, -move_v.z)

func _find_target() -> Node3D:
	var party := get_node_or_null("/root/Party")
	if party and party.has_method("leader_body"):
		var lb = party.call("leader_body")
		if lb is Node3D and is_instance_valid(lb):
			return lb as Node3D
	return get_tree().get_first_node_in_group("player") as Node3D

func _mi(p: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot_deg
	m.scale = sc
	p.add_child(m)
	return m

func _mat(c: Color, rough: float = 0.72, metal: float = 0.0, em: Color = Color.BLACK, em_e: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if em_e > 0.0:
		m.emission_enabled = true
		m.emission = em
		m.emission_energy_multiplier = em_e
	return m

func _build_sky_stalker_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var fur := _mat(Color(0.14, 0.13, 0.15), 0.86)
	var face_skin := _mat(Color(0.46, 0.34, 0.28), 0.62)
	var armor := _mat(Color(0.22, 0.21, 0.24), 0.34, 0.82)
	var brass := _mat(Color(0.84, 0.66, 0.28), 0.24, 0.92)
	var wing_mem := _mat(Color(0.32, 0.22, 0.19), 0.64)
	wing_mem.cull_mode = BaseMaterial3D.CULL_DISABLED
	var eye_glow := _mat(Color(1.0, 0.66, 0.12), 0.10, 0.0, Color(1.0, 0.62, 0.08), 2.8)
	var fang_m := _mat(Color(0.95, 0.93, 0.88), 0.22)

	# Muscular crouching simian torso + crossed leather harness
	var chest := CapsuleMesh.new()
	chest.radius = 0.24; chest.height = 0.68
	_mi(_visual, chest, fur, Vector3(0, 0.78, 0), Vector3(18, 0, 0))
	var belt := TorusMesh.new()
	belt.inner_radius = 0.21; belt.outer_radius = 0.25
	_mi(_visual, belt, brass, Vector3(0, 0.56, 0))

	# Snarling Head + brow ridge + glowing amber eyes + bared fangs + pointed ears
	var head := SphereMesh.new()
	head.radius = 0.20; head.height = 0.38
	_mi(_visual, head, fur, Vector3(0, 1.18, -0.10))
	var muzzle := SphereMesh.new()
	muzzle.radius = 0.12; muzzle.height = 0.18
	_mi(_visual, muzzle, face_skin, Vector3(0, 1.13, -0.24), Vector3.ZERO, Vector3(1.0, 0.85, 1.15))
	var eye_s := SphereMesh.new()
	eye_s.radius = 0.032; eye_s.height = 0.064
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		_mi(_visual, eye_s, eye_glow, Vector3(s * 0.075, 1.21, -0.25))
		var ear := SphereMesh.new()
		ear.radius = 0.065; ear.height = 0.12
		_mi(_visual, ear, face_skin, Vector3(s * 0.19, 1.20, -0.08), Vector3(0, 0, -s * 18), Vector3(0.45, 1.0, 0.8))
		var fang := CylinderMesh.new()
		fang.top_radius = 0.014; fang.bottom_radius = 0.002; fang.height = 0.055
		_mi(_visual, fang, fang_m, Vector3(s * 0.045, 1.07, -0.32))

		# Spiked brass-trimmed shoulder pauldrons & clawed arms!
		var pauld := SphereMesh.new()
		pauld.radius = 0.15; pauld.height = 0.24
		_mi(_visual, pauld, armor, Vector3(s * 0.28, 0.98, -0.02), Vector3(0, 0, -s * 24))
		var spike := CylinderMesh.new()
		spike.top_radius = 0.004; spike.bottom_radius = 0.025; spike.height = 0.12
		_mi(_visual, spike, brass, Vector3(s * 0.35, 1.08, -0.02), Vector3(0, 0, -s * 35))
		var arm := CapsuleMesh.new()
		arm.radius = 0.075; arm.height = 0.56
		_mi(_visual, arm, fur, Vector3(s * 0.34, 0.68, -0.12), Vector3(-28, 0, s * 12))
		var bracer := CylinderMesh.new()
		bracer.top_radius = 0.082; bracer.bottom_radius = 0.075; bracer.height = 0.22
		_mi(_visual, bracer, brass, Vector3(s * 0.37, 0.52, -0.22), Vector3(-28, 0, s * 12))
		# Crouching hind legs
		var leg := CapsuleMesh.new()
		leg.radius = 0.085; leg.height = 0.48
		_mi(_visual, leg, fur, Vector3(s * 0.16, 0.32, 0.08), Vector3(24, 0, 0))

	# Curved prehensile tail
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.52, 0.22)
	_visual.add_child(_tail)
	var t_seg := CapsuleMesh.new()
	t_seg.radius = 0.032; t_seg.height = 0.58
	_mi(_tail, t_seg, fur, Vector3(0, 0.12, 0.24), Vector3(55, 0, 0))

	# Large Articulated Bat-Wings with feathered ridges & wing-tip claws!
	_wing_l = _build_wing(-1.0, fur, wing_mem, brass)
	_wing_r = _build_wing(1.0, fur, wing_mem, brass)
	_visual.add_child(_wing_l)
	_visual.add_child(_wing_r)

func _build_wing(side: float, fur: Material, mem: Material, brass: Material) -> Node3D:
	var piv := Node3D.new()
	piv.name = "WingL" if side < 0.0 else "WingR"
	piv.position = Vector3(side * 0.18, 0.96, 0.12)
	# Wing arm bone + primary & secondary leathery bat-membranes + wing claw
	var spar := CapsuleMesh.new()
	spar.radius = 0.036; spar.height = 1.25
	_mi(piv, spar, fur, Vector3(side * 0.58, 0.26, 0.10), Vector3(0, 0, side * 66))
	var panel1 := BoxMesh.new()
	panel1.size = Vector3(0.85, 0.58, 0.025)
	_mi(piv, panel1, mem, Vector3(side * 0.55, 0.08, 0.14), Vector3(12, side * 14, side * 18))
	var panel2 := BoxMesh.new()
	panel2.size = Vector3(0.75, 0.44, 0.022)
	_mi(piv, panel2, mem, Vector3(side * 1.18, 0.20, 0.16), Vector3(16, side * 22, -side * 16))
	var claw := CylinderMesh.new()
	claw.top_radius = 0.004; claw.bottom_radius = 0.022; claw.height = 0.14
	_mi(piv, claw, brass, Vector3(side * 1.12, 0.52, 0.08), Vector3(0, 0, -side * 28))
	return piv
