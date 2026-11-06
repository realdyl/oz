extends CharacterBody3D


## Dorothy. Feet at the origin. The camera lives on this body so Play
## works without wiring a separate rig.
##
## The Shoes are silver (book canon). Blink and kick work before the claim
## so the first minute is playable; claiming them lengthens the blink.

@export var move_speed: float = 5.4
@export var acceleration: float = 18.0
@export var friction: float = 14.0
@export var gravity: float = 24.0

@export var blink_distance: float = 3.3
@export var blink_cooldown: float = 0.42
@export var iframe_time: float = 0.18

@export var kick_damage: int = 10
@export var kick_cooldown: float = 0.5
@export var kick_range: float = 1.15

@export var mouse_sensitivity: float = 0.0028
@export var follow_distance: float = 2.2
@export var step_height: float = 1.15

var blink_timer: float = 0.0
var kick_timer: float = 0.0
var kick_active: float = 0.0
var iframe_timer: float = 0.0
var stun_timer: float = 0.0
var shoes_claimed: bool = false
var looking: bool = false
var leading: bool = true
var follow_target: Node3D = null
## Level scripts park her (asleep / safe south) so she does not trail Lead back into danger.
var parked: bool = false
var park_pos: Vector3 = Vector3.ZERO

@onready var visual: Node3D = $Visual
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var body: Node3D = $Visual/Body

func _ready() -> void:
	add_to_group("player")
	add_to_group("party")
	floor_snap_length = 0.3
	# Godot 4 SpringArm places children along local +Z. Pitch down a little.
	spring_arm.collision_mask = 0
	_set_arm_pitch(-18.0)
	looking = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Party.register(Party.ID_DOROTHY, self, true)
	set_leading(true)

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
	else:
		park_pos = Vector3.ZERO

func can_take_lead() -> bool:
	return not parked

func _set_arm_pitch(pitch_deg: float) -> void:
	if spring_arm and is_instance_valid(spring_arm):
		spring_arm.rotation_degrees = Vector3(pitch_deg, 0.0, 0.0)

func wants_look_hint() -> bool:
	return not Party.looking

func _physics_process(delta: float) -> void:
	blink_timer = maxf(blink_timer - delta, 0.0)
	kick_timer = maxf(kick_timer - delta, 0.0)
	kick_active = maxf(kick_active - delta, 0.0)
	iframe_timer = maxf(iframe_timer - delta, 0.0)
	stun_timer = maxf(stun_timer - delta, 0.0)

	if parked:
		global_position = Vector3(park_pos.x, global_position.y, park_pos.z)
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = -0.5
		_animate_visual(delta)
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5

	# When a companion leads, Dorothy trails — and still fights on her own.
	if not leading:
		_ally_or_follow(delta)
		_animate_visual(delta)
		move_and_slide()
		return

	var locked := kick_active > 0.0 or stun_timer > 0.0
	if not locked:
		_move(delta)
		if Input.is_action_just_pressed("blink") and blink_timer <= 0.0:
			_blink()
		elif Input.is_action_just_pressed("kick") and kick_timer <= 0.0:
			_kick()
		elif Input.is_action_just_pressed("summon"):
			print("No one answers yet.")
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)

	_animate_visual(delta)
	move_and_slide()

func _ally_or_follow(delta: float) -> void:
	var foe: Node3D = Party.nearest_enemy(self, 16.0) if Party else null
	var lead := Party.follow_body() if Party else null
	var leash_ok := true
	if lead and is_instance_valid(lead) and lead != self and foe:
		if global_position.distance_to(lead.global_position) > 26.0 \
				and foe.global_position.distance_to(lead.global_position) > 20.0:
			leash_ok = false
	if foe and leash_ok and stun_timer <= 0.0:
		_ally_fight(delta, foe)
	else:
		_follow_lead(delta)

func _ally_fight(delta: float, foe: Node3D) -> void:
	var to := foe.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var hold := kick_range + 0.15
	if kick_active > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
		return
	if dist > 0.05:
		var dir := to / dist
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)
		if dist > hold:
			var steered: Vector3 = Locomotion.steer(self, dir)
			if steered.length() > 0.05:
				velocity.x = steered.x * move_speed * 0.95
				velocity.z = steered.z * move_speed * 0.95
				Locomotion.try_step(self, steered, step_height)
			else:
				velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
				velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
			if kick_timer <= 0.0:
				_kick()
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)

func _follow_lead(delta: float) -> void:
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
			velocity.x = steered.x * move_speed * 0.95
			velocity.z = steered.z * move_speed * 0.95
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-steered.x, -steered.z), 10.0 * delta)
			Locomotion.try_step(self, steered, step_height)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)

func _camera_basis() -> Basis:
	var node := Party.camera_basis_node()
	if node:
		return node.global_transform.basis
	if camera_pivot and is_instance_valid(camera_pivot):
		return camera_pivot.global_transform.basis
	return global_transform.basis

