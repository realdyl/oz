extends Node3D

## Kansas Act 0 — B&W Gale farm (Baum). Basket → Toto → Aunt Em → shutter → cellar
## (too late) → FINAL STEP: house door E → cyclone lifts house → hourglass → Munchkinland.
## No film-only Marvel/Gulch/rainbow. Cannot fail. F9 skip · F8 force storm-to-door.

const MUNCHKIN_SCENE := "res://regions/munchkinland/landing_square.tscn"
const DEBRIS_SCENE := preload("res://regions/kansas/debris.tscn")

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
var _marker: MeshInstance3D
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
var _near_door: bool = false
var _aunt_line: int = 0
var wind_t: float = 0.0
var _house_base_y: float = 0.0
var _near_build_door: Area3D = null
var _inside_building: bool = false
var _door_busy: bool = false
var _active_build_door: Area3D = null
var whimsy_score: int = 0

# Spoken AFTER Toto is already in the basket — never "go get Toto" again.
const AUNT_LINES := [
	"There you are — and Toto's safe in the basket. Good girl.",
	"Henry's gone to look after the stock. Latch that shutter before the wind takes it.",
	"When the shutter's done, check the cellar. I'll be waiting below.",
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
	_add_barn(Vector3(-22.0, 0.0, 26.0))
	_add_fence_ring(Vector3(-22.0, 0.0, 26.0), 8.0, 14)
	_add_fence_ring(Vector3(24.0, 0.0, -20.0), 6.0, 12)
	# Shutter / cellar / door relative to Farmhouse node at (-2,0,-8)
	var hx := -2.0
	var hz := -8.0
	_add_house_shutter(Vector3(hx + 3.6, 0.0, hz + 0.5))
	_add_cellar_door(Vector3(hx - 4.2, 0.0, hz + 1.5))
	_add_house_door(Vector3(hx, 0.0, hz + 3.6))
	_add_aunt_em(Vector3(hx + 1.2, 0.0, hz + 4.2))
	_add_uncle_henry(Vector3(-16.0, 0.0, 18.0))
	_add_clothesline(Vector3(8.0, 0.0, 4.0))
	_add_windmill_ghost(Vector3(-32.0, 0.0, -10.0))
	_add_cyclone_funnel(Vector3(12.0, 0.0, -36.0))
	# Enterable Kansas buildings (E door enter/exit like Munchkinland).
	_make_enterable_box(farmhouse, "Farmhouse", Vector3(hx, 0.12, hz + 0.2), Vector3(hx, 0.12, hz + 5.5), Vector3(5.5, 3.6, 4.2))
	_make_enterable_box(barn, "Barn", Vector3(-22.0, 0.12, 26.0), Vector3(-22.0, 0.12, 30.5), Vector3(5.5, 3.8, 4.5))
	_make_enterable_simple(Vector3(24.0, 0.0, -20.0), "Chicken coop", Vector3(2.6, 1.4, 2.0), Color(0.4, 0.4, 0.42))
	_add_map_border(56.0, 54.0)
	_add_kansas_whimsy()

func _dress_basket() -> void:
	## Ensure basket reads as a basket even if scene mesh is small.
	if basket == null:
		return
	basket.scale = Vector3(1.65, 1.65, 1.65)
	var lab := Label3D.new()
	lab.name = "BasketLabel"
	lab.text = "Toto's basket"
	lab.font_size = 48
	lab.modulate = Color(0.92, 0.92, 0.95)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = Vector3(0, 1.05, 0)
	lab.outline_modulate = Color(0, 0, 0, 0.85)
	lab.outline_size = 8
	basket.add_child(lab)
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
	var lab := Label3D.new()
	lab.text = "Barn"
	lab.font_size = 64
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = Vector3(0, 5.4, 0)
	lab.modulate = Color(0.85, 0.85, 0.88)
	barn.add_child(lab)

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
	var lab := Label3D.new()
	lab.text = "Chicken run"
	lab.font_size = 48
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = Vector3(0, 2.2, 0)
	lab.modulate = Color(0.85, 0.85, 0.88)
	coop.add_child(lab)

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

func _add_person(name: String, at: Vector3, dress: Color, hair: Color) -> Node3D:
	var root := Node3D.new()
	root.name = name
	add_child(root)
	root.global_position = at
	# legs
	for side in [-0.12, 0.12]:
		var leg := MeshInstance3D.new()
		var lc := CylinderMesh.new()
		lc.top_radius = 0.07
		lc.bottom_radius = 0.08
		lc.height = 0.55
		leg.mesh = lc
		leg.material_override = _grey_mat(Color(0.28, 0.28, 0.3))
		leg.position = Vector3(side, 0.28, 0)
		root.add_child(leg)
	# skirt / trousers volume
	var skirt := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.22
	sc.bottom_radius = 0.32
	sc.height = 0.7
	skirt.mesh = sc
	skirt.material_override = _grey_mat(dress)
	skirt.position = Vector3(0, 0.85, 0)
	root.add_child(skirt)
	# torso
	var torso := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.16
	tc.bottom_radius = 0.2
	tc.height = 0.45
	torso.mesh = tc
	torso.material_override = _grey_mat(dress.darkened(0.08))
	torso.position = Vector3(0, 1.35, 0)
	root.add_child(torso)
	# arms
	for side2 in [-0.28, 0.28]:
		var arm := MeshInstance3D.new()
		var ac := CylinderMesh.new()
		ac.top_radius = 0.05
		ac.bottom_radius = 0.06
		ac.height = 0.5
		arm.mesh = ac
		arm.material_override = _grey_mat(Color(0.55, 0.55, 0.57))
		arm.position = Vector3(side2, 1.3, 0)
		arm.rotation_degrees.z = -12.0 if side2 < 0 else 12.0
		root.add_child(arm)
	# head
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.16
	hs.height = 0.32
	head.mesh = hs
	head.material_override = _grey_mat(Color(0.72, 0.72, 0.74))
	head.position = Vector3(0, 1.72, 0)
	root.add_child(head)
	# hair / bonnet
	var hair_m := MeshInstance3D.new()
	var hh := SphereMesh.new()
	hh.radius = 0.17
	hh.height = 0.22
	hair_m.mesh = hh
	hair_m.material_override = _grey_mat(hair)
	hair_m.position = Vector3(0, 1.82, 0.02)
	root.add_child(hair_m)
	var lab := Label3D.new()
	lab.text = name.replace("_", " ")
	lab.font_size = 42
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = Vector3(0, 2.25, 0)
	lab.modulate = Color(0.92, 0.92, 0.95)
	lab.outline_size = 6
	lab.outline_modulate = Color(0, 0, 0, 0.8)
	root.add_child(lab)
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
	var lab := Label3D.new()
	lab.text = "Shutter"
	lab.font_size = 40
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = Vector3(0, 2.2, 0)
	lab.modulate = Color(0.9, 0.9, 0.92)
	shutter.add_child(lab)
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
	var lab := Label3D.new()
	lab.text = "Cellar doors"
	lab.font_size = 40
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = Vector3(0, 1.1, 0)
	lab.modulate = Color(0.9, 0.9, 0.92)
	cellar.add_child(lab)
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
	var lab := Label3D.new()
	lab.name = "DoorLabel"
	lab.text = "Farmhouse door"
	lab.font_size = 44
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = Vector3(0, 2.4, 0)
	lab.modulate = Color(0.95, 0.95, 0.98)
	house_door.add_child(lab)
	add_child(house_door)
	house_door.global_position = at
	house_door.body_entered.connect(func(b): if b.is_in_group("player"): _near_door = true)
	house_door.body_exited.connect(func(b): if b.is_in_group("player"): _near_door = false)
	house_door.visible = false # revealed as FINAL STEP

func _add_clothesline(at: Vector3) -> void:
	for i in 5:
		var cloth := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.6, 0.8, 0.05)
		cloth.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.65 + float(i) * 0.02, 0.65, 0.68)
		cloth.material_override = mat
		add_child(cloth)
		cloth.global_position = at + Vector3(float(i) * 0.7, 1.2, 0)
		cloth.set_meta("wind", true)

