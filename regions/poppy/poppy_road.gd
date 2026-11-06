extends Node3D

## L3 · The Deadly Poppy Field (Baum ch.VIII–IX) — between Munchkin party and West.
## Flesh (Dorothy + Lion) both fall asleep in the scarlet scent on first pass.
## Scarecrow + Tin Man immune. Rescue is three clear pickups:
##   1) CLEAR AIR (south meadow) → wakes Dorothy, parks her south
##   2) MICE CART (east of road) → you must hold the cart
##   3) E on sleeping Lion with cart → haul south on YBR
## FINAL STEP = south West gate E.

const PLAYER_SCENE := preload("res://actors/dorothy/player.tscn")
const HUD_SCENE := preload("res://ui/play_hud.tscn")
const SCARECROW_SCENE := preload("res://actors/companions/scarecrow.tscn")
const LION_SCENE := preload("res://actors/companions/lion.tscn")
const TINMAN_SCENE := preload("res://actors/companions/tinman.tscn")
const WEST_SCENE := "res://regions/winkie/west_castle.tscn"
const EMERALD_SCENE := "res://regions/emerald_city/wizard_tower.tscn"

const PLAY_BOUND_X := 48.0
const PLAY_BOUND_Z := 70.0
const YBR_SPAWN := Vector3(0.0, 0.08, -58.0)
const POPPY_START_Z := -28.0
const POPPY_END_Z := 28.0
const SAFE_SOUTH := Vector3(0.0, 0.08, 38.0)
const CLEAR_AIR_POS := Vector3(0.0, 0.08, 36.0)
const LION_FALL := Vector3(0.0, 0.08, 8.0)
const DOROTHY_FALL := Vector3(0.0, 0.08, -4.0)
const CART_POS := Vector3(8.0, 0.08, 20.0)
const WEST_GATE := Vector3(0.0, 0.08, 58.0)

const SLEEP_RATE := 28.0
const SLEEP_MAX := 100.0

enum Beat {
	ENTER,
	WALK_FIELD,
	FLESH_DOWN,
	GET_CLEAR_AIR,
	GET_CART,
	HAUL_LION,
	ROAD_OPEN,
}

var hud: CanvasLayer
var player: CharacterBody3D
var scarecrow: CharacterBody3D
var lion: CharacterBody3D
var tinman: CharacterBody3D
var beat: Beat = Beat.ENTER
var compass: Label
var sleep_label: Label

var dorothy_sleep: float = 0.0
var lion_sleep: float = 0.0
var dorothy_asleep: bool = false
var lion_asleep: bool = false
var dorothy_safe: bool = false
var lion_safe: bool = false
var clear_air_got: bool = false
var cart_owned: bool = false
var hauling: bool = false

var clear_air: Node3D
var cart: Node3D
var _near_clear: bool = false
var _near_cart: bool = false
var _near_lion: bool = false
var _near_gate: bool = false
var _going: bool = false

func _enter_tree() -> void:
	var p := get_node_or_null("/root/Party")
	if p and p.has_method("reset_party"):
		p.reset_party()

func _ready() -> void:
	_build_world()
	_spawn_party()
	_spawn_set_pieces()
	_add_poppy_whimsy()
	_ensure_compass()
	_ensure_sleep_hud()
	if hud and hud.has_method("set_kansas_mode"):
		hud.set_kansas_mode(false)
	_set_beat(Beat.ENTER)
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("on_level_start"):
		lt.on_level_start("The Deadly Poppy Field")
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say"):
		d.say("Narrator", "The Yellow Brick Road runs on — but scarlet poppies crowd both sides. Their scent is deadly to flesh. Straw and tin feel nothing.", true, 4.5)
	await get_tree().create_timer(0.4).timeout
	if beat == Beat.ENTER:
		_set_beat(Beat.WALK_FIELD)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			_go_west("Playtest — hourglass to West…")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F11:
			_go_emerald()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F9:
			_go_west("The poppies thin — Winkie Country ahead…")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F8:
			_debug_skip_field()
			get_viewport().set_input_as_handled()

