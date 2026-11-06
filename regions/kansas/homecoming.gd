extends Node3D

## L6 · Kansas Homecoming — interactive finale (book-true).
## Baum: Silver Shoes carry Dorothy home; she lands on the prairie;
## Aunt Em finds her. The Wizard's balloon is HIS exit (L4), not Dorothy's ride.
## Mirror of L1: B&W farm, walk + E beats, cannot fail. F9 ends · F8 skip to Aunt.

const PLAYER_SCENE := preload("res://actors/dorothy/player.tscn")
const HUD_SCENE := preload("res://ui/play_hud.tscn")

const PLAY_BOUND_X := 40.0
const PLAY_BOUND_Z := 36.0
const SPAWN := Vector3(6.0, 0.08, 18.0)
const AUNT_POS := Vector3(-2.0, 0.08, -4.0)
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
var farmhouse: Node3D
var fade: ColorRect
var compass: Label
var phase: Phase = Phase.LANDING
var _near_aunt: bool = false
var _near_porch: bool = false
var _aunt_line: int = 0
var _fade_t: float = 0.0
var _landing_t: float = 0.0
var _epilogue_t: float = 0.0
var _ended: bool = false

const AUNT_LINES := [
	"Aunt Em: \"Dorothy! My darling child — where have you been?\"",
	"Aunt Em: \"We thought the cyclone had taken you for good. Toto too!\"",
	"Aunt Em: \"You're home now. The prairie is grey, but it's ours.\"",
	"Aunt Em: \"Come to the house. Henry's fixing the shutter you always hated.\"",
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
		elif event.keycode == KEY_F8:
			_aunt_line = AUNT_LINES.size()
			_set_phase(Phase.WALK_HOME)
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if player == null or _ended:
		return
	_update_compass()
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
	_near_porch = phase in [Phase.WALK_HOME, Phase.PORCH] and player.global_position.distance_to(PORCH_PAD) < 3.5
	if Input.is_action_just_pressed("interact"):
		if _near_aunt and phase == Phase.FIND_AUNT:
			_set_phase(Phase.REUNION)
			_advance_aunt()
		elif _near_aunt and phase == Phase.REUNION:
			_advance_aunt()
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
	if _aunt_line >= AUNT_LINES.size():
		_set_phase(Phase.WALK_HOME)
		return
	var line: String = AUNT_LINES[_aunt_line]
	_aunt_line += 1
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say_line"):
		d.say_line(line, true)
	elif hud:
		hud.set_prompt(line)
	if _aunt_line >= AUNT_LINES.size():
		_set_phase(Phase.WALK_HOME)

func _finish(msg: String) -> void:
	if _ended:
		return
	_ended = true
	phase = Phase.DONE
	if hud:
		hud.set_objective("The Road Home — complete.")
		hud.set_prompt(msg)
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("play_exit"):
		lt.play_exit(msg)
	# Stay on scene after sting — prototype credits hold. No loop to L1 unless F9 again.
	await get_tree().create_timer(2.4).timeout
	if hud:
		hud.set_prompt("Spine complete · F5 replay from Kansas · Oz remembers.")

func _build_world() -> void:
	_add_box(Vector3(0, -0.2, 0), Vector3(90, 0.4, 80), Color(0.42, 0.42, 0.44), "Ground")
	_add_box(Vector3(0, -0.2, -20), Vector3(70, 0.4, 40), Color(0.4, 0.4, 0.42), "GroundN")
	# Dirt path to house (grey)
	_add_box(Vector3(2, 0.04, 6), Vector3(4.0, 0.08, 28), Color(0.48, 0.46, 0.42), "Path")
	# Farmhouse mass
	farmhouse = Node3D.new()
	farmhouse.name = "Farmhouse"
	add_child(farmhouse)
	farmhouse.global_position = HOUSE_POS
	_add_box_to(farmhouse, Vector3(0, 2.0, 0), Vector3(7.0, 4.0, 5.5), Color(0.5, 0.5, 0.52), "HouseBody")
	_add_box_to(farmhouse, Vector3(0, 4.6, 0), Vector3(8.0, 1.2, 6.2), Color(0.35, 0.35, 0.38), "Roof")
	# Porch pad (FINAL STEP)
	_add_box(PORCH_PAD + Vector3(0, 0.02, 0), Vector3(5.5, 0.12, 4.0), Color(0.55, 0.55, 0.58), "PorchPad")
	var porch_lab := Label3D.new()
	porch_lab.text = "HOME\n(FINAL STEP · E)"
	porch_lab.font_size = 44
	porch_lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	porch_lab.modulate = Color(0.9, 0.9, 0.92)
	add_child(porch_lab)
	porch_lab.global_position = PORCH_PAD + Vector3(0, 3.5, 0)
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
	var blab := Label3D.new()
	blab.text = "a balloon drifts far\n(the Wizard's — not yours)"
	blab.font_size = 28
	blab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	blab.modulate = Color(0.7, 0.7, 0.72)
	balloon.add_child(blab)
	blab.position = Vector3(0, 3.5, 0)
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
	env.environment = e
	add_child(env)
	_add_map_border(PLAY_BOUND_X + 4.0, PLAY_BOUND_Z + 4.0)
	var title := Label3D.new()
	title.text = "KANSAS\nHomecoming"
	title.font_size = 56
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.modulate = Color(0.85, 0.85, 0.88)
	add_child(title)
	title.global_position = Vector3(0, 8, 8)

func _spawn_cast() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = SPAWN
	# Shoes carried her; they fall away in the desert — no Oz power on home soil.
	if player.has_method("set_kansas_locked"):
		player.set_kansas_locked(true)
	# Toto marker
	var toto := MeshInstance3D.new()
	toto.name = "Toto"
	var ts := SphereMesh.new()
	ts.radius = 0.28
	ts.height = 0.45
	toto.mesh = ts
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.25, 0.22, 0.2)
	toto.material_override = tm
	add_child(toto)
	toto.global_position = SPAWN + Vector3(0.8, 0.25, 0.4)
	# Aunt Em
	aunt_em = CharacterBody3D.new()
	aunt_em.name = "AuntEm"
	add_child(aunt_em)
	aunt_em.global_position = AUNT_POS
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.45
	cyl.height = 1.5
	body.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.55, 0.58)
	body.material_override = mat
	body.position = Vector3(0, 0.85, 0)
	aunt_em.add_child(body)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.22
	hs.height = 0.44
	head.mesh = hs
	head.material_override = mat
	head.position = Vector3(0, 1.8, 0)
	aunt_em.add_child(head)
	var lab := Label3D.new()
	lab.text = "AUNT EM"
	lab.font_size = 40
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(0.9, 0.9, 0.92)
	lab.position = Vector3(0, 2.8, 0)
	aunt_em.add_child(lab)
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
	if _near_aunt and phase in [Phase.FIND_AUNT, Phase.REUNION]:
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
