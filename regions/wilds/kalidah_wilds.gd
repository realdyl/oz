extends Node3D

## L3a · The Kalidah Wilds & Great Chasms (Baum Ch. 7 — "The Journey to the Great Oz").
## Bridges Munchkinland (L2) and the Deadly Poppy Field (L3b):
## 1) First Great Chasm — Interactive Spyro-camera party counsel + Lion's Courage Leap!
## 2) Central Ridge Ambush — 2 sculpted 3D Kalidah Beasts (bear bodies + sabre-tiger heads)!
## 3) Second Great Chasm — Tin Man chops the Towering Ancient Pine (F / C / E) so it topples
##    90° across the gorge as a solid walkable timber bridge to the Poppy Field portal!

const PLAYER_SCENE := preload("res://actors/dorothy/player.tscn")
const HUD_SCENE := preload("res://ui/play_hud.tscn")
const SCARECROW_SCENE := preload("res://actors/companions/scarecrow.tscn")
const LION_SCENE := preload("res://actors/companions/lion.tscn")
const TINMAN_SCENE := preload("res://actors/companions/tinman.tscn")
const WorldKit := preload("res://systems/world_kit.gd")
const OzEncounters := preload("res://systems/oz_encounters.gd")
const POPPY_SCENE := "res://regions/poppy/poppy_road.tscn"

const PLAY_BOUND_X := 52.0
const PLAY_BOUND_Z := 104.0
const SPAWN_POS := Vector3(0.0, 0.08, -88.0)
const CHASM1_BRINK := Vector3(0.0, 0.08, -32.0)
const CHASM1_LAND := Vector3(0.0, 0.08, -17.5)
const PINE_POS := Vector3(2.8, 0.0, 34.0)
const POPPY_GATE := Vector3(0.0, 0.08, 90.0)

enum Beat {
	CHASM_COUNSEL,
	LEAP_CHASM,
	KALIDAH_AMBUSH,
	FELL_PINE,
	ROAD_TO_POPPIES,
}

var hud: CanvasLayer
var player: CharacterBody3D
var scarecrow: CharacterBody3D
var lion: CharacterBody3D
var tinman: CharacterBody3D
var compass: Label
var beat: Beat = Beat.CHASM_COUNSEL

var _counsel_idx: int = 0
var _counsel_done: bool = false
var _pine_felled: bool = false
var _pine_pivot: Node3D = null
var _pine_bridge_body: StaticBody3D = null
var _kalidahs: Array[CharacterBody3D] = []
var _kalidah_kills: int = 0
var _going: bool = false

const COUNSEL_LINES := [
	"Dorothy: \"Oh! Look how deep that rocky gorge is — the Yellow Brick Road breaks right off at the cliff!\"",
	"Scarecrow: \"Wait — let me think with these new straw brains of mine. None of us can fly, so someone must carry us across.\"",
	"Tin Man: \"Even with my axe I couldn't chop enough stone to fill a chasm that wide.\"",
	"Scarecrow: \"Then the Lion must leap across on his strong legs, carrying us one by one on his back!\"",
	"Lion: \"M-me?! I am terribly afraid of falling into that dark gulf… Still, if you hold fast to my mane, I suppose I must try!\"",
	"Dorothy: \"Good, brave Lion! Step up to the brink (E) — or switch to Lion [4] and pounce right across!\"",
]

func _enter_tree() -> void:
	var p := get_node_or_null("/root/Party")
	if p and p.has_method("reset_party"):
		p.reset_party()

func _ready() -> void:
	_build_world()
	_spawn_party()
	_spawn_kalidahs()
	_add_wilds_whimsy()
	_ensure_compass()
	if hud and hud.has_method("set_kansas_mode"):
		hud.set_kansas_mode(false)
	_set_beat(Beat.CHASM_COUNSEL)
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("on_level_start"):
		lt.on_level_start("The Kalidah Wilds · Great Chasms")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			_fell_pine_bridge()
			_set_beat(Beat.ROAD_TO_POPPIES)
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_F9, KEY_F10]:
			_go_poppy_road()
			get_viewport().set_input_as_handled()

