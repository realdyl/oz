extends Node3D

## Act 3 · Winkie Country — Witch of the West castle (vault [[Witch of the West]]).
## Dark iron/ember arena. Book-true water melt (Baum) as the finish window — not a film gag alone.
## Prototype spine: L3 after Munchkinland OPEN_ROAD. F9 → Emerald City.

const PLAYER_SCENE := preload("res://actors/dorothy/player.tscn")
const HUD_SCENE := preload("res://ui/play_hud.tscn")
const PUPPET_SCENE := preload("res://actors/enemies/puppet_munchkin.tscn")
const SCARECROW_SCENE := preload("res://actors/companions/scarecrow.tscn")
const LION_SCENE := preload("res://actors/companions/lion.tscn")
const TINMAN_SCENE := preload("res://actors/companions/tinman.tscn")
const EMERALD_SCENE := "res://regions/emerald_city/wizard_tower.tscn"

const PLAY_BOUND_X := 48.0
const PLAY_BOUND_Z := 44.0

enum Beat {
	ENTER,
	CLEAR_COURT,
	FACE_WEST,
	WATER_READY,
	MELTING,
	ROAD_OPEN,
}

var hud: CanvasLayer
var player: CharacterBody3D
var scarecrow: CharacterBody3D
var lion: CharacterBody3D
var tinman: CharacterBody3D
var west: CharacterBody3D
var cistern: Node3D
var bucket: Area3D
var beat: Beat = Beat.ENTER
var court_kills: int = 0
var court_need: int = 4
var west_hp: int = 120
var west_grounded: bool = false
var has_water: bool = false
var melt_done: bool = false
var _near_bucket: bool = false
var _near_west: bool = false
var _near_gate: bool = false
var compass: Label
var gate_pos: Vector3 = Vector3(0.0, 0.08, -38.0)

func _enter_tree() -> void:
	var p := get_node_or_null("/root/Party")
	if p and p.has_method("reset_party"):
		p.reset_party()

func _ready() -> void:
	_build_world()
	_spawn_party()
	_spawn_court_guards()
	_spawn_west()
	_spawn_cistern()
	_ensure_compass()
	if hud and hud.has_method("set_kansas_mode"):
		hud.set_kansas_mode(false)
	_set_beat(Beat.ENTER)
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("on_level_start"):
		lt.on_level_start("Winkie Country · the West castle")
	# Brief ENTER then court fight.
	await get_tree().create_timer(0.35).timeout
	if beat == Beat.ENTER:
		_set_beat(Beat.CLEAR_COURT)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			_go_emerald("The hourglass turns — Emerald City…")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F8:
			# Playtest: force water-ready + melt path.
			if not melt_done:
				west_grounded = true
				west_hp = mini(west_hp, 40)
				has_water = true
				_set_beat(Beat.WATER_READY)
				hud.set_prompt("F8 debug — water ready. E on the Witch to melt her.")
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if player == null:
		return
	_update_compass()
	var actor := _lead()
	if actor == null:
		return
	_near_bucket = bucket != null and bucket.monitoring and actor.global_position.distance_to(bucket.global_position) < 2.4
	_near_west = west != null and is_instance_valid(west) and not melt_done \
		and actor.global_position.distance_to(west.global_position) < 3.2
	_near_gate = beat == Beat.ROAD_OPEN and actor.global_position.distance_to(gate_pos) < 4.0
	if Input.is_action_just_pressed("interact"):
		if _near_bucket and not has_water and beat >= Beat.FACE_WEST:
			_take_water()
		elif _near_west and has_water and west_grounded and beat >= Beat.WATER_READY:
			_melt_west()
		elif _near_west and beat >= Beat.FACE_WEST and not has_water:
			hud.set_prompt("She reels — take water from the ruptured cistern (E), then douse her.")
		elif _near_gate:
			_go_emerald("West falls — the hourglass turns toward the Emerald City…")
	_update_prompt()

func _lead() -> CharacterBody3D:
	var party := get_node_or_null("/root/Party")
	if party and party.has_method("leader_body"):
		var b = party.call("leader_body")
		if b is CharacterBody3D:
			return b
	return player

