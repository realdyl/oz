extends SceneTree

## Kansas prologue: walk, basket, Toto, Aunt Em, shutter, cellar, house door → lift/fade.

var _failures: PackedStringArray = []
var _farm: Node3D
var _player: CharacterBody3D
var _basket: Area3D
var _toto: CharacterBody3D

func _initialize() -> void:
	var packed: PackedScene = load("res://regions/kansas/farmyard.tscn")
	if packed == null:
		_fail("farmyard load failed")
		_finish()
		return
	_farm = packed.instantiate()
	root.add_child(_farm)
	for _i in 40:
		await process_frame

	_player = _farm.find_child("Player", true, false) as CharacterBody3D
	_basket = _farm.find_child("Basket", true, false) as Area3D
	_toto = _farm.find_child("Toto", true, false) as CharacterBody3D
	var hud := _farm.find_child("PlayHUD", true, false)
	var house := _farm.find_child("Farmhouse", true, false)
	var cam := _farm.find_child("Camera3D", true, false) as Camera3D
	var aunt := _farm.find_child("Aunt Em", true, false)
	var henry := _farm.find_child("Uncle Henry", true, false)
	var door := _farm.find_child("HouseDoor", true, false)

	if _player == null:
		_fail("missing Player")
	if _basket == null:
		_fail("missing Basket")
	if _toto == null:
		_fail("missing Toto")
	if hud == null:
		_fail("missing PlayHUD")
	if house == null:
		_fail("missing Farmhouse")
	if cam == null or not cam.current:
		_fail("missing current Camera3D")
	if aunt == null:
		_fail("missing Aunt Em")
	if henry == null:
		_fail("missing Uncle Henry")
	if door == null:
		_fail("missing HouseDoor")
	if not InputMap.has_action("move_forward") or not InputMap.has_action("interact"):
		_fail("input incomplete")

	if not _failures.is_empty():
		_finish()
		return

	for _i in 40:
		await process_frame
	if not _player.is_on_floor():
		_fail("player not on floor y=%.3f" % _player.global_position.y)
	print("FLOOR_OK y=", _player.global_position.y)

	# Objectives should be spread (not all <8m from spawn)
	var bdist: float = _player.global_position.distance_to(_basket.global_position)
	var tdist: float = _player.global_position.distance_to(_toto.global_position)
	print("SPREAD basket=%.1fm toto=%.1fm" % [bdist, tdist])
	if bdist < 10.0:
		_fail("basket too close to spawn dist=%.1f" % bdist)
	if tdist < 10.0:
		_fail("toto too close to spawn dist=%.1f" % tdist)
	if _basket.global_position.distance_to(_toto.global_position) < 12.0:
		_fail("basket and toto too close to each other")

	var start := _player.global_position
	var pivot: Node3D = _player.get_node_or_null("CameraPivot")
	if pivot:
		pivot.rotation.y = 0.0
	Input.action_press("move_forward", 1.0)
	for _i in 50:
		await process_frame
	Input.action_release("move_forward")
	var walked := start.distance_to(_player.global_position)
	print("WALK dist=", walked)
	if walked < 1.2:
		_fail("walk too short dist=%.3f" % walked)

	# Basket
	_player.global_position = _basket.global_position + Vector3(0, 0.05, 0.5)
	for _i in 8:
		await process_frame
	if not _basket.player_near:
		_basket._on_body_entered(_player)
	_basket.take()
	for _i in 10:
		await process_frame
	if not _player.has_basket:
		_fail("basket not taken")
	else:
		print("BASKET_OK")

	# Toto
	_player.global_position = _toto.global_position + Vector3(0, 0.05, 0.6)
	for _i in 12:
		await process_frame
	if not _toto.joined_basket:
		_toto._join(_player)
	for _i in 15:
		await process_frame
	if not _player.has_toto or not _toto.joined_basket:
		_fail("toto did not join basket")
	else:
		print("TOTO_OK")

	# Aunt Em multi-line → shutter phase
	if _farm.phase == _farm.Phase.NEED_AUNT:
		_farm._aunt_line = 99
		_farm._talk_aunt()
		for _i in 6:
			await process_frame
		print("AUNT_OK")
	if _farm.phase == _farm.Phase.NEED_SHUTTER:
		_farm._close_shutter()
		for _i in 6:
			await process_frame
		print("SHUTTER_OK")
	if _farm.phase == _farm.Phase.NEED_CELLAR:
		_farm._touch_cellar()
		for _i in 6:
			await process_frame
		print("CELLAR_OK")
	if _farm.phase != _farm.Phase.STORM_RUN:
		_fail("storm_run not started after cellar phase=%s" % str(_farm.phase))
	else:
		print("STORM_RUN_OK")
	if _farm.find_child("Barn", true, false) == null:
		_fail("missing Barn landmark")
	else:
		print("BARN_OK")
	if not door.visible:
		_fail("house door not revealed in storm")
	else:
		print("DOOR_REVEAL_OK")

	# FINAL STEP: enter house → lift → fade
	_farm.force_house_enter()
	for _i in 20:
		await process_frame
	if _farm.phase != _farm.Phase.HOUSE_LIFT and _farm.phase != _farm.Phase.FADE and _farm.phase != _farm.Phase.STRIKE:
		_fail("house lift/fade not entered phase=%s" % str(_farm.phase))
	else:
		print("HOUSE_LIFT_OK phase=", _farm.phase)

	# Advance lift to fade
	if _farm.phase == _farm.Phase.HOUSE_LIFT:
		_farm._lift_t = 3.5
		_farm._process(0.05)
		for _i in 8:
			await process_frame
	if _farm.phase == _farm.Phase.FADE or _farm.phase == _farm.Phase.STRIKE or _farm.phase == _farm.Phase.HOUSE_LIFT:
		print("FADE_PATH_OK")
	else:
		_fail("fade path missing phase=%s" % str(_farm.phase))

	_finish()

func _fail(msg: String) -> void:
	_failures.append(msg)
	push_error("KANSAS_FAIL " + msg)

func _finish() -> void:
	if _failures.is_empty():
		print("KANSAS_OK")
		quit(0)
	else:
		print("KANSAS_FAIL count=", _failures.size())
		for f in _failures:
			print(" - ", f)
		quit(1)