func _lead() -> CharacterBody3D:
	var p := get_node_or_null("/root/Party")
	if p and p.has_method("leader_body"):
		var b = p.call("leader_body")
		if b is CharacterBody3D:
			return b as CharacterBody3D
	return player

func _process(delta: float) -> void:
	if player == null or _going:
		return
	_tick_kalidahs(delta)
	_update_compass()
	var actor := _lead()
	if actor == null:
		return

	# Auto-recover if anyone ever slips below canyon rim
	var party_n := get_node_or_null("/root/Party")
	if party_n and party_n.has_method("each_member"):
		for m in party_n.call("each_member"):
			if m is CharacterBody3D and is_instance_valid(m):
				var mb := m as CharacterBody3D
				if mb.global_position.y < -1.8:
					mb.global_position = Vector3(0.0, 0.25, -10.5 if mb.global_position.z < 12.0 else 40.5)
					mb.velocity = Vector3.ZERO

	# Advance past Chasm 1 automatically if player crosses south of z = -13.5
	if beat in [Beat.CHASM_COUNSEL, Beat.LEAP_CHASM] and actor.global_position.z > -13.5:
		var p_cam := get_node_or_null("/root/Party")
		if p_cam and p_cam.has_method("exit_dialogue_shot"):
			p_cam.call("exit_dialogue_shot")
		_set_beat(Beat.KALIDAH_AMBUSH)

	var near_brink := actor.global_position.distance_to(CHASM1_BRINK) < 4.5
	var near_pine := not _pine_felled and actor.global_position.distance_to(PINE_POS) < 4.5
	var near_gate := actor.global_position.distance_to(POPPY_GATE) < 4.8

	if Input.is_action_just_pressed("interact"):
		if beat == Beat.CHASM_COUNSEL and near_brink and not _counsel_done:
			_advance_counsel()
		elif beat in [Beat.CHASM_COUNSEL, Beat.LEAP_CHASM] and near_brink:
			_perform_lion_chasm_leap()
		elif near_pine and not _pine_felled:
			_fell_pine_bridge()
		elif near_gate and (beat == Beat.ROAD_TO_POPPIES or _pine_felled):
			_go_poppy_road()
		else:
			var w := get_node_or_null("/root/Whimsy")
			if w and w.has_method("try_collect"):
				w.call("try_collect", actor)

	if hud:
		if beat == Beat.CHASM_COUNSEL and near_brink and not _counsel_done:
			hud.set_prompt("E  —  Hold council at the Great Chasm (%d/%d)" % [_counsel_idx + 1, COUNSEL_LINES.size()])
		elif beat in [Beat.CHASM_COUNSEL, Beat.LEAP_CHASM] and near_brink:
			hud.set_prompt("E  —  Lion's Courage Leap across the First Chasm!")
		elif near_pine and not _pine_felled:
			hud.set_prompt("E / Tin Man [F]  —  Chop the Towering Pine across the Second Chasm!")
		elif near_gate:
			hud.set_prompt("E  —  Enter the Deadly Poppy Field (Ch. VIII)")

func _advance_counsel() -> void:
	var p_cam := get_node_or_null("/root/Party")
	if _counsel_idx >= COUNSEL_LINES.size():
		_counsel_done = true
		if p_cam and p_cam.has_method("exit_dialogue_shot"):
			p_cam.call("exit_dialogue_shot")
		_set_beat(Beat.LEAP_CHASM)
		return
	var line: String = COUNSEL_LINES[_counsel_idx]
	_counsel_idx += 1
	var dui := get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("say_line"):
		dui.say_line(line, true)
	if p_cam and p_cam.has_method("enter_dialogue_shot") and player and lion:
		var sp_n: Node3D = player
		var ls_n: Node3D = lion
		var rev := false
		if line.begins_with("Scarecrow:") and scarecrow:
			sp_n = scarecrow; ls_n = lion; rev = true
		elif line.begins_with("Tin Man:") and tinman:
			sp_n = tinman; ls_n = scarecrow if scarecrow else player; rev = false
		elif line.begins_with("Lion:"):
			sp_n = lion; ls_n = player; rev = true
		p_cam.call("enter_dialogue_shot", sp_n, ls_n, rev)
	if _counsel_idx >= COUNSEL_LINES.size():
		_counsel_done = true
		if p_cam and p_cam.has_method("exit_dialogue_shot"):
			p_cam.call("exit_dialogue_shot")
		_set_beat(Beat.LEAP_CHASM)

