extends Node3D

## Act 4 · Emerald City — Yellow Brick approach + enterable Wizard palace-tower.
## Vault [[The Wizard (Boss)]]: green glass spectacle, projected face, curtain → humbug body.
## Not "Tower of Oz". F8 → audience · F9 road-home stub.

const PLAYER_SCENE := preload("res://actors/dorothy/player.tscn")
const HUD_SCENE := preload("res://ui/play_hud.tscn")
const SCARECROW_SCENE := preload("res://actors/companions/scarecrow.tscn")
const LION_SCENE := preload("res://actors/companions/lion.tscn")
const TINMAN_SCENE := preload("res://actors/companions/tinman.tscn")
const WorldKit := preload("res://systems/world_kit.gd")
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
var _gate_seal: StaticBody3D
var _gate_doors: Dictionary = {}
var _palace_doors: Dictionary = {}
var _curtain_rig: Dictionary = {}
var _wizard_spot: OmniLight3D = null
var _projection_dismissed: bool = false
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
			_open_gate_doors()
			_set_beat(Beat.ENTER_HALL)
			if DisplayServer.get_name() in ["headless", "Dummy"]:
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

func _open_gate_doors() -> void:
	if _gate_seal:
		_gate_seal.collision_layer = 0
	if _gate_doors.has("left") and _gate_doors.has("right"):
		var tw := create_tween()
		tw.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_gate_doors["left"], "rotation_degrees:y", 105.0, 1.1)
		tw.tween_property(_gate_doors["right"], "rotation_degrees:y", -105.0, 1.1)

func _enter_hall(skip_walk: bool) -> void:
	_in_hall = true
	if door_seal:
		door_seal.collision_layer = 0
		door_seal.visible = false
	if _palace_doors.has("left") and _palace_doors.has("right"):
		var tw := create_tween()
		tw.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_palace_doors["left"], "rotation_degrees:y", 105.0, 1.25)
		tw.tween_property(_palace_doors["right"], "rotation_degrees:y", -105.0, 1.25)
	var actor := _lead()
	if actor and not skip_walk:
		if DisplayServer.get_name() in ["headless", "Dummy"]:
			actor.global_position = hall_stand
		else:
			var wtw := create_tween()
			wtw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			wtw.tween_property(actor, "global_position", hall_stand, 1.15)
	# Stagger party into hall.
	var party := get_node_or_null("/root/Party")
	if party and party.has_method("combat_bodies"):
		var bodies = party.call("combat_bodies")
		var i := 0
		if bodies is Array:
			for b in bodies:
				if b is CharacterBody3D and b != actor:
					i += 1
					var dest := hall_stand + Vector3(float(i % 3) - 1.0, 0, 1.2 + float(i) * 0.8)
					if DisplayServer.get_name() in ["headless", "Dummy"]:
						(b as CharacterBody3D).global_position = dest
					else:
						var btw := create_tween()
						btw.tween_property(b, "global_position", dest, 1.25)