func _debug_skip_field() -> void:
	dorothy_asleep = false
	lion_asleep = false
	dorothy_safe = true
	lion_safe = true
	clear_air_got = true
	cart_owned = true
	hauling = false
	dorothy_sleep = 0.0
	lion_sleep = 0.0
	if player:
		player.visible = true
		if player.has_method("set_parked"):
			player.call("set_parked", false)
		player.global_position = SAFE_SOUTH + Vector3(-1.5, 0, 0)
	if lion:
		if lion.has_method("set_parked"):
			lion.call("set_parked", false)
		lion.global_position = SAFE_SOUTH + Vector3(1.5, 0, 0)
	_hide_node(clear_air)
	_hide_node(cart)
	for n in ["SafeDorothyLab", "LionAsleepLab", "DorothyAsleepLab"]:
		if has_node(n):
			get_node(n).queue_free()
	_set_beat(Beat.ROAD_OPEN)

func _process(delta: float) -> void:
	if player == null or _going:
		return
	_update_compass()
	_tick_flesh_sleep(delta)
	_tick_haul(delta)
	_pin_parked_bodies()
	var actor := _lead()
	if actor == null:
		return
	_near_clear = beat == Beat.GET_CLEAR_AIR and not clear_air_got and clear_air \
		and actor.global_position.distance_to(CLEAR_AIR_POS) < 4.5
	_near_cart = beat == Beat.GET_CART and not cart_owned and cart \
		and actor.global_position.distance_to(cart.global_position) < 4.5
	_near_lion = beat == Beat.HAUL_LION and lion_asleep and not lion_safe and not hauling and cart_owned \
		and actor.global_position.distance_to(lion.global_position if lion else LION_FALL) < 5.5
	_near_gate = beat == Beat.ROAD_OPEN and actor.global_position.distance_to(WEST_GATE) < 4.5
	if Input.is_action_just_pressed("interact"):
		if _near_gate:
			_go_west("The Yellow Brick Road leaves the poppies — West waits…")
		elif _near_clear:
			_collect_clear_air()
		elif _near_cart:
			_collect_cart()
		elif _near_lion:
			_start_haul()
		elif beat == Beat.HAUL_LION and not cart_owned and lion_asleep and not lion_safe \
				and actor.global_position.distance_to(lion.global_position if lion else LION_FALL) < 5.5:
			hud.set_prompt("Need the MICE CART first — compass east · E the brown cart")
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

func _lead_id() -> StringName:
	var party := get_node_or_null("/root/Party")
	if party and party.has_method("leader_id"):
		return party.call("leader_id") as StringName
	return &"dorothy"

func _in_poppy(pos: Vector3) -> bool:
	return pos.z >= POPPY_START_Z and pos.z <= POPPY_END_Z

## Both flesh bodies sleep from THEIR position — not only the Lead.
func _tick_flesh_sleep(delta: float) -> void:
	if beat >= Beat.ROAD_OPEN:
		dorothy_sleep = 0.0
		lion_sleep = 0.0
		_refresh_sleep_hud()
		return
	if player and not dorothy_asleep and not dorothy_safe:
		if _in_poppy(player.global_position):
			dorothy_sleep = minf(dorothy_sleep + delta * SLEEP_RATE, SLEEP_MAX)
		else:
			dorothy_sleep = maxf(dorothy_sleep - delta * 40.0, 0.0)
		if dorothy_sleep >= SLEEP_MAX:
			_drop_dorothy_asleep()
	if lion and not lion_asleep and not lion_safe:
		if _in_poppy(lion.global_position):
			lion_sleep = minf(lion_sleep + delta * SLEEP_RATE, SLEEP_MAX)
		else:
			lion_sleep = maxf(lion_sleep - delta * 40.0, 0.0)
		if lion_sleep >= SLEEP_MAX:
			_drop_lion_asleep()
	# Dorothy down → Lion cannot finish the crossing
	if dorothy_asleep and not dorothy_safe and not lion_asleep and lion:
		if lion.global_position.z >= POPPY_START_Z - 2.0:
			_drop_lion_asleep()
	_refresh_sleep_hud()