func _perform_lion_chasm_leap() -> void:
	var p_cam := get_node_or_null("/root/Party")
	if p_cam and p_cam.has_method("exit_dialogue_shot"):
		p_cam.call("exit_dialogue_shot")
	var fx := get_node_or_null("/root/CombatFx")
	if fx and fx.has_method("roar_shockwave") and lion:
		fx.call("roar_shockwave", self, lion.global_position, 4.8)
	var dui := get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("say_line"):
		dui.say_line("Lion: \"Hold tight, everyone — ROOOAR! Over we go!\"", true)
	var party_n := get_node_or_null("/root/Party")
	var idx := 0
	if party_n and party_n.has_method("each_member"):
		for m in party_n.call("each_member"):
			if m is CharacterBody3D and is_instance_valid(m):
				var mb := m as CharacterBody3D
				var dest := CHASM1_LAND + Vector3(float(idx % 3 - 1) * 1.4, 0.0, float(idx / 3) * -1.4)
				idx += 1
				if DisplayServer.get_name() in ["headless", "Dummy"]:
					mb.global_position = dest
				else:
					var start_p := mb.global_position
					var mid_p := (start_p + dest) * 0.5 + Vector3(0, 4.2, 0)
					var tw := create_tween()
					tw.tween_property(mb, "global_position", mid_p, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					tw.tween_property(mb, "global_position", dest, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_set_beat(Beat.KALIDAH_AMBUSH)

func _fell_pine_bridge() -> void:
	if _pine_felled:
		return
	_pine_felled = true
	if _pine_bridge_body:
		for c in _pine_bridge_body.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = false
	var fx := get_node_or_null("/root/CombatFx")
	if fx and fx.has_method("ring"):
		fx.call("ring", self, PINE_POS + Vector3(0, 0.6, 0), Color(0.95, 0.80, 0.35), 3.6, 0.45)
	if _pine_pivot:
		if DisplayServer.get_name() in ["headless", "Dummy"]:
			_pine_pivot.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		else:
			var tw := create_tween()
			tw.tween_property(_pine_pivot, "rotation_degrees:x", 90.0, 0.85).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var dui := get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("say_line"):
		dui.say_line("Tin Man: \"TIMBER! Cross quickly, friends — my axe has bridged the gulf!\"", true)
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("add_desire"):
		sm.call("add_desire", 20, "Kalidah Pine Bridge")
	_set_beat(Beat.ROAD_TO_POPPIES)

func on_enemy_down(_who: Node) -> void:
	_kalidah_kills += 1
	if beat == Beat.KALIDAH_AMBUSH and _kalidah_kills >= _kalidahs.size():
		_set_beat(Beat.FELL_PINE)

func _set_beat(next: Beat) -> void:
	beat = next
	if hud == null:
		return
	match beat:
		Beat.CHASM_COUNSEL:
			hud.set_objective("Follow the Yellow Brick Road south through the dark forest to the First Great Chasm (E).")
		Beat.LEAP_CHASM:
			hud.set_objective("Press E at the chasm brink for the Lion's Courage Leap (or cross the west root arch).")
		Beat.KALIDAH_AMBUSH:
			if _kalidah_kills >= _kalidahs.size():
				_set_beat(Beat.FELL_PINE)
				return
			hud.set_objective("Kalidah Beasts ambush the ridge! Defeat the ferocious tiger-bear monsters (%d/%d)." % [_kalidah_kills, _kalidahs.size()])
		Beat.FELL_PINE:
			if _pine_felled:
				_set_beat(Beat.ROAD_TO_POPPIES)
				return
			hud.set_objective("A Second Great Chasm blocks the road! Chop the Towering Pine (E or Tin Man [F]) to bridge it.")
		Beat.ROAD_TO_POPPIES:
			hud.set_objective("FINAL STEP (L3a): Walk across the fallen pine bridge to the glowing Poppy Field Gate (E).")

func _go_poppy_road() -> void:
	if _going:
		return
	_going = true
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("go_to"):
		lt.go_to(POPPY_SCENE, "Beyond the dark forest, scarlet blossoms scent the breeze…", "The Deadly Poppy Field")
	else:
		get_tree().change_scene_to_file(POPPY_SCENE)

func _build_world() -> void:
	# Three expansive canyon plateaus separated by Two Great Chasms (~15-min deep exploration!)
	# North Plateau: z = -108..-31 | Central Kalidah Ridge: z = -19..+35 | South Plateau: z = +48..+108
	_add_box(Vector3(0, -0.25, -69.5), Vector3(112, 0.5, 77.0), Color(0.16, 0.28, 0.18), "NorthPlateau")
	_add_box(Vector3(0, -0.25, 8.0), Vector3(112, 0.5, 54.0), Color(0.18, 0.26, 0.16), "KalidahRidge")
	_add_box(Vector3(0, -0.25, 78.0), Vector3(112, 0.5, 60.0), Color(0.24, 0.42, 0.24), "SouthPlateau")

	# Deep misty abyssal gorge floors beneath Chasm 1 & Chasm 2 (visual depth!)
	_add_box(Vector3(0, -9.5, -25.0), Vector3(116, 0.5, 14.0), Color(0.05, 0.06, 0.09), "AbyssFloor1")
	_add_box(Vector3(0, -9.5, 41.5), Vector3(116, 0.5, 15.0), Color(0.05, 0.06, 0.09), "AbyssFloor2")

	# Walkable Gnarled Ancient Root-Arch on far west of Chasm 1 so companions never get stranded!
	_add_box(Vector3(-9.5, -0.08, -25.0), Vector3(2.8, 0.28, 13.6), Color(0.26, 0.18, 0.12), "AncientRootBridge")

	# Yellow Brick Road broken cleanly at both chasms
	_add_box(Vector3(0, 0.04, -63.0), Vector3(5.6, 0.08, 62.0), Color(0.94, 0.80, 0.24), "YellowBrickRoad")
	_add_box(Vector3(0, 0.04, 8.0), Vector3(5.6, 0.08, 52.0), Color(0.92, 0.78, 0.22), "YellowBrickRoadMid")
	_add_box(Vector3(0, 0.04, 72.0), Vector3(5.6, 0.08, 48.0), Color(0.95, 0.82, 0.25), "YellowBrickRoadSouth")
	WorldKit.dress_ybr_spine(self, -90.0, -33.0, 2.9)
	WorldKit.dress_ybr_spine(self, -17.0, 33.0, 2.9)
	WorldKit.dress_ybr_spine(self, 49.0, 92.0, 2.9)

	WorldKit.make_world_badge(self, CHASM1_BRINK + Vector3(0, 2.2, 0), "✦  FIRST GREAT CHASM  ·  COUNSEL / LEAP [E]", Color(0.98, 0.84, 0.42), 9.0)

	# Towering Ancient Pine on North Brink of Second Chasm (topples 90° south across z = 24..38!)
	var pine_base := StaticBody3D.new()
	pine_base.name = "GreatChasmPineStump"
	pine_base.collision_layer = 1 | 4
	pine_base.add_to_group("living_tree")
	add_child(pine_base)
	pine_base.global_position = PINE_POS
	pine_base.set_script(_make_pine_hit_script())
	var p_stump_col := CollisionShape3D.new()
	var p_cyl := CylinderShape3D.new()
	p_cyl.radius = 0.65
	p_cyl.height = 1.2
	p_stump_col.shape = p_cyl
	p_stump_col.position = Vector3(0, 0.6, 0)
	pine_base.add_child(p_stump_col)

	_pine_pivot = Node3D.new()
	_pine_pivot.name = "GreatChasmPinePivot"
	_pine_pivot.position = Vector3(0.0, 0.15, 34.2)
	add_child(_pine_pivot)
	var trunk_mi := MeshInstance3D.new()
	var t_cyl := CylinderMesh.new()
	t_cyl.top_radius = 0.52
	t_cyl.bottom_radius = 0.72
	t_cyl.height = 15.2
	trunk_mi.mesh = t_cyl
	var bark_m := StandardMaterial3D.new()
	bark_m.albedo_color = Color(0.30, 0.19, 0.12)
	bark_m.roughness = 0.90
	trunk_mi.material_override = bark_m
	trunk_mi.position = Vector3(0, 7.6, 0)
	_pine_pivot.add_child(trunk_mi)
	var needle_m := StandardMaterial3D.new()
	needle_m.albedo_color = Color(0.12, 0.34, 0.18)
	needle_m.roughness = 0.88
	for ci in range(3):
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.12
		cm.bottom_radius = 2.4 - float(ci) * 0.45
		cm.height = 3.6
		cone.mesh = cm
		cone.material_override = needle_m
		cone.position = Vector3(0, 10.5 + float(ci) * 2.1, 0)
		_pine_pivot.add_child(cone)
	WorldKit.make_world_badge(self, PINE_POS + Vector3(-1.4, 2.5, 0), "✦  ANCIENT PINE  ·  CHOP BRIDGE [E / F]", Color(0.85, 0.95, 0.68), 9.0)

	# Solid walkable Pine Bridge collider (enabled as soon as pine falls!)
	_pine_bridge_body = StaticBody3D.new()
	_pine_bridge_body.name = "FallenPineBridge"
	_pine_bridge_body.collision_layer = 1
	add_child(_pine_bridge_body)
	_pine_bridge_body.global_position = Vector3(0.0, -0.02, 41.5)
	var bcol := CollisionShape3D.new()
	var bsh := BoxShape3D.new()
	bsh.size = Vector3(3.8, 0.35, 15.5)
	bcol.shape = bsh
	bcol.disabled = true
	_pine_bridge_body.add_child(bcol)

	# Primeval Gnarled Forest Trees flanking the canyons
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	for ti in range(28):
		var side := -1.0 if (ti % 2 == 0) else 1.0
		var tx := side * rng.randf_range(8.5, 34.0)
		var tz := rng.randf_range(-62.0, 56.0)
		if (tz > -26.0 and tz < -11.0) or (tz > 23.0 and tz < 39.0):
			continue
		var tr := WorldKit.make_gnarled_tree(Vector3(tx, 0.0, tz), rng, rng.randf_range(1.05, 1.55))
		add_child(tr)

	# South Poppy Field Portal Arch
	_add_box(POPPY_GATE + Vector3(0, 0.05, 0), Vector3(7.2, 0.08, 7.2), Color(0.75, 0.24, 0.26), "PoppyGatePad")
	WorldKit.build_grand_portal_arch(self, POPPY_GATE, Color(0.98, 0.36, 0.42), "Deadly Poppy Field")
	WorldKit.make_world_badge(self, POPPY_GATE + Vector3(0, 3.4, -1.2), "✦  DEADLY POPPY FIELD  [E]", Color(1.0, 0.56, 0.62), 9.5)

	WorldKit.scatter_swaying_grass(self, Vector3(0, 0, -42), 28.0, 80, 4.5)
	WorldKit.add_horizon_hills(self, PLAY_BOUND_X + 4.0, PLAY_BOUND_Z + 4.0, Color(0.12, 0.22, 0.15))
	_add_map_border(PLAY_BOUND_X + 3.0, PLAY_BOUND_Z + 3.0)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.86, 0.88, 0.98)
	sun.light_energy = 0.88
	sun.rotation_degrees = Vector3(-46, 26, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.08, 0.11, 0.15)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.24, 0.30, 0.34)
	e.ambient_light_energy = 0.78
	WorldKit.apply_aaa_post_processing(e, "winkie")
	env.environment = e
	add_child(env)

