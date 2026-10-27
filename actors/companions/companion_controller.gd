extends CharacterBody3D

## CompanionController: Logic for summoned friends
## Handles following Dorothy and using abilities

@export var companion_type: String = "Scarecrow"
@export var follow_distance: float = 2.0
@export var move_speed: float = 4.0
@export var rotation_speed: float = 5.0

var target: Node3D = null
var is_engaged: bool = false

func _ready() -> void:
	# Find Dorothy in the scene
	target = get_tree().root.find_child("Player", true, false)

func _physics_process(delta: float) -> void:
	if not target:
		return

	if not is_engaged:
		follow_target(delta)

	move_and_slide()

func follow_target(delta: float) -> void:
	var dist = global_position.distance_to(target.global_position)

	if dist > follow_distance:
		var dir = (target.global_position - global_position).normalized()
		velocity = dir * move_speed

		# Smooth rotation
		var target_rot = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)
	else:
		velocity = velocity.lerp(Vector3.ZERO, 10.0 * delta)

func execute_ability(ability: AbilityData) -> void:
	# Use the MeterService to check for cost
	var meter_type = get_meter_type()
	if MeterService.spend_meter(meter_type, ability.cost):
		print(companion_type, " uses ", ability.display_name, "!")
		# In a full version: instantiate ability.effect_scene
	else:
		print("Not enough ", meter_type, "!")

func get_meter_type() -> String:
	match companion_type:
		"Scarecrow": return "Brain"
		"TinMan": return "Heart"
		"Lion": return "Courage"
	return "Brain"