func _build_world() -> void:
	_add_box(Vector3(0, -0.2, 20), Vector3(90, 0.4, 100), Color(0.18, 0.32, 0.22), "OuterGround")
	# Yellow brick road
	_add_box(Vector3(0, 0.04, 14), Vector3(7.5, 0.1, 60), Color(0.92, 0.78, 0.2), "YellowBrickRoad")
	for i in 14:
		var z := 38.0 - float(i) * 4.2
		_add_box(Vector3(-2.6, 0.08, z), Vector3(2.0, 0.06, 2.0), Color(0.95, 0.82, 0.25), "Brick")
		_add_box(Vector3(2.6, 0.08, z), Vector3(2.0, 0.06, 2.0), Color(0.88, 0.72, 0.18), "Brick")
	var ybr_sign := WorldKit.make_wooden_signpost(Vector3(-4.2, 0.0, 28.0), "EMERALD CITY", Color(0.35, 0.95, 0.55), gate_pos)
	add_child(ybr_sign)
	# City gates — grander arch + sealed double gates + FULL-SPAN WALLS to MapBorder (ZERO gap to sneak around!)
	_add_box(Vector3(-28.5, 6, -8), Vector3(40, 14, 5), Color(0.12, 0.42, 0.26), "GateL")
	_add_box(Vector3(28.5, 6, -8), Vector3(40, 14, 5), Color(0.12, 0.42, 0.26), "GateR")
	_add_box(Vector3(0, 11, -8), Vector3(17, 5, 4), Color(0.18, 0.55, 0.34), "GateArch")
	_add_box(Vector3(-7.6, 3, -8), Vector3(2.2, 8, 3.2), Color(0.15, 0.5, 0.3), "PillarL")
	_add_box(Vector3(7.6, 3, -8), Vector3(2.2, 8, 3.2), Color(0.15, 0.5, 0.3), "PillarR")
	_gate_doors = WorldKit.build_palace_double_doors(self, Vector3(0, 0, -8.0), 13.8, 8.5)
	_gate_seal = StaticBody3D.new()
	_gate_seal.name = "EmeraldGateSeal"
	_gate_seal.collision_layer = 1
	add_child(_gate_seal)
	_gate_seal.global_position = Vector3(0, 4.2, -8.0)
	var gcs := CollisionShape3D.new()
	var gsh := BoxShape3D.new()
	gsh.size = Vector3(14.0, 8.5, 1.2)
	gcs.shape = gsh
	_gate_seal.add_child(gcs)
	WorldKit.make_building_crest_sign(self, Vector3(0, 9.6, -5.8), "EMERALD CITY GATES", Color(0.22, 0.78, 0.45), false)
	WorldKit.make_world_badge(self, gate_pos + Vector3(0, 3.6, 1.2), "✦  Emerald City Gates — Open (E)", Color(0.55, 1.0, 0.72), 14.0)
	# Disney-World Fairy-Tale Emerald Castle Ramparts: 6 Crystal Turrets, Battlements, Stained-Glass Niches, Pennants & Fountains!
	WorldKit.dress_emerald_city_wall(self, -8.0)
	# Plaza + Disney-World Fairy-Tale Emerald Boulevard Lanterns & Pennant Flags + Phase P8 Tailor of Vices Boutique!
	_add_box(Vector3(0, -0.12, -40), Vector3(70, 0.4, 55), Color(0.16, 0.38, 0.26), "Plaza")
	for sx in [-1.0, 1.0]:
		for lz in [-14.0, -21.0, -27.0]:
			_add_box(Vector3(float(sx) * 9.5, 3.2, lz), Vector3(0.28, 6.4, 0.28), Color(0.88, 0.76, 0.28), "BoulevardPost")
			_add_box(Vector3(float(sx) * 9.5, 6.6, lz), Vector3(0.85, 0.85, 0.85), Color(0.35, 1.0, 0.65), "BoulevardGem")
	# Phase P8: The Tailor of Vices Ornate Boutique Pavilion on the Emerald Plaza!
	_build_tailor_of_vices(Vector3(-16.5, 0.08, -20.0))
	# Continuous climbable approach stairs culminating in a FLUSH Grand Emerald Marble Landing Terrace (ZERO drop-off!)
	for s in 5:
		_add_box(Vector3(0, 0.06 + float(s) * 0.14, -28.0 - float(s) * 1.1), Vector3(14.0 - float(s) * 0.3, 0.16, 1.25), Color(0.20, 0.56, 0.36), "ApproachStep")
	# Flush top landing terrace connecting stair top directly to the Palace Doors (z = -33.2..-36.8)!
	_add_box(Vector3(0, 0.36, -35.0), Vector3(13.2, 0.72, 4.2), Color(0.22, 0.62, 0.40), "PalaceLandingTerrace")
	# Crystalline multi-spire Emerald Palace architecture matching Munchkinland's horizon skyline!
	WorldKit.build_emerald_palace_facade(self, Vector3(0, 0, -52))
	WorldKit.dress_ybr_spine(self, -6.0, 42.0, 3.6)
	WorldKit.scatter_swaying_grass(self, Vector3(0, 0, 18), 36.0, 110, 5.2)
	WorldKit.add_horizon_hills(self, 48.0, 58.0, Color(0.14, 0.36, 0.22))
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
	WorldKit.apply_aaa_post_processing(e, "emerald")
	env.environment = e
	add_child(env)
	_add_map_border(48.0, 58.0)

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
	# Columns widened to x = ±11.4 so the central Great Hall & Wizard reveal stage are 100% unobstructed!
	for x in [-11.4, 11.4]:
		for z in [-44.0, -52.0, -60.0]:
			_add_box(Vector3(x, 4.0, z), Vector3(1.4, 8.0, 1.4), Color(0.2, 0.55, 0.35), "HallCol")
	# Throne dais
	_add_box(Vector3(0, 0.45, -60), Vector3(10, 0.9, 6), Color(0.35, 0.28, 0.15), "ThroneDais")
	_add_box(Vector3(0, 1.4, -61.5), Vector3(3.2, 2.2, 1.6), Color(0.55, 0.45, 0.2), "ThroneSeat")
	# Full-width colossal Emerald & Gold Double Doors completely sealing the 10m archway until E!
	_palace_doors = WorldKit.build_palace_double_doors(self, Vector3(0, 0, -36.5), 10.0, 7.5)
	door_seal = StaticBody3D.new()
	door_seal.name = "PalaceDoorSeal"
	add_child(door_seal)
	door_seal.global_position = Vector3(0, 3.75, -36.5)
	door_seal.collision_layer = 1
	var dcs := CollisionShape3D.new()
	var dbox := BoxShape3D.new()
	dbox.size = Vector3(10.4, 7.6, 1.2)
	dcs.shape = dbox
	door_seal.add_child(dcs)
	WorldKit.make_building_crest_sign(self, Vector3(0, 8.6, -35.6), "GREAT HALL OF OZ", Color(0.22, 0.78, 0.45), false)
	WorldKit.make_world_badge(self, door_pos + Vector3(0, 3.4, 2.2), "✦  Palace Doors — Enter Great Hall (E)", Color(0.65, 1.0, 0.78), 14.0)
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
	## Sculpted 3D holographic visage of OZ THE GREAT AND POWERFUL (replaces flat green sphere).
	wizard_head = Node3D.new()
	wizard_head.name = "WizardProjection"
	add_child(wizard_head)
	wizard_head.global_position = Vector3(0, 7.2, -64.0)
	WorldKit.build_oz_projection_head(wizard_head)
	wizard_head.visible = false

