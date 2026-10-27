extends CanvasLayer

@onready var objective: Label = $Paper/Objective
@onready var prompt: Label = $Prompt
@onready var controls: Label = $Controls

func _ready() -> void:
	_style(objective, 22)
	_style(prompt, 22)
	_style(controls, 16)
	set_prompt("")

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("wants_look_hint") and player.wants_look_hint():
		controls.text = "Click the game window to look around.  Esc releases the mouse."
	else:
		controls.text = "WASD move     Mouse look     Space blink     F kick     E take     Esc mouse"

func set_objective(text: String) -> void:
	objective.text = text

func set_prompt(text: String) -> void:
	prompt.text = text
	prompt.visible = text != ""

func _style(label: Label, size: int) -> void:
	label.add_theme_color_override("font_color", Color(0.18, 0.07, 0.14))
	label.add_theme_color_override("font_shadow_color", Color(1, 0.96, 0.9, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_font_size_override("font_size", size)
