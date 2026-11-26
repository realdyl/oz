extends Node3D

## L6 · Kansas Homecoming — interactive finale (book-true).
## Baum: Silver Shoes carry Dorothy home; she lands on the prairie;
## Aunt Em finds her. The Wizard's balloon is HIS exit (L4), not Dorothy's ride.
## Mirror of L1: B&W farm, walk + E beats, cannot fail. F9 ends · F8 skip to Aunt.

const PLAYER_SCENE := preload("res://actors/dorothy/player.tscn")
const HUD_SCENE := preload("res://ui/play_hud.tscn")
const WorldKit := preload("res://systems/world_kit.gd")
const OzEncounters := preload("res://systems/oz_encounters.gd")

const PLAY_BOUND_X := 40.0
const PLAY_BOUND_Z := 36.0
const SPAWN := Vector3(6.0, 0.08, 18.0)
const AUNT_POS := Vector3(-2.0, 0.08, -4.0)
const UNCLE_POS := Vector3(-6.2, 0.08, -4.5)
const HOUSE_POS := Vector3(-2.0, 0.0, -10.0)
const PORCH_PAD := Vector3(-2.0, 0.08, -6.5)

enum Phase {
	LANDING,
	FIND_AUNT,
	REUNION,
	WALK_HOME,
	PORCH,
	EPILOGUE,
	DONE,
}

var hud: CanvasLayer
var player: CharacterBody3D
var aunt_em: Node3D
var uncle_henry: Node3D
var farmhouse: Node3D
var _wind_clothes: Array = []
var _windmill_rotor: Node3D = null
var _wind_t: float = 0.0
var fade: ColorRect
var compass: Label
var phase: Phase = Phase.LANDING
var _near_aunt: bool = false
var _near_uncle: bool = false
var _near_porch: bool = false
var _near_barn_door: bool = false
var _inside_barn: bool = false
var _barn_node: Node3D = null
var _barn_fitout: Node3D = null
var _near_coop_door: bool = false
var _inside_coop: bool = false
var _coop_node: Node3D = null
var _coop_fitout: Node3D = null
var _cam_out_len: float = 5.5
var _cam_out_fov: float = 65.0
var _cam_out_pitch: float = -18.0
var _aunt_line: int = 0
var _fade_t: float = 0.0
var _landing_t: float = 0.0
var _epilogue_t: float = 0.0
var _ended: bool = false

const AUNT_LINES := [
	"Aunt Em: \"Dorothy! My darling child — where in the world have you come from?!\"",
	"Dorothy: \"From the Land of Oz, Aunt Em! And look — Toto never left my side for a single second!\"",
	"Toto: \"*yip! yip!*\"",
	"Aunt Em: \"We thought the cyclone had carried you off for good. Oh, let me look at you — you're really home!\"",
	"Dorothy: \"I'm so glad to be home, Aunt Em. Even the grey prairie looks wonderful to me now.\"",
	"Aunt Em: \"Come on up to the porch, sweetheart. Henry's fixing that shutter you always hated.\"",
]

func _enter_tree() -> void:
	var p := get_node_or_null("/root/Party")
	if p and p.has_method("reset_party"):
		p.reset_party()

