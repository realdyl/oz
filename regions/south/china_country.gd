extends Node3D

## L6a · Fighting Trees, Dainty China Country & King of Beasts (Baum Ch. 18–21).
## Bridges Emerald City (L5) and Glinda's Quadling Court (L6b):
## - Zone 1 (North): Fighting Trees Orchard — Gnarled Oaks hurl seed-pods until Tin Man's axe clears the road!
## - Zone 2 (Center): Dainty China Country — Gleaming white & cobalt-blue porcelain walls, miniature glazed
##   teapot cottages, and a 6-line interactive back-and-forth Spyro-camera counsel with the China Princess!
## - Zone 3 (South): Dark Forest Spider Glade — Defeat the Giant 8-Legged Forest Spider to crown the
##   Cowardly Lion "King of the Forest Beasts" before entering Quadling Country!

const PLAYER_SCENE := preload("res://actors/dorothy/player.tscn")
const HUD_SCENE := preload("res://ui/play_hud.tscn")
const SCARECROW_SCENE := preload("res://actors/companions/scarecrow.tscn")
const LION_SCENE := preload("res://actors/companions/lion.tscn")
const TINMAN_SCENE := preload("res://actors/companions/tinman.tscn")
const TREE_SCRIPT := preload("res://actors/enemies/living_tree.gd")
const WorldKit := preload("res://systems/world_kit.gd")
const OzEncounters := preload("res://systems/oz_encounters.gd")
const GLINDA_SCENE := "res://regions/quadling/glinda_court.tscn"

const PLAY_BOUND_X := 54.0
const PLAY_BOUND_Z := 108.0
const SPAWN_POS := Vector3(0.0, 0.08, -94.0)
const PRINCESS_POS := Vector3(-4.2, 0.14, 0.0)
const SPIDER_POS := Vector3(0.0, 0.08, 62.0)
const GLINDA_GATE := Vector3(0.0, 0.08, 94.0)

enum Beat {
	FIGHTING_TREES,
	CHINA_PRINCESS,
	SPIDER_GLADE,
	ROAD_TO_GLINDA,
}

var hud: CanvasLayer
var player: CharacterBody3D
var scarecrow: CharacterBody3D
var lion: CharacterBody3D
var tinman: CharacterBody3D
var china_princess: CharacterBody3D
var spider_boss: CharacterBody3D
var compass: Label
var beat: Beat = Beat.FIGHTING_TREES

var _trees_down: int = 0
var _trees_need: int = 4
var _princess_idx: int = 0
var _princess_done: bool = false
var _spider_down: bool = false
var _spider_legs: Array[Node3D] = []
var _spider_gait: float = 0.0
var _going: bool = false

const PRINCESS_LINES := [
	"China Princess: \"Oh, tread softly, giant travelers! One clumsy kick could chip a milkmaid's elbow or crack our cobalt cottages!\"",
	"Dorothy: \"You're made of the finest painted porcelain I've ever seen! How pretty and dainty your whole village is!\"",
	"China Princess: \"Thank you, child. I am the Princess of China Country — though I broke my left ankle once and had to be mended with glue.\"",
	"Dorothy: \"Oh, I wish I could carry you home to Aunt Em's parlor shelf in Kansas — she would admire you every single day!\"",
	"China Princess: \"Mercy, no! Outside our wall our joints stiffen at once, and we can only stand rigid on a mantelpiece while dust gathers on our noses!\"",
	"Lion: \"She's quite right, Dorothy — freedom in one's own home beats any gilded shelf. Come softly over the south stile!\"",
]

func _enter_tree() -> void:
	var p := get_node_or_null("/root/Party")
	if p and p.has_method("reset_party"):
		p.reset_party()

