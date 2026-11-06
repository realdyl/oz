extends CharacterBody3D

## Kansas Dorothy — full-body visual, free 360° camera, move + interact only.
## Hold RMB + WASD/arrows to orbit camera without mouse look.

@export var move_speed: float = 4.8
@export var run_multiplier: float = 1.35
@export var acceleration: float = 16.0
@export var friction: float = 12.0
@export var gravity: float = 24.0
@export var mouse_sensitivity: float = 0.0032
@export var key_orbit_speed: float = 2.2

var looking: bool = false
var has_basket: bool = false
var has_toto: bool = false
var stunned: float = 0.0
var input_locked: bool = false

@onready var visual: Node3D = $Visual
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var body: Node3D = $Visual/Body

func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.3
	spring_arm.collision_mask = 0
	spring_arm.spring_length = 4.8
	spring_arm.rotation_degrees = Vector3(-16.0, 0.0, 0.0)
	looking = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		looking = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		looking = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		var pitch: float = spring_arm.rotation_degrees.x - event.relative.y * mouse_sensitivity * 60.0
		spring_arm.rotation_degrees = Vector3(clampf(pitch, -60.0, 25.0), 0.0, 0.0)

func _physics_process(delta: float) -> void:
	stunned = maxf(stunned - delta, 0.0)
	var orbiting := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	if not input_locked:
		var orbit := 0.0
		if Input.is_action_pressed("camera_left"):
			orbit += 1.0
		if Input.is_action_pressed("camera_right"):
			orbit -= 1.0
		# RMB + A/D (or left/right) orbits yaw 360°
		if orbiting:
			var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
			orbit += -stick.x
			if absf(stick.y) > 0.05:
				var pitch: float = spring_arm.rotation_degrees.x + stick.y * key_orbit_speed * 25.0 * delta
				spring_arm.rotation_degrees = Vector3(clampf(pitch, -60.0, 25.0), 0.0, 0.0)
		if orbit != 0.0:
			camera_pivot.rotate_y(orbit * key_orbit_speed * delta)
			looking = true

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5

	if input_locked or stunned > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
		_anim(delta)
		move_and_slide()
		return

	var wish := Vector3.ZERO
	var spd := move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		spd *= run_multiplier
	# Move only when not RMB-orbiting
	if not orbiting:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if input.length() > 0.05:
			wish = camera_pivot.global_transform.basis * Vector3(input.x, 0.0, input.y)
			wish.y = 0.0
			if wish.length() > 0.01:
				wish = wish.normalized()
				visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-wish.x, -wish.z), 12.0 * delta)
	velocity.x = move_toward(velocity.x, wish.x * spd, acceleration * delta * spd)
	velocity.z = move_toward(velocity.z, wish.z * spd, acceleration * delta * spd)
	_anim(delta)
	move_and_slide()

func _anim(delta: float) -> void:
	var hs := Vector2(velocity.x, velocity.z).length()
	if body and body.has_method("set_locomotion"):
		body.set_locomotion(hs, delta)

func wants_look_hint() -> bool:
	return not looking and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED

func take_basket() -> void:
	has_basket = true

func take_toto() -> void:
	has_toto = true

func soft_hit() -> void:
	stunned = 0.35
	velocity.y = 1.6

func lock_input() -> void:
	input_locked = true
	looking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
