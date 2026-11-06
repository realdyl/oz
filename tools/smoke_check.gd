extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://regions/kansas/farmyard.tscn")
	if packed == null:
		push_error("LOAD_FAIL kansas")
		quit(1)
		return
	var node := packed.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	var player := node.find_child("Player", true, false)
	var basket := node.find_child("Basket", true, false)
	var toto := node.find_child("Toto", true, false)
	var house := node.find_child("Farmhouse", true, false)
	var hud := node.find_child("PlayHUD", true, false)
	if player == null or basket == null or toto == null or house == null or hud == null:
		push_error("MISSING player=%s basket=%s toto=%s house=%s hud=%s" % [player, basket, toto, house, hud])
		quit(1)
		return
	var m := load("res://regions/munchkinland/landing_square.tscn")
	if m == null:
		push_error("LOAD_FAIL munchkinland")
		quit(1)
		return
	var w := load("res://regions/winkie/west_castle.tscn")
	if w == null:
		push_error("LOAD_FAIL west_castle")
		quit(1)
		return
	var e := load("res://regions/emerald_city/wizard_tower.tscn")
	if e == null:
		push_error("LOAD_FAIL wizard_tower")
		quit(1)
		return
	print("SMOKE_OK")
	print("SMOKE_L3_L4_OK")
	quit(0)