func _drop_dorothy_asleep() -> void:
	if dorothy_asleep or dorothy_safe:
		return
	dorothy_asleep = true
	dorothy_sleep = 0.0
	var drop := player.global_position if player else DOROTHY_FALL
	drop.y = 0.08
	drop.x = clampf(drop.x, -2.5, 2.5)
	if drop.z < POPPY_START_Z + 2.0:
		drop.z = POPPY_START_Z + 4.0
	if player and player.has_method("set_parked"):
		player.call("set_parked", true, drop)
	elif player:
		player.global_position = drop
	_ensure_asleep_marker("DorothyAsleepLab", drop, "DOROTHY — ASLEEP\n(needs CLEAR AIR south)", Color(1.0, 0.7, 0.85))
	if not lion_asleep and not lion_safe:
		_drop_lion_asleep()
	var party := get_node_or_null("/root/Party")
	if party and party.has_method("set_leader"):
		party.call("set_leader", &"scarecrow")
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say"):
		d.say("Narrator", "Dorothy and the Lion fall among the poppies. Scarecrow and Tin Man feel nothing — walk SOUTH and collect CLEAR AIR to wake Dorothy.", true, 5.0)
	_set_beat(Beat.FLESH_DOWN)
	_set_beat(Beat.GET_CLEAR_AIR)

func _drop_lion_asleep() -> void:
	if lion_asleep or lion_safe:
		return
	lion_asleep = true
	lion_sleep = 0.0
	if lion:
		if lion.has_method("set_parked"):
			lion.call("set_parked", true, LION_FALL)
		else:
			lion.global_position = LION_FALL
	_ensure_asleep_marker("LionAsleepLab", LION_FALL, "LION — ASLEEP\n(too heavy · need CART)", Color(1.0, 0.85, 0.35))
	var party := get_node_or_null("/root/Party")
	if party and party.has_method("set_leader"):
		var lid: StringName = _lead_id()
		if lid == &"lion" or lid == &"dorothy":
			if not party.call("set_leader", &"tinman"):
				party.call("set_leader", &"scarecrow")

func _collect_clear_air() -> void:
	if clear_air_got or not dorothy_asleep:
		return
	clear_air_got = true
	_hide_node(clear_air)
	dorothy_asleep = false
	dorothy_safe = true
	var safe_pos := SAFE_SOUTH + Vector3(-2.0, 0, 0)
	if player:
		player.visible = true
		if player.has_method("set_parked"):
			player.call("set_parked", true, safe_pos)
		else:
			player.global_position = safe_pos
	if has_node("DorothyAsleepLab"):
		get_node("DorothyAsleepLab").queue_free()
	_ensure_asleep_marker("SafeDorothyLab", safe_pos, "DOROTHY — SAFE\n(waits here · will not follow)", Color(0.75, 0.95, 1.0))
	if not lion_safe:
		lion_asleep = true
		if lion:
			if lion.has_method("set_parked"):
				lion.call("set_parked", true, LION_FALL)
			else:
				lion.global_position = LION_FALL
		_ensure_asleep_marker("LionAsleepLab", LION_FALL, "LION — ASLEEP\n(too heavy · need CART then E)", Color(1.0, 0.85, 0.35))
	if cart:
		cart.visible = true
		_ensure_cart_label()
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say"):
		d.say("Narrator", "Clear air wakes Dorothy. She stays south. The Lion is still too heavy — collect the MICE CART east of the road, then press E on the Lion.", true, 5.0)
	_set_beat(Beat.GET_CART)

func _collect_cart() -> void:
	if cart_owned:
		return
	cart_owned = true
	if cart:
		_ensure_cart_label()
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say"):
		d.say("Scarecrow", "The field mice hitch to the cart. Now walk to the sleeping Lion on the road and press E — then walk SOUTH.", true, 4.5)
	_set_beat(Beat.HAUL_LION)

func _start_haul() -> void:
	if hauling or lion_safe or not lion_asleep or not cart_owned:
		return
	hauling = true
	if lion and lion.has_method("set_parked"):
		lion.call("set_parked", false)
	if has_node("LionAsleepLab"):
		get_node("LionAsleepLab").queue_free()
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say"):
		d.say("Narrator", "The mice pull. Hold SOUTH on the Yellow Brick Road until the Lion wakes in clear air.", true, 3.5)
	hud.set_objective("HAULING Lion — walk SOUTH on the YBR until you leave the red field.")
	hud.set_prompt("Hold SOUTH — cart + Lion follow you out")

func _tick_haul(delta: float) -> void:
	var actor := _lead()
	if actor == null:
		return
	if cart_owned and cart and not lion_safe:
		var side := Vector3(1.5, 0, 0.2)
		if hauling:
			side = Vector3(1.5, 0, -0.2)
		cart.global_position = cart.global_position.lerp(
			actor.global_position + side, 1.0 - exp(-4.0 * delta)
		)
		cart.visible = true
	if not hauling or lion == null:
		return
	if cart:
		lion.global_position = cart.global_position + Vector3(-1.2, 0.1, 0)
	else:
		lion.global_position = lion.global_position.lerp(
			actor.global_position + Vector3(-1.2, 0, -0.5), 1.0 - exp(-2.5 * delta)
		)
	if actor.global_position.z >= POPPY_END_Z + 6.0 or (
		actor.global_position.z >= SAFE_SOUTH.z - 8.0 and not _in_poppy(actor.global_position)
	):
		_finish_haul()

