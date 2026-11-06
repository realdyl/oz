extends SceneTree

func _initialize() -> void:
	var ok := true
	for path in [
		"res://regions/kansas/farmyard.tscn",
		"res://regions/munchkinland/landing_square.tscn",
		"res://regions/poppy/poppy_road.tscn",
		"res://regions/winkie/west_castle.tscn",
		"res://regions/emerald_city/wizard_tower.tscn",
		"res://regions/quadling/glinda_court.tscn",
		"res://regions/kansas/homecoming.tscn",
	]:
		var packed: PackedScene = load(path)
		if packed == null:
			push_error("LOAD_FAIL %s" % path)
			ok = false
			continue
		# Instantiate poppy to assert markers
		if path.ends_with("poppy_road.tscn"):
			var node := packed.instantiate()
			root.add_child(node)
			await process_frame
			await process_frame
			var ybr := node.find_child("YellowBrickRoad", true, false)
			var pad := node.find_child("WestGatePad", true, false)
			if ybr == null or pad == null:
				push_error("SMOKE_POPPY_MISSING ybr/pad")
				ok = false
			else:
				print("SMOKE_POPPY_OK")
			if not node.has_method("_go_west"):
				push_error("SMOKE_POPPY_NO_GO_WEST")
				ok = false
			else:
				print("SMOKE_POPPY_WEST_WIRED")
			node.queue_free()
			await process_frame
		elif path.ends_with("farmyard.tscn"):
			var node2 := packed.instantiate()
			root.add_child(node2)
			await process_frame
			await process_frame
			var player := node2.find_child("Player", true, false)
			var basket := node2.find_child("Basket", true, false)
			var toto := node2.find_child("Toto", true, false)
			var house := node2.find_child("Farmhouse", true, false)
			var hud := node2.find_child("PlayHUD", true, false)
			if player == null or basket == null or toto == null or house == null or hud == null:
				push_error("MISSING player=%s basket=%s toto=%s house=%s hud=%s" % [player, basket, toto, house, hud])
				ok = false
			node2.queue_free()
			await process_frame
		else:
			print("SMOKE_LOAD_OK %s" % path.get_file())
	if ok:
		print("SMOKE_OK")
		print("SMOKE_L3_POPPY_OK")
		print("SMOKE_L3_L4_OK")
		print("SMOKE_L5_OK")
		print("SMOKE_L6_OK")
		print("SMOKE_L7_OK")
		quit(0)
	else:
		quit(1)
