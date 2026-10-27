extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://regions/munchkinland/landing_square.tscn")
	var node := packed.instantiate()
	root.add_child(node)
	for _i in 30:
		await process_frame
	var player := node.find_child("Player", true, false) as Node3D
	print("PLAYER_POS ", player.global_position)
	var img := root.get_viewport().get_texture().get_image()
	var out := "res://tools/landing_preview.png"
	var err := img.save_png(ProjectSettings.globalize_path(out))
	print("SHOT ", err, " ", img.get_width(), "x", img.get_height())
	quit(0)
