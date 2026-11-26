extends CharacterBody3D


## Scarecrow — crowd control. F = Confusing Caw (AoE confuse + light damage). No blink.

@export var move_speed: float = 4.6
@export var acceleration: float = 14.0
@export var friction: float = 12.0
@export var gravity: float = 24.0
@export var caw_damage: int = 5
@export var caw_cooldown: float = 0.85
@export var caw_radius: float = 2.6
@export var follow_distance: float = 2.4

var leading: bool = false
var caw_timer: float = 0.0
var follow_target: Node3D = null
var bound_on_pole: bool = true
var freed: bool = false
var kit_lock: float = 0.0
var _prev_vis_yaw: float = 0.0
var _armament_idx: int = 0
var _armament_cd: float = 0.0
const SCARECROW_ARMS := ["Straw Decoy", "Lantern Spark", "Harvest Gust", "Patchwork Tether"]

@onready var visual: Node3D = $Visual
@onready var body: Node3D = $Visual/Body

func _ready() -> void:
	add_to_group("party")
	add_to_group("companions")
	floor_snap_length = 0.3
	Party.register(Party.ID_SCARECROW, self, false)
	Party.set_present(Party.ID_SCARECROW, false)
	if bound_on_pole:
		_set_bound_pose(true)

func can_take_lead() -> bool:
	return freed and Party.is_unlocked(Party.ID_SCARECROW) and visible

func set_leading(on: bool) -> void:
	leading = on
	follow_target = null if on else Party.follow_body()

func set_player_controlled(on: bool) -> void:
	set_leading(on)

func free_from_pole() -> void:
	if freed:
		return
	freed = true
	bound_on_pole = false
	_set_bound_pose(false)
	Party.set_present(Party.ID_SCARECROW, true)
	Party.unlock(Party.ID_SCARECROW)
	follow_target = Party.follow_body()

func _set_bound_pose(on: bool) -> void:
	if visual:
		visual.rotation_degrees.x = -8.0 if on else 0.0

func _physics_process(delta: float) -> void:
	caw_timer = maxf(caw_timer - delta, 0.0)
	kit_lock = maxf(kit_lock - delta, 0.0)
	_armament_cd = maxf(_armament_cd - delta, 0.0)
	if bound_on_pole and not freed:
		velocity = Vector3.ZERO
		if body and body.has_method("set_locomotion"):
			body.set_locomotion(0.0, delta)
		return

	if global_position.y < -3.5:
		global_position = Vector3(clampf(global_position.x, -30.0, 30.0), 0.25, clampf(global_position.z, -50.0, 120.0))
		velocity = Vector3.ZERO

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5

	if leading:
		if kit_lock <= 0.0:
			_move_as_lead(delta)
			if Input.is_action_just_pressed("blink") and is_on_floor():
				velocity.y = 7.4
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
		if Input.is_action_just_pressed("kick") and caw_timer <= 0.0:
			_caw()
	else:
		_ally_or_follow(delta)

	_anim(delta)
	move_and_slide()

func _ally_or_follow(delta: float) -> void:
	# Free Scarecrow fights on his own when not Lead — Tab still lets the player take over.
	if not freed:
		_follow(delta)
		return
	var foe: Node3D = Party.nearest_enemy(self, 18.0) if Party else null
	var lead := Party.follow_body() if Party else null
	var leash_ok := true
	if lead and is_instance_valid(lead) and lead != self:
		if global_position.distance_to(lead.global_position) > 26.0 and foe:
			# Don't abandon the party forever — if very far from Lead, rejoin first.
			if foe.global_position.distance_to(lead.global_position) > 20.0:
				leash_ok = false
	if foe and leash_ok:
		_ally_fight(delta, foe)
	else:
		_follow(delta)

func _ally_fight(delta: float, foe: Node3D) -> void:
	var to := foe.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var hold := caw_radius * 0.72
	if dist > 0.05:
		var dir := to / dist
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
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
			if caw_timer <= 0.0 and kit_lock <= 0.0:
				_caw()
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
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-wish.x, -wish.z), 10.0 * delta)
	var cur_speed := move_speed * (1.85 if Locomotion.is_sprinting() else 1.0)
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
	if dist > follow_distance:
		var dir := to / dist
		var steered: Vector3 = Locomotion.steer(self, dir)
		if steered.length() > 0.05:
			velocity.x = steered.x * move_speed * 0.92
			velocity.z = steered.z * move_speed * 0.92
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