func _move(delta: float) -> void:
	# RMB steals WASD/arrows for camera orbit (Party)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish := Vector3.ZERO
	if input.length() > 0.05:
		wish = (_camera_basis() * Vector3(input.x, 0.0, input.y))
		wish.y = 0.0
		if wish.length() > 0.01:
			wish = wish.normalized()
			var face := atan2(-wish.x, -wish.z)
			visual.rotation.y = lerp_angle(visual.rotation.y, face, 12.0 * delta)
	if wish.length() > 0.05:
		var steered: Vector3 = Locomotion.steer(self, wish)
		if steered.length() < 0.05:
			steered = wish
		velocity.x = move_toward(velocity.x, steered.x * move_speed, acceleration * delta * move_speed)
		velocity.z = move_toward(velocity.z, steered.z * move_speed, acceleration * delta * move_speed)
		Locomotion.try_step(self, steered, step_height)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta * move_speed)

func _try_step(dir: Vector3) -> void:
	Locomotion.try_step(self, dir, step_height)

func _blink() -> void:
	blink_timer = blink_cooldown
	iframe_timer = iframe_time
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var dir := Vector3.ZERO
	if input.length() > 0.05:
		dir = _camera_basis() * Vector3(input.x, 0.0, input.y)
		dir.y = 0.0
		if dir.length() > 0.01:
			dir = dir.normalized()
	else:
		dir = -visual.global_transform.basis.z
		dir.y = 0.0
		if dir.length() < 0.01:
			return
		dir = dir.normalized()
	global_position = _blink_destination(dir)
	visual.scale = Vector3(0.86, 1.12, 0.86)

func _blink_destination(dir: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0, 0.7, 0)
	var travel := dir * blink_distance
	var query := PhysicsRayQueryParameters3D.create(origin, origin + travel, 1)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	var dest := global_position + travel
	if hit:
		var hit_pos: Vector3 = hit.position
		dest = hit_pos - dir * 0.45
		dest.y = global_position.y
		var above: Vector3 = hit_pos + Vector3(0, 1.35, 0) - dir * 0.15
		var down := PhysicsRayQueryParameters3D.create(above, above + Vector3(0, -1.8, 0), 1)
		down.exclude = [get_rid()]
		var top := space.intersect_ray(down)
		if top and top.position.y - global_position.y <= 1.25 and top.position.y >= global_position.y - 0.2:
			dest = top.position + Vector3(0, 0.05, 0)
	else:
		var drop_from := dest + Vector3(0, 1.4, 0)
		var drop := PhysicsRayQueryParameters3D.create(drop_from, drop_from + Vector3(0, -3.0, 0), 1)
		drop.exclude = [get_rid()]
		var ground := space.intersect_ray(drop)
		if ground:
			dest.y = ground.position.y + 0.05
	return dest

func _kick() -> void:
	kick_timer = kick_cooldown
	kick_active = 0.22
	var forward := -visual.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = -global_transform.basis.z
	forward = forward.normalized()
	# Heel plant + silver arc (always visible even with no target)
	CombatFx.slash_box(self, global_position, forward, Color(0.85, 0.9, 1.0), Vector3(0.95, 0.22, 1.2), 0.16)
	CombatFx.flash_sphere(self, global_position + Vector3(0, 0.5, 0) + forward * 0.9, Color(0.9, 0.95, 1.0), 0.4, 0.12)
	CombatFx.label(self, global_position, "KICK", Color(0.95, 0.95, 1.0))
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = 4
	params.exclude = [get_rid()]
	params.transform = Transform3D(Basis(), global_position + Vector3(0, 0.55, 0) + forward * kick_range)
	var hits := space.intersect_shape(params, 6)
	var connected := false
	for hit in hits:
		var collider: Object = hit.collider
		if collider and collider.has_method("take_damage"):
			collider.take_damage(kick_damage, global_position, {"knockback": 8.5, "launch": true})
			connected = true
	if connected:
		_hitstop()
		# Small lunge into the kick
		velocity += forward * 3.2

func _hitstop() -> void:
	Engine.time_scale = 0.08
	await get_tree().create_timer(0.09, true, false, true).timeout
	Engine.time_scale = 1.0

func _animate_visual(delta: float) -> void:
	var target_x := -0.55 if kick_active > 0.0 else 0.0
	visual.rotation.x = lerp_angle(visual.rotation.x, target_x, 16.0 * delta)
	visual.scale = visual.scale.lerp(Vector3.ONE, 10.0 * delta)
	var hs := Vector2(velocity.x, velocity.z).length()
	if body and body.has_method("set_locomotion"):
		body.set_locomotion(hs, delta)

func stumble(from: Vector3) -> void:
	if iframe_timer > 0.0 or stun_timer > 0.0:
		return
	stun_timer = 0.28
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.01:
		away = visual.global_transform.basis.z
	away = away.normalized()
	velocity.x = away.x * 5.5
	velocity.z = away.z * 5.5
	velocity.y = 2.4

func is_intangible() -> bool:
	return iframe_timer > 0.0

func empower_shoes() -> void:
	shoes_claimed = true
	blink_distance = 5.0
	blink_cooldown = 0.32
	if body:
		body.set("show_silver_shoes", true)
		# Rebuild visual so silver shoes show
		if body.has_method("_ready"):
			for c in body.get_children():
				c.free()
			body.call("_build")