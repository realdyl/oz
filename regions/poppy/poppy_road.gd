extends Node3D

## L3 · The Deadly Poppy Field (Baum ch.VIII–IX) — between Munchkin party and West.
## Flesh sleeps in the scarlet scent; Scarecrow + Tin Man are immune.
## Carry Dorothy out → Lion too heavy → save Field-Mouse Queen → mice cart → West gate.
## YBR continuous N→S. FINAL STEP = south open road E → West castle.

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
const LION_FALL := Vector3(0.0, 0.08, 8.0)
const QUEEN_POS := Vector3(10.0, 0.08, 14.0)
const WILDCAT_POS := Vector3(14.0, 0.08, 12.0)
const CART_POS := Vector3(6.0, 0.08, 16.0)
const WEST_GATE := Vector3(0.0, 0.08, 58.0)

enum Beat {
	ENTER,
	WALK_FIELD,
	DOROTHY_DOWN,
	CARRY_DOROTHY,
	LION_DOWN,
	SAVE_QUEEN,
	MICE_CART,
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
var sleep_meter: float = 0.0
var dorothy_asleep: bool = false
var lion_asleep: bool = false
var dorothy_carried: bool = false
var dorothy_safe: bool = false
var lion_safe: bool = false
var queen_saved: bool = false
var cart_ready: bool = false
var hauling: bool = false
var queen: Node3D
var wildcat: Node3D
var cart: Node3D
var sleep_label: Label
var _near_dorothy: bool = false
var _near_lion: bool = false
var _near_queen: bool = false
var _near_cat: bool = false
var _near_cart: bool = false
var _near_gate: bool = false
var _queen_line: int = 0
var _going: bool = false

const QUEEN_LINES := [
	"Mouse Queen: \"You saved me from the wildcat. I am Queen of the Field Mice.\"",
	"Mouse Queen: \"The Lion is too heavy for two wood-and-straw friends. My people will pull.\"",
	"Mouse Queen: \"Hitch us to the cart (E) — then haul him south, out of the deadly flowers.\"",
]

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
		d.say("Narrator", "The Yellow Brick Road runs on — but scarlet poppies crowd both sides. Their scent is deadly to flesh.", true, 4.5)
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
			# Skip to road open with party safe
			dorothy_asleep = false
			lion_asleep = false
			dorothy_safe = true
			lion_safe = true
			dorothy_carried = false
			hauling = false
			if player:
				player.visible = true
				if player.has_method("set_parked"):
					player.call("set_parked", false)
				player.global_position = SAFE_SOUTH + Vector3(-1.5, 0, 0)
			if lion:
				if lion.has_method("set_parked"):
					lion.call("set_parked", false)
				lion.global_position = SAFE_SOUTH + Vector3(1.5, 0, 0)
			if has_node("SafeDorothyLab"):
				get_node("SafeDorothyLab").queue_free()
			_set_beat(Beat.ROAD_OPEN)
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if player == null or _going:
		return
	_update_compass()
	_tick_sleep(delta)
	_tick_carry()
	_tick_haul(delta)
	var actor := _lead()
	if actor == null:
		return
	_near_dorothy = dorothy_asleep and not dorothy_carried and not dorothy_safe \
		and actor != player and actor.global_position.distance_to(player.global_position) < 3.2
	_near_lion = lion_asleep and not lion_safe and not hauling \
		and actor.global_position.distance_to(lion.global_position if lion else LION_FALL) < 5.5
	var queen_phase: bool = beat == Beat.LION_DOWN or beat == Beat.SAVE_QUEEN
	_near_queen = queen_phase and queen_saved and queen and actor.global_position.distance_to(QUEEN_POS) < 3.5
	_near_cat = queen_phase and wildcat and is_instance_valid(wildcat) \
		and actor.global_position.distance_to(wildcat.global_position) < 3.5
	_near_cart = (beat == Beat.MICE_CART or beat == Beat.HAUL_LION) and cart \
		and actor.global_position.distance_to(cart.global_position) < 4.0
	_near_gate = beat == Beat.ROAD_OPEN and actor.global_position.distance_to(WEST_GATE) < 4.5
	if Input.is_action_just_pressed("interact"):
		if _near_gate:
			_go_west("The Yellow Brick Road leaves the poppies — West waits…")
		elif _near_dorothy and beat in [Beat.DOROTHY_DOWN, Beat.CARRY_DOROTHY]:
			_pick_up_dorothy()
		elif _near_cat and queen_phase:
			_kill_wildcat()
		elif _near_queen and queen_saved:
			_advance_queen()
		elif _near_cart and (beat == Beat.MICE_CART or beat == Beat.HAUL_LION) and not cart_ready:
			_hitch_mice()
		elif _near_lion and dorothy_safe and not lion_safe and not hauling:
			# One path: E on Lion always routes through rescue helper
			_try_start_lion_rescue()
		else:
			var w := get_node_or_null("/root/Whimsy")
			if w and w.has_method("try_collect"):
				w.call("try_collect", actor)
	# Auto beat advances
	if beat == Beat.WALK_FIELD and dorothy_asleep:
		_set_beat(Beat.DOROTHY_DOWN)
	if beat == Beat.CARRY_DOROTHY and dorothy_safe and not dorothy_carried:
		if not lion_asleep and lion:
			# Lion may still be in field — put him down if still in scent
			if _in_poppy(lion.global_position):
				lion_asleep = true
				_set_beat(Beat.LION_DOWN)
			else:
				_set_beat(Beat.ROAD_OPEN)
		elif lion_asleep:
			_set_beat(Beat.LION_DOWN)
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

func _is_flesh_lead() -> bool:
	var id := _lead_id()
	return id == &"dorothy" or id == &"lion"

func _in_poppy(pos: Vector3) -> bool:
	return pos.z >= POPPY_START_Z and pos.z <= POPPY_END_Z

func _tick_sleep(delta: float) -> void:
	if beat >= Beat.ROAD_OPEN:
		sleep_meter = 0.0
		_refresh_sleep_hud()
		return
	var actor := _lead()
	if actor == null:
		return
	var in_field := _in_poppy(actor.global_position)
	if in_field and _is_flesh_lead() and not (dorothy_asleep and _lead_id() == &"dorothy"):
		# Lion already asleep doesn't keep ticking if not lead
		if _lead_id() == &"lion" and lion_asleep:
			pass
		else:
			sleep_meter = minf(sleep_meter + delta * 22.0, 100.0)
	elif not in_field:
		sleep_meter = maxf(sleep_meter - delta * 35.0, 0.0)
	else:
		# Straw/tin immune — meter drains
		sleep_meter = maxf(sleep_meter - delta * 40.0, 0.0)
	_refresh_sleep_hud()
	if sleep_meter >= 100.0 and _is_flesh_lead():
		if _lead_id() == &"dorothy" and not dorothy_asleep:
			_drop_dorothy_asleep()
		elif _lead_id() == &"lion" and not lion_asleep and dorothy_safe:
			_drop_lion_asleep()

func _drop_dorothy_asleep() -> void:
	dorothy_asleep = true
	sleep_meter = 0.0
	var drop := player.global_position if player else YBR_SPAWN
	drop.y = 0.08
	if player and player.has_method("set_parked"):
		player.call("set_parked", true, drop)
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say"):
		d.say("Narrator", "Dorothy falls among the poppies. Toto too. Scarecrow and Tin Man feel nothing — they are not flesh.", true, 4.0)
	var party := get_node_or_null("/root/Party")
	if party and party.has_method("set_leader"):
		party.call("set_leader", &"scarecrow")
	_set_beat(Beat.DOROTHY_DOWN)

func _drop_lion_asleep() -> void:
	lion_asleep = true
	sleep_meter = 0.0
	if lion:
		if lion.has_method("set_parked"):
			lion.call("set_parked", true, LION_FALL)
		else:
			lion.global_position = LION_FALL
	var party := get_node_or_null("/root/Party")
	if party and party.has_method("set_leader"):
		if not party.call("set_leader", &"tinman"):
			party.call("set_leader", &"scarecrow")
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say"):
		d.say("Scarecrow", "The Lion is too big to carry. We need help!", true, 3.5)
	_set_beat(Beat.LION_DOWN)

func _pick_up_dorothy() -> void:
	dorothy_carried = true
	_set_beat(Beat.CARRY_DOROTHY)
	hud.set_prompt("Carrying Dorothy — walk SOUTH out of the poppies")
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say"):
		d.say("Tin Man", "Quickly — south, out of the scent!", true, 2.5)

func _tick_carry() -> void:
	if not dorothy_carried or player == null:
		return
	var actor := _lead()
	if actor == null or actor == player:
		return
	var carry_pos := actor.global_position + Vector3(0.0, 0.0, -0.8)
	carry_pos.y = 0.08
	if player.has_method("set_parked"):
		player.call("set_parked", true, carry_pos)
	else:
		player.global_position = carry_pos
	if not _in_poppy(actor.global_position) and actor.global_position.z >= SAFE_SOUTH.z - 6.0:
		dorothy_carried = false
		dorothy_asleep = false
		dorothy_safe = true
		var safe_pos := SAFE_SOUTH + Vector3(-2.0, 0, 0)
		# Park south — she must NOT trail Lead back into the field.
		if player.has_method("set_parked"):
			player.call("set_parked", true, safe_pos)
		else:
			player.global_position = safe_pos
		_ensure_safe_dorothy_marker(safe_pos)
		var d := get_node_or_null("/root/DialogueUI")
		if d and d.has_method("say"):
			d.say("Narrator", "Clear air. Dorothy stays south of the flowers — she will not follow you back in. Go get the Lion.", true, 4.5)
		lion_asleep = true
		if lion:
			if lion.has_method("set_parked"):
				lion.call("set_parked", true, LION_FALL)
			else:
				lion.global_position = LION_FALL
		_set_beat(Beat.LION_DOWN)

func _kill_wildcat() -> void:
	if wildcat and is_instance_valid(wildcat):
		wildcat.queue_free()
		wildcat = null
	queen_saved = true
	if queen:
		queen.visible = true
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say"):
		d.say("Tin Man", "No heart — but that was wrong. The little Queen is safe.", true, 3.0)
	hud.set_objective("E the Mouse Queen (grey, east of YBR). After her lines, walk to the Lion and press E.")
	hud.set_prompt("E  —  Speak with the Mouse Queen (press E through her lines)")

func _advance_queen() -> void:
	if _queen_line >= QUEEN_LINES.size():
		_hitch_mice()
		return
	var line: String = QUEEN_LINES[_queen_line]
	_queen_line += 1
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say_line"):
		d.say_line(line, true)
	elif hud:
		hud.set_prompt(line)
	if _queen_line >= QUEEN_LINES.size():
		_hitch_mice()

func _hitch_mice() -> void:
	if cart_ready and beat == Beat.HAUL_LION:
		return
	cart_ready = true
	if cart:
		cart.visible = true
		_ensure_cart_label_loud()
	_set_beat(Beat.HAUL_LION)
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say"):
		d.say("Mouse Queen", "Now walk to the sleeping Lion on the road and press E — then walk SOUTH. Dorothy waits safely south.", true, 4.5)
	hud.set_objective("Walk to the sleeping LION on the YBR and press E. Then walk SOUTH out of the red field.")
	hud.set_prompt("Compass → Lion · E starts haul · then hold SOUTH")

func _try_start_lion_rescue() -> void:
	if not dorothy_safe or lion_safe or hauling:
		return
	if not queen_saved:
		hud.set_prompt("Lion too heavy — E the orange WILDCAT east of the road first, then the Mouse Queen")
		_set_beat(Beat.LION_DOWN)
		return
	if _queen_line < QUEEN_LINES.size():
		hud.set_prompt("Finish Mouse Queen lines first (E on the grey Queen east of the road)")
		return
	if not cart_ready:
		_hitch_mice()
	_start_haul()

func _start_haul() -> void:
	if hauling or lion_safe or not lion_asleep:
		return
	if not cart_ready:
		cart_ready = true
		if cart:
			cart.visible = true
	hauling = true
	# Unpark Lion so the haul can drag him; Dorothy stays parked south.
	if lion and lion.has_method("set_parked"):
		lion.call("set_parked", false)
	hud.set_objective("HAULING Lion — walk SOUTH on the Yellow Brick Road until clear of the poppies. Dorothy stays south.")
	hud.set_prompt("Hold SOUTH on YBR — Lion + cart follow you out")
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say"):
		d.say("Narrator", "The field mice pull. Walk south on the Yellow Brick Road until the Lion wakes in clear air.", true, 3.5)

func _tick_haul(delta: float) -> void:
	var actor := _lead()
	if actor == null:
		return
	# Pin Dorothy south while Lion still needs rescue (never re-enter follow)
	if dorothy_safe and not lion_safe and player:
		var sp := SAFE_SOUTH + Vector3(-2.0, 0, 0)
		if player.has_method("set_parked"):
			if bool(player.get("parked")):
				player.set("park_pos", sp)
			else:
				player.call("set_parked", true, sp)
	# Keep Lion pinned until haul starts
	if lion_asleep and not hauling and not lion_safe and lion and lion.has_method("set_parked"):
		if not bool(lion.get("parked")):
			lion.call("set_parked", true, LION_FALL)
	if cart_ready and cart and not hauling and beat == Beat.HAUL_LION:
		cart.global_position = cart.global_position.lerp(
			actor.global_position + Vector3(1.6, 0, 0.2), 1.0 - exp(-4.0 * delta)
		)
		if lion and actor.global_position.distance_to(lion.global_position) < 5.0:
			_start_haul()
			return
	if not hauling or lion == null:
		return
	if cart:
		var target := actor.global_position + Vector3(0, 0, -0.4)
		cart.global_position = cart.global_position.lerp(target + Vector3(1.5, 0, 0), 1.0 - exp(-3.0 * delta))
		lion.global_position = cart.global_position + Vector3(-1.2, 0.1, 0)
	else:
		lion.global_position = lion.global_position.lerp(
			actor.global_position + Vector3(-1.2, 0, -0.5), 1.0 - exp(-2.5 * delta)
		)
	if actor.global_position.z >= POPPY_END_Z + 6.0 or (
		actor.global_position.z >= SAFE_SOUTH.z - 8.0 and not _in_poppy(actor.global_position)
	):
		hauling = false
		lion_asleep = false
		lion_safe = true
		var lion_safe_pos := SAFE_SOUTH + Vector3(2.0, 0, 0)
		if lion and lion.has_method("set_parked"):
			lion.call("set_parked", false)
		if lion:
			lion.global_position = lion_safe_pos
		if cart:
			cart.global_position = SAFE_SOUTH + Vector3(4.0, 0, 0)
		# Release Dorothy — party free again
		if player and player.has_method("set_parked"):
			player.call("set_parked", false)
			player.global_position = SAFE_SOUTH + Vector3(-2.0, 0, 0)
		if has_node("SafeDorothyLab"):
			get_node("SafeDorothyLab").queue_free()
		var d := get_node_or_null("/root/DialogueUI")
		if d and d.has_method("say"):
			d.say("Narrator", "The Lion wakes in clear air. The poppies are behind you. The road runs on to the West.", true, 4.0)
		_set_beat(Beat.ROAD_OPEN)

func _ensure_safe_dorothy_marker(pos: Vector3) -> void:
	if has_node("SafeDorothyLab"):
		return
	var lab := Label3D.new()
	lab.name = "SafeDorothyLab"
	lab.text = "DOROTHY — SAFE\n(waits here · will not follow)"
	lab.font_size = 34
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(0.75, 0.9, 1.0)
	add_child(lab)
	lab.global_position = pos + Vector3(0, 2.8, 0)

func _set_beat(next: Beat) -> void:
	beat = next
	match beat:
		Beat.ENTER:
			hud.set_objective("Yellow Brick Road — poppies crowd both sides. Stay alert.")
			hud.set_prompt("F8 skip field · F9/F10 → West · F11 Emerald")
		Beat.WALK_FIELD:
			hud.set_objective("Follow the YBR south through the poppy field. Flesh grows sleepy — Tab to Scarecrow or Tin Man if you must.")
			hud.set_prompt("Sleep meter rises on Dorothy/Lion in the red field")
		Beat.DOROTHY_DOWN:
			hud.set_objective("Dorothy sleeps in the poppies. Lead Scarecrow or Tin Man (2/3) — E to carry her SOUTH out of the scent.")
			hud.set_prompt("Tab 2 or 3 · E near Dorothy · walk south")
		Beat.CARRY_DOROTHY:
			hud.set_objective("Carry Dorothy south on the Yellow Brick Road — leave the deadly flowers.")
			hud.set_prompt("Keep walking south until the meter dies and air clears")
		Beat.LION_DOWN:
			hud.set_objective("You cannot carry the Lion. Rescue chain: 1) E wildcat (east) 2) E Mouse Queen 3) E mice cart 4) E Lion 5) walk SOUTH.")
			hud.set_prompt("Compass → Wildcat (east of YBR) · E")
			_show_lion_help_marker()
			if wildcat:
				wildcat.visible = true
			if queen:
				queen.visible = true
			# Same beat family as SAVE_QUEEN — keep interactions live immediately.
			beat = Beat.SAVE_QUEEN
		Beat.SAVE_QUEEN:
			hud.set_objective("Lion is too heavy. 1) E the orange WILDCAT east of the road 2) E the Mouse Queen until she offers the cart.")
			hud.set_prompt("E on wildcat · then E on Queen (several times)")
			_show_lion_help_marker()
			if wildcat:
				wildcat.visible = true
			if queen:
				queen.visible = true
		Beat.MICE_CART:
			hud.set_objective("Lion rescue 2/4: E the brown MICE CART (east of YBR) to hitch the field mice. Then return to the Lion.")
			hud.set_prompt("Compass → Mice cart · E")
			if cart:
				cart.visible = true
				_ensure_cart_label_loud()
		Beat.HAUL_LION:
			hud.set_objective("Lion rescue 3/4: Stand next to the sleeping Lion on the Yellow Brick Road and press E. Then walk SOUTH out of the red field.")
			hud.set_prompt("E near Lion starts haul · then hold SOUTH on YBR")
			_show_lion_help_marker()
		Beat.ROAD_OPEN:
			hud.set_objective("FINAL STEP (L3): Follow the Yellow Brick Road SOUTH to the glowing West gate — E.")
			hud.set_prompt("End-gate: YBR south · E on gate · F9/F10 West")
			_ensure_west_gate_label()
			if has_node("LionTooHeavyLab"):
				get_node("LionTooHeavyLab").queue_free()

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
	# Continuous YBR
	_add_box(Vector3(0, 0.05, 0), Vector3(5.8, 0.1, 130), Color(0.95, 0.82, 0.25), "YellowBrickRoad")
	# Poppy beds both sides (visual masses + scent zone markers)
	for z in range(int(POPPY_START_Z), int(POPPY_END_Z) + 1, 6):
		_add_box(Vector3(-12, 0.4, float(z)), Vector3(14, 0.9, 5.5), Color(0.85, 0.15, 0.28), "PoppiesL")
		_add_box(Vector3(12, 0.4, float(z)), Vector3(14, 0.9, 5.5), Color(0.8, 0.12, 0.3), "PoppiesR")
		# Soft emission tips
		_add_box(Vector3(-12, 1.0, float(z)), Vector3(12, 0.25, 4.0), Color(1.0, 0.25, 0.4), "PoppyBloomL")
		_add_box(Vector3(12, 1.0, float(z)), Vector3(12, 0.25, 4.0), Color(1.0, 0.2, 0.35), "PoppyBloomR")
	# Safe green south of field
	_add_box(Vector3(0, 0.03, 42), Vector3(40, 0.08, 24), Color(0.4, 0.65, 0.38), "SafeMeadow")
	_add_box(WEST_GATE + Vector3(0, 0.02, 0), Vector3(7.0, 0.14, 7.0), Color(0.55, 0.2, 0.15), "WestGatePad")
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
	# Wildcat
	wildcat = CharacterBody3D.new()
	wildcat.name = "Wildcat"
	add_child(wildcat)
	wildcat.global_position = WILDCAT_POS
	var wc := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 0.7, 2.2)
	wc.mesh = box
	var wcm := StandardMaterial3D.new()
	wcm.albedo_color = Color(0.85, 0.55, 0.15)
	wc.material_override = wcm
	wc.position = Vector3(0, 0.4, 0)
	wildcat.add_child(wc)
	var wlab := Label3D.new()
	wlab.text = "WILDCAT"
	wlab.font_size = 36
	wlab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	wlab.modulate = Color(1.0, 0.6, 0.2)
	wlab.position = Vector3(0, 1.6, 0)
	wildcat.add_child(wlab)
	wildcat.visible = false
	# Queen
	queen = CharacterBody3D.new()
	queen.name = "MouseQueen"
	add_child(queen)
	queen.global_position = QUEEN_POS
	var qb := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.35
	sph.height = 0.5
	qb.mesh = sph
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(0.55, 0.55, 0.6)
	qm.emission_enabled = true
	qm.emission = Color(0.8, 0.75, 0.4)
	qm.emission_energy_multiplier = 0.5
	qb.material_override = qm
	qb.position = Vector3(0, 0.35, 0)
	queen.add_child(qb)
	var qlab := Label3D.new()
	qlab.text = "MOUSE QUEEN"
	qlab.font_size = 34
	qlab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	qlab.modulate = Color(1.0, 0.9, 0.5)
	qlab.position = Vector3(0, 1.4, 0)
	queen.add_child(qlab)
	queen.visible = false
	# Cart
	cart = Node3D.new()
	cart.name = "MiceCart"
	add_child(cart)
	cart.global_position = CART_POS
	var cb := MeshInstance3D.new()
	var cbox := BoxMesh.new()
	cbox.size = Vector3(2.4, 0.8, 3.2)
	cb.mesh = cbox
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.45, 0.3, 0.15)
	cb.material_override = cm
	cb.position = Vector3(0, 0.5, 0)
	cart.add_child(cb)
	var clab := Label3D.new()
	clab.text = "MICE CART"
	clab.font_size = 36
	clab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	clab.modulate = Color(0.95, 0.85, 0.5)
	clab.position = Vector3(0, 1.8, 0)
	cart.add_child(clab)
	cart.visible = false

