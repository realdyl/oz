extends Node3D

## Kansas Act 0 — B&W Gale farm (Baum). Basket → Toto → Aunt Em → shutter → cellar
## (too late) → FINAL STEP: house door E → cyclone lifts house → hourglass → Munchkinland.
## No film-only Marvel/Gulch/rainbow. Cannot fail. F9 skip · F8 force storm-to-door.

const MUNCHKIN_SCENE := "res://regions/munchkinland/landing_square.tscn"
const DEBRIS_SCENE := preload("res://regions/kansas/debris.tscn")
const WorldKit := preload("res://systems/world_kit.gd")
const OzEncounters := preload("res://systems/oz_encounters.gd")

enum Phase {
	INTRO,
	NEED_BASKET,
	NEED_TOTO,
	NEED_AUNT,
	NEED_SHUTTER,
	NEED_CELLAR,
	STORM_RUN,
	HOUSE_LIFT,
	FADE,
	STRIKE,
}

@onready var hud: CanvasLayer = $PlayHUD
@onready var player: CharacterBody3D = $Player
@onready var basket: Area3D = $Basket
@onready var toto: CharacterBody3D = $Toto
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var farmhouse: Node3D = $Farmhouse

var fade: ColorRect
var compass: Label
var phase: Phase = Phase.INTRO
var _storm_time: float = 0.0
var _spawn_cd: float = 0.0
var _safe_pos: Vector3
var _fade_t: float = 0.0
var _lift_t: float = 0.0
var _marker: Node3D
var _wind_clothes: Array = []
var _windmill_rotor: Node3D = null
var shutter: Area3D
var cellar: Area3D
var house_door: Area3D
var barn: Node3D
var aunt_em: Node3D
var uncle_henry: Node3D
var cyclone: Node3D
var shutter_done: bool = false
var cellar_touched: bool = false
var aunt_talked: bool = false
var _near_shutter: bool = false
var _near_cellar: bool = false
var _near_aunt: bool = false
var _near_uncle: bool = false
var _near_door: bool = false
var _aunt_line: int = 0
var wind_t: float = 0.0
var _house_base_y: float = 0.0
var _near_build_door: Area3D = null
var _inside_building: bool = false
var _door_busy: bool = false
var _active_build_door: Area3D = null
var _cam_out_len: float = 5.5
var _cam_out_fov: float = 65.0
var _cam_out_pitch: float = -18.0
var _cyclone_rings: Array = []
var _lightning_cd: float = 1.8
var _lightning_flash: float = 0.0
var whimsy_score: int = 0

# Spoken AFTER Toto is already in the basket — never "go get Toto" again.
const AUNT_LINES := [
	"There you are — and Toto's safe in the basket. Good girl.",
	"Henry's gone to look after the stock. Latch that shutter before the wind takes it.",
	"When the shutter's done, check the cellar. I'll be waiting below.",
]
const AUNT_IDLE := "Keep Toto close, Dorothy. This prairie wind is mean today."
const UNCLE_LINES := [
	"Stock's restless. If the sky goes green, you run for the house — not the cellar.",
	"Em's on the porch. Don't keep her waiting.",
]

func _ready() -> void:
	hud.add_to_group("hud")
	fade = hud.get_node_or_null("Fade") as ColorRect
	if fade == null:
		fade = ColorRect.new()
		fade.name = "Fade"
		fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.z_index = 20
		hud.add_child(fade)
	_ensure_compass()
	_stabilize_lighting()
	_build_farm_layout()
	# Spread objectives across an open yard — basket never wedged in a building corner.
	# Player spawn ~ (4, 10); farmhouse ~ (-2, -8); barn ~ (-18, 22).
	basket.global_position = Vector3(10.0, 0.05, 24.0) # open south yard, clear of walls
	toto.global_position = Vector3(22.0, 0.05, -18.0) # east chicken run past house
	_dress_basket()
	_spawn_basket_marker()
	hud.set_objective("Grey Kansas. South open yard — pick up Toto's basket (glowing post · E).")
	if hud.has_method("set_kansas_mode"):
		hud.set_kansas_mode(true)
	basket.taken.connect(_on_basket_taken)
	toto.joined.connect(_on_toto_joined)
	_safe_pos = player.global_position
	fade.color = Color(0, 0, 0, 0)
	fade.visible = true
	phase = Phase.NEED_BASKET
	_fade_t = -1.0
	if farmhouse:
		_house_base_y = farmhouse.global_position.y
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("on_level_start"):
		lt.on_level_start("Kansas · the Gale farm")
	_dlg("Narrator", "The prairie is grey. Aunt Em and Uncle Henry work the farm. Toto is loose again.")

func _dlg(speaker: String, text: String) -> void:
	var d := get_node_or_null("/root/DialogueUI")
	if d and d.has_method("say"):
		d.say(speaker, text, true, 4.0)

