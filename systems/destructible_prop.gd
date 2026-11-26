extends StaticBody3D

## Phase P11 Destructible Storybook Urn / Crate — shatters on F/C hit & drops +5 Desire Fragments!

@export var desire_reward: int = 5
var _broken: bool = false
var perfumed: bool = false

func _ready() -> void:
	add_to_group("destructibles")
	collision_layer = 1 | 4
	collision_mask = 0

func apply_perfume_bonus() -> void:
	if _broken or perfumed:
		return
	perfumed = true
	# Shimmering amethyst-rose enchantment halo showing this urn now drops 2× Desire!
	var aura := MeshInstance3D.new()
	aura.name = "PerfumeAura"
	var tor := TorusMesh.new()
	tor.inner_radius = 0.40
	tor.outer_radius = 0.48
	aura.mesh = tor
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0.92, 0.36, 0.86, 0.88)
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.emission_enabled = true
	am.emission = Color(0.96, 0.40, 0.90)
	am.emission_energy_multiplier = 2.2
	aura.material_override = am
	aura.position = Vector3(0, 0.55, 0)
	add_child(aura)
	if CombatFx:
		CombatFx.label(self, global_position + Vector3(0, 1.15, 0), "♥ PERFUMED · 2× DESIRE!", Color(0.96, 0.52, 0.94))

func take_damage(_amount: int, source_position: Vector3, _tags: Dictionary = {}) -> void:
	if _broken:
		return
	_broken = true
	collision_layer = 0
	remove_from_group("destructibles")
	var final_reward := desire_reward * (2 if perfumed else 1)
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("add_desire"):
		sm.add_desire(final_reward, "Perfumed Urn (2×)" if perfumed else "Shattered Urn")
	var afx := get_node_or_null("/root/AudioFx")
	if afx and afx.has_method("play"):
		afx.play("urn", -4.0)
	if CombatFx:
		if CombatFx.has_method("shatter_porcelain"):
			CombatFx.shatter_porcelain(self, global_position, global_position - source_position, perfumed)
		else:
			CombatFx.flash_sphere(self, global_position + Vector3(0, 0.5, 0), Color(0.98, 0.82, 0.36), 0.75, 0.22)
		var lbl_txt := "♥ ♦ +%d DESIRE (2×!)" % final_reward if perfumed else "♦ +%d DESIRE" % final_reward
		var lbl_col := Color(0.98, 0.55, 0.94) if perfumed else Color(1.0, 0.86, 0.42)
		CombatFx.label(self, global_position + Vector3(0, 0.9, 0), lbl_txt, lbl_col)
	queue_free()
