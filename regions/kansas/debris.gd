extends Area3D

## Flying debris. Soft hits stun; the final large piece ends the prologue.

signal soft_hit_player
signal final_hit_player

@export var is_final: bool = false
@export var speed: float = 8.0
@export var lifetime: float = 6.0

var _dir: Vector3 = Vector3(-1, 0, 0)
var _age: float = 0.0
var _armed: bool = true

func launch(from: Vector3, toward: Vector3, final_piece: bool = false) -> void:
	global_position = from
	is_final = final_piece
	toward.y = from.y
	_dir = (toward - from)
	_dir.y = 0.0
	if _dir.length() < 0.01:
		_dir = Vector3(-1, 0, 0)
	else:
		_dir = _dir.normalized()
	look_at(global_position + _dir, Vector3.UP)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	collision_layer = 0
	collision_mask = 2

func _physics_process(delta: float) -> void:
	_age += delta
	global_position += _dir * speed * delta
	global_position.y += sin(_age * 9.0) * 0.01
	if _age > lifetime:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if not _armed or not body.is_in_group("player"):
		return
	_armed = false
	if is_final:
		final_hit_player.emit()
	else:
		soft_hit_player.emit()
		if body.has_method("soft_hit"):
			body.soft_hit()
	if not is_final:
		queue_free()