func _add_windmill_ghost(at: Vector3) -> void:
	var tower := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.7
	cyl.height = 8.0
	tower.mesh = cyl
	tower.material_override = _grey_mat(Color(0.3, 0.3, 0.33))
	add_child(tower)
	tower.global_position = at + Vector3(0, 4.0, 0)
	var blade := MeshInstance3D.new()
	blade.name = "WindBlade"
	var box := BoxMesh.new()
	box.size = Vector3(6.0, 0.15, 0.4)
	blade.mesh = box
	blade.material_override = _grey_mat(Color(0.45, 0.45, 0.48))
	add_child(blade)
	blade.global_position = at + Vector3(0, 7.5, 0)
	blade.set_meta("spin", true)

func _add_cyclone_funnel(at: Vector3) -> void:
	## Distant B&W funnel — grey only (no rainbow; vault B&W + IP).
	cyclone = Node3D.new()
	cyclone.name = "Cyclone"
	add_child(cyclone)
	cyclone.global_position = at
	cyclone.visible = false
	var funnel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.2
	cyl.bottom_radius = 6.0
	cyl.height = 22.0
	funnel.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.38, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.4, 0.42)
	mat.emission_energy_multiplier = 0.35
	funnel.material_override = mat
	funnel.position = Vector3(0, 11.0, 0)
	cyclone.add_child(funnel)
	funnel.set_meta("spin", true)

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
	_marker.global_position = basket.global_position + Vector3(0, 1.5, 0)

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
			_spawn_cd = maxf(0.5, 1.0 - _storm_time * 0.025)
			_spawn_debris(false)
		if world_env and world_env.environment:
			world_env.environment.adjustment_brightness = 0.7 - minf(_storm_time, 12.0) * 0.015
		# Soft nudge: after long storm, still need door — flash door label
		if _storm_time > 20.0 and house_door:
			var dl := house_door.get_node_or_null("DoorLabel") as Label3D
			if dl:
				dl.modulate = Color(1, 1, 1, 0.6 + 0.4 * sin(_storm_time * 4.0))
		# Henry runs toward barn during storm
		if uncle_henry and _storm_time < 8.0:
			var dest := Vector3(-14.0, 0.0, 18.0)
			uncle_henry.global_position = uncle_henry.global_position.lerp(dest, 1.0 - exp(-1.2 * delta))

	if phase == Phase.HOUSE_LIFT:
		_lift_t += delta
		var rise := ease(_lift_t / 3.2, 1.6) * 14.0
		if farmhouse:
			farmhouse.global_position.y = _house_base_y + rise
			farmhouse.rotation_degrees.y = sin(_lift_t * 1.4) * 8.0
			farmhouse.rotation_degrees.z = cos(_lift_t * 1.1) * 4.0
		if player:
			player.global_position.y = 0.9 + rise * 0.92
		if cyclone:
			cyclone.global_position = farmhouse.global_position + Vector3(2.0, 0, -6.0) if farmhouse else cyclone.global_position
		if world_env and world_env.environment:
			world_env.environment.adjustment_brightness = 0.55 + _lift_t * 0.08
		if _lift_t >= 3.2:
			phase = Phase.FADE
			_fade_t = 0.0
			hud.set_objective("")
			_dlg("Narrator", "The house is carried over the prairie…")

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
	# Building enter/exit (any calm phase; storm final door still wins when near it).
	if _inside_building or _near_build_door != null:
		if phase != Phase.STORM_RUN or not _near_door:
			if _try_build_door():
				return
	match phase:
		Phase.NEED_AUNT:
			if _near_aunt:
				_talk_aunt()
		Phase.NEED_SHUTTER:
			if _near_shutter and not shutter_done:
				_close_shutter()
		Phase.NEED_CELLAR:
			if _near_cellar and not cellar_touched:
				_touch_cellar()
		Phase.STORM_RUN:
			if _near_door:
				_enter_house()
		_:
			var w := get_node_or_null("/root/Whimsy")
			if w and w.has_method("try_collect") and player:
				w.call("try_collect", player)

