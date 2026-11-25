extends CharacterBody3D


## Tin Man — armor-breaker. F = Hacking Axe (armor_break + heavy hit). No blink.

@export var move_speed: float = 3.9
@export var acceleration: float = 10.0
@export var friction: float = 14.0
@export var gravity: float = 24.0
@export var axe_damage: int = 16
@export var axe_cooldown: float = 0.75
@export var follow_distance: float = 2.8

var leading: bool = false
var axe_timer: float = 0.0
var follow_target: Node3D = null
var rusted: bool = true
var freed: bool = false
var kit_lock: float = 0.0
var _axe_step: int = 0
var _prev_vis_yaw: float = 0.0

@onready var visual: Node3D = $Visual
@onready var body: Node3D = $Visual/Body

func _ready() -> void:
	add_to_group("party")
	add_to_group("companions")
	floor_snap_length = 0.3
	Party.register(Party.ID_TINMAN, self, false)
	Party.set_present(Party.ID_TINMAN, false)
	if body and body.has_method("set_rusted"):
		body.set_rusted(true)

func can_take_lead() -> bool:
	return freed and not rusted and Party.is_unlocked(Party.ID_TINMAN) and visible

func set_leading(on: bool) -> void:
	leading = on
	follow_target = null if on else Party.follow_body()

func set_player_controlled(on: bool) -> void:
	set_leading(on)

func oil_and_free() -> void:
	if freed:
		return
	rusted = false
	freed = true
	if body and body.has_method("set_rusted"):
		body.set_rusted(false)
	Party.set_present(Party.ID_TINMAN, true)
	Party.unlock(Party.ID_TINMAN)
	follow_target = Party.follow_body()

func _physics_process(delta: float) -> void:
	axe_timer = maxf(axe_timer - delta, 0.0)
	kit_lock = maxf(kit_lock - delta, 0.0)
	if rusted:
		velocity = Vector3.ZERO
		if body and body.has_method("set_locomotion"):
			body.set_locomotion(0.0, delta)
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
				velocity.y = 7.2
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
		if Input.is_action_just_pressed("kick") and axe_timer <= 0.0:
			_axe()
	else:
		_ally_or_follow(delta)
	_anim(delta)
	move_and_slide()

func _ally_or_follow(delta: float) -> void:
	if not freed or rusted:
		_follow(delta)
		return
	var foe: Node3D = Party.nearest_enemy(self, 16.0) if Party else null
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
	var hold := 1.55
	if dist > 0.05:
		var dir := to / dist
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)
		if dist > hold:
			var steered: Vector3 = Locomotion.steer(self, dir)
			if steered.length() > 0.05:
				velocity.x = steered.x * move_speed * 0.9
				velocity.z = steered.z * move_speed * 0.9
				_try_step(steered)
			else:
				velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
				velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
			if axe_timer <= 0.0 and kit_lock <= 0.0:
				_axe()
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
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-wish.x, -wish.z), 8.0 * delta)
	var cur_speed := move_speed * (1.80 if Input.is_action_pressed("blink") else 1.0)
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
			velocity.x = steered.x * move_speed * 0.85
			velocity.z = steered.z * move_speed * 0.85
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-steered.x, -steered.z), 6.0 * delta)
			_try_step(steered)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)

func _try_step(dir: Vector3) -> void:
	Locomotion.try_step(self, dir, 1.15)


func _axe() -> void:
	axe_timer = axe_cooldown
	kit_lock = 0.42
	_axe_step = (_axe_step % 2) + 1
	var sm := get_node_or_null("/root/SaveManager")
	var eq: String = str(sm.equipped_outfits.get("tinman", "")) if (sm and "equipped_outfits" in sm) else ""
	var eff_dmg := axe_damage + (10 if eq == "tinman_velvet" else 0)
	var forward := -visual.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = -global_transform.basis.z
	forward = forward.normalized()
	# 2-stage alternating Overhead Chop / Horizontal Sweeping Cleave!
	if body and body.has_method("play_axe_swing"):
		body.call("play_axe_swing", _axe_step)
	var swing_origin := global_position + Vector3(0, 1.05, 0) + forward * 0.35
	CombatFx.axe_arc(self, swing_origin, forward, Color(0.92, 0.34, 0.44) if eq == "tinman_velvet" else Color(0.7, 0.82, 0.95), 0.38)
	CombatFx.label(self, global_position + Vector3(0, 0.2, 0), "AXE" if _axe_step == 1 else "CLEAVE ×2", Color(0.8, 0.9, 1.0))

	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.75
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = 4
	params.exclude = [get_rid()]
	params.transform = Transform3D(Basis(), global_position + Vector3(0, 0.85, 0) + forward * 1.35)
	var connected := false
	for hit in space.intersect_shape(params, 6):
		var collider: Object = hit.collider
		if collider and collider.has_method("take_damage"):
			collider.take_damage(eff_dmg, global_position, {"armor_break": true, "knockback": 9.0})
			connected = true
	if connected:
		Engine.time_scale = 0.12
		await get_tree().create_timer(0.08, true, false, true).timeout
		Engine.time_scale = 1.0
		velocity += forward * 2.0

func _unhandled_key_input(event: InputEvent) -> void:
	if leading and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		if body and body.has_method("play_flourish"):
			body.call("play_flourish")

func _anim(delta: float) -> void:
	var yaw_diff := angle_difference(_prev_vis_yaw, visual.rotation.y)
	_prev_vis_yaw = visual.rotation.y
	var turn_vel := yaw_diff / maxf(delta, 0.001)
	var hs := Vector2(velocity.x, velocity.z).length()
	var bank := clampf(-turn_vel * 0.014 * clampf(hs / 3.8, 0.0, 1.1), -0.12, 0.12)
	visual.rotation.z = lerp_angle(visual.rotation.z, bank, 8.0 * delta)
	if body:
		if body.has_method("set_airborne"):
			body.call("set_airborne", velocity.y, is_on_floor(), turn_vel)
		if body.has_method("set_locomotion"):
			body.set_locomotion(hs, delta)