func _finish_haul() -> void:
	hauling = false
	lion_asleep = false
	lion_safe = true
	var lion_safe_pos := SAFE_SOUTH + Vector3(2.0, 0, 0)
	if lion:
		if lion.has_method("set_parked"):
			lion.call("set_parked", false)
		lion.global_position = lion_safe_pos
	if cart:
		cart.global_position = SAFE_SOUTH + Vector3(4.0, 0, 0)
	if player and player.has_method("set_parked"):
		player.call("set_parked", false)
		player.global_position = SAFE_SOUTH + Vector3(-2.0, 0, 0)
	for n in ["SafeDorothyLab", "LionAsleepLab", "DorothyAsleepLab"]:
		if has_node(n):
			get_node(n).queue_free()
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say"):
		d.say("Narrator", "The Lion wakes in clear air. The poppies are behind you. The road runs on to the West.", true, 4.0)
	_set_beat(Beat.ROAD_OPEN)

func _pin_parked_bodies() -> void:
	if dorothy_safe and not lion_safe and player and player.has_method("set_parked"):
		var sp := SAFE_SOUTH + Vector3(-2.0, 0, 0)
		var p_on = player.get("parked")
		if p_on != true:
			player.call("set_parked", true, sp)
		else:
			player.set("park_pos", sp)
			if player.global_position.distance_to(sp) > 0.4:
				player.global_position = sp
	if lion_asleep and not hauling and not lion_safe and lion and lion.has_method("set_parked"):
		var l_on = lion.get("parked")
		if l_on != true:
			lion.call("set_parked", true, LION_FALL)
		else:
			lion.set("park_pos", LION_FALL)
			if lion.global_position.distance_to(LION_FALL) > 0.5:
				lion.global_position = LION_FALL

func _set_beat(next: Beat) -> void:
	beat = next
	match beat:
		Beat.ENTER:
			hud.set_objective("Yellow Brick Road — poppies crowd both sides. Stay alert.")
			hud.set_prompt("F8 skip field · F9/F10 → West · F11 Emerald")
		Beat.WALK_FIELD:
			hud.set_objective("Walk the YBR south. Dorothy and the Lion will grow sleepy in the scarlet scent — straw and tin do not.")
			hud.set_prompt("Sleep meters rise on Dorothy + Lion in the red field")
		Beat.FLESH_DOWN:
			hud.set_objective("Dorothy and Lion sleep in the poppies. Lead Scarecrow or Tin Man (2 / 3).")
			hud.set_prompt("Tab 2 or 3 · compass → CLEAR AIR south")
		Beat.GET_CLEAR_AIR:
			hud.set_objective("1/3  Walk SOUTH out of the red field. Collect CLEAR AIR (glowing blue orb) with Scarecrow or Tin Man — E.")
			hud.set_prompt("Compass → CLEAR AIR · E")
			if clear_air:
				clear_air.visible = true
		Beat.GET_CART:
			hud.set_objective("2/3  Collect the MICE CART east of the Yellow Brick Road — E. Dorothy waits safely south.")
			hud.set_prompt("Compass → MICE CART · E")
			if cart:
				cart.visible = true
				_ensure_cart_label()
		Beat.HAUL_LION:
			hud.set_objective("3/3  Walk to the sleeping LION on the road (you have the cart) and press E. Then walk SOUTH until clear air.")
			hud.set_prompt("Compass → Lion · E starts haul · then hold SOUTH")
			_ensure_asleep_marker("LionAsleepLab", LION_FALL, "LION — E with CART\nto haul south", Color(1.0, 0.9, 0.35))
		Beat.ROAD_OPEN:
			hud.set_objective("FINAL STEP (L3): Follow the Yellow Brick Road SOUTH to the glowing West gate — E.")
			hud.set_prompt("End-gate: YBR south · E on gate · F9/F10 West")
			_ensure_west_gate_label()

