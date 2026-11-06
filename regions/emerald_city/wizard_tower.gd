extends Node3D

## Act 4 · Emerald City — Yellow Brick approach + enterable Wizard palace-tower.
## Vault [[The Wizard (Boss)]]: green glass spectacle, projected face, curtain → humbug body.
## Not "Tower of Oz". F8 → audience · F9 road-home stub.

const PLAYER_SCENE := preload("res://actors/dorothy/player.tscn")
const HUD_SCENE := preload("res://ui/play_hud.tscn")
const SCARECROW_SCENE := preload("res://actors/companions/scarecrow.tscn")
const LION_SCENE := preload("res://actors/companions/lion.tscn")
const TINMAN_SCENE := preload("res://actors/companions/tinman.tscn")
const GLINDA_SCENE := "res://regions/quadling/glinda_court.tscn"
enum Beat {
	APPROACH,
	GATES,
	ENTER_HALL,
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
var wizard_body: Node3D
var curtain: Node3D
var hall_root: Node3D
var door_seal: StaticBody3D
var gate_pos: Vector3 = Vector3(0, 0.08, -8)
var door_pos: Vector3 = Vector3(0, 0.08, -38)
var hall_stand: Vector3 = Vector3(0, 0.15, -46)
var throne_pos: Vector3 = Vector3(0, 0.15, -58)
var compass: Label
var _near_gate: bool = false
var _near_door: bool = false
var _near_throne: bool = false
var _near_curtain: bool = false
var _in_hall: bool = false
var _audience_line: int = 0
var _head_pulse: float = 0.0
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
	_add_emerald_whimsy()
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
			_go_glinda("The hourglass turns — Glinda's court…")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F8:
			_enter_hall(true)
			_set_beat(Beat.AUDIENCE)
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if player == null:
		return
	_pulse_projection(delta)
	_update_compass()
	var actor := _lead()
	if actor == null:
		return
	if beat == Beat.APPROACH and actor.global_position.distance_to(gate_pos) < 6.0:
		_set_beat(Beat.GATES)
	_near_gate = beat == Beat.GATES and actor.global_position.distance_to(gate_pos) < 3.8
	_near_door = (beat == Beat.ENTER_HALL or beat == Beat.GATES) and (not _in_hall) \
		and actor.global_position.distance_to(door_pos) < 4.0
	# Audience E works anywhere near the throne dais OR once dialogue started.
	_near_throne = beat == Beat.AUDIENCE and (
		actor.global_position.distance_to(throne_pos) < 14.0 or _audience_line > 0
	)
	_near_curtain = beat == Beat.CURTAIN and curtain \
		and actor.global_position.distance_to(curtain.global_position) < 4.0
	if Input.is_action_just_pressed("interact"):
		if _near_gate and beat == Beat.GATES:
			_set_beat(Beat.ENTER_HALL)
			# Walk them through the arch onto the palace approach.
			actor.global_position = Vector3(0, 0.12, -18)
		elif _near_door and not _in_hall:
			_enter_hall(false)
			_set_beat(Beat.AUDIENCE)
		elif beat == Beat.AUDIENCE and (_near_throne or _audience_line > 0 or _in_hall):
			_advance_audience()
		elif _near_curtain and beat == Beat.CURTAIN:
			_set_beat(Beat.CHOICE)
		elif beat == Beat.CHOICE:
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

func _say(line: String) -> void:
	if hud:
		hud.set_prompt(line)
	var dui := get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("say_line"):
		dui.say_line(line, true)

func _enter_hall(skip_walk: bool) -> void:
	_in_hall = true
	if door_seal:
		door_seal.collision_layer = 0
		door_seal.visible = false
	var actor := _lead()
	if actor and not skip_walk:
		actor.global_position = hall_stand
	# Stagger party into hall.
	var party := get_node_or_null("/root/Party")
	if party and party.has_method("combat_bodies"):
		var bodies = party.call("combat_bodies")
		var i := 0
		if bodies is Array:
			for b in bodies:
				if b is CharacterBody3D and b != actor:
					i += 1
					(b as CharacterBody3D).global_position = hall_stand + Vector3(float(i % 3) - 1.0, 0, 1.2 + float(i) * 0.8)

func _build_world() -> void:
	_add_box(Vector3(0, -0.2, 20), Vector3(90, 0.4, 100), Color(0.18, 0.32, 0.22), "OuterGround")
	# Yellow brick road
	_add_box(Vector3(0, 0.04, 14), Vector3(7.5, 0.1, 60), Color(0.92, 0.78, 0.2), "YellowBrickRoad")
	for i in 14:
		var z := 38.0 - float(i) * 4.2
		_add_box(Vector3(-2.6, 0.08, z), Vector3(2.0, 0.06, 2.0), Color(0.95, 0.82, 0.25), "Brick")
		_add_box(Vector3(2.6, 0.08, z), Vector3(2.0, 0.06, 2.0), Color(0.88, 0.72, 0.18), "Brick")
	var ybr := Label3D.new()
	ybr.text = "YELLOW BRICK ROAD\n→ Emerald City"
	ybr.font_size = 48
	ybr.pixel_size = 0.014
	ybr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ybr.modulate = Color(1.0, 0.9, 0.35)
	ybr.outline_size = 8
	add_child(ybr)
	ybr.global_position = Vector3(0, 3.5, 30)
	# City gates — grander arch
	_add_box(Vector3(-20, 6, -8), Vector3(14, 14, 5), Color(0.12, 0.42, 0.26), "GateL")
	_add_box(Vector3(20, 6, -8), Vector3(14, 14, 5), Color(0.12, 0.42, 0.26), "GateR")
	_add_box(Vector3(0, 11, -8), Vector3(14, 5, 4), Color(0.18, 0.55, 0.34), "GateArch")
	_add_box(Vector3(-8, 3, -8), Vector3(2.2, 8, 3.2), Color(0.15, 0.5, 0.3), "PillarL")
	_add_box(Vector3(8, 3, -8), Vector3(2.2, 8, 3.2), Color(0.15, 0.5, 0.3), "PillarR")
	var glab := Label3D.new()
	glab.text = "EMERALD CITY GATES\n(E — pass through)"
	glab.font_size = 44
	glab.pixel_size = 0.013
	glab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glab.modulate = Color(0.5, 1.0, 0.65)
	add_child(glab)
	glab.global_position = gate_pos + Vector3(0, 6, 0)
	# Plaza
	_add_box(Vector3(0, -0.12, -40), Vector3(70, 0.4, 55), Color(0.16, 0.38, 0.26), "Plaza")
	# Approach stairs up to palace (climbable)
	for s in 5:
		var t := float(s + 1) / 5.0
		_add_box(Vector3(0, 0.12 + float(s) * 0.22, -28.0 - float(s) * 1.1), Vector3(14.0 - float(s) * 0.4, 0.24, 1.2), Color(0.2, 0.5, 0.32), "ApproachStep")
	# Green glass spires
	for xz in [Vector3(-14, 0, -42), Vector3(14, 0, -42), Vector3(-12, 0, -62), Vector3(12, 0, -62), Vector3(0, 0, -70)]:
		var sp := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.15
		cone.bottom_radius = 1.6
		cone.height = 18.0
		sp.mesh = cone
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.2, 0.75, 0.4, 0.7)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.emission_enabled = true
		sm.emission = Color(0.15, 0.6, 0.3)
		sm.emission_energy_multiplier = 0.85
		sp.material_override = sm
		add_child(sp)
		sp.global_position = xz + Vector3(0, 9, 0)
	_build_palace_hall()
	_build_wizard_projection()
	_build_curtain_and_body()
	# Lights
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.75, 1.0, 0.85)
	sun.light_energy = 0.95
	sun.rotation_degrees = Vector3(-48, 18, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.14, 0.11)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.22, 0.42, 0.3)
	e.ambient_light_energy = 0.75
	env.environment = e
	add_child(env)
	_add_map_border(48.0, 58.0)
	var title := Label3D.new()
	title.text = "EMERALD CITY"
	title.font_size = 72
	title.pixel_size = 0.018
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.modulate = Color(0.45, 1.0, 0.6)
	add_child(title)
	title.global_position = Vector3(0, 12, -22)

