extends CharacterBody3D


## Cursed Munchkin puppet / rogue. Kick staggers. Scarecrow confuses. Lion fears.
## Targets current Lead (Bond), not Dorothy only.

enum State { WANDER, APPROACH, TELEGRAPH, LUNGE, RECOVER, STAGGER, CONFUSED, FEARED, DEAD }

@export var health: int = 30
@export var tint: Color = Color(0.93, 0.62, 0.72, 1)
@export var notice_range: float = 9.0
@export var lunge_range: float = 1.75
## Once armed, always chase the Lead out to this range (map-scale hunt — no freeze-wander).
@export var hunt_range: float = 200.0
@export var approach_speed: float = 3.55
@export var armored: bool = false
@export var is_marshal: bool = false
## Seconds before full combat (sneak/creep first). 0 = fight-ready immediately.
@export var activation_delay: float = 0.0
@export var sneak_speed: float = 1.85
## Keep combat inside the playable map (set by the level to match MapBorder).
@export var bound_half_x: float = 56.0
@export var bound_half_z: float = 52.0

var state: State = State.WANDER
var state_time: float = 0.0
var lunge_dir: Vector3 = Vector3.ZERO
var hit_this_lunge: bool = false
var target: Node3D
var gravity: float = 24.0
var body_mat: StandardMaterial3D
var confuse_t: float = 0.0
var fear_t: float = 0.0
var bind_t: float = 0.0
var enamored_t: float = 0.0
var _chain_partner: Node3D = null
var _chain_t: float = 0.0
var fear_from: Vector3 = Vector3.ZERO
var combat_ready: bool = true
var _activate_t: float = 0.0
var _base_notice: float = 9.0
var _anim_phase: float = 0.0
var _p_head: Node3D
var _p_arm_l: Node3D
var _p_arm_r: Node3D
var _p_leg_l: Node3D
var _p_leg_r: Node3D

@onready var visual: Node3D = $Visual

func _ready() -> void:
	add_to_group("enemies")
	_base_notice = notice_range
	if is_marshal:
		health = 90
		scale = Vector3(1.35, 1.35, 1.35)
		notice_range = 12.0
		_base_notice = 12.0
	if activation_delay > 0.0:
		combat_ready = false
		notice_range = 5.5 # only react if the player walks into them while sneaking
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = tint
	body_mat.roughness = 0.55
	call_deferred("_build_detailed_visual")

func set_play_bounds(half_x: float, half_z: float) -> void:
	bound_half_x = maxf(half_x, 8.0)
	bound_half_z = maxf(half_z, 8.0)
	_clamp_in_bounds()

## Call after spawn to delay full aggression (landing sneak-up).
func arm_delayed(delay: float, slow: float = 0.85) -> void:
	activation_delay = maxf(delay, 0.0)
	sneak_speed = maxf(slow, 1.2)
	_activate_t = 0.0
	if activation_delay > 0.0:
		combat_ready = false
		notice_range = 5.5
		_set_state(State.WANDER)

## Place this rogue far off-camera and march toward `toward` so they don't pop in.
## Spawn is always clamped inside play bounds so the compass never points past the map edge.
func march_from_afar(toward: Vector3, bearing_rad: float, distance: float = 24.0, delay: float = 11.0, walk_spd: float = 1.85) -> void:
	var dir := Vector3(sin(bearing_rad), 0.0, cos(bearing_rad))
	if dir.length() < 0.01:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	# Cap march length so the spawn stays on the playable side of MapBorder.
	var max_d := distance
	if absf(dir.x) > 0.05:
		var room_x: float = (bound_half_x - 1.5 - absf(toward.x)) / absf(dir.x)
		max_d = minf(max_d, maxf(room_x, 6.0))
	if absf(dir.z) > 0.05:
		var room_z: float = (bound_half_z - 1.5 - absf(toward.z)) / absf(dir.z)
		max_d = minf(max_d, maxf(room_z, 6.0))
	max_d = clampf(max_d, 8.0, distance)
	var spawn := toward + dir * max_d + Vector3(0, 0.08, 0)
	spawn.x = clampf(spawn.x, -bound_half_x + 1.2, bound_half_x - 1.2)
	spawn.z = clampf(spawn.z, -bound_half_z + 1.2, bound_half_z - 1.2)
	# If clamp collapsed onto the player, push to the nearest rim inside bounds.
	if spawn.distance_to(toward) < 6.0:
		spawn = toward + dir * 10.0
		spawn.x = clampf(spawn.x, -bound_half_x + 1.2, bound_half_x - 1.2)
		spawn.z = clampf(spawn.z, -bound_half_z + 1.2, bound_half_z - 1.2)
	global_position = spawn
	# Face the approach path (toward the rally).
	var in_dir := toward - global_position
	in_dir.y = 0.0
	if in_dir.length() > 0.01:
		in_dir = in_dir.normalized()
		rotation.y = atan2(-in_dir.x, -in_dir.z)
	arm_delayed(delay, maxf(walk_spd, 1.6))
	notice_range = 4.0