func _caw() -> void:
	caw_timer = caw_cooldown
	kit_lock = 0.28
	var sm := get_node_or_null("/root/SaveManager")
	var eq: String = str(sm.equipped_outfits.get("scarecrow", "")) if (sm and "equipped_outfits" in sm) else ""
	var eff_rad := caw_radius + (0.9 if eq == "scarecrow_leather" else (0.5 if eq == "scarecrow_obsidian" else 0.0))
	var eff_confuse := 3.8 if eq == "scarecrow_obsidian" else 2.6
	var eff_dmg := caw_damage + (3 if eq == "scarecrow_obsidian" else 0)
	if body and body.has_method("play_caw"):
		body.call("play_caw")
	# Murder of 3D flapping black crows spiraling outward + straw burst
	if CombatFx.has_method("crow_storm"):
		CombatFx.crow_storm(self, global_position, eff_rad)
	else:
		CombatFx.ring(self, global_position, Color(0.95, 0.82, 0.25), eff_rad * 0.9, 0.4)
	CombatFx.label(self, global_position, "CAW!", Color(1.0, 0.9, 0.35))

	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = eff_rad
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = 4
	params.exclude = [get_rid()]
	params.transform = Transform3D(Basis(), global_position + Vector3(0, 0.7, 0))
	var hits := space.intersect_shape(params, 12)
	for hit in hits:
		var collider: Object = hit.collider
		if collider == null:
			continue
		if collider.has_method("apply_confuse"):
			collider.apply_confuse(eff_confuse)
		if collider.has_method("take_damage"):
			collider.take_damage(eff_dmg, global_position, {"knockback": 3.5})

func _unhandled_key_input(event: InputEvent) -> void:
	if not leading or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = (event as InputEventKey).keycode
	if kc == KEY_V:
		if body and body.has_method("play_flourish"):
			body.call("play_flourish")
	elif kc in [KEY_Z, KEY_X, KEY_C]:
		get_viewport().set_input_as_handled()
		if kc == KEY_Z:
			_armament_idx = (_armament_idx + SCARECROW_ARMS.size() - 1) % SCARECROW_ARMS.size()
			var h1 := get_tree().get_first_node_in_group("hud")
			if h1 and h1.has_method("set_active_armament"):
				h1.call("set_active_armament", SCARECROW_ARMS[_armament_idx])
		elif kc == KEY_X:
			_armament_idx = (_armament_idx + 1) % SCARECROW_ARMS.size()
			var h2 := get_tree().get_first_node_in_group("hud")
			if h2 and h2.has_method("set_active_armament"):
				h2.call("set_active_armament", SCARECROW_ARMS[_armament_idx])
		elif kc == KEY_C and _armament_cd <= 0.0:
			_use_scarecrow_armament()

func _unhandled_input(event: InputEvent) -> void:
	if not leading:
		return
	if event.is_action_pressed("ability_prev"):
		get_viewport().set_input_as_handled()
		_armament_idx = (_armament_idx + SCARECROW_ARMS.size() - 1) % SCARECROW_ARMS.size()
		var h1 := get_tree().get_first_node_in_group("hud")
		if h1 and h1.has_method("set_active_armament"): h1.call("set_active_armament", SCARECROW_ARMS[_armament_idx])
	elif event.is_action_pressed("ability_next"):
		get_viewport().set_input_as_handled()
		_armament_idx = (_armament_idx + 1) % SCARECROW_ARMS.size()
		var h2 := get_tree().get_first_node_in_group("hud")
		if h2 and h2.has_method("set_active_armament"): h2.call("set_active_armament", SCARECROW_ARMS[_armament_idx])
	elif event.is_action_pressed("ability_cast") and _armament_cd <= 0.0:
		get_viewport().set_input_as_handled()
		_use_scarecrow_armament()

