extends Node3D

## Kansas Act 0 — B&W farmyard. Basket → Toto → shutter → cellar option → storm → Munchkinland.
## Vault: cannot fail out of story; debris only delays; F9 skip; F8 storm.

const MUNCHKIN_SCENE := "res://regions/munchkinland/landing_square.tscn"
const DEBRIS_SCENE := preload("res://regions/kansas/debris.tscn")

enum Phase { INTRO, NEED_BASKET, NEED_TOTO, NEED_SHUTTER, NEED_CELLAR, STORM, STRIKE, FADE }

@onready var hud: CanvasLayer = $PlayHUD
@onready var player: CharacterBody3D = $Player
@onready var basket: Area3D = $Basket
@onready var toto: CharacterBody3D = $Toto
@onready var world_env: WorldEnvironment = $WorldEnvironment

var fade: ColorRect
var compass: Label
var phase: Phase = Phase.INTRO
var _storm_time: float = 0.0
var _spawn_cd: float = 0.0
var _safe_pos: Vector3
var _fade_t: float = 0.0
var _striking: bool = false
var _marker: MeshInstance3D
var shutter: Area3D
var cellar: Area3D
var barn: Node3D
var shutter_done: bool = false
var cellar_touched: bool = false
var _near_shutter: bool = false
var _near_cellar: bool = false
var wind_t: float = 0.0

func _ready() -> void:
	hud.add_to_group("hud")
	fade = hud.get_node_or_null("Fade") as ColorRect
	if fade == null:
		fade = ColorRect.new()
		fade.name = "Fade"
		fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.z_index = 20
		hud.add_child(fade)
	_ensure_compass()
	_stabilize_lighting()
	_build_farm_layout()
	basket.global_position = player.global_position + Vector3(-2.5, 0.05, -3.0)
	toto.global_position = player.global_position + Vector3(8.0, 0.05, -10.0)
	_spawn_basket_marker()
	hud.set_objective("Grey Kansas. Find the basket — tall glowing post by the path.")
	if hud.has_method("set_kansas_mode"):
		hud.set_kansas_mode(true)
	basket.taken.connect(_on_basket_taken)
	toto.joined.connect(_on_toto_joined)
	_safe_pos = player.global_position
	fade.color = Color(0, 0, 0, 0)
	fade.visible = true
	phase = Phase.NEED_BASKET
	_fade_t = -1.0
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("on_level_start"):
		lt.on_level_start("Kansas · the farmyard")

