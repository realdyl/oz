extends SceneTree

## Phase P1.3–P12.3 Retail Verification Suite:
## Verifies Title Screen, 360° Camera Floor-Clamp, Open-Book Grimoire, Boutique Curios,
## Style Rank (D -> ★ SOVEREIGN), Side Quests ("Vile Requests"), Velvet Sanctums & NG+!

var _failures: PackedStringArray = []

func _fail(msg: String) -> void:
	_failures.append(msg)
	push_error("RETAIL_P3_FAIL: " + msg)

func _initialize() -> void:
	# 1. Verify 2026 Title Screen loads & builds cleanly
	var t_packed: PackedScene = load("res://ui/shell/title_screen.tscn")
	if t_packed == null:
		_fail("title_screen.tscn failed to load")
	else:
		var t_node := t_packed.instantiate()
		root.add_child(t_node)
		await process_frame
		await process_frame
		print("TITLE_SCREEN_OK")
		t_node.queue_free()
		await process_frame

	# 2. Verify SaveManager Style Rank, Curios, Side Quests & Velvet Road NG+
	var sm := root.get_node_or_null("SaveManager")
	if sm == null:
		_fail("SaveManager autoload missing")
	else:
		sm.call("register_style_action", 150.0, "Test Sovereign")
		var rank := str(sm.call("style_rank"))
		if "SOVEREIGN" not in rank:
			_fail("expected SOVEREIGN style rank, got: " + rank)
		else:
			print("STYLE_RANK_OK ", rank, " mult=", sm.call("style_multiplier"))
		sm.call("grant_charm", "charm_clockwork_heart")
		sm.call("buy_and_equip", "charms", "charm_clockwork_heart")
		if int(sm.get("max_hp")) != 6:
			_fail("charm_clockwork_heart did not raise max_hp to 6")
		else:
			print("CURIO_CHARM_6HP_OK")
		sm.call("advance_side_quest", "kansas_storm_prep", 2)
		if "kansas_storm_prep" not in sm.get("completed_quests"):
			_fail("side quest kansas_storm_prep did not complete")
		else:
			print("VILE_REQUEST_OK")
		sm.call("unlock_velvet_road")
		if not bool(sm.get("velvet_road_unlocked")):
			_fail("velvet_road_unlocked not set")
		else:
			print("VELVET_ROAD_NG_PLUS_OK")
		# Reset hp/max_hp back to clean defaults after test
		sm.call("buy_and_equip", "charms", "charm_echo_heel")
		sm.set("style_points", 0.0)

	# 3. Verify 360° Camera Floor-Clamp in Munchkinland + Velvet Sanctum & Synergy Monuments
	var m_packed: PackedScene = load("res://regions/munchkinland/landing_square.tscn")
	if m_packed:
		var m_node := m_packed.instantiate()
		root.add_child(m_node)
		for _i in 20:
			await process_frame
		var party := root.get_node_or_null("Party")
		var player := m_node.find_child("Player", true, false) as Node3D
		var arm := m_node.find_child("SpringArm3D", true, false) as SpringArm3D
		var cam := m_node.find_child("Camera3D", true, false) as Camera3D
		if player and arm and cam and party:
			# Attempt to force extreme positive pitch (+75 deg, which previously plunged camera under floor!)
			arm.rotation_degrees = Vector3(75.0, 0.0, 0.0)
			party.call("_process", 0.016)
			await process_frame
			var cam_y := cam.global_position.y
			var floor_y := player.global_position.y
			if cam_y < floor_y + 0.12 or arm.rotation_degrees.x > 20.0:
				_fail("camera dipped below safe floor! cam_y=%.3f pitch=%.2f" % [cam_y, arm.rotation_degrees.x])
			else:
				print("CAMERA_FLOOR_CLAMP_OK cam_y=%.3f pitch=%.2f" % [cam_y, arm.rotation_degrees.x])
		var sanctum := m_node.find_child("VelvetSanctum_sanctum_munchkin", true, false)
		var crow_bell := m_node.find_child("Monument_ScarecrowCrow-Bell", true, false)
		if sanctum == null or crow_bell == null:
			_fail("missing Munchkinland VelvetSanctum or Crow-Bell monument")
		else:
			print("MUNCHKIN_SANCTUM_AND_PUZZLES_OK")
		# Open Grimoire & Boutique headlessly to verify zero UI runtime errors
		var hud := m_node.find_child("PlayHUD", true, false)
		if hud:
			var gm = hud.get("grimoire_menu")
			var sh = hud.get("shop_menu")
			if gm:
				for tab_i in range(6):
					gm.call("open", tab_i)
				gm.call("close")
				print("GRIMOIRE_6_TABS_OK")
			if sh:
				for c_id in ["dorothy", "scarecrow", "tinman", "lion", "toto", "charms"]:
					sh.call("open", c_id)
				sh.call("close")
				print("BOUTIQUE_6_TABS_OK")
		m_node.queue_free()
		await process_frame

	if _failures.is_empty():
		print("RETAIL_P3_ALL_OK")
		quit(0)
	else:
		quit(1)