func _stabilize_lighting() -> void:
	if world_env and world_env.environment:
		WorldKit.apply_sky_and_weather(world_env, "kansas")
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.shadow_enabled = true
		sun.shadow_bias = 0.1
		sun.shadow_normal_bias = 3.0
		sun.shadow_blur = 2.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 48.0
		sun.light_angular_distance = 1.5
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var path := str(mi.get_path())
		if path.contains("Ground") or path.contains("Dirt") or path.contains("pad") or path.contains("Pad"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if player:
		for n in player.find_children("*", "MeshInstance3D", true, false):
			var mi2 := n as MeshInstance3D
			if mi2:
				mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_farm_layout() -> void:
	# Expansive prairie pads (Munchkinland-scale) — never scale main Ground.
	_add_ground_pad(Vector3(0, -0.05, 0), Vector3(100, 0.1, 100))
	_add_ground_pad(Vector3(0, -0.05, -40), Vector3(90, 0.1, 50))
	_add_ground_pad(Vector3(0, -0.05, 40), Vector3(90, 0.1, 50))
	_add_ground_pad(Vector3(-40, -0.05, 0), Vector3(50, 0.1, 90))
	_add_ground_pad(Vector3(40, -0.05, 0), Vector3(50, 0.1, 90))
	# Replace sporadic flat baked fence slabs with clean rustic split-rail posts
	for fn in ["FenceN1", "FenceN2", "FenceE1", "FenceE2", "FenceW1", "FenceS1", "FenceBroken"]:
		var fnode := get_node_or_null(fn) as Node3D
		if fnode:
			fnode.visible = false
			for fc in fnode.find_children("*", "CollisionShape3D", true, false):
				if fc is CollisionShape3D:
					(fc as CollisionShape3D).disabled = true
	_add_barn(Vector3(-22.0, 0.0, 26.0))
	_add_fence_ring(Vector3(-22.0, 0.0, 26.0), 8.0, 14)
	_add_fence_ring(Vector3(24.0, 0.0, -20.0), 6.0, 12)
	# Dress Gale Farmhouse identically to L7 Kansas Homecoming (hide bare flat-slab .tscn roof!)
	if farmhouse:
		var old_roof := farmhouse.get_node_or_null("Roof") as Node3D
		if old_roof:
			old_roof.visible = false
		var old_body := farmhouse.get_node_or_null("Body/Mesh") as MeshInstance3D
		if old_body:
			var fm := StandardMaterial3D.new()
			fm.albedo_color = Color(0.48, 0.48, 0.50)
			fm.roughness = 0.88
			old_body.material_override = fm
		WorldKit.dress_cottage_exterior(farmhouse, 3.5, 2.75, 4.2, Color(0.48, 0.48, 0.50), Color(0.28, 0.28, 0.31))
		WorldKit.make_building_crest_sign(farmhouse, Vector3(0, 4.35, 3.1), "GALE FARMHOUSE", Color(0.55, 0.55, 0.58), true)
	# Shutter / cellar / door relative to Farmhouse node at (-2,0,-8)
	var hx := -2.0
	var hz := -8.0
	_add_house_shutter(Vector3(hx + 3.6, 0.0, hz + 0.5))
	_add_cellar_door(Vector3(hx - 4.2, 0.0, hz + 1.5))
	_add_house_door(Vector3(hx, 0.0, hz + 3.6))
	# Aunt on porch east — keep clear of the enterable farmhouse door (south face).
	_add_aunt_em(Vector3(hx + 3.2, 0.0, hz + 4.8))
	_add_uncle_henry(Vector3(-16.0, 0.0, 18.0))
	_add_clothesline(Vector3(8.0, 0.0, 4.0))
	_add_windmill_ghost(Vector3(-32.0, 0.0, -10.0))
	_add_cyclone_funnel(Vector3(12.0, 0.0, -36.0))
	WorldKit.scatter_swaying_grass(self, Vector3(0, 0, 4), 36.0, 120, 4.8)
	# Enterable Kansas buildings (clean invisible door triggers flush with each building's real architectural door!).
	_make_enterable_box(farmhouse, "Farmhouse", Vector3(hx, 0.12, hz + 0.2), Vector3(hx, 0.12, hz + 3.8), Vector3(5.5, 3.6, 4.2))
	_make_enterable_box(barn, "Barn", Vector3(-22.0, 0.12, 26.0), Vector3(-22.0, 0.12, 29.8), Vector3(5.5, 3.8, 4.5))
	_build_chicken_coop_and_chickens(Vector3(24.0, 0.0, -20.0))
	_add_map_border(56.0, 54.0)
	WorldKit.add_horizon_hills(self, 56.0, 54.0, Color(0.32, 0.32, 0.35))
	_add_kansas_whimsy()

func _dress_basket() -> void:
	## Sculpted woven wicker farm basket with arched handle & cloth liner.
	if basket == null:
		return
	basket.scale = Vector3(1.55, 1.55, 1.55)
	WorldKit.build_wicker_basket(basket)
	WorldKit.make_world_badge(basket, Vector3(0, 1.10, 0), "✦  Toto's Basket (E)", Color(0.92, 0.92, 0.96), 12.0)
	var col := basket.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col and col.shape is SphereShape3D:
		(col.shape as SphereShape3D).radius = 1.5

func _add_map_border(half_x: float, half_z: float) -> void:
	var h := 2.8
	var thick := 2.0
	var col := Color(0.28, 0.28, 0.3)
	var specs := [
		{"pos": Vector3(0, h * 0.5, -half_z), "size": Vector3(half_x * 2.0 + thick * 2.0, h, thick)},
		{"pos": Vector3(0, h * 0.5, half_z), "size": Vector3(half_x * 2.0 + thick * 2.0, h, thick)},
		{"pos": Vector3(-half_x, h * 0.5, 0), "size": Vector3(thick, h, half_z * 2.0)},
		{"pos": Vector3(half_x, h * 0.5, 0), "size": Vector3(thick, h, half_z * 2.0)},
	]
	for s in specs:
		var body := StaticBody3D.new()
		body.name = "MapBorder"
		add_child(body)
		body.global_position = s["pos"]
		body.collision_layer = 1
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = s["size"]
		mi.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 0.95
		mi.material_override = mat
		body.add_child(mi)
		var c := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = s["size"]
		c.shape = sh
		body.add_child(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 191
	for i in 40:
		var t := float(i) / 40.0 * TAU
		var p := Vector3(
			cos(t) * (half_x - 1.2 + rng.randf_range(-0.4, 0.4)),
			0.0,
			sin(t) * (half_z - 1.2 + rng.randf_range(-0.4, 0.4))
		)
		var tree := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		var th := rng.randf_range(1.4, 2.4)
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.14
		cyl.height = th
		tree.mesh = cyl
		var tm := StandardMaterial3D.new()
		tm.albedo_color = Color(0.32, 0.32, 0.34)
		tree.material_override = tm
		add_child(tree)
		tree.global_position = p + Vector3(0, th * 0.5, 0)
		var canopy := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = rng.randf_range(0.7, 1.2)
		sph.height = sph.radius * 1.5
		canopy.mesh = sph
		var cm := StandardMaterial3D.new()
		cm.albedo_color = Color(0.35, 0.35, 0.38)
		canopy.material_override = cm
		add_child(canopy)
		canopy.global_position = p + Vector3(0, th + 0.5, 0)

func _add_ground_pad(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.global_position = at
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.42, 0.45)
	mat.roughness = 0.95
	mi.material_override = mat
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	body.add_child(col)

func _add_barn(at: Vector3) -> void:
	barn = StaticBody3D.new()
	barn.name = "Barn"
	add_child(barn)
	barn.global_position = at
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(7.0, 4.5, 6.0)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.38)
	mi.material_override = mat
	barn.add_child(mi)
	mi.position = Vector3(0, 2.25, 0)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(7.0, 4.5, 6.0)
	col.shape = sh
	col.position = Vector3(0, 2.25, 0)
	barn.add_child(col)
	var roof := MeshInstance3D.new()
	var r := BoxMesh.new()
	r.size = Vector3(7.8, 0.35, 6.6)
	roof.mesh = r
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.22, 0.22, 0.25)
	roof.material_override = rm
	barn.add_child(roof)
	roof.position = Vector3(0, 4.6, 0)
	WorldKit.dress_cottage_exterior(barn, 3.5, 3.0, 4.5, Color(0.35, 0.35, 0.38), Color(0.22, 0.22, 0.25), true)
	WorldKit.make_building_crest_sign(barn, Vector3(0, 4.65, 3.3), "BARN", Color(0.45, 0.45, 0.48), true)