func _clamp_in_bounds() -> void:
	var p := global_position
	var nx := clampf(p.x, -bound_half_x, bound_half_x)
	var nz := clampf(p.z, -bound_half_z, bound_half_z)
	if nx != p.x or nz != p.z:
		global_position = Vector3(nx, p.y, nz)
		# Kill outward velocity so fear/knockback cannot pin them outside rails.
		if signf(velocity.x) == signf(p.x) and absf(p.x) >= bound_half_x - 0.05:
			velocity.x = -signf(p.x) * absf(velocity.x) * 0.35
		if signf(velocity.z) == signf(p.z) and absf(p.z) >= bound_half_z - 0.05:
			velocity.z = -signf(p.z) * absf(velocity.z) * 0.35

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	confuse_t = maxf(confuse_t - delta, 0.0)
	fear_t = maxf(fear_t - delta, 0.0)
	bind_t = maxf(bind_t - delta, 0.0)
	enamored_t = maxf(enamored_t - delta, 0.0)
	if _chain_t > 0.0:
		_chain_t = maxf(_chain_t - delta, 0.0)
		if _chain_t <= 0.0:
			_chain_partner = null
	_resolve_target()

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -1.0

	state_time += delta

	# Sneak phase: always walk toward the Lead — never idle on the rim.
	if not combat_ready and confuse_t <= 0.0 and fear_t <= 0.0 and state != State.STAGGER:
		_activate_t += delta
		_run_sneak(delta)
		if _activate_t >= activation_delay or _target_dist() < 2.2:
			_finish_arming()
		_pulse()
		_animate_puppet(delta)
		move_and_slide()
		_clamp_in_bounds()
		return

	if bind_t > 0.0 and state != State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
	elif enamored_t > 0.0 and state != State.DEAD and state != State.STAGGER:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		visual.rotation.y += delta * 1.4
	elif confuse_t > 0.0 and state != State.DEAD and state != State.STAGGER:
		_run_confused(delta)
	elif fear_t > 0.0 and state != State.DEAD and state != State.STAGGER:
		_run_feared(delta)
	else:
		match state:
			State.WANDER:
				# Any live target → hunt. Never freeze waiting for short notice_range.
				if target != null:
					_set_state(State.APPROACH)
				else:
					velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
					velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
			State.APPROACH:
				var to := _flat_to_target()
				var dist := to.length()
				if dist < lunge_range and dist > 0.01:
					lunge_dir = to / dist
					_set_state(State.TELEGRAPH)
				elif target == null or dist < 0.01:
					_set_state(State.WANDER)
				else:
					var dir := to / dist
					# Far = sprint in so the player never chases the map edge.
					var base := approach_speed * (1.25 if is_marshal else 1.0)
					var spd: float = base
					if dist > 40.0:
						spd = base * 2.4
					elif dist > 24.0:
						spd = base * 2.0
					elif dist > 14.0:
						spd = base * 1.65
					elif dist > 7.0:
						spd = base * 1.3
					var steered: Vector3 = Locomotion.steer(self, dir, 1.35)
					if steered.length() > 0.05:
						velocity.x = steered.x * spd
						velocity.z = steered.z * spd
						rotation.y = atan2(-steered.x, -steered.z)
						Locomotion.try_step(self, steered, 1.0)
					else:
						velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
						velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
			State.TELEGRAPH:
				velocity.x = 0.0
				velocity.z = 0.0
				visual.rotation.x = lerp_angle(visual.rotation.x, 0.45, 8.0 * delta)
				if is_marshal and health <= 45 and state_time < delta * 1.5 and target and CombatFx and CombatFx.has_method("aoe_telegraph"):
					var strike_p := target.global_position
					CombatFx.aoe_telegraph(get_parent(), strike_p, 2.7, 0.72, Color(0.96, 0.26, 0.42), func():
						if target and is_instance_valid(target) and target.global_position.distance_to(strike_p) < 2.8:
							if target.has_method("stumble"):
								target.call("stumble", global_position)
					)
				if state_time > (0.7 if is_marshal else 0.55):
					hit_this_lunge = false
					_set_state(State.LUNGE)
			State.LUNGE:
				visual.rotation.x = lerp_angle(visual.rotation.x, -0.35, 14.0 * delta)
				var spd := 8.5 if is_marshal else 7.2
				velocity.x = lunge_dir.x * spd
				velocity.z = lunge_dir.z * spd
				_try_shove()
				if state_time > 0.28:
					_set_state(State.RECOVER)
			State.RECOVER:
				visual.rotation.x = lerp_angle(visual.rotation.x, 0.0, 6.0 * delta)
				velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
				if state_time > 0.7:
					_set_state(State.APPROACH)
			State.STAGGER:
				visual.rotation.x = lerp_angle(visual.rotation.x, 0.2, 8.0 * delta)
				if state_time > 0.38:
					_set_state(State.APPROACH)
			State.CONFUSED, State.FEARED:
				pass

	_pulse()
	_animate_puppet(delta)
	move_and_slide()
	_clamp_in_bounds()