func _ready() -> void:
	_build_world()
	_spawn_cast()
	_ensure_compass()
	_ensure_fade()
	if hud and hud.has_method("set_kansas_mode"):
		hud.set_kansas_mode(true)
	phase = Phase.LANDING
	_landing_t = 0.0
	if hud:
		hud.set_objective("Kansas — the prairie after the shoes. You are home.")
		hud.set_prompt("The world is grey again…")
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("on_level_start"):
		lt.on_level_start("Kansas · homecoming")
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say"):
		d.say("Narrator", "The Silver Shoes carried her over the desert. They fell away. The prairie is grey — and real.", true, 4.5)
	# Soft landing settle, then FIND_AUNT
	await get_tree().create_timer(1.2).timeout
	if phase == Phase.LANDING:
		_set_phase(Phase.FIND_AUNT)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			_finish("The road rests — home.")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F5:
			get_tree().change_scene_to_file("res://ui/shell/title_screen.tscn")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F8:
			_aunt_line = AUNT_LINES.size()
			_set_phase(Phase.WALK_HOME)
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if player == null or _ended:
		return
	_update_compass()
	_wind_t += delta
	for ci in range(_wind_clothes.size()):
		var cl := _wind_clothes[ci] as Node3D
		if cl and is_instance_valid(cl):
			cl.rotation.x = sin(_wind_t * 2.4 + float(ci) * 0.9) * 0.22
	if _windmill_rotor and is_instance_valid(_windmill_rotor):
		_windmill_rotor.rotate_z(delta * 1.4)
	if phase == Phase.LANDING:
		_landing_t += delta
		if fade:
			fade.color = Color(1, 1, 1, clampf(1.0 - _landing_t * 0.7, 0.0, 0.85))
		return
	if phase == Phase.EPILOGUE:
		_epilogue_t += delta
		if fade:
			fade.color = Color(0.05, 0.04, 0.06, clampf(_epilogue_t * 0.35, 0.0, 0.92))
		if _epilogue_t >= 3.2 and not _ended:
			_finish("There's no place like the road that ends.")
		return
	_near_aunt = phase in [Phase.FIND_AUNT, Phase.REUNION] and player.global_position.distance_to(AUNT_POS) < 3.2
	_near_uncle = player.global_position.distance_to(UNCLE_POS) < 3.0
	_near_porch = phase in [Phase.WALK_HOME, Phase.PORCH] and player.global_position.distance_to(PORCH_PAD) < 3.5
	_near_barn_door = not _inside_barn and not _inside_coop and player.global_position.distance_to(Vector3(-20.0, 0.08, 17.8)) < 2.2
	_near_coop_door = not _inside_coop and not _inside_barn and player.global_position.distance_to(Vector3(22.0, 0.08, -11.4)) < 2.4
	if Input.is_action_just_pressed("interact"):
		if _inside_barn:
			_toggle_barn_interior(false)
		elif _inside_coop:
			_toggle_coop_interior(false)
		elif _near_barn_door:
			_toggle_barn_interior(true)
		elif _near_coop_door:
			_toggle_coop_interior(true)
		elif _near_aunt and phase == Phase.FIND_AUNT:
			_set_phase(Phase.REUNION)
			_advance_aunt()
		elif _near_aunt and phase == Phase.REUNION:
			_advance_aunt()
		elif _near_uncle:
			var du := get_node_or_null("/root/DialogueUI")
			if du and du.has_method("say"):
				du.say("Uncle Henry", "Dorothy! Bless my soul — the child is back, and Toto too! Come on up to the porch.", true, 4.0)
		elif _near_porch and phase == Phase.WALK_HOME:
			_set_phase(Phase.PORCH)
		elif _near_porch and phase == Phase.PORCH:
			_set_phase(Phase.EPILOGUE)
		else:
			var w := get_node_or_null("/root/Whimsy")
			if w and w.has_method("try_collect"):
				w.call("try_collect", player)
	_update_prompt()

func _set_phase(next: Phase) -> void:
	phase = next
	match phase:
		Phase.FIND_AUNT:
			hud.set_objective("Aunt Em is on the yard — walk to her. (B&W Kansas finale)")
			hud.set_prompt("Compass → Aunt Em · F8 skip reunion · F9 end")
			if fade:
				fade.color = Color(1, 1, 1, 0)
		Phase.REUNION:
			hud.set_objective("Speak with Aunt Em (E) — you are home.")
			hud.set_prompt("E advances Aunt Em")
		Phase.WALK_HOME:
			hud.set_objective("Walk to the farmhouse porch — the grey house stands.")
			hud.set_prompt("Compass → Porch · FINAL STEP ahead")
		Phase.PORCH:
			hud.set_objective("FINAL STEP (L6): E on the porch — rest. The road is done.")
			hud.set_prompt("E  —  Come home")
		Phase.EPILOGUE:
			hud.set_objective("Home.")
			hud.set_prompt("The hourglass rests…")
			var d := get_node_or_null("/root/DialogueUI")
			if d and d.has_method("say"):
				d.say("Narrator", "Oz is far. The companions remain in their gifts. Dorothy has the prairie — and Toto — and the road she walked.", true, 5.0)