func _add_chicken_coop(at: Vector3) -> void:
	var coop := StaticBody3D.new()
	coop.name = "ChickenCoop"
	add_child(coop)
	coop.global_position = at
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.2, 1.6, 2.4)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.4, 0.42)
	mi.material_override = mat
	coop.add_child(mi)
	mi.position = Vector3(0, 0.8, 0)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(3.2, 1.6, 2.4)
	col.shape = sh
	col.position = Vector3(0, 0.8, 0)
	coop.add_child(col)
	WorldKit.make_world_badge(coop, Vector3(0, 2.1, 0), "✦  Chicken Run", Color(0.90, 0.90, 0.94), 10.0)

func _add_fence_ring(center: Vector3, radius: float, posts: int) -> void:
	for i in posts:
		var ang := float(i) / float(posts) * TAU
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.07
		cyl.height = 1.0
		post.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.4, 0.42)
		post.material_override = mat
		add_child(post)
		post.global_position = center + Vector3(cos(ang) * radius, 0.5, sin(ang) * radius)

func _grey_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m

func _add_person(name: String, at: Vector3, _dress: Color, _hair: Color) -> Node3D:
	var root := Node3D.new()
	root.name = name
	add_child(root)
	root.global_position = at
	WorldKit.build_kansas_farmer(root, "Aunt" in name)
	WorldKit.make_world_badge(root, Vector3(0, 2.25, 0), "✦  %s" % name.replace("_", " "), Color(0.94, 0.94, 0.98), 11.0)
	return root

func _add_aunt_em(at: Vector3) -> void:
	aunt_em = _add_person("Aunt Em", at, Color(0.48, 0.48, 0.5), Color(0.55, 0.55, 0.58))
	var area := Area3D.new()
	area.name = "AuntArea"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.8
	col.shape = sph
	area.add_child(col)
	aunt_em.add_child(area)
	area.body_entered.connect(func(b): if b.is_in_group("player"): _near_aunt = true)
	area.body_exited.connect(func(b): if b.is_in_group("player"): _near_aunt = false)

func _add_uncle_henry(at: Vector3) -> void:
	uncle_henry = _add_person("Uncle Henry", at, Color(0.36, 0.36, 0.38), Color(0.3, 0.3, 0.32))
	# hat brim
	var brim := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.28
	cyl.height = 0.04
	brim.mesh = cyl
	brim.material_override = _grey_mat(Color(0.25, 0.25, 0.27))
	brim.position = Vector3(0, 1.95, 0)
	uncle_henry.add_child(brim)
	var area := Area3D.new()
	area.name = "UncleArea"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.8
	col.shape = sph
	area.add_child(col)
	uncle_henry.add_child(area)
	area.body_entered.connect(func(b): if b.is_in_group("player"): _near_uncle = true)
	area.body_exited.connect(func(b): if b.is_in_group("player"): _near_uncle = false)

func _add_house_shutter(at: Vector3) -> void:
	shutter = Area3D.new()
	shutter.name = "Shutter"
	shutter.collision_layer = 0
	shutter.collision_mask = 2
	shutter.monitoring = true
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.6
	col.shape = sph
	shutter.add_child(col)
	# Window frame + shutter panel
	var frame := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(1.4, 1.5, 0.12)
	frame.mesh = fb
	frame.material_override = _grey_mat(Color(0.42, 0.42, 0.44))
	frame.position = Vector3(0, 1.1, 0)
	shutter.add_child(frame)
	var panel := MeshInstance3D.new()
	panel.name = "ShutterPanel"
	var pb := BoxMesh.new()
	pb.size = Vector3(0.65, 1.35, 0.08)
	panel.mesh = pb
	var pm := _grey_mat(Color(0.55, 0.55, 0.58))
	pm.emission_enabled = true
	pm.emission = Color(0.75, 0.75, 0.8)
	pm.emission_energy_multiplier = 0.55
	panel.material_override = pm
	panel.position = Vector3(-0.35, 1.1, 0.1)
	shutter.add_child(panel)
	add_child(shutter)
	shutter.global_position = at
	shutter.body_entered.connect(func(b): if b.is_in_group("player"): _near_shutter = true)
	shutter.body_exited.connect(func(b): if b.is_in_group("player"): _near_shutter = false)

func _add_cellar_door(at: Vector3) -> void:
	cellar = Area3D.new()
	cellar.name = "Cellar"
	cellar.collision_layer = 0
	cellar.collision_mask = 2
	cellar.monitoring = true
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.5
	col.shape = sph
	cellar.add_child(col)
	# Angled cellar doors (two flaps)
	for i in 2:
		var flap := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.85, 0.1, 1.3)
		flap.mesh = box
		var mat := _grey_mat(Color(0.22, 0.22, 0.25))
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.4, 0.45)
		mat.emission_energy_multiplier = 0.45
		flap.material_override = mat
		flap.position = Vector3(-0.45 + float(i) * 0.9, 0.08, 0)
		flap.rotation_degrees.x = -18.0
		cellar.add_child(flap)
	WorldKit.make_world_badge(cellar, Vector3(0, 1.15, 0), "✦  Storm Cellar (E)", Color(0.92, 0.92, 0.96), 10.0)
	add_child(cellar)
	cellar.global_position = at
	cellar.body_entered.connect(func(b): if b.is_in_group("player"): _near_cellar = true)
	cellar.body_exited.connect(func(b): if b.is_in_group("player"): _near_cellar = false)