func _ensure_west_gate_label() -> void:
	if has_node("WestGateLab"):
		return
	var lab := Label3D.new()
	lab.name = "WestGateLab"
	lab.text = "YBR → WEST CASTLE\n(FINAL STEP · E)"
	lab.font_size = 44
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(0.95, 0.75, 0.25)
	add_child(lab)
	lab.global_position = WEST_GATE + Vector3(0, 4.0, 0)

func _ensure_asleep_marker(node_name: String, pos: Vector3, text: String, col: Color) -> void:
	var lab: Label3D
	if has_node(node_name):
		lab = get_node(node_name) as Label3D
	else:
		lab = Label3D.new()
		lab.name = node_name
		add_child(lab)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.text = text
	lab.font_size = 34
	lab.modulate = col
	lab.global_position = pos + Vector3(0, 3.0, 0)

func _ensure_cart_label() -> void:
	if cart == null:
		return
	for c in cart.get_children():
		if c is Label3D:
			var lab := c as Label3D
			if cart_owned:
				lab.text = "MICE CART — yours\n(walk to Lion · E)"
			else:
				lab.text = "MICE CART — E to take\n(required for Lion)"
			lab.font_size = 40
			lab.modulate = Color(1.0, 0.95, 0.4)

func _hide_node(n: Node3D) -> void:
	if n and is_instance_valid(n):
		n.visible = false

func _go_west(msg: String) -> void:
	if _going:
		return
	_going = true
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("go_to"):
		lt.go_to(WEST_SCENE, msg, "Winkie Country · the West castle")
	else:
		get_tree().change_scene_to_file(WEST_SCENE)

func _go_emerald() -> void:
	if _going:
		return
	_going = true
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("go_to"):
		lt.go_to(EMERALD_SCENE, "Playtest skip — Emerald…", "Emerald City · the Wizard's tower")
	else:
		get_tree().change_scene_to_file(EMERALD_SCENE)

func _build_world() -> void:
	_add_box(Vector3(0, -0.2, 0), Vector3(100, 0.4, 150), Color(0.35, 0.55, 0.32), "Ground")
	_add_box(Vector3(0, 0.05, 0), Vector3(5.8, 0.1, 130), Color(0.95, 0.82, 0.25), "YellowBrickRoad")
	for z in range(int(POPPY_START_Z), int(POPPY_END_Z) + 1, 6):
		_add_box(Vector3(-12, 0.4, float(z)), Vector3(14, 0.9, 5.5), Color(0.85, 0.15, 0.28), "PoppiesL")
		_add_box(Vector3(12, 0.4, float(z)), Vector3(14, 0.9, 5.5), Color(0.8, 0.12, 0.3), "PoppiesR")
		_add_box(Vector3(-12, 1.0, float(z)), Vector3(12, 0.25, 4.0), Color(1.0, 0.25, 0.4), "PoppyBloomL")
		_add_box(Vector3(12, 1.0, float(z)), Vector3(12, 0.25, 4.0), Color(1.0, 0.2, 0.35), "PoppyBloomR")
	_add_box(Vector3(0, 0.03, 42), Vector3(40, 0.08, 24), Color(0.4, 0.65, 0.38), "SafeMeadow")
	_add_box(WEST_GATE + Vector3(0, 0.02, 0), Vector3(7.0, 0.14, 7.0), Color(0.55, 0.2, 0.15), "WestGatePad")
	_add_box(CLEAR_AIR_POS + Vector3(0, 0.02, 0), Vector3(5.0, 0.12, 5.0), Color(0.35, 0.75, 1.0), "ClearAirPad")
	var ybr := Label3D.new()
	ybr.text = "YELLOW BRICK ROAD\n→ through the poppies"
	ybr.font_size = 42
	ybr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ybr.modulate = Color(1.0, 0.9, 0.4)
	add_child(ybr)
	ybr.global_position = Vector3(0, 3.5, -48)
	var warn := Label3D.new()
	warn.name = "PoppyWarn"
	warn.text = "DEADLY POPPY FIELD\nFlesh sleeps — straw & tin do not"
	warn.font_size = 40
	warn.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	warn.modulate = Color(1.0, 0.4, 0.45)
	add_child(warn)
	warn.global_position = Vector3(0, 4.0, POPPY_START_Z)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.92, 0.85)
	sun.light_energy = 1.05
	sun.rotation_degrees = Vector3(-52, 25, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.35, 0.45)
	fill.light_energy = 2.8
	fill.omni_range = 40.0
	add_child(fill)
	fill.global_position = Vector3(0, 6, 0)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.45, 0.55, 0.4)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.45, 0.4)
	e.ambient_light_energy = 0.85
	e.fog_enabled = true
	e.fog_light_color = Color(0.7, 0.25, 0.35)
	e.fog_density = 0.008
	env.environment = e
	add_child(env)
	_add_map_border(PLAY_BOUND_X + 4.0, PLAY_BOUND_Z + 4.0)
	var title := Label3D.new()
	title.text = "THE DEADLY\nPOPPY FIELD"
	title.font_size = 56
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.modulate = Color(1.0, 0.45, 0.5)
	add_child(title)
	title.global_position = Vector3(0, 9, -10)

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
	scarecrow.global_position = YBR_SPAWN + Vector3(-2.2, 0, 2.2)
	if scarecrow.has_method("free_from_pole"):
		scarecrow.free_from_pole()
	lion = LION_SCENE.instantiate()
	add_child(lion)
	lion.global_position = YBR_SPAWN + Vector3(2.2, 0, 2.5)
	if lion.has_method("calm_and_join"):
		lion.calm_and_join()
	elif lion.has_method("calm"):
		lion.calm()
	tinman = TINMAN_SCENE.instantiate()
	add_child(tinman)
	tinman.global_position = YBR_SPAWN + Vector3(0, 0, 3.2)
	if tinman.has_method("oil_and_free"):
		tinman.oil_and_free()

