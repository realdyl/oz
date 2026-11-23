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

## Murder of 9 sculpted 3D black crows with multi-cycle continuous flapping wings & drifting feathers.
func crow_storm(host: Node3D, origin: Vector3, radius: float = 2.8) -> void:
	var root := _host_root(host)
	if root == null:
		return
	ring(host, origin, Color(0.95, 0.82, 0.25), radius * 0.85, 0.42)
	var crow_mat := StandardMaterial3D.new()
	crow_mat.albedo_color = Color(0.05, 0.05, 0.08)
	crow_mat.roughness = 0.42
	crow_mat.metallic = 0.22
	var beak_mat := StandardMaterial3D.new()
	beak_mat.albedo_color = Color(0.92, 0.72, 0.22)
	beak_mat.emission_enabled = true
	beak_mat.emission = Color(0.92, 0.72, 0.22)
	beak_mat.emission_energy_multiplier = 0.65
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.85, 0.25)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.85, 0.25)
	eye_mat.emission_energy_multiplier = 1.6

	for i in range(9):
		var ang := float(i) / 9.0 * TAU
		var crow := Node3D.new()
		root.add_child(crow)
		crow.global_position = origin + Vector3(cos(ang) * 0.35, 1.05 + float(i % 3) * 0.20, sin(ang) * 0.35)
		crow.rotation.y = -ang + PI * 0.5

		# Tapered sleek avian torso + head + golden eyes + hooked beak + fanned 3-feather tail
		var body_mi := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.095
		bm.height = 0.19
		body_mi.mesh = bm
		body_mi.scale = Vector3(0.82, 0.72, 1.68)
		body_mi.material_override = crow_mat
		crow.add_child(body_mi)

		var head_mi := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.062
		hm.height = 0.12
		head_mi.mesh = hm
		head_mi.position = Vector3(0, 0.045, -0.14)
		head_mi.material_override = crow_mat
		crow.add_child(head_mi)

		for ex in [-0.032, 0.032]:
			var emi := MeshInstance3D.new()
			var es := SphereMesh.new()
			es.radius = 0.014
			es.height = 0.028
			emi.mesh = es
			emi.position = Vector3(float(ex), 0.06, -0.185)
			emi.material_override = eye_mat
			crow.add_child(emi)

		var beak := MeshInstance3D.new()
		var bk := PrismMesh.new()
		bk.size = Vector3(0.04, 0.11, 0.04)
		beak.mesh = bk
		beak.position = Vector3(0, 0.03, -0.24)
		beak.rotation_degrees = Vector3(-96, 0, 0)
		beak.material_override = beak_mat
		crow.add_child(beak)

		for ti in [-1.0, 0.0, 1.0]:
			var tail := MeshInstance3D.new()
			var tm := PrismMesh.new()
			tm.size = Vector3(0.06, 0.22, 0.015)
			tail.mesh = tm
			tail.position = Vector3(float(ti) * 0.04, 0.0, 0.20)
			tail.rotation_degrees = Vector3(94, float(ti) * 18.0, 0)
			tail.material_override = crow_mat
			crow.add_child(tail)

		# Pivot-hinged 2-segment swept wings
		var w_piv_l := Node3D.new()
		var w_piv_r := Node3D.new()
		w_piv_l.position = Vector3(-0.06, 0.03, -0.02)
		w_piv_r.position = Vector3(0.06, 0.03, -0.02)
		crow.add_child(w_piv_l)
		crow.add_child(w_piv_r)

		for pair in [[w_piv_l, -1.0], [w_piv_r, 1.0]]:
			var piv: Node3D = pair[0] as Node3D
			var sgn: float = float(pair[1])
			var inner := MeshInstance3D.new()
			var iw := BoxMesh.new()
			iw.size = Vector3(0.24, 0.022, 0.14)
			inner.mesh = iw
			inner.position = Vector3(sgn * 0.12, 0, 0.01)
			inner.material_override = crow_mat
			piv.add_child(inner)
			var outer := MeshInstance3D.new()
			var ow := PrismMesh.new()
			ow.size = Vector3(0.14, 0.26, 0.018)
			outer.mesh = ow
			outer.position = Vector3(sgn * 0.34, 0, 0.03)
			outer.rotation_degrees = Vector3(0, 0, sgn * -90.0)
			outer.material_override = crow_mat
			piv.add_child(outer)

		var end_ang := ang + 1.85
		var end_pos := origin + Vector3(cos(end_ang) * (radius * 1.25), 2.3 + float(i % 3) * 0.45, sin(end_ang) * (radius * 1.25))
		var tw := host.get_tree().create_tween()
		tw.set_parallel(true)
		tw.tween_property(crow, "global_position", end_pos, 0.78).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(crow, "rotation:y", crow.rotation.y - 2.3, 0.78)
		tw.tween_property(crow, "scale", Vector3(0.05, 0.05, 0.05), 0.22).set_delay(0.56)
		tw.chain().tween_callback(crow.queue_free)

		# Continuous 4-flap wing cycle tween
		var ftw := host.get_tree().create_tween()
		for _flap in range(4):
			ftw.tween_property(w_piv_l, "rotation_degrees:z", 44.0, 0.09)
			ftw.parallel().tween_property(w_piv_r, "rotation_degrees:z", -44.0, 0.09)
			ftw.tween_property(w_piv_l, "rotation_degrees:z", -34.0, 0.09)
			ftw.parallel().tween_property(w_piv_r, "rotation_degrees:z", 34.0, 0.09)