func _make_pine_hit_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = """extends StaticBody3D
func take_damage(_amount: int, _src: Vector3, tags: Dictionary = {}) -> void:
	if bool(tags.get("armor_break", false)) or _amount >= 15:
		var p := get_parent()
		if p and p.has_method("_fell_pine_bridge"):
			p.call("_fell_pine_bridge")
"""
	s.reload()
	return s

func _spawn_party() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = SPAWN_POS
	if player.has_method("empower_shoes"):
		player.empower_shoes()
	scarecrow = SCARECROW_SCENE.instantiate()
	add_child(scarecrow)
	scarecrow.global_position = SPAWN_POS + Vector3(-2.0, 0.0, -2.0)
	if scarecrow.has_method("free_from_pole"):
		scarecrow.free_from_pole()
	lion = LION_SCENE.instantiate()
	add_child(lion)
	lion.global_position = SPAWN_POS + Vector3(2.0, 0.0, -2.0)
	if lion.has_method("calm_and_join"):
		lion.calm_and_join()
	tinman = TINMAN_SCENE.instantiate()
	add_child(tinman)
	tinman.global_position = SPAWN_POS + Vector3(0.0, 0.0, -3.4)
	if tinman.has_method("oil_and_free"):
		tinman.oil_and_free()
	var party_f := get_node_or_null("/root/Party")
	if party_f and party_f.has_method("face_all_forward"):
		party_f.call_deferred("face_all_forward", PI)

