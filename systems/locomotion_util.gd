extends Node

## Shared natural stair step-up + wall-steer for party, allies, and rogues.
## Smooth hills are climbed naturally by CharacterBody3D.move_and_slide() (NO 25m/s hill teleport!).
## Vertical stair/terrace risers step cleanly upward with a natural per-step rhythm.

const DEFAULT_STEP := 1.15
const STEP_COOLDOWN_MS := 110
const DOUBLE_TAP_WINDOW_MS := 340

var double_tap_sprinting: bool = false
var _last_dir_tap_ms: Dictionary = {
	"move_forward": -9999,
	"move_backward": -9999,
	"move_left": -9999,
	"move_right": -9999,
}

func _ready() -> void:
	_register_gamepad_bindings()

## Registers unified modern Gamepad bindings (PlayStation DualSense, Xbox Series X|S, Nintendo Switch Pro)
## across all core movement, combat, superpower, party-swap, and menu actions!
func _register_gamepad_bindings() -> void:
	# Analog Left Stick -> 360° Movement
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_backward", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	# Face Buttons (Unified SDL GameController layout: PS5 Cross/Square/Circle/Triangle · Xbox A/X/B/Y · Switch B/Y/A/X)
	_add_joy_btn("blink", JOY_BUTTON_A)          # South: Jump / Silver Blink (Space)
	_add_joy_btn("kick", JOY_BUTTON_X)           # West: Primary Combat Kit (F)
	_add_joy_btn("interact", JOY_BUTTON_B)       # East: Interact / Talk (E)
	# Extra Superpowers (Z / X / C) -> L1 / R1 cycle · Triangle/Y or R2 cast!
	_ensure_action("ability_prev")
	_ensure_action("ability_next")
	_ensure_action("ability_cast")
	_add_joy_btn("ability_prev", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_btn("ability_next", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_btn("ability_cast", JOY_BUTTON_Y)
	_add_joy_axis("ability_cast", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	# Party Lead Swap -> D-Pad Left / Right
	_add_joy_btn("switch_next", JOY_BUTTON_DPAD_RIGHT)
	_ensure_action("switch_prev")
	_add_joy_btn("switch_prev", JOY_BUTTON_DPAD_LEFT)
	# Menus & Utility -> Start (Pause), D-Pad Up (Shop), D-Pad Down (Grimoire), Select/Back (Green Spectacles), L3 (Sprint Toggle)
	_add_joy_btn("ui_cancel", JOY_BUTTON_START)
	_ensure_action("sprint_toggle")
	_add_joy_btn("sprint_toggle", JOY_BUTTON_LEFT_STICK)
	_ensure_action("open_shop")
	_add_joy_btn("open_shop", JOY_BUTTON_DPAD_UP)
	_ensure_action("open_grimoire")
	_add_joy_btn("open_grimoire", JOY_BUTTON_DPAD_DOWN)
	_ensure_action("toggle_spectacles")
	_add_joy_btn("toggle_spectacles", JOY_BUTTON_BACK)

func _ensure_action(act: StringName) -> void:
	if not InputMap.has_action(act):
		InputMap.add_action(act, 0.25)

func _add_joy_btn(act: StringName, btn: JoyButton) -> void:
	if not InputMap.has_action(act):
		return
	for ev in InputMap.action_get_events(act):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == btn:
			return
	var jb := InputEventJoypadButton.new()
	jb.button_index = btn
	InputMap.action_add_event(act, jb)

func _add_joy_axis(act: StringName, axis: JoyAxis, axis_val: float) -> void:
	if not InputMap.has_action(act):
		return
	for ev in InputMap.action_get_events(act):
		if ev is InputEventJoypadMotion and (ev as InputEventJoypadMotion).axis == axis and signf((ev as InputEventJoypadMotion).axis_value) == signf(axis_val):
			return
	var jm := InputEventJoypadMotion.new()
	jm.axis = axis
	jm.axis_value = axis_val
	InputMap.action_add_event(act, jm)

func _process(_delta: float) -> void:
	# Omnidirectional Double-Tap Sprint: double-tap Up, Down, Left, or Right (Arrows or WASD) to sprint!
	var now := Time.get_ticks_msec()
	for dir_act in ["move_forward", "move_backward", "move_left", "move_right"]:
		if Input.is_action_just_pressed(dir_act):
			var last_ms: int = int(_last_dir_tap_ms.get(dir_act, -9999))
			if now - last_ms <= DOUBLE_TAP_WINDOW_MS:
				double_tap_sprinting = true
			_last_dir_tap_ms[dir_act] = now
	if InputMap.has_action("sprint_toggle") and Input.is_action_just_pressed("sprint_toggle"):
		double_tap_sprinting = not double_tap_sprinting
	if double_tap_sprinting:
		var mv := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if mv.length() < 0.08:
			double_tap_sprinting = false

func is_sprinting() -> bool:
	return double_tap_sprinting or Input.is_action_pressed("blink") or Input.is_key_pressed(KEY_SHIFT)

func try_step(body: CharacterBody3D, dir: Vector3, step_height: float = DEFAULT_STEP) -> bool:
	if body == null or not body.is_on_floor() or dir.length() < 0.05:
		return false
	var now_ms := Time.get_ticks_msec()
	if body.has_meta("_last_step_ms") and (now_ms - int(body.get_meta("_last_step_ms"))) < STEP_COOLDOWN_MS:
		return false
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	if space == null:
		return false
	var d: Vector3 = dir.normalized()
	var rid: RID = body.get_rid()
	for dist_mul in [0.42, 0.62]:
		var feet: Vector3 = body.global_position + Vector3(0, 0.025, 0)
		var ahead: Vector3 = feet + d * float(dist_mul)
		var hit_wall: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(feet, ahead, 1, [rid]))
		# Only step up when an actual VERTICAL riser wall blocks feet (normal.y < 0.35).
		# Smooth grassy hills (hit_wall.is_empty() or normal.y >= 0.35) are walked naturally!
		if hit_wall.is_empty():
			continue
		var norm: Vector3 = hit_wall.get("normal", Vector3.UP)
		if norm.y >= 0.35:
			continue
		var hit_top: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
			ahead + Vector3(0, step_height + 0.45, 0),
			ahead + Vector3(0, 0.01, 0),
			1,
			[rid]
		))
		if hit_top.is_empty():
			continue
		var land_y: float = hit_top.position.y
		if land_y <= body.global_position.y + 0.02 or land_y > body.global_position.y + step_height + 0.22:
			continue
		if not _head_clear(space, rid, ahead.x, land_y, ahead.z):
			continue
		# Smoothly lift onto the stair tread with minimal horizontal clearance (no sudden forward launch)
		var micro_fwd: Vector3 = body.global_position + d * 0.14
		body.global_position = Vector3(micro_fwd.x, land_y + 0.02, micro_fwd.z)
		body.velocity.y = 0.0
		body.set_meta("_last_step_ms", now_ms)
		return true
	return false

