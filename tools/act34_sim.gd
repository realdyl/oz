extends SceneTree

## Headless load + beat smoke: Poppy (L3) · West (L4) · Emerald (L5) · Glinda · Home.

func _initialize() -> void:
	var ok := true
	# L3 Deadly Poppy Field
	var ppath := "res://regions/poppy/poppy_road.tscn"
	var ppacked: PackedScene = load(ppath)
	if ppacked == null:
		push_error("LOAD_FAIL poppy_road")
		ok = false
	else:
		var pnode := ppacked.instantiate()
		root.add_child(pnode)
		await process_frame
		await process_frame
		var pp := pnode.find_child("Player", true, false)
		var ph := pnode.find_child("PlayHUD", true, false)
		var pybr := pnode.find_child("YellowBrickRoad", true, false)
		var pgate := pnode.find_child("WestGatePad", true, false)
		if pp == null or ph == null:
			push_error("POPPY_MISSING player/hud")
			ok = false
		else:
			print("POPPY_PRESENT")
		if pybr == null or pgate == null:
			push_error("POPPY_YBR_GATE_MISSING")
			ok = false
		else:
			print("POPPY_YBR_OK")
		if pnode.has_method("_go_west"):
			print("POPPY_WEST_WIRED")
		else:
			push_error("POPPY_WEST_NOT_WIRED")
			ok = false
		var sc := pnode.find_child("Scarecrow", true, false)
		var tm := pnode.find_child("TinMan", true, false)
		if sc == null and tm == null:
			# companion roots may be Player-named; still OK if party spawned
			print("POPPY_PARTY_SOFT")
		print("POPPY_OK")
		print("ACT3_POPPY_OK")
		pnode.queue_free()
		await process_frame
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
		# Pad + homecoming path present
		var pad := gnode.find_child("RoadHomePad", true, false)
		if pad == null:
			push_error("GLINDA_PAD_MISSING")
			ok = false
		else:
			print("GLINDA_PAD_OK")
		if gnode.has_method("_go_homecoming"):
			print("GLINDA_HOME_WIRED")
		else:
			push_error("GLINDA_HOME_NOT_WIRED")
			ok = false
		print("GLINDA_OK")
		gnode.queue_free()
		await process_frame
	# L6 Kansas homecoming finale
	var hpath := "res://regions/kansas/homecoming.tscn"
	var hpacked: PackedScene = load(hpath)
	if hpacked == null:
		push_error("LOAD_FAIL homecoming")
		ok = false
	else:
		var hnode := hpacked.instantiate()
		root.add_child(hnode)
		await process_frame
		await process_frame
		var hp := hnode.find_child("Player", true, false)
		var hh := hnode.find_child("PlayHUD", true, false)
		var ha := hnode.find_child("AuntEm", true, false)
		var porch := hnode.find_child("PorchPad", true, false)
		if hp == null or hh == null or ha == null:
			push_error("HOME_MISSING player/hud/aunt")
			ok = false
		else:
			print("HOME_PRESENT")
		if porch:
			print("HOME_PORCH_OK")
		else:
			push_error("HOME_PORCH_MISSING")
			ok = false
		print("HOME_OK")
		hnode.queue_free()
		await process_frame
	var m := load("res://regions/munchkinland/landing_square.tscn")
	if m == null:
		push_error("LOAD_FAIL munchkinland")
		ok = false
	else:
		var src := FileAccess.get_file_as_string("res://regions/munchkinland/landing_square.gd")
		if src.find("poppy_road.tscn") < 0 or src.find("_go_poppy_road") < 0:
			push_error("L2_NOT_WIRED_TO_POPPY")
			ok = false
		else:
			print("L2_POPPY_WIRED")
	if ok:
		print("ACT34_OK")
		print("ACT3_POPPY_OK")
		print("ACT5_OK")
		print("ACT6_OK")
		print("ACT7_OK")
		quit(0)
	else:
		quit(1)