func _build_palace_hall() -> void:
	hall_root = Node3D.new()
	hall_root.name = "WizardPalace"
	add_child(hall_root)
	# Hollow hall: floor, ceiling, three walls + door gap on +Z face.
	var floor_y := 0.05
	_add_box(Vector3(0, floor_y, -52), Vector3(28, 0.2, 32), Color(0.22, 0.18, 0.14), "HallFloor")
	_add_box(Vector3(0, 11.0, -52), Vector3(28, 0.4, 32), Color(0.1, 0.35, 0.22), "HallCeiling")
	# Side walls
	_add_box(Vector3(-14, 5.5, -52), Vector3(1.2, 11, 32), Color(0.1, 0.48, 0.28), "HallWallL")
	_add_box(Vector3(14, 5.5, -52), Vector3(1.2, 11, 32), Color(0.1, 0.48, 0.28), "HallWallR")
	# Back wall (throne end)
	_add_box(Vector3(0, 5.5, -67.5), Vector3(28, 11, 1.4), Color(0.08, 0.4, 0.24), "HallWallBack")
	# Front wall with door opening (two side slabs)
	_add_box(Vector3(-9.5, 5.5, -36.5), Vector3(9, 11, 1.4), Color(0.1, 0.45, 0.28), "HallFrontL")
	_add_box(Vector3(9.5, 5.5, -36.5), Vector3(9, 11, 1.4), Color(0.1, 0.45, 0.28), "HallFrontR")
	_add_box(Vector3(0, 9.2, -36.5), Vector3(10, 3.5, 1.4), Color(0.15, 0.55, 0.35), "HallFrontLint")
	# Outer tower mass (visual bulk above)
	_add_box(Vector3(0, 18, -52), Vector3(18, 14, 18), Color(0.1, 0.5, 0.3), "TowerUpper")
	_add_box(Vector3(0, 28, -52), Vector3(20, 2.5, 20), Color(0.65, 0.9, 0.4), "TowerCrown")
	# Columns inside
	for x in [-8.0, 8.0]:
		for z in [-44.0, -52.0, -60.0]:
			_add_box(Vector3(x, 4.0, z), Vector3(1.4, 8.0, 1.4), Color(0.2, 0.55, 0.35), "HallCol")
	# Throne dais
	_add_box(Vector3(0, 0.45, -60), Vector3(10, 0.9, 6), Color(0.35, 0.28, 0.15), "ThroneDais")
	_add_box(Vector3(0, 1.4, -61.5), Vector3(3.2, 2.2, 1.6), Color(0.55, 0.45, 0.2), "ThroneSeat")
	# Door seal (blocks until E)
	door_seal = StaticBody3D.new()
	door_seal.name = "PalaceDoorSeal"
	add_child(door_seal)
	door_seal.global_position = door_pos + Vector3(0, 2.2, 0)
	door_seal.collision_layer = 1
	var dcs := CollisionShape3D.new()
	var dbox := BoxShape3D.new()
	dbox.size = Vector3(5.5, 4.4, 0.6)
	dcs.shape = dbox
	door_seal.add_child(dcs)
	var dmi := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = dbox.size
	dmi.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.08, 0.35, 0.22)
	dmat.emission_enabled = true
	dmat.emission = Color(0.15, 0.6, 0.35)
	dmat.emission_energy_multiplier = 0.6
	dmi.material_override = dmat
	door_seal.add_child(dmi)
	var dlab := Label3D.new()
	dlab.text = "PALACE DOORS\n(E — enter the great hall)"
	dlab.font_size = 42
	dlab.pixel_size = 0.012
	dlab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dlab.modulate = Color(0.7, 1.0, 0.75)
	dlab.outline_size = 8
	add_child(dlab)
	dlab.global_position = door_pos + Vector3(0, 5.2, 1.5)
	# Hall lights
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.6, 1.0, 0.7)
	lamp.light_energy = 3.2
	lamp.omni_range = 28.0
	add_child(lamp)
	lamp.global_position = Vector3(0, 8, -50)
	var lamp2 := OmniLight3D.new()
	lamp2.light_color = Color(0.9, 0.85, 0.5)
	lamp2.light_energy = 2.0
	lamp2.omni_range = 16.0
	add_child(lamp2)
	lamp2.global_position = Vector3(0, 6, -58)

