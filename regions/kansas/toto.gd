extends CharacterBody3D

## Toto — waits until basket is held, then hops into the basket on interact/near.
const TotoCompanionScript := preload("res://actors/companions/toto_companion.gd")

signal joined

@export var hop_speed: float = 6.0

var player_near: bool = false
var joined_basket: bool = false
var following: bool = false
var _hop_t: float = 0.0
var _parts: Dictionary = {}
var outfit_id: String = "toto_classic"

@onready var visual: Node3D = $Visual

func _ready() -> void:
	add_to_group("toto")
	floor_snap_length = 0.2
	var sm := get_node_or_null("/root/SaveManager")
	if sm and "equipped_outfits" in sm:
		var eq: String = str(sm.equipped_outfits.get("toto", ""))
		if eq != "":
			outfit_id = eq
		if sm.has_signal("state_changed") and not sm.state_changed.is_connected(_on_save_state_changed):
			sm.state_changed.connect(_on_save_state_changed)
	if visual:
		_parts = TotoCompanionScript.build_dog_visual(visual, true, outfit_id)

func set_outfit(new_id: String) -> void:
	outfit_id = new_id if new_id != "" else "toto_classic"
	if visual:
		_parts = TotoCompanionScript.build_dog_visual(visual, true, outfit_id)

func _on_save_state_changed() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm and "equipped_outfits" in sm:
		var eq: String = str(sm.equipped_outfits.get("toto", ""))
		if eq != "" and eq != outfit_id:
			set_outfit(eq)

func _physics_process(delta: float) -> void:
	if joined_basket:
		_stick_to_basket(delta)
		return
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.2
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	# Idle bob
	visual.position.y = sin(Time.get_ticks_msec() * 0.008) * 0.03
	move_and_slide()

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var dist := global_position.distance_to(player.global_position)
	player_near = dist < 1.6
	if player_near and player.has_method("take_toto") and player.get("has_basket") and not joined_basket:
		if Input.is_action_just_pressed("interact") or dist < 1.1:
			_join(player)

func _join(player: Node) -> void:
	joined_basket = true
	following = true
	if player.has_method("take_toto"):
		player.take_toto()
	joined.emit()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_prompt"):
		hud.set_prompt("")

func _stick_to_basket(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	# Toto actually rides INSIDE Dorothy's carried wicker basket (head & ears peeking over the woven rim!)
	var cb := player.find_child("CarriedBasket", true, false) as Node3D
	var target: Vector3 = cb.global_position + Vector3(0.0, 0.16, 0.0) if cb else (player.global_position + Vector3(0.32, 0.85, -0.18))
	global_position = global_position.lerp(target, 1.0 - exp(-12.0 * delta))
	scale = scale.lerp(Vector3(0.62, 0.62, 0.62), 1.0 - exp(-8.0 * delta))
	_hop_t += delta * 8.0
	visual.position.y = absf(sin(_hop_t)) * 0.025
	if player.has_node("Visual"):
		visual.rotation.y = (player.get_node("Visual") as Node3D).rotation.y
	var tail := _parts.get("tail") as Node3D
	if tail:
		tail.rotation.z = sin(Time.get_ticks_msec() * 0.015) * 0.45
