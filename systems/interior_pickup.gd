extends Area3D

## Interactive Building Interior Activity: Gilded Desire Chest or Shattered Memory Keepsake.
## Triggers cleanly when Dorothy or any Lead approaches inside a cottage, farmhouse, or barn!

@export var kind: String = "chest" # "chest" or "memory"
@export var item_id: String = ""
@export var reward_amount: int = 15

var _collected: bool = false
var _spin_node: Node3D = null
var _t: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_spin_node = get_node_or_null("Visual") as Node3D

func _process(delta: float) -> void:
	if _collected or _spin_node == null:
		return
	_t += delta
	if kind == "memory":
		_spin_node.rotate_y(delta * 1.8)
		_spin_node.position.y = 0.95 + sin(_t * 2.8) * 0.12

func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if not (body.is_in_group("player") or body.is_in_group("companions")):
		return
	_collected = true
	var sm := get_node_or_null("/root/SaveManager")
	var dlg := get_node_or_null("/root/DialogueUI")
	if kind == "memory":
		if sm and sm.has_method("unlock_memory"):
			sm.unlock_memory(item_id)
			var info: Dictionary = sm.MEMORY_CATALOG.get(item_id, {})
			if dlg and dlg.has_method("say"):
				dlg.say("Shattered Memory", "✦ %s — \"%s\"  (+10 Desire · Open Grimoire [J])" % [str(info.get("title", "Memory")), str(info.get("text", ""))], true, 5.0)
		visible = false
	else:
		if sm and sm.has_method("open_chest"):
			sm.open_chest(item_id, reward_amount)
		var lid := get_node_or_null("Visual/Lid") as Node3D
		if lid:
			var tw := create_tween()
			tw.tween_property(lid, "rotation_degrees:x", -105.0, 0.38).set_trans(Tween.TRANS_BACK)
		var fx := get_node_or_null("/root/CombatFx")
		if fx and fx.has_method("flash_sphere"):
			fx.call("flash_sphere", self, global_position + Vector3(0, 0.65, 0), Color(1.0, 0.24, 0.48), 0.75, 0.45)
			if fx.has_method("ring"):
				fx.call("ring", self, global_position + Vector3(0, 0.15, 0), Color(1.0, 0.82, 0.32), 1.35, 0.48)
		if dlg and dlg.has_method("say"):
			dlg.say("Gilded Chest", "♦ Found +%d Desire Fragments! Spend them at The Tailor of Vices or check your Grimoire (J)." % reward_amount, true, 3.8)
