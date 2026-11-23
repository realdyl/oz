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

@onready var visual: Node3D = $Visual

func _ready() -> void:
	add_to_group("toto")
	floor_snap_length = 0.2
	if visual:
		_parts = TotoCompanionScript.build_dog_visual(visual, true)

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
	# Trot right on the prairie ground beside Dorothy (never floating mid-air!)
	var target: Vector3 = player.global_position + Vector3(0.95, 0.0, 0.55)
	target.y = 0.0
	var to_t := target - global_position
	to_t.y = 0.0
	var dist := to_t.length()
	if dist > 0.35:
		global_position = global_position.lerp(target, 1.0 - exp(-hop_speed * delta))
		global_position.y = 0.0
		_hop_t += delta * 12.0
		visual.position.y = absf(sin(_hop_t)) * 0.05
		visual.rotation.y = atan2(to_t.x, to_t.z)
	else:
		global_position.y = 0.0
		visual.position.y = 0.0
	var tail := _parts.get("tail") as Node3D
	if tail:
		tail.rotation.z = sin(Time.get_ticks_msec() * 0.015) * 0.42