func _ready() -> void:
	_build_world()
	_spawn_party()
	_spawn_orchard_trees()
	_spawn_china_cast()
	_spawn_spider_boss()
	_add_china_whimsy()
	_ensure_compass()
	if hud and hud.has_method("set_kansas_mode"):
		hud.set_kansas_mode(false)
	_set_beat(Beat.FIGHTING_TREES)
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("on_level_start"):
		lt.on_level_start("Southward Road · China Country & Spider Glade")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			_spider_down = true
			_set_beat(Beat.ROAD_TO_GLINDA)
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_F9, KEY_F10]:
			_go_glinda()
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
	_tick_spider_boss(delta)
	_update_compass()
	var actor := _lead()
	if actor == null:
		return

	if beat == Beat.FIGHTING_TREES and actor.global_position.z > -20.0:
		_set_beat(Beat.CHINA_PRINCESS)
	elif beat == Beat.CHINA_PRINCESS and actor.global_position.z > 22.0:
		var p_cam := get_node_or_null("/root/Party")
		if p_cam and p_cam.has_method("exit_dialogue_shot"):
			p_cam.call("exit_dialogue_shot")
		_set_beat(Beat.SPIDER_GLADE)

	var near_princess := china_princess != null and actor.global_position.distance_to(PRINCESS_POS) < 4.2
	var near_gate := actor.global_position.distance_to(GLINDA_GATE) < 4.8

	if Input.is_action_just_pressed("interact"):
		if near_princess and not _princess_done:
			_advance_princess()
		elif near_gate and (_spider_down or beat == Beat.ROAD_TO_GLINDA):
			_go_glinda()
		else:
			var w := get_node_or_null("/root/Whimsy")
			if w and w.has_method("try_collect"):
				w.call("try_collect", actor)

	if hud:
		if near_princess and not _princess_done:
			hud.set_prompt("E  —  Speak gently with the China Princess (%d/%d)" % [_princess_idx + 1, PRINCESS_LINES.size()])
		elif near_gate and (_spider_down or beat == Beat.ROAD_TO_GLINDA):
			hud.set_prompt("E  —  Enter Quadling Country · Glinda's Court (Ch. XXIII)")
		elif near_gate:
			hud.set_prompt("Defeat the Giant Forest Spider first to free the forest beasts!")

func _advance_princess() -> void:
	var p_cam := get_node_or_null("/root/Party")
	if _princess_idx >= PRINCESS_LINES.size():
		_princess_done = true
		if p_cam and p_cam.has_method("exit_dialogue_shot"):
			p_cam.call("exit_dialogue_shot")
		_set_beat(Beat.SPIDER_GLADE)
		return
	var line: String = PRINCESS_LINES[_princess_idx]
	_princess_idx += 1
	var dui := get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("say_line"):
		dui.say_line(line, true)
	if p_cam and p_cam.has_method("enter_dialogue_shot") and china_princess and player:
		var sp_n: Node3D = china_princess
		var ls_n: Node3D = player
		var rev := false
		if line.begins_with("Dorothy:"):
			sp_n = player; ls_n = china_princess; rev = true
		elif line.begins_with("Lion:") and lion:
			sp_n = lion; ls_n = china_princess; rev = true
		p_cam.call("enter_dialogue_shot", sp_n, ls_n, rev)
	if _princess_idx >= PRINCESS_LINES.size():
		_princess_done = true
		if p_cam and p_cam.has_method("exit_dialogue_shot"):
			p_cam.call("exit_dialogue_shot")
		var sm := get_node_or_null("/root/SaveManager")
		if sm and sm.has_method("advance_side_quest"):
			sm.call("advance_side_quest", "quadling_porcelain", 3)
		_set_beat(Beat.SPIDER_GLADE)

func on_enemy_down(who: Node) -> void:
	if who == null:
		return
	if who.is_in_group("living_tree"):
		_trees_down += 1
		if beat == Beat.FIGHTING_TREES and _trees_down >= _trees_need:
			_set_beat(Beat.CHINA_PRINCESS)
	elif who == spider_boss or who.is_in_group("boss"):
		_spider_down = true
		var dui := get_node_or_null("/root/DialogueUI")
		if dui and dui.has_method("say_line"):
			dui.say_line("Lion: \"The monstrous spider is slain! Hear me, beasts of the forest — your King is sworn, and the road to Glinda is open!\"", true)
		var sm := get_node_or_null("/root/SaveManager")
		if sm and sm.has_method("add_desire"):
			sm.call("add_desire", 30, "King of the Forest Beasts")
		_set_beat(Beat.ROAD_TO_GLINDA)