func _add_house_door(at: Vector3) -> void:
	house_door = Area3D.new()
	house_door.name = "HouseDoor"
	house_door.collision_layer = 0
	house_door.collision_mask = 2
	house_door.monitoring = true
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.7
	col.shape = sph
	house_door.add_child(col)
	var door := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.1, 2.1, 0.12)
	door.mesh = box
	var mat := _grey_mat(Color(0.3, 0.3, 0.33))
	mat.emission_enabled = true
	mat.emission = Color(0.85, 0.85, 0.9)
	mat.emission_energy_multiplier = 0.7
	door.material_override = mat
	door.position = Vector3(0, 1.05, 0)
	house_door.add_child(door)
	WorldKit.make_world_badge(house_door, Vector3(0, 2.45, 0), "✦  Farmhouse Shelter (E)", Color(0.98, 0.98, 1.0), 14.0)
	add_child(house_door)
	house_door.global_position = at
	house_door.body_entered.connect(func(b): if b.is_in_group("player"): _near_door = true)
	house_door.body_exited.connect(func(b): if b.is_in_group("player"): _near_door = false)
	house_door.visible = false # revealed as FINAL STEP

func _add_clothesline(at: Vector3) -> void:
	_wind_clothes = WorldKit.build_clothesline(self, at)

func _add_windmill_ghost(at: Vector3) -> void:
	_windmill_rotor = WorldKit.build_lattice_windmill(self, at)

func _add_cyclone_funnel(at: Vector3) -> void:
	## Dramatic multi-tier twisting B&W prairie cyclone with anvil storm cloud & orbiting wind debris!
	cyclone = Node3D.new()
	cyclone.name = "Cyclone"
	add_child(cyclone)
	cyclone.global_position = at
	cyclone.visible = false
	_cyclone_rings.clear()
	for i in range(9):
		var t := float(i) / 8.0
		var ring_piv := Node3D.new()
		ring_piv.position = Vector3(0.0, 1.4 + float(i) * 3.2, 0.0)
		cyclone.add_child(ring_piv)
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.radial_segments = 20
		cyl.bottom_radius = lerpf(1.1, 9.5, pow(t, 1.35))
		cyl.top_radius = lerpf(1.8, 12.2, pow(t, 1.35))
		cyl.height = 3.8
		seg.mesh = cyl
		var mat := StandardMaterial3D.new()
		var shade := lerpf(0.24, 0.14, t)
		mat.albedo_color = Color(shade, shade, shade + 0.02, lerpf(0.62, 0.88, t))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.95
		mat.emission_enabled = true
		mat.emission = Color(0.28, 0.28, 0.32)
		mat.emission_energy_multiplier = 0.22
		seg.material_override = mat
		ring_piv.add_child(seg)
		# Orbiting storm debris planks & dust streaks around each vortex tier
		for d in range(3):
			var da := float(d) / 3.0 * TAU + float(i) * 0.7
			var dr := cyl.top_radius + 1.4 + float(d) * 0.6
			var plank := MeshInstance3D.new()
			var pb := BoxMesh.new()
			pb.size = Vector3(1.6, 0.16, 0.34)
			plank.mesh = pb
			plank.material_override = _grey_mat(Color(0.18, 0.18, 0.20))
			plank.position = Vector3(cos(da) * dr, 0.0, sin(da) * dr)
			plank.rotation_degrees = Vector3(25.0 * float(d), rad_to_deg(-da), 18.0)
			ring_piv.add_child(plank)
		_cyclone_rings.append(ring_piv)
	# Churning overhead storm anvil cloud
	var anvil := MeshInstance3D.new()
	var asph := SphereMesh.new()
	asph.radius = 18.0
	asph.height = 7.0
	anvil.mesh = asph
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.14, 0.14, 0.16, 0.90)
	amat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	anvil.material_override = amat
	anvil.position = Vector3(0, 31.0, 0)
	cyclone.add_child(anvil)

func _ensure_compass() -> void:
	compass = hud.get_node_or_null("Compass") as Label
	if compass == null:
		compass = Label.new()
		compass.name = "Compass"
		compass.position = Vector2(16, 96)
		compass.add_theme_font_size_override("font_size", 18)
		compass.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
		hud.add_child(compass)