func _spawn_kalidahs() -> void:
	var spots := [
		Vector3(-5.0, 0.08, -2.0),
		Vector3(5.0, 0.08, 8.0),
		Vector3(-6.2, 0.08, 18.0),
		Vector3(6.2, 0.08, 25.0),
	]
	for i in range(spots.size()):
		var kb := CharacterBody3D.new()
		kb.name = "KalidahBeast_%d" % (i + 1)
		kb.collision_layer = 4
		kb.collision_mask = 1
		kb.add_to_group("enemies")
		kb.set_script(_make_kalidah_script())
		kb.set("health", 85)
		add_child(kb)
		kb.global_position = spots[i]
		_build_kalidah_visual(kb)
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.68
		cap.height = 1.9
		col.shape = cap
		col.position = Vector3(0, 0.95, 0)
		kb.add_child(col)
		WorldKit.make_world_badge(kb, Vector3(0, 2.25, 0), "✦  KALIDAH SHADOW-BEAST", Color(1.0, 0.54, 0.26), 10.0)
		_kalidahs.append(kb)

func _make_kalidah_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = """extends CharacterBody3D
var health: int = 85
var alive: bool = true
var attack_cd: float = 1.4
var gait_t: float = 0.0
var bind_t: float = 0.0
var _chain_partner: Node3D = null
var _chain_t: float = 0.0

func apply_bind(dur: float) -> void:
	bind_t = maxf(bind_t, dur)

func set_chain_partner(p: Node3D, dur: float) -> void:
	_chain_partner = p
	_chain_t = dur

func take_damage(amount: int, src: Vector3, tags: Dictionary = {}) -> void:
	if not alive:
		return
	health -= maxi(1, amount)
	if not bool(tags.get("mirrored", false)) and _chain_t > 0.0 and _chain_partner and is_instance_valid(_chain_partner) and _chain_partner.has_method("take_damage"):
		_chain_partner.call("take_damage", maxi(1, int(float(amount) * 0.75)), src, {"mirrored": true})
	var fx := get_node_or_null("/root/CombatFx")
	if fx and fx.has_method("hit_sparks"):
		fx.call("hit_sparks", self, global_position + Vector3(0, 1.0, 0), Color(1.0, 0.55, 0.20))
	var push := (global_position - src)
	push.y = 0.0
	if push.length() > 0.05:
		velocity = push.normalized() * 5.2
	if health <= 0:
		alive = false
		add_to_group("enemies_dead")
		collision_layer = 0
		visible = false
		var sc := get_parent()
		if sc and sc.has_method("on_enemy_down"):
			sc.call("on_enemy_down", self)
"""
	s.reload()
	return s

