extends Node3D

## Act 4 · Emerald City — Yellow Brick approach + Wizard's tower (vault [[The Wizard (Boss)]]).
## Not "Tower of Oz" — Emerald City / the Wizard's palace. Green glass, spectacle, curtain.
## Prototype: L4 after West castle. F9 prints road-home stub.

const PLAYER_SCENE := preload("res://actors/dorothy/player.tscn")
const HUD_SCENE := preload("res://ui/play_hud.tscn")
const SCARECROW_SCENE := preload("res://actors/companions/scarecrow.tscn")
const LION_SCENE := preload("res://actors/companions/lion.tscn")
const TINMAN_SCENE := preload("res://actors/companions/tinman.tscn")

enum Beat {
	APPROACH,
	GATES,
	AUDIENCE,
	CURTAIN,
	CHOICE,
	DONE,
}

var hud: CanvasLayer
var player: CharacterBody3D
var scarecrow: CharacterBody3D
var lion: CharacterBody3D
var tinman: CharacterBody3D
var beat: Beat = Beat.APPROACH
var wizard_head: Node3D
var curtain: Node3D
var throne_pos: Vector3 = Vector3(0, 0.08, -48)
var gate_pos: Vector3 = Vector3(0, 0.08, -8)
var compass: Label
var _near_gate: bool = false
var _near_throne: bool = false
var _near_curtain: bool = false
var _audience_line: int = 0
var _audience_lines: PackedStringArray = PackedStringArray([
	"OZ (projection): \"I AM OZ — THE GREAT AND POWERFUL.\"",
	"OZ: \"You want heart, brain, courage, home? Then prove you can unmake the West.\"",
	"OZ: \"…She is already gone? Then approach the curtain, if you dare.\"",
	"Scarecrow: \"The voice is coming from behind the drapes — not the head.\"",
	"Tin Man: \"I hear gears. Small gears.\"",
	"Lion: \"He smells afraid.\"",
])

func _enter_tree() -> void:
	var p := get_node_or_null("/root/Party")
	if p and p.has_method("reset_party"):
		p.reset_party()

func _ready() -> void:
	_build_world()
	_spawn_party()
	_ensure_compass()
	if hud and hud.has_method("set_kansas_mode"):
		hud.set_kansas_mode(false)
	_set_beat(Beat.APPROACH)
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("on_level_start"):
		lt.on_level_start("Emerald City · the Wizard's tower")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			_set_beat(Beat.DONE)
			hud.set_prompt("F9 — Road Home stub (Glinda act later).")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F8:
			_set_beat(Beat.AUDIENCE)
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if player == null:
		return
	_update_compass()
	var actor := _lead()
	if actor == null:
		return
	# Auto-advance approach when near gates.
	if beat == Beat.APPROACH and actor.global_position.distance_to(gate_pos) < 6.0:
		_set_beat(Beat.GATES)
	_near_gate = beat == Beat.GATES and actor.global_position.distance_to(gate_pos) < 3.5
	_near_throne = (beat == Beat.AUDIENCE or beat == Beat.GATES) and actor.global_position.distance_to(throne_pos) < 5.0
	_near_curtain = beat == Beat.CURTAIN and curtain and actor.global_position.distance_to(curtain.global_position) < 3.0
	if Input.is_action_just_pressed("interact"):
		if _near_gate and beat == Beat.GATES:
			_set_beat(Beat.AUDIENCE)
			# Pull party into throne approach.
			actor.global_position = throne_pos + Vector3(0, 0, 10)
		elif beat == Beat.AUDIENCE and (_near_throne or _audience_line > 0):
			_advance_audience()
		elif _near_curtain and beat == Beat.CURTAIN:
			_set_beat(Beat.CHOICE)
		elif beat == Beat.CHOICE:
			_set_beat(Beat.DONE)
	_update_prompt()

func _lead() -> CharacterBody3D:
	var party := get_node_or_null("/root/Party")
	if party and party.has_method("leader_body"):
		var b = party.call("leader_body")
		if b is CharacterBody3D:
			return b
	return player