func _spawn_basket_marker() -> void:
	_marker = MeshInstance3D.new()
	_marker.name = "BasketMarker"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.12
	cyl.height = 2.8
	_marker.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.9, 1.0)
	mat.emission_energy_multiplier = 1.4
	_marker.material_override = mat
	add_child(_marker)
	# Place lantern marker 1.4m beside the basket (never stabbing straight through it!)
	_marker.global_position = basket.global_position + Vector3(1.4, 1.5, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			_skip_to_munchkin()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F8:
			if not player.has_basket:
				basket.take()
			if not player.has_toto:
				toto._join(player)
			shutter_done = true
			cellar_touched = true
			aunt_talked = true
			_enter_storm_run()
			get_viewport().set_input_as_handled()

func _skip_to_munchkin() -> void:
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("go_to"):
		lt.go_to(MUNCHKIN_SCENE, "The hourglass turns…", "Munchkinland · the landing")
	else:
		get_tree().change_scene_to_file(MUNCHKIN_SCENE)

func _process(delta: float) -> void:
	_update_compass()
	_wind_props(delta)
	if Input.is_action_just_pressed("interact"):
		_try_interact()

	if _fade_t < 0.0:
		_fade_t = minf(_fade_t + delta * 0.7, 0.0)
		fade.color = Color(0, 0, 0, clampf(-_fade_t, 0.0, 1.0))
		return

	if phase == Phase.STORM_RUN:
		_storm_time += delta
		_spawn_cd -= delta
		if _spawn_cd <= 0.0:
			_spawn_cd = maxf(0.45, 0.95 - _storm_time * 0.025)
			_spawn_debris(false)
		# Dynamic storm lightning flashes + approaching funnel
		_lightning_cd -= delta
		if _lightning_cd <= 0.0:
			_lightning_cd = randf_range(1.6, 3.8)
			_lightning_flash = 0.65
		_lightning_flash = maxf(0.0, _lightning_flash - delta * 2.4)
		if world_env and world_env.environment:
			var base_b := 0.66 - minf(_storm_time, 12.0) * 0.016
			world_env.environment.adjustment_brightness = base_b + _lightning_flash * 0.55
		if cyclone:
			var target_c := Vector3(4.0, 0.0, -22.0)
			cyclone.global_position = cyclone.global_position.lerp(target_c, 1.0 - exp(-0.35 * delta))
		# Henry runs toward barn during storm
		if uncle_henry and _storm_time < 8.0:
			var dest := Vector3(-14.0, 0.0, 18.0)
			uncle_henry.global_position = uncle_henry.global_position.lerp(dest, 1.0 - exp(-1.2 * delta))

	if phase == Phase.HOUSE_LIFT:
		_lift_t += delta
		var p_norm := clampf(_lift_t / 4.2, 0.0, 1.0)
		var rise := ease(p_norm, 1.65) * 22.0
		var swirl_r := ease(p_norm, 1.4) * 4.5
		var swirl_ang := _lift_t * 2.2
		_lightning_cd -= delta
		if _lightning_cd <= 0.0:
			_lightning_cd = randf_range(0.7, 1.5)
			_lightning_flash = 0.85
		_lightning_flash = maxf(0.0, _lightning_flash - delta * 3.0)
		if farmhouse:
			farmhouse.global_position.y = _house_base_y + rise
			farmhouse.global_position.x = -2.0 + cos(swirl_ang) * swirl_r
			farmhouse.global_position.z = -8.0 + sin(swirl_ang) * swirl_r
			farmhouse.rotation_degrees.y = _lift_t * 24.0
			farmhouse.rotation_degrees.z = sin(_lift_t * 2.6) * (6.0 + p_norm * 10.0)
			farmhouse.rotation_degrees.x = cos(_lift_t * 2.1) * (4.0 + p_norm * 7.0)
		if player:
			player.global_position = (farmhouse.global_position if farmhouse else Vector3(-2.0, rise, -8.0)) + Vector3(0, 1.1, 2.0)
			var cam_piv := player.get_node_or_null("CameraPivot") as Node3D
			if cam_piv:
				var shake := (0.14 + p_norm * 0.22)
				cam_piv.position = Vector3(sin(_lift_t * 31.0) * shake, 1.6 + cos(_lift_t * 27.0) * shake, 0.0)
		if cyclone and farmhouse:
			cyclone.global_position = Vector3(farmhouse.global_position.x, 0.0, farmhouse.global_position.z - 2.0)
		if world_env and world_env.environment:
			world_env.environment.adjustment_brightness = 0.52 + p_norm * 0.28 + _lightning_flash * 0.65
		if _lift_t >= 4.2:
			phase = Phase.FADE
			_fade_t = 0.0
			hud.set_objective("")
			_dlg("Narrator", "The cyclone tears the farmhouse from the Kansas prairie and carries it skyward…")

	if phase == Phase.FADE:
		_fade_t += delta * 0.5
		fade.color = Color(1, 1, 1, clampf(_fade_t, 0.0, 1.0))
		if _fade_t >= 1.05:
			phase = Phase.STRIKE
			var lt2 := get_node_or_null("/root/LevelTransition")
			if lt2 and lt2.has_method("go_to"):
				lt2.go_to(MUNCHKIN_SCENE, "The house lands — the hourglass turns…", "Munchkinland · color returns")
			else:
				get_tree().change_scene_to_file(MUNCHKIN_SCENE)

	_update_prompts()

func _try_interact() -> void:
	# Exit always works while inside.
	if _inside_building:
		_try_build_door()
		return
	# Storm FINAL STEP house door beats everything when near it.
	if phase == Phase.STORM_RUN and _near_door:
		_enter_house()
		return
	# NPCs and story props ALWAYS beat optional building enter (porch/Aunt overlap).
	if _near_aunt:
		_talk_aunt()
		return
	if _near_uncle:
		_talk_uncle()
		return
	if _near_shutter and not shutter_done and phase in [Phase.NEED_SHUTTER, Phase.NEED_CELLAR]:
		_close_shutter()
		return
	if _near_cellar and not cellar_touched:
		if phase in [Phase.NEED_SHUTTER, Phase.NEED_CELLAR]:
			if not shutter_done:
				shutter_done = true
			_touch_cellar()
			return
		elif phase == Phase.NEED_AUNT:
			_dlg("Narrator", "Speak with Aunt Em on the porch first — she's calling for you!")
			return
	# Optional enterable shells only when not doing story talk.
	if _near_build_door != null:
		if _try_build_door():
			return
	var w := get_node_or_null("/root/Whimsy")
	if w and w.has_method("try_collect") and player:
		w.call("try_collect", player)

func _talk_uncle() -> void:
	var line: String = UNCLE_LINES[0] if phase <= Phase.NEED_AUNT else UNCLE_LINES[mini(1, UNCLE_LINES.size() - 1)]
	_dlg("Uncle Henry", line)

func _update_prompts() -> void:
	if _inside_building and _active_build_door:
		hud.set_prompt("E  —  Exit %s" % str(_active_build_door.get_meta("title")))
	elif phase == Phase.STORM_RUN and _near_door:
		hud.set_prompt("E  —  FINAL STEP: Get into the house with Toto!")
	elif _near_aunt:
		hud.set_prompt("E  —  Talk to Aunt Em")
	elif _near_uncle:
		hud.set_prompt("E  —  Talk to Uncle Henry")
	elif phase == Phase.NEED_SHUTTER and _near_shutter:
		hud.set_prompt("E  —  Latch the farmhouse shutter")
	elif phase == Phase.NEED_CELLAR and _near_cellar:
		hud.set_prompt("E  —  Check the cellar (Aunt Em is below)")
	elif phase == Phase.STORM_RUN:
		hud.set_prompt("Run to the glowing farmhouse door — E to enter")
	elif _near_build_door != null:
		hud.set_prompt("E  —  Enter %s" % str(_near_build_door.get_meta("title")))
	else:
		var w := get_node_or_null("/root/Whimsy")
		if w and w.has_method("prompt_if_near"):
			var p: String = str(w.call("prompt_if_near"))
			if p != "":
				hud.set_prompt(p)

func _add_kansas_whimsy() -> void:
	var w := get_node_or_null("/root/Whimsy")
	if w == null or not w.has_method("setup") or hud == null:
		return
	# Grey prairie side-fun — same pattern as Oz, monochrome palette.
	w.call("setup", self, hud, [
		{"pos": Vector3(14, 0, 14), "kind": "bounce", "name": "Prairie bounce"},
		{"pos": Vector3(-12, 0, 8), "kind": "giggle", "name": "Dust giggle"},
		{"pos": Vector3(13.5, 0, -6), "kind": "chime", "name": "Fence chime"},
		{"pos": Vector3(-8, 0, 28), "kind": "dance", "name": "Barn dance ring"},
		{"pos": Vector3(18, 0, 30), "kind": "giggle", "name": "Yard giggle"},
	], "kansas")
	# Phase P6.3: Kansas Storm Barometer & Aunt Em's Silver Thimble Side Quest ("The Dropping Barometer")
	OzEncounters.spawn_monument(self, Vector3(-13.5, 0.0, 12.5), "chime", "Storm Barometer", "kansas_storm_prep", Color(0.78, 0.80, 0.84), 10)
	OzEncounters.spawn_monument(self, Vector3(-19.5, 0.0, 21.5), "chime", "Aunt Em's Thimble", "kansas_storm_prep", Color(0.88, 0.90, 0.94), 10)

func _wind_props(delta: float) -> void:
	wind_t += delta
	var spin_mul := 1.2
	var storm_fac := 0.0
	if phase == Phase.NEED_SHUTTER:
		storm_fac = 0.35
	elif phase == Phase.NEED_CELLAR:
		storm_fac = 0.62
	elif phase >= Phase.STORM_RUN:
		storm_fac = 1.0
	if world_env:
		WorldKit.set_sky_storm_factor(world_env, storm_fac, _lightning_flash)
	if phase == Phase.STORM_RUN or phase == Phase.HOUSE_LIFT:
		spin_mul = 4.5
	var cloth_amp := 0.24 if phase < Phase.STORM_RUN else 0.72
	for ci in range(_wind_clothes.size()):
		var cl := _wind_clothes[ci] as Node3D
		if cl and is_instance_valid(cl):
			cl.rotation.x = sin(wind_t * 2.8 + float(ci) * 0.9) * cloth_amp
	if _windmill_rotor and is_instance_valid(_windmill_rotor):
		_windmill_rotor.rotate_z(delta * spin_mul * 1.4)
	if cyclone and cyclone.visible:
		for ri in range(_cyclone_rings.size()):
			var rp := _cyclone_rings[ri] as Node3D
			if rp and is_instance_valid(rp):
				var t := float(ri) / maxf(1.0, float(_cyclone_rings.size() - 1))
				rp.rotate_y(delta * spin_mul * (2.6 - t * 1.1))
				rp.position.x = sin(wind_t * 2.4 + float(ri) * 0.65) * (0.4 + t * 2.6)
				rp.position.z = cos(wind_t * 2.0 + float(ri) * 0.55) * (0.4 + t * 2.2)

func _update_compass() -> void:
	if compass == null or player == null:
		return
	var target: Node3D = null
	var label := ""
	match phase:
		Phase.NEED_BASKET:
			if basket and not basket.claimed:
				target = basket
				label = "Basket (open yard)"
		Phase.NEED_TOTO:
			if toto and not toto.joined_basket:
				target = toto
				label = "Toto (chicken run)"
		Phase.NEED_AUNT:
			target = aunt_em
			label = "Aunt Em (porch)"
		Phase.NEED_SHUTTER:
			target = shutter
			label = "Shutter"
		Phase.NEED_CELLAR:
			target = cellar
			label = "Cellar doors"
		Phase.STORM_RUN:
			target = house_door
			label = "FINAL: House door"
		_:
			compass.text = "F9 → Munchkinland   ·   F8 force storm"
			return
	if target == null:
		compass.text = ""
		return
	var to: Vector3 = target.global_position - player.global_position
	to.y = 0.0
	var dist := to.length()
	var cam: Node3D = player.get_node_or_null("CameraPivot")
	var forward := Vector3(0, 0, -1)
	if cam:
		forward = -cam.global_transform.basis.z
		forward.y = 0.0
		if forward.length() > 0.01:
			forward = forward.normalized()
	var right := Vector3.UP.cross(forward)
	var local := Vector2(to.dot(right), to.dot(forward))
	var ang := rad_to_deg(atan2(local.x, local.y))
	var dir := "ahead"
	if ang > 30.0 and ang < 150.0:
		dir = "right"
	elif ang < -30.0 and ang > -150.0:
		dir = "left"
	elif absf(ang) >= 150.0:
		dir = "behind"
	compass.text = "%s is %s (%.0fm)  ·  F9 skip" % [label, dir, dist]

func _on_basket_taken() -> void:
	phase = Phase.NEED_TOTO
	hud.set_objective("Toto is at the chicken run — east past the house (compass). Call him into the basket (E).")
	_safe_pos = player.global_position
	# Attach a visible woven wicker basket right to Dorothy's hand!
	if player:
		var vis := player.get_node_or_null("Visual") as Node3D
		if vis and vis.get_node_or_null("CarriedBasket") == null:
			var cb := Node3D.new()
			cb.name = "CarriedBasket"
			cb.position = Vector3(0.32, 0.72, -0.18)
			cb.scale = Vector3(0.65, 0.65, 0.65)
			vis.add_child(cb)
			WorldKit.build_wicker_basket(cb)
	# Offset lantern marker 2.0m beside Toto so it NEVER impales or overlaps Toto!
	_retarget_marker(toto.global_position + Vector3(2.0, 0.0, 1.2))
	_dlg("Dorothy", "There — Toto's basket. Now where's that dog?")

func _on_toto_joined() -> void:
	phase = Phase.NEED_AUNT
	hud.set_objective("Aunt Em is on the farmhouse porch — go hear her (E).")
	_safe_pos = player.global_position
	if aunt_em:
		_retarget_marker(aunt_em.global_position + Vector3(0, 2.0, 0))
	_dlg("Toto", "*yip*")

func _talk_aunt() -> void:
	# If Dorothy hasn't found Toto & his basket yet, give a clear reminder without burning Aunt Em's quest state!
	if phase < Phase.NEED_AUNT:
		_dlg("Aunt Em", "Find Toto and his wicker basket first, Dorothy — the wind's turning mean!")
		return
	# After her quest lines, stop repeating idle lines on E (matching Locasta's clean behavior!)
	if aunt_talked or _aunt_line >= AUNT_LINES.size():
		aunt_talked = true
		if phase == Phase.NEED_AUNT:
			phase = Phase.NEED_SHUTTER
			hud.set_objective("Latch the glowing shutter on the farmhouse wall (E) — or check the storm cellar.")
			if shutter:
				_retarget_marker(shutter.global_position + Vector3(0, 1.4, 0))
		return
	_dlg("Aunt Em", AUNT_LINES[_aunt_line])
	_aunt_line += 1
	if _aunt_line >= AUNT_LINES.size():
		aunt_talked = true
		phase = Phase.NEED_SHUTTER
		hud.set_objective("Latch the glowing shutter on the farmhouse wall (E) — or check the storm cellar.")
		if shutter:
			_retarget_marker(shutter.global_position + Vector3(0, 1.4, 0))
		hud.set_prompt("Shutter — east wall of the house (or Storm Cellar on the west)")

func _close_shutter() -> void:
	shutter_done = true
	if shutter:
		var panel := shutter.get_node_or_null("ShutterPanel") as MeshInstance3D
		if panel:
			panel.rotation_degrees.y = 95.0
			panel.position.x = 0.2
	hud.set_prompt("Shutter latched.")
	phase = Phase.NEED_CELLAR
	hud.set_objective("Cellar doors by the house — E to check. (Aunt Em already went below.)")
	if cellar:
		_retarget_marker(cellar.global_position + Vector3(0, 0.8, 0))
	_dlg("Aunt Em", "The shutter — good girl! Now the cellar!")

func _touch_cellar() -> void:
	cellar_touched = true
	# Baum: Aunt Em is already in the cellar; Dorothy is too late to join her safely.
	_dlg("Aunt Em", "Dorothy! Down here! — the door won't hold — get into the house!")
	hud.set_prompt("Too late for the cellar — the cyclone is here.")
	_enter_storm_run()

func _enter_storm_run() -> void:
	phase = Phase.STORM_RUN
	_storm_time = 0.0
	_spawn_cd = 0.3
	_safe_pos = player.global_position
	if _marker:
		_marker.queue_free()
		_marker = null
	if house_door:
		house_door.visible = true
		_retarget_marker(house_door.global_position + Vector3(0, 1.5, 0))
	if cyclone:
		cyclone.visible = true
	if world_env and world_env.environment:
		world_env.environment.adjustment_brightness = 0.68
		world_env.environment.fog_density = 0.028
	hud.set_objective("FINAL STEP: Cyclone! Get Toto into the farmhouse — glowing door (E). Debris cannot stop you.")
	_dlg("Uncle Henry", "The stock! — Dorothy, the house!")

func _enter_house() -> void:
	if phase != Phase.STORM_RUN:
		return
	phase = Phase.HOUSE_LIFT
	_lift_t = 0.0
	hud.set_prompt("")
	hud.set_objective("The cyclone takes the house — hold on!")
	_dlg("Narrator", "Dorothy and Toto are inside. The house rises with the storm.")
	if player and player.has_method("lock_input"):
		player.lock_input()
	# Snap player onto porch / into house volume
	if farmhouse:
		player.global_position = farmhouse.global_position + Vector3(0, 0.9, 2.2)

func _retarget_marker(at: Vector3) -> void:
	if _marker == null:
		_marker = WorldKit.build_prairie_lantern_marker()
		add_child(_marker)
	_marker.global_position = Vector3(at.x, 0.02, at.z)

func _spawn_debris(final_piece: bool) -> void:
	var d: Area3D = DEBRIS_SCENE.instantiate()
	add_child(d)
	var angle := randf() * TAU
	var radius := 20.0 if not final_piece else 24.0
	var from := player.global_position + Vector3(cos(angle) * radius, 1.2 if not final_piece else 2.4, sin(angle) * radius)
	var toward := player.global_position + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
	if d.has_method("launch"):
		d.launch(from, toward, final_piece)
	d.soft_hit_player.connect(_on_soft_debris)
	# final_hit unused as primary end-gate; house door is the book-true finish
	if d.has_signal("final_hit_player"):
		d.final_hit_player.connect(func(): pass)
	if final_piece:
		d.speed = 11.0
		d.scale = Vector3(2.4, 2.4, 2.4)

func _on_soft_debris() -> void:
	if phase != Phase.STORM_RUN:
		return
	# Physical knockdown recoil + dust impact so Dorothy must dodge storm debris!
	if player:
		player.velocity = Vector3(randf_range(-6.0, 6.0), 3.2, 6.5)
		var vis := player.get_node_or_null("Visual") as Node3D
		if vis:
			var tw := create_tween()
			tw.tween_property(vis, "rotation_degrees:x", -68.0, 0.16).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.32)
			tw.tween_property(vis, "rotation_degrees:x", 0.0, 0.28).set_ease(Tween.EASE_IN_OUT)
		CombatFx.label(player, player.global_position, "KNOCKED DOWN!", Color(0.95, 0.95, 1.0))
	if player.global_position.distance_to(_safe_pos) > 16.0:
		player.global_position = _safe_pos + Vector3(0, 0.1, 0)
	hud.set_prompt("Knocked down by storm debris! Dodge it and run for the farmhouse door!")
	get_tree().create_timer(1.2).timeout.connect(func():
		if phase == Phase.STORM_RUN and not _near_door:
			hud.set_prompt("Run to the glowing farmhouse door — E to enter")
	)