func _advance_aunt() -> void:
	var p_cam := get_node_or_null("/root/Party")
	if _aunt_line >= AUNT_LINES.size():
		if p_cam and p_cam.has_method("exit_dialogue_shot"):
			p_cam.call("exit_dialogue_shot")
		_set_phase(Phase.WALK_HOME)
		return
	var line: String = AUNT_LINES[_aunt_line]
	_aunt_line += 1
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say_line"):
		d.say_line(line, true)
	elif hud:
		hud.set_prompt(line)
	if p_cam and p_cam.has_method("enter_dialogue_shot") and aunt_em and player:
		var dor_sp := line.begins_with("Dorothy:") or line.begins_with("Toto:")
		p_cam.call("enter_dialogue_shot", player if dor_sp else aunt_em, aunt_em if dor_sp else player, dor_sp)
	if _aunt_line >= AUNT_LINES.size():
		if p_cam and p_cam.has_method("exit_dialogue_shot"):
			p_cam.call("exit_dialogue_shot")
		_set_phase(Phase.WALK_HOME)

func _finish(msg: String) -> void:
	if _ended:
		return
	_ended = true
	phase = Phase.DONE
	if hud:
		hud.set_objective("The Road Home — complete.")
		hud.set_prompt(msg)
	var sm_end := get_node_or_null("/root/SaveManager")
	if sm_end and sm_end.has_method("unlock_velvet_road"):
		sm_end.call("unlock_velvet_road")
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("play_exit"):
		lt.play_exit(msg)
	# Stay on scene after sting — unlock New Game+ ("The Velvet Road") & F5 Title Screen!
	await get_tree().create_timer(2.4).timeout
	if hud:
		hud.set_prompt("★ THE VELVET ROAD (NG+) UNLOCKED · [F5] Title & Chapter Select · [J] Grimoire")

