extends Node

## Party / Lead swap. See obsidian-oz: Party Control and the Bond.
## The Shoes stay on Dorothy. Only agency moves.

signal leader_changed(id: StringName, body: Node3D)
signal unlock_changed(id: StringName, unlocked: bool)
signal swap_failed(reason: String)

const ID_DOROTHY := &"dorothy"
const ID_SCARECROW := &"scarecrow"
const ID_TINMAN := &"tinman"
const ID_LION := &"lion"

var _members: Dictionary = {} # StringName -> CharacterBody3D
var _unlocked: Dictionary = {ID_DOROTHY: true}
var _present: Dictionary = {ID_DOROTHY: true} # in party / on map and free to lead
var _leader_id: StringName = ID_DOROTHY
var _swap_cd: float = 0.0
var _camera_rig: Node3D = null
var looking: bool = false
var mouse_sensitivity: float = 0.0028
var last_fail: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func reset_party() -> void:
	## Call when a region scene loads so Kansas refs do not stick.
	_members.clear()
	_unlocked = {ID_DOROTHY: true}
	_present = {ID_DOROTHY: true}
	_leader_id = ID_DOROTHY
	_swap_cd = 0.0
	_camera_rig = null
	last_fail = ""

func _process(delta: float) -> void:
	_swap_cd = maxf(_swap_cd - delta, 0.0)
	if _camera_rig and is_instance_valid(_camera_rig):
		var orbit := 0.0
		if Input.is_action_pressed("camera_left"):
			orbit += 1.0
		if Input.is_action_pressed("camera_right"):
			orbit -= 1.0
		var orbiting := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if orbiting:
			var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
			orbit += -stick.x
			var arm := _camera_rig.find_child("SpringArm3D", true, false) as SpringArm3D
			if arm and absf(stick.y) > 0.05:
				var pitch_deg: float = arm.rotation_degrees.x + stick.y * 55.0 * delta
				arm.rotation_degrees = Vector3(clampf(pitch_deg, -55.0, 20.0), 0.0, 0.0)
		if orbit != 0.0:
			_camera_rig.rotate_y(orbit * 2.2 * delta)
			looking = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		looking = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			looking = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _camera_rig:
		_camera_rig.rotate_y(-event.relative.x * mouse_sensitivity)
		var arm := _camera_rig.find_child("SpringArm3D", true, false) as SpringArm3D
		if arm:
			var pitch_deg: float = arm.rotation_degrees.x - event.relative.y * mouse_sensitivity * 60.0
			pitch_deg = clampf(pitch_deg, -55.0, 20.0)
			arm.rotation_degrees = Vector3(pitch_deg, 0.0, 0.0)

	# Lead swap — handle Tab in unhandled_input so UI focus cannot eat it silently
	if _swap_cd > 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var pk: int = event.physical_keycode
		var kc: int = event.keycode
		if pk == KEY_TAB or kc == KEY_TAB or event.is_action_pressed("switch_next"):
			cycle_leader()
			get_viewport().set_input_as_handled()
			return
		if pk == KEY_1 or event.is_action_pressed("switch_dorothy"):
			_try_set(ID_DOROTHY)
			get_viewport().set_input_as_handled()
			return
		if pk == KEY_2 or event.is_action_pressed("switch_scarecrow"):
			_try_set(ID_SCARECROW)
			get_viewport().set_input_as_handled()
			return
		if pk == KEY_3 or event.is_action_pressed("switch_tinman"):
			_try_set(ID_TINMAN)
			get_viewport().set_input_as_handled()
			return
		if pk == KEY_4 or event.is_action_pressed("switch_lion"):
			_try_set(ID_LION)
			get_viewport().set_input_as_handled()
			return

func register(id: StringName, body: CharacterBody3D, unlocked: bool = false) -> void:
	_members[id] = body
	if unlocked:
		_unlocked[id] = true
		_present[id] = true
	if id == ID_DOROTHY and body.has_node("CameraPivot"):
		_camera_rig = body.get_node("CameraPivot")
		looking = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _leader_id == id:
		_apply_leader()

func set_present(id: StringName, on: bool = true) -> void:
	_present[id] = on
	unlock_changed.emit(id, is_unlocked(id))