## Toto's Sonic Bark Wave — golden-turquoise expanding bark rings + scent-trail spark.
func bark_wave(host: Node3D, origin: Vector3, forward: Vector3) -> void:
	var root := _host_root(host)
	if root == null:
		return
	ring(host, origin, Color(0.35, 0.92, 0.98), 2.8, 0.42)
	ring(host, origin + Vector3(0, 0.25, 0), Color(1.0, 0.86, 0.36), 2.1, 0.34)
	label(host, origin + Vector3(0, 1.05, 0), "ARF! ARF!", Color(1.0, 0.92, 0.48))
	var f := forward
	f.y = 0.0
	if f.length() < 0.01:
		f = Vector3(0, 0, -1)
	f = f.normalized()
	for i in range(4):
		var mote := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.18
		mote.mesh = sm
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.45, 0.96, 1.0, 0.9)
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.emission_enabled = true
		mm.emission = Color(0.4, 0.95, 1.0)
		mm.emission_energy_multiplier = 2.4
		mote.material_override = mm
		root.add_child(mote)
		mote.global_position = origin + Vector3(0, 0.38, 0) + f * 0.35
		var tw := host.get_tree().create_tween()
		tw.set_parallel(true)
		tw.tween_property(mote, "global_position", mote.global_position + f * (2.6 + float(i) * 0.6) + Vector3((float(i) - 1.5) * 0.55, 0.4, 0), 0.42)
		tw.tween_property(mm, "albedo_color:a", 0.0, 0.42)
		tw.chain().tween_callback(mote.queue_free)

