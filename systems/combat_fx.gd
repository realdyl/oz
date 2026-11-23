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

## Curved 3D silver stiletto heel-slash crescent + sparkling starlight burst.
func kick_arc(host: Node3D, origin: Vector3, forward: Vector3) -> void:
	var root := _host_root(host)
	if root == null:
		return
	var f := forward
	f.y = 0.0
	if f.length() < 0.01:
		f = Vector3(0, 0, -1)
	f = f.normalized()
	var holder := Node3D.new()
	root.add_child(holder)
	holder.global_position = origin + Vector3(0, 0.85, 0) + f * 0.45
	holder.look_at(holder.global_position + f, Vector3.UP)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.96, 1.0, 0.88)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.85, 0.92, 1.0)
	mat.emission_energy_multiplier = 2.6

	var arc := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.62
	tor.outer_radius = 0.88
	tor.rings = 16
	arc.mesh = tor
	arc.material_override = mat
	arc.scale = Vector3(1.0, 0.28, 1.15)
	arc.rotation_degrees = Vector3(12, 0, -24)
	holder.add_child(arc)

	# 5 sparkling starlight motes flying along the kick trajectory
	for i in range(5):
		var sp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.065
		sm.height = 0.13
		sp.mesh = sm
		sp.material_override = mat
		sp.position = Vector3((float(i) - 2.0) * 0.28, (float(i % 2) - 0.5) * 0.25, -0.55 - float(i) * 0.08)
		holder.add_child(sp)

	var tw := host.get_tree().create_tween()
	tw.set_parallel(true)
	tw.tween_property(holder, "scale", Vector3(1.55, 1.35, 1.55), 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_property(arc, "rotation_degrees:y", 110.0, 0.22)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.24)
	tw.chain().tween_callback(holder.queue_free)

## Murder of 8 articulated 3D black crows with animated flapping wings spiraling outward.
func crow_storm(host: Node3D, origin: Vector3, radius: float = 2.8) -> void:
	var root := _host_root(host)
	if root == null:
		return
	ring(host, origin, Color(0.95, 0.82, 0.25), radius * 0.85, 0.42)
	var crow_mat := StandardMaterial3D.new()
	crow_mat.albedo_color = Color(0.06, 0.05, 0.08)
	crow_mat.roughness = 0.55
	var beak_mat := StandardMaterial3D.new()
	beak_mat.albedo_color = Color(0.92, 0.72, 0.22)
	beak_mat.emission_enabled = true
	beak_mat.emission = Color(0.92, 0.72, 0.22)
	beak_mat.emission_energy_multiplier = 0.7

	for i in range(8):
		var ang := float(i) / 8.0 * TAU
		var crow := Node3D.new()
		root.add_child(crow)
		crow.global_position = origin + Vector3(cos(ang) * 0.4, 1.05 + float(i % 3) * 0.18, sin(ang) * 0.4)
		crow.rotation.y = -ang + PI * 0.5

		var body_mi := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.10
		bm.height = 0.20
		body_mi.mesh = bm
		body_mi.scale = Vector3(0.85, 0.75, 1.55)
		body_mi.material_override = crow_mat
		crow.add_child(body_mi)

		var beak := MeshInstance3D.new()
		var bk := PrismMesh.new()
		bk.size = Vector3(0.05, 0.10, 0.05)
		beak.mesh = bk
		beak.position = Vector3(0, 0.02, -0.17)
		beak.rotation_degrees = Vector3(-90, 0, 0)
		beak.material_override = beak_mat
		crow.add_child(beak)

		var wing_l := MeshInstance3D.new()
		var wing_r := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.32, 0.025, 0.14)
		wing_l.mesh = wm
		wing_r.mesh = wm
		wing_l.material_override = crow_mat
		wing_r.material_override = crow_mat
		wing_l.position = Vector3(-0.18, 0.03, 0)
		wing_r.position = Vector3(0.18, 0.03, 0)
		crow.add_child(wing_l)
		crow.add_child(wing_r)

		var end_ang := ang + 1.65
		var end_pos := origin + Vector3(cos(end_ang) * (radius * 1.15), 2.1 + float(i % 3) * 0.4, sin(end_ang) * (radius * 1.15))
		var tw := host.get_tree().create_tween()
		tw.set_parallel(true)
		tw.tween_property(crow, "global_position", end_pos, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(crow, "rotation:y", crow.rotation.y - 2.1, 0.65)
		tw.tween_property(wing_l, "rotation_degrees:z", 48.0, 0.15)
		tw.tween_property(wing_r, "rotation_degrees:z", -48.0, 0.15)
		tw.tween_property(crow, "scale", Vector3(0.05, 0.05, 0.05), 0.20).set_delay(0.45)
		tw.chain().tween_callback(crow.queue_free)

## Concentric golden sonic shockwave pressure rings + radial dust blast for Lion's Roar.
func roar_shockwave(host: Node3D, origin: Vector3, forward: Vector3, radius: float = 3.2) -> void:
	var root := _host_root(host)
	if root == null:
		return
	ring(host, origin, Color(1.0, 0.68, 0.22), radius * 0.65, 0.30)
	ring(host, origin + Vector3(0, 0.35, 0), Color(1.0, 0.45, 0.12), radius * 1.15, 0.48)

	var f := forward
	f.y = 0.0
	if f.length() < 0.01:
		f = Vector3(0, 0, -1)
	f = f.normalized()

	for k in range(3):
		var wave := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.28 + float(k) * 0.18
		tor.outer_radius = 0.42 + float(k) * 0.20
		wave.mesh = tor
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(1.0, 0.78 - float(k) * 0.14, 0.24, 0.85)
		wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wmat.emission_enabled = true
		wmat.emission = Color(1.0, 0.62, 0.18)
		wmat.emission_energy_multiplier = 2.4
		wave.material_override = wmat
		root.add_child(wave)
		wave.global_position = origin + Vector3(0, 0.95, 0) + f * (0.45 + float(k) * 0.25)
		wave.look_at(wave.global_position + f, Vector3.UP)

		var tw := host.get_tree().create_tween()
		tw.set_parallel(true)
		tw.tween_property(wave, "global_position", origin + Vector3(0, 1.05, 0) + f * (radius * (0.75 + float(k) * 0.22)), 0.38).set_ease(Tween.EASE_OUT)
		tw.tween_property(wave, "scale", Vector3.ONE * (2.2 + float(k) * 0.55), 0.38)
		tw.tween_property(wmat, "albedo_color:a", 0.0, 0.40)
		tw.chain().tween_callback(wave.queue_free)

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