func _build_world() -> void:
	# Dark iron ground
	_add_box(Vector3(0, -0.2, 0), Vector3(100, 0.4, 90), Color(0.12, 0.1, 0.11), "Ground")
	_add_box(Vector3(0, 0.02, 0), Vector3(36, 0.06, 28), Color(0.18, 0.14, 0.13), "Courtyard")
	# Outer walls — castle silhouette
	_add_box(Vector3(0, 4, -42), Vector3(52, 10, 3), Color(0.1, 0.08, 0.09), "WallN")
	_add_box(Vector3(0, 4, 42), Vector3(52, 10, 3), Color(0.1, 0.08, 0.09), "WallS")
	_add_box(Vector3(-48, 4, 0), Vector3(3, 10, 86), Color(0.1, 0.08, 0.09), "WallW")
	_add_box(Vector3(48, 4, 0), Vector3(3, 10, 86), Color(0.1, 0.08, 0.09), "WallE")
	# Keep towers
	for xz in [Vector3(-22, 0, -22), Vector3(22, 0, -22), Vector3(-22, 0, 18), Vector3(22, 0, 18)]:
		_add_box(xz + Vector3(0, 6, 0), Vector3(5, 12, 5), Color(0.14, 0.1, 0.11), "Tower")
		_add_box(xz + Vector3(0, 12.5, 0), Vector3(6, 1.2, 6), Color(0.08, 0.06, 0.07), "Battlement")
	# Gatehouse toward Emerald (north)
	_add_box(Vector3(0, 5, -36), Vector3(10, 10, 4), Color(0.16, 0.11, 0.1), "Gatehouse")
	var gate_lab := Label3D.new()
	gate_lab.text = "ROAD TO\nEMERALD CITY"
	gate_lab.font_size = 48
	gate_lab.pixel_size = 0.014
	gate_lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gate_lab.modulate = Color(0.3, 0.85, 0.45)
	gate_lab.outline_size = 8
	add_child(gate_lab)
	gate_lab.global_position = gate_pos + Vector3(0, 4.5, 0)
	# Ember braziers
	for i in 6:
		var a := float(i) / 6.0 * TAU
		_add_box(Vector3(cos(a) * 14.0, 0.6, sin(a) * 10.0), Vector3(0.6, 1.2, 0.6), Color(0.45, 0.12, 0.05), "Brazier")
	# Lighting — eerie
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(0.55, 0.45, 0.55)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-42, 30, 0)
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.7, 0.25, 0.12)
	fill.light_energy = 2.2
	fill.omni_range = 28.0
	add_child(fill)
	fill.global_position = Vector3(0, 6, 0)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.04, 0.03, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.18, 0.12, 0.16)
	e.ambient_light_energy = 0.55
	e.fog_enabled = true
	e.fog_light_color = Color(0.12, 0.08, 0.1)
	e.fog_density = 0.012
	env.environment = e
	add_child(env)
	# Map border rails
	_add_map_border(PLAY_BOUND_X + 4.0, PLAY_BOUND_Z + 4.0)
	# Title
	var title := Label3D.new()
	title.text = "WINKIE CASTLE\nWitch of the West"
	title.font_size = 64
	title.pixel_size = 0.016
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.modulate = Color(0.85, 0.35, 0.3)
	title.outline_size = 10
	add_child(title)
	title.global_position = Vector3(0, 8, -8)

func _add_map_border(half_x: float, half_z: float) -> void:
	var h := 3.5
	var thick := 2.2
	var col := Color(0.08, 0.12, 0.08)
	for s in [
		{"pos": Vector3(0, h * 0.5, -half_z), "size": Vector3(half_x * 2 + thick * 2, h, thick)},
		{"pos": Vector3(0, h * 0.5, half_z), "size": Vector3(half_x * 2 + thick * 2, h, thick)},
		{"pos": Vector3(-half_x, h * 0.5, 0), "size": Vector3(thick, h, half_z * 2)},
		{"pos": Vector3(half_x, h * 0.5, 0), "size": Vector3(thick, h, half_z * 2)},
	]:
		_add_box(s["pos"], s["size"], col, "MapBorder")

