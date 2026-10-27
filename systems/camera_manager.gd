extends Node3D

## Camera manager for Oz
## Provides a smooth third-person follow camera

@export_group("Follow Settings")
@export var target: Node3D
@export var offset: Vector3 = Vector3(0, 2, 4)
@export var smooth_speed: float = 10.0

@export_group("Rotation Settings")
@export var mouse_sensitivity: float = 0.1
@export var min_pitch: float = -45.0
@export var max_pitch: float = 45.0

var pitch: float = 0.0
var yaw: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity * 0.01
		pitch -= event.relative.y * mouse_sensitivity * 0.01
		pitch = clamp(pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

func _process(delta: float) -> void:
	if not target:
		return

	# Update rotation
	rotation.x = pitch
	rotation.y = yaw

	# Smoothly follow target position
	var target_pos = target.global_position + offset.rotated(Vector3.UP, yaw)
	global_position = global_position.lerp(target_pos, smooth_speed * delta)

	# Always look at target
	look_at(target.global_position + Vector3(0, 1, 0))