func unlock(id: StringName) -> void:
	_unlocked[id] = true
	_present[id] = true
	unlock_changed.emit(id, true)
	leader_changed.emit(_leader_id, leader_body())

func is_unlocked(id: StringName) -> bool:
	return bool(_unlocked.get(id, false))

func is_present(id: StringName) -> bool:
	return bool(_present.get(id, false))

func leader_id() -> StringName:
	return _leader_id

func leader_body() -> CharacterBody3D:
	return _members.get(_leader_id) as CharacterBody3D

## Body every non-Lead party member should trail. Always the current Lead.
func follow_body() -> CharacterBody3D:
	return leader_body()

## Unlocked + present party bodies that can be attacked and fight on their own.
func combat_bodies() -> Array:
	var out: Array = []
	for id in [ID_DOROTHY, ID_SCARECROW, ID_LION, ID_TINMAN]:
		if not is_unlocked(id) or not is_present(id):
			continue
		var b: CharacterBody3D = _members.get(id) as CharacterBody3D
		if b == null or not is_instance_valid(b) or not b.visible:
			continue
		if id != ID_DOROTHY and b.has_method("can_take_lead") and not b.can_take_lead():
			continue
		out.append(b)
	return out

## How many live rogues are currently locked onto this body.
func attackers_on(body: Node3D) -> int:
	if body == null or not is_instance_valid(body):
		return 0
	var n := 0
	var tree := get_tree()
	if tree == null:
		return 0
	for e in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.is_in_group("enemies_dead"):
			continue
		var hp = e.get("health")
		if hp != null and int(hp) <= 0:
			continue
		var t = e.get("target")
		if t == body:
			n += 1
	return n

## Spread rogues across the active party — soft stick on current, prefer under-attacked bodies.
func pick_threat_target(from: Node3D, current: Node3D = null, stick_range: float = 48.0) -> Node3D:
	var bodies: Array = combat_bodies()
	if bodies.is_empty():
		return leader_body()
	var best: Node3D = null
	var best_score := 1.0e12
	for b in bodies:
		var body: Node3D = b as Node3D
		if body == null or not is_instance_valid(body):
			continue
		var d: float = from.global_position.distance_to(body.global_position)
		if d > stick_range:
			continue
		var pressure: float = float(attackers_on(body))
		# Closer + under-attacked; soft stick so packs still peel onto free friends.
		var score: float = d + pressure * 7.0
		if body == current:
			score -= 9.0
		if score < best_score:
			best_score = score
			best = body
	if best:
		return best
	# Fall back to nearest combat body even outside stick_range.
	best_score = 1.0e12
	for b2 in bodies:
		var body2: Node3D = b2 as Node3D
		if body2 == null:
			continue
		var d2: float = from.global_position.distance_to(body2.global_position)
		if d2 < best_score:
			best_score = d2
			best = body2
	return best if best else leader_body()