func _use_scarecrow_armament() -> void:
	_armament_cd = 0.85
	if body and body.has_method("play_flourish"):
		body.call("play_flourish")
	var fwd := -visual.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.05 else Vector3.FORWARD
	match _armament_idx:
		0: # Straw Decoy — golden chaff effigy burst + 2× gilding on nearby vases & whimsies!
			CombatFx.ring(self, global_position + fwd * 2.0, Color(0.98, 0.84, 0.36), 3.6, 0.55)
			CombatFx.flash_sphere(self, global_position + fwd * 2.0 + Vector3(0, 0.8, 0), Color(0.96, 0.80, 0.32), 0.85, 0.45)
			CombatFx.label(self, global_position + fwd * 2.0 + Vector3(0, 1.5, 0), "✦ STRAW DECOY!", Color(1.0, 0.88, 0.40))
			for dp in get_tree().get_nodes_in_group("destructibles"):
				if dp is Node3D and is_instance_valid(dp) and (dp as Node3D).global_position.distance_to(global_position) <= 6.5 and dp.has_method("apply_perfume_bonus"):
					dp.call("apply_perfume_bonus")
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Node3D and is_instance_valid(e) and not e.is_in_group("enemies_dead") and (e as Node3D).global_position.distance_to(global_position) <= 7.0:
					if e.has_method("apply_confuse"): e.call("apply_confuse", 4.2)
		1: # Lantern Spark — blinding golden solar flash!
			CombatFx.flash_sphere(self, global_position + Vector3(0, 1.2, 0), Color(1.0, 0.90, 0.44), 2.4, 0.32)
			CombatFx.ring(self, global_position, Color(1.0, 0.82, 0.30), 4.8, 0.36)
			CombatFx.label(self, global_position + Vector3(0, 1.5, 0), "✦ LANTERN SPARK!", Color(1.0, 0.92, 0.48))
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Node3D and is_instance_valid(e) and not e.is_in_group("enemies_dead") and (e as Node3D).global_position.distance_to(global_position) <= 5.5:
					if e.has_method("apply_bind"): e.call("apply_bind", 2.5)
		2: # Harvest Gust — autumn whirlwind knockback + shatters vases & multi-whimsy sweep!
			CombatFx.ring(self, global_position, Color(0.95, 0.62, 0.22), 5.6, 0.42)
			CombatFx.label(self, global_position + Vector3(0, 1.4, 0), "✦ HARVEST GUST!", Color(1.0, 0.72, 0.28))
			var wh_s := get_node_or_null("/root/Whimsy")
			if wh_s and wh_s.has_method("smash_collect_near"):
				wh_s.call("smash_collect_near", global_position, fwd, 6.2, self)
			for dp in get_tree().get_nodes_in_group("destructibles"):
				if dp is Node3D and is_instance_valid(dp) and (dp as Node3D).global_position.distance_to(global_position) <= 5.8 and dp.has_method("take_damage"):
					dp.call("take_damage", 15, global_position, {})
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Node3D and is_instance_valid(e) and not e.is_in_group("enemies_dead") and (e as Node3D).global_position.distance_to(global_position) <= 5.8:
					if e.has_method("take_damage"): e.call("take_damage", 9, global_position, {"knockback": 12.0})
		3: # Patchwork Tether — woven burlap twine snaring up to 3 foes in place!
			CombatFx.ring(self, global_position + fwd * 2.5, Color(0.84, 0.66, 0.36), 4.4, 0.40)
			CombatFx.label(self, global_position + Vector3(0, 1.4, 0), "✦ PATCHWORK TETHER!", Color(0.95, 0.80, 0.48))
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Node3D and is_instance_valid(e) and not e.is_in_group("enemies_dead") and (e as Node3D).global_position.distance_to(global_position) <= 7.5:
					if e.has_method("apply_bind"): e.call("apply_bind", 3.4)

func _anim(delta: float) -> void:
	var yaw_diff := angle_difference(_prev_vis_yaw, visual.rotation.y)
	_prev_vis_yaw = visual.rotation.y
	var turn_vel := yaw_diff / maxf(delta, 0.001)
	var hs := Vector2(velocity.x, velocity.z).length()
	var bank := clampf(-turn_vel * 0.020 * clampf(hs / 4.2, 0.0, 1.2), -0.16, 0.16)
	visual.rotation.z = lerp_angle(visual.rotation.z, bank, 10.0 * delta)
	if body:
		if body.has_method("set_airborne"):
			body.call("set_airborne", velocity.y, is_on_floor(), turn_vel)
		if body.has_method("set_locomotion"):
			body.set_locomotion(hs, delta)