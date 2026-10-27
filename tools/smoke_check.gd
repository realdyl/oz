extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://regions/munchkinland/landing_square.tscn")
	if packed == null:
		push_error("LOAD_FAIL")
		quit(1)
		return
	var node := packed.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	var player := node.find_child("Player", true, false)
	var shoes := node.find_child("SilverShoes", true, false)
	var house := node.find_child("CrashedHouse", true, false)
	var hud := node.find_child("PlayHUD", true, false)
	if player == null or shoes == null or house == null or hud == null:
		push_error("MISSING player=%s shoes=%s house=%s hud=%s" % [player, shoes, house, hud])
		quit(1)
		return
	print("SMOKE_OK")
	quit(0)