## Debug / sim hooks (kansas_sim)
func _close_shutter_debug() -> void:
	_close_shutter()

func _touch_cellar_debug() -> void:
	_touch_cellar()

## --- Enterable buildings (E teleport; walls stay solid) ---
func _make_enterable_box(host: Node3D, title: String, interior: Vector3, exterior: Vector3, _half_size: Vector3) -> void:
	if host == null:
		return
	var door := Area3D.new()
	door.name = "BuildDoor_%s" % title.replace(" ", "")
	door.collision_layer = 0
	door.collision_mask = 2
	door.monitoring = true
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	# Tight radius so porch NPCs are not inside the enter volume.
	sph.radius = 1.15
	col.shape = sph
	door.add_child(col)
	# Invisible trigger seated cleanly in front of the building's built-in architectural door (NO detached box slab!)
	add_child(door)
	door.global_position = exterior
	door.set_meta("title", title)
	door.set_meta("interior_pos", interior)
	door.set_meta("exterior_pos", exterior)
	door.set_meta("host", host)
	var fit := Node3D.new()
	fit.name = "InteriorFitout"
	fit.visible = false
	host.add_child(fit)
	_add_kansas_interior(fit, title)
	door.set_meta("fitout", fit)
	door.body_entered.connect(func(b):
		if b.is_in_group("player") and not _inside_building:
			_near_build_door = door
	)
	door.body_exited.connect(func(b):
		if b.is_in_group("player") and _near_build_door == door and not _inside_building:
			_near_build_door = null
	)