func _stabilize_lighting() -> void:
	# Recent pad/barn mesh spam + scaled Ground made shadow maps swim while walking.
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.shadow_enabled = true
		sun.shadow_bias = 0.1
		sun.shadow_normal_bias = 3.0
		sun.shadow_blur = 2.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 40.0
		sun.light_angular_distance = 1.5
	# Don't cast from huge scaled ground / every prop — biggest flicker source.
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var path := str(mi.get_path())
		if path.contains("Ground") or path.contains("Dirt") or path.contains("pad") or path.contains("Pad"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if player:
		for n in player.find_children("*", "MeshInstance3D", true, false):
			var mi2 := n as MeshInstance3D
			if mi2:
				mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_farm_layout() -> void:
	# Extra ground pads — never scale the main Ground collider.
	_add_ground_pad(Vector3(0, -0.05, -20), Vector3(60, 0.1, 40))
	_add_ground_pad(Vector3(20, -0.05, 10), Vector3(40, 0.1, 40))
	_add_barn(player.global_position + Vector3(-14, 0, 6))
	_add_fence_ring(player.global_position, 16.0, 18)
	_add_house_shutter(player.global_position + Vector3(4.5, 0, 2.0))
	_add_cellar_door(player.global_position + Vector3(-3.0, 0, 5.5))
	_add_clothesline(player.global_position + Vector3(6, 0, -4))
	_add_windmill_ghost(player.global_position + Vector3(-20, 0, -8))
	_add_map_border(28.0, 28.0)

func _add_map_border(half_x: float, half_z: float) -> void:
	# Grey Kansas edge — solid rails + dead trees so the farm doesn't drop into void.
	var h := 2.8
	var thick := 2.0
	var col := Color(0.28, 0.28, 0.3)
	var specs := [
		{"pos": Vector3(0, h * 0.5, -half_z), "size": Vector3(half_x * 2.0 + thick * 2.0, h, thick)},
		{"pos": Vector3(0, h * 0.5, half_z), "size": Vector3(half_x * 2.0 + thick * 2.0, h, thick)},
		{"pos": Vector3(-half_x, h * 0.5, 0), "size": Vector3(thick, h, half_z * 2.0)},
		{"pos": Vector3(half_x, h * 0.5, 0), "size": Vector3(thick, h, half_z * 2.0)},
	]
	for s in specs:
		var body := StaticBody3D.new()
		body.name = "MapBorder"
		add_child(body)
		body.global_position = s["pos"]
		body.collision_layer = 1
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = s["size"]
		mi.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 0.95
		mi.material_override = mat
		body.add_child(mi)
		var c := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = s["size"]
		c.shape = sh
		body.add_child(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 191
	for i in 36:
		var t := float(i) / 36.0 * TAU
		var p := Vector3(
			cos(t) * (half_x - 1.2 + rng.randf_range(-0.4, 0.4)),
			0.0,
			sin(t) * (half_z - 1.2 + rng.randf_range(-0.4, 0.4))
		)
		var tree := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		var th := rng.randf_range(1.4, 2.4)
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.14
		cyl.height = th
		tree.mesh = cyl
		var tm := StandardMaterial3D.new()
		tm.albedo_color = Color(0.32, 0.32, 0.34)
		tree.material_override = tm
		add_child(tree)
		tree.global_position = p + Vector3(0, th * 0.5, 0)
		var canopy := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = rng.randf_range(0.7, 1.2)
		sph.height = sph.radius * 1.5
		canopy.mesh = sph
		var cm := StandardMaterial3D.new()
		cm.albedo_color = Color(0.35, 0.35, 0.38)
		canopy.material_override = cm
		add_child(canopy)
		canopy.global_position = p + Vector3(0, th + 0.5, 0)

func _add_ground_pad(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.global_position = at
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.42, 0.45)
	mat.roughness = 0.95
	mi.material_override = mat
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	body.add_child(col)

func _add_barn(at: Vector3) -> void:
	barn = StaticBody3D.new()
	barn.name = "Barn"
	add_child(barn)
	barn.global_position = at
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6.0, 4.0, 5.0)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.38)
	mi.material_override = mat
	barn.add_child(mi)
	mi.position = Vector3(0, 2.0, 0)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(6.0, 4.0, 5.0)
	col.shape = sh
	col.position = Vector3(0, 2.0, 0)
	barn.add_child(col)
	var roof := MeshInstance3D.new()
	var r := BoxMesh.new()
	r.size = Vector3(6.8, 0.3, 5.6)
	roof.mesh = r
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.22, 0.22, 0.25)
	roof.material_override = rm
	barn.add_child(roof)
	roof.position = Vector3(0, 4.2, 0)

func _add_fence_ring(center: Vector3, radius: float, posts: int) -> void:
	for i in posts:
		var ang := float(i) / float(posts) * TAU
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.07
		cyl.height = 1.0
		post.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.4, 0.42)
		post.material_override = mat
		add_child(post)
		post.global_position = center + Vector3(cos(ang) * radius, 0.5, sin(ang) * radius)

func _add_house_shutter(at: Vector3) -> void:
	shutter = Area3D.new()
	shutter.name = "Shutter"
	shutter.collision_layer = 0
	shutter.collision_mask = 2
	shutter.monitoring = true
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.5
	col.shape = sph
	shutter.add_child(col)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 1.4, 0.15)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.52)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.7, 0.75)
	mat.emission_energy_multiplier = 0.6
	mi.material_override = mat
	shutter.add_child(mi)
	mi.position = Vector3(0, 0.9, 0)
	add_child(shutter)
	shutter.global_position = at
	shutter.body_entered.connect(func(b): if b.is_in_group("player"): _near_shutter = true)
	shutter.body_exited.connect(func(b): if b.is_in_group("player"): _near_shutter = false)

func _add_cellar_door(at: Vector3) -> void:
	cellar = Area3D.new()
	cellar.name = "Cellar"
	cellar.collision_layer = 0
	cellar.collision_mask = 2
	cellar.monitoring = true
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.4
	col.shape = sph
	cellar.add_child(col)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 0.12, 1.2)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.28)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.4, 0.45)
	mat.emission_energy_multiplier = 0.5
	mi.material_override = mat
	cellar.add_child(mi)
	add_child(cellar)
	cellar.global_position = at
	cellar.body_entered.connect(func(b): if b.is_in_group("player"): _near_cellar = true)
	cellar.body_exited.connect(func(b): if b.is_in_group("player"): _near_cellar = false)

func _add_clothesline(at: Vector3) -> void:
	for i in 5:
		var cloth := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.6, 0.8, 0.05)
		cloth.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.65 + float(i) * 0.02, 0.65, 0.68)
		cloth.material_override = mat
		add_child(cloth)
		cloth.global_position = at + Vector3(float(i) * 0.7, 1.2, 0)
		cloth.set_meta("wind", true)