func _add_box(pos: Vector3, size: Vector3, color: Color, n: String) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.name = n
	add_child(body)
	body.global_position = pos
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if color.r > 0.35 and color.g < 0.2:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.8
	mi.material_override = mat
	body.add_child(mi)
	return mi

func _spawn_party() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 0.08, 16)
	if player.has_method("empower_shoes"):
		player.empower_shoes()
	# Full party free for Act 3 prototype (vault: all kits vs West).
	scarecrow = SCARECROW_SCENE.instantiate()
	add_child(scarecrow)
	scarecrow.global_position = Vector3(-2.5, 0.08, 18)
	if scarecrow.has_method("free_from_pole"):
		scarecrow.free_from_pole()
	lion = LION_SCENE.instantiate()
	add_child(lion)
	lion.global_position = Vector3(2.5, 0.08, 18)
	if lion.has_method("calm_and_join"):
		lion.calm_and_join()
	tinman = TINMAN_SCENE.instantiate()
	add_child(tinman)
	tinman.global_position = Vector3(0, 0.08, 19.5)
	if tinman.has_method("oil_and_free"):
		tinman.oil_and_free()
	var party := get_node_or_null("/root/Party")
	if party:
		if party.has_method("unlock"):
			for id in [&"scarecrow", &"lion", &"tinman"]:
				party.call("unlock", id)
		# Present flags via companion free methods usually; force if needed.
		if party.has_method("set_present"):
			for id in [&"dorothy", &"scarecrow", &"lion", &"tinman"]:
				party.call("set_present", id, true)

func _spawn_court_guards() -> void:
	var bearings := [0.4, 1.6, 3.0, 4.6]
	for i in bearings.size():
		var pup: CharacterBody3D = PUPPET_SCENE.instantiate()
		add_child(pup)
		pup.tint = Color(0.35, 0.32, 0.38)
		pup.set_meta("wave", "winkie")
		if pup.has_method("set_play_bounds"):
			pup.set_play_bounds(PLAY_BOUND_X, PLAY_BOUND_Z)
		var rally := Vector3(0, 0.08, 8)
		if pup.has_method("march_from_afar"):
			pup.march_from_afar(rally, bearings[i], 16.0 + float(i), 4.0 + float(i) * 0.8, 1.9)
		else:
			pup.global_position = rally + Vector3(sin(bearings[i]) * 14.0, 0.08, cos(bearings[i]) * 14.0)

func _spawn_west() -> void:
	west = CharacterBody3D.new()
	west.name = "WitchOfTheWest"
	west.set_script(preload("res://regions/winkie/west_witch_boss.gd"))
	west.collision_layer = 4
	west.collision_mask = 1
	add_child(west)
	west.global_position = Vector3(0, 0.08, -10)
	var hip := Node3D.new()
	west.add_child(hip)
	hip.position = Vector3(0, 1.2, 0)
	var robe := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.55
	cyl.height = 2.0
	robe.mesh = cyl
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.12, 0.08, 0.14)
	rm.emission_enabled = true
	rm.emission = Color(0.35, 0.05, 0.08)
	rm.emission_energy_multiplier = 0.9
	robe.material_override = rm
	hip.add_child(robe)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.44
	head.mesh = sph
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.55, 0.7, 0.45)
	head.material_override = hm
	hip.add_child(head)
	head.position = Vector3(0, 1.15, 0)
	var hat := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.01
	cone.bottom_radius = 0.4
	cone.height = 0.7
	hat.mesh = cone
	var hatm := StandardMaterial3D.new()
	hatm.albedo_color = Color(0.05, 0.04, 0.06)
	hat.material_override = hatm
	hip.add_child(hat)
	hat.position = Vector3(0, 1.6, 0)
	var lab := Label3D.new()
	lab.name = "WestLabel"
	lab.text = "WITCH OF THE WEST"
	lab.font_size = 52
	lab.pixel_size = 0.014
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(0.9, 0.35, 0.3)
	lab.outline_size = 10
	west.add_child(lab)
	lab.position = Vector3(0, 3.6, 0)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 2.0
	col.shape = cap
	col.position = Vector3(0, 1.1, 0)
	west.add_child(col)
	if west.has_method("setup"):
		west.call("setup", self)