func _build_world() -> void:
	_add_box(Vector3(0, -0.2, 0), Vector3(90, 0.4, 80), Color(0.42, 0.42, 0.44), "Ground")
	_add_box(Vector3(0, -0.2, -20), Vector3(70, 0.4, 40), Color(0.4, 0.4, 0.42), "GroundN")
	# Dirt path to house (grey)
	_add_box(Vector3(2, 0.04, 6), Vector3(4.0, 0.08, 28), Color(0.48, 0.46, 0.42), "Path")
	# Farmhouse dressed with full Kansas storybook architecture (matching L1 farmyard!)
	farmhouse = Node3D.new()
	farmhouse.name = "Farmhouse"
	add_child(farmhouse)
	farmhouse.global_position = HOUSE_POS
	_add_box_to(farmhouse, Vector3(0, 2.0, 0), Vector3(7.0, 4.0, 5.5), Color(0.48, 0.48, 0.50), "HouseBody")
	WorldKit.dress_cottage_exterior(farmhouse, 3.5, 2.75, 4.0, Color(0.48, 0.48, 0.50), Color(0.28, 0.28, 0.31))
	WorldKit.make_building_crest_sign(farmhouse, Vector3(0, 4.15, 3.1), "GALE FARMHOUSE", Color(0.55, 0.55, 0.58), true)
	OzEncounters.spawn_monument(self, Vector3(-5.8, 0.0, -6.2), "chime", "Porch Memory Album", "", Color(0.88, 0.90, 0.94), 25, "", "kansas_locket")
	# Matching L1 Kansas landmarks: Barn, Clothesline, Lattice Windmill, Prairie Grass & Horizon Hills
	var barn := Node3D.new()
	barn.name = "Barn"
	add_child(barn)
	barn.global_position = Vector3(-20.0, 0.0, 14.0)
	_barn_node = barn
	_add_box_to(barn, Vector3(0, 2.25, 0), Vector3(7.0, 4.5, 6.0), Color(0.36, 0.36, 0.39), "BarnBody")
	WorldKit.dress_cottage_exterior(barn, 3.5, 3.0, 4.5, Color(0.36, 0.36, 0.39), Color(0.22, 0.22, 0.25), true)
	WorldKit.make_building_crest_sign(barn, Vector3(0, 4.6, 3.3), "BARN", Color(0.45, 0.45, 0.48), true)
	_build_barn_interior(barn)
	# Matching L1 Kansas Chicken Coop + Swinging Fence Gate + 5 sculpted 3D chickens + Enterable Interior!
	var coop := StaticBody3D.new()
	coop.name = "ChickenCoop"
	add_child(coop)
	coop.global_position = Vector3(22.0, 0.0, -14.0)
	_coop_node = coop
	WorldKit.build_chicken_coop(coop)
	var cc := CollisionShape3D.new()
	var csh := BoxShape3D.new()
	csh.size = Vector3(3.4, 2.2, 2.6)
	cc.shape = csh
	cc.position = Vector3(0, 1.1, 0)
	coop.add_child(cc)
	_build_coop_interior(coop)
	_wind_clothes = WorldKit.build_clothesline(self, Vector3(8.0, 0.0, 4.0))
	_windmill_rotor = WorldKit.build_lattice_windmill(self, Vector3(-26.0, 0.0, -10.0))
	WorldKit.scatter_swaying_grass(self, Vector3(0, 0, 4), 32.0, 100, 4.8)
	# Porch pad (FINAL STEP)
	_add_box(PORCH_PAD + Vector3(0, -0.02, 0), Vector3(5.5, 0.08, 4.0), Color(0.55, 0.55, 0.58), "PorchPad")
	WorldKit.make_world_badge(self, PORCH_PAD + Vector3(0, 2.6, 0), "✦  Home Porch — Final Step (E)", Color(0.94, 0.94, 0.98), 14.0)
	# Fence posts
	for x in [-14.0, -8.0, 4.0, 10.0, 16.0]:
		_add_box(Vector3(x, 0.7, 12), Vector3(0.25, 1.4, 0.25), Color(0.38, 0.36, 0.34), "Fence")
	# Distant balloon silhouette — Wizard's exit only (not Dorothy's ride). Ambient flavor.
	var balloon := MeshInstance3D.new()
	balloon.name = "WizardBalloonFar"
	var sph := SphereMesh.new()
	sph.radius = 1.8
	sph.height = 3.6
	balloon.mesh = sph
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.55, 0.55, 0.58)
	bm.emission_enabled = true
	bm.emission = Color(0.5, 0.5, 0.52)
	bm.emission_energy_multiplier = 0.15
	balloon.material_override = bm
	add_child(balloon)
	balloon.global_position = Vector3(28, 22, -30)
	var basket_m := MeshInstance3D.new()
	var boxm := BoxMesh.new()
	boxm.size = Vector3(1.2, 0.8, 1.2)
	basket_m.mesh = boxm
	basket_m.material_override = bm
	balloon.add_child(basket_m)
	basket_m.position = Vector3(0, -2.6, 0)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.85, 0.85, 0.88)
	sun.light_energy = 0.85
	sun.rotation_degrees = Vector3(-48, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.55, 0.58)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.58)
	e.ambient_light_energy = 0.75
	e.adjustment_enabled = true
	e.adjustment_saturation = 0.05
	WorldKit.apply_sky_and_weather_to_env(e, "homecoming")
	env.environment = e
	add_child(env)
	_add_map_border(PLAY_BOUND_X + 4.0, PLAY_BOUND_Z + 4.0)
	WorldKit.add_horizon_hills(self, PLAY_BOUND_X + 4.0, PLAY_BOUND_Z + 4.0, Color(0.34, 0.34, 0.37))

