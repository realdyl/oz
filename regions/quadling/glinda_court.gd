extends Node3D

## Act 5 · Quadling Country — Glinda's court & the Road Home (vault [[Q4 - Glinda & the Road Home]]).
## Book-true: Glinda = Good Witch of the South. Shoes were always the key home.
## Enter from Emerald City curtain choice. FINAL STEP = shoes choice → ending sting.

const PLAYER_SCENE := preload("res://actors/dorothy/player.tscn")
const HUD_SCENE := preload("res://ui/play_hud.tscn")
const SCARECROW_SCENE := preload("res://actors/companions/scarecrow.tscn")
const LION_SCENE := preload("res://actors/companions/lion.tscn")
const TINMAN_SCENE := preload("res://actors/companions/tinman.tscn")

const PLAY_BOUND_X := 42.0
const PLAY_BOUND_Z := 48.0
const YBR_SPAWN := Vector3(0.0, 0.08, 36.0)
const GLINDA_POS := Vector3(0.0, 0.08, -18.0)
const ROAD_HOME_PAD := Vector3(0.0, 0.08, -40.0)

enum Beat {
	APPROACH,
	MEET_GLINDA,
	REVEAL,
	CHOICE,
	DONE,
}

var hud: CanvasLayer
var player: CharacterBody3D
var scarecrow: CharacterBody3D
var lion: CharacterBody3D
var tinman: CharacterBody3D
var glinda: Node3D
var beat: Beat = Beat.APPROACH
var compass: Label
var _near_glinda: bool = false
var _near_home: bool = false
var _glinda_line: int = 0
var _glinda_lines: PackedStringArray = PackedStringArray([
	"Glinda: \"Welcome, Dorothy. I am Glinda, the Good Witch of the South.\"",
	"Glinda: \"You have walked the Yellow Brick Road with true friends. The West is gone. The Wizard is only a man.\"",
	"Glinda: \"The Silver Shoes on your feet have always been the way home — you needed to be ready to use them.\"",
	"Glinda: \"Click your heels with intention, child. Or stay — Oz remembers those who choose her.\"",
	"Glinda: \"When you are ready, walk the last stretch of the Yellow Brick Road south — that is your FINAL STEP.\"",
])

func _enter_tree() -> void:
	var p := get_node_or_null("/root/Party")
	if p and p.has_method("reset_party"):
		p.reset_party()

func _ready() -> void:
	_build_world()
	_spawn_party()
	_spawn_glinda()
	_add_glinda_whimsy()
	_ensure_compass()
	if hud and hud.has_method("set_kansas_mode"):
		hud.set_kansas_mode(false)
	_set_beat(Beat.APPROACH)
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("on_level_start"):
		lt.on_level_start("Quadling Country · Glinda's court")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			_set_beat(Beat.DONE)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F8:
			_glinda_line = _glinda_lines.size()
			_set_beat(Beat.CHOICE)
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if player == null:
		return
	_update_compass()
	var actor := _lead()
	if actor == null:
		return
	if beat == Beat.APPROACH and actor.global_position.distance_to(GLINDA_POS) < 10.0:
		_set_beat(Beat.MEET_GLINDA)
	_near_glinda = beat == Beat.MEET_GLINDA and actor.global_position.distance_to(GLINDA_POS) < 3.5
	_near_home = beat == Beat.CHOICE and actor.global_position.distance_to(ROAD_HOME_PAD) < 4.0
	if Input.is_action_just_pressed("interact"):
		if _near_glinda and beat == Beat.MEET_GLINDA:
			_advance_glinda()
		elif beat == Beat.REVEAL and _near_glinda:
			_set_beat(Beat.CHOICE)
		elif _near_home and beat == Beat.CHOICE:
			_set_beat(Beat.DONE)
		else:
			var w := get_node_or_null("/root/Whimsy")
			if w and w.has_method("try_collect"):
				w.call("try_collect", actor)
	_update_prompt()

func _lead() -> CharacterBody3D:
	var party := get_node_or_null("/root/Party")
	if party and party.has_method("leader_body"):
		var b = party.call("leader_body")
		if b is CharacterBody3D:
			return b
	return player