func _build_world() -> void:
	# Outer approach ground
	_add_box(Vector3(0, -0.2, 20), Vector3(80, 0.4, 80), Color(0.2, 0.35, 0.22), "OuterGround")
	# Yellow brick road strip toward the tower (book-true path name).
	_add_box(Vector3(0, 0.03, 12), Vector3(6, 0.08, 55), Color(0.92, 0.78, 0.2), "YellowBrickRoad")
	for i in 12:
		var z := 35.0 - float(i) * 4.5
		_add_box(Vector3(-2.2, 0.06, z), Vector3(1.8, 0.05, 1.8), Color(0.95, 0.82, 0.25), "Brick")
		_add_box(Vector3(2.2, 0.06, z), Vector3(1.8, 0.05, 1.8), Color(0.88, 0.72, 0.18), "Brick")
	var ybr := Label3D.new()
	ybr.text = "YELLOW BRICK ROAD\n→ Emerald City"
	ybr.font_size = 48
	ybr.pixel_size = 0.014
	ybr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ybr.modulate = Color(1.0, 0.9, 0.35)
	ybr.outline_size = 8
	add_child(ybr)
	ybr.global_position = Vector3(0, 3.5, 28)
	# City walls / gates
	_add_box(Vector3(-18, 5, -8), Vector3(12, 12, 4), Color(0.15, 0.45, 0.28), "GateL")
	_add_box(Vector3(18, 5, -8), Vector3(12, 12, 4), Color(0.15, 0.45, 0.28), "GateR")
	_add_box(Vector3(0, 8, -8), Vector3(10, 4, 3), Color(0.2, 0.55, 0.35), "GateArch")
	var glab := Label3D.new()
	glab.text = "EMERALD CITY GATES\n(E — enter)"
	glab.font_size = 44
	glab.pixel_size = 0.013
	glab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glab.modulate = Color(0.5, 1.0, 0.65)
	add_child(glab)
	glab.global_position = gate_pos + Vector3(0, 5, 0)
	# Plaza + tower
	_add_box(Vector3(0, -0.15, -40), Vector3(60, 0.4, 50), Color(0.18, 0.4, 0.28), "Plaza")
	_add_box(Vector3(0, 12, -52), Vector3(14, 28, 14), Color(0.12, 0.55, 0.32), "WizardTower")
	_add_box(Vector3(0, 27, -52), Vector3(16, 2, 16), Color(0.7, 0.85, 0.4), "TowerCrown")
	# Green glass spires
	for xz in [Vector3(-10, 0, -45), Vector3(10, 0, -45), Vector3(-8, 0, -58), Vector3(8, 0, -58)]:
		var sp := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.2
		cone.bottom_radius = 1.4
		cone.height = 14.0
		sp.mesh = cone
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.2, 0.75, 0.4, 0.75)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.emission_enabled = true
		sm.emission = Color(0.15, 0.6, 0.3)
		sm.emission_energy_multiplier = 0.7
		sp.material_override = sm
		add_child(sp)
		sp.global_position = xz + Vector3(0, 7, 0)
	# Throne room floor pad
	_add_box(Vector3(0, 0.05, -48), Vector3(22, 0.1, 18), Color(0.25, 0.2, 0.15), "ThroneFloor")
	# Giant projected head
	wizard_head = Node3D.new()
	wizard_head.name = "WizardProjection"
	add_child(wizard_head)
	wizard_head.global_position = Vector3(0, 9, -56)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 3.2
	hs.height = 6.4
	head.mesh = hs
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.3, 0.85, 0.45, 0.55)
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.emission_enabled = true
	hm.emission = Color(0.2, 0.9, 0.4)
	hm.emission_energy_multiplier = 1.6
	head.material_override = hm
	wizard_head.add_child(head)
	var hlab := Label3D.new()
	hlab.text = "O Z"
	hlab.font_size = 96
	hlab.pixel_size = 0.02
	hlab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hlab.modulate = Color(0.7, 1.0, 0.75)
	wizard_head.add_child(hlab)
	hlab.position = Vector3(0, 0, 3.5)
	# Curtain
	curtain = Node3D.new()
	curtain.name = "Curtain"
	add_child(curtain)
	curtain.global_position = Vector3(6, 0.08, -54)
	_add_box(curtain.global_position + Vector3(0, 3, 0), Vector3(0.3, 6, 4), Color(0.55, 0.1, 0.12), "CurtainMesh")
	var clab := Label3D.new()
	clab.text = "CURTAIN\n(E — pull)"
	clab.font_size = 40
	clab.pixel_size = 0.012
	clab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	clab.modulate = Color(1.0, 0.7, 0.7)
	curtain.add_child(clab)
	clab.position = Vector3(0, 5, 0)
	# Small man marker (hidden until curtain)
	var man := Label3D.new()
	man.name = "ManBehind"
	man.text = ""
	man.font_size = 36
	man.pixel_size = 0.012
	man.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(man)
	man.global_position = Vector3(6, 2.2, -56)
	man.set_meta("label", man)
	# Lights
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.75, 1.0, 0.85)
	sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-50, 20, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.08, 0.16, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.25, 0.45, 0.32)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	_add_map_border(42.0, 55.0)
	var title := Label3D.new()
	title.text = "EMERALD CITY"
	title.font_size = 72
	title.pixel_size = 0.018
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.modulate = Color(0.45, 1.0, 0.6)
	add_child(title)
	title.global_position = Vector3(0, 10, -20)

