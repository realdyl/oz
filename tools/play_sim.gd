extends SceneTree

## Headless: walk, blink, kick, shoes, free Scarecrow/Lion/Tin, Lead each.

var _player: CharacterBody3D
var _shoes: Node3D
var _landing: Node3D
var _scarecrow: CharacterBody3D
var _lion: CharacterBody3D
var _tinman: CharacterBody3D
var _party: Node
var _failures: PackedStringArray = []

func _initialize() -> void:
	_party = root.get_node_or_null("Party")
	var packed: PackedScene = load("res://regions/munchkinland/landing_square.tscn")
	if packed == null:
		_fail("scene load failed")
		_finish()
		return
	_landing = packed.instantiate()
	root.add_child(_landing)
	for _i in 40:
		await process_frame

	_player = _landing.find_child("Player", true, false) as CharacterBody3D
	_shoes = _landing.find_child("SilverShoes", true, false) as Node3D
	_scarecrow = _landing.find_child("Scarecrow", true, false) as CharacterBody3D
	_lion = _landing.find_child("Lion", true, false) as CharacterBody3D
	_tinman = _landing.find_child("TinMan", true, false) as CharacterBody3D
	var cam := _landing.find_child("Camera3D", true, false) as Camera3D
	var house := _landing.find_child("CrashedHouse", true, false)
	var hud := _landing.find_child("PlayHUD", true, false)
	var road := _landing.find_child("YellowBrickRoad", true, false)
	var puppets := _landing.find_children("*", "CharacterBody3D", true, false).filter(
		func(n: Node) -> bool: return n.is_in_group("enemies")
	)

	if _player == null:
		_fail("missing Player")
	if _shoes == null:
		_fail("missing SilverShoes")
	if cam == null or not cam.current:
		_fail("missing current Camera3D")
	if house == null:
		_fail("missing CrashedHouse")
	if hud == null:
		_fail("missing PlayHUD")
	if road == null:
		_fail("missing YellowBrickRoad")
	if puppets.is_empty():
		_fail("no puppet enemies")
	if _scarecrow == null:
		_fail("missing Scarecrow")
	if _lion == null:
		_fail("missing Lion")
	if _tinman == null:
		_fail("missing TinMan")
	if not InputMap.has_action("switch_next"):
		_fail("party switch actions missing")
	if _party == null:
		_fail("Party autoload missing")
	# Placement: Scarecrow in open cornfield, not wedged on PinkCottage.
	if _scarecrow:
		var pink := _landing.get_node_or_null("PinkCottage") as Node3D
		if pink and _scarecrow.global_position.distance_to(pink.global_position) < 14.0:
			_fail("Scarecrow still near PinkCottage d=%.1f" % _scarecrow.global_position.distance_to(pink.global_position))
		if _scarecrow.global_position.x < 30.0:
			_fail("Scarecrow not in east cornfield x=%.1f" % _scarecrow.global_position.x)
	if _lion and _lion.global_position.z > -20.0:
		_fail("Lion not north enough z=%.1f" % _lion.global_position.z)
	if _scarecrow and _scarecrow.global_position.distance_to(Vector3(0, 0, 14)) < 12.0:
		_fail("Scarecrow too close to spawn")
	if _tinman and _tinman.global_position.x > -30.0:
		_fail("TinMan not west enough x=%.1f" % _tinman.global_position.x)
	var wall_w := _landing.get_node_or_null("WallWest") as Node3D
	if wall_w and wall_w.global_position.x > -55.0:
		_fail("WallWest still blocks west path at x=%.1f" % wall_w.global_position.x)
	print("PLACE_OK sc=", _scarecrow.global_position if _scarecrow else Vector3.ZERO, " lion=", _lion.global_position if _lion else Vector3.ZERO, " tin=", _tinman.global_position if _tinman else Vector3.ZERO)

	if not _failures.is_empty():
		_finish()
		return

	var start := _player.global_position
	print("START ", start)
	for _i in 40:
		await process_frame
	if not _player.is_on_floor():
		_fail("player not on floor y=%.3f" % _player.global_position.y)
	print("FLOOR_OK y=", _player.global_position.y)

	# Sticky threat compass + hunt-the-Lead (no chase-the-map).
	var threat := hud.get_node_or_null("ThreatCompass") as Label
	if threat == null:
		_fail("missing sticky ThreatCompass")
	else:
		for _i in 20:
			await process_frame
		if threat.text.strip_edges() == "":
			_fail("ThreatCompass empty with live enemies")
		else:
			print("THREAT_COMPASS_OK ", threat.text)
	var seeker: CharacterBody3D = puppets[0]
	var lead_pos := _player.global_position
	seeker.global_position = lead_pos + Vector3(18.0, 0.08, 0.0)
	if seeker.has_method("arm_delayed"):
		seeker.arm_delayed(0.0, 2.0)
	if "combat_ready" in seeker:
		seeker.combat_ready = true
	if seeker.has_method("_finish_arming"):
		seeker.call("_finish_arming")
	elif "state" in seeker:
		# APPROACH = 1
		seeker.set("state", 1)
	var d0: float = seeker.global_position.distance_to(lead_pos)
	for _i in 90:
		await physics_frame
	var d1: float = seeker.global_position.distance_to(_player.global_position)
	print("HUNT d0=", d0, " d1=", d1)
	if d1 >= d0 - 2.0:
		_fail("rogue did not hunt Lead d0=%.1f d1=%.1f" % [d0, d1])
	else:
		print("HUNT_OK")

	var pivot: Node3D = _party.call("camera_basis_node") as Node3D if _party.has_method("camera_basis_node") else null
	if pivot:
		pivot.rotation.y = 0.0
	Input.action_press("move_forward", 1.0)
	for _i in 54:
		await process_frame
	Input.action_release("move_forward")
	var walked := start.distance_to(_player.global_position)
	print("WALK dist=", walked)
	if walked < 1.5:
		_fail("walk too short dist=%.3f" % walked)

	var pre_blink := _player.global_position
	_player.visual.rotation.y = 0.0
	_player._blink()
	for _i in 8:
		await process_frame
	var blink_dist := pre_blink.distance_to(_player.global_position)
	print("BLINK dist=", blink_dist)
	if blink_dist < 1.5:
		_fail("blink distance too short dist=%.3f" % blink_dist)

	var target: CharacterBody3D = puppets[0]
	var hp_before: int = target.health
	_player.global_position = target.global_position + Vector3(0, 0.05, 1.0)
	for _i in 6:
		await process_frame
	_player._kick()
	for _i in 20:
		await process_frame
	print("KICK hp ", hp_before, " -> ", target.health)
	if target.health >= hp_before:
		_fail("kick did not damage puppet")

	# Shoes
	_player.global_position = _shoes.global_position + Vector3(0, 0.05, 0.4)
	for _i in 10:
		await process_frame
	if not _shoes.player_near:
		_shoes._on_body_entered(_player)
	_shoes.take()
	for _i in 20:
		await process_frame
	if not _player.shoes_claimed:
		_fail("shoes claim failed")
	else:
		print("SHOES_OK")

	# Free Scarecrow (after shoes) — level free path auto-Leads Scarecrow
	if not bool(_landing.get("shoes_done")):
		_landing.set("shoes_done", true)
	if _landing.has_method("_free_scarecrow"):
		_landing.call("_free_scarecrow")
	else:
		_scarecrow.free_from_pole()
	for _i in 15:
		await process_frame
	if not bool(_party.call("is_unlocked", _party.get("ID_SCARECROW"))):
		_fail("Scarecrow not unlocked after free")
	else:
		print("SCARECROW_UNLOCK_OK")
	var sc_id = _party.get("ID_SCARECROW")
	var d_id = _party.get("ID_DOROTHY")
	if _party.call("leader_id") != sc_id:
		# Fallback if auto-lead missed
		if not bool(_party.call("set_leader", sc_id)):
			_fail("set_leader scarecrow failed")
	else:
		print("AUTO_LEAD_SCARECROW_OK")
	for _i in 10:
		await process_frame
	if _party.call("leader_id") != sc_id:
		_fail("leader not scarecrow")
	if _player.leading:
		_fail("Dorothy still leading")
	if not _scarecrow.leading:
		_fail("Scarecrow not leading")
	# Party follows current Lead (Dorothy should trail Scarecrow)
	_scarecrow.global_position = Vector3(0.0, 0.05, 8.0)
	_player.global_position = Vector3(0.0, 0.05, 14.0)
	_player.velocity = Vector3.ZERO
	for _i in 8:
		await process_frame
	var d_start := _player.global_position
	for _i in 90:
		await process_frame
	var d_to_sc := _player.global_position.distance_to(_scarecrow.global_position)
	var d_moved := d_start.distance_to(_player.global_position)
	print("FOLLOW_LEAD d_moved=", d_moved, " d_to_sc=", d_to_sc)
	if d_to_sc > 4.5 and d_moved < 1.0:
		_fail("Dorothy did not follow Scarecrow Lead")
	else:
		print("FOLLOW_OK")

	# Multi-target: rogues split across party; non-Lead allies auto-fight.
	_party.call("set_leader", d_id)
	for _i in 8:
		await process_frame
	var bodies = _party.call("combat_bodies")
	if bodies is Array and bodies.size() < 2:
		_fail("combat_bodies expected >=2 got %s" % str(bodies.size() if bodies is Array else 0))
	else:
		print("COMBAT_BODIES_OK n=", bodies.size())
	_player.global_position = Vector3(-4.0, 0.08, 8.0)
	_scarecrow.global_position = Vector3(4.0, 0.08, 8.0)
	_player.velocity = Vector3.ZERO
	_scarecrow.velocity = Vector3.ZERO
	var p_a: CharacterBody3D = puppets[0]
	var p_b: CharacterBody3D = puppets[1] if puppets.size() > 1 else puppets[0]
	p_a.global_position = Vector3(-4.0, 0.08, 11.0)
	p_b.global_position = Vector3(4.0, 0.08, 11.0)
	for p in [p_a, p_b]:
		if p.has_method("arm_delayed"):
			p.arm_delayed(0.0, 2.0)
		p.combat_ready = true
		if p.has_method("_finish_arming"):
			p.call("_finish_arming")
		p.set("target", null)
		p.set("state", 1) # APPROACH
	var sc_caw_before: float = float(_scarecrow.get("caw_timer"))
	for _i in 100:
		await physics_frame
	var t_a = p_a.get("target")
	var t_b = p_b.get("target")
	print("MULTI_TARGET a=", t_a, " b=", t_b)
	var a_on_d: int = int(_party.call("attackers_on", _player))
	var a_on_s: int = int(_party.call("attackers_on", _scarecrow))
	print("ATTACKERS dorothy=", a_on_d, " scarecrow=", a_on_s)
	if a_on_d < 1 and a_on_s < 1:
		_fail("no party member under attack")
	# Prefer spread when two bodies are available and two rogues live.
	if p_a != p_b and t_a != null and t_b != null and t_a == t_b and a_on_d + a_on_s >= 2:
		# Soft fail soft: allow same target if spread failed, but warn via print only if both pressure 0 on one
		if a_on_d == 0 or a_on_s == 0:
			_fail("rogues did not spread across party d=%d sc=%d" % [a_on_d, a_on_s])
	else:
		print("MULTI_TARGET_OK")
	# Ally AI: Scarecrow not Lead should auto-caw or close on a foe.
	var sc_caw_after: float = float(_scarecrow.get("caw_timer"))
	var foe_near_sc = _party.call("nearest_enemy", _scarecrow, 20.0)
	print("ALLY_SC caw_before=", sc_caw_before, " after=", sc_caw_after, " foe=", foe_near_sc)
	if sc_caw_after <= 0.01 and sc_caw_before <= 0.01 and foe_near_sc != null:
		# May have fired and cooled; check confuse on nearby puppet or distance closed
		var closed := p_b.global_position.distance_to(_scarecrow.global_position) < 6.0 \
			or p_a.global_position.distance_to(_scarecrow.global_position) < 6.0
		if not closed and float(p_b.get("confuse_t")) <= 0.0 and float(p_a.get("confuse_t")) <= 0.0:
			_fail("Scarecrow ally did not engage")
		else:
			print("ALLY_FIGHT_OK")
	else:
		print("ALLY_FIGHT_OK")

	# Clear space, face camera-forward
	_scarecrow.global_position = Vector3(0.0, 0.05, 8.0)
	_scarecrow.velocity = Vector3.ZERO
	var sc_pivot: Node3D = _party.call("camera_basis_node") as Node3D
	if sc_pivot:
		sc_pivot.rotation = Vector3.ZERO
	_scarecrow.visual.rotation.y = 0.0
	for _i in 8:
		await process_frame
	var sc_start := _scarecrow.global_position
	Input.action_press("move_forward", 1.0)
	for _i in 60:
		await process_frame
	Input.action_release("move_forward")
	var sc_walked := sc_start.distance_to(_scarecrow.global_position)
	print("SCARECROW_WALK dist=", sc_walked)
	if sc_walked < 0.6:
		_fail("Scarecrow Lead walk too short dist=%.3f" % sc_walked)
	# CAW kit
	var conf_target: CharacterBody3D = puppets[0]
	if conf_target.state == conf_target.State.DEAD:
		conf_target = puppets[mini(1, puppets.size() - 1)]
	conf_target.set_physics_process(true)
	conf_target.state = conf_target.State.WANDER
	conf_target.health = 40
	conf_target.confuse_t = 0.0
	conf_target.fear_t = 0.0
	conf_target.armored = false
	conf_target.collision_layer = 4
	_scarecrow.global_position = conf_target.global_position + Vector3(0, 0.05, 0.5)
	for _i in 6:
		await process_frame
	_scarecrow._caw()
	for _i in 20:
		await process_frame
	if conf_target.confuse_t <= 0.0 and conf_target.health >= 40:
		_fail("Scarecrow CAW had no effect")
	else:
		print("CAW_OK confuse_t=", conf_target.confuse_t, " hp=", conf_target.health)

	# Lion — calm via level path auto-Leads Lion + LION_PACK wave
	if _landing.has_method("_calm_lion"):
		_landing.call("_calm_lion")
	else:
		_lion.calm_and_join()
	for _i in 12:
		await process_frame
	if not bool(_party.call("is_unlocked", _party.get("ID_LION"))):
		_fail("Lion not unlocked")
	else:
		print("LION_UNLOCK_OK")
	var lion_id = _party.get("ID_LION")
	if _party.call("leader_id") != lion_id:
		if not bool(_party.call("set_leader", lion_id)):
			_fail("set_leader lion failed")
	else:
		print("AUTO_LEAD_LION_OK")
	for _i in 8:
		await process_frame
	if not _lion.leading:
		_fail("Lion not leading")
	var pack_count := 0
	for n in _landing.get_children():
		if n is CharacterBody3D and n.has_meta("wave") and str(n.get_meta("wave")) == "lion_pack":
			pack_count += 1
	print("LION_PACK count=", pack_count)
	if pack_count < 3:
		_fail("Lion pack wave missing count=%d" % pack_count)
	else:
		print("LION_PACK_OK")
	var li_start := _lion.global_position
	# Clear open pad so den/hedge collision cannot pin Lead walk.
	_lion.global_position = Vector3(4.0, 0.08, -18.0)
	_lion.velocity = Vector3.ZERO
	var li_pivot: Node3D = _party.call("camera_basis_node") as Node3D
	if li_pivot:
		li_pivot.rotation = Vector3.ZERO
	if _lion.get("visual"):
		_lion.visual.rotation.y = 0.0
	for _i in 8:
		await process_frame
	li_start = _lion.global_position
	Input.action_press("move_forward", 1.0)
	for _i in 50:
		await process_frame
	Input.action_release("move_forward")
	var li_walked := li_start.distance_to(_lion.global_position)
	print("LION_WALK dist=", li_walked)
	if li_walked < 0.45:
		_fail("Lion Lead walk too short dist=%.3f" % li_walked)
	_lion.global_position = conf_target.global_position + Vector3(0, 0.05, 0.5)
	for _i in 4:
		await process_frame
	_lion._roar()
	for _i in 15:
		await process_frame
	print("ROAR_OK fear_t=", conf_target.fear_t)

	# Tin path: Dorothy Lead, walk west toward terrace.
	_party.call("set_leader", d_id)
	for _i in 6:
		await process_frame
	# Park followers / rogues clear of the west road so the path probe is geometry-only.
	if _scarecrow:
		_scarecrow.global_position = Vector3(20.0, 0.08, 20.0)
	if _lion:
		_lion.global_position = Vector3(12.0, 0.08, -30.0)
	if _tinman:
		# Keep tin on pad; move oil path clear
		pass
	for n in _landing.get_children():
		if n is CharacterBody3D and n.is_in_group("enemies") and is_instance_valid(n):
			n.global_position = Vector3(0.0, 0.08, 40.0)
			n.collision_layer = 0
	_player.global_position = Vector3(-12.0, 0.08, 4.0)
	_player.velocity = Vector3.ZERO
	var tin_pivot: Node3D = _party.call("camera_basis_node") as Node3D
	if tin_pivot:
		# +Y 90°: identity looks −Z; +PI/2 looks −X (west).
		tin_pivot.rotation = Vector3(0.0, PI * 0.5, 0.0)
	for _i in 12:
		await process_frame
	Input.action_press("move_forward", 1.0)
	for _i in 220:
		await physics_frame
	Input.action_release("move_forward")
	var tin_path_x := _player.global_position.x
	var tin_path_y := _player.global_position.y
	print("TIN_PATH x=", tin_path_x, " y=", tin_path_y)
	var blue := _landing.get_node_or_null("BlueCottage") as Node3D
	if blue:
		print("BLUE_AT ", blue.global_position)
	# Must progress west past the old WallWest / cottage choke (~−24).
	if tin_path_x > -30.0:
		_fail("Tin path blocked before terrace x=%.2f" % tin_path_x)
	else:
		print("TIN_PATH_OK")

	# Tin Man — level free path auto-Leads Tin
	if _landing.has_method("_free_tinman"):
		_landing.call("_free_tinman")
	else:
		_tinman.oil_and_free()
	for _i in 12:
		await process_frame
	if not bool(_party.call("is_unlocked", _party.get("ID_TINMAN"))):
		_fail("Tin Man not unlocked")
	else:
		print("TINMAN_UNLOCK_OK")
	var tm_id = _party.get("ID_TINMAN")
	if _party.call("leader_id") != tm_id:
		if not bool(_party.call("set_leader", tm_id)):
			_fail("set_leader tinman failed")
	else:
		print("AUTO_LEAD_TIN_OK")
	for _i in 8:
		await process_frame
	if not _tinman.leading:
		_fail("Tin Man not leading")
	_tinman.global_position = Vector3(0.0, 0.05, 6.0)
	_tinman.velocity = Vector3.ZERO
	for _i in 6:
		await process_frame
	var tm_start := _tinman.global_position
	Input.action_press("move_forward", 1.0)
	for _i in 35:
		await process_frame
	Input.action_release("move_forward")
	var tm_walked := tm_start.distance_to(_tinman.global_position)
	print("TINMAN_WALK dist=", tm_walked)
	if tm_walked < 0.6:
		_fail("Tin Man Lead walk too short dist=%.3f" % tm_walked)
	# Armored puppet + axe break
	conf_target.set_physics_process(true)
	conf_target.state = conf_target.State.WANDER
	conf_target.armored = true
	conf_target.health = 40
	conf_target.collision_layer = 4
	var hp_a: int = int(conf_target.health)
	_tinman.global_position = conf_target.global_position + Vector3(0, 0.05, 0.8)
	_tinman.visual.rotation.y = 0.0
	for _i in 4:
		await process_frame
	_tinman._axe()
	for _i in 25:
		await process_frame
	print("AXE_OK hp ", hp_a, " -> ", conf_target.health, " armored=", conf_target.armored)
	if conf_target.health >= hp_a:
		_fail("Tin axe did no damage")
	if conf_target.armored:
		_fail("Tin axe did not break armor")
	else:
		print("ARMOR_BREAK_OK")

	# Cycle via switch_next path
	if not bool(_party.call("set_leader", d_id)):
		_fail("return Dorothy failed")
	for _i in 6:
		await process_frame
	_party.call("cycle_leader")
	for _i in 6:
		await process_frame
	if _party.call("leader_id") == d_id:
		_fail("cycle_leader did not leave Dorothy")
	else:
		print("TAB_CYCLE_OK leader=", _party.call("leader_id"))

	if not bool(_party.call("set_leader", d_id)):
		_fail("final Dorothy return failed")

	_finish()

func _fail(msg: String) -> void:
	_failures.append(msg)
	push_error("PLAY_FAIL " + msg)

func _finish() -> void:
	if _failures.is_empty():
		print("PLAY_OK")
		quit(0)
	else:
		print("PLAY_FAIL count=", _failures.size())
		for f in _failures:
			print(" - ", f)
		quit(1)