func _tick_kalidahs(delta: float) -> void:
	var actor := _lead()
	if actor == null:
		return
	for kb in _kalidahs:
		if kb == null or not is_instance_valid(kb) or not bool(kb.get("alive")):
			continue
		if not kb.is_on_floor():
			kb.velocity.y -= 20.0 * delta
		var d := kb.global_position.distance_to(actor.global_position)
		# Stay on Central Kalidah Ridge (-12..+22) and ambush once party crosses Chasm 1!
		if actor.global_position.z > -13.5 and actor.global_position.z < 24.5 and d < 22.0:
			var to_p := actor.global_position - kb.global_position
			to_p.y = 0.0
			if d > 1.75 and to_p.length() > 0.1:
				var dir := Locomotion.steer(kb, to_p.normalized(), 2.2)
				kb.velocity.x = lerpf(kb.velocity.x, dir.x * 4.8, clampf(delta * 8.0, 0.0, 1.0))
				kb.velocity.z = lerpf(kb.velocity.z, dir.z * 4.8, clampf(delta * 8.0, 0.0, 1.0))
				var vis := kb.get_node_or_null("Visual") as Node3D
				if vis:
					vis.rotation.y = lerp_angle(vis.rotation.y, atan2(dir.x, dir.z), clampf(delta * 10.0, 0.0, 1.0))
			else:
				kb.velocity.x = move_toward(kb.velocity.x, 0.0, 14.0 * delta)
				kb.velocity.z = move_toward(kb.velocity.z, 0.0, 14.0 * delta)
				var cd := float(kb.get("attack_cd")) - delta
				if cd <= 0.0:
					cd = 1.55
					if actor.has_method("take_damage"):
						actor.call("take_damage", 1, kb.global_position)
					var fx := get_node_or_null("/root/CombatFx")
					if fx and fx.has_method("slash_arc"):
						fx.call("slash_arc", self, kb.global_position + Vector3(0, 1.0, 0), (actor.global_position - kb.global_position).normalized(), Color(1.0, 0.45, 0.18), 1.8)
				kb.set("attack_cd", cd)
		else:
			kb.velocity.x = move_toward(kb.velocity.x, 0.0, 12.0 * delta)
			kb.velocity.z = move_toward(kb.velocity.z, 0.0, 12.0 * delta)
		kb.move_and_slide()
		kb.global_position.z = clampf(kb.global_position.z, -11.8, 22.8)