func _set_beat(next: Beat) -> void:
	beat = next
	if hud == null:
		return
	match beat:
		Beat.FIGHTING_TREES:
			hud.set_objective("Zone 1 · Fighting Trees Orchard: Cleave the hostile Orchard Oaks with Tin Man [3] (F / C) (%d/%d)." % [_trees_down, _trees_need])
		Beat.CHINA_PRINCESS:
			hud.set_objective("Zone 2 · Dainty China Country: Climb the porcelain wall & speak gently with the China Princess (E).")
		Beat.SPIDER_GLADE:
			if _spider_down:
				_set_beat(Beat.ROAD_TO_GLINDA)
				return
			hud.set_objective("Zone 3 · Dark Forest Glade: Slay the Giant Forest Spider so the Lion becomes King of Beasts!")
		Beat.ROAD_TO_GLINDA:
			hud.set_objective("FINAL STEP (L6a): Follow the Yellow Brick Road south into Quadling Country — Glinda's Court (E).")

func _go_glinda() -> void:
	if _going:
		return
	_going = true
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("go_to"):
		lt.go_to(GLINDA_SCENE, "The ruby banners of Quadling Country shimmer ahead…", "Quadling Country · Glinda's court")
	else:
		get_tree().change_scene_to_file(GLINDA_SCENE)

func _build_world() -> void:
	# Zone 1: Orchard Meadow (-112..-22) | Zone 2: Glazed Porcelain Floor (-22..+22) | Zone 3: Spider Forest (+22..+112)
	_add_box(Vector3(0, -0.2, -67.0), Vector3(114, 0.4, 90.0), Color(0.24, 0.42, 0.22), "OrchardGround")
	_add_porcelain_plaza()
	_add_box(Vector3(0, -0.2, 67.0), Vector3(114, 0.4, 90.0), Color(0.14, 0.22, 0.16), "ForestGround")

	# Continuous Yellow Brick Road north & south, plus Cobalt-Gold Porcelain Promenade in China Country
	_add_box(Vector3(0, 0.04, -60.0), Vector3(5.6, 0.08, 76.0), Color(0.94, 0.80, 0.24), "YellowBrickRoad")
	_add_box(Vector3(0, 0.04, 60.0), Vector3(5.6, 0.08, 76.0), Color(0.94, 0.80, 0.24), "YellowBrickRoadS")
	WorldKit.dress_ybr_spine(self, -96.0, -24.0, 2.9)
	WorldKit.dress_ybr_spine(self, 24.0, 96.0, 2.9)

	# South Quadling Portal Arch -> Glinda's Court!
	_add_box(GLINDA_GATE + Vector3(0, 0.05, 0), Vector3(7.4, 0.08, 7.4), Color(0.76, 0.20, 0.34), "GlindaGatePad")
	WorldKit.build_grand_portal_arch(self, GLINDA_GATE, Color(0.98, 0.34, 0.54), "Glinda's Quadling Court")
	WorldKit.make_world_badge(self, GLINDA_GATE + Vector3(0, 3.4, -1.2), "✦  GLINDA'S COURT  [E]", Color(1.0, 0.62, 0.78), 9.5)

	# Dark Forest Trees & Web Canopies around Spider Glade
	var rng := RandomNumberGenerator.new()
	rng.seed = 918
	for ti in range(22):
		var side := -1.0 if (ti % 2 == 0) else 1.0
		var tx := side * rng.randf_range(9.0, 34.0)
		var tz := rng.randf_range(26.0, 62.0)
		var tr := WorldKit.make_gnarled_tree(Vector3(tx, 0.0, tz), rng, rng.randf_range(1.1, 1.6))
		add_child(tr)

	WorldKit.scatter_swaying_grass(self, Vector3(0, 0, -45), 26.0, 75, 4.5)
	WorldKit.add_horizon_hills(self, PLAY_BOUND_X + 4.0, PLAY_BOUND_Z + 4.0, Color(0.20, 0.34, 0.22))
	_add_map_border(PLAY_BOUND_X + 3.0, PLAY_BOUND_Z + 3.0)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.98, 0.94, 0.88)
	sun.light_energy = 0.96
	sun.rotation_degrees = Vector3(-50, 22, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.14, 0.16, 0.22)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.38, 0.38, 0.44)
	e.ambient_light_energy = 0.80
	WorldKit.apply_aaa_post_processing(e, "glinda")
	env.environment = e
	add_child(env)