func _resolve_target() -> void:
	var party := get_node_or_null("/root/Party")
	if party and party.has_method("pick_threat_target"):
		var picked = party.call("pick_threat_target", self, target, hunt_range)
		if picked and is_instance_valid(picked):
			target = picked
			return
	if party and party.has_method("combat_bodies"):
		var bodies = party.call("combat_bodies")
		if bodies is Array and not bodies.is_empty():
			var best: Node3D = null
			var best_d := 1.0e9
			for b in bodies:
				if b is Node3D and is_instance_valid(b):
					var d: float = global_position.distance_to((b as Node3D).global_position)
					if d < best_d:
						best_d = d
						best = b as Node3D
			if best:
				target = best
				return
	if party and party.has_method("leader_body"):
		var lead = party.call("leader_body")
		if lead and is_instance_valid(lead):
			target = lead
			return
	target = get_tree().get_first_node_in_group("player")

func take_damage(amount: int, source_position: Vector3, tags: Dictionary = {}) -> void:
	if state == State.DEAD:
		return
	var dmg := amount
	if bind_t > 0.0 or enamored_t > 0.0:
		dmg = int(ceilf(float(dmg) * 1.5))
	if armored and not bool(tags.get("armor_break", false)):
		dmg = maxi(1, int(amount * 0.35))
		CombatFx.label(self, global_position, "CLINK", Color(0.8, 0.85, 0.95))
	else:
		if armored and bool(tags.get("armor_break", false)):
			armored = false
			if body_mat:
				body_mat.metallic = 0.0
			CombatFx.label(self, global_position, "SHATTER", Color(1.0, 0.85, 0.4))
	health -= dmg
	var away := global_position - source_position
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.FORWARD
	away = away.normalized()
	var knock := float(tags.get("knockback", 6.5))
	velocity.x = away.x * knock
	velocity.z = away.z * knock
	velocity.y = 1.6
	_set_state(State.STAGGER)
	CombatFx.flash_sphere(self, global_position + Vector3(0, 0.7, 0), Color(1.0, 0.5, 0.55), 0.35, 0.12)
	if CombatFx.has_method("blood_splatter"):
		CombatFx.blood_splatter(self, global_position, away, Color(0.62, 0.03, 0.06))
	# Gilded Chain tether mirrors 75% of damage onto bound partner!
	if not bool(tags.get("chain_echo", false)) and _chain_partner and is_instance_valid(_chain_partner) and _chain_partner.has_method("take_damage"):
		var echo_dmg := maxi(1, int(float(dmg) * 0.75))
		CombatFx.gilded_chain(self, global_position, _chain_partner.global_position)
		_chain_partner.take_damage(echo_dmg, global_position, {"chain_echo": true, "knockback": 2.0})
	if is_marshal:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_boss_bar"):
			var ph := "PHASE II — ENRAGED CLEAVE" if health <= 45 else "PHASE I — GUILD CAPTAIN"
			hud.call("show_boss_bar", "LOLLIPOP GUILD MARSHAL", ph, float(health), 90.0)
	if health <= 0:
		_die()

