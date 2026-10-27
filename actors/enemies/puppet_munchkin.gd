extends CharacterBody3D

## Cursed Munchkin puppet from the landing beat.
## Short, stitched, licorice hat. Not a film costume.
## Wind-up, then lunge. Kick staggers. Three kicks drop it.
## It cannot kill Dorothy.

enum State { WANDER, APPROACH, TELEGRAPH, LUNGE, RECOVER, STAGGER, DEAD }

@export var health: int = 30
@export var tint: Color = Color(0.93, 0.62, 0.72, 1)
@export var notice_range: float = 8.5
@export var lunge_range: float = 1.75

var state: State = State.WANDER
var state_time: float = 0.0
var lunge_dir: Vector3 = Vector3.ZERO
var hit_this_lunge: bool = false
var player: Node3D
var gravity: float = 24.0
var body_mat: StandardMaterial3D

@onready var visual: Node3D = $Visual

func _ready() -> void:
	add_to_group("enemies")
	var body := visual.get_node_or_null("Body") as MeshInstance3D
	if body:
		var active := body.get_active_material(0)
		if active is StandardMaterial3D:
			body_mat = (active as StandardMaterial3D).duplicate()
			body_mat.albedo_color = tint
			body.set_surface_override_material(0, body_mat)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -1.0

	state_time += delta
	match state:
		State.WANDER:
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
			if _player_dist() < notice_range:
				_set_state(State.APPROACH)
		State.APPROACH:
			var to := _flat_to_player()
			var dist := to.length()
			if dist < lunge_range and dist > 0.01:
				lunge_dir = to / dist
				_set_state(State.TELEGRAPH)
			elif dist > notice_range * 1.35 or dist < 0.01:
				_set_state(State.WANDER)
			else:
				var dir := to / dist
				velocity.x = dir.x * 2.15
				velocity.z = dir.z * 2.15
				rotation.y = atan2(-dir.x, -dir.z)
		State.TELEGRAPH:
			velocity.x = 0.0
			velocity.z = 0.0
			visual.rotation.x = lerp_angle(visual.rotation.x, 0.45, 8.0 * delta)
			if state_time > 0.55:
				hit_this_lunge = false
				_set_state(State.LUNGE)
		State.LUNGE:
			visual.rotation.x = lerp_angle(visual.rotation.x, -0.35, 14.0 * delta)
			velocity.x = lunge_dir.x * 7.2
			velocity.z = lunge_dir.z * 7.2
			_try_shove()
			if state_time > 0.28:
				_set_state(State.RECOVER)
		State.RECOVER:
			visual.rotation.x = lerp_angle(visual.rotation.x, 0.0, 6.0 * delta)
			velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
			if state_time > 0.7:
				_set_state(State.APPROACH)
		State.STAGGER:
			visual.rotation.x = lerp_angle(visual.rotation.x, 0.2, 8.0 * delta)
			if state_time > 0.38:
				_set_state(State.APPROACH)

	_pulse()
	move_and_slide()

func take_damage(amount: int, source_position: Vector3) -> void:
	if state == State.DEAD:
		return
	health -= amount
	var away := global_position - source_position
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.FORWARD
	away = away.normalized()
	velocity.x = away.x * 6.5
	velocity.z = away.z * 6.5
	velocity.y = 1.6
	_set_state(State.STAGGER)
	if health <= 0:
		_die()

func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(visual, "rotation:x", deg_to_rad(78), 0.35)
	tween.parallel().tween_property(visual, "position:y", 0.15, 0.35)

func _try_shove() -> void:
	if hit_this_lunge or player == null:
		return
	if global_position.distance_to(player.global_position) > 1.05:
		return
	hit_this_lunge = true
	if player.has_method("is_intangible") and player.is_intangible():
		return
	if player.has_method("stumble"):
		player.stumble(global_position)

func _player_dist() -> float:
	if player == null:
		return 999.0
	return global_position.distance_to(player.global_position)

func _flat_to_player() -> Vector3:
	if player == null:
		return Vector3.ZERO
	var to := player.global_position - global_position
	to.y = 0.0
	return to

func _set_state(next: State) -> void:
	state = next
	state_time = 0.0

func _pulse() -> void:
	if body_mat == null:
		return
	if state == State.TELEGRAPH:
		body_mat.emission_enabled = true
		body_mat.emission = Color(0.55, 0.15, 0.35)
		body_mat.emission_energy_multiplier = 1.2 + sin(state_time * 28.0) * 0.8
	elif state == State.DEAD:
		body_mat.emission_enabled = false
	else:
		body_mat.emission_enabled = false