func _spawn_cast() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = SPAWN
	# Shoes carried her; they fall away in the desert — no Oz power on home soil.
	if player.has_method("set_kansas_locked"):
		player.set_kansas_locked(true)
	# PlayHUD automatically spawns the real sculpted, playable 3D Cairn Terrier Toto!
	# Aunt Em (exact same articulated character visual as L1 Kansas!)
	aunt_em = CharacterBody3D.new()
	aunt_em.name = "AuntEm"
	add_child(aunt_em)
	aunt_em.global_position = AUNT_POS
	WorldKit.build_kansas_farmer(aunt_em, true)
	WorldKit.make_world_badge(aunt_em, Vector3(0, 2.25, 0), "✦  Aunt Em", Color(0.94, 0.94, 0.98), 12.0)
	# Uncle Henry on the yard beside Aunt Em!
	uncle_henry = CharacterBody3D.new()
	uncle_henry.name = "UncleHenry"
	add_child(uncle_henry)
	uncle_henry.global_position = UNCLE_POS
	WorldKit.build_kansas_farmer(uncle_henry, false)
	WorldKit.make_world_badge(uncle_henry, Vector3(0, 2.25, 0), "✦  Uncle Henry", Color(0.94, 0.94, 0.98), 12.0)
	# Soft whimsy — grey prairie only
	var w := get_node_or_null("/root/Whimsy")
	if w and w.has_method("setup") and hud:
		w.call("setup", self, hud, [
			{"pos": Vector3(12, 0, 10), "kind": "bounce", "name": "Prairie bounce"},
			{"pos": Vector3(-10, 0, 8), "kind": "giggle", "name": "Dust giggle"},
			{"pos": Vector3(8, 0, -2), "kind": "chime", "name": "Fence chime"},
		], "kansas")

func _ensure_fade() -> void:
	fade = hud.get_node_or_null("Fade") as ColorRect
	if fade == null:
		fade = ColorRect.new()
		fade.name = "Fade"
		fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.z_index = 20
		hud.add_child(fade)
	fade.color = Color(1, 1, 1, 0.85)
	fade.visible = true

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
	compass.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))

func _update_compass() -> void:
	if compass == null or player == null:
		return
	match phase:
		Phase.FIND_AUNT, Phase.REUNION:
			var d := player.global_position.distance_to(AUNT_POS)
			compass.text = "Aunt Em  ·  %.0fm" % d
		Phase.WALK_HOME, Phase.PORCH:
			var d2 := player.global_position.distance_to(PORCH_PAD)
			compass.text = "Home porch (FINAL)  ·  %.0fm" % d2
		Phase.EPILOGUE, Phase.DONE:
			compass.text = "Home — the road rests"
		_:
			compass.text = "Kansas homecoming"

func _update_prompt() -> void:
	if _inside_barn:
		hud.set_prompt("E  —  Exit Barn")
	elif _inside_coop:
		hud.set_prompt("E  —  Exit Chicken Coop")
	elif _near_barn_door:
		hud.set_prompt("E  —  Enter Barn")
	elif _near_coop_door:
		hud.set_prompt("E  —  Enter Chicken Coop")
	elif _near_aunt and phase in [Phase.FIND_AUNT, Phase.REUNION]:
		hud.set_prompt("E  —  Talk to Aunt Em")
	elif _near_porch and phase == Phase.WALK_HOME:
		hud.set_prompt("E  —  Step onto the porch")
	elif _near_porch and phase == Phase.PORCH:
		hud.set_prompt("E  —  FINAL STEP: Come home")
	else:
		var w := get_node_or_null("/root/Whimsy")
		if w and w.has_method("prompt_if_near"):
			var p: String = str(w.call("prompt_if_near"))
			if p != "":
				hud.set_prompt(p)

func _add_map_border(half_x: float, half_z: float) -> void:
	var h := 3.0
	var thick := 2.0
	var col := Color(0.32, 0.32, 0.34)
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
	mi.material_override = mat
	body.add_child(mi)
	return mi

func _add_box_to(parent: Node3D, pos: Vector3, size: Vector3, color: Color, n: String) -> void:
	var body := StaticBody3D.new()
	body.name = n
	parent.add_child(body)
	body.position = pos
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
	mi.material_override = mat
	body.add_child(mi)

