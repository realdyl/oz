extends SceneTree

## Headless load + beat smoke for West castle and Emerald City.

func _initialize() -> void:
	var ok := true
	for path in [
		"res://regions/winkie/west_castle.tscn",
		"res://regions/emerald_city/wizard_tower.tscn",
	]:
		var packed: PackedScene = load(path)
		if packed == null:
			push_error("LOAD_FAIL %s" % path)
			ok = false
			continue
		var node := packed.instantiate()
		root.add_child(node)
		await process_frame
		await process_frame
		await process_frame
		var player := node.find_child("Player", true, false)
		var hud := node.find_child("PlayHUD", true, false)
		if player == null or hud == null:
			push_error("MISSING player/hud in %s" % path)
			ok = false
		if path.ends_with("west_castle.tscn"):
			var west := node.find_child("WitchOfTheWest", true, false)
			var cistern := node.find_child("Cistern", true, false)
			if west == null or cistern == null:
				push_error("WEST_MISSING boss or cistern")
				ok = false
			else:
				print("WEST_PRESENT")
			if node.has_method("_set_beat"):
				# Force water path without full fight.
				node.set("has_water", true)
				node.set("west_grounded", true)
				node.set("west_hp", 30)
				node.call("_set_beat", 3) # WATER_READY
				print("WEST_WATER_BEAT")
			print("WEST_OK")
		elif path.ends_with("wizard_tower.tscn"):
			var head := node.find_child("WizardProjection", true, false)
			var curtain := node.find_child("Curtain", true, false)
			var ybr := false
			for c in node.get_children():
				if str(c.name).begins_with("YellowBrick") or str(c.name) == "YellowBrickRoad":
					ybr = true
			if head == null or curtain == null:
				push_error("EMERALD_MISSING head/curtain")
				ok = false
			else:
				print("EMERALD_PRESENT")
			if ybr:
				print("YBR_OK")
			else:
				# YBR is a mesh body named YellowBrickRoad
				var road := node.find_child("YellowBrickRoad", true, false)
				if road:
					print("YBR_OK")
				else:
					push_error("YBR_MISSING")
					ok = false
			print("EMERALD_OK")
		node.queue_free()
		await process_frame
	# Smoke both still load after unload
	var m := load("res://regions/munchkinland/landing_square.tscn")
	if m == null:
		push_error("LOAD_FAIL munchkinland")
		ok = false
	if ok:
		print("ACT34_OK")
		quit(0)
	else:
		quit(1)