func _spawn_cistern() -> void:
	cistern = Node3D.new()
	cistern.name = "Cistern"
	add_child(cistern)
	cistern.global_position = Vector3(-12, 0, 4)
	_add_box(cistern.global_position + Vector3(0, 0.4, 0), Vector3(3.5, 0.8, 3.5), Color(0.25, 0.28, 0.32), "CisternRim")
	var water := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 1.4
	wm.bottom_radius = 1.4
	wm.height = 0.25
	water.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.25, 0.45, 0.7, 0.85)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.emission_enabled = true
	wmat.emission = Color(0.2, 0.4, 0.7)
	wmat.emission_energy_multiplier = 0.5
	water.material_override = wmat
	cistern.add_child(water)
	water.position = Vector3(0, 0.35, 0)
	var lab := Label3D.new()
	lab.text = "RUPTURED CISTERN\n(water — her undoing)"
	lab.font_size = 36
	lab.pixel_size = 0.012
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(0.6, 0.8, 1.0)
	cistern.add_child(lab)
	lab.position = Vector3(0, 2.2, 0)
	bucket = Area3D.new()
	bucket.name = "WaterBucket"
	bucket.collision_layer = 0
	bucket.collision_mask = 2
	bucket.monitoring = true
	var bcol := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.0
	bcol.shape = sph
	bucket.add_child(bcol)
	cistern.add_child(bucket)
	bucket.position = Vector3(0, 0.5, 0)
	var blab := Label3D.new()
	blab.text = "WATER"
	blab.font_size = 40
	blab.pixel_size = 0.012
	blab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	blab.modulate = Color(0.5, 0.75, 1.0)
	bucket.add_child(blab)
	blab.position = Vector3(0, 1.2, 0)

func on_enemy_down(who: Node) -> void:
	if who == null:
		return
	if who.is_in_group("boss"):
		return
	var wave := str(who.get_meta("wave")) if who.has_meta("wave") else ""
	if wave == "winkie" and beat == Beat.CLEAR_COURT:
		court_kills += 1
		hud.set_objective("Winkie court — clear the guards. %d/%d" % [court_kills, court_need])
		if court_kills >= court_need or _count_winkie() <= 0:
			_set_beat(Beat.FACE_WEST)

func _count_winkie() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == null or not is_instance_valid(e):
			continue
		if e.is_in_group("enemies_dead") or e.is_in_group("boss"):
			continue
		var hp = e.get("health")
		if hp != null and int(hp) <= 0:
			continue
		if e.has_meta("wave") and str(e.get_meta("wave")) == "winkie":
			n += 1
	return n

func on_west_damaged(hp_left: int, grounded: bool) -> void:
	west_hp = hp_left
	west_grounded = grounded
	if melt_done:
		return
	if beat < Beat.FACE_WEST:
		_set_beat(Beat.FACE_WEST)
	if grounded and hp_left <= 45:
		_set_beat(Beat.WATER_READY)
	else:
		hud.set_objective("Witch of the West — break her smoke (Tin axe F). HP %d" % hp_left)

func _take_water() -> void:
	has_water = true
	if bucket:
		bucket.monitoring = false
	hud.set_prompt("Cistern water in hand — douse the Witch (E) while she is grounded.")
	hud.set_objective("Douse the grounded Witch with cistern water (E) — Baum's undoing.")
	if west_grounded:
		_set_beat(Beat.WATER_READY)

func _melt_west() -> void:
	if melt_done or west == null:
		return
	melt_done = true
	_set_beat(Beat.MELTING)
	hud.set_prompt("\"You cursed — wretched — girl…!\" — she melts.")
	if west.has_method("begin_melt"):
		west.call("begin_melt")
	else:
		west.queue_free()
	await get_tree().create_timer(2.2).timeout
	_set_beat(Beat.ROAD_OPEN)

