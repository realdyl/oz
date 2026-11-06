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
	return calmed and Party.is_unlocked(Party.ID_LION) and visible

func set_leading(on: bool) -> void:
	leading = on
	follow_target = null if on else Party.follow_body()

func set_player_controlled(on: bool) -> void:
	set_leading(on)

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
	if leading:
		if kit_lock <= 0.0:
			_move_as_lead(delta)
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
	if wish.length() > 0.05:
		var steered: Vector3 = Locomotion.steer(self, wish)
		if steered.length() < 0.05:
			steered = wish
		velocity.x = move_toward(velocity.x, steered.x * move_speed, acceleration * delta * move_speed)
		velocity.z = move_toward(velocity.z, steered.z * move_speed, acceleration * delta * move_speed)
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
	# Expanding fear ring + mane flash
	CombatFx.ring(self, global_position, Color(1.0, 0.55, 0.15), roar_radius * 0.55, 0.25)
	CombatFx.ring(self, global_position, Color(1.0, 0.4, 0.1), roar_radius, 0.45)
	CombatFx.flash_sphere(self, global_position + Vector3(0, 0.8, 0), Color(1.0, 0.7, 0.25), 1.0, 0.3)
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
	shape.radius = roar_radius
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
			collider.apply_fear(2.0, global_position)
		if collider.has_method("take_damage"):
			collider.take_damage(roar_damage, global_position, {"knockback": 11.0})

func _anim(delta: float) -> void:
	var hs := Vector2(velocity.x, velocity.z).length()
	if body and body.has_method("set_locomotion"):
		body.set_locomotion(hs, delta)