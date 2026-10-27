extends CharacterBody3D

## Dorothy's main controller
## Handles movement, blinking, and kicking

@export_group("Movement")
@export var move_speed: float = 5.0
@export var rotation_speed: float = 10.0
@export var acceleration: float = 15.0
@export var friction: float = 10.0

@export_group("Blink")
@export var blink_distance: float = 3.0
@export var blink_cooldown: float = 0.4
@export var blink_duration: float = 0.1

@export_group("Combat")
@export var kick_damage: int = 10
@export var kick_knockback: float = 5.0
@export var kick_cooldown: float = 0.6

enum State {
	IDLE,
	MOVING,
	BLINKING,
	KICKING,
	STUNNED
}

var current_state: State = State.IDLE
var blink_timer: float = 0.0
var kick_timer: float = 0.0

@onready var camera_pivot = $CameraPivot # Expected node structure

func _physics_process(delta: float) -> void:
	process_timers(delta)

	match current_state:
		State.IDLE, State.MOVING:
			handle_movement(delta)
			handle_inputs()
		State.BLINKING:
			# Logic for blink duration if not using a simple teleport
			pass
		State.KICKING:
			# Logic for kick recovery
			pass
		State.STUNNED:
			apply_friction(delta)

	move_and_slide()

func process_timers(delta: float) -> void:
	if blink_timer > 0:
		blink_timer -= delta
	if kick_timer > 0:
		kick_timer -= delta

func handle_inputs() -> void:
	# Blink input
	if Input.is_action_just_pressed("blink") and blink_timer <= 0:
		execute_blink()
		return

	# Kick input
	if Input.is_action_just_pressed("kick") and kick_timer <= 0:
		execute_kick()
		return

	# Summon input
	if Input.is_action_just_pressed("summon"):
		handle_summon()
		return

func handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	# Transform input relative to camera rotation
	var camera_basis = camera_pivot.global_transform.basis
	var direction := (camera_basis.z * input_dir.y + camera_basis.x * input_dir.x).normalized()

	if direction:
		# Move
		velocity.x = lerp(velocity.x, direction.x * move_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * move_speed, acceleration * delta)

		# Rotate to face movement
		var target_rotation = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

		current_state = State.MOVING
	else:
		apply_friction(delta)
		current_state = State.IDLE

func apply_friction(delta: float) -> void:
	velocity.x = lerp(velocity.x, 0.0, friction * delta)
	velocity.z = lerp(velocity.z, 0.0, friction * delta)

func execute_blink() -> void:
	blink_timer = blink_cooldown

	# Calculate blink position
	var blink_dir = Vector3.ZERO
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	if input_dir != Vector2.ZERO:
		var camera_basis = camera_pivot.global_transform.basis
		blink_dir = (camera_basis.z * input_dir.y + camera_basis.x * input_dir.x).normalized()
	else:
		# Blink forward relative to player
		blink_dir = -global_transform.basis.z

	# Teleport (simple version for prototype)
	global_position += blink_dir * blink_distance

	# In a full version, we would:
	# 1. Check for collisions along the path
	# 2. Play a blink effect/animation
	# 3. Set state to BLINKING for i-frames

	print("Blinked to: ", global_position)

func execute_kick() -> void:
	kick_timer = kick_cooldown
	current_state = State.KICKING

	print("Kicked!")

	# Collision detection for kick
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position - global_transform.basis.z * 1.5
	)
	var result = space_state.intersect_ray(query)

	if result:
		var collider = result.collider
		if collider.has_method("take_damage"):
			collider.take_damage(kick_damage, global_position + global_transform.basis.z * -1.0)

	# Reset state after small delay (usually handled by animation)
	await get_tree().create_timer(0.2).timeout
	current_state = State.IDLE

func handle_summon() -> void:
	# For prototype, we just summon Scarecrow
	SummonService.summon("Scarecrow", global_position)