func _head_clear(space: PhysicsDirectSpaceState3D, rid: RID, x: float, land_y: float, z: float) -> bool:
	var blocked: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(x, land_y + 0.25, z),
		Vector3(x, land_y + 1.35, z),
		1,
		[rid]
	))
	return blocked.is_empty()

func steer(body: CharacterBody3D, wish: Vector3, probe_dist: float = 1.65) -> Vector3:
	if body == null or wish.length() < 0.05:
		return Vector3.ZERO
	var d: Vector3 = wish.normalized()
	d.y = 0.0
	if d.length() < 0.01:
		return Vector3.ZERO
	d = d.normalized()
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	if space == null:
		return d
	var rid: RID = body.get_rid()
	var origin: Vector3 = body.global_position + Vector3(0, 0.62, 0)
	var now_ms := Time.get_ticks_msec()

	# Anti-stuck stall recovery: if trying to move for >450ms with <0.16m displacement, depenetrate & commit to open flank!
	var prev_check_ms := int(body.get_meta("_stuck_ms", 0))
	if prev_check_ms == 0:
		body.set_meta("_stuck_ms", now_ms)
		body.set_meta("_stuck_pos", body.global_position)
	elif now_ms - prev_check_ms >= 460:
		var old_p: Vector3 = body.get_meta("_stuck_pos", body.global_position)
		var moved_2d := Vector2(body.global_position.x - old_p.x, body.global_position.z - old_p.z).length()
		body.set_meta("_stuck_ms", now_ms)
		body.set_meta("_stuck_pos", body.global_position)
		if moved_2d < 0.16:
			# Cast 8 radial escape rays to push cleanly out of any cottage/wall corner!
			for esc_i in range(8):
				var ea := float(esc_i) / 8.0 * TAU
				var edir := Vector3(cos(ea), 0.0, sin(ea))
				if not _blocked_tall(space, rid, origin, edir, 2.2, body.global_position.y):
					body.global_position += edir * 0.48
					var fsign := 1.0 if edir.cross(d).y >= 0.0 else -1.0
					body.set_meta("_flank_sign", fsign)
					body.set_meta("_flank_until_ms", now_ms + 1600)
					return edir

	# 3-Whisker forward clearance check (center + ±28 deg shoulder whiskers so wide cottages are detected early!)
	var left_w := Vector3(d.x * cos(0.48) - d.z * sin(0.48), 0.0, d.x * sin(0.48) + d.z * cos(0.48)).normalized()
	var right_w := Vector3(d.x * cos(-0.48) - d.z * sin(-0.48), 0.0, d.x * sin(-0.48) + d.z * cos(-0.48)).normalized()
	var center_blocked := _blocked_tall(space, rid, origin, d, probe_dist, body.global_position.y)
	var lw_blocked := _blocked_tall(space, rid, origin, left_w, probe_dist * 0.78, body.global_position.y)
	var rw_blocked := _blocked_tall(space, rid, origin, right_w, probe_dist * 0.78, body.global_position.y)
	if not center_blocked and not lw_blocked and not rw_blocked and now_ms > int(body.get_meta("_flank_until_ms", 0)):
		return d

	# Commit to a consistent flank side around buildings so AI never ping-pongs left/right against cottage walls!
	var pref_sign := float(body.get_meta("_flank_sign", 0.0))
	if now_ms > int(body.get_meta("_flank_until_ms", 0)) or pref_sign == 0.0:
		pref_sign = -1.0 if lw_blocked and not rw_blocked else (1.0 if rw_blocked and not lw_blocked else 1.0)

	var best: Vector3 = Vector3.ZERO
	var best_score: float = -1.0e9
	for ang_deg in [28.0, -28.0, 52.0, -52.0, 78.0, -78.0, 102.0, -102.0, 135.0, -135.0]:
		var ang: float = deg_to_rad(float(ang_deg))
		var side: Vector3 = Vector3(d.x * cos(ang) - d.z * sin(ang), 0.0, d.x * sin(ang) + d.z * cos(ang)).normalized()
		if _blocked_tall(space, rid, origin, side, probe_dist * 1.05, body.global_position.y):
			continue
		var same_flank := 0.55 if (signf(float(ang_deg)) == pref_sign) else 0.0
		var score: float = side.dot(d) * 1.8 + same_flank - absf(float(ang_deg)) * 0.008
		if score > best_score:
			best_score = score
			best = side
			if absf(float(ang_deg)) >= 45.0:
				body.set_meta("_flank_sign", signf(float(ang_deg)))
				body.set_meta("_flank_until_ms", now_ms + 1150)
	if best.length() > 0.01:
		return best
	return Vector3.ZERO

func _blocked_tall(space: PhysicsDirectSpaceState3D, rid: RID, origin: Vector3, dir: Vector3, dist: float, floor_y: float) -> bool:
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + dir * dist, 1, [rid]))
	if hit.is_empty():
		return false
	var hit_y: float = hit.position.y
	if hit_y <= floor_y + DEFAULT_STEP + 0.15:
		var top: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
			hit.position + Vector3(0, DEFAULT_STEP + 0.4, 0),
			hit.position + Vector3(0, 0.02, 0),
			1,
			[rid]
		))
		if not top.is_empty() and top.position.y <= floor_y + DEFAULT_STEP + 0.25:
			return false
	return true