func _build_kalidah_visual(parent: Node3D) -> void:
	# Baum Ch. 7: Bear body + fierce sabre-tiger head & striped flanks + long razor claws!
	var vis := Node3D.new()
	vis.name = "Visual"
	parent.add_child(vis)
	var bear_fur := StandardMaterial3D.new()
	bear_fur.albedo_color = Color(0.16, 0.11, 0.09)
	bear_fur.roughness = 0.88
	var tiger_fur := StandardMaterial3D.new()
	tiger_fur.albedo_color = Color(0.76, 0.42, 0.14)
	tiger_fur.roughness = 0.82
	var eye_m := StandardMaterial3D.new()
	eye_m.albedo_color = Color(1.0, 0.65, 0.12)
	eye_m.emission_enabled = true
	eye_m.emission = Color(1.0, 0.50, 0.08)
	eye_m.emission_energy_multiplier = 2.6
	var claw_m := StandardMaterial3D.new()
	claw_m.albedo_color = Color(0.94, 0.90, 0.82)
	claw_m.roughness = 0.30

	# Hulking bear ribcage & haunches + tiger stripes
	_mi_local(vis, _sph_m(0.68, 1.30), bear_fur, Vector3(0, 0.98, 0.18), Vector3(78, 0, 0))
	_mi_local(vis, _sph_m(0.56, 1.05), bear_fur, Vector3(0, 0.88, -0.48), Vector3(72, 0, 0))
	for si in range(-2, 3):
		_mi_local(vis, _torus_m(0.52, 0.59), tiger_fur, Vector3(0, 0.96, float(si) * 0.22), Vector3(90, 0, 0))
	# Tiger head, striped cheek ruff, ears, glowing eyes & sabre fangs
	_mi_local(vis, _sph_m(0.44, 0.82), tiger_fur, Vector3(0, 1.32, 0.78))
	_mi_local(vis, _sph_m(0.26, 0.48), bear_fur, Vector3(0, 1.18, 1.08))
	for sx in [-1.0, 1.0]:
		_mi_local(vis, _sph_m(0.14, 0.24), tiger_fur, Vector3(float(sx) * 0.34, 1.66, 0.72))
		_mi_local(vis, _sph_m(0.065, 0.11), eye_m, Vector3(float(sx) * 0.17, 1.40, 1.12))
		_mi_local(vis, _cyl_m(0.01, 0.045, 0.24), claw_m, Vector3(float(sx) * 0.13, 1.02, 1.16), Vector3(180, 0, 0))
	# 4 Muscular Bear Limbs + Razor Claws
	for lx in [-0.46, 0.46]:
		for lz in [-0.48, 0.44]:
			_mi_local(vis, _cyl_m(0.18, 0.22, 0.82), bear_fur, Vector3(float(lx), 0.44, float(lz)))
			for ci in [-0.08, 0.0, 0.08]:
				_mi_local(vis, _cyl_m(0.008, 0.03, 0.18), claw_m, Vector3(float(lx) + float(ci), 0.08, float(lz) + 0.22), Vector3(75, 0, 0))

