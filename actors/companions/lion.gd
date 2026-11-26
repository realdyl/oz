extends CharacterBody3D


## Cowardly Lion — fear identity. F = Lion's Roar (AoE fear + knockback). No blink.

@export var move_speed: float = 5.8
@export var acceleration: float = 16.0
@export var friction: float = 12.0
@export var gravity: float = 24.0
@export var roar_damage: int = 6
@export var roar_cooldown: float = 1.05
@export var roar_radius: float = 3.2
@export var follow_distance: float = 3.0

var leading: bool = false
var roar_timer: float = 0.0
var follow_target: Node3D = null
var hiding: bool = true
var calmed: bool = false
var kit_lock: float = 0.0
var _prev_vis_yaw: float = 0.0
var _armament_idx: int = 0
var _armament_cd: float = 0.0
const LION_ARMS := ["Apex Pounce", "Mane-Flare Courage", "Earthshaker Slam", "Velvet Stalk"]
## Asleep in poppies / safe park — do not trail Lead.
var parked: bool = false
var park_pos: Vector3 = Vector3.ZERO

@onready var visual: Node3D = $Visual
@onready var body: Node3D = $Visual/Body

func _ready() -> void:
	add_to_group("party")
	add_to_group("companions")
	floor_snap_length = 0.3
	Party.register(Party.ID_LION, self, false)
	Party.set_present(Party.ID_LION, false)
	if body and body.has_method("set_cowering"):
		body.set_cowering(true)

func can_take_lead() -> bool:
	return calmed and Party.is_unlocked(Party.ID_LION) and visible and not parked

func set_leading(on: bool) -> void:
	leading = on
	follow_target = null if on else Party.follow_body()

func set_player_controlled(on: bool) -> void:
	set_leading(on)

func set_parked(on: bool, pos: Vector3 = Vector3.ZERO) -> void:
	parked = on
	if on:
		if pos != Vector3.ZERO:
			park_pos = pos
			global_position = pos
		else:
			park_pos = global_position
		velocity = Vector3.ZERO
		follow_target = null
		leading = false
	else:
		park_pos = Vector3.ZERO
		set_sleeping(false)

func set_sleeping(on: bool) -> void:
	if body and body.has_method("set_sleeping"):
		body.call("set_sleeping", on)

func calm_and_join() -> void:
	if calmed:
		return
	calmed = true
	hiding = false
	if body and body.has_method("set_cowering"):
		body.set_cowering(false)
	Party.set_present(Party.ID_LION, true)
	Party.unlock(Party.ID_LION)
	follow_target = Party.follow_body()

func _physics_process(delta: float) -> void:
	roar_timer = maxf(roar_timer - delta, 0.0)
	kit_lock = maxf(kit_lock - delta, 0.0)
	_armament_cd = maxf(_armament_cd - delta, 0.0)
	if parked:
		global_position = Vector3(park_pos.x, global_position.y, park_pos.z)
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = -0.5
		_anim(delta)
		move_and_slide()
		return
	if hiding and not calmed:
		velocity = Vector3.ZERO
		if body and body.has_method("set_locomotion"):
			body.set_locomotion(0.0, delta)
		if visual:
			visual.position.y = sin(Time.get_ticks_msec() * 0.006) * 0.02
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	if global_position.y < -3.5:
		global_position = Vector3(clampf(global_position.x, -30.0, 30.0), 0.25, clampf(global_position.z, -50.0, 120.0))
		velocity = Vector3.ZERO
	if leading:
		if kit_lock <= 0.0:
			_move_as_lead(delta)
			if Input.is_action_just_pressed("blink") and is_on_floor():
				velocity.y = 7.6
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
		if Input.is_action_just_pressed("kick") and roar_timer <= 0.0:
			_roar()
	else:
		_ally_or_follow(delta)
	_anim(delta)
	move_and_slide()

func _ally_or_follow(delta: float) -> void:
	if not calmed:
		_follow(delta)
		return
	var foe: Node3D = Party.nearest_enemy(self, 18.0) if Party else null
	var lead := Party.follow_body() if Party else null
	var leash_ok := true
	if lead and is_instance_valid(lead) and lead != self and foe:
		if global_position.distance_to(lead.global_position) > 26.0 \
				and foe.global_position.distance_to(lead.global_position) > 20.0:
			leash_ok = false
	if foe and leash_ok:
		_ally_fight(delta, foe)
	else:
		_follow(delta)

