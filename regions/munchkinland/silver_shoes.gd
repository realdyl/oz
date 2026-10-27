extends Node3D

## The Witch of the East's shoes, spilled in front of the house.
## Silver. Book canon. Not ruby slippers, no bows.

signal claimed
signal prompt_changed(text: String)

var player_near: bool = false
var taken: bool = false

func _ready() -> void:
	$Area3D.body_entered.connect(_on_body_entered)
	$Area3D.body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if taken or not player_near:
		return
	if event.is_action_pressed("interact"):
		take()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node) -> void:
	if taken or not body.is_in_group("player"):
		return
	player_near = true
	prompt_changed.emit("E  —  Take the Shoes")

func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	player_near = false
	if not taken:
		prompt_changed.emit("")

func take() -> void:
	if taken:
		return
	taken = true
	player_near = false
	prompt_changed.emit("")
	claimed.emit()
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + 1.4, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector3(0.15, 0.15, 0.15), 0.55)
	await tween.finished
	visible = false
