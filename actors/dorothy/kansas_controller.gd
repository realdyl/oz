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
var _prev_vis_yaw: float = 0.0

@onready var visual: Node3D = $Visual
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var body: Node3D = $Visual/Body

const CAM_PITCH_MIN_DEG := -62.0
const CAM_PITCH_MAX_DEG := 17.5
const CAM_FLOOR_CLEARANCE := 0.18

func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.3
	spring_arm.collision_mask = 1
	spring_arm.margin = 0.24
	if spring_arm.shape == null:
		var sph := SphereShape3D.new()
		sph.radius = 0.22
		spring_arm.shape = sph
	spring_arm.add_excluded_object(get_rid())
	spring_arm.spring_length = 4.8
	spring_arm.rotation_degrees = Vector3(-16.0, 0.0, 0.0)
	looking = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _clamp_kansas_camera() -> void:
	if camera_pivot == null or spring_arm == null:
		return
	var floor_y := global_position.y
	var world := get_world_3d()
	if world and world.direct_space_state:
		var cam_n := spring_arm.find_child("Camera3D", true, false) as Camera3D
		var p_xz := cam_n.global_position if cam_n else camera_pivot.global_position
		var q := PhysicsRayQueryParameters3D.create(
			Vector3(p_xz.x, camera_pivot.global_position.y + 3.5, p_xz.z),
			Vector3(p_xz.x, camera_pivot.global_position.y - 6.0, p_xz.z),
			1,
			[get_rid()]
		)
		var hit := world.direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			floor_y = maxf(floor_y, float(hit.position.y))
	var pivot_h := maxf(0.45, camera_pivot.global_position.y - floor_y)
	var max_sin := clampf((pivot_h - CAM_FLOOR_CLEARANCE) / maxf(1.2, spring_arm.spring_length), -0.92, 0.45)
	var dyn_max := minf(CAM_PITCH_MAX_DEG, rad_to_deg(asin(max_sin)))
	spring_arm.rotation_degrees = Vector3(clampf(spring_arm.rotation_degrees.x, CAM_PITCH_MIN_DEG, dyn_max), 0.0, 0.0)
	var cam := spring_arm.find_child("Camera3D", true, false) as Camera3D
	if cam and cam.global_position.y < floor_y + CAM_FLOOR_CLEARANCE * 0.88:
		cam.global_position.y = floor_y + CAM_FLOOR_CLEARANCE * 0.88

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
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = clampf(spring_arm.spring_length - 0.35, 2.5, 6.2)
			_clamp_kansas_camera()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = clampf(spring_arm.spring_length + 0.35, 2.5, 6.2)
			_clamp_kansas_camera()
			return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		var pitch: float = spring_arm.rotation_degrees.x - event.relative.y * mouse_sensitivity * 60.0
		spring_arm.rotation_degrees = Vector3(pitch, 0.0, 0.0)
		_clamp_kansas_camera()

func _physics_process(delta: float) -> void:
	stunned = maxf(stunned - delta, 0.0)
	var orbiting := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	if not input_locked:
		var orbit := 0.0
		if Input.is_action_pressed("camera_left"):
			orbit += 1.0
		if Input.is_action_pressed("camera_right"):
			orbit -= 1.0
		# DualSense / Gamepad Right-Stick 360° Orbit & Floor-Safe Pitch!
		if not get_tree().paused:
			var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
			var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
			if Vector2(rx, ry).length() > 0.16:
				orbit -= rx * 1.35
				spring_arm.rotation_degrees.x -= ry * 85.0 * delta
				looking = true
		# RMB + A/D (or left/right) orbits yaw 360°
		if orbiting:
			var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
			orbit += -stick.x
			if absf(stick.y) > 0.05:
				var pitch: float = spring_arm.rotation_degrees.x + stick.y * key_orbit_speed * 25.0 * delta
				spring_arm.rotation_degrees = Vector3(pitch, 0.0, 0.0)
		if orbit != 0.0:
			camera_pivot.rotate_y(orbit * key_orbit_speed * delta)
			looking = true
		_clamp_kansas_camera()

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
	if Locomotion.is_sprinting():
		spd *= 1.82
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
	var yaw_diff := angle_difference(_prev_vis_yaw, visual.rotation.y)
	_prev_vis_yaw = visual.rotation.y
	var turn_vel := yaw_diff / maxf(delta, 0.001)
	var hs := Vector2(velocity.x, velocity.z).length()
	var bank_target := clampf(-turn_vel * 0.020 * clampf(hs / 4.2, 0.0, 1.2), -0.15, 0.15)
	visual.rotation.z = lerp_angle(visual.rotation.z, bank_target, 10.0 * delta)
	if Input.is_action_just_pressed("interact") and body and body.has_method("play_interact"):
		body.call("play_interact")
	if body:
		if body.has_method("set_airborne"):
			body.call("set_airborne", velocity.y, is_on_floor(), turn_vel)
		if body.has_method("set_locomotion"):
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