func _spawn_set_pieces() -> void:
	clear_air = Node3D.new()
	clear_air.name = "ClearAir"
	add_child(clear_air)
	clear_air.global_position = CLEAR_AIR_POS
	var orb := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.85
	sph.height = 1.7
	orb.mesh = sph
	var om := StandardMaterial3D.new()
	om.albedo_color = Color(0.45, 0.85, 1.0)
	om.emission_enabled = true
	om.emission = Color(0.4, 0.9, 1.0)
	om.emission_energy_multiplier = 2.4
	orb.material_override = om
	orb.position = Vector3(0, 1.2, 0)
	clear_air.add_child(orb)
	var olab := Label3D.new()
	olab.text = "CLEAR AIR\nE as Scarecrow or Tin Man\n(wakes Dorothy)"
	olab.font_size = 40
	olab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	olab.modulate = Color(0.7, 0.95, 1.0)
	olab.position = Vector3(0, 3.2, 0)
	clear_air.add_child(olab)
	var olight := OmniLight3D.new()
	olight.light_color = Color(0.5, 0.85, 1.0)
	olight.light_energy = 4.0
	olight.omni_range = 12.0
	clear_air.add_child(olight)
	olight.position = Vector3(0, 1.5, 0)
	clear_air.visible = false
	cart = Node3D.new()
	cart.name = "MiceCart"
	add_child(cart)
	cart.global_position = CART_POS
	var cb := MeshInstance3D.new()
	var cbox := BoxMesh.new()
	cbox.size = Vector3(2.6, 1.0, 3.4)
	cb.mesh = cbox
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.5, 0.32, 0.14)
	cm.emission_enabled = true
	cm.emission = Color(0.7, 0.5, 0.2)
	cm.emission_energy_multiplier = 0.55
	cb.material_override = cm
	cb.position = Vector3(0, 0.55, 0)
	cart.add_child(cb)
	for wx in [-1.1, 1.1]:
		for wz in [-1.2, 1.2]:
			var wh := MeshInstance3D.new()
			var wc := CylinderMesh.new()
			wc.top_radius = 0.35
			wc.bottom_radius = 0.35
			wc.height = 0.25
			wh.mesh = wc
			wh.rotation_degrees = Vector3(0, 0, 90)
			wh.position = Vector3(wx, 0.35, wz)
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color(0.2, 0.15, 0.1)
			wh.material_override = wm
			cart.add_child(wh)
	var clab := Label3D.new()
	clab.text = "MICE CART — E to take\n(required for Lion)"
	clab.font_size = 40
	clab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	clab.modulate = Color(1.0, 0.95, 0.4)
	clab.position = Vector3(0, 2.4, 0)
	cart.add_child(clab)
	cart.visible = false