func _add_map_border(half_x: float, half_z: float) -> void:
	var h := 3.0
	var thick := 2.0
	var col := Color(0.1, 0.25, 0.15)
	for s in [
		{"pos": Vector3(0, h * 0.5, -half_z), "size": Vector3(half_x * 2 + thick * 2, h, thick)},
		{"pos": Vector3(0, h * 0.5, half_z), "size": Vector3(half_x * 2 + thick * 2, h, thick)},
		{"pos": Vector3(-half_x, h * 0.5, 0), "size": Vector3(thick, h, half_z * 2)},
		{"pos": Vector3(half_x, h * 0.5, 0), "size": Vector3(thick, h, half_z * 2)},
	]:
		_add_box(s["pos"], s["size"], col, "MapBorder")

func _add_box(pos: Vector3, size: Vector3, color: Color, n: String) -> void:
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
	if color.g > 0.5 and color.r < 0.4:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.35
	mi.material_override = mat
	body.add_child(mi)

func _spawn_party() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 0.08, 36)
	if player.has_method("empower_shoes"):
		player.empower_shoes()
	scarecrow = SCARECROW_SCENE.instantiate()
	add_child(scarecrow)
	scarecrow.global_position = Vector3(-2.2, 0.08, 37.5)
	if scarecrow.has_method("free_from_pole"):
		scarecrow.free_from_pole()
	lion = LION_SCENE.instantiate()
	add_child(lion)
	lion.global_position = Vector3(2.2, 0.08, 37.5)
	if lion.has_method("calm_and_join"):
		lion.calm_and_join()
	tinman = TINMAN_SCENE.instantiate()
	add_child(tinman)
	tinman.global_position = Vector3(0, 0.08, 38.5)
	if tinman.has_method("oil_and_free"):
		tinman.oil_and_free()

func _advance_audience() -> void:
	if _audience_line >= _audience_lines.size():
		_set_beat(Beat.CURTAIN)
		return
	hud.set_prompt(_audience_lines[_audience_line])
	_audience_line += 1
	if _audience_line >= _audience_lines.size():
		hud.set_objective("The companions see through him — pull the curtain (E).")
	else:
		hud.set_objective("Audience with Oz — E to continue (%d/%d)" % [_audience_line, _audience_lines.size()])

func _set_beat(next: Beat) -> void:
	beat = next
	match beat:
		Beat.APPROACH:
			hud.set_objective("Yellow Brick Road — walk toward the Emerald City gates.")
			hud.set_prompt("Green glass towers ahead · F8 skip to audience · F9 road-home stub")
		Beat.GATES:
			hud.set_objective("Emerald City gates — E to enter the Wizard's tower.")
			hud.set_prompt("E  —  Enter the Emerald City")
		Beat.AUDIENCE:
			hud.set_objective("Throne room — face the great projection. E advances.")
			hud.set_prompt("I AM OZ — E to hear him")
			_audience_line = 0
			if wizard_head:
				wizard_head.visible = true
		Beat.CURTAIN:
			hud.set_objective("Pull the curtain (E) — the man behind the spectacle.")
			hud.set_prompt("E at the red curtain")
			if wizard_head:
				var tw := create_tween()
				tw.tween_property(wizard_head, "scale", Vector3(0.2, 0.2, 0.2), 0.8)
		Beat.CHOICE:
			hud.set_objective("The Wizard is only a man. Prototype choice: claim the road home.")
			hud.set_prompt("E  —  \"I want to go home\" (Glinda stub later) · vault endings branch here")
			var man := find_child("ManBehind", true, false) as Label3D
			if man:
				man.text = "A SMALL MAN\n\"I'm a humbug…\""
				man.modulate = Color(0.95, 0.9, 0.75)
			if wizard_head:
				wizard_head.visible = false
		Beat.DONE:
			hud.set_objective("Act 4 prototype complete — Glinda / Road Home next (not built).")
			hud.set_prompt("The machine is exposed. Hourglass rests.")
			var lt := get_node_or_null("/root/LevelTransition")
			if lt and lt.has_method("play_exit"):
				lt.play_exit("The curtain falls — the hourglass rests…")

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
	compass.add_theme_color_override("font_color", Color(0.45, 0.95, 0.6))

func _update_compass() -> void:
	if compass == null:
		return
	var actor := _lead()
	if actor == null:
		return
	var target := gate_pos
	var label := "Gates"
	match beat:
		Beat.APPROACH, Beat.GATES:
			target = gate_pos
			label = "Emerald gates"
		Beat.AUDIENCE:
			target = throne_pos
			label = "Throne / Oz"
		Beat.CURTAIN, Beat.CHOICE:
			target = curtain.global_position if curtain else throne_pos
			label = "Curtain"
		Beat.DONE:
			compass.text = "Act 4 spine complete"
			return
	var dist := actor.global_position.distance_to(target)
	compass.text = "%s  ·  %.0fm" % [label, dist]

func _update_prompt() -> void:
	if beat == Beat.GATES and _near_gate:
		hud.set_prompt("E  —  Enter the Emerald City")
	elif beat == Beat.CURTAIN and _near_curtain:
		hud.set_prompt("E  —  Pull the curtain")
	elif beat == Beat.CHOICE:
		hud.set_prompt("E  —  Choose the road home (prototype)")