func _build_world() -> void:
	_add_box(Vector3(0, -0.2, 0), Vector3(90, 0.4, 100), Color(0.55, 0.35, 0.48), "Ground")
	_add_box(Vector3(0, -0.2, -30), Vector3(70, 0.4, 50), Color(0.5, 0.32, 0.45), "GroundS")
	# Continuous YBR south to Glinda then Road Home pad
	_add_box(Vector3(0, 0.05, 10), Vector3(5.6, 0.1, 55), Color(0.95, 0.82, 0.25), "YellowBrickRoad")
	_add_box(Vector3(0, 0.05, -30), Vector3(5.8, 0.12, 30), Color(0.96, 0.84, 0.28), "YellowBrickRoadS")
	_add_box(ROAD_HOME_PAD + Vector3(0, 0.02, 0), Vector3(7.0, 0.14, 7.0), Color(1.0, 0.75, 0.9), "RoadHomePad")
	# Soft rose court around Glinda
	_add_box(Vector3(0, 0.03, -18), Vector3(22, 0.08, 16), Color(0.75, 0.45, 0.6), "Court")
	# Pillars / pavilion
	for xz in [Vector3(-8, 0, -14), Vector3(8, 0, -14), Vector3(-8, 0, -24), Vector3(8, 0, -24)]:
		_add_box(xz + Vector3(0, 3, 0), Vector3(1.4, 6, 1.4), Color(0.9, 0.7, 0.85), "Pillar")
	_add_box(Vector3(0, 6.5, -19), Vector3(20, 0.6, 14), Color(0.85, 0.55, 0.75), "Canopy")
	var ybr := Label3D.new()
	ybr.text = "YELLOW BRICK ROAD\n→ Glinda · Road Home"
	ybr.font_size = 44
	ybr.pixel_size = 0.013
	ybr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ybr.modulate = Color(1.0, 0.9, 0.4)
	add_child(ybr)
	ybr.global_position = Vector3(0, 3.5, 24)
	var home_lab := Label3D.new()
	home_lab.text = "ROAD HOME\n(FINAL STEP · E)"
	home_lab.font_size = 48
	home_lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	home_lab.modulate = Color(1.0, 0.7, 0.9)
	add_child(home_lab)
	home_lab.global_position = ROAD_HOME_PAD + Vector3(0, 4.0, 0)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.9, 0.95)
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-50, 20, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.7, 0.85)
	fill.light_energy = 3.5
	fill.omni_range = 36.0
	add_child(fill)
	fill.global_position = GLINDA_POS + Vector3(0, 5, 0)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.28, 0.16, 0.28)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.4, 0.55)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)
	_add_map_border(PLAY_BOUND_X + 4.0, PLAY_BOUND_Z + 4.0)
	var title := Label3D.new()
	title.text = "QUADLING COUNTRY\nGlinda · the South"
	title.font_size = 56
	title.pixel_size = 0.015
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.modulate = Color(1.0, 0.65, 0.85)
	add_child(title)
	title.global_position = Vector3(0, 9, -8)

func _add_map_border(half_x: float, half_z: float) -> void:
	var h := 3.2
	var thick := 2.0
	var col := Color(0.35, 0.2, 0.35)
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
	if color.r > 0.85 and color.b > 0.7:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.55
	mi.material_override = mat
	body.add_child(mi)
	return mi

func _spawn_party() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = YBR_SPAWN
	if player.has_method("empower_shoes"):
		player.empower_shoes()
	scarecrow = SCARECROW_SCENE.instantiate()
	add_child(scarecrow)
	scarecrow.global_position = YBR_SPAWN + Vector3(-2.2, 0, 2.5)
	if scarecrow.has_method("free_from_pole"):
		scarecrow.free_from_pole()
	lion = LION_SCENE.instantiate()
	add_child(lion)
	lion.global_position = YBR_SPAWN + Vector3(2.2, 0, 2.8)
	if lion.has_method("calm"):
		lion.calm()
	tinman = TINMAN_SCENE.instantiate()
	add_child(tinman)
	tinman.global_position = YBR_SPAWN + Vector3(0, 0, 3.5)
	if tinman.has_method("oil_and_free"):
		tinman.oil_and_free()

func _spawn_glinda() -> void:
	glinda = CharacterBody3D.new()
	glinda.name = "Glinda"
	add_child(glinda)
	glinda.global_position = GLINDA_POS
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.7
	cyl.height = 1.6
	body.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.55, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.85)
	mat.emission_energy_multiplier = 0.7
	body.material_override = mat
	body.position = Vector3(0, 0.9, 0)
	glinda.add_child(body)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.28
	sph.height = 0.56
	head.mesh = sph
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.95, 0.85, 0.78)
	head.material_override = hm
	head.position = Vector3(0, 1.95, 0)
	glinda.add_child(head)
	var lab := Label3D.new()
	lab.text = "GLINDA\nGood Witch of the South"
	lab.font_size = 40
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(1.0, 0.8, 0.95)
	lab.position = Vector3(0, 3.2, 0)
	glinda.add_child(lab)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.95)
	light.light_energy = 2.5
	light.omni_range = 12.0
	glinda.add_child(light)
	light.position = Vector3(0, 2.5, 0)