func _build_wizard_projection() -> void:
	## Book/vault: terrifying head/face of Oz as projected spectacle (not a real giant).
	wizard_head = Node3D.new()
	wizard_head.name = "WizardProjection"
	add_child(wizard_head)
	wizard_head.global_position = Vector3(0, 7.5, -64.5)
	# Glow plate / screen
	var screen := MeshInstance3D.new()
	var sq := BoxMesh.new()
	sq.size = Vector3(12, 10, 0.4)
	screen.mesh = sq
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.05, 0.2, 0.12, 0.85)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.emission_enabled = true
	sm.emission = Color(0.1, 0.45, 0.25)
	sm.emission_energy_multiplier = 1.2
	screen.material_override = sm
	wizard_head.add_child(screen)
	screen.position = Vector3(0, 0, -0.5)
	# Face sphere
	var head := MeshInstance3D.new()
	head.name = "Face"
	var hs := SphereMesh.new()
	hs.radius = 3.4
	hs.height = 6.8
	head.mesh = hs
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.25, 0.85, 0.4, 0.55)
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.emission_enabled = true
	hm.emission = Color(0.2, 0.95, 0.4)
	hm.emission_energy_multiplier = 1.8
	head.material_override = hm
	wizard_head.add_child(head)
	# Eyes
	for ex in [-1.1, 1.1]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.45
		es.height = 0.9
		eye.mesh = es
		var em := StandardMaterial3D.new()
		em.albedo_color = Color(0.05, 0.05, 0.05)
		em.emission_enabled = true
		em.emission = Color(0.9, 0.2, 0.15)
		em.emission_energy_multiplier = 3.0
		eye.material_override = em
		wizard_head.add_child(eye)
		eye.position = Vector3(ex, 0.6, 3.0)
	# Mouth
	var mouth := MeshInstance3D.new()
	mouth.name = "Mouth"
	var mb := BoxMesh.new()
	mb.size = Vector3(2.2, 0.55, 0.35)
	mouth.mesh = mb
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.1, 0.02, 0.02)
	mm.emission_enabled = true
	mm.emission = Color(0.8, 0.15, 0.1)
	mm.emission_energy_multiplier = 1.5
	mouth.material_override = mm
	wizard_head.add_child(mouth)
	mouth.position = Vector3(0, -1.2, 3.1)
	var hlab := Label3D.new()
	hlab.text = "O Z"
	hlab.font_size = 110
	hlab.pixel_size = 0.022
	hlab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hlab.modulate = Color(0.75, 1.0, 0.8)
	hlab.outline_size = 12
	wizard_head.add_child(hlab)
	hlab.position = Vector3(0, 4.2, 2.0)
	wizard_head.visible = false

