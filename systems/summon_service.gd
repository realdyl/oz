extends Node

## SummonService: Manages the active companion
## Ensures only one friend is active at a time

signal companion_summoned(companion: Node3D)
signal companion_dismissed

var active_companion: Node3D = null
var current_companion_type: String = ""

# Mapping of companion types to their scenes
var companion_scenes = {
	"Scarecrow": "res://actors/companions/scarecrow/scarecrow.tscn",
	"TinMan": "res://actors/companions/tinman/tinman.tscn",
	"Lion": "res://actors/companions/lion/lion.tscn"
}

func summon(type: String, spawn_pos: Vector3) -> void:
	if active_companion:
		dismiss()

	var scene_path = companion_scenes.get(type)
	if not scene_path:
		print("Companion type not found: ", type)
		return

	var scene = load(scene_path)
	var companion = scene.instantiate()

	# Add to the main scene (typically the root or a designated container)
	get_tree().root.add_child(companion)
	companion.global_position = spawn_pos + Vector3(1, 0, 1)

	active_companion = companion
	current_companion_type = type

	companion_summoned.emit(companion)
	print("Summoned: ", type)

func dismiss() -> void:
	if active_companion:
		var companion = active_companion
		active_companion = null
		current_companion_type = ""
		companion.queue_free()
		companion_dismissed.emit()
		print("Companion dismissed")

func get_active() -> Node3D:
	return active_companion