func _ally_fight(delta: float, foe: Node3D) -> void:
	var to := foe.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var hold := roar_radius * 0.65
	if dist > 0.05:
		var dir := to / dist
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)
		if dist > hold:
			var steered: Vector3 = Locomotion.steer(self, dir)
			if steered.length() > 0.05:
				velocity.x = steered.x * move_speed * 0.95
				velocity.z = steered.z * move_speed * 0.95
				_try_step(steered)
			else:
				velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
				velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
			if roar_timer <= 0.0 and kit_lock <= 0.0:
				_roar()
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)

func _move_as_lead(delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish := Vector3.ZERO
	if input.length() > 0.05:
		var basis_node := Party.camera_basis_node()
		var basis := basis_node.global_transform.basis if basis_node else global_transform.basis
		wish = basis * Vector3(input.x, 0.0, input.y)
		wish.y = 0.0
		if wish.length() > 0.01:
			wish = wish.normalized()
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-wish.x, -wish.z), 12.0 * delta)
	var cur_speed := move_speed * (1.82 if Locomotion.is_sprinting() else 1.0)
	if wish.length() > 0.05:
		var steered: Vector3 = Locomotion.steer(self, wish)
		if steered.length() < 0.05:
			steered = wish
		velocity.x = move_toward(velocity.x, steered.x * cur_speed, acceleration * delta * cur_speed)
		velocity.z = move_toward(velocity.z, steered.z * cur_speed, acceleration * delta * cur_speed)
		_try_step(steered)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta * move_speed)

func _follow(delta: float) -> void:
	follow_target = Party.follow_body()
	if follow_target == null or follow_target == self:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
		return
	var to := follow_target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var want := follow_distance + 0.6
	if dist > want:
		var dir := to / dist
		var steered: Vector3 = Locomotion.steer(self, dir)
		if steered.length() > 0.05:
			velocity.x = steered.x * move_speed * 0.9
			velocity.z = steered.z * move_speed * 0.9
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-steered.x, -steered.z), 8.0 * delta)
			_try_step(steered)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)

func _try_step(dir: Vector3) -> void:
	Locomotion.try_step(self, dir, 1.15)


func _roar() -> void:
	roar_timer = roar_cooldown
	kit_lock = 0.4
	var sm := get_node_or_null("/root/SaveManager")
	var eq: String = str(sm.equipped_outfits.get("lion", "")) if (sm and "equipped_outfits" in sm) else ""
	var eff_rad := roar_radius + (1.2 if eq == "lion_primal" else 0.0)
	var eff_fear := 2.8 if eq == "lion_primal" else 2.0
	if body and body.has_method("play_roar"):
		body.call("play_roar")
	var fwd := -visual.global_transform.basis.z if visual else Vector3(0, 0, -1)
	if CombatFx.has_method("roar_shockwave"):
		CombatFx.roar_shockwave(self, global_position, fwd, eff_rad)
	else:
		CombatFx.ring(self, global_position, Color(1.0, 0.55, 0.15), eff_rad * 0.55, 0.25)
		CombatFx.ring(self, global_position, Color(1.0, 0.4, 0.1), eff_rad, 0.45)
	CombatFx.label(self, global_position, "ROAR", Color(1.0, 0.65, 0.2))
	# Camera shake via pivot if available
	var pivot := Party.camera_basis_node() if Party else null
	if pivot:
		var base := pivot.position
		var tw := create_tween()
		tw.tween_property(pivot, "position", base + Vector3(0.08, 0.05, 0), 0.05)
		tw.tween_property(pivot, "position", base, 0.12)

	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = eff_rad
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = 4
	params.exclude = [get_rid()]
	params.transform = Transform3D(Basis(), global_position + Vector3(0, 0.6, 0))
	for hit in space.intersect_shape(params, 12):
		var collider: Object = hit.collider
		if collider == null:
			continue
		if collider.has_method("apply_fear"):
			collider.apply_fear(eff_fear, global_position)
		if collider.has_method("take_damage"):
			collider.take_damage(roar_damage, global_position, {"knockback": 11.0})

func _unhandled_key_input(event: InputEvent) -> void:
	if not leading or parked or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = (event as InputEventKey).keycode
	if kc == KEY_V:
		if body and body.has_method("play_flourish"):
			body.call("play_flourish")
	elif kc in [KEY_Z, KEY_X, KEY_C]:
		get_viewport().set_input_as_handled()
		if kc == KEY_Z:
			_armament_idx = (_armament_idx + LION_ARMS.size() - 1) % LION_ARMS.size()
			var h1 := get_tree().get_first_node_in_group("hud")
			if h1 and h1.has_method("set_active_armament"): h1.call("set_active_armament", LION_ARMS[_armament_idx])
		elif kc == KEY_X:
			_armament_idx = (_armament_idx + 1) % LION_ARMS.size()
			var h2 := get_tree().get_first_node_in_group("hud")
			if h2 and h2.has_method("set_active_armament"): h2.call("set_active_armament", LION_ARMS[_armament_idx])
		elif kc == KEY_C and _armament_cd <= 0.0:
			_use_lion_armament()