func _build_curtain_and_body() -> void:
	curtain = Node3D.new()
	curtain.name = "Curtain"
	add_child(curtain)
	curtain.global_position = Vector3(7.5, 0.1, -58)
	_add_box(curtain.global_position + Vector3(0, 3.5, 0), Vector3(0.35, 7, 5), Color(0.55, 0.08, 0.12), "CurtainMesh")
	var clab := Label3D.new()
	clab.text = "CURTAIN\n(E — pull)"
	clab.font_size = 40
	clab.pixel_size = 0.012
	clab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	clab.modulate = Color(1.0, 0.7, 0.7)
	curtain.add_child(clab)
	clab.position = Vector3(0, 6, 0)
	# Humbug body — hidden until curtain
	wizard_body = Node3D.new()
	wizard_body.name = "WizardBody"
	add_child(wizard_body)
	wizard_body.global_position = Vector3(7.5, 0.1, -60.5)
	wizard_body.visible = false
	# Simple man silhouette: legs, torso, head, coat
	_add_limb(wizard_body, Vector3(-0.22, 0.55, 0), Vector3(0.22, 1.1, 0.22), Color(0.2, 0.18, 0.25))
	_add_limb(wizard_body, Vector3(0.22, 0.55, 0), Vector3(0.22, 1.1, 0.22), Color(0.2, 0.18, 0.25))
	_add_limb(wizard_body, Vector3(0, 1.45, 0), Vector3(0.7, 0.95, 0.4), Color(0.45, 0.2, 0.15))
	_add_limb(wizard_body, Vector3(0, 2.15, 0), Vector3(0.38, 0.4, 0.38), Color(0.92, 0.78, 0.65))
	_add_limb(wizard_body, Vector3(0, 2.45, 0), Vector3(0.55, 0.22, 0.55), Color(0.15, 0.12, 0.1))
	# Lever / machine
	_add_limb(wizard_body, Vector3(-0.9, 1.0, -0.3), Vector3(0.8, 1.6, 0.5), Color(0.35, 0.35, 0.4))
	var blab := Label3D.new()
	blab.name = "HumbugLabel"
	blab.text = "A SMALL MAN\n\"I'm a humbug…\""
	blab.font_size = 36
	blab.pixel_size = 0.011
	blab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	blab.modulate = Color(0.95, 0.9, 0.75)
	blab.outline_size = 8
	wizard_body.add_child(blab)
	blab.position = Vector3(0, 3.2, 0)