func _update_prompts() -> void:
	if _inside_building and _active_build_door:
		hud.set_prompt("E  —  Exit %s" % str(_active_build_door.get_meta("title")))
	elif _near_build_door != null and (phase != Phase.STORM_RUN or not _near_door):
		hud.set_prompt("E  —  Enter %s" % str(_near_build_door.get_meta("title")))
	elif phase == Phase.NEED_AUNT and _near_aunt:
		hud.set_prompt("E  —  Talk to Aunt Em")
	elif phase == Phase.NEED_SHUTTER and _near_shutter:
		hud.set_prompt("E  —  Latch the farmhouse shutter")
	elif phase == Phase.NEED_CELLAR and _near_cellar:
		hud.set_prompt("E  —  Check the cellar (Aunt Em is below)")
	elif phase == Phase.STORM_RUN and _near_door:
		hud.set_prompt("E  —  FINAL STEP: Get into the house with Toto!")
	elif phase == Phase.STORM_RUN:
		hud.set_prompt("Run to the glowing farmhouse door — E to enter")
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
		{"pos": Vector3(16, 0, -6), "kind": "chime", "name": "Fence chime"},
		{"pos": Vector3(-8, 0, 28), "kind": "dance", "name": "Barn dance ring"},
		{"pos": Vector3(18, 0, 30), "kind": "giggle", "name": "Yard giggle"},
	], "kansas")

