extends Node

## Autoload CombatFx — readable kit VFX (arcs, bursts, floating labels).

func _host_root(host: Node) -> Node:
	if host == null or not is_instance_valid(host):
		return null
	var tree := host.get_tree()
	if tree == null:
		return null
	if tree.current_scene:
		return tree.current_scene
	return tree.root

func flash_sphere(host: Node3D, pos: Vector3, color: Color, radius: float = 0.55, life: float = 0.18) -> void:
	var root := _host_root(host)
	if root == null:
		return
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	mi.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.2
	mi.material_override = mat
	root.add_child(mi)
	mi.global_position = pos
	var tw := host.get_tree().create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.6, life)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, life)
	tw.tween_callback(mi.queue_free)

func slash_box(host: Node3D, origin: Vector3, forward: Vector3, color: Color, size := Vector3(0.9, 0.2, 1.1), life: float = 0.14) -> void:
	var root := _host_root(host)
	if root == null:
		return
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.65)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.8
	mi.material_override = mat
	root.add_child(mi)
	var f := forward
	f.y = 0.0
	if f.length() < 0.01:
		f = Vector3(0, 0, -1)
	f = f.normalized()
	mi.global_position = origin + f * (size.z * 0.45) + Vector3(0, 0.55, 0)
	mi.look_at(mi.global_position + f, Vector3.UP)
	var tw := host.get_tree().create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, life)
	tw.tween_callback(mi.queue_free)

func ring(host: Node3D, pos: Vector3, color: Color, radius: float = 2.0, life: float = 0.35) -> void:
	var root := _host_root(host)
	if root == null:
		return
	var mi := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = radius * 0.85
	tor.outer_radius = radius
	mi.mesh = tor
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	root.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.15, 0)
	mi.rotation_degrees.x = 90.0
	var tw := host.get_tree().create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.35, life)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, life)
	tw.tween_callback(mi.queue_free)

func axe_arc(host: Node3D, origin: Vector3, forward: Vector3, color: Color = Color(0.75, 0.85, 0.95), life: float = 0.36) -> void:
	## Sweeping axe blade trail — reads as a swing, not a body flash.
	var root := _host_root(host)
	if root == null:
		return
	var f := forward
	f.y = 0.0
	if f.length() < 0.01:
		f = Vector3(0, 0, -1)
	f = f.normalized()
	var right := f.cross(Vector3.UP).normalized()
	# Start raised behind the shoulder, end low in front.
	var start := origin - f * 0.2 + right * 0.15 + Vector3(0, 0.85, 0)
	var end := origin + f * 1.45 - right * 0.1 + Vector3(0, -0.15, 0)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.08, 1.35)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.4
	mi.material_override = mat
	root.add_child(mi)
	mi.global_position = start
	mi.look_at(start + f, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, -0.9)
	var tw := host.get_tree().create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "global_position", end, life * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(mi, "rotation:x", mi.rotation.x + 1.6, life * 0.55)
	tw.chain().tween_property(mat, "albedo_color:a", 0.0, life * 0.45)
	tw.chain().tween_callback(mi.queue_free)
	# Thin secondary edge spark at contact plane.
	slash_box(host, origin + f * 0.2, f, color, Vector3(1.25, 0.1, 0.35), life * 0.4)

func label(host: Node3D, pos: Vector3, text: String, color: Color = Color.WHITE) -> void:
	var root := _host_root(host)
	if root == null:
		return
	var holder := Node3D.new()
	root.add_child(holder)
	holder.global_position = pos + Vector3(0, 1.4, 0)
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 48
	lab.modulate = color
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.outline_modulate = Color(0, 0, 0, 0.8)
	lab.outline_size = 8
	holder.add_child(lab)
	var tw := host.get_tree().create_tween()
	tw.tween_property(holder, "global_position:y", holder.global_position.y + 0.9, 0.55)
	tw.parallel().tween_property(lab, "modulate:a", 0.0, 0.55)
	tw.tween_callback(holder.queue_free)