func _build_curtain_and_body() -> void:
	# Place velvet curtain & Wizard completely clear of ThroneDais & side walls!
	curtain = Node3D.new()
	curtain.name = "Curtain"
	add_child(curtain)
	curtain.global_position = Vector3(7.2, 0.15, -55.2)
	_curtain_rig = WorldKit.build_velvet_curtain(curtain, curtain.global_position, 5.4, 6.2)
	WorldKit.make_world_badge(curtain, Vector3(0, 5.4, 0.4), "✦  Velvet Curtain — Pull (E)", Color(1.0, 0.78, 0.72), 16.0)
	# Sculpted Omaha Humbug Inventor + Brass Voice-Horn Console right behind the curtain, facing +Z!
	wizard_body = Node3D.new()
	wizard_body.name = "WizardBody"
	add_child(wizard_body)
	wizard_body.global_position = Vector3(7.2, 0.15, -56.4)
	wizard_body.scale = Vector3(1.18, 1.18, 1.18)
	wizard_body.visible = false
	WorldKit.build_humbug_wizard(wizard_body)
	WorldKit.make_world_badge(wizard_body, Vector3(0, 2.55, 0), "✦  Oscar Diggs — \"I'm a humbug…\"", Color(0.98, 0.90, 0.65), 16.0)
	_wizard_spot = OmniLight3D.new()
	_wizard_spot.light_color = Color(1.0, 0.88, 0.62)
	_wizard_spot.light_energy = 0.0
	_wizard_spot.omni_range = 14.0
	add_child(_wizard_spot)
	_wizard_spot.global_position = Vector3(7.2, 3.8, -52.5)