func _wind_props(delta: float) -> void:
	wind_t += delta
	var spin_mul := 1.2
	if phase == Phase.STORM_RUN or phase == Phase.HOUSE_LIFT:
		spin_mul = 4.5
	for n in get_children():
		if n is MeshInstance3D and n.has_meta("wind"):
			(n as MeshInstance3D).rotation.z = sin(wind_t * 2.2 + n.position.x) * (0.15 if phase < Phase.STORM_RUN else 0.55)
		if n is MeshInstance3D and n.has_meta("spin"):
			(n as MeshInstance3D).rotate_z(delta * spin_mul)
	if cyclone:
		for c in cyclone.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).rotate_y(delta * spin_mul * 0.8)

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
	_retarget_marker(toto.global_position + Vector3(0, 1.2, 0))
	_dlg("Dorothy", "There — Toto's basket. Now where's that dog?")

func _on_toto_joined() -> void:
	phase = Phase.NEED_AUNT
	hud.set_objective("Aunt Em is on the farmhouse porch — go hear her (E).")
	_safe_pos = player.global_position
	if aunt_em:
		_retarget_marker(aunt_em.global_position + Vector3(0, 2.0, 0))
	_dlg("Toto", "*yip*")

func _talk_aunt() -> void:
	if _aunt_line >= AUNT_LINES.size():
		aunt_talked = true
		phase = Phase.NEED_SHUTTER
		hud.set_objective("Latch the glowing shutter on the farmhouse wall (E).")
		if shutter:
			_retarget_marker(shutter.global_position + Vector3(0, 1.4, 0))
		return
	_dlg("Aunt Em", AUNT_LINES[_aunt_line])
	_aunt_line += 1
	if _aunt_line >= AUNT_LINES.size():
		aunt_talked = true
		phase = Phase.NEED_SHUTTER
		hud.set_objective("Latch the glowing shutter on the farmhouse wall (E).")
		if shutter:
			_retarget_marker(shutter.global_position + Vector3(0, 1.4, 0))
		hud.set_prompt("Shutter — east wall of the house")

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
		_marker = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.1
		cyl.height = 2.0
		_marker.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.8, 0.85)
		mat.emission_enabled = true
		mat.emission = Color(1, 1, 1)
		mat.emission_energy_multiplier = 1.2
		_marker.material_override = mat
		add_child(_marker)
	_marker.global_position = at

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
	if player.global_position.distance_to(_safe_pos) > 16.0:
		player.global_position = _safe_pos + Vector3(0, 0.1, 0)
	hud.set_prompt("Debris! You cannot fail — keep for the house door.")
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
	sph.radius = 1.7
	col.shape = sph
	door.add_child(col)
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
	var lab := Label3D.new()
	lab.text = title
	lab.font_size = 40
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = Vector3(0, size.y + 0.6, 0)
	lab.modulate = Color(0.9, 0.9, 0.92)
	body.add_child(lab)
	_make_enterable_box(body, title, at + Vector3(0, 0.12, 0), at + Vector3(0, 0.12, size.z * 0.5 + 1.6), size)