func _add_poppy_whimsy() -> void:
	var w := get_node_or_null("/root/Whimsy")
	if w == null or not w.has_method("setup") or hud == null:
		return
	# Off-road only — north safe strip + south safe meadow (not inside deadly scent as required pickup)
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
	sleep_label.add_theme_font_size_override("font_size", 16)
	sleep_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.55))
	_refresh_sleep_hud()

func _refresh_sleep_hud() -> void:
	if sleep_label == null:
		return
	if sleep_meter <= 1.0:
		sleep_label.text = "Poppy scent  —"
		return
	var who := "Flesh"
	if _lead_id() == &"dorothy":
		who = "Dorothy"
	elif _lead_id() == &"lion":
		who = "Lion"
	elif not _is_flesh_lead():
		who = "Immune (straw/tin)"
	sleep_label.text = "Poppy sleep  %s  %.0f%%" % [who, sleep_meter]

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
		Beat.DOROTHY_DOWN, Beat.CARRY_DOROTHY:
			if dorothy_carried:
				target = SAFE_SOUTH
				label = "Carry → clear air"
			else:
				target = player.global_position if player else target
				label = "Dorothy (carry E)"
		Beat.LION_DOWN, Beat.SAVE_QUEEN:
			if wildcat and is_instance_valid(wildcat):
				target = wildcat.global_position
				label = "Wildcat"
			else:
				target = QUEEN_POS
				label = "Mouse Queen"
		Beat.MICE_CART:
			target = cart.global_position if cart else CART_POS
			label = "Mice cart"
		Beat.HAUL_LION:
			if hauling:
				target = SAFE_SOUTH
				label = "Haul → clear air"
			else:
				target = lion.global_position if lion else LION_FALL
				label = "Lion + cart"
		Beat.ROAD_OPEN:
			target = WEST_GATE
			label = "YBR → West (FINAL)"
	var dist := actor.global_position.distance_to(target)
	compass.text = "%s  ·  %.0fm" % [label, dist]