func apply_bind(duration: float = 3.5) -> void:
	if state == State.DEAD:
		return
	bind_t = maxf(bind_t, duration)
	CombatFx.silk_cocoon(self, global_position)
	CombatFx.label(self, global_position, "BOUND", Color(0.98, 0.36, 0.82))

func apply_enamored(duration: float = 5.0) -> void:
	if state == State.DEAD:
		return
	enamored_t = maxf(enamored_t, duration)
	CombatFx.label(self, global_position, "♥ ENAMORED", Color(1.0, 0.34, 0.66))

func set_chain_partner(other: Node3D, duration: float = 8.0) -> void:
	if state == State.DEAD or other == null or other == self:
		return
	_chain_partner = other
	_chain_t = duration
	CombatFx.label(self, global_position, "⛓ TETHERED", Color(1.0, 0.84, 0.30))

func apply_confuse(duration: float = 2.4) -> void:
	if state == State.DEAD:
		return
	confuse_t = maxf(confuse_t, duration)
	_set_state(State.CONFUSED)
	CombatFx.label(self, global_position, "?", Color(0.95, 0.85, 0.3))

func apply_fear(duration: float, from_pos: Vector3) -> void:
	if state == State.DEAD:
		return
	fear_t = maxf(fear_t, duration)
	fear_from = from_pos
	_set_state(State.FEARED)
	CombatFx.label(self, global_position, "!", Color(1.0, 0.7, 0.2))

func _run_confused(delta: float) -> void:
	# Wander randomly — Scarecrow hard counter
	if state_time > 0.4 or velocity.length() < 0.2:
		var a := randf() * TAU
		velocity.x = cos(a) * 2.4
		velocity.z = sin(a) * 2.4
		state_time = 0.0
	visual.rotation.y += delta * 4.0

func _run_feared(delta: float) -> void:
	var away := global_position - fear_from
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3(1, 0, 0)
	away = away.normalized()
	velocity.x = away.x * 5.5
	velocity.z = away.z * 5.5
	rotation.y = atan2(-away.x, -away.z)

func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	add_to_group("enemies_dead")
	if is_marshal:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("hide_boss_bar"):
			hud.call("hide_boss_bar")
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("add_desire"):
		var bonus := 8 if (bind_t > 0.0 or enamored_t > 0.0) else 3
		sm.add_desire(bonus, "Allure Execution" if bonus > 3 else "")
	var tween := create_tween()
	tween.tween_property(visual, "rotation:x", deg_to_rad(78), 0.35)
	tween.parallel().tween_property(visual, "position:y", 0.15, 0.35)
	# Notify level
	var land := get_tree().current_scene
	if land and land.has_method("on_enemy_down"):
		land.on_enemy_down(self)

func _try_shove() -> void:
	if hit_this_lunge or target == null:
		return
	if global_position.distance_to(target.global_position) > 1.15:
		return
	hit_this_lunge = true
	if target.has_method("is_intangible") and target.is_intangible():
		return
	if target.has_method("stumble"):
		target.stumble(global_position)

func _target_dist() -> float:
	if target == null:
		return 999.0
	return global_position.distance_to(target.global_position)

func _flat_to_target() -> Vector3:
	if target == null:
		return Vector3.ZERO
	var to := target.global_position - global_position
	to.y = 0.0
	return to

func _set_state(next: State) -> void:
	state = next
	state_time = 0.0