func _build_chicken_coop_and_chickens(at: Vector3) -> void:
	## Distinct pitched-roof Kansas timber Chicken Coop + see-through wire fence + 5 sculpted 3D chickens!
	var body := StaticBody3D.new()
	body.name = "ChickenCoop"
	add_child(body)
	body.global_position = at
	WorldKit.build_chicken_coop(body)
	var c := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(3.4, 2.2, 2.6)
	c.shape = sh
	c.position = Vector3(0, 1.1, 0)
	body.add_child(c)
	_make_enterable_box(body, "Chicken coop", at + Vector3(0, 0.12, 0), at + Vector3(0, 0.12, 2.1), Vector3(3.4, 2.2, 2.6))

func _make_enterable_simple(at: Vector3, title: String, size: Vector3, col: Color) -> void:
	var body := StaticBody3D.new()
	body.name = title.replace(" ", "")
	add_child(body)
	body.global_position = at
	var mi := MeshInstance3D.new()
	mi.name = "Shell"
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _grey_mat(col)
	mi.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(mi)
	var c := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	c.shape = sh
	c.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(c)
	WorldKit.make_world_badge(body, Vector3(0, size.y + 0.65, 0), "✦  %s" % title, Color(0.92, 0.92, 0.96), 10.0)
	_make_enterable_box(body, title, at + Vector3(0, 0.12, 0), at + Vector3(0, 0.12, size.z * 0.5 + 1.6), size)

