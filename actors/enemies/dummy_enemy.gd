extends CharacterBody3D

## Simple dummy enemy for prototype feel tests

@export var health: int = 30
@export var knockback_force: float = 10.0

var knockback_velocity: Vector3 = Vector3.ZERO

func _physics_process(delta: float) -> void:
	# Apply knockback decay
	knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, 5.0 * delta)
	velocity = knockback_velocity
	move_and_slide()

func take_damage(amount: int, source_position: Vector3) -> void:
	health -= amount
	print("Enemy took damage: ", amount, " Health remaining: ", health)

	# Calculate knockback direction
	var knockback_dir = (global_position - source_position).normalized()
	knockback_velocity = knockback_dir * knockback_force

	if health <= 0:
		die()

func die() -> void:
	print("Enemy died!")
	# In a real game: play animation, drop loot, then queue_free()
	# For prototype: just disable collisions and wait
	set_physics_process(false)
	# queue_free() # Uncomment to remove enemy