func _go_emerald(msg: String) -> void:
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("go_to"):
		lt.go_to(EMERALD_SCENE, msg, "Emerald City · the Wizard's tower")
	else:
		get_tree().change_scene_to_file(EMERALD_SCENE)

func _set_beat(next: Beat) -> void:
	beat = next
	match beat:
		Beat.ENTER:
			hud.set_objective("Winkie Country — the West castle looms. Party is with you.")
			hud.set_prompt("Dark iron and ember. F9 → Emerald City (playtest)")
		Beat.CLEAR_COURT:
			hud.set_objective("Winkie court — clear the guards. %d/%d" % [court_kills, court_need])
			hud.set_prompt("F kits · Tab Lead · guards march from the walls")
		Beat.FACE_WEST:
			hud.set_objective("Witch of the West — Tin axe breaks smoke armor. HP %d" % west_hp)
			hud.set_prompt("She flies on storm-front · ground her, then water")
			if west and west.has_method("begin_fight"):
				west.call("begin_fight")
		Beat.WATER_READY:
			hud.set_objective("She is grounded — take cistern water (E) and douse her (E).")
			hud.set_prompt("Baum: water is her undoing — not a one-button cutscene alone")
		Beat.MELTING:
			hud.set_objective("The West melts…")
		Beat.ROAD_OPEN:
			hud.set_objective("West falls. North gate → Emerald City (walk or E at gate). F9 skip.")
			hud.set_prompt("Road to the Wizard opens")
			var lt := get_node_or_null("/root/LevelTransition")
			if lt and lt.has_method("play_exit"):
				lt.play_exit("The West melts — the hourglass turns…")

func _ensure_compass() -> void:
	compass = Label.new()
	compass.name = "LevelCompass"
	hud.add_child(compass)
	compass.set_anchors_preset(Control.PRESET_TOP_WIDE)
	compass.offset_top = 48.0
	compass.offset_bottom = 78.0
	compass.offset_left = 120.0
	compass.offset_right = -120.0
	compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass.add_theme_font_size_override("font_size", 18)
	compass.add_theme_color_override("font_color", Color(0.85, 0.7, 0.55))

func _update_compass() -> void:
	if compass == null:
		return
	var actor := _lead()
	if actor == null:
		compass.text = ""
		return
	var target := Vector3.ZERO
	var label := ""
	match beat:
		Beat.CLEAR_COURT:
			label = "Winkie guard"
			target = _nearest_enemy(actor)
		Beat.FACE_WEST, Beat.WATER_READY, Beat.MELTING:
			if west and is_instance_valid(west) and not melt_done:
				target = west.global_position
				label = "West"
			if beat == Beat.WATER_READY and not has_water:
				target = cistern.global_position if cistern else target
				label = "Cistern water"
		Beat.ROAD_OPEN:
			target = gate_pos
			label = "Emerald gate"
	if label == "" or target == Vector3.ZERO:
		compass.text = "F8 force water · F9 Emerald City"
		return
	var to := target - actor.global_position
	to.y = 0.0
	var dist := to.length()
	compass.text = "%s  ·  %.0fm   ·  F9 Emerald" % [label, dist]

func _nearest_enemy(from: Node3D) -> Vector3:
	var best := Vector3.ZERO
	var best_d := 1e9
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == null or not is_instance_valid(n) or n.is_in_group("boss"):
			continue
		if n.is_in_group("enemies_dead"):
			continue
		var d: float = from.global_position.distance_to((n as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = (n as Node3D).global_position
	return best

func _update_prompt() -> void:
	if beat == Beat.ROAD_OPEN and _near_gate:
		hud.set_prompt("E  —  Take the road to the Emerald City")
	elif _near_bucket and not has_water and beat >= Beat.FACE_WEST:
		hud.set_prompt("E  —  Draw water from the ruptured cistern")
	elif _near_west and has_water and west_grounded:
		hud.set_prompt("E  —  Douse the Witch of the West")