func _run_sneak(delta: float) -> void:
	# Always walk toward the current Lead — never stand still on the rim waiting to be found.
	var to := _flat_to_target()
	var dist := to.length()
	if dist < 0.05 or target == null:
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
		return
	var dir := to / dist
	var t_frac: float = 0.7
	if activation_delay > 0.01:
		t_frac = clampf(_activate_t / activation_delay, 0.55, 1.0)
	var spd: float = sneak_speed * t_frac
	if dist < 2.6 and _activate_t < activation_delay * 0.85:
		spd *= 0.55
	# Far march = purposeful approach so the fight comes to you.
	if dist > 28.0:
		spd = maxf(spd, sneak_speed * 2.1)
	elif dist > 16.0:
		spd = maxf(spd, sneak_speed * 1.7)
	elif dist > 8.0:
		spd = maxf(spd, sneak_speed * 1.25)
	var steered: Vector3 = Locomotion.steer(self, dir, 1.25)
	if steered.length() > 0.05:
		velocity.x = steered.x * spd
		velocity.z = steered.z * spd
		rotation.y = atan2(-steered.x, -steered.z)
		Locomotion.try_step(self, steered, 1.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	if visual:
		visual.rotation.x = lerp_angle(visual.rotation.x, 0.08, 4.0 * delta)

func _finish_arming() -> void:
	combat_ready = true
	notice_range = _base_notice if _base_notice > 0.1 else 9.0
	if is_marshal:
		notice_range = maxf(notice_range, 12.0)
	# Armed = always hunt. No mid-map idle.
	if target != null:
		_set_state(State.APPROACH)
	else:
		_set_state(State.WANDER)

func _pulse() -> void:
	if body_mat == null:
		return
	if state == State.TELEGRAPH:
		body_mat.emission_enabled = true
		body_mat.emission = Color(0.55, 0.15, 0.35)
		body_mat.emission_energy_multiplier = 1.2 + sin(state_time * 28.0) * 0.8
	elif confuse_t > 0.0:
		body_mat.emission_enabled = true
		body_mat.emission = Color(0.9, 0.8, 0.2)
		body_mat.emission_energy_multiplier = 1.0
	elif fear_t > 0.0:
		body_mat.emission_enabled = true
		body_mat.emission = Color(1.0, 0.5, 0.15)
		body_mat.emission_energy_multiplier = 1.1
	elif state == State.DEAD:
		body_mat.emission_enabled = false
	else:
		body_mat.emission_enabled = armored
		if armored:
			body_mat.emission = Color(0.4, 0.5, 0.6)
			body_mat.emission_energy_multiplier = 0.35

func _pm(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	n.rotation_degrees = rot_deg
	n.scale = scl
	parent.add_child(n)
	return n

func _mat_s(c: Color, rough: float = 0.65, metal: float = 0.0, emit_c: Color = Color(0, 0, 0), emit_e: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit_c
		m.emission_energy_multiplier = emit_e
	return m

func _build_detailed_visual() -> void:
	if visual == null or not is_instance_valid(visual):
		return
	for c in visual.get_children():
		c.queue_free()

	body_mat.albedo_color = tint
	body_mat.metallic = 0.58 if armored else 0.08
	body_mat.roughness = 0.34 if armored else 0.56

	var licorice := _mat_s(Color(0.08, 0.05, 0.09), 0.42, 0.12)
	var porcelain := _mat_s(Color(0.95, 0.91, 0.86), 0.32, 0.05)
	var brass := _mat_s(Color(0.90, 0.72, 0.30), 0.28, 0.85)
	var crimson := _mat_s(Color(0.72, 0.12, 0.22), 0.45, 0.1)
	var eye_glow := _mat_s(Color(1.0, 0.32, 0.46), 0.2, 0.0, Color(1.0, 0.24, 0.40), 1.4)
	var stitch := _mat_s(Color(0.35, 0.08, 0.18), 0.5, 0.0, Color(0.82, 0.18, 0.38), 0.7)
	var ruff := _mat_s(Color(0.96, 0.93, 0.90), 0.78)

	# Tailored cabaret waistcoat torso + flared coat skirt
	var coat_c := CylinderMesh.new()
	coat_c.top_radius = 0.17
	coat_c.bottom_radius = 0.24
	coat_c.height = 0.46
	coat_c.radial_segments = 12
	_pm(visual, coat_c, body_mat, Vector3(0, 0.68, 0))

	var skirt_c := CylinderMesh.new()
	skirt_c.top_radius = 0.23
	skirt_c.bottom_radius = 0.32
	skirt_c.height = 0.22
	skirt_c.radial_segments = 12
	_pm(visual, skirt_c, body_mat, Vector3(0, 0.42, 0))

	# Licorice waist belt + brass buckle + buttons + glowing stitch seam
	var belt_c := CylinderMesh.new()
	belt_c.top_radius = 0.22
	belt_c.bottom_radius = 0.22
	belt_c.height = 0.08
	_pm(visual, belt_c, licorice, Vector3(0, 0.52, 0))
	var b_box := BoxMesh.new()
	b_box.size = Vector3(0.10, 0.09, 0.05)
	_pm(visual, b_box, brass, Vector3(0, 0.52, -0.21))

	var st_box := BoxMesh.new()
	st_box.size = Vector3(0.035, 0.32, 0.035)
	_pm(visual, st_box, stitch, Vector3(0, 0.72, -0.21))
	for by in [0.62, 0.74, 0.84]:
		var bs := SphereMesh.new()
		bs.radius = 0.022
		bs.height = 0.044
		_pm(visual, bs, brass, Vector3(-0.07, float(by), -0.19))
		_pm(visual, bs, brass, Vector3(0.07, float(by), -0.19))

	# Ruffled Pierrot collar
	var collar_c := CylinderMesh.new()
	collar_c.top_radius = 0.24
	collar_c.bottom_radius = 0.16
	collar_c.height = 0.07
	collar_c.radial_segments = 14
	_pm(visual, collar_c, ruff, Vector3(0, 0.93, 0))

	# Marshal Armor Pauldrons & Sash
	if is_marshal or armored:
		var steel := _mat_s(Color(0.55, 0.60, 0.68), 0.28, 0.88)
		var chest_b := BoxMesh.new()
		chest_b.size = Vector3(0.36, 0.34, 0.26)
		_pm(visual, chest_b, steel, Vector3(0, 0.74, -0.04))
		for sx in [-1.0, 1.0]:
			var ep := SphereMesh.new()
			ep.radius = 0.11
			ep.height = 0.14
			_pm(visual, ep, brass if is_marshal else steel, Vector3(float(sx) * 0.25, 0.90, 0))

	# Articulated Head (Cracked porcelain mask + stitched grin + glowing eyes + cabaret hat)
	_p_head = Node3D.new()
	_p_head.position = Vector3(0, 1.08, 0)
	visual.add_child(_p_head)
	var h_sph := SphereMesh.new()
	h_sph.radius = 0.175
	h_sph.height = 0.36
	_pm(_p_head, h_sph, porcelain, Vector3(0, 0.06, 0))
	# Porcelain crack + exposed golden brass clockwork gears + multi-stitch grin (mem_04_porcelain_mask.jpg!)
	var crk := CylinderMesh.new()
	crk.top_radius = 0.006
	crk.bottom_radius = 0.006
	crk.height = 0.18
	_pm(_p_head, crk, licorice, Vector3(0.062, 0.10, -0.165), Vector3(0, 0, 18))
	var gear_t := TorusMesh.new()
	gear_t.inner_radius = 0.018
	gear_t.outer_radius = 0.032
	_pm(_p_head, gear_t, brass, Vector3(0.068, 0.095, -0.162), Vector3(90, 0, 0))
	for gi in range(-2, 3):
		var gt := float(gi) / 2.0
		var st := CylinderMesh.new()
		st.top_radius = 0.0045
		st.bottom_radius = 0.0045
		st.height = 0.028
		_pm(_p_head, st, licorice, Vector3(gt * 0.065, -0.022 + gt * gt * 0.018, -0.164), Vector3(0, 0, 90.0 - gt * 18.0))
	# Glowing eyes with specular catchlights
	var glint_m := StandardMaterial3D.new()
	glint_m.albedo_color = Color.WHITE
	glint_m.emission_enabled = true
	glint_m.emission = Color.WHITE
	glint_m.emission_energy_multiplier = 1.6
	for ex in [-0.065, 0.065]:
		var es := SphereMesh.new()
		es.radius = 0.032
		es.height = 0.064
		_pm(_p_head, es, eye_glow, Vector3(float(ex), 0.09, -0.155))
		var gs := SphereMesh.new()
		gs.radius = 0.009
		gs.height = 0.018
		_pm(_p_head, gs, glint_m, Vector3(float(ex) - 0.008, 0.102, -0.180))

	# Hat: Spiked Candied-Crimson Marshal Shako vs Bell-Tipped Rose Munchkin Enforcer Hat
	if is_marshal:
		var shako := CylinderMesh.new()
		shako.top_radius = 0.18
		shako.bottom_radius = 0.16
		shako.height = 0.32
		_pm(_p_head, shako, crimson, Vector3(0, 0.33, 0))
		var band := CylinderMesh.new()
		band.top_radius = 0.185
		band.bottom_radius = 0.185
		band.height = 0.06
		_pm(_p_head, band, brass, Vector3(0, 0.22, 0))
		# Lollipop swirl gold emblem on shako front
		var emblem := CylinderMesh.new()
		emblem.top_radius = 0.055
		emblem.bottom_radius = 0.055
		emblem.height = 0.025
		_pm(_p_head, emblem, brass, Vector3(0, 0.32, -0.175), Vector3(90, 0, 0))
		var plume := SphereMesh.new()
		plume.radius = 0.085
		plume.height = 0.26
		_pm(_p_head, plume, crimson, Vector3(0, 0.56, -0.04))
		# Spiked candied-crimson armored pauldrons (enemy_06_marshal_boss.jpg)
		for px in [-1.0, 1.0]:
			var ps := SphereMesh.new()
			ps.radius = 0.14
			ps.height = 0.18
			_pm(visual, ps, crimson, Vector3(float(px) * 0.28, 0.90, 0))
			var spk := CylinderMesh.new()
			spk.top_radius = 0.005
			spk.bottom_radius = 0.028
			spk.height = 0.11
			_pm(visual, spk, brass, Vector3(float(px) * 0.34, 0.98, 0), Vector3(0, 0, -float(px) * 38.0))
	else:
		# Ruffled cream neck collar + rosy porcelain cheeks + bell-tipped pointed hat (enemy_05_munchkin_enforcer.jpg)
		var neck_ruff := CylinderMesh.new()
		neck_ruff.top_radius = 0.18
		neck_ruff.bottom_radius = 0.14
		neck_ruff.height = 0.07
		_pm(_p_head, neck_ruff, porcelain, Vector3(0, -0.08, 0))
		for cx in [-0.095, 0.095]:
			var ch := SphereMesh.new()
			ch.radius = 0.028
			ch.height = 0.044
			_pm(_p_head, ch, crimson, Vector3(float(cx), 0.03, -0.145))
		var brim := CylinderMesh.new()
		brim.top_radius = 0.26
		brim.bottom_radius = 0.26
		brim.height = 0.035
		_pm(_p_head, brim, crimson, Vector3(0, 0.21, 0), Vector3(-6, 0, 8))
		var crown := CylinderMesh.new()
		crown.top_radius = 0.035
		crown.bottom_radius = 0.15
		crown.height = 0.32
		_pm(_p_head, crown, crimson, Vector3(0.03, 0.36, 0), Vector3(-10, 0, 18))
		var rib := CylinderMesh.new()
		rib.top_radius = 0.155
		rib.bottom_radius = 0.155
		rib.height = 0.05
		_pm(_p_head, rib, brass, Vector3(0.01, 0.24, 0), Vector3(-6, 0, 10))
		var bell := SphereMesh.new()
		bell.radius = 0.036
		bell.height = 0.072
		_pm(_p_head, bell, brass, Vector3(0.11, 0.50, 0.04))

	# Articulated Arms + Weapon (Licorice Cane / Marshal Halberd)
	_p_arm_l = _build_arm(-1.0, licorice, porcelain, brass, crimson)
	_p_arm_r = _build_arm(1.0, licorice, porcelain, brass, crimson)

	# Articulated Legs + Spats Boots
	_p_leg_l = _build_leg(-1.0, licorice, porcelain)
	_p_leg_r = _build_leg(1.0, licorice, porcelain)

func _build_arm(side: float, licorice: Material, porcelain: Material, brass: Material, crimson: Material) -> Node3D:
	var arm := Node3D.new()
	arm.position = Vector3(side * 0.25, 0.86, 0)
	visual.add_child(arm)
	var sleeve := CylinderMesh.new()
	sleeve.top_radius = 0.065
	sleeve.bottom_radius = 0.05
	sleeve.height = 0.38
	_pm(arm, sleeve, body_mat, Vector3(0, -0.18, 0))
	var hand := SphereMesh.new()
	hand.radius = 0.048
	hand.height = 0.096
	_pm(arm, hand, porcelain, Vector3(0, -0.39, 0))
	# Weapon in right hand
	if side > 0.0:
		var staff := CylinderMesh.new()
		staff.top_radius = 0.024
		staff.bottom_radius = 0.024
		staff.height = 0.95 if is_marshal else 0.62
		_pm(arm, staff, licorice, Vector3(0.02, -0.44, -0.26), Vector3(72, 0, 0))
		if is_marshal:
			# Massive serrated ceremonial cleaver (enemy_06_marshal_boss.jpg)
			var blade := BoxMesh.new()
			blade.size = Vector3(0.045, 0.42, 0.24)
			_pm(arm, blade, porcelain, Vector3(0.02, -0.58, -0.72), Vector3(72, 0, 0))
			var guard := BoxMesh.new()
			guard.size = Vector3(0.06, 0.08, 0.26)
			_pm(arm, guard, brass, Vector3(0.02, -0.42, -0.52), Vector3(72, 0, 0))
		else:
			# Gold-filigree short hatchet blade (enemy_05_munchkin_enforcer.jpg)
			var hatchet := BoxMesh.new()
			hatchet.size = Vector3(0.032, 0.18, 0.16)
			_pm(arm, hatchet, porcelain, Vector3(0.02, -0.54, -0.52), Vector3(72, 0, 0))
			var collar := BoxMesh.new()
			collar.size = Vector3(0.042, 0.07, 0.07)
			_pm(arm, collar, brass, Vector3(0.02, -0.50, -0.44), Vector3(72, 0, 0))
	return arm

func _build_leg(side: float, licorice: Material, porcelain: Material) -> Node3D:
	var leg := Node3D.new()
	leg.position = Vector3(side * 0.11, 0.42, 0)
	visual.add_child(leg)
	var shin := CylinderMesh.new()
	shin.top_radius = 0.058
	shin.bottom_radius = 0.046
	shin.height = 0.36
	_pm(leg, shin, licorice, Vector3(0, -0.18, 0))
	var boot := SphereMesh.new()
	boot.radius = 0.062
	boot.height = 0.095
	var b_mi := _pm(leg, boot, licorice, Vector3(0, -0.37, -0.045))
	b_mi.scale = Vector3(0.95, 0.72, 1.68)
	var spat := CylinderMesh.new()
	spat.top_radius = 0.056
	spat.bottom_radius = 0.056
	spat.height = 0.065
	_pm(leg, spat, porcelain, Vector3(0, -0.31, 0))
	return leg

func _animate_puppet(delta: float) -> void:
	if _p_leg_l == null:
		return
	var hspd := Vector2(velocity.x, velocity.z).length()
	if confuse_t > 0.0:
		_anim_phase += delta * 11.0
		_p_head.rotation.z = sin(_anim_phase) * 0.45
		_p_arm_l.rotation.z = 0.6 + sin(_anim_phase * 1.3) * 0.3
		_p_arm_r.rotation.z = -0.6 - sin(_anim_phase * 1.3) * 0.3
		return
	if fear_t > 0.0:
		_anim_phase += delta * 15.0
		_p_arm_l.rotation.x = -2.1 + sin(_anim_phase) * 0.4
		_p_arm_r.rotation.x = -2.1 - sin(_anim_phase) * 0.4
		_p_leg_l.rotation.x = sin(_anim_phase) * 0.75
		_p_leg_r.rotation.x = -sin(_anim_phase) * 0.75
		return
	if state == State.TELEGRAPH:
		_p_arm_r.rotation.x = lerp_angle(_p_arm_r.rotation.x, -1.9, 10.0 * delta)
		_p_arm_l.rotation.x = lerp_angle(_p_arm_l.rotation.x, 0.5, 10.0 * delta)
		_p_head.rotation.z = lerp_angle(_p_head.rotation.z, 0.22, 8.0 * delta)
		return
	if state == State.LUNGE:
		_p_arm_r.rotation.x = lerp_angle(_p_arm_r.rotation.x, 1.35, 18.0 * delta)
		return
	if hspd > 0.25:
		_anim_phase += delta * (7.5 + clampf(hspd * 1.2, 0.0, 8.0))
		var sw := sin(_anim_phase) * 0.62
		_p_leg_l.rotation.x = sw
		_p_leg_r.rotation.x = -sw
		_p_arm_l.rotation.x = -sw * 0.85
		_p_arm_r.rotation.x = sw * 0.75
		_p_arm_l.rotation.z = 0.12
		_p_arm_r.rotation.z = -0.12
		_p_head.rotation.z = sin(_anim_phase * 0.5) * 0.12
	else:
		_anim_phase += delta * 2.4
		_p_leg_l.rotation.x = lerp_angle(_p_leg_l.rotation.x, 0.0, 6.0 * delta)
		_p_leg_r.rotation.x = lerp_angle(_p_leg_r.rotation.x, 0.0, 6.0 * delta)
		_p_arm_l.rotation.x = lerp_angle(_p_arm_l.rotation.x, 0.0, 6.0 * delta)
		_p_arm_r.rotation.x = lerp_angle(_p_arm_r.rotation.x, 0.0, 6.0 * delta)
		_p_head.rotation.z = sin(_anim_phase) * 0.08