## Dramatic water splash + steam plumes + bubbling obsidian-crimson puddle + leftover gothic hat.
func water_splash_and_melt(host: Node3D, from_pos: Vector3, target_pos: Vector3) -> void:
	var root := _host_root(host)
	if root == null:
		return
	# 1) Glistening water splash droplets arcing from Lead to Witch
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.35, 0.80, 1.0, 0.92)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.emission_enabled = true
	wmat.emission = Color(0.35, 0.80, 1.0)
	wmat.emission_energy_multiplier = 2.2
	for i in range(10):
		var drop := MeshInstance3D.new()
		var ds := SphereMesh.new()
		ds.radius = 0.12 + float(i % 3) * 0.04
		ds.height = ds.radius * 2.0
		drop.mesh = ds
		drop.material_override = wmat
		root.add_child(drop)
		drop.global_position = from_pos + Vector3(0, 1.0, 0)
		var mid := from_pos.lerp(target_pos, 0.5) + Vector3((float(i % 5) - 2.0) * 0.32, 2.2 + float(i % 3) * 0.3, (float(i / 5) - 0.5) * 0.4)
		var dest := target_pos + Vector3((float(i % 4) - 1.5) * 0.45, 0.4 + float(i % 3) * 0.4, (float(i % 3) - 1.0) * 0.45)
		var tw := host.get_tree().create_tween()
		tw.tween_property(drop, "global_position", mid, 0.22).set_delay(float(i) * 0.025)
		tw.tween_property(drop, "global_position", dest, 0.25)
		tw.tween_callback(drop.queue_free)

	# 2) Billowing steam & dark-magic smoke plumes rising from the melting Witch
	for si in range(12):
		var puff := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 0.32
		ps.height = 0.64
		puff.mesh = ps
		var pm := StandardMaterial3D.new()
		var is_steam := si % 2 == 0
		pm.albedo_color = Color(0.88, 0.94, 1.0, 0.65) if is_steam else Color(0.28, 0.08, 0.16, 0.72)
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.emission_enabled = true
		pm.emission = Color(0.65, 0.88, 1.0) if is_steam else Color(0.55, 0.10, 0.18)
		pm.emission_energy_multiplier = 0.9
		puff.material_override = pm
		root.add_child(puff)
		var ang := float(si) / 12.0 * TAU
		puff.global_position = target_pos + Vector3(cos(ang) * 0.45, 0.35, sin(ang) * 0.45)
		var stw := host.get_tree().create_tween()
		stw.set_parallel(true)
		stw.tween_property(puff, "global_position", puff.global_position + Vector3(cos(ang) * 1.1, 3.2 + float(si % 3) * 0.7, sin(ang) * 1.1), 1.6).set_delay(0.25 + float(si) * 0.08)
		stw.tween_property(puff, "scale", Vector3.ONE * 2.8, 1.6).set_delay(0.25 + float(si) * 0.08)
		stw.tween_property(pm, "albedo_color:a", 0.0, 1.6).set_delay(0.25 + float(si) * 0.08)
		stw.chain().tween_callback(puff.queue_free)

	# 3) Persistent steaming obsidian-crimson puddle + leftover gothic pointed hat on the flagstones!
	var puddle_root := Node3D.new()
	puddle_root.name = "MeltedWitchRemains"
	root.add_child(puddle_root)
	puddle_root.global_position = Vector3(target_pos.x, 0.07, target_pos.z)
	var pud := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 1.65
	pc.bottom_radius = 1.75
	pc.height = 0.04
	pud.mesh = pc
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.14, 0.04, 0.09, 0.92)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.roughness = 0.12
	pmat.metallic = 0.35
	pmat.emission_enabled = true
	pmat.emission = Color(0.45, 0.08, 0.18)
	pmat.emission_energy_multiplier = 0.65
	pud.material_override = pmat
	pud.scale = Vector3(0.1, 1.0, 0.1)
	puddle_root.add_child(pud)

	# Leftover buckled gothic hat resting atop the puddle
	var hat_root := Node3D.new()
	hat_root.position = Vector3(0.0, 0.08, 0.0)
	hat_root.rotation_degrees = Vector3(12, 24, -14)
	hat_root.scale = Vector3(0.05, 0.05, 0.05)
	puddle_root.add_child(hat_root)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.07, 0.05, 0.09)
	hmat.roughness = 0.45
	var brim := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.46
	bc.bottom_radius = 0.48
	bc.height = 0.04
	brim.mesh = bc
	brim.material_override = hmat
	hat_root.add_child(brim)
	var spire := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.025
	sc.bottom_radius = 0.17
	sc.height = 0.52
	spire.mesh = sc
	spire.position = Vector3(0.04, 0.26, 0.04)
	spire.rotation_degrees = Vector3(-14, 0, 14)
	spire.material_override = hmat
	hat_root.add_child(spire)

	var ptw := host.get_tree().create_tween()
	ptw.set_parallel(true)
	ptw.tween_property(pud, "scale", Vector3(1.15, 1.0, 1.15), 1.9).set_delay(0.25)
	ptw.tween_property(hat_root, "scale", Vector3.ONE, 0.6).set_delay(1.4)

## Spawns gently rising animated "Zzz" slumber letters above a sleeping character.
func spawn_sleep_zzz(host: Node3D, pos: Vector3) -> void:
	var root := _host_root(host)
	if root == null:
		return
	var lab := Label3D.new()
	lab.text = "Z" if randi() % 2 == 0 else "z"
	lab.font_size = 38
	lab.pixel_size = 0.0065
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.shaded = false
	lab.modulate = Color(0.88, 0.94, 1.0, 0.95)
	lab.outline_size = 6
	lab.outline_modulate = Color(0.14, 0.10, 0.24, 0.9)
	root.add_child(lab)
	lab.global_position = pos + Vector3(randf_range(-0.25, 0.25), 0.55, randf_range(-0.25, 0.25))
	var tw := host.get_tree().create_tween()
	tw.set_parallel(true)
	tw.tween_property(lab, "global_position", lab.global_position + Vector3(randf_range(-0.35, 0.35), 1.35, randf_range(-0.25, 0.25)), 1.55)
	tw.tween_property(lab, "modulate:a", 0.0, 1.55)
	tw.chain().tween_callback(lab.queue_free)

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