func _add_poppy_whimsy() -> void:
	var w := get_node_or_null("/root/Whimsy")
	if w == null or not w.has_method("setup") or hud == null:
		return
	w.call("setup", self, hud, [
		{"pos": Vector3(8, 0, -50), "kind": "bounce", "name": "Roadside bounce"},
		{"pos": Vector3(-9, 0, -44), "kind": "giggle", "name": "Pre-field giggle"},
		{"pos": Vector3(10, 0, 44), "kind": "chime", "name": "Clear-air chime"},
		{"pos": Vector3(-8, 0, 48), "kind": "dance", "name": "Safe meadow dance"},
		{"pos": Vector3(9, 0, 52), "kind": "giggle", "name": "West-gate giggle"},
	], "candy")

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
	compass.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))

func _ensure_sleep_hud() -> void:
	sleep_label = Label.new()
	sleep_label.name = "SleepMeter"
	hud.add_child(sleep_label)
	sleep_label.position = Vector2(16, 100)
	sleep_label.add_theme_font_size_override("font_size", 15)
	sleep_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.55))
	_refresh_sleep_hud()

func _refresh_sleep_hud() -> void:
	if sleep_label == null:
		return
	var d_txt := "—"
	var l_txt := "—"
	if not dorothy_safe:
		if dorothy_asleep:
			d_txt = "ASLEEP"
		elif dorothy_sleep > 1.0:
			d_txt = "%.0f%%" % dorothy_sleep
	else:
		d_txt = "safe"
	if not lion_safe:
		if lion_asleep:
			l_txt = "ASLEEP"
		elif lion_sleep > 1.0:
			l_txt = "%.0f%%" % lion_sleep
	else:
		l_txt = "safe"
	sleep_label.text = "Poppy  Dorothy %s  ·  Lion %s" % [d_txt, l_txt]

func _update_compass() -> void:
	if compass == null:
		return
	var actor := _lead()
	if actor == null:
		return
	var target := WEST_GATE
	var label := "YBR south"
	match beat:
		Beat.WALK_FIELD:
			target = Vector3(0, 0, 0)
			label = "Through poppies"
		Beat.FLESH_DOWN, Beat.GET_CLEAR_AIR:
			target = CLEAR_AIR_POS
			label = "CLEAR AIR (E)"
		Beat.GET_CART:
			target = cart.global_position if cart else CART_POS
			label = "MICE CART (E)"
		Beat.HAUL_LION:
			if hauling:
				target = SAFE_SOUTH
				label = "Haul → clear air"
			else:
				target = lion.global_position if lion else LION_FALL
				label = "Lion (E with cart)"
		Beat.ROAD_OPEN:
			target = WEST_GATE
			label = "YBR → West (FINAL)"
	var dist := actor.global_position.distance_to(target)
	compass.text = "%s  ·  %.0fm" % [label, dist]

func _update_prompt() -> void:
	if _near_gate:
		hud.set_prompt("E  —  FINAL STEP: Yellow Brick Road to the West castle")
	elif _near_clear:
		hud.set_prompt("E  —  Collect CLEAR AIR (wakes Dorothy · she stays south)")
	elif _near_cart:
		hud.set_prompt("E  —  Take the MICE CART (required to haul the Lion)")
	elif _near_lion:
		hud.set_prompt("E  —  Hitch cart · haul Lion SOUTH out of the poppies")
	elif hauling:
		hud.set_prompt("HAULING — hold SOUTH on the Yellow Brick Road")
	elif beat == Beat.GET_CLEAR_AIR:
		hud.set_prompt("Compass → glowing CLEAR AIR south of the field · E")
	elif beat == Beat.GET_CART:
		hud.set_prompt("Compass → brown MICE CART east of road · E")
	elif beat == Beat.HAUL_LION and cart_owned:
		hud.set_prompt("Compass → sleeping Lion on YBR · E then walk SOUTH")
	else:
		var w := get_node_or_null("/root/Whimsy")
		if w and w.has_method("prompt_if_near"):
			var p: String = str(w.call("prompt_if_near"))
			if p != "":
				hud.set_prompt(p)

func _add_map_border(half_x: float, half_z: float) -> void:
	var h := 3.2
	var thick := 2.0
	var col := Color(0.25, 0.4, 0.22)
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
	var solid := not str(n).begins_with("Poppy")
	if solid:
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
	if color.r > 0.75 and color.b < 0.5:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.45
	if str(n).begins_with("ClearAir"):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.2
	mi.material_override = mat
	body.add_child(mi)
	return mi
