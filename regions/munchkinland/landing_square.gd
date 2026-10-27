extends Node3D

## Act 1 landing preview. Color has already bloomed.
## The house stays grey on purpose: it is the last Kansas object.
## The other quadrants are silhouettes in the fog, not built regions.

@onready var hud: CanvasLayer = $PlayHUD
@onready var shoes: Node3D = $SilverShoes
@onready var player: CharacterBody3D = $Player

func _ready() -> void:
	hud.set_objective("The Shoes are under the house.")
	shoes.claimed.connect(_on_shoes_claimed)
	shoes.prompt_changed.connect(hud.set_prompt)

func _on_shoes_claimed() -> void:
	if player.has_method("empower_shoes"):
		player.empower_shoes()
	hud.set_objective("They chose you.")
	hud.set_prompt("")