func _add_windmill_ghost(at: Vector3) -> void:
	var tower := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.7
	cyl.height = 8.0
	tower.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.33)
	tower.material_override = mat
	add_child(tower)
	tower.global_position = at + Vector3(0, 4.0, 0)
	var blade := MeshInstance3D.new()
	blade.name = "WindBlade"
	var box := BoxMesh.new()
	box.size = Vector3(6.0, 0.15, 0.4)
	blade.mesh = box
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.45, 0.45, 0.48)
	blade.material_override = bm
	add_child(blade)
	blade.global_position = at + Vector3(0, 7.5, 0)
	blade.set_meta("spin", true)

func _ensure_compass() -> void:
	compass = hud.get_node_or_null("Compass") as Label
	if compass == null:
		compass = Label.new()
		compass.name = "Compass"
		compass.position = Vector2(16, 96)
		compass.add_theme_font_size_override("font_size", 18)
		compass.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
		hud.add_child(compass)

func _spawn_basket_marker() -> void:
	_marker = MeshInstance3D.new()
	_marker.name = "BasketMarker"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.12
	cyl.height = 2.4
	_marker.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.9, 1.0)
	mat.emission_energy_multiplier = 1.4
	_marker.material_override = mat
	add_child(_marker)
	_marker.global_position = basket.global_position + Vector3(0, 1.2, 0)
	var col := basket.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col and col.shape is SphereShape3D:
		(col.shape as SphereShape3D).radius = 1.4

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			_skip_to_munchkin()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F8:
			if not player.has_basket:
				basket.take()
			if not player.has_toto:
				toto._join(player)
			shutter_done = true
			cellar_touched = true
			phase = Phase.STORM
			_storm_time = 0.0
			_spawn_cd = 0.2
			hud.set_objective("Storm (debug). Stay upright.")
			get_viewport().set_input_as_handled()

func _skip_to_munchkin() -> void:
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("go_to"):
		lt.go_to(MUNCHKIN_SCENE, "The hourglass turns…", "Munchkinland · the landing")
	else:
		get_tree().change_scene_to_file(MUNCHKIN_SCENE)

func _process(delta: float) -> void:
	_update_compass()
	_wind_props(delta)
	if Input.is_action_just_pressed("interact"):
		if _near_shutter and phase == Phase.NEED_SHUTTER and not shutter_done:
			_close_shutter()
		elif _near_cellar and phase == Phase.NEED_CELLAR and not cellar_touched:
			_touch_cellar()

	if _fade_t < 0.0:
		_fade_t = minf(_fade_t + delta * 0.7, 0.0)
		fade.color = Color(0, 0, 0, clampf(-_fade_t, 0.0, 1.0))
		return

	if phase == Phase.STORM:
		_storm_time += delta
		_spawn_cd -= delta
		if _spawn_cd <= 0.0:
			_spawn_cd = maxf(0.45, 0.95 - _storm_time * 0.03)
			_spawn_debris(false)
		# Wind lean on camera
		if world_env and world_env.environment:
			world_env.environment.adjustment_brightness = 0.72 - minf(_storm_time, 10.0) * 0.02
		if _storm_time > 14.0 and not _striking:
			_begin_final_strike()

	if phase == Phase.FADE:
		_fade_t += delta * 0.55
		fade.color = Color(1, 1, 1, clampf(_fade_t, 0.0, 1.0))
		if _fade_t >= 1.05:
			phase = Phase.STRIKE # freeze fade loop
			var lt2 := get_node_or_null("/root/LevelTransition")
			if lt2 and lt2.has_method("go_to"):
				lt2.go_to(MUNCHKIN_SCENE, "The house lands — the hourglass turns…", "Munchkinland · color returns")
			else:
				get_tree().change_scene_to_file(MUNCHKIN_SCENE)

	if _near_shutter and phase == Phase.NEED_SHUTTER:
		hud.set_prompt("E  —  Latch the farmhouse shutter")
	elif _near_cellar and phase == Phase.NEED_CELLAR:
		hud.set_prompt("E  —  Check the cellar (Aunt Em's voice)")

func _wind_props(delta: float) -> void:
	wind_t += delta
	for n in get_children():
		if n is MeshInstance3D and n.has_meta("wind"):
			(n as MeshInstance3D).rotation.z = sin(wind_t * 2.2 + n.position.x) * 0.15
		if n is MeshInstance3D and n.has_meta("spin"):
			(n as MeshInstance3D).rotate_z(delta * (1.2 + (2.5 if phase == Phase.STORM else 0.0)))

