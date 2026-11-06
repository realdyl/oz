extends SceneTree

## Headless load + beat smoke for West castle, Emerald City, and Glinda (L5).

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
			var sealed := node.find_child("Gatehouse", true, false)
			if sealed != null:
				push_error("WEST_GATE_STILL_SOLID Gatehouse block present")
				ok = false
			else:
				var arch := node.find_child("GateArch", true, false)
				var pad := node.find_child("EmeraldGatePad", true, false)
				var ybrn := node.find_child("YellowBrickRoadN", true, false)
				if arch == null or pad == null or ybrn == null:
					push_error("WEST_YBR_GATE_MISSING arch/pad/road")
					ok = false
				else:
					print("WEST_YBR_OPEN")
			if node.has_method("_set_beat"):
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
				var road := node.find_child("YellowBrickRoad", true, false)
				if road:
					print("YBR_OK")
				else:
					push_error("YBR_MISSING")
					ok = false
			print("EMERALD_OK")
		node.queue_free()
		await process_frame
	# L5 Glinda
	var gpath := "res://regions/quadling/glinda_court.tscn"
	var gpacked: PackedScene = load(gpath)
	if gpacked == null:
		push_error("LOAD_FAIL glinda_court")
		ok = false
	else:
		var gnode := gpacked.instantiate()
		root.add_child(gnode)
		await process_frame
		await process_frame
		var gp := gnode.find_child("Player", true, false)
		var gh := gnode.find_child("PlayHUD", true, false)
		var gl := gnode.find_child("Glinda", true, false)
		var ybr_g := gnode.find_child("YellowBrickRoad", true, false)
		if gp == null or gh == null or gl == null:
			push_error("GLINDA_MISSING player/hud/glinda")
			ok = false
		else:
			print("GLINDA_PRESENT")
		if ybr_g:
			print("GLINDA_YBR_OK")
		else:
			push_error("GLINDA_YBR_MISSING")
			ok = false
		print("GLINDA_OK")
		gnode.queue_free()
		await process_frame
	var m := load("res://regions/munchkinland/landing_square.tscn")
	if m == null:
		push_error("LOAD_FAIL munchkinland")
		ok = false
	if ok:
		print("ACT34_OK")
		print("ACT5_OK")
		quit(0)
	else:
		quit(1)
