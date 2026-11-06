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
	if bound_on_pole and not freed:
		velocity = Vector3.ZERO
		if body and body.has_method("set_locomotion"):
			body.set_locomotion(0.0, delta)
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5

	if leading:
		if kit_lock <= 0.0:
			_move_as_lead(delta)
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
			velocity.x = dir.x * move_speed * 0.95
			velocity.z = dir.z * move_speed * 0.95
			_try_step(dir)
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
	velocity.x = move_toward(velocity.x, wish.x * move_speed, acceleration * delta * move_speed)
	velocity.z = move_toward(velocity.z, wish.z * move_speed, acceleration * delta * move_speed)
	if wish.length() > 0.05:
		_try_step(wish)

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
		velocity.x = dir.x * move_speed * 0.92
		velocity.z = dir.z * move_speed * 0.92
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)
		_try_step(dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)

func _try_step(dir: Vector3) -> void:
	if not is_on_floor() or dir.length() < 0.05:
		return
	var space := get_world_3d().direct_space_state
	var feet := global_position + Vector3(0, 0.15, 0)
	var ahead := feet + dir.normalized() * 0.45
	var hit_wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(feet, ahead, 1, [get_rid()]))
	if hit_wall.is_empty():
		return
	var step_h := 0.55
	var top_from := ahead + Vector3(0, step_h + 0.35, 0)
	var top_to := ahead + Vector3(0, 0.05, 0)
	var hit_top := space.intersect_ray(PhysicsRayQueryParameters3D.create(top_from, top_to, 1, [get_rid()]))
	if hit_top.is_empty():
		return
	var land_y: float = hit_top.position.y
	if land_y <= global_position.y + 0.08 or land_y > global_position.y + step_h + 0.15:
		return
	var head := Vector3(ahead.x, land_y + 1.2, ahead.z)
	var blocked := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(ahead.x, land_y + 0.2, ahead.z), head, 1, [get_rid()]))
	if not blocked.is_empty():
		return
	global_position = Vector3(ahead.x, land_y + 0.02, ahead.z)
	velocity.y = 0.0

func _caw() -> void:
	caw_timer = caw_cooldown
	kit_lock = 0.28
	# Burst of "crows" — yellow confetti spheres + ring
	CombatFx.ring(self, global_position, Color(0.95, 0.82, 0.25), caw_radius * 0.9, 0.4)
	CombatFx.flash_sphere(self, global_position + Vector3(0, 1.0, 0), Color(0.95, 0.85, 0.3), 0.7, 0.25)
	CombatFx.label(self, global_position, "CAW!", Color(1.0, 0.9, 0.35))
	for i in 6:
		var ang := float(i) / 6.0 * TAU
		var p := global_position + Vector3(cos(ang) * 0.8, 1.2 + randf() * 0.4, sin(ang) * 0.8)
		CombatFx.flash_sphere(self, p, Color(0.15, 0.12, 0.1), 0.18, 0.35)

	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = caw_radius
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
			collider.apply_confuse(2.6)
		if collider.has_method("take_damage"):
			collider.take_damage(caw_damage, global_position, {"knockback": 3.5})

func _anim(delta: float) -> void:
	var hs := Vector2(velocity.x, velocity.z).length()
	if body and body.has_method("set_locomotion"):
		body.set_locomotion(hs, delta)