func _add_glinda_whimsy() -> void:
	var w := get_node_or_null("/root/Whimsy")
	if w == null or not w.has_method("setup") or hud == null:
		return
	w.call("setup", self, hud, [
		{"pos": Vector3(8, 0, 28), "kind": "bounce", "name": "Rose toadstool"},
		{"pos": Vector3(-9, 0, 18), "kind": "giggle", "name": "South giggle"},
		{"pos": Vector3(10, 0, 0), "kind": "chime", "name": "Crystal chime"},
		{"pos": Vector3(-10, 0, -10), "kind": "dance", "name": "Quadling dance"},
		{"pos": Vector3(8, 0, -32), "kind": "giggle", "name": "Home giggle"},
	], "glinda")

func _advance_glinda() -> void:
	if _glinda_line >= _glinda_lines.size():
		_set_beat(Beat.REVEAL)
		return
	var line: String = _glinda_lines[_glinda_line]
	_glinda_line += 1
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say_line"):
		d.say_line(line, true)
	elif hud:
		hud.set_prompt(line)
	if _glinda_line >= _glinda_lines.size():
		_set_beat(Beat.REVEAL)

func _set_beat(next: Beat) -> void:
	beat = next
	match beat:
		Beat.APPROACH:
			hud.set_objective("Follow the Yellow Brick Road south to Glinda — Good Witch of the South.")
			hud.set_prompt("YBR south · pink court ahead · F8 skip counsel · F9 ending")
		Beat.MEET_GLINDA:
			hud.set_objective("Speak with Glinda (E) — she holds the truth of the Shoes.")
			hud.set_prompt("E advances Glinda's counsel")
		Beat.REVEAL:
			hud.set_objective("The Shoes were always home. When ready, follow the YBR south to the Road Home pad.")
			hud.set_prompt("YBR south · pink FINAL STEP pad")
		Beat.CHOICE:
			hud.set_objective("FINAL STEP (L5): Walk the Yellow Brick Road to the glowing Road Home pad — E to choose.")
			hud.set_prompt("E on Road Home pad · go home (prototype ending)")
		Beat.DONE:
			hud.set_objective("The Road Home opens. Oz remembers.")
			hud.set_prompt("Hourglass rests — prototype spine complete.")
			var d := get_node_or_null("/root/DialogueUI")
			if d and d.has_method("say"):
				d.say("Narrator", "Dorothy clicks her heels. The Yellow Brick Road becomes the road home — and the hourglass rests.", true, 5.0)
			var lt := get_node_or_null("/root/LevelTransition")
			if lt and lt.has_method("play_exit"):
				lt.play_exit("There's no place like home…")

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
	compass.add_theme_color_override("font_color", Color(1.0, 0.75, 0.9))

func _update_compass() -> void:
	if compass == null:
		return
	var actor := _lead()
	if actor == null:
		return
	var target := GLINDA_POS
	var label := "Glinda"
	match beat:
		Beat.APPROACH, Beat.MEET_GLINDA, Beat.REVEAL:
			target = GLINDA_POS
			label = "Glinda"
			if beat == Beat.REVEAL:
				target = ROAD_HOME_PAD
				label = "YBR → Road Home"
		Beat.CHOICE:
			target = ROAD_HOME_PAD
			label = "Road Home (FINAL)"
		Beat.DONE:
			compass.text = "Spine complete — Road Home"
			return
	var dist := actor.global_position.distance_to(target)
	compass.text = "%s  ·  %.0fm" % [label, dist]

func _update_prompt() -> void:
	if _near_glinda and beat == Beat.MEET_GLINDA:
		hud.set_prompt("E  —  Speak with Glinda")
	elif _near_home and beat == Beat.CHOICE:
		hud.set_prompt("E  —  FINAL STEP: Take the Road Home")
	else:
		var w := get_node_or_null("/root/Whimsy")
		if w and w.has_method("prompt_if_near"):
			var p: String = str(w.call("prompt_if_near"))
			if p != "":
				hud.set_prompt(p)