func _add_porcelain_plaza() -> void:
	# Gleaming White-and-Cobalt Glazed Porcelain Country (-22..+22) bounded by climbable Porcelain Stile Walls!
	var plaza := StaticBody3D.new()
	plaza.name = "DaintyChinaPlaza"
	plaza.collision_layer = 1
	add_child(plaza)
	var pcol := CollisionShape3D.new()
	var psh := BoxShape3D.new()
	psh.size = Vector3(88.0, 0.20, 44.0)
	pcol.shape = psh
	pcol.position = Vector3(0, 0.0, 0)
	plaza.add_child(pcol)

	var glaze_white := StandardMaterial3D.new()
	glaze_white.albedo_color = Color(0.97, 0.97, 0.99)
	glaze_white.roughness = 0.07
	glaze_white.metallic = 0.12
	var cobalt := StandardMaterial3D.new()
	cobalt.albedo_color = Color(0.14, 0.32, 0.76)
	cobalt.roughness = 0.10
	cobalt.metallic = 0.18
	var gold_trim := StandardMaterial3D.new()
	gold_trim.albedo_color = Color(0.94, 0.78, 0.32)
	gold_trim.roughness = 0.20
	gold_trim.metallic = 0.88

	_mi_mat(plaza, Vector3(88.0, 0.20, 44.0), glaze_white, Vector3(0, 0.0, 0))
	_mi_mat(plaza, Vector3(6.2, 0.04, 43.0), cobalt, Vector3(0, 0.11, 0))
	_mi_mat(plaza, Vector3(5.4, 0.05, 43.0), glaze_white, Vector3(0, 0.115, 0))

	# North & South Glazed White Porcelain Walls with open central cobalt-gold arch + stepped stile ramps!
	for wz in [-21.5, 21.5]:
		for sx in [-1.0, 1.0]:
			_add_porcelain_wall_wing(Vector3(float(sx) * 23.5, 0.75, float(wz)), Vector3(39.0, 1.5, 0.9), glaze_white, cobalt)
		# Ornate Cobalt-and-Gold Porcelain Archway over the central road!
		_mi_mat(plaza, Vector3(0.9, 3.8, 0.9), cobalt, Vector3(-3.6, 1.9, float(wz)))
		_mi_mat(plaza, Vector3(0.9, 3.8, 0.9), cobalt, Vector3(3.6, 1.9, float(wz)))
		_mi_mat(plaza, Vector3(8.4, 0.75, 1.1), gold_trim, Vector3(0.0, 3.95, float(wz)))
	WorldKit.make_world_badge(self, Vector3(0, 3.2, -21.5), "✦  DAINTY CHINA COUNTRY  ·  TREAD SOFTLY", Color(0.62, 0.84, 1.0), 9.5)

	# 4 Hand-Painted Delft Blue-and-White Porcelain Teapot Cottages!
	for cp in [Vector3(-14.0, 0.10, -9.0), Vector3(14.0, 0.10, -9.0), Vector3(-14.0, 0.10, 9.0), Vector3(14.0, 0.10, 9.0)]:
		_build_porcelain_teapot_cottage(cp, glaze_white, cobalt, gold_trim)

func _add_porcelain_wall_wing(pos: Vector3, sz: Vector3, white_m: Material, trim_m: Material) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	add_child(b)
	b.global_position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = sz
	cs.shape = sh
	b.add_child(cs)
	_mi_mat(b, sz, white_m, Vector3.ZERO)
	_mi_mat(b, Vector3(sz.x + 0.1, 0.16, sz.z + 0.12), trim_m, Vector3(0, sz.y * 0.5 + 0.06, 0))