func _use_lion_armament() -> void:
	_armament_cd = 0.85
	var fwd := -visual.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.05 else Vector3.FORWARD
	match _armament_idx:
		0: # Apex Pounce — golden predatory leap that shatters vases & slams foes!
			velocity = Vector3(fwd.x * 15.5, 6.2, fwd.z * 15.5)
			if body and body.has_method("play_roar"): body.call("play_roar")
			CombatFx.ring(self, global_position, Color(1.0, 0.78, 0.24), 3.6, 0.36)
			CombatFx.label(self, global_position + Vector3(0, 1.3, 0), "✦ APEX POUNCE!", Color(1.0, 0.82, 0.30))
			for dp in get_tree().get_nodes_in_group("destructibles"):
				if dp is Node3D and is_instance_valid(dp) and (dp as Node3D).global_position.distance_to(global_position + fwd * 2.2) <= 4.8 and dp.has_method("take_damage"):
					dp.call("take_damage", 20, global_position, {})
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Node3D and is_instance_valid(e) and not e.is_in_group("enemies_dead") and (e as Node3D).global_position.distance_to(global_position + fwd * 2.2) <= 4.8:
					if e.has_method("take_damage"): e.call("take_damage", 16, global_position, {"knockback": 10.0})
		1: # Mane-Flare Courage — golden war-mane aura + style surge!
			if body and body.has_method("play_flourish"): body.call("play_flourish")
			var sm_l := get_node_or_null("/root/SaveManager")
			if sm_l and sm_l.has_method("register_style_action"):
				sm_l.call("register_style_action", 28.0, "Mane-Flare Courage")
			CombatFx.flash_sphere(self, global_position + Vector3(0, 0.9, 0), Color(1.0, 0.80, 0.26), 2.2, 0.38)
			CombatFx.label(self, global_position + Vector3(0, 1.4, 0), "✦ MANE-FLARE COURAGE!", Color(1.0, 0.86, 0.34))
		2: # Earthshaker Slam — radial brick-cracking shockwave!
			if body and body.has_method("play_roar"): body.call("play_roar")
			CombatFx.ring(self, global_position, Color(1.0, 0.56, 0.18), 5.6, 0.45)
			CombatFx.label(self, global_position + Vector3(0, 1.4, 0), "✦ EARTHSHAKER SLAM!", Color(1.0, 0.68, 0.24))
			for dp in get_tree().get_nodes_in_group("destructibles"):
				if dp is Node3D and is_instance_valid(dp) and (dp as Node3D).global_position.distance_to(global_position) <= 5.6 and dp.has_method("take_damage"):
					dp.call("take_damage", 22, global_position, {})
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Node3D and is_instance_valid(e) and not e.is_in_group("enemies_dead") and (e as Node3D).global_position.distance_to(global_position) <= 5.6:
					if e.has_method("apply_fear"): e.call("apply_fear", 2.8, global_position)
					if e.has_method("take_damage"): e.call("take_damage", 14, global_position, {"knockback": 12.0})
		3: # Velvet Stalk — gilds nearby vases/whimsies & grants brief stealth surge!
			velocity.x = fwd.x * 11.0
			velocity.z = fwd.z * 11.0
			for dp in get_tree().get_nodes_in_group("destructibles"):
				if dp is Node3D and is_instance_valid(dp) and (dp as Node3D).global_position.distance_to(global_position) <= 6.5 and dp.has_method("apply_perfume_bonus"):
					dp.call("apply_perfume_bonus")
			CombatFx.ring(self, global_position, Color(0.86, 0.48, 0.96), 3.2, 0.38)
			CombatFx.label(self, global_position + Vector3(0, 1.3, 0), "✦ VELVET STALK!", Color(0.94, 0.62, 1.0))

func _anim(delta: float) -> void:
	var yaw_diff := angle_difference(_prev_vis_yaw, visual.rotation.y)
	_prev_vis_yaw = visual.rotation.y
	var turn_vel := yaw_diff / maxf(delta, 0.001)
	var hs := Vector2(velocity.x, velocity.z).length()
	var bank := clampf(-turn_vel * 0.018 * clampf(hs / 5.0, 0.0, 1.2), -0.15, 0.15)
	visual.rotation.z = lerp_angle(visual.rotation.z, bank, 10.0 * delta)
	if body:
		if body.has_method("set_airborne"):
			body.call("set_airborne", velocity.y, is_on_floor(), turn_vel)
		if body.has_method("set_locomotion"):
			body.set_locomotion(hs, delta)