func _update_prompt() -> void:
	if _near_gate:
		hud.set_prompt("E  —  FINAL STEP: Yellow Brick Road to the West castle")
	elif _near_dorothy:
		hud.set_prompt("E  —  Carry Dorothy south out of the poppies")
	elif _near_cat:
		hud.set_prompt("E  —  Stop the wildcat (save the Queen)")
	elif _near_queen and queen_saved:
		hud.set_prompt("E  —  Speak with the Mouse Queen (keep pressing E through her lines)")
	elif _near_cart and beat == Beat.MICE_CART:
		hud.set_prompt("E  —  Hitch field mice to the cart (required before Lion)")
	elif _near_lion and dorothy_safe and not cart_ready and not queen_saved:
		hud.set_prompt("Lion too heavy — compass east: E wildcat → E Queen → then E Lion")
	elif _near_lion and dorothy_safe and not lion_safe and not hauling:
		hud.set_prompt("E  —  Start hauling the Lion SOUTH out of the poppies")
	elif _near_lion and not cart_ready:
		hud.set_prompt("Lion too heavy — compass east: wildcat → Queen first")
	elif hauling:
		hud.set_prompt("HAULING Lion — walk SOUTH on the Yellow Brick Road until clear air")
	elif dorothy_carried:
		hud.set_prompt("Carrying Dorothy — south, out of the red field")
	else:
		var w := get_node_or_null("/root/Whimsy")
		if w and w.has_method("prompt_if_near"):
			var p: String = str(w.call("prompt_if_near"))
			if p != "":
				hud.set_prompt(p)

func _show_lion_help_marker() -> void:
	if has_node("LionTooHeavyLab"):
		var existing := get_node("LionTooHeavyLab") as Label3D
		if existing and lion:
			existing.global_position = lion.global_position + Vector3(0, 3.2, 0)
		return
	var lab := Label3D.new()
	lab.name = "LionTooHeavyLab"
	lab.text = "LION — TOO HEAVY\nCannot carry alone\n1 Wildcat  2 Queen  3 Cart  4 E here  5 South"
	lab.font_size = 36
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(1.0, 0.85, 0.35)
	add_child(lab)
	lab.global_position = (lion.global_position if lion else LION_FALL) + Vector3(0, 3.2, 0)

func _ensure_cart_label_loud() -> void:
	if cart == null:
		return
	for c in cart.get_children():
		if c is Label3D:
			(c as Label3D).text = "MICE CART — E to hitch\n(then walk to Lion)"
			(c as Label3D).font_size = 42
			(c as Label3D).modulate = Color(1.0, 0.95, 0.4)

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
	# Poppy beds are scent, not solid walls on the road — only tall blooms block a little off-road
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
	mi.material_override = mat
	body.add_child(mi)
	return mi