func _build_porcelain_teapot_cottage(pos: Vector3, white_m: Material, cobalt_m: Material, gold_m: Material) -> void:
	var c := StaticBody3D.new()
	c.name = "PorcelainTeapotCottage"
	c.collision_layer = 1
	add_child(c)
	c.global_position = pos
	var col := CollisionShape3D.new()
	var cyl_s := CylinderShape3D.new()
	cyl_s.radius = 2.6
	cyl_s.height = 3.8
	col.shape = cyl_s
	col.position = Vector3(0, 1.9, 0)
	c.add_child(col)
	# Round glazed porcelain teapot belly + cobalt dome lid + gold finial + handle & spout!
	var belly := MeshInstance3D.new()
	var bs := SphereMesh.new(); bs.radius = 2.55; bs.height = 3.4
	belly.mesh = bs; belly.material_override = white_m; belly.position = Vector3(0, 1.65, 0)
	c.add_child(belly)
	var lid := MeshInstance3D.new()
	var ls := SphereMesh.new(); ls.radius = 2.15; ls.height = 1.6
	lid.mesh = ls; lid.material_override = cobalt_m; lid.position = Vector3(0, 3.25, 0)
	c.add_child(lid)
	var knob := MeshInstance3D.new()
	var ks := SphereMesh.new(); ks.radius = 0.34; ks.height = 0.68
	knob.mesh = ks; knob.material_override = gold_m; knob.position = Vector3(0, 4.15, 0)
	c.add_child(knob)
	var handle := MeshInstance3D.new()
	var ht := TorusMesh.new(); ht.inner_radius = 0.72; ht.outer_radius = 0.96
	handle.mesh = ht; handle.material_override = gold_m
	handle.position = Vector3(-2.45, 1.85, 0); handle.rotation_degrees = Vector3(90, 0, 0)
	c.add_child(handle)

