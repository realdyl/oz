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
	# Munchkinland still loads
	var m := load("res://regions/munchkinland/landing_square.tscn")
	if m == null:
		push_error("LOAD_FAIL munchkinland")
		quit(1)
		return
	print("SMOKE_OK")
	quit(0)
