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

var blink_timer: float = 0.0
var kick_timer: float = 0.0
var kick_active: float = 0.0
var iframe_timer: float = 0.0
var stun_timer: float = 0.0
var shoes_claimed: bool = false
var looking: bool = false

@onready var visual: Node3D = $Visual
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var shoe_l: MeshInstance3D = $Visual/ShoeL
@onready var shoe_r: MeshInstance3D = $Visual/ShoeR

func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.3
	spring_arm.rotation.x = deg_to_rad(-14)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for shoe in [shoe_l, shoe_r]:
		var existing: Material = shoe.get_surface_override_material(0)
		if existing is StandardMaterial3D:
			shoe.set_surface_override_material(0, existing.duplicate())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		looking = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			looking = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotation.x = clampf(
			spring_arm.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(-55),
			deg_to_rad(18)
		)

func _physics_process(delta: float) -> void:
	blink_timer = maxf(blink_timer - delta, 0.0)
	kick_timer = maxf(kick_timer - delta, 0.0)
	kick_active = maxf(kick_active - delta, 0.0)
	iframe_timer = maxf(iframe_timer - delta, 0.0)
	stun_timer = maxf(stun_timer - delta, 0.0)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5

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

func _move(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish := Vector3.ZERO
	if input.length() > 0.05:
		var basis := camera_pivot.global_transform.basis
		wish = (basis * Vector3(input.x, 0.0, input.y)).normalized()
		var face := atan2(-wish.x, -wish.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, face, 12.0 * delta)
	velocity.x = move_toward(velocity.x, wish.x * move_speed, acceleration * delta * move_speed)
	velocity.z = move_toward(velocity.z, wish.z * move_speed, acceleration * delta * move_speed)

func _blink() -> void:
	blink_timer = blink_cooldown
	iframe_timer = iframe_time
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var dir := Vector3.ZERO
	if input.length() > 0.05:
		var basis := camera_pivot.global_transform.basis
		dir = (basis * Vector3(input.x, 0.0, input.y)).normalized()
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
	kick_active = 0.16
	_show_kick_arc()
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.48
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = 4
	params.exclude = [get_rid()]
	var forward := -visual.global_transform.basis.z
	params.transform = Transform3D(Basis(), global_position + Vector3(0, 0.55, 0) + forward * kick_range)
	var hits := space.intersect_shape(params, 4)
	var connected := false
	for hit in hits:
		var collider: Object = hit.collider
		if collider and collider.has_method("take_damage"):
			collider.take_damage(kick_damage, global_position)
			connected = true
	if connected:
		_hitstop()

func _show_kick_arc() -> void:
	var arc := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.72, 0.16, 0.85)
	arc.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.93, 0.96, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc.material_override = mat
	visual.add_child(arc)
	arc.position = Vector3(0, 0.42, -0.72)
	var timer := get_tree().create_timer(0.1)
	timer.timeout.connect(arc.queue_free)

func _hitstop() -> void:
	Engine.time_scale = 0.08
	await get_tree().create_timer(0.09, true, false, true).timeout
	Engine.time_scale = 1.0

func _animate_visual(delta: float) -> void:
	var target_x := -0.55 if kick_active > 0.0 else 0.0
	visual.rotation.x = lerp_angle(visual.rotation.x, target_x, 16.0 * delta)
	visual.scale = visual.scale.lerp(Vector3.ONE, 10.0 * delta)
	var energy := 1.7 if iframe_timer > 0.0 or shoes_claimed else 0.35
	for shoe in [shoe_l, shoe_r]:
		var mat := shoe.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = energy

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
	for shoe in [shoe_l, shoe_r]:
		var mat := shoe.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.emission_enabled = true
			mat.emission = Color(0.85, 0.9, 1.0)
			mat.emission_energy_multiplier = 1.8

func wants_look_hint() -> bool:
	return not looking