func _mi_local(p: Node3D, m: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	p.add_child(mi)

func _sph_m(r: float, h: float) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = h; return s

func _cyl_m(tr: float, br: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = tr; c.bottom_radius = br; c.height = h; return c

func _torus_m(ir: float, orad: float) -> TorusMesh:
	var t := TorusMesh.new(); t.inner_radius = ir; t.outer_radius = orad; return t

func _add_wilds_whimsy() -> void:
	var w := get_node_or_null("/root/Whimsy")
	if w and w.has_method("setup") and hud:
		w.call("setup", self, hud, [
			{"pos": Vector3(-7.5, 0, -72), "kind": "bounce", "name": "Mossy cap"},
			{"pos": Vector3(-5.2, 0, -69.5), "kind": "giggle", "name": "Twin fern bloom"},
			{"pos": Vector3(8.0, 0, -52), "kind": "chime", "name": "Canyon chime"},
			{"pos": Vector3(-11.0, 0, -38), "kind": "dance", "name": "Brink waltz"},
			{"pos": Vector3(-8.5, 0, -6), "kind": "giggle", "name": "Briar bloom"},
			{"pos": Vector3(8.5, 0, 12), "kind": "bounce", "name": "Ridge toadstool"},
			{"pos": Vector3(11.0, 0, 14.5), "kind": "chime", "name": "Echo pine chime"},
			{"pos": Vector3(-9.5, 0, 56), "kind": "dance", "name": "Gorge ribbon"},
			{"pos": Vector3(7.5, 0, 68), "kind": "bounce", "name": "Poppy-edge cap"},
			{"pos": Vector3(10.0, 0, 70.5), "kind": "giggle", "name": "Scarlet bud"},
		], "winkie")
	OzEncounters.spawn_velvet_sanctum(self, Vector3(-18.0, 0.0, 66.0), "sanctum_kalidah", "charm_silver_spur", "Velvet Sanctum of the Gorge")
	OzEncounters.spawn_monument(self, Vector3(16.0, 0.0, -56.0), "chime", "Chasm Watch-Bell", "", Color(0.95, 0.78, 0.36), 20)
	for up in [Vector3(-5.0, 0, -60), Vector3(5.2, 0, -42), Vector3(-5.2, 0, 2), Vector3(5.2, 0, 22), Vector3(-5.2, 0, 58), Vector3(5.2, 0, 76)]:
		WorldKit.spawn_destructible_urn(self, up)

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

func _update_compass() -> void:
	if compass == null:
		return
	var actor := _lead()
	if actor == null:
		return
	var tgt := POPPY_GATE
	var lbl := "Poppy Gate"
	match beat:
		Beat.CHASM_COUNSEL, Beat.LEAP_CHASM:
			tgt = CHASM1_BRINK; lbl = "First Great Chasm"
		Beat.KALIDAH_AMBUSH:
			tgt = Vector3(0, 0, 6); lbl = "Kalidah Ridge"
		Beat.FELL_PINE:
			tgt = PINE_POS; lbl = "Ancient Pine Bridge"
		Beat.ROAD_TO_POPPIES:
			tgt = POPPY_GATE; lbl = "Poppy Field Gate"
	compass.text = "%s  ·  %.0fm" % [lbl, actor.global_position.distance_to(tgt)]

func _add_map_border(half_x: float, half_z: float) -> void:
	var h := 3.2
	var thick := 2.0
	var col := Color(0.10, 0.18, 0.12)
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
	mat.roughness = 0.88
	mi.material_override = mat
	body.add_child(mi)