func _build_tailor_of_vices(at: Vector3) -> void:
	## Phase P8: The Tailor of Vices ornate Emerald Plaza Boutique (interactive outfit & Allure blessing!).
	var shop := Node3D.new()
	shop.name = "TailorOfVices"
	add_child(shop)
	shop.global_position = at
	_add_box(at + Vector3(0, 2.1, 0), Vector3(5.6, 4.2, 4.6), Color(0.18, 0.06, 0.16), "TailorShopBody")
	WorldKit.make_building_crest_sign(shop, Vector3(0, 4.45, 2.45), "THE TAILOR OF VICES", Color(0.94, 0.34, 0.62), false)
	WorldKit.make_world_badge(shop, Vector3(0, 2.9, 2.8), "✦  Boutique · Velvet Blessing (+25 Allure)", Color(1.0, 0.62, 0.84), 14.0)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = Vector3(0, 1.0, 3.0)
	shop.add_child(area)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.6
	cs.shape = sph
	area.add_child(cs)
	area.body_entered.connect(func(b):
		if b.is_in_group("player"):
			if not shop.has_meta("visited"):
				shop.set_meta("visited", true)
				var sm := get_node_or_null("/root/SaveManager")
				if sm and sm.has_method("add_desire"):
					sm.add_desire(25, "The Tailor of Vices")
			if hud and hud.get("shop_menu"):
				hud.get("shop_menu").call("open", "dorothy")
	)

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
	if _projection_dismissed or wizard_head == null or not wizard_head.visible:
		return
	_head_pulse += delta
	var s := 1.0 + sin(_head_pulse * 2.2) * 0.04
	wizard_head.scale = Vector3(s, s, s)
	var halo := wizard_head.get_node_or_null("HaloOuter") as Node3D
	if halo:
		halo.rotation.z = _head_pulse * 0.35
	var mouth := wizard_head.get_node_or_null("Mouth") as Node3D
	if mouth:
		mouth.position.y = -1.25 - absf(sin(_head_pulse * 5.5)) * 0.35

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
			_projection_dismissed = true
			if wizard_head and wizard_head.visible:
				var tw := create_tween()
				tw.tween_property(wizard_head, "scale", Vector3(0.02, 0.02, 0.02), 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				tw.tween_callback(func():
					if wizard_head:
						wizard_head.visible = false
				)
		Beat.CHOICE:
			hud.set_objective("The Wizard is only a man. E — take the Yellow Brick Road south to Glinda.")
			hud.set_prompt("E  —  \"I want to go home\" → Glinda / Road Home (L5)")
			_projection_dismissed = true
			if wizard_head:
				wizard_head.visible = false
			# Draw both pleated crimson-velvet drapes apart to reveal the little man & brass projector!
			var l_drape := _curtain_rig.get("left") as Node3D
			var r_drape := _curtain_rig.get("right") as Node3D
			if l_drape and r_drape:
				var ctw := create_tween().set_parallel(true)
				ctw.tween_property(l_drape, "scale:x", 0.22, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				ctw.tween_property(r_drape, "scale:x", 0.22, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			if _wizard_spot:
				var ltw := create_tween()
				ltw.tween_property(_wizard_spot, "light_energy", 4.2, 0.7)
			if wizard_body:
				wizard_body.visible = true
				var wtw := create_tween()
				wtw.tween_property(wizard_body, "global_position:z", -52.8, 0.95).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_say("Wizard: \"Pay no attention— I'm a humbug… just a little man from Omaha. Please don't tell anyone.\"")
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
		{"pos": Vector3(-14.5, 0, 12), "kind": "dance", "name": "Gate dance"},
		{"pos": Vector3(9, 0, -22), "kind": "giggle", "name": "Plaza giggle"},
	], "emerald")