## Nearest live enemy to a party body (for ally auto-combat).
func nearest_enemy(from: Node3D, max_range: float = 22.0) -> Node3D:
	if from == null or not is_instance_valid(from):
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var best: Node3D = null
	var best_d := max_range
	for e in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e is Node3D):
			continue
		if e.is_in_group("enemies_dead"):
			continue
		var hp = e.get("health")
		if hp != null and int(hp) <= 0:
			continue
		var d: float = from.global_position.distance_to((e as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = e as Node3D
	return best

func member(id: StringName) -> CharacterBody3D:
	return _members.get(id) as CharacterBody3D

func each_member() -> Array:
	var out: Array = []
	for id in _members.keys():
		var b: CharacterBody3D = _members[id]
		if b and is_instance_valid(b):
			out.append(b)
	return out

func camera_basis_node() -> Node3D:
	if _camera_rig and is_instance_valid(_camera_rig):
		return _camera_rig
	return leader_body()

func roster_line() -> String:
	var bits: PackedStringArray = []
	for id in [ID_DOROTHY, ID_SCARECROW, ID_LION, ID_TINMAN]:
		var name := _display_name(id)
		if id == ID_DOROTHY:
			bits.append("1 %s%s" % [name, " *" if _leader_id == id else ""])
		elif not is_unlocked(id):
			bits.append("%s locked" % name)
		elif not is_present(id):
			bits.append("%s away" % name)
		else:
			var key := "2" if id == ID_SCARECROW else ("4" if id == ID_LION else "3")
			bits.append("%s %s%s" % [key, name, " *" if _leader_id == id else ""])
	return "  ·  ".join(bits)

func _display_name(id: StringName) -> String:
	match id:
		ID_DOROTHY:
			return "Dorothy"
		ID_SCARECROW:
			return "Scarecrow"
		ID_TINMAN:
			return "Tin Man"
		ID_LION:
			return "Lion"
	return String(id)

func cycle_leader() -> void:
	# Order matches vault join order once present: Dorothy → Scarecrow → Lion → Tin Man
	var order: Array[StringName] = [ID_DOROTHY, ID_SCARECROW, ID_LION, ID_TINMAN]
	var start := order.find(_leader_id)
	if start < 0:
		start = 0
	for i in range(1, order.size() + 1):
		var cand: StringName = order[(start + i) % order.size()]
		if _can_lead(cand):
			set_leader(cand)
			return
	_fail_swap(_why_no_swap())

func _try_set(id: StringName) -> void:
	if not set_leader(id):
		_fail_swap(_why_cannot(id))

func set_leader(id: StringName) -> bool:
	if not _can_lead(id):
		return false
	if id == _leader_id:
		return true
	_leader_id = id
	_swap_cd = 0.45
	_apply_leader()
	leader_changed.emit(_leader_id, leader_body())
	last_fail = ""
	return true

func _can_lead(id: StringName) -> bool:
	if not bool(_unlocked.get(id, false)):
		return false
	if not bool(_present.get(id, true)):
		return false
	var body := _members.get(id) as CharacterBody3D
	if body == null or not is_instance_valid(body):
		return false
	if not body.visible:
		return false
	if body.has_method("can_take_lead") and not body.can_take_lead():
		return false
	return true

func _why_cannot(id: StringName) -> String:
	if id == ID_DOROTHY:
		return "Dorothy is already ready."
	if not _members.has(id) or not is_instance_valid(_members.get(id)):
		return "%s is not on this road yet." % _display_name(id)
	if not is_unlocked(id):
		match id:
			ID_SCARECROW:
				return "Free Scarecrow from the pole after the Shoes (E)."
			ID_LION:
				return "Calm the Lion in the brush first (E)."
			ID_TINMAN:
				return "Oil the Tin Man (can + E) before he can Lead."
			_:
				return "%s is not bonded yet." % _display_name(id)
	if not is_present(id):
		return "%s is not present." % _display_name(id)
	return "Cannot Lead as %s right now." % _display_name(id)

func _why_no_swap() -> String:
	if not is_unlocked(ID_SCARECROW):
		return "No other Lead yet — claim Shoes, free Scarecrow (E)."
	return "No other bonded friend is ready. Tab cycles unlocked Leads."

func _fail_swap(reason: String) -> void:
	last_fail = reason
	swap_failed.emit(reason)
	print("Lead blocked: ", reason)

func _apply_leader() -> void:
	for id in _members.keys():
		var body: CharacterBody3D = _members[id]
		if body == null or not is_instance_valid(body):
			continue
		var lead: bool = id == _leader_id
		if body.has_method("set_leading"):
			body.set_leading(lead)
		elif body.has_method("set_player_controlled"):
			body.set_player_controlled(lead)
	_reattach_camera()

func _reattach_camera() -> void:
	var lead := leader_body()
	if lead == null or _camera_rig == null or not is_instance_valid(_camera_rig):
		return
	if _camera_rig.get_parent() != lead:
		_camera_rig.reparent(lead, false)
	if lead.has_node("CameraAnchor"):
		var anchor: Node3D = lead.get_node("CameraAnchor")
		_camera_rig.position = anchor.position
	else:
		_camera_rig.position = Vector3(0, 1.35, 0)
	_camera_rig.rotation.x = 0.0
	_camera_rig.rotation.z = 0.0
	var cam := _camera_rig.find_child("Camera3D", true, false) as Camera3D
	if cam:
		cam.current = true