func _build_barn_interior(host: Node3D) -> void:
	_barn_fitout = Node3D.new()
	_barn_fitout.name = "InteriorFitout"
	_barn_fitout.visible = false
	host.add_child(_barn_fitout)
	var hw := 3.8
	var hd := 3.4
	var wh := 3.6
	for spec in [
		[Vector3(0, 0.03, 0), Vector3(hw * 2.0, 0.06, hd * 2.0), Color(0.32, 0.32, 0.35)],
		[Vector3(0, wh * 0.5, -hd), Vector3(hw * 2.0, wh, 0.14), Color(0.52, 0.52, 0.56)],
		[Vector3(-hw, wh * 0.5, 0), Vector3(0.14, wh, hd * 2.0), Color(0.46, 0.46, 0.50)],
		[Vector3(hw, wh * 0.5, 0), Vector3(0.14, wh, hd * 2.0), Color(0.46, 0.46, 0.50)],
		[Vector3(0, wh * 0.5, hd), Vector3(hw * 2.0, wh, 0.14), Color(0.48, 0.48, 0.52)],
		[Vector3(0, 1.08, hd - 0.14), Vector3(1.18, 2.12, 0.08), Color(0.22, 0.22, 0.25)],
		[Vector3(0, wh, 0), Vector3(hw * 2.0, 0.14, hd * 2.0), Color(0.28, 0.28, 0.31)],
		[Vector3(-2.5, 0.65, -2.2), Vector3(1.5, 1.3, 1.8), Color(0.38, 0.38, 0.41)],
		[Vector3(2.5, 0.55, -2.2), Vector3(1.4, 1.1, 1.6), Color(0.44, 0.44, 0.47)],
	]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = spec[1]
		m.mesh = b
		var sm := StandardMaterial3D.new()
		sm.albedo_color = spec[2]
		m.material_override = sm
		m.position = spec[0]
		_barn_fitout.add_child(m)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.95, 0.95, 1.0)
	lamp.light_energy = 2.8
	lamp.omni_range = 12.0
	lamp.position = Vector3(0, wh - 0.65, 0)
	_barn_fitout.add_child(lamp)
	WorldKit.make_world_badge(_barn_fitout, Vector3(0, 2.45, hd - 0.24), "✦  Exit Barn (E)", Color(0.96, 0.96, 1.0), 10.0)
	WorldKit.add_interior_wall_colliders(_barn_fitout, hw, hd, wh)
	WorldKit.add_interior_activities(_barn_fitout, "homecoming_barn", "", Vector3(1.6, 0.06, -0.8), Vector3.ZERO, true)

func _toggle_barn_interior(enter: bool) -> void:
	if player == null or _barn_node == null or _barn_fitout == null:
		return
	_inside_barn = enter
	for c in _barn_node.find_children("*", "CollisionShape3D", true, false):
		if _barn_fitout.is_ancestor_of(c):
			continue
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = enter
	WorldKit.set_interior_colliders_enabled(_barn_fitout, enter)
	for n in _barn_node.find_children("*", "MeshInstance3D", true, false):
		if _barn_fitout.is_ancestor_of(n):
			continue
		if n is MeshInstance3D:
			(n as MeshInstance3D).visible = not enter
	_barn_fitout.visible = enter
	player.global_position = Vector3(-20.0, 0.14, 14.4) if enter else Vector3(-20.0, 0.14, 18.2)
	player.velocity = Vector3.ZERO
	var pivot := player.find_child("CameraPivot", true, false) as Node3D
	if pivot:
		var arm := pivot.find_child("SpringArm3D", true, false) as SpringArm3D
		var cam := pivot.find_child("Camera3D", true, false) as Camera3D
		if arm and cam:
			if enter:
				_cam_out_len = arm.spring_length
				_cam_out_fov = cam.fov
				_cam_out_pitch = arm.rotation_degrees.x
				arm.spring_length = 2.45
				arm.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
				cam.fov = 72.0
			else:
				arm.spring_length = _cam_out_len
				arm.rotation_degrees = Vector3(_cam_out_pitch, 0.0, 0.0)
				cam.fov = _cam_out_fov