func _update_compass() -> void:
	if compass == null or player == null:
		return
	var target: Node3D = null
	var label := ""
	match phase:
		Phase.NEED_BASKET:
			if basket and not basket.claimed:
				target = basket
				label = "Basket"
		Phase.NEED_TOTO:
			if toto and not toto.joined_basket:
				target = toto
				label = "Toto"
		Phase.NEED_SHUTTER:
			target = shutter
			label = "Shutter"
		Phase.NEED_CELLAR:
			target = cellar
			label = "Cellar"
		_:
			compass.text = "F9 → Munchkinland   ·   F8 force storm"
			return
	if target == null:
		compass.text = ""
		return
	var to: Vector3 = target.global_position - player.global_position
	to.y = 0.0
	var dist := to.length()
	var cam: Node3D = player.get_node_or_null("CameraPivot")
	var forward := Vector3(0, 0, -1)
	if cam:
		forward = -cam.global_transform.basis.z
		forward.y = 0.0
		if forward.length() > 0.01:
			forward = forward.normalized()
	var right := Vector3.UP.cross(forward)
	var local := Vector2(to.dot(right), to.dot(forward))
	var ang := rad_to_deg(atan2(local.x, local.y))
	var dir := "ahead"
	if ang > 30.0 and ang < 150.0:
		dir = "right"
	elif ang < -30.0 and ang > -150.0:
		dir = "left"
	elif absf(ang) >= 150.0:
		dir = "behind"
	compass.text = "%s is %s (%.0fm)  ·  F9 skip" % [label, dir, dist]

func _on_basket_taken() -> void:
	phase = Phase.NEED_TOTO
	hud.set_objective("Toto is loose in the yard — compass to him before the wind rises.")
	_safe_pos = player.global_position
	_retarget_marker(toto.global_position + Vector3(0, 1.0, 0))

func _on_toto_joined() -> void:
	phase = Phase.NEED_SHUTTER
	hud.set_objective("Aunt Em shouts from the house — latch the glowing shutter.")
	_safe_pos = player.global_position
	if shutter:
		_retarget_marker(shutter.global_position + Vector3(0, 1.2, 0))

func _close_shutter() -> void:
	shutter_done = true
	if shutter:
		for c in shutter.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).rotation_degrees.y = 75.0
	hud.set_prompt("Shutter latched.")
	phase = Phase.NEED_CELLAR
	hud.set_objective("The cellar door — one last look (E). Storm is coming either way.")
	if cellar:
		_retarget_marker(cellar.global_position + Vector3(0, 0.6, 0))

func _touch_cellar() -> void:
	cellar_touched = true
	hud.set_prompt("\"Dorothy! Down here!\" — too late. The sky opens.")
	phase = Phase.STORM
	_storm_time = 0.0
	_spawn_cd = 0.35
	hud.set_objective("Tornado weather. Debris only slows you — keep Toto, stay standing.")
	_safe_pos = player.global_position
	if _marker:
		_marker.queue_free()
		_marker = null
	if world_env and world_env.environment:
		world_env.environment.adjustment_brightness = 0.7

func _retarget_marker(at: Vector3) -> void:
	if _marker == null:
		_marker = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.1
		cyl.height = 1.8
		_marker.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.8, 0.85)
		mat.emission_enabled = true
		mat.emission = Color(1, 1, 1)
		mat.emission_energy_multiplier = 1.2
		_marker.material_override = mat
		add_child(_marker)
	_marker.global_position = at

func _spawn_debris(final_piece: bool) -> void:
	var d: Area3D = DEBRIS_SCENE.instantiate()
	add_child(d)
	var angle := randf() * TAU
	var radius := 18.0 if not final_piece else 22.0
	var from := player.global_position + Vector3(cos(angle) * radius, 1.2 if not final_piece else 2.4, sin(angle) * radius)
	var toward := player.global_position + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
	if d.has_method("launch"):
		d.launch(from, toward, final_piece)
	d.soft_hit_player.connect(_on_soft_debris)
	d.final_hit_player.connect(_on_final_debris)
	if final_piece:
		d.speed = 11.0
		d.scale = Vector3(2.4, 2.4, 2.4)

func _on_soft_debris() -> void:
	if player.global_position.distance_to(_safe_pos) > 12.0:
		player.global_position = _safe_pos + Vector3(0, 0.1, 0)
	hud.set_prompt("Debris! Keep moving — you cannot fail this storm.")
	get_tree().create_timer(1.2).timeout.connect(func(): hud.set_prompt(""))

func _begin_final_strike() -> void:
	_striking = true
	phase = Phase.STRIKE
	hud.set_objective("Something huge is coming —")
	_spawn_debris(true)

func _on_final_debris() -> void:
	if phase == Phase.FADE:
		return
	phase = Phase.FADE
	_fade_t = 0.0
	if player.has_method("lock_input"):
		player.lock_input()
	hud.set_objective("")
	hud.set_prompt("")