func _add_kansas_interior(fit: Node3D, title: String) -> void:
	WorldKit.build_kansas_interior(fit, title)

func _set_indoor_camera(inside: bool) -> void:
	if player == null:
		return
	var pivot := player.find_child("CameraPivot", true, false) as Node3D
	if pivot == null:
		return
	var arm := pivot.find_child("SpringArm3D", true, false) as SpringArm3D
	var cam := pivot.find_child("Camera3D", true, false) as Camera3D
	if arm == null or cam == null:
		return
	if inside:
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

func _ks_prop(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _grey_mat(col)
	mi.position = pos
	parent.add_child(mi)

func _try_build_door() -> bool:
	if _door_busy:
		return false
	if _inside_building and _active_build_door:
		_exit_building()
		return true
	if _near_build_door != null:
		_enter_building(_near_build_door)
		return true
	return false

func _set_host_collisions(host: Node, enabled: bool) -> void:
	if host == null:
		return
	var fit := host.get_node_or_null("InteriorFitout")
	for c in host.find_children("*", "CollisionShape3D", true, false):
		if fit and (c == fit or fit.is_ancestor_of(c)):
			continue
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = not enabled
	if fit:
		WorldKit.set_interior_colliders_enabled(fit, not enabled)

func _enter_building(door: Area3D) -> void:
	if door == null or player == null:
		return
	_door_busy = true
	_inside_building = true
	_active_build_door = door
	_near_build_door = door
	var host = door.get_meta("host") if door.has_meta("host") else null
	# Disable exterior solid box collider while inside so Dorothy can walk freely and never gets stuck!
	_set_host_collisions(host, false)
	var ip: Vector3 = door.get_meta("interior_pos")
	player.global_position = ip + Vector3(0, 0.08, 0.45)
	player.velocity = Vector3.ZERO
	var fit = door.get_meta("fitout") if door.has_meta("fitout") else null
	if fit:
		fit.visible = true
	if host:
		for n in host.find_children("*", "MeshInstance3D", true, false):
			if fit and (n == fit or fit.is_ancestor_of(n)):
				continue
			if n is MeshInstance3D:
				(n as MeshInstance3D).visible = false
	_set_indoor_camera(true)
	hud.set_prompt("E  —  Exit %s" % str(door.get_meta("title")))
	_dlg("Narrator", "Inside the %s. Press E to step back outside." % str(door.get_meta("title")))
	get_tree().create_timer(0.25).timeout.connect(func(): _door_busy = false)

func _exit_building() -> void:
	if _active_build_door == null or player == null:
		_inside_building = false
		_door_busy = false
		return
	_door_busy = true
	var door := _active_build_door
	var ep: Vector3 = door.get_meta("exterior_pos")
	player.global_position = ep + Vector3(0, 0.08, 0.5)
	player.velocity = Vector3.ZERO
	_set_indoor_camera(false)
	var fit = door.get_meta("fitout") if door.has_meta("fitout") else null
	if fit:
		fit.visible = false
	var host = door.get_meta("host") if door.has_meta("host") else null
	_set_host_collisions(host, true)
	if host:
		for n in host.find_children("*", "MeshInstance3D", true, false):
			if n is MeshInstance3D:
				(n as MeshInstance3D).visible = true
		var old_roof := host.get_node_or_null("Roof") as Node3D
		if old_roof and host == farmhouse:
			old_roof.visible = false
		if fit:
			fit.visible = false
	_inside_building = false
	_active_build_door = null
	_near_build_door = null
	hud.set_prompt("")
	get_tree().create_timer(0.25).timeout.connect(func(): _door_busy = false)

func force_house_enter() -> void:
	if phase < Phase.STORM_RUN:
		_enter_storm_run()
	_enter_house()