func _add_limb(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.75
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos

func _pulse_projection(delta: float) -> void:
	if wizard_head == null or not wizard_head.visible:
		return
	_head_pulse += delta
	var s := 1.0 + sin(_head_pulse * 2.2) * 0.04
	wizard_head.scale = Vector3(s, s, s)
	var mouth := wizard_head.get_node_or_null("Mouth") as MeshInstance3D
	if mouth:
		var open := 0.55 + absf(sin(_head_pulse * 6.0)) * 0.55
		mouth.scale = Vector3(1.0, open, 1.0)

func _add_map_border(half_x: float, half_z: float) -> void:
	var h := 3.0
	var thick := 2.0
	var col := Color(0.08, 0.22, 0.14)
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
	_say(_audience_lines[_audience_line])
	_audience_line += 1
	if _audience_line >= _audience_lines.size():
		hud.set_objective("The companions see through him — walk to the red curtain and pull it (E).")
	else:
		hud.set_objective("Audience with Oz — E to continue (%d/%d)" % [_audience_line, _audience_lines.size()])

func _set_beat(next: Beat) -> void:
	beat = next
	match beat:
		Beat.APPROACH:
			hud.set_objective("Yellow Brick Road — walk to the Emerald City gates.")
			hud.set_prompt("Green glass towers ahead · F8 skip into hall · F9 → Glinda (L5)")
		Beat.GATES:
			hud.set_objective("Emerald City gates — E to pass the arch onto the palace approach.")
			hud.set_prompt("E  —  Pass the Emerald gates")
		Beat.ENTER_HALL:
			hud.set_objective("Climb the steps to the palace doors — E to enter the great hall.")
			hud.set_prompt("E at the glowing palace doors")
		Beat.AUDIENCE:
			hud.set_objective("Great hall — face the projected Oz. E advances his speech.")
			hud.set_prompt("I AM OZ — E to hear him")
			_audience_line = 0
			if wizard_head:
				wizard_head.visible = true
			# Kick first line so first E isn't a dead click after enter.
			_advance_audience()
		Beat.CURTAIN:
			hud.set_objective("Final step: pull the red curtain (E) — the man behind the spectacle.")
			hud.set_prompt("E at the red curtain · this is the level end-gate")
			if wizard_head:
				var tw := create_tween()
				tw.tween_property(wizard_head, "scale", Vector3(0.15, 0.15, 0.15), 0.9)
		Beat.CHOICE:
			hud.set_objective("The Wizard is only a man. E — take the Yellow Brick Road south to Glinda.")
			hud.set_prompt("E  —  \"I want to go home\" → Glinda / Road Home (L5)")
			if wizard_body:
				wizard_body.visible = true
			if curtain:
				var tw2 := create_tween()
				tw2.tween_property(curtain, "position:x", curtain.position.x + 4.5, 0.7)
			if wizard_head:
				wizard_head.visible = false
			_say("Wizard: \"I'm a humbug… Please don't tell anyone.\"")
		Beat.DONE:
			hud.set_objective("FINAL STEP (L4): Hourglass turns — Yellow Brick Road to Glinda's court (L5).")
			hud.set_prompt("Curtain falls. The road continues south…")
			var dui := get_node_or_null("/root/DialogueUI")
			if dui and dui.has_method("clear"):
				dui.clear()
			_go_glinda("The curtain falls — the hourglass turns toward the South…")

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
		Beat.ENTER_HALL:
			target = door_pos
			label = "Palace doors"
		Beat.AUDIENCE:
			target = throne_pos
			label = "Throne / Oz"
		Beat.CURTAIN, Beat.CHOICE:
			target = curtain.global_position if curtain else throne_pos
			label = "Curtain (end-gate)"
		Beat.DONE:
			compass.text = "YBR → Glinda (L5)"
			return
	var dist := actor.global_position.distance_to(target)
	compass.text = "%s  ·  %.0fm" % [label, dist]

func _update_prompt() -> void:
	if beat == Beat.GATES and _near_gate:
		hud.set_prompt("E  —  Pass the Emerald gates")
	elif beat == Beat.ENTER_HALL and _near_door:
		hud.set_prompt("E  —  Enter the Wizard's great hall")
	elif beat == Beat.AUDIENCE and (_near_throne or _in_hall):
		if _audience_line == 0:
			hud.set_prompt("E  —  Face Oz, the Great and Powerful")
		elif _audience_line < _audience_lines.size():
			hud.set_prompt("E  —  Continue audience (%d/%d)" % [_audience_line + 1, _audience_lines.size()])
		else:
			hud.set_prompt("E  —  Finish audience → curtain")
	elif beat == Beat.CURTAIN and _near_curtain:
		hud.set_prompt("E  —  Pull the curtain (level end-gate)")
	elif beat == Beat.CHOICE:
		hud.set_prompt("E  —  Choose the road home → Glinda (L5)")
	else:
		var w := get_node_or_null("/root/Whimsy")
		if w and w.has_method("prompt_if_near"):
			var p: String = str(w.call("prompt_if_near"))
			if p != "":
				hud.set_prompt(p)

func _go_glinda(msg: String) -> void:
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("go_to"):
		lt.go_to(GLINDA_SCENE, msg, "Quadling Country · Glinda's court")
	else:
		get_tree().change_scene_to_file(GLINDA_SCENE)

func _add_emerald_whimsy() -> void:
	var w := get_node_or_null("/root/Whimsy")
	if w == null or not w.has_method("setup") or hud == null:
		return
	w.call("setup", self, hud, [
		{"pos": Vector3(8, 0, 28), "kind": "bounce", "name": "Emerald toadstool"},
		{"pos": Vector3(-9, 0, 20), "kind": "giggle", "name": "Green giggle"},
		{"pos": Vector3(10, 0, 8), "kind": "chime", "name": "Glass chime"},
		{"pos": Vector3(-8, 0, -2), "kind": "dance", "name": "Gate dance"},
		{"pos": Vector3(9, 0, -22), "kind": "giggle", "name": "Plaza giggle"},
	], "emerald")
