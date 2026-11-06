extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://regions/munchkinland/landing_square.tscn")
	var node := packed.instantiate()
	root.add_child(node)
	for _i in 50:
		await process_frame
	var player := node.find_child("Player", true, false) as Node3D
	var cam := node.find_child("Camera3D", true, false) as Camera3D
	if player and cam:
		var forward := -cam.global_transform.basis.z
		print("CAM_POS ", cam.global_position)
		print("CAM_FWD ", forward)
		print("PLAYER ", player.global_position)
	var tex := root.get_viewport().get_texture()
	var img := tex.get_image() if tex else null
	if img == null:
		print("SHOT_FAIL")
		quit(1)
		return
	var path := ProjectSettings.globalize_path("res://tools/landing_preview.png")
	print("SHOT_OK ", img.save_png(path), " ", img.get_width(), "x", img.get_height())
	quit(0)
