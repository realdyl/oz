extends Area3D

signal taken

@export var prompt: String = "E  —  Take the basket"

var player_near: bool = false
var claimed: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2

func _process(_delta: float) -> void:
	if claimed or not player_near:
		return
	if Input.is_action_just_pressed("interact"):
		take()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = true
		_emit_prompt(true)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = false
		_emit_prompt(false)

func take() -> void:
	if claimed:
		return
	claimed = true
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("take_basket"):
		p.take_basket()
	taken.emit()
	visible = false
	monitoring = false
	_emit_prompt(false)

func _emit_prompt(show: bool) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_prompt"):
		hud.set_prompt(prompt if show and not claimed else "")