func _mi_mat(p: Node3D, sz: Vector3, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = sz
	mi.mesh = bm; mi.material_override = mat; mi.position = pos
	p.add_child(mi)

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

func _spawn_orchard_trees() -> void:
	for tp in [
		Vector3(-3.8, 0.0, -72.0),
		Vector3(3.8, 0.0, -60.0),
		Vector3(-4.0, 0.0, -46.0),
		Vector3(4.0, 0.0, -34.0),
	]:
		var tr := StaticBody3D.new()
		tr.set_script(TREE_SCRIPT)
		add_child(tr)
		tr.global_position = tp

func _spawn_china_cast() -> void:
	china_princess = CharacterBody3D.new()
	china_princess.name = "ChinaPrincess"
	china_princess.collision_layer = 1
	add_child(china_princess)
	china_princess.global_position = PRINCESS_POS
	WorldKit.build_glinda_visual(china_princess)
	china_princess.scale = Vector3(0.76, 0.76, 0.76) # Dainty Baum-canon miniature porcelain scale!
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.35; cap.height = 1.5
	col.shape = cap; col.position = Vector3(0, 0.75, 0)
	china_princess.add_child(col)
	WorldKit.make_world_badge(china_princess, Vector3(0, 2.55, 0), "✦  CHINA PRINCESS  [E]", Color(0.68, 0.88, 1.0), 9.5)

func _spawn_spider_boss() -> void:
	spider_boss = CharacterBody3D.new()
	spider_boss.name = "GiantForestSpider"
	spider_boss.collision_layer = 4
	spider_boss.collision_mask = 1
	spider_boss.add_to_group("enemies")
	spider_boss.add_to_group("boss")
	spider_boss.set_script(_make_spider_script())
	add_child(spider_boss)
	spider_boss.global_position = SPIDER_POS
	_build_spider_visual(spider_boss)
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new(); sph.radius = 1.35
	col.shape = sph; col.position = Vector3(0, 1.35, 0)
	spider_boss.add_child(col)
	WorldKit.make_world_badge(spider_boss, Vector3(0, 3.1, 0), "✦  GIANT FOREST SPIDER  ·  TERROR OF THE BEASTS", Color(1.0, 0.38, 0.44), 12.0)

func _make_spider_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = """extends CharacterBody3D
var health: int = 160
var alive: bool = true
var bite_cd: float = 1.45
var bind_t: float = 0.0
var _chain_partner: Node3D = null
var _chain_t: float = 0.0

func apply_bind(dur: float) -> void:
	bind_t = maxf(bind_t, dur)

func set_chain_partner(p: Node3D, dur: float) -> void:
	_chain_partner = p
	_chain_t = dur

func take_damage(amount: int, src: Vector3, _tags: Dictionary = {}) -> void:
	if not alive:
		return
	health -= maxi(1, amount)
	var fx := get_node_or_null("/root/CombatFx")
	if fx and fx.has_method("hit_sparks"):
		fx.call("hit_sparks", self, global_position + Vector3(0, 1.2, 0), Color(0.95, 0.25, 0.38))
	var push := (global_position - src)
	push.y = 0.0
	if push.length() > 0.05:
		velocity = push.normalized() * 3.8
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

func _build_spider_visual(parent: Node3D) -> void:
	var vis := Node3D.new()
	vis.name = "Visual"
	parent.add_child(vis)
	var chitin := StandardMaterial3D.new()
	chitin.albedo_color = Color(0.09, 0.06, 0.11)
	chitin.roughness = 0.32
	chitin.metallic = 0.35
	var crimson := StandardMaterial3D.new()
	crimson.albedo_color = Color(0.86, 0.12, 0.24)
	crimson.emission_enabled = true
	crimson.emission = Color(0.85, 0.10, 0.20)
	crimson.emission_energy_multiplier = 1.8

	# Elephant-sized striped abdomen + cephalothorax + 8 glowing ruby eyes + twin fangs
	var abd := MeshInstance3D.new()
	var asph := SphereMesh.new(); asph.radius = 1.25; asph.height = 2.1
	abd.mesh = asph; abd.material_override = chitin
	abd.position = Vector3(0, 1.35, -0.95); abd.rotation_degrees = Vector3(68, 0, 0)
	vis.add_child(abd)
	var mark := MeshInstance3D.new()
	var ms := SphereMesh.new(); ms.radius = 0.55; ms.height = 0.95
	mark.mesh = ms; mark.material_override = crimson
	mark.position = Vector3(0, 2.25, -0.95)
	vis.add_child(mark)
	var head := MeshInstance3D.new()
	var hsph := SphereMesh.new(); hsph.radius = 0.72; hsph.height = 1.25
	head.mesh = hsph; head.material_override = chitin
	head.position = Vector3(0, 1.15, 0.55)
	vis.add_child(head)
	for ei in range(6):
		var ex := -0.32 + float(ei) * 0.128
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new(); es.radius = 0.065; es.height = 0.11
		eye.mesh = es; eye.material_override = crimson
		eye.position = Vector3(ex, 1.32 + (0.06 if ei % 2 == 0 else 0.0), 1.18)
		vis.add_child(eye)
	# 8 Articulated Tree-Trunk Chitin Legs!
	_spider_legs.clear()
	for side in [-1.0, 1.0]:
		for li in range(4):
			var piv := Node3D.new()
			piv.position = Vector3(float(side) * 0.62, 1.15, 0.65 - float(li) * 0.45)
			piv.rotation_degrees = Vector3(0, float(side) * (-28.0 + float(li) * 19.0), 0)
			vis.add_child(piv)
			var upper := MeshInstance3D.new()
			var uc := CylinderMesh.new(); uc.top_radius = 0.10; uc.bottom_radius = 0.15; uc.height = 1.65
			upper.mesh = uc; upper.material_override = chitin
			upper.position = Vector3(float(side) * 0.68, 0.52, 0); upper.rotation_degrees = Vector3(0, 0, -float(side) * 52.0)
			piv.add_child(upper)
			var lower := MeshInstance3D.new()
			var lc := CylinderMesh.new(); lc.top_radius = 0.09; lc.bottom_radius = 0.03; lc.height = 1.95
			lower.mesh = lc; lower.material_override = chitin
			lower.position = Vector3(float(side) * 1.55, 0.02, 0); lower.rotation_degrees = Vector3(0, 0, float(side) * 18.0)
			piv.add_child(lower)
			_spider_legs.append(piv)

func _tick_spider_boss(delta: float) -> void:
	if spider_boss == null or not is_instance_valid(spider_boss) or not bool(spider_boss.get("alive")):
		return
	_spider_gait += delta * 7.5
	for i in range(_spider_legs.size()):
		var leg := _spider_legs[i]
		if leg and is_instance_valid(leg):
			leg.rotation.z = sin(_spider_gait + float(i) * 1.15) * 0.18
	if not spider_boss.is_on_floor():
		spider_boss.velocity.y -= 20.0 * delta
	var actor := _lead()
	if actor and actor.global_position.z > 23.0:
		var d := spider_boss.global_position.distance_to(actor.global_position)
		if d < 24.0 and d > 2.3:
			var to_p := actor.global_position - spider_boss.global_position
			to_p.y = 0.0
			var dir := Locomotion.steer(spider_boss, to_p.normalized(), 2.4)
			spider_boss.velocity.x = lerpf(spider_boss.velocity.x, dir.x * 4.2, clampf(delta * 6.5, 0.0, 1.0))
			spider_boss.velocity.z = lerpf(spider_boss.velocity.z, dir.z * 4.2, clampf(delta * 6.5, 0.0, 1.0))
			var vis := spider_boss.get_node_or_null("Visual") as Node3D
			if vis:
				vis.rotation.y = lerp_angle(vis.rotation.y, atan2(dir.x, dir.z), clampf(delta * 8.0, 0.0, 1.0))
		else:
			spider_boss.velocity.x = move_toward(spider_boss.velocity.x, 0.0, 12.0 * delta)
			spider_boss.velocity.z = move_toward(spider_boss.velocity.z, 0.0, 12.0 * delta)
			if d <= 2.5:
				var cd := float(spider_boss.get("bite_cd")) - delta
				if cd <= 0.0:
					cd = 1.75
					if actor.has_method("take_damage"):
						actor.call("take_damage", 1, spider_boss.global_position)
				spider_boss.set("bite_cd", cd)
	spider_boss.move_and_slide()
	spider_boss.global_position.z = clampf(spider_boss.global_position.z, 25.0, 58.0)

func _add_china_whimsy() -> void:
	var w := get_node_or_null("/root/Whimsy")
	if w and w.has_method("setup") and hud:
		w.call("setup", self, hud, [
			{"pos": Vector3(-8.0, 0, -80.0), "kind": "bounce", "name": "Orchard mushroom"},
			{"pos": Vector3(-5.8, 0, -77.5), "kind": "giggle", "name": "Apple blossom"},
			{"pos": Vector3(9.5, 0, -52.0), "kind": "chime", "name": "Oak-bough chime"},
			{"pos": Vector3(7.5, 0.12, -10.0), "kind": "chime", "name": "Delft teacup chime"},
			{"pos": Vector3(9.8, 0.12, -7.8), "kind": "dance", "name": "Cobalt ballerina"},
			{"pos": Vector3(-7.5, 0.12, 8.0), "kind": "dance", "name": "Porcelain shepherdess"},
			{"pos": Vector3(-11.0, 0.12, 12.0), "kind": "giggle", "name": "Glazed milkmaid"},
			{"pos": Vector3(8.5, 0, 42.0), "kind": "bounce", "name": "Web-glade cap"},
			{"pos": Vector3(-8.5, 0, 74.0), "kind": "giggle", "name": "Forest lily"},
			{"pos": Vector3(-6.2, 0, 76.5), "kind": "chime", "name": "Quadling ruby chime"},
		], "glinda")
	OzEncounters.spawn_velvet_sanctum(self, Vector3(20.0, 0.12, 0.0), "sanctum_china", "charm_porcelain_grace", "Velvet Sanctum of Porcelain")
	for up in [Vector3(-5.8, 0.12, -14.0), Vector3(5.8, 0.12, -14.0), Vector3(-5.8, 0.12, 14.0), Vector3(5.8, 0.12, 14.0), Vector3(-6.5, 0.0, 48.0), Vector3(6.5, 0.0, 78.0)]:
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
	var tgt := GLINDA_GATE
	var lbl := "Glinda's Court"
	match beat:
		Beat.FIGHTING_TREES:
			tgt = Vector3(0, 0, -36.0); lbl = "Fighting Trees"
		Beat.CHINA_PRINCESS:
			tgt = PRINCESS_POS; lbl = "China Princess"
		Beat.SPIDER_GLADE:
			tgt = spider_boss.global_position if (spider_boss and is_instance_valid(spider_boss)) else SPIDER_POS
			lbl = "Giant Forest Spider"
		Beat.ROAD_TO_GLINDA:
			tgt = GLINDA_GATE; lbl = "Quadling Gate"
	compass.text = "%s  ·  %.0fm" % [lbl, actor.global_position.distance_to(tgt)]

func _add_map_border(half_x: float, half_z: float) -> void:
	var h := 3.2
	var thick := 2.0
	var col := Color(0.18, 0.28, 0.20)
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
