extends Node3D

## Lightweight waddling & pecking AI for sculpted 3D Kansas chickens!

var _home: Vector3 = Vector3.ZERO
var _target: Vector3 = Vector3.ZERO
var _wait_t: float = 0.0
var _peck_t: float = 0.0
var _waddle_t: float = 0.0
var _wander_r: float = 1.6

func _ready() -> void:
	_home = position
	_target = _home
	_wait_t = randf_range(0.4, 2.2)

func _process(delta: float) -> void:
	if _wait_t > 0.0:
		_wait_t -= delta
		# Pecking bob while paused
		_peck_t += delta * 7.5
		rotation_degrees.x = maxf(0.0, sin(_peck_t)) * 22.0
		if _wait_t <= 0.0:
			var ang := randf() * TAU
			var dist := randf_range(0.5, _wander_r)
			_target = _home + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		return
	rotation_degrees.x = lerpf(rotation_degrees.x, 0.0, 10.0 * delta)
	var to := _target - position
	to.y = 0.0
	if to.length() < 0.12:
		_wait_t = randf_range(1.2, 3.2)
		return
	var dir := to.normalized()
	position += dir * 0.85 * delta
	var want_yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, want_yaw, 6.0 * delta)
	_waddle_t += delta * 14.0
	rotation_degrees.z = sin(_waddle_t) * 7.5
	position.y = _home.y + absf(sin(_waddle_t)) * 0.03
