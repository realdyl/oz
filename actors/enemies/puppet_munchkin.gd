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
var fear_from: Vector3 = Vector3.ZERO
var combat_ready: bool = true
var _activate_t: float = 0.0
var _base_notice: float = 9.0

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
	var body := visual.get_node_or_null("Body") as MeshInstance3D
	if body:
		var active := body.get_active_material(0)
		if active is StandardMaterial3D:
			body_mat = (active as StandardMaterial3D).duplicate()
			body_mat.albedo_color = tint
			if armored:
				body_mat.metallic = 0.55
				body_mat.roughness = 0.35
			body.set_surface_override_material(0, body_mat)
	for part_name in ["Head", "ArmL", "ArmR"]:
		var part := visual.get_node_or_null(part_name) as MeshInstance3D
		if part and body_mat:
			part.set_surface_override_material(0, body_mat)

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
		move_and_slide()
		_clamp_in_bounds()
		return

	if confuse_t > 0.0 and state != State.DEAD and state != State.STAGGER:
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
	if health <= 0:
		_die()

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