func _add_kansas_interior(fit: Node3D, title: String) -> void:
	var floor := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(4.5, 0.08, 4.0)
	floor.mesh = fb
	floor.material_override = _grey_mat(Color(0.35, 0.35, 0.38))
	floor.position = Vector3(0, 0.04, 0)
	fit.add_child(floor)
	var t := title.to_lower()
	if "farm" in t:
		_ks_prop(fit, Vector3(0, 0.45, -0.8), Vector3(1.4, 0.7, 0.7), Color(0.28, 0.28, 0.3))
		_ks_prop(fit, Vector3(1.4, 0.5, 0.6), Vector3(0.7, 1.0, 0.5), Color(0.22, 0.22, 0.24))
		_ks_prop(fit, Vector3(-1.3, 0.35, 0.5), Vector3(0.6, 0.7, 0.6), Color(0.32, 0.32, 0.34))
		var pl := Label3D.new()
		pl.text = "Gale kitchen"
		pl.font_size = 36
		pl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pl.position = Vector3(0, 2.0, 0)
		fit.add_child(pl)
	elif "barn" in t:
		_ks_prop(fit, Vector3(-1.2, 0.6, 0), Vector3(0.8, 1.2, 2.5), Color(0.3, 0.3, 0.32))
		_ks_prop(fit, Vector3(1.2, 0.4, -0.5), Vector3(1.0, 0.8, 1.0), Color(0.4, 0.38, 0.3))
		var pl2 := Label3D.new()
		pl2.text = "Hay loft"
		pl2.font_size = 36
		pl2.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pl2.position = Vector3(0, 2.0, 0)
		fit.add_child(pl2)
	else:
		_ks_prop(fit, Vector3(0, 0.25, 0), Vector3(0.8, 0.5, 0.8), Color(0.45, 0.45, 0.4))
		var pl3 := Label3D.new()
		pl3.text = "Coop"
		pl3.font_size = 32
		pl3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pl3.position = Vector3(0, 1.4, 0)
		fit.add_child(pl3)

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

func _enter_building(door: Area3D) -> void:
	if door == null or player == null:
		return
	_door_busy = true
	_inside_building = true
	_active_build_door = door
	_near_build_door = door
	var ip: Vector3 = door.get_meta("interior_pos")
	player.global_position = ip + Vector3(0, 0.05, 0)
	var fit = door.get_meta("fitout") if door.has_meta("fitout") else null
	if fit:
		fit.visible = true
	var host = door.get_meta("host") if door.has_meta("host") else null
	if host:
		for n in host.find_children("*", "MeshInstance3D", true, false):
			if fit and (n == fit or fit.is_ancestor_of(n)):
				continue
			if n is MeshInstance3D:
				(n as MeshInstance3D).visible = false
	hud.set_prompt("E  —  Exit %s" % str(door.get_meta("title")))
	_dlg("Narrator", "Inside the %s." % str(door.get_meta("title")))
	get_tree().create_timer(0.25).timeout.connect(func(): _door_busy = false)

func _exit_building() -> void:
	if _active_build_door == null or player == null:
		_inside_building = false
		_door_busy = false
		return
	_door_busy = true
	var door := _active_build_door
	var ep: Vector3 = door.get_meta("exterior_pos")
	player.global_position = ep + Vector3(0, 0.05, 0.4)
	var fit = door.get_meta("fitout") if door.has_meta("fitout") else null
	if fit:
		fit.visible = false
	var host = door.get_meta("host") if door.has_meta("host") else null
	if host:
		for n in host.find_children("*", "MeshInstance3D", true, false):
			if n is MeshInstance3D:
				(n as MeshInstance3D).visible = true
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
