extends StaticBody3D

## Phase P11 Destructible Storybook Urn / Crate — shatters on F/C hit & drops +5 Desire Fragments!

@export var desire_reward: int = 5
var _broken: bool = false

func _ready() -> void:
	add_to_group("destructibles")
	collision_layer = 1 | 4
	collision_mask = 0

func take_damage(_amount: int, source_position: Vector3, _tags: Dictionary = {}) -> void:
	if _broken:
		return
	_broken = true
	collision_layer = 0
	remove_from_group("destructibles")
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("add_desire"):
		sm.add_desire(desire_reward, "Shattered Urn")
	var afx := get_node_or_null("/root/AudioFx")
	if afx and afx.has_method("play"):
		afx.play("urn", -5.0)
	if CombatFx:
		CombatFx.flash_sphere(self, global_position + Vector3(0, 0.5, 0), Color(0.98, 0.82, 0.36), 0.75, 0.22)
		CombatFx.label(self, global_position, "♦ +%d DESIRE" % desire_reward, Color(1.0, 0.86, 0.42))
		if CombatFx.has_method("blood_splatter"):
			CombatFx.blood_splatter(self, global_position, global_position - source_position, Color(0.88, 0.74, 0.32))
	queue_free()