func _build_coop_interior(host: Node3D) -> void:
	_coop_fitout = Node3D.new()
	_coop_fitout.name = "CoopInteriorFitout"
	_coop_fitout.visible = false
	host.add_child(_coop_fitout)
	var hw := 2.6
	var hd := 2.2
	var wh := 2.8
	for spec in [
		[Vector3(0, 0.03, 0), Vector3(hw * 2.0, 0.06, hd * 2.0), Color(0.36, 0.35, 0.34)],
		[Vector3(0, wh * 0.5, -hd), Vector3(hw * 2.0, wh, 0.14), Color(0.50, 0.50, 0.52)],
		[Vector3(-hw, wh * 0.5, 0), Vector3(0.14, wh, hd * 2.0), Color(0.45, 0.45, 0.48)],
		[Vector3(hw, wh * 0.5, 0), Vector3(0.14, wh, hd * 2.0), Color(0.45, 0.45, 0.48)],
		[Vector3(0, wh * 0.5, hd), Vector3(hw * 2.0, wh, 0.14), Color(0.47, 0.47, 0.50)],
		[Vector3(0, 1.0, hd - 0.14), Vector3(1.05, 1.95, 0.08), Color(0.22, 0.22, 0.25)],
		[Vector3(0, wh, 0), Vector3(hw * 2.0, 0.14, hd * 2.0), Color(0.28, 0.28, 0.31)],
		# Nesting boxes & straw roosting perches
		[Vector3(-1.7, 0.35, -1.4), Vector3(1.2, 0.7, 0.85), Color(0.40, 0.39, 0.38)],
		[Vector3(1.7, 0.35, -1.4), Vector3(1.2, 0.7, 0.85), Color(0.40, 0.39, 0.38)],
		[Vector3(0.0, 0.85, -1.6), Vector3(2.2, 0.10, 0.14), Color(0.34, 0.34, 0.36)],
	]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = spec[1]
		m.mesh = b
		var sm := StandardMaterial3D.new()
		sm.albedo_color = spec[2]
		m.material_override = sm
		m.position = spec[0]
		_coop_fitout.add_child(m)
	# Animated sculpted chickens pecking & roosting inside the coop!
	for cp in [Vector3(-1.5, 0.72, -1.4), Vector3(1.5, 0.72, -1.4), Vector3(-0.6, 0.06, -0.3)]:
		WorldKit.build_chicken_visual(_coop_fitout, cp, 0.0)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.96, 0.96, 1.0)
	lamp.light_energy = 2.4
	lamp.omni_range = 10.0
	lamp.position = Vector3(0, wh - 0.55, 0)
	_coop_fitout.add_child(lamp)
	WorldKit.make_world_badge(_coop_fitout, Vector3(0, 2.2, hd - 0.24), "✦  Exit Chicken Coop (E)", Color(0.96, 0.96, 1.0), 10.0)
	WorldKit.add_interior_wall_colliders(_coop_fitout, hw, hd, wh)
	WorldKit.add_interior_activities(_coop_fitout, "homecoming_coop", "", Vector3(1.1, 0.06, 0.1), Vector3.ZERO, true)

func _toggle_coop_interior(enter: bool) -> void:
	if player == null or _coop_node == null or _coop_fitout == null:
		return
	_inside_coop = enter
	for c in _coop_node.find_children("*", "CollisionShape3D", true, false):
		if _coop_fitout.is_ancestor_of(c):
			continue
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = enter
	WorldKit.set_interior_colliders_enabled(_coop_fitout, enter)
	for n in _coop_node.find_children("*", "MeshInstance3D", true, false):
		if _coop_fitout.is_ancestor_of(n):
			continue
		if n is MeshInstance3D:
			(n as MeshInstance3D).visible = not enter
	_coop_fitout.visible = enter
	player.global_position = Vector3(22.0, 0.14, -13.5) if enter else Vector3(22.0, 0.14, -10.8)
	player.velocity = Vector3.ZERO
	var pivot := player.find_child("CameraPivot", true, false) as Node3D
	if pivot:
		var arm := pivot.find_child("SpringArm3D", true, false) as SpringArm3D
		var cam := pivot.find_child("Camera3D", true, false) as Camera3D
		if arm and cam:
			if enter:
				_cam_out_len = arm.spring_length
				_cam_out_fov = cam.fov
				_cam_out_pitch = arm.rotation_degrees.x
				arm.spring_length = 2.2
				arm.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
				cam.fov = 72.0
			else:
				arm.spring_length = _cam_out_len
				arm.rotation_degrees = Vector3(_cam_out_pitch, 0.0, 0.0)
				cam.fov = _cam_out_fov
