extends Node3D

## Act 1 landing — vault-compressed road joins + combat lessons (Enemy Roster).
## Dorothy → Shoes → clear landing swarm → free Scarecrow → crow field → calm Lion
## → tree gate (Tin axe) → oil Tin Man → Marshal rogue → open road.

const SCARECROW_SCENE := preload("res://actors/companions/scarecrow.tscn")
const LION_SCENE := preload("res://actors/companions/lion.tscn")
const TINMAN_SCENE := preload("res://actors/companions/tinman.tscn")
const PUPPET_SCENE := preload("res://actors/enemies/puppet_munchkin.tscn")
const TREE_SCRIPT := preload("res://actors/enemies/living_tree.gd")
const WEST_SCENE := "res://regions/winkie/west_castle.tscn"
const EMERALD_SCENE := "res://regions/emerald_city/wizard_tower.tscn"

enum Beat {
	MEET_LOCASTA,
	SHOES,
	CLEAR_LANDING,
	FREE_SCARECROW,
	CROW_FIELD,
	FREE_LION,
	LION_PACK,
	FREE_TIN,
	TREE_GATE,
	MARSHAL,
	OPEN_ROAD,
}

## Match MapBorder half extents with a soft inward margin (expanded YBR spine).
const PLAY_BOUND_X := 72.0
const PLAY_BOUND_Z := 140.0

## Yellow Brick Road story spine (south = +Z toward West castle).
## House stays at baked ~z=-5; Dorothy starts far north and walks the road south.
const YBR_SPAWN := Vector3(0.0, 0.08, -52.0)
const YBR_LOCASTA := Vector3(0.0, 0.08, -28.0) # before the grey house, clear of wreckage
const YBR_SCARECROW := Vector3(0.0, 0.08, 28.0)
const YBR_LION := Vector3(0.0, 0.08, 62.0)
const YBR_TIN := Vector3(0.0, 0.08, 95.0)
const YBR_TREE := Vector3(0.0, 0.0, 110.0)
const YBR_WEST_GATE := Vector3(0.0, 0.08, 128.0)

@onready var hud: CanvasLayer = $PlayHUD
@onready var shoes: Node3D = $SilverShoes
@onready var player: CharacterBody3D = $Player

var scarecrow: CharacterBody3D
var lion: CharacterBody3D
var tinman: CharacterBody3D
var pole: MeshInstance3D
var oil_can: Area3D
var has_oil: bool = false
var shoes_done: bool = false
var beat: Beat = Beat.MEET_LOCASTA
var landing_kills: int = 0
var crow_kills: int = 0
var lion_pack_kills: int = 0
var tree_down: bool = false
var marshal_down: bool = false
var landing_need: int = 3
var crow_need: int = 4
var lion_pack_need: int = 4
var living_tree: StaticBody3D
var marshal: CharacterBody3D

var _near_oil: bool = false
var _near_scarecrow: bool = false
var _near_lion: bool = false
var _near_tin: bool = false
var _near_door: Area3D = null
var _inside_building: bool = false
var _door_busy: bool = false
var _active_interior: Area3D = null
var _outside_return: Vector3 = Vector3.ZERO
var _cam_out_len: float = 4.8
var _cam_out_fov: float = 58.0
var _cam_out_pitch: float = -18.0
var compass: Label
var _sign_sway: Array = []  # MeshInstance3D boards that gently sway
var _open_road_sting_done: bool = false
var _west_road_gate: Node3D = null
var _west_gate_pos: Vector3 = YBR_WEST_GATE
var _near_west_gate: bool = false
var locasta: Node3D
var locasta_done: bool = false
var _near_locasta: bool = false
var _locasta_line: int = 0
var whimsy_points: int = 0
var _whimsy_label: Label
var _near_whimsy: Area3D = null
var _locasta_lines: PackedStringArray = PackedStringArray([
	"Locasta: \"Welcome to Munchkinland, child. The house has done what armies could not — the Wicked Witch of the East is gone.\"",
	"Locasta: \"Her Silver Shoes are yours now. Claim them under the grey house ahead on this road — they chose the one who landed.\"",
	"Locasta: \"Then follow the Yellow Brick Road. First you will find a Scarecrow bound to a pole. Free him with kindness (E).\"",
	"Locasta: \"Further along the same road: a Lion hides in fear, then a Tin Man rusts. Calm and oil them when you reach them.\"",
	"Locasta: \"Rogue Munchkins will march near the landing. Kick them (F). Each friend teaches a counter. I keep the North — walk the road.\"",
	"Locasta: \"When your friends stand with you, keep following the Yellow Brick Road south to the West. The glowing pad is your FINAL STEP.\"",
	"Locasta: \"The Wicked Witch of the West watches later. For now: Shoes, clear the rogues, free the bound. Follow the brick.\"",
])

func _enter_tree() -> void:
	var p := get_node_or_null("/root/Party")
	if p and p.has_method("reset_party"):
		p.reset_party()

func _ready() -> void:
	if hud.has_method("set_kansas_mode"):
		hud.set_kansas_mode(false)
	shoes.claimed.connect(_on_shoes_claimed)
	shoes.prompt_changed.connect(hud.set_prompt)
	_fix_world_text()
	_expand_world()
	_open_baked_cottages()
	_spawn_party_world()
	_tag_baked_landing_puppets()
	_spawn_landing_puppets()
	if Party:
		Party.leader_changed.connect(_on_leader_changed)
		Party.swap_failed.connect(_on_swap_failed)
		Party.unlock_changed.connect(func(_id, _u): _refresh_roster())
	_ensure_compass()
	_set_beat(Beat.MEET_LOCASTA)
	_refresh_roster()
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("on_level_start"):
		lt.on_level_start("Munchkinland · the landing")

func _fix_world_text() -> void:
	# Label3D with 180 yaw / negative basis reads mirrored from the approach path.
	# Billboard so every sign is legible from any camera angle.
	for n in find_children("*", "Label3D", true, false):
		var lab := n as Label3D
		if lab == null:
			continue
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.double_sided = false
		lab.shaded = false
		lab.fixed_size = false
		lab.rotation = Vector3.ZERO
		lab.scale = Vector3.ONE
		if lab.text.strip_edges().to_upper() == "DEBTS":
			lab.text = "DEBTS"
			lab.modulate = Color(0.95, 0.88, 0.75, 1)
			lab.outline_modulate = Color(0.25, 0.08, 0.14, 1)

func _expand_world() -> void:
	# Vast YBR corridor — pads only (never scale primary Ground).
	_add_ground_pad(Vector3(0, -0.05, 0), Vector3(140, 0.1, 160), Color(0.4, 0.6, 0.32))
	_add_ground_pad(Vector3(0, -0.05, -80), Vector3(120, 0.1, 90), Color(0.42, 0.62, 0.34))
	_add_ground_pad(Vector3(0, -0.05, 70), Vector3(120, 0.1, 100), Color(0.4, 0.58, 0.3))
	_add_ground_pad(Vector3(0, -0.05, 130), Vector3(100, 0.1, 60), Color(0.38, 0.56, 0.28))
	_add_ground_pad(Vector3(-40, -0.05, 40), Vector3(50, 0.1, 120), Color(0.38, 0.58, 0.3))
	_add_ground_pad(Vector3(40, -0.05, 40), Vector3(50, 0.1, 120), Color(0.38, 0.58, 0.3))
	# Bound walls pushed far out so they don't seal the spine.
	for wname in ["WallWest", "WallEast", "WallSouth", "ContentGate"]:
		var w := get_node_or_null(wname) as Node3D
		if w == null:
			continue
		match wname:
			"WallWest":
				w.global_position = Vector3(-78.0, 1.2, 30.0)
			"WallEast":
				w.global_position = Vector3(78.0, 1.2, 30.0)
			"WallSouth":
				w.global_position = Vector3(0.0, 1.2, 145.0)
			"ContentGate":
				w.global_position = Vector3(0.0, 1.2, -70.0)
	# Continuous Yellow Brick Road spine (north spawn → Locasta → house → companions → West).
	# Center positions are midpoints of long N–S strips on x=0.
	_add_road_spur(Vector3(0, 0.02, -40), Vector3(5.4, 0.06, 50)) # spawn → Locasta → house approach
	_add_road_spur(Vector3(0, 0.02, 10), Vector3(5.4, 0.06, 70)) # house → Scarecrow stretch
	_add_road_spur(Vector3(0, 0.02, 70), Vector3(5.5, 0.06, 70)) # Lion stretch
	_add_road_spur(Vector3(0, 0.02, 115), Vector3(5.6, 0.07, 50)) # Tin → West gate
	# Soft side spurs for cottages / whimsy only — not the companion path.
	_add_road_spur(Vector3(14, 0.02, 20), Vector3(22, 0.04, 3.2))
	_add_road_spur(Vector3(-14, 0.02, 45), Vector3(22, 0.04, 3.2))
	# Buildings off the brick — walk the road, duck into homes if you want.
	_add_enterable_cottage(Vector3(22, 0, 18), Color(0.92, 0.55, 0.65), "Candy Home")
	_add_enterable_cottage(Vector3(-20, 0, 48), Color(0.55, 0.7, 0.92), "Mint Home")
	_add_enterable_cottage(Vector3(18, 0, 88), Color(0.95, 0.75, 0.45), "Butter Home")
	_scatter_grass(Vector3(0, 0, 0), 50.0, 120)
	_scatter_grass(Vector3(0, 0, 60), 40.0, 100)
	_scatter_grass(Vector3(0, 0, -40), 30.0, 80)
	# Soft story border — thicket + solid rails.
	_add_map_border(85.0, 150.0)
	_add_whimsy_activities()
	_ensure_whimsy_hud()
	# Dorothy starts far up the YBR so Locasta and the house are a real walk south.
	if player:
		player.global_position = YBR_SPAWN
		player.velocity = Vector3.ZERO

func _add_map_border(half_x: float, half_z: float) -> void:
	# Continuous solid rails + shrub/tree dressing. Corners closed so pads can't leak.
	var h := 3.2
	var thick := 2.4
	var col := Color(0.18, 0.32, 0.16)
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
		body.collision_mask = 0
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
	# Tree/shrub ring just inside the rail for readable “end of the land.”
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for i in 56:
		var t := float(i) / 56.0 * TAU
		var r := minf(half_x, half_z) - 1.2 + rng.randf_range(-0.6, 0.8)
		var p := Vector3(cos(t) * (half_x - 1.4 + rng.randf_range(-0.5, 0.5)), 0.0, sin(t) * (half_z - 1.4 + rng.randf_range(-0.5, 0.5)))
		_add_border_tree(p, rng)

func _add_border_tree(at: Vector3, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = at
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	var th := rng.randf_range(1.6, 2.8)
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.18
	cyl.height = th
	trunk.mesh = cyl
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.28, 0.18, 0.1)
	trunk.material_override = tm
	root.add_child(trunk)
	trunk.position = Vector3(0, th * 0.5, 0)
	var canopy := MeshInstance3D.new()
	var sph := SphereMesh.new()
	var cr := rng.randf_range(0.9, 1.6)
	sph.radius = cr
	sph.height = cr * 1.6
	canopy.mesh = sph
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.22, 0.48, 0.26).lerp(Color(0.35, 0.55, 0.2), rng.randf())
	cm.roughness = 0.9
	canopy.material_override = cm
	root.add_child(canopy)
	canopy.position = Vector3(0, th + cr * 0.35, 0)
	# Low shrub collision bump so bodies don't clip the trunk line.
	var bump := StaticBody3D.new()
	root.add_child(bump)
	var bc := CollisionShape3D.new()
	var bsh := BoxShape3D.new()
	bsh.size = Vector3(1.1, 1.4, 1.1)
	bc.shape = bsh
	bc.position = Vector3(0, 0.7, 0)
	bump.add_child(bc)

func _add_ground_pad(at: Vector3, size: Vector3, col: Color = Color(0.45, 0.62, 0.35)) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.global_position = at
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.95
	mi.material_override = mat
	body.add_child(mi)
	var c := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	c.shape = sh
	body.add_child(c)

func _add_block_terrace(at: Vector3, size: Vector3, steps: int, approach: Vector3 = Vector3(0, 0, 1)) -> void:
	# Stacked pads + long shallow stair run so any Lead climbs without blink.
	var h := size.y
	for s in range(steps):
		var layer := StaticBody3D.new()
		add_child(layer)
		var layer_size := Vector3(size.x - float(s) * 0.6, h, size.z - float(s) * 0.6)
		layer.global_position = at + Vector3(0, h * 0.5 + float(s) * h, 0)
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = layer_size
		mi.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.34 + float(s) * 0.04, 0.55, 0.28)
		mat.roughness = 0.92
		mi.material_override = mat
		layer.add_child(mi)
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = layer_size
		col.shape = sh
		layer.add_child(col)
	var dir := approach.normalized()
	var top_h := h * float(steps)
	# Many shallow treads (~0.18–0.22 rise) spanning a longer approach.
	var ramp_steps := maxi(10, int(ceil(top_h / 0.2)))
	for i in ramp_steps:
		var t := float(i + 1) / float(ramp_steps)
		var ramp := StaticBody3D.new()
		add_child(ramp)
		var rh := maxf(top_h * t, 0.1)
		var tread := 0.55
		var outward := (size.x if absf(dir.x) > absf(dir.z) else size.z) * 0.5 + 0.25 + float(ramp_steps - i) * tread
		var pos := at + dir * outward + Vector3(0, rh * 0.5, 0)
		ramp.global_position = pos
		var mi2 := MeshInstance3D.new()
		var box2 := BoxMesh.new()
		if absf(dir.x) > absf(dir.z):
			box2.size = Vector3(tread + 0.08, rh, size.z * 0.7)
		else:
			box2.size = Vector3(size.x * 0.7, rh, tread + 0.08)
		mi2.mesh = box2
		var mat2 := StandardMaterial3D.new()
		mat2.albedo_color = Color(0.52, 0.44, 0.3)
		mi2.material_override = mat2
		ramp.add_child(mi2)
		var c2 := CollisionShape3D.new()
		var sh2 := BoxShape3D.new()
		sh2.size = box2.size
		c2.shape = sh2
		ramp.add_child(c2)
	# Low lip at terrace edge.
	var lip := StaticBody3D.new()
	add_child(lip)
	var lip_h := 0.22
	var lip_out := (size.x if absf(dir.x) > absf(dir.z) else size.z) * 0.5 + 0.12
	lip.global_position = at + dir * lip_out + Vector3(0, lip_h * 0.5, 0)
	var lmi := MeshInstance3D.new()
	var lbox := BoxMesh.new()
	if absf(dir.x) > absf(dir.z):
		lbox.size = Vector3(0.4, lip_h, size.z * 0.75)
	else:
		lbox.size = Vector3(size.x * 0.75, lip_h, 0.4)
	lmi.mesh = lbox
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.48, 0.4, 0.28)
	lmi.material_override = lmat
	lip.add_child(lmi)
	var lc := CollisionShape3D.new()
	var lsh := BoxShape3D.new()
	lsh.size = lbox.size
	lc.shape = lsh
	lip.add_child(lc)

func _add_road_spur(at: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.72, 0.2)
	mat.roughness = 0.7
	mi.material_override = mat
	add_child(mi)
	mi.global_position = at + Vector3(0, size.y * 0.5, 0)

func _scatter_grass(center: Vector3, radius: float, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in count:
		var ang := rng.randf() * TAU
		var r := rng.randf() * radius
		var p := center + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var blade := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, rng.randf_range(0.25, 0.55), 0.08)
		blade.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.28 + rng.randf() * 0.2, 0.55 + rng.randf() * 0.25, 0.22)
		mat.roughness = 1.0
		blade.material_override = mat
		add_child(blade)
		blade.global_position = p + Vector3(0, box.size.y * 0.5, 0)
		blade.rotation.y = rng.randf() * TAU

func _add_enterable_cottage(at: Vector3, wall_col: Color, title: String) -> void:
	# Large hollow room — readable third-person interior for any Lead.
	var root := Node3D.new()
	root.name = "Cottage_%s" % title.replace(" ", "")
	add_child(root)
	root.global_position = at
	var half_w := 4.5
	var half_d := 3.6
	var wall_h := 3.6
	var thick := 0.28
	var exterior := Node3D.new()
	exterior.name = "ExteriorShell"
	root.add_child(exterior)
	_add_wall_box(exterior, Vector3(0, wall_h * 0.5, -half_d), Vector3(half_w * 2.0 + thick, wall_h, thick), wall_col)
	_add_wall_box(exterior, Vector3(-half_w, wall_h * 0.5, 0), Vector3(thick, wall_h, half_d * 2.0), wall_col)
	_add_wall_box(exterior, Vector3(half_w, wall_h * 0.5, 0), Vector3(thick, wall_h, half_d * 2.0), wall_col)
	var gap := 1.6
	var wing := (half_w * 2.0 - gap) * 0.5
	_add_wall_box(exterior, Vector3(-(gap * 0.5 + wing * 0.5), wall_h * 0.5, half_d), Vector3(wing, wall_h, thick), wall_col)
	_add_wall_box(exterior, Vector3((gap * 0.5 + wing * 0.5), wall_h * 0.5, half_d), Vector3(wing, wall_h, thick), wall_col)
	_add_wall_box(exterior, Vector3(0, wall_h - 0.35, half_d), Vector3(gap + 0.2, 0.7, thick), wall_col)
	# Closed door seal — walk-in blocked; only E opens (teleport + mute seal).
	var door_seal := _add_door_seal(exterior, Vector3(0, 1.15, half_d), Vector3(gap - 0.05, 2.3, thick + 0.06))
	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	var rbox := BoxMesh.new()
	rbox.size = Vector3(half_w * 2.0 + 1.0, 0.35, half_d * 2.0 + 1.0)
	roof.mesh = rbox
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.5, 0.2, 0.26)
	rm.roughness = 0.9
	roof.material_override = rm
	exterior.add_child(roof)
	roof.position = Vector3(0, wall_h + 0.1, 0)
	# Closed door visual (not ajar gap you can stroll through)
	var door_vis := MeshInstance3D.new()
	door_vis.name = "DoorVis"
	var dbox := BoxMesh.new()
	dbox.size = Vector3(gap - 0.1, 2.2, 0.08)
	door_vis.mesh = dbox
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.32, 0.2, 0.14)
	door_vis.material_override = dm
	exterior.add_child(door_vis)
	door_vis.position = Vector3(0, 1.1, half_d + 0.06)
	_add_building_sign(root, Vector3(0, wall_h + 0.15, half_d + 0.35), title.to_upper(), wall_col)
	var fit := _build_interior_fitout(root, half_w, half_d, wall_h, wall_col.lightened(0.25), title)
	fit.visible = false
	var door_area := Area3D.new()
	door_area.name = "Door"
	door_area.collision_layer = 0
	door_area.collision_mask = 2
	door_area.monitoring = true
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.7
	col.shape = sph
	door_area.add_child(col)
	root.add_child(door_area)
	door_area.position = Vector3(0, 1.0, half_d + 0.4)
	door_area.set_meta("interior_pos", at + Vector3(0, 0.12, 0.4))
	door_area.set_meta("exterior_pos", at + Vector3(0, 0.12, half_d + 2.2))
	door_area.set_meta("title", title)
	door_area.set_meta("building", root)
	door_area.set_meta("door_seal", door_seal)
	var interior_area := Area3D.new()
	interior_area.name = "InteriorZone"
	interior_area.collision_layer = 0
	interior_area.collision_mask = 2
	interior_area.monitoring = true
	var icol := CollisionShape3D.new()
	var ibox := BoxShape3D.new()
	ibox.size = Vector3(half_w * 2.0 - 0.4, wall_h, half_d * 2.0 - 0.4)
	icol.shape = ibox
	interior_area.add_child(icol)
	root.add_child(interior_area)
	interior_area.position = Vector3(0, wall_h * 0.5, 0)
	interior_area.set_meta("door", door_area)
	interior_area.body_entered.connect(func(b): _on_interior_enter(door_area, b))
	interior_area.body_exited.connect(func(b): _on_interior_exit(door_area, b))
	door_area.body_entered.connect(func(b): _on_door_enter(door_area, b))
	door_area.body_exited.connect(func(b): _on_door_exit(door_area, b))

func _build_interior_fitout(parent: Node3D, half_w: float, half_d: float, wall_h: float, wall_col: Color, title: String) -> Node3D:
	var fit := Node3D.new()
	fit.name = "InteriorFitout"
	parent.add_child(fit)
	var floor_mi := MeshInstance3D.new()
	var fbox := BoxMesh.new()
	fbox.size = Vector3(half_w * 2.0 - 0.2, 0.1, half_d * 2.0 - 0.2)
	floor_mi.mesh = fbox
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.55, 0.38, 0.26)
	fm.roughness = 0.85
	floor_mi.material_override = fm
	fit.add_child(floor_mi)
	floor_mi.position = Vector3(0, 0.05, 0)
	var ceil := MeshInstance3D.new()
	var cbox := BoxMesh.new()
	cbox.size = Vector3(half_w * 2.0 - 0.3, 0.08, half_d * 2.0 - 0.3)
	ceil.mesh = cbox
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.92, 0.86, 0.78, 0.92)
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.roughness = 1.0
	ceil.material_override = cm
	fit.add_child(ceil)
	ceil.position = Vector3(0, wall_h - 0.15, 0)
	var inner := wall_col.lerp(Color(0.95, 0.9, 0.82), 0.35)
	_add_decor_box(fit, Vector3(0, wall_h * 0.5, -half_d + 0.08), Vector3(half_w * 2.0 - 0.3, wall_h - 0.2, 0.08), inner)
	_add_decor_box(fit, Vector3(-half_w + 0.08, wall_h * 0.5, 0), Vector3(0.08, wall_h - 0.2, half_d * 2.0 - 0.3), inner)
	_add_decor_box(fit, Vector3(half_w - 0.08, wall_h * 0.5, 0), Vector3(0.08, wall_h - 0.2, half_d * 2.0 - 0.3), inner)
	_add_decor_box(fit, Vector3(-(half_w * 0.55), wall_h * 0.5, half_d - 0.08), Vector3(half_w * 0.7, wall_h - 0.2, 0.08), inner)
	_add_decor_box(fit, Vector3((half_w * 0.55), wall_h * 0.5, half_d - 0.08), Vector3(half_w * 0.7, wall_h - 0.2, 0.08), inner)
	# Story-flavored set dressing by building title (not anonymous junk cubes).
	var tlow := title.to_lower()
	if "mayor" in tlow or "hall" in tlow:
		_add_decor_box(fit, Vector3(0, 0.7, -half_d + 1.0), Vector3(2.4, 1.4, 1.0), Color(0.35, 0.22, 0.12)) # desk
		_add_decor_box(fit, Vector3(0, 1.5, -half_d + 1.0), Vector3(1.6, 0.12, 0.7), Color(0.55, 0.4, 0.2))
		_add_decor_box(fit, Vector3(-1.8, 0.55, 0.8), Vector3(0.7, 1.1, 0.7), Color(0.45, 0.2, 0.15)) # chair
		_add_decor_box(fit, Vector3(1.8, 1.2, -0.4), Vector3(0.9, 1.6, 0.35), Color(0.3, 0.25, 0.2)) # ledger shelf
		_add_named_plaque(fit, Vector3(0, 2.2, -half_d + 0.25), "MAYOR'S LEDGER\n(welcome to Munchkinland)")
	elif "shop" in tlow or "store" in tlow or "market" in tlow:
		_add_decor_box(fit, Vector3(-1.6, 0.7, -0.6), Vector3(2.0, 1.4, 0.6), Color(0.5, 0.35, 0.2)) # counter
		_add_decor_box(fit, Vector3(1.5, 0.9, -1.2), Vector3(1.2, 1.8, 0.5), Color(0.4, 0.28, 0.18)) # shelves
		_add_decor_box(fit, Vector3(1.5, 0.35, 1.0), Vector3(0.8, 0.7, 0.8), Color(0.7, 0.25, 0.3)) # candy crate
		_add_decor_box(fit, Vector3(-1.2, 0.3, 1.3), Vector3(0.6, 0.6, 0.6), Color(0.9, 0.75, 0.2)) # grain sack
		_add_named_plaque(fit, Vector3(0, 2.2, -half_d + 0.25), "MUNCHKIN MARKET\nboots · sweets · oil cans")
	elif "cottage" in tlow or "house" in tlow or "home" in tlow:
		_add_decor_box(fit, Vector3(-1.8, 0.45, -1.0), Vector3(2.0, 0.9, 1.4), Color(0.55, 0.3, 0.25)) # bed
		_add_decor_box(fit, Vector3(-1.8, 0.95, -1.0), Vector3(1.8, 0.25, 1.2), Color(0.85, 0.75, 0.9)) # quilt
		_add_decor_box(fit, Vector3(1.6, 0.55, -0.8), Vector3(1.0, 1.1, 0.8), Color(0.4, 0.25, 0.15)) # hearth
		_add_decor_box(fit, Vector3(1.6, 1.3, -0.8), Vector3(0.35, 0.5, 0.35), Color(0.9, 0.4, 0.15)) # fire
		_add_decor_box(fit, Vector3(0.2, 0.4, 1.2), Vector3(1.0, 0.8, 1.0), Color(0.45, 0.3, 0.2)) # table
		_add_named_plaque(fit, Vector3(0, 2.2, -half_d + 0.25), "COTTAGE\nrest · hearth · kindness")
	else:
		_add_decor_box(fit, Vector3(-1.8, 0.55, -1.0), Vector3(1.8, 1.1, 0.9), Color(0.4, 0.25, 0.16))
		_add_decor_box(fit, Vector3(1.8, 0.7, -0.6), Vector3(1.2, 1.4, 0.55), Color(0.45, 0.3, 0.22))
		_add_decor_box(fit, Vector3(0.0, 0.4, 1.2), Vector3(1.2, 0.8, 1.0), Color(0.5, 0.28, 0.25))
		_add_named_plaque(fit, Vector3(0, 2.2, -half_d + 0.25), title.to_upper())
	# Window light strip
	_add_decor_box(fit, Vector3(0.0, 1.5, -half_d + 0.2), Vector3(1.6, 1.1, 0.06), Color(0.7, 0.85, 0.95))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.92, 0.75)
	lamp.light_energy = 2.6
	lamp.omni_range = 12.0
	lamp.shadow_enabled = false
	fit.add_child(lamp)
	lamp.position = Vector3(0, wall_h - 0.6, 0)
	var lamp2 := OmniLight3D.new()
	lamp2.light_color = Color(1.0, 0.85, 0.65)
	lamp2.light_energy = 1.3
	lamp2.omni_range = 8.0
	lamp2.shadow_enabled = false
	fit.add_child(lamp2)
	lamp2.position = Vector3(-1.5, 1.8, -0.8)
	var plaque := Label3D.new()
	plaque.text = title
	plaque.font_size = 64
	plaque.pixel_size = 0.012
	plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plaque.modulate = Color(0.95, 0.9, 0.8)
	plaque.outline_size = 8
	plaque.outline_modulate = Color(0.15, 0.08, 0.1)
	fit.add_child(plaque)
	plaque.position = Vector3(0, 2.55, 0)
	return fit

func _add_named_plaque(parent: Node3D, pos: Vector3, text: String) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 40
	lab.pixel_size = 0.01
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(0.95, 0.88, 0.7)
	lab.outline_size = 6
	parent.add_child(lab)
	lab.position = pos

func _add_decor_box(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.8
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos

func _add_door_seal(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	# Solid closed door — blocks walk-in until E enter disables it.
	var body := StaticBody3D.new()
	body.name = "DoorSeal"
	parent.add_child(body)
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var c := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	c.shape = sh
	body.add_child(c)
	return body

func _set_door_seal_open(door: Area3D, open: bool) -> void:
	if door == null or not door.has_meta("door_seal"):
		return
	var seal = door.get_meta("door_seal")
	if seal == null or not is_instance_valid(seal):
		return
	for n in seal.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		if cs:
			cs.disabled = open
	# Hide closed door mesh while inside.
	var building = door.get_meta("building") if door.has_meta("building") else null
	if building:
		var exterior = building.get_node_or_null("ExteriorShell")
		if exterior:
			var vis = exterior.get_node_or_null("DoorVis")
			if vis:
				vis.visible = not open

func _add_wall_box(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = pos
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.88
	mi.material_override = mat
	body.add_child(mi)
	var c := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	c.shape = sh
	body.add_child(c)

func _open_baked_cottages() -> void:
	# Solid filled boxes have no interior — hollow into large readable rooms.
	for path in ["PinkCottage", "BlueCottage", "DebtCottage", "GuildHall"]:
		var cottage := get_node_or_null(path) as StaticBody3D
		if cottage == null:
			continue
		var main_col := cottage.get_node_or_null("Collision") as CollisionShape3D
		if main_col:
			main_col.disabled = true
		var walls_col := cottage.get_node_or_null("WallsCol") as CollisionShape3D
		if walls_col:
			walls_col.disabled = true
		var roof_col := cottage.get_node_or_null("RoofCol") as CollisionShape3D
		if roof_col:
			roof_col.disabled = true
		for mesh_name in ["Walls", "Roof", "Door"]:
			var mi := cottage.get_node_or_null(mesh_name) as MeshInstance3D
			if mi:
				mi.visible = false
		var wall_col := Color(0.9, 0.55, 0.65)
		match path:
			"BlueCottage":
				wall_col = Color(0.55, 0.7, 0.9)
				# Far northwest — not next to spawn or Tin pad.
				cottage.global_position = Vector3(-28.0, 0.0, 30.0)
				cottage.rotation = Vector3.ZERO
			"DebtCottage":
				wall_col = Color(0.55, 0.4, 0.35)
				cottage.global_position = Vector3(30.0, 0.0, -28.0)
				cottage.rotation = Vector3.ZERO
			"GuildHall":
				wall_col = Color(0.75, 0.55, 0.7)
				# Far north-west of gate, clear approach plaza.
				cottage.global_position = Vector3(-24.0, 0.0, -30.0)
				cottage.rotation = Vector3.ZERO
			"PinkCottage":
				wall_col = Color(0.9, 0.55, 0.65)
				# Far south-east village edge — nowhere near the cornfield Scarecrow.
				cottage.global_position = Vector3(48.0, 0.0, 40.0)
				cottage.rotation = Vector3.ZERO
		var half_w := 4.2 if path != "GuildHall" else 5.5
		var half_d := 3.4 if path != "GuildHall" else 4.5
		var wall_h := 3.5 if path != "GuildHall" else 4.2
		var exterior := Node3D.new()
		exterior.name = "ExteriorShell"
		cottage.add_child(exterior)
		_add_wall_box(exterior, Vector3(0, wall_h * 0.5, -half_d), Vector3(half_w * 2.0 + 0.3, wall_h, 0.3), wall_col)
		_add_wall_box(exterior, Vector3(-half_w, wall_h * 0.5, 0), Vector3(0.3, wall_h, half_d * 2.0), wall_col)
		_add_wall_box(exterior, Vector3(half_w, wall_h * 0.5, 0), Vector3(0.3, wall_h, half_d * 2.0), wall_col)
		var gap := 1.7
		var wing := (half_w * 2.0 - gap) * 0.5
		_add_wall_box(exterior, Vector3(-(gap * 0.5 + wing * 0.5), wall_h * 0.5, half_d), Vector3(wing, wall_h, 0.3), wall_col)
		_add_wall_box(exterior, Vector3((gap * 0.5 + wing * 0.5), wall_h * 0.5, half_d), Vector3(wing, wall_h, 0.3), wall_col)
		_add_wall_box(exterior, Vector3(0, wall_h - 0.4, half_d), Vector3(gap + 0.2, 0.8, 0.3), wall_col)
		var door_seal := _add_door_seal(exterior, Vector3(0, 1.15, half_d), Vector3(gap - 0.05, 2.3, 0.36))
		var door_vis := MeshInstance3D.new()
		door_vis.name = "DoorVis"
		var dbox := BoxMesh.new()
		dbox.size = Vector3(gap - 0.1, 2.2, 0.1)
		door_vis.mesh = dbox
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.32, 0.2, 0.14)
		door_vis.material_override = dm
		exterior.add_child(door_vis)
		door_vis.position = Vector3(0, 1.1, half_d + 0.08)
		var roof := MeshInstance3D.new()
		roof.name = "Roof"
		var rbox := BoxMesh.new()
		rbox.size = Vector3(half_w * 2.0 + 1.0, 0.35, half_d * 2.0 + 1.0)
		roof.mesh = rbox
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.48, 0.2, 0.24)
		roof.material_override = rm
		exterior.add_child(roof)
		roof.position = Vector3(0, wall_h + 0.1, 0)
		var fit := _build_interior_fitout(cottage, half_w, half_d, wall_h, wall_col.lightened(0.2), path)
		fit.visible = false
		var door_area := Area3D.new()
		door_area.name = "Door"
		door_area.collision_layer = 0
		door_area.collision_mask = 2
		door_area.monitoring = true
		var col := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 1.8
		col.shape = sph
		door_area.add_child(col)
		cottage.add_child(door_area)
		door_area.position = Vector3(0, 1.0, half_d + 0.35)
		door_area.set_meta("interior_pos", cottage.to_global(Vector3(0, 0.12, 0.3)))
		door_area.set_meta("exterior_pos", cottage.to_global(Vector3(0, 0.12, half_d + 2.4)))
		door_area.set_meta("title", path)
		door_area.set_meta("building", cottage)
		door_area.set_meta("door_seal", door_seal)
		var interior_area := Area3D.new()
		interior_area.name = "InteriorZone"
		interior_area.collision_layer = 0
		interior_area.collision_mask = 2
		interior_area.monitoring = true
		var icol := CollisionShape3D.new()
		var ibox := BoxShape3D.new()
		ibox.size = Vector3(half_w * 2.0 - 0.5, wall_h, half_d * 2.0 - 0.5)
		icol.shape = ibox
		interior_area.add_child(icol)
		cottage.add_child(interior_area)
		interior_area.position = Vector3(0, wall_h * 0.5, 0)
		interior_area.set_meta("door", door_area)
		interior_area.body_entered.connect(func(b): _on_interior_enter(door_area, b))
		interior_area.body_exited.connect(func(b): _on_interior_exit(door_area, b))
		door_area.body_entered.connect(func(b): _on_door_enter(door_area, b))
		door_area.body_exited.connect(func(b): _on_door_exit(door_area, b))
		var pretty: String = String(path).replace("Cottage", "").replace("Hall", " HALL").strip_edges().to_upper()
		if pretty == "DEBT":
			pretty = "DEBTS"
		_add_building_sign(cottage, Vector3(0, wall_h + 0.15, half_d + 0.35), pretty, wall_col)

func _is_party_body(body: Node) -> bool:
	return body != null and (body.is_in_group("player") or body.is_in_group("party"))

func _on_door_enter(area: Area3D, body: Node3D) -> void:
	if not _is_party_body(body):
		return
	# Any Lead can open doors — track the door when the current Lead is near it.
	if body == _interact_actor() or (Party and Party.leader_body() == body):
		if not _inside_building:
			_near_door = area

func _on_door_exit(area: Area3D, body: Node3D) -> void:
	if not _is_party_body(body):
		return
	# Never drop the door while inside — interior teleport leaves the frame Area.
	if _inside_building and _active_interior == area:
		return
	if _near_door == area and body == _interact_actor():
		_near_door = null

func _on_interior_enter(door: Area3D, body: Node3D) -> void:
	if not _is_party_body(body):
		return
	# Only meaningful once E has entered — never treat walk-in as being inside.
	if not _inside_building:
		return
	if body == _interact_actor():
		_near_door = door
		_active_interior = door

func _on_interior_exit(door: Area3D, body: Node3D) -> void:
	if body == _interact_actor() and _inside_building and _active_interior == door:
		_near_door = door

func _set_building_walls_solid(_building: Node, _solid: bool) -> void:
	# Walls stay solid always. Only DoorSeal opens for E enter/exit — never soft-walls.
	# (Older builds disabled ExteriorShell while inside, which let you walk out through walls.)
	pass

func _set_interior_view(building: Node, inside: bool) -> void:
	if building == null:
		return
	var exterior := building.get_node_or_null("ExteriorShell")
	if exterior:
		exterior.visible = not inside
	var fit := building.get_node_or_null("InteriorFitout")
	if fit:
		fit.visible = inside
	# Hide leftover solid shell pieces on baked cottages.
	for mesh_name in ["Walls", "Roof", "Door"]:
		var mi := building.get_node_or_null(mesh_name) as MeshInstance3D
		if mi:
			mi.visible = false if inside else mi.visible
	_set_indoor_camera(inside)

func _set_indoor_camera(inside: bool) -> void:
	var rig: Node3D = null
	if Party and Party.has_method("camera_basis_node"):
		rig = Party.camera_basis_node()
	if rig == null and player:
		rig = player.get_node_or_null("CameraPivot") as Node3D
	if rig == null:
		return
	# camera_basis_node may return the Lead body — prefer the pivot on/under it.
	var pivot := rig
	if not (rig is Node and rig.find_child("SpringArm3D", true, false)):
		pivot = rig.find_child("CameraPivot", true, false) as Node3D
		if pivot == null and player:
			pivot = player.get_node_or_null("CameraPivot") as Node3D
	if pivot == null:
		pivot = rig
	var arm := pivot.find_child("SpringArm3D", true, false) as SpringArm3D
	var cam := pivot.find_child("Camera3D", true, false) as Camera3D
	if arm == null or cam == null:
		return
	if inside:
		_cam_out_len = arm.spring_length
		_cam_out_fov = cam.fov
		_cam_out_pitch = arm.rotation_degrees.x
		arm.spring_length = 2.6
		arm.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
		cam.fov = 72.0
	else:
		arm.spring_length = _cam_out_len
		arm.rotation_degrees = Vector3(_cam_out_pitch, 0.0, 0.0)
		cam.fov = _cam_out_fov

func _try_use_door() -> void:
	if _door_busy:
		return
	var door := _near_door
	if door == null and _inside_building:
		door = _active_interior
	if door == null:
		return
	var lead := _interact_actor()
	if lead == null:
		return
	_door_busy = true
	if _inside_building:
		await _party_door_procession(door, false)
		_inside_building = false
		_active_interior = null
		_near_door = null
		hud.set_prompt("Left the building.")
	else:
		_outside_return = lead.global_position
		await _party_door_procession(door, true)
		_inside_building = true
		_active_interior = door
		_near_door = door
		var title := str(door.get_meta("title"))
		hud.set_prompt("Inside %s — walls hold · E at door to leave" % title)
	_door_busy = false

func _party_bodies_for_door() -> Array:
	# Lead first, then free followers (skip pole/brush/rusted).
	var bodies: Array = []
	var lead := _interact_actor()
	if lead:
		bodies.append(lead)
	if Party == null:
		return bodies
	for id in [Party.ID_DOROTHY, Party.ID_SCARECROW, Party.ID_LION, Party.ID_TINMAN]:
		if not Party.is_unlocked(id) or not Party.is_present(id):
			continue
		var m: CharacterBody3D = Party.member(id)
		if m == null or not is_instance_valid(m) or m in bodies:
			continue
		if m.has_method("can_take_lead") and id != Party.ID_DOROTHY and not m.can_take_lead():
			continue
		bodies.append(m)
	return bodies

func _party_door_procession(door: Area3D, entering: bool) -> void:
	## Staggered walk-through so the party is seen entering/leaving — not a pop teleport.
	var building = door.get_meta("building") if door.has_meta("building") else null
	var inn: Vector3 = door.get_meta("interior_pos")
	var ext: Vector3 = door.get_meta("exterior_pos")
	var mid: Vector3 = ext.lerp(inn, 0.42)
	mid.y = maxf(inn.y, ext.y)
	var bodies := _party_bodies_for_door()
	_set_door_seal_open(door, true)
	if entering:
		if hud:
			hud.set_prompt("Entering…")
		for i in bodies.size():
			var body: Node3D = bodies[i] as Node3D
			if body == null:
				continue
			var slot := Vector3(float(i % 3) * 0.5 - 0.5, 0.0, float(i / 3) * 0.45)
			var dest := inn + slot
			if i == 0:
				# Lead crosses threshold first, then swap to interior view.
				await _walk_body_door(body, body.global_position, mid, dest, 0.0)
				_set_interior_view(building, true)
			else:
				await _walk_body_door(body, body.global_position, mid, dest, 0.18)
		# Seal shut while inside — E is the only exit (walls stay solid).
		_set_door_seal_open(door, false)
	else:
		if hud:
			hud.set_prompt("Leaving…")
		for i in bodies.size():
			var body2: Node3D = bodies[i] as Node3D
			if body2 == null:
				continue
			var slot2 := Vector3(float(i % 3) * 0.55 - 0.55, 0.0, float(i / 3) * 0.5)
			var dest2 := ext + slot2
			if i == 0:
				await _walk_body_door(body2, body2.global_position, mid, dest2, 0.0)
				_set_interior_view(building, false)
			else:
				await _walk_body_door(body2, body2.global_position, mid, dest2, 0.18)
		_set_door_seal_open(door, false)

func _walk_body_door(body: Node3D, from: Vector3, mid: Vector3, to: Vector3, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if body == null or not is_instance_valid(body):
		return
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
	# Face travel direction while crossing.
	var face := to - from
	face.y = 0.0
	if face.length() > 0.05 and body.get("visual"):
		var vis = body.get("visual")
		if vis is Node3D:
			(vis as Node3D).rotation.y = atan2(-face.normalized().x, -face.normalized().z)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	body.global_position = from
	tw.tween_property(body, "global_position", mid, 0.32)
	tw.tween_property(body, "global_position", to, 0.38)
	await tw.finished
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO

func _teleport_party_to(at: Vector3) -> void:
	# Instant fallback (sims / rescue). Prefer _party_door_procession for play.
	var bodies := _party_bodies_for_door()
	var i := 0
	for b in bodies:
		var body := b as Node3D
		if body == null:
			continue
		var offset := Vector3(float(i % 3) * 0.45 - 0.45, 0.0, float(i / 3) * 0.45)
		body.global_position = at + offset
		if body is CharacterBody3D:
			(body as CharacterBody3D).velocity = Vector3.ZERO
		i += 1

func _add_fence_line(start: Vector3, dir: Vector3, count: int) -> void:
	for i in count:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.08
		cyl.height = 1.1
		post.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.32, 0.2)
		post.material_override = mat
		add_child(post)
		post.global_position = start + dir.normalized() * float(i) * 2.2 + Vector3(0, 0.55, 0)

func _spawn_party_world() -> void:
	# Linear YBR: companions sit ON the road south of the house — follow the brick to find each.
	scarecrow = SCARECROW_SCENE.instantiate() as CharacterBody3D
	add_child(scarecrow)
	var sc_field := YBR_SCARECROW
	scarecrow.global_position = sc_field
	_build_pole(sc_field + Vector3(0.35, 0, 0.15))
	_build_cornfield(sc_field + Vector3(6.0, 0.0, 0.0)) # corn beside the road, not blocking it
	_add_way_marker(Vector3(0.0, 0.08, 12.0), Color(0.95, 0.85, 0.3), "YBR → SCARECROW", sc_field)
	_add_way_marker(Vector3(0.0, 0.08, 20.0), Color(0.95, 0.85, 0.3), "YBR → SCARECROW", sc_field)
	_add_way_marker(sc_field + Vector3(0.0, 0.0, -3.5), Color(0.95, 0.85, 0.3), "SCARECROW", sc_field)

	lion = LION_SCENE.instantiate() as CharacterBody3D
	add_child(lion)
	lion.global_position = YBR_LION
	_build_lion_den(lion.global_position + Vector3(5.0, 0.0, 0.0)) # den mouth toward road
	_add_way_marker(Vector3(0.0, 0.08, 42.0), Color(1.0, 0.55, 0.15), "YBR → LION", lion.global_position)
	_add_way_marker(Vector3(0.0, 0.08, 52.0), Color(1.0, 0.55, 0.15), "YBR → LION", lion.global_position)
	_add_way_marker(lion.global_position + Vector3(0.0, 0.0, -3.5), Color(1.0, 0.55, 0.15), "LION", lion.global_position)

	tinman = TINMAN_SCENE.instantiate() as CharacterBody3D
	add_child(tinman)
	tinman.global_position = YBR_TIN
	_build_oil_can(YBR_TIN + Vector3(2.5, 0.0, 1.5))
	_add_way_marker(Vector3(0.0, 0.08, 78.0), Color(0.7, 0.85, 0.95), "YBR → TIN MAN", tinman.global_position)
	_add_way_marker(Vector3(0.0, 0.08, 88.0), Color(0.7, 0.85, 0.95), "YBR → TIN MAN", tinman.global_position)
	_add_way_marker(tinman.global_position + Vector3(0.0, 0.0, -3.5), Color(0.7, 0.85, 0.95), "TIN MAN", tinman.global_position)
	# Tree blocks the road past Tin — axe clears the path south to West.
	_spawn_tree_gate(YBR_TREE)
	_spawn_story_witches()

func _spawn_story_witches() -> void:
	# Locasta stands on the YBR *before* the grey house — never inside the wreckage.
	# Dorothy spawns further north and must walk the brick to reach her.
	var greet_at := YBR_LOCASTA
	_spawn_locasta(greet_at)
	_spawn_west_omen(Vector3(-36.0, 0.5, 100.0))
	_add_way_marker(YBR_SPAWN + Vector3(0.0, 0.0, 8.0), Color(0.55, 0.75, 1.0), "YBR → LOCASTA", greet_at)
	_add_way_marker(Vector3(0.0, 0.08, -40.0), Color(0.55, 0.75, 1.0), "YBR → LOCASTA", greet_at)
	_add_way_marker(greet_at + Vector3(0.0, 0.0, 3.0), Color(0.55, 0.75, 1.0), "LOCASTA", greet_at)
	# After Locasta, brick continues to the house/shoes.
	_add_way_marker(Vector3(0.0, 0.08, -18.0), Color(0.85, 0.85, 0.9), "YBR → HOUSE", Vector3(0.0, 0.08, -5.0))

func _spawn_locasta(at: Vector3) -> void:
	var root := CharacterBody3D.new()
	root.name = "Locasta"
	root.add_to_group("story_npc")
	root.collision_layer = 1
	root.collision_mask = 1
	add_child(root)
	root.global_position = at
	locasta = root
	var hip := Node3D.new()
	root.add_child(hip)
	hip.position = Vector3(0, 1.05, 0)
	# Full-ish body: legs, layered skirts, torso, arms, head, pointed hat + wand.
	_locasta_mesh(hip, Vector3(-0.16, -0.55, 0), Vector3(0.18, 0.7, 0.18), Color(0.75, 0.85, 1.0))
	_locasta_mesh(hip, Vector3(0.16, -0.55, 0), Vector3(0.18, 0.7, 0.18), Color(0.75, 0.85, 1.0))
	# Outer robe flare
	var robe := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.32
	cyl.bottom_radius = 0.72
	cyl.height = 1.35
	robe.mesh = cyl
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.45, 0.72, 1.0)
	rm.emission_enabled = true
	rm.emission = Color(0.35, 0.6, 1.0)
	rm.emission_energy_multiplier = 0.9
	robe.material_override = rm
	hip.add_child(robe)
	robe.position = Vector3(0, -0.25, 0)
	# Inner petticoat
	_locasta_mesh(hip, Vector3(0, -0.15, 0), Vector3(0.55, 1.05, 0.55), Color(0.85, 0.92, 1.0, 0.0))
	var pet := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.22
	pc.bottom_radius = 0.5
	pc.height = 1.05
	pet.mesh = pc
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.92, 0.95, 1.0)
	pet.material_override = pm
	hip.add_child(pet)
	pet.position = Vector3(0, -0.2, 0)
	# Bodice
	_locasta_mesh(hip, Vector3(0, 0.55, 0), Vector3(0.55, 0.55, 0.32), Color(0.55, 0.35, 0.75))
	# Arms
	_locasta_mesh(hip, Vector3(-0.42, 0.45, 0), Vector3(0.14, 0.7, 0.14), Color(0.95, 0.82, 0.72))
	_locasta_mesh(hip, Vector3(0.42, 0.45, 0), Vector3(0.14, 0.7, 0.14), Color(0.95, 0.82, 0.72))
	# Head
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.24
	sph.height = 0.48
	head.mesh = sph
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.96, 0.84, 0.74)
	head.material_override = hm
	hip.add_child(head)
	head.position = Vector3(0, 1.0, 0)
	# Hair bun
	_locasta_mesh(hip, Vector3(0, 1.18, -0.05), Vector3(0.28, 0.18, 0.28), Color(0.92, 0.88, 0.55))
	# Pointed hat
	var hat := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.42
	cone.height = 0.7
	hat.mesh = cone
	var hatm := StandardMaterial3D.new()
	hatm.albedo_color = Color(1.0, 0.88, 0.3)
	hatm.emission_enabled = true
	hatm.emission = Color(1.0, 0.85, 0.25)
	hatm.emission_energy_multiplier = 1.5
	hat.material_override = hatm
	hip.add_child(hat)
	hat.position = Vector3(0, 1.48, 0)
	# Brim
	var brim := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.48
	bc.bottom_radius = 0.48
	bc.height = 0.05
	brim.mesh = bc
	brim.material_override = hatm
	hip.add_child(brim)
	brim.position = Vector3(0, 1.18, 0)
	# Star tip
	var star := MeshInstance3D.new()
	var starm := SphereMesh.new()
	starm.radius = 0.14
	starm.height = 0.28
	star.mesh = starm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(1.0, 1.0, 0.7)
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.95, 0.4)
	sm.emission_energy_multiplier = 2.4
	star.material_override = sm
	hip.add_child(star)
	star.position = Vector3(0, 1.9, 0)
	# Wand
	_locasta_mesh(hip, Vector3(0.55, 0.35, 0.15), Vector3(0.06, 1.1, 0.06), Color(0.85, 0.75, 0.4))
	_locasta_mesh(hip, Vector3(0.55, 0.95, 0.15), Vector3(0.16, 0.16, 0.16), Color(1.0, 0.95, 0.5))
	# Soft aura ring at feet
	var aura := MeshInstance3D.new()
	var atorus := TorusMesh.new()
	atorus.inner_radius = 0.55
	atorus.outer_radius = 0.85
	aura.mesh = atorus
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0.6, 0.85, 1.0, 0.45)
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.emission_enabled = true
	am.emission = Color(0.5, 0.8, 1.0)
	am.emission_energy_multiplier = 1.2
	aura.material_override = am
	root.add_child(aura)
	aura.position = Vector3(0, 0.08, 0)
	var lab := Label3D.new()
	lab.text = "LOCASTA\nGood Witch of the North\n(E — speak)"
	lab.font_size = 56
	lab.pixel_size = 0.014
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(0.9, 0.95, 1.0)
	lab.outline_size = 10
	lab.outline_modulate = Color(0.05, 0.1, 0.25)
	root.add_child(lab)
	lab.position = Vector3(0, 3.6, 0)
	var col_body := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.9
	col_body.shape = cap
	col_body.position = Vector3(0, 0.95, 0)
	root.add_child(col_body)
	_add_way_marker(at + Vector3(-2.5, 0, 0), Color(0.65, 0.85, 1.0), "LOCASTA", at)
	_add_way_marker(at + Vector3(2.5, 0, 1.5), Color(0.65, 0.85, 1.0), "NORTH", at)

func _locasta_mesh(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b)
	mat.roughness = 0.7
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos

func _advance_locasta_talk() -> void:
	if locasta_done or locasta == null:
		return
	if _locasta_line >= _locasta_lines.size():
		_finish_locasta_greet()
		return
	var line := _locasta_lines[_locasta_line]
	hud.set_prompt(line)
	var dui := get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("say_line"):
		dui.say_line(line, true)
	_locasta_line += 1
	if _locasta_line >= _locasta_lines.size():
		hud.set_objective("Press E again when you are ready — then claim the Silver Shoes.")
	else:
		hud.set_objective("Locasta speaks — press E to continue (%d/%d)" % [_locasta_line, _locasta_lines.size()])

func _finish_locasta_greet() -> void:
	if locasta_done:
		return
	locasta_done = true
	_near_locasta = false
	var farewell := "Locasta: \"The road is yours. I keep the North.\""
	hud.set_prompt(farewell)
	var dui := get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("say_line"):
		dui.say_line(farewell, true)
	if shoes_done:
		_set_beat(Beat.CLEAR_LANDING)
	else:
		_set_beat(Beat.SHOES)

## Headless / playtest: skip greeting so sims can claim shoes.
func debug_skip_locasta() -> void:
	_locasta_line = _locasta_lines.size()
	_finish_locasta_greet()

func _spawn_west_omen(at: Vector3) -> void:
	# Distant smoke plume + locked sign — boss later (Winkie / after Tin arc).
	var root := Node3D.new()
	root.name = "WestWitchOmen"
	add_child(root)
	root.global_position = at
	var plume := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 2.4
	sph.height = 4.5
	plume.mesh = sph
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.12, 0.08, 0.14, 0.55)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.emission_enabled = true
	pm.emission = Color(0.35, 0.05, 0.08)
	pm.emission_energy_multiplier = 1.2
	plume.material_override = pm
	root.add_child(plume)
	plume.position = Vector3(0, 3.2, 0)
	var lab := Label3D.new()
	lab.text = "WEST WIND\n(not yet)"
	lab.font_size = 48
	lab.pixel_size = 0.014
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(0.85, 0.35, 0.3)
	lab.outline_size = 8
	lab.outline_modulate = Color(0.05, 0, 0)
	root.add_child(lab)
	lab.position = Vector3(0, 6.0, 0)
	# Soft push-back so you can't stroll into the unfinished boss.
	var wall := StaticBody3D.new()
	root.add_child(wall)
	var c := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 4, 8)
	c.shape = box
	c.position = Vector3(0, 2, 0)
	wall.add_child(c)

func _add_way_marker(at: Vector3, col: Color, label: String, toward: Vector3 = Vector3.ZERO) -> void:
	# Signpost post + board + optional 3D arrow that points at the real target (no lying text arrows).
	var root := Node3D.new()
	root.name = "WayMarker_%s" % label.replace(" ", "")
	add_child(root)
	root.global_position = at
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.1
	cyl.height = 3.2
	post.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col.darkened(0.15)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.6
	post.material_override = mat
	root.add_child(post)
	post.position = Vector3(0, 1.6, 0)
	# Wooden board
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.8, 0.7, 0.08)
	board.mesh = box
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.42, 0.28, 0.14)
	bm.roughness = 0.85
	board.material_override = bm
	root.add_child(board)
	board.position = Vector3(0, 3.15, 0)
	_sign_sway.append(board)
	# Painted face plate
	var face := MeshInstance3D.new()
	var fbox := BoxMesh.new()
	fbox.size = Vector3(1.65, 0.55, 0.04)
	face.mesh = fbox
	var fm := StandardMaterial3D.new()
	fm.albedo_color = col.lightened(0.35)
	fm.emission_enabled = true
	fm.emission = col
	fm.emission_energy_multiplier = 0.45
	face.material_override = fm
	board.add_child(face)
	face.position = Vector3(0, 0, 0.06)
	var lab := Label3D.new()
	lab.text = label
	lab.font_size = 56
	lab.pixel_size = 0.011
	lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lab.modulate = Color(0.12, 0.06, 0.1)
	lab.outline_size = 12
	lab.outline_modulate = Color(0.98, 0.94, 0.82)
	board.add_child(lab)
	lab.position = Vector3(0, 0.02, 0.1)
	# 3D chevron arrow aiming at target
	var aim := toward
	if aim == Vector3.ZERO:
		aim = at + Vector3(0, 0, -4)
	var flat := aim - at
	flat.y = 0.0
	if flat.length() > 0.05:
		var yaw := atan2(-flat.x, -flat.z)
		root.rotation.y = yaw
		var arrow := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.55, 0.18, 0.7)
		arrow.mesh = prism
		var am := StandardMaterial3D.new()
		am.albedo_color = col
		am.emission_enabled = true
		am.emission = col
		am.emission_energy_multiplier = 2.0
		arrow.material_override = am
		root.add_child(arrow)
		# Point along local −Z (toward aim after yaw)
		arrow.position = Vector3(0, 2.55, -0.85)
		arrow.rotation_degrees = Vector3(90, 0, 0)

func _add_building_sign(parent: Node3D, local_pos: Vector3, title: String, accent: Color) -> void:
	# Thematic hanging sign: post arm + painted board + readable Label3D.
	var root := Node3D.new()
	root.name = "BuildingSign"
	parent.add_child(root)
	root.position = local_pos
	var arm := MeshInstance3D.new()
	var arm_box := BoxMesh.new()
	arm_box.size = Vector3(0.12, 0.12, 0.9)
	arm.mesh = arm_box
	var arm_m := StandardMaterial3D.new()
	arm_m.albedo_color = Color(0.35, 0.22, 0.12)
	arm.material_override = arm_m
	root.add_child(arm)
	arm.position = Vector3(0, 0.35, -0.2)
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.4, 0.95, 0.12)
	board.mesh = box
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.48, 0.3, 0.16)
	bm.roughness = 0.8
	board.material_override = bm
	root.add_child(board)
	board.position = Vector3(0, 0.0, 0.35)
	_sign_sway.append(board)
	var plate := MeshInstance3D.new()
	var pbox := BoxMesh.new()
	pbox.size = Vector3(2.15, 0.72, 0.05)
	plate.mesh = pbox
	var pm := StandardMaterial3D.new()
	pm.albedo_color = accent.lerp(Color(0.95, 0.88, 0.75), 0.35)
	pm.emission_enabled = true
	pm.emission = accent.lightened(0.2)
	pm.emission_energy_multiplier = 0.35
	plate.material_override = pm
	board.add_child(plate)
	plate.position = Vector3(0, 0, 0.08)
	# Corner bolts
	for ox in [-0.95, 0.95]:
		for oy in [-0.28, 0.28]:
			var bolt := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.04
			sph.height = 0.08
			bolt.mesh = sph
			var bolt_m := StandardMaterial3D.new()
			bolt_m.albedo_color = Color(0.75, 0.65, 0.35)
			bolt_m.metallic = 0.7
			bolt.material_override = bolt_m
			board.add_child(bolt)
			bolt.position = Vector3(ox, oy, 0.1)
	var lab := Label3D.new()
	lab.text = title
	lab.font_size = 72
	lab.pixel_size = 0.012
	lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lab.modulate = Color(0.14, 0.06, 0.1)
	lab.outline_size = 14
	lab.outline_modulate = Color(0.98, 0.93, 0.8)
	board.add_child(lab)
	lab.position = Vector3(0, 0.02, 0.14)
	# Small hanging chain links look
	var chain := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.03
	cc.bottom_radius = 0.03
	cc.height = 0.35
	chain.mesh = cc
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.55, 0.5, 0.4)
	cm.metallic = 0.5
	chain.material_override = cm
	root.add_child(chain)
	chain.position = Vector3(0, 0.55, 0.2)

func _ensure_compass() -> void:
	if hud == null:
		return
	compass = hud.get_node_or_null("Compass") as Label
	if compass == null:
		compass = Label.new()
		compass.name = "Compass"
		compass.position = Vector2(16, 100)
		hud.add_child(compass)
	compass.add_theme_font_size_override("font_size", 20)
	compass.add_theme_color_override("font_color", Color(0.18, 0.07, 0.14))
	compass.add_theme_color_override("font_shadow_color", Color(1, 0.96, 0.9, 0.95))
	compass.add_theme_constant_override("shadow_offset_x", 1)
	compass.add_theme_constant_override("shadow_offset_y", 1)

func _compass_forward() -> Vector3:
	var basis_node: Node3D = null
	if Party and Party.has_method("camera_basis_node"):
		basis_node = Party.camera_basis_node()
	if basis_node == null and player:
		basis_node = player.get_node_or_null("CameraPivot") as Node3D
	var forward := Vector3(0, 0, -1)
	if basis_node:
		# Match locomotion: camera basis * (0,0,-1) style via −Z of the pivot.
		forward = -basis_node.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3(0, 0, -1)
	return forward.normalized()

func _compass_arrow(ang_deg: float) -> String:
	# 8-way arrow from camera-relative bearing (0 = ahead, + = right).
	var a := ang_deg
	while a > 180.0:
		a -= 360.0
	while a < -180.0:
		a += 360.0
	if a >= -22.5 and a < 22.5:
		return "↑"
	if a >= 22.5 and a < 67.5:
		return "↗"
	if a >= 67.5 and a < 112.5:
		return "→"
	if a >= 112.5 and a < 157.5:
		return "↘"
	if a >= 157.5 or a < -157.5:
		return "↓"
	if a >= -157.5 and a < -112.5:
		return "↙"
	if a >= -112.5 and a < -67.5:
		return "←"
	return "↖"

func _update_compass() -> void:
	if compass == null:
		return
	var actor := _interact_actor()
	if actor == null:
		compass.text = ""
		return
	var target_pos := Vector3.ZERO
	var label := ""
	match beat:
		Beat.MEET_LOCASTA:
			if locasta and not locasta_done:
				target_pos = locasta.global_position
				label = "Locasta"
		Beat.SHOES:
			if shoes and not shoes_done:
				target_pos = shoes.global_position
				label = "Silver Shoes"
		Beat.CLEAR_LANDING:
			label = "Landing swarm"
			target_pos = _nearest_enemy_pos(actor, "landing")
			if target_pos == Vector3.ZERO:
				target_pos = _nearest_enemy_pos(actor, "")
				if target_pos == Vector3.ZERO:
					label = ""
		Beat.FREE_SCARECROW:
			if scarecrow and not scarecrow.freed:
				target_pos = scarecrow.global_position
				label = "Scarecrow"
		Beat.CROW_FIELD:
			label = "Crow field"
			target_pos = _nearest_enemy_pos(actor, "crow")
			if target_pos == Vector3.ZERO:
				target_pos = scarecrow.global_position + Vector3(0, 0, -5) if scarecrow else Vector3.ZERO
		Beat.FREE_LION:
			if lion and not lion.calmed:
				target_pos = lion.global_position
				label = "Lion den"
		Beat.LION_PACK:
			label = "Lion pack"
			target_pos = _nearest_enemy_pos(actor, "lion_pack")
			if target_pos == Vector3.ZERO and lion:
				target_pos = lion.global_position
		Beat.FREE_TIN:
			if tinman and tinman.rusted:
				if not has_oil and oil_can:
					target_pos = oil_can.global_position
					label = "Oil can"
				else:
					target_pos = tinman.global_position
					label = "Tin Man"
		Beat.TREE_GATE:
			if living_tree and is_instance_valid(living_tree) and not tree_down:
				target_pos = living_tree.global_position
				label = "Living Tree"
		Beat.MARSHAL:
			if marshal and is_instance_valid(marshal):
				target_pos = marshal.global_position
				label = "Marshal"
		Beat.OPEN_ROAD:
			target_pos = _west_gate_pos
			label = "YBR West gate"
	if label == "" or target_pos == Vector3.ZERO:
		compass.text = ""
		return
	var to: Vector3 = target_pos - actor.global_position
	to.y = 0.0
	var dist := to.length()
	var forward := _compass_forward()
	var right := Vector3.UP.cross(forward)
	if right.length() < 0.01:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var local := Vector2(to.dot(right), to.dot(forward))
	var ang := rad_to_deg(atan2(local.x, local.y))
	var arrow := _compass_arrow(ang)
	var dir := "ahead"
	if ang > 30.0 and ang < 150.0:
		dir = "right"
	elif ang < -30.0 and ang > -150.0:
		dir = "left"
	elif absf(ang) >= 150.0:
		dir = "behind"
	compass.text = "%s  %s  ·  %s  ·  %.0fm" % [arrow, label, dir, dist]

func _nearest_enemy_pos(from: Node3D, wave: String = "") -> Vector3:
	if from == null:
		return Vector3.ZERO
	var best := Vector3.ZERO
	var best_d := 1.0e9
	for n in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(n) or not (n is Node3D):
			continue
		if n.is_in_group("enemies_dead"):
			continue
		var hp = n.get("health")
		if hp != null and int(hp) <= 0:
			continue
		if wave != "":
			if not n.has_meta("wave") or str(n.get_meta("wave")) != wave:
				continue
		var marshal_v = n.get("is_marshal")
		if marshal_v == true and wave == "landing":
			continue
		var d: float = from.global_position.distance_to((n as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = (n as Node3D).global_position
	return best

func _tag_baked_landing_puppets() -> void:
	# Scene-baked puppets had no wave meta → kills never advanced CLEAR_LANDING.
	# Relocate them far off-camera and march them in so they never "pop" near the house.
	var i := 0
	var rally := Vector3(0.0, 0.08, 10.0)
	if player:
		rally = player.global_position
	for n in get_children():
		if n is CharacterBody3D and n.is_in_group("enemies") and not n.has_meta("wave"):
			n.set_meta("wave", "landing")
			if n.has_method("set_play_bounds"):
				n.set_play_bounds(PLAY_BOUND_X, PLAY_BOUND_Z)
			var bearing: float = float(i) * TAU / 5.0 + 0.4
			if n.has_method("march_from_afar"):
				n.march_from_afar(rally, bearing, 22.0 + float(i) * 1.5, 8.0 + float(i) * 1.2, 1.75)
			elif n.has_method("arm_delayed"):
				n.arm_delayed(6.0 + float(i) * 1.2, 1.4)
			i += 1

func _spawn_landing_puppets() -> void:
	# March toward the house plaza on the YBR — not into Dorothy's far-north start.
	var rally := Vector3(0.0, 0.08, -2.0)
	var bearings := [0.55, 2.2, 3.7, 5.1]
	var i := 0
	for bearing in bearings:
		var pup := _spawn_puppet(rally, Color(0.93, 0.62, 0.72), "landing")
		if pup and pup.has_method("march_from_afar"):
			pup.march_from_afar(rally, float(bearing), 22.0 + float(i) * 1.8, 7.5 + float(i) * 1.4, 1.8)
		elif pup and pup.has_method("arm_delayed"):
			pup.arm_delayed(6.0 + float(i) * 1.2, 1.3)
		i += 1
	landing_need = maxi(3, _count_live_landing())

func _count_live_landing() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == null or not is_instance_valid(e):
			continue
		if e.is_in_group("enemies_dead"):
			continue
		if e is CharacterBody3D and e.get("is_marshal") == true:
			continue
		if e == living_tree or (e is Node and e.is_in_group("living_tree")):
			continue
		var wave := str(e.get_meta("wave")) if e.has_meta("wave") else "landing"
		if wave == "landing":
			n += 1
	return n

func _try_advance_landing_clear() -> void:
	if beat != Beat.CLEAR_LANDING:
		return
	if landing_kills >= landing_need or _count_live_landing() <= 0:
		_set_beat(Beat.FREE_SCARECROW)

func _spawn_crow_field() -> void:
	# Approach from off-screen around Scarecrow — no ring-pop at his feet.
	var rally := scarecrow.global_position if scarecrow else Vector3(28, 0.08, 28)
	for i in crow_need:
		var bearing: float = float(i) / float(crow_need) * TAU + 0.25
		var pup := _spawn_puppet(rally, Color(0.7, 0.45, 0.55), "crow")
		if pup and pup.has_method("march_from_afar"):
			pup.march_from_afar(rally, bearing, 18.0 + float(i) * 1.2, 3.5 + float(i) * 0.55, 2.0)
		elif pup and pup.has_method("arm_delayed"):
			pup.arm_delayed(1.0 + float(i) * 0.4, 1.5)

func _spawn_lion_pack() -> void:
	# Post-Lion unlock teach wave — ROAR (F) while Leading Lion. March from the rim.
	lion_pack_kills = 0
	var rally := Vector3(6.0, 0.08, -20.0)
	if lion:
		rally = lion.global_position + Vector3(0.0, 0.0, 6.0)
	for i in lion_pack_need:
		var bearing: float = float(i) / float(lion_pack_need) * TAU + 0.15
		var pup := _spawn_puppet(rally, Color(0.85, 0.4, 0.5), "lion_pack")
		if pup and pup.has_method("march_from_afar"):
			pup.march_from_afar(rally, bearing, 18.0 + float(i) * 1.0, 3.0 + float(i) * 0.45, 2.05)
		elif pup and pup.has_method("arm_delayed"):
			pup.arm_delayed(0.7 + float(i) * 0.3, 1.55)

func _spawn_tin_wave() -> void:
	# Post-Tin unlock: rogues advance from the west rim toward the terrace/tree.
	var rally := Vector3(-42.0, 0.08, 4.0)
	if tinman:
		rally = tinman.global_position + Vector3(4.0, 0.0, 0.0)
	for i in 3:
		var bearing: float = PI + float(i) * 0.7 # mostly from further west / flanks
		var pup := _spawn_puppet(rally, Color(0.55, 0.65, 0.75), "tin_wave")
		if pup and pup.has_method("march_from_afar"):
			pup.march_from_afar(rally, bearing, 16.0 + float(i) * 1.2, 2.5 + float(i) * 0.35, 1.95)
		elif pup and pup.has_method("arm_delayed"):
			pup.arm_delayed(0.5 + float(i) * 0.25, 1.5)

func _auto_lead(id: StringName) -> void:
	if Party == null:
		return
	# Unlock/present already set by companion free methods; force agency onto the new friend.
	if Party.has_method("set_leader"):
		Party.set_leader(id)

func _spawn_tree_gate(at: Vector3) -> void:
	living_tree = StaticBody3D.new()
	living_tree.set_script(TREE_SCRIPT)
	add_child(living_tree)
	living_tree.global_position = at

func _spawn_marshal() -> void:
	# Blocks the YBR south of the tree, before the West gate.
	marshal = _spawn_puppet(Vector3(0.0, 0.08, 118.0), Color(0.75, 0.25, 0.4), "marshal")
	if marshal:
		marshal.is_marshal = true
		marshal.armored = true
		marshal.health = 90
		marshal.scale = Vector3(1.35, 1.35, 1.35)

func _spawn_puppet(at: Vector3, tint: Color, tag: String) -> CharacterBody3D:
	var p: CharacterBody3D = PUPPET_SCENE.instantiate() as CharacterBody3D
	add_child(p)
	p.global_position = at
	p.tint = tint
	p.set_meta("wave", tag)
	if p.has_method("set_play_bounds"):
		p.set_play_bounds(PLAY_BOUND_X, PLAY_BOUND_Z)
	return p

func _build_pole(at: Vector3) -> void:
	pole = MeshInstance3D.new()
	pole.name = "ScarecrowPole"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.12
	cyl.height = 2.6
	pole.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.28, 0.16)
	pole.material_override = mat
	add_child(pole)
	pole.global_position = at + Vector3(0, 1.3, 0)
	var tip := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.12
	tip.mesh = sph
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.9, 0.85, 0.5)
	em.emission_enabled = true
	em.emission = Color(1.0, 0.9, 0.4)
	em.emission_energy_multiplier = 1.5
	tip.material_override = em
	tip.position = Vector3(0, 1.4, 0)
	pole.add_child(tip)

func _build_cornfield(at: Vector3) -> void:
	# Open field for Scarecrow — rows of stalks, not a building wedge.
	var root := Node3D.new()
	root.name = "Cornfield"
	add_child(root)
	root.global_position = at
	# Tilled / dirt patch under the pole (walkable, no collision)
	_add_decor_box(root, Vector3(0, 0.03, 0), Vector3(14.0, 0.06, 12.0), Color(0.42, 0.32, 0.18))
	_add_decor_box(root, Vector3(0, 0.05, 0), Vector3(11.0, 0.04, 9.0), Color(0.36, 0.5, 0.22))
	var stalk_m := StandardMaterial3D.new()
	stalk_m.albedo_color = Color(0.45, 0.62, 0.22)
	stalk_m.roughness = 0.9
	var tassel_m := StandardMaterial3D.new()
	tassel_m.albedo_color = Color(0.85, 0.72, 0.28)
	tassel_m.emission_enabled = true
	tassel_m.emission = Color(0.7, 0.55, 0.15)
	tassel_m.emission_energy_multiplier = 0.25
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# Leave a clear aisle on −X (road approach) and a small clearing around the pole.
	for row in range(-4, 5):
		for col in range(-5, 6):
			if absf(float(row)) <= 1.1 and absf(float(col)) <= 1.1:
				continue # clearing around pole
			if col <= -3 and absf(float(row)) <= 1.5:
				continue # approach aisle from the west road
			var stalk := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			var h: float = 1.35 + rng.randf() * 0.55
			cyl.top_radius = 0.04
			cyl.bottom_radius = 0.07
			cyl.height = h
			stalk.mesh = cyl
			stalk.material_override = stalk_m
			root.add_child(stalk)
			var ox: float = float(col) * 1.15 + rng.randf_range(-0.15, 0.15)
			var oz: float = float(row) * 1.05 + rng.randf_range(-0.12, 0.12)
			stalk.position = Vector3(ox, h * 0.5, oz)
			stalk.rotation_degrees.y = rng.randf_range(-20.0, 20.0)
			stalk.rotation_degrees.z = rng.randf_range(-6.0, 6.0)
			var ear := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.09
			sph.height = 0.22
			ear.mesh = sph
			ear.material_override = tassel_m
			stalk.add_child(ear)
			ear.position = Vector3(0.0, h * 0.42, 0.0)
	# Field label
	var lab := Label3D.new()
	lab.text = "a cornfield"
	lab.font_size = 48
	lab.pixel_size = 0.012
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(0.2, 0.14, 0.06)
	lab.outline_size = 10
	lab.outline_modulate = Color(0.95, 0.9, 0.7)
	root.add_child(lab)
	lab.position = Vector3(0.0, 2.8, -4.5)
	# Low rail fence on far edges (visual only)
	for side in [-1, 1]:
		for i in range(8):
			var post := MeshInstance3D.new()
			var pc := CylinderMesh.new()
			pc.top_radius = 0.05
			pc.bottom_radius = 0.06
			pc.height = 0.9
			post.mesh = pc
			var pm := StandardMaterial3D.new()
			pm.albedo_color = Color(0.4, 0.28, 0.16)
			post.material_override = pm
			root.add_child(post)
			post.position = Vector3(side * 6.5, 0.45, -5.0 + float(i) * 1.3)

func _build_lion_den(at: Vector3) -> void:
	# Afraid hide that still reads: open south alcove, lion visible in the hollow.
	# Never a solid fill over the character (that looked like a wedge).
	var root := Node3D.new()
	root.name = "LionDen"
	add_child(root)
	root.global_position = at
	var leaf := Color(0.28, 0.52, 0.26)
	var leaf_dark := Color(0.18, 0.36, 0.18)
	# Soft ground patch (no collision — walkable)
	_add_decor_box(root, Vector3(0, 0.04, 0.2), Vector3(4.2, 0.08, 3.6), Color(0.32, 0.48, 0.28))
	# Horseshoe thicket: back (north) + flanks; mouth open toward approach (+Z / south).
	_add_hedge_wall(root, Vector3(0.0, 0.85, -1.55), Vector3(3.6, 1.7, 0.55), leaf_dark) # back
	_add_hedge_wall(root, Vector3(-1.85, 0.75, 0.15), Vector3(0.55, 1.5, 2.8), leaf) # west
	_add_hedge_wall(root, Vector3(1.85, 0.75, 0.15), Vector3(0.55, 1.5, 2.8), leaf) # east
	# Corner clumps for silhouette (no full roof)
	_add_hedge_wall(root, Vector3(-1.4, 1.35, -1.2), Vector3(1.0, 0.9, 0.9), leaf)
	_add_hedge_wall(root, Vector3(1.4, 1.35, -1.2), Vector3(1.0, 0.9, 0.9), leaf)
	# Tall grass blades at the mouth — partial cover without swallowing the body
	for i in range(7):
		var blade := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.04
		cyl.height = 0.7 + float(i % 3) * 0.15
		blade.mesh = cyl
		var bm := StandardMaterial3D.new()
		bm.albedo_color = leaf.lightened(0.1 * float(i % 2))
		bm.roughness = 0.95
		blade.material_override = bm
		root.add_child(blade)
		blade.position = Vector3(-1.2 + float(i) * 0.4, cyl.height * 0.5, 1.35)
		blade.rotation_degrees = Vector3(8.0 * (1 if i % 2 == 0 else -1), 12.0 * float(i), 0)
	# Broken candy fence post (story beat prop)
	var post := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.08
	pc.bottom_radius = 0.1
	pc.height = 1.4
	post.mesh = pc
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.85, 0.55, 0.65)
	post.material_override = pm
	root.add_child(post)
	post.position = Vector3(-2.4, 0.7, 0.8)
	post.rotation_degrees = Vector3(0, 0, 18)
	# Fear halo ring on ground — reads "something cowers here"
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.05
	ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.95, 0.55, 0.2, 0.55)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.45, 0.15)
	rm.emission_energy_multiplier = 0.6
	ring.material_override = rm
	root.add_child(ring)
	ring.position = Vector3(0, 0.06, 0.15)
	ring.rotation_degrees.x = 90
	# Soft label — readable without spoiling the find
	var lab := Label3D.new()
	lab.text = "a trembling thicket"
	lab.font_size = 36
	lab.pixel_size = 0.01
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(0.95, 0.85, 0.7)
	lab.outline_size = 6
	lab.outline_modulate = Color(0.15, 0.1, 0.08)
	root.add_child(lab)
	lab.position = Vector3(0, 2.35, 0.2)
	# Keep lion slightly inset so he peeks from the hollow (not buried in mesh)
	if lion:
		lion.global_position = at + Vector3(0.0, 0.08, -0.35)
		if lion.get_node_or_null("Visual"):
			lion.get_node("Visual").rotation_degrees.y = 180.0 # face the open mouth / approach

func _add_hedge_wall(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.92
	mi.material_override = mat
	body.add_child(mi)
	var c := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	# Collision slightly thinner so the alcove stays walkable
	sh.size = size * Vector3(0.92, 1.0, 0.92)
	c.shape = sh
	body.add_child(c)
	# Bumpy top puffs for "leaves" silhouette
	for k in range(3):
		var puff := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.28 + 0.08 * float(k % 2)
		sph.height = sph.radius * 1.6
		puff.mesh = sph
		var pm := StandardMaterial3D.new()
		pm.albedo_color = col.lightened(0.08)
		puff.material_override = pm
		body.add_child(puff)
		puff.position = Vector3(
			(float(k) - 1.0) * size.x * 0.28,
			size.y * 0.5 + 0.1,
			(float(k % 2) - 0.5) * size.z * 0.15
		)

func _build_oil_can(at: Vector3) -> void:
	oil_can = Area3D.new()
	oil_can.name = "OilCan"
	oil_can.collision_layer = 0
	oil_can.collision_mask = 2
	oil_can.monitoring = true
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.2
	col.shape = sph
	oil_can.add_child(col)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.14
	cyl.height = 0.28
	mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.35, 0.15)
	mat.metallic = 0.6
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.5, 0.1)
	mat.emission_energy_multiplier = 0.8
	mesh.material_override = mat
	oil_can.add_child(mesh)
	add_child(oil_can)
	oil_can.global_position = at + Vector3(0, 0.2, 0)
	oil_can.body_entered.connect(_on_oil_body_entered)
	oil_can.body_exited.connect(_on_oil_body_exited)

func _process(_delta: float) -> void:
	if player == null:
		return
	_update_compass()
	# Gentle sign sway
	var t := Time.get_ticks_msec() * 0.001
	for i in _sign_sway.size():
		var b = _sign_sway[i]
		if b and is_instance_valid(b):
			b.rotation_degrees.z = sin(t * 1.4 + float(i) * 0.7) * 2.5
	# Soft recovery: if the square is empty but the beat stuck, open free.
	if beat == Beat.CLEAR_LANDING and _count_live_landing() <= 0:
		_try_advance_landing_clear()
	var actor := _interact_actor()
	if actor == null:
		return
	# Oil: distance to current Lead (any character), not body_enter sticky flags.
	if oil_can and oil_can.monitoring and oil_can.visible:
		_near_oil = actor.global_position.distance_to(oil_can.global_position) < 2.0
	else:
		_near_oil = false
	# Door: if inside, E always exits — keep door armed even if Area signals flaked.
	if _inside_building and _active_interior != null:
		_near_door = _active_interior
	var near_sc_body: bool = scarecrow != null and not scarecrow.freed \
		and actor.global_position.distance_to(scarecrow.global_position) < 2.8
	# Free is E at the pole — kill-all alone never unlocks him. Any Lead can free.
	_near_scarecrow = beat == Beat.FREE_SCARECROW and near_sc_body
	_near_lion = beat == Beat.FREE_LION and lion and not lion.calmed \
		and actor.global_position.distance_to(lion.global_position) < 2.8
	_near_tin = beat == Beat.FREE_TIN and tinman and tinman.rusted and has_oil \
		and actor.global_position.distance_to(tinman.global_position) < 2.4
	_near_locasta = (not locasta_done) and locasta != null \
		and actor.global_position.distance_to(locasta.global_position) < 5.5
	_near_west_gate = beat == Beat.OPEN_ROAD and _west_road_gate != null \
		and actor.global_position.distance_to(_west_gate_pos) < 4.5
	# Auto-open first line when Dorothy walks into Locasta (cannot miss the greeter).
	if _near_locasta and not locasta_done and _locasta_line == 0 and beat == Beat.MEET_LOCASTA:
		_advance_locasta_talk()

	if Input.is_action_just_pressed("interact"):
		# Exit always wins while flagged inside (stuck-in-building fix).
		if _inside_building:
			_try_use_door()
		elif _near_door != null:
			_try_use_door()
		elif _near_west_gate:
			_go_west_castle()
		elif _near_whimsy != null:
			_collect_whimsy(_near_whimsy)
		elif _near_locasta and not locasta_done:
			_advance_locasta_talk()
		elif _near_scarecrow:
			_free_scarecrow()
		elif near_sc_body and beat < Beat.FREE_SCARECROW:
			if beat == Beat.MEET_LOCASTA:
				hud.set_prompt("Speak with Locasta first (E) — then the Shoes, then free Scarecrow.")
			elif beat == Beat.SHOES:
				hud.set_prompt("Claim the Silver Shoes first, then free the Scarecrow (E).")
			else:
				hud.set_prompt("Clear the landing swarm first (%d/%d), then E at the pole." % [landing_kills, landing_need])
		elif _near_lion:
			_calm_lion()
		elif _near_oil and not has_oil and beat >= Beat.FREE_TIN and beat <= Beat.TREE_GATE and tinman and tinman.rusted:
			_take_oil()
		elif _near_tin:
			_free_tinman()

	_update_proximity_prompt()

func _interact_actor() -> Node3D:
	# Unlocks and doors always key off whoever is currently Leading.
	if Party and Party.has_method("leader_body"):
		var lead = Party.leader_body()
		if lead and is_instance_valid(lead):
			return lead
	return player

func on_enemy_down(enemy: Node) -> void:
	if enemy == null:
		return
	var wave := ""
	if enemy.has_meta("wave"):
		wave = str(enemy.get_meta("wave"))
	if enemy == living_tree or (enemy is Node and enemy.is_in_group("living_tree")):
		tree_down = true
		if beat == Beat.TREE_GATE:
			_set_beat(Beat.MARSHAL)
		return
	# Untagged square puppets count as landing (baked scene used to omit meta).
	if wave == "" and enemy is CharacterBody3D and enemy.is_in_group("enemies"):
		if enemy.get("is_marshal") != true:
			wave = "landing"
			enemy.set_meta("wave", "landing")
	if wave == "landing":
		landing_kills += 1
		_refresh_roster()
		_try_advance_landing_clear()
	elif wave == "crow":
		crow_kills += 1
		_refresh_roster()
		if beat == Beat.CROW_FIELD and crow_kills >= crow_need:
			_set_beat(Beat.FREE_LION)
	elif wave == "lion_pack":
		lion_pack_kills += 1
		_refresh_roster()
		if beat == Beat.LION_PACK and lion_pack_kills >= lion_pack_need:
			_set_beat(Beat.FREE_TIN)
	elif wave == "marshal" or (enemy is CharacterBody3D and enemy.get("is_marshal") == true):
		marshal_down = true
		if beat == Beat.MARSHAL:
			_set_beat(Beat.OPEN_ROAD)

func _set_beat(next: Beat) -> void:
	beat = next
	match beat:
		Beat.MEET_LOCASTA:
			hud.set_objective("Follow the Yellow Brick Road south to Locasta — Good Witch of the North (E).")
			hud.set_prompt("YBR south · glowing Locasta · E advances her counsel")
		Beat.SHOES:
			hud.set_objective("Keep on the Yellow Brick Road — claim the Silver Shoes under the grey house ahead.")
			hud.set_prompt("Locasta has spoken — YBR → house · Shoes")
		Beat.CLEAR_LANDING:
			hud.set_objective("Rogue Munchkins sneak in near the landing — kick them down (F). %d/%d" % [landing_kills, landing_need])
			# Kills before shoes already counted → don't soft-lock waiting for more deaths.
			_try_advance_landing_clear()
		Beat.FREE_SCARECROW:
			hud.set_objective("Follow the Yellow Brick Road south — free the Scarecrow on the pole (E).")
			hud.set_prompt("YBR south · E at the pole frees Scarecrow")
		Beat.CROW_FIELD:
			hud.set_objective("Crow field on the road: Lead Scarecrow — F = CAW. %d/%d" % [crow_kills, crow_need])
			_spawn_crow_field()
		Beat.FREE_LION:
			hud.set_objective("Follow the Yellow Brick Road south — calm the Lion (E as any Lead).")
		Beat.LION_PACK:
			hud.set_objective("Lion pack on the road: Lead Lion — F = ROAR. %d/%d" % [lion_pack_kills, lion_pack_need])
			_spawn_lion_pack()
		Beat.FREE_TIN:
			hud.set_objective("Follow the Yellow Brick Road south — oil can, then free the Tin Man (E).")
		Beat.TREE_GATE:
			hud.set_objective("Lead Tin Man — F = AXE the Living Tree blocking the Yellow Brick Road.")
			_spawn_tin_wave()
		Beat.MARSHAL:
			hud.set_objective("Marshal blocks the Yellow Brick Road south — axe or roar recommended.")
			if marshal == null:
				_spawn_marshal()
		Beat.OPEN_ROAD:
			hud.set_objective("FINAL STEP (L2): Keep following the Yellow Brick Road SOUTH to the glowing gate — E → West castle.")
			hud.set_prompt("End-gate: YBR south · E on yellow pad · F10 West · F11 Emerald skip")
			if not _open_road_sting_done:
				_open_road_sting_done = true
				_ensure_west_road_gate()
				_add_way_marker(Vector3(0.0, 0.08, 118.0), Color(0.95, 0.8, 0.2), "YBR → WEST", _west_gate_pos)
				_add_way_marker(Vector3(0.0, 0.08, 124.0), Color(0.95, 0.8, 0.2), "YBR → WEST", _west_gate_pos)
				var d := get_node_or_null("/root/DialogueUI")
				if d and d.has_method("say"):
					d.say("Narrator", "The Yellow Brick Road opens south. Follow it to the glowing gate — that is how you leave Munchkinland.", true, 5.0)
	_refresh_roster()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			_go_west_castle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F11:
			_go_emerald_city()
			get_viewport().set_input_as_handled()

func _ensure_west_road_gate() -> void:
	if _west_road_gate != null and is_instance_valid(_west_road_gate):
		return
	_west_road_gate = Node3D.new()
	_west_road_gate.name = "WestRoadGate"
	add_child(_west_road_gate)
	_west_road_gate.global_position = _west_gate_pos
	var pad := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(10.0, 0.14, 8.0)
	pad.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.72, 0.18)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.45, 0.1)
	mat.emission_energy_multiplier = 0.85
	pad.material_override = mat
	_west_road_gate.add_child(pad)
	var lab := Label3D.new()
	lab.text = "YELLOW BRICK ROAD\n→ Winkie Country · West castle\nFINAL STEP · E to travel"
	lab.font_size = 52
	lab.pixel_size = 0.014
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(1.0, 0.88, 0.35)
	lab.outline_size = 10
	_west_road_gate.add_child(lab)
	lab.position = Vector3(0, 3.6, 0)
	# Tall emissive post so gate reads from far up the road
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.18
	cyl.height = 6.0
	post.mesh = cyl
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.9, 0.75, 0.2)
	pm.emission_enabled = true
	pm.emission = Color(1.0, 0.85, 0.3)
	pm.emission_energy_multiplier = 1.4
	post.material_override = pm
	_west_road_gate.add_child(post)
	post.position = Vector3(0, 3.0, 0)

## Optional chuckles — not required for story; feed Whimsy score.
func _ensure_whimsy_hud() -> void:
	if hud == null:
		return
	_whimsy_label = hud.get_node_or_null("WhimsyScore") as Label
	if _whimsy_label == null:
		_whimsy_label = Label.new()
		_whimsy_label.name = "WhimsyScore"
		_whimsy_label.position = Vector2(16, 128)
		_whimsy_label.add_theme_font_size_override("font_size", 16)
		_whimsy_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.9))
		hud.add_child(_whimsy_label)
	_refresh_whimsy_hud()

func _refresh_whimsy_hud() -> void:
	if _whimsy_label:
		_whimsy_label.text = "Whimsy  %d" % whimsy_points

func _add_whimsy_activities() -> void:
	# Side fun along the YBR corridor (not on the brick centerline).
	var spots := [
		{"pos": Vector3(8, 0, -44), "kind": "bounce", "name": "Bounce toadstool"},
		{"pos": Vector3(-9, 0, -20), "kind": "giggle", "name": "Giggle bloom"},
		{"pos": Vector3(10, 0, 8), "kind": "chime", "name": "Candy chime"},
		{"pos": Vector3(-8, 0, 32), "kind": "bounce", "name": "Bounce toadstool"},
		{"pos": Vector3(9, 0, 55), "kind": "giggle", "name": "Roadside giggle"},
		{"pos": Vector3(-10, 0, 75), "kind": "chime", "name": "Candy chime"},
		{"pos": Vector3(8, 0, 100), "kind": "dance", "name": "Dance ring"},
		{"pos": Vector3(-8, 0, 120), "kind": "giggle", "name": "Gate giggle"},
	]
	for s in spots:
		_spawn_whimsy(s["pos"], s["kind"], s["name"])

func _spawn_whimsy(at: Vector3, kind: String, title: String) -> void:
	var area := Area3D.new()
	area.name = "Whimsy_%s" % kind
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.set_meta("kind", kind)
	area.set_meta("title", title)
	area.set_meta("taken", false)
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.6
	col.shape = sph
	area.add_child(col)
	add_child(area)
	area.global_position = at + Vector3(0, 0.2, 0)
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	match kind:
		"bounce":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.55
			cyl.bottom_radius = 0.75
			cyl.height = 0.55
			mi.mesh = cyl
			mat.albedo_color = Color(0.95, 0.35, 0.55)
			mat.emission = Color(0.9, 0.3, 0.5)
			mat.emission_energy_multiplier = 0.6
			mi.position = Vector3(0, 0.3, 0)
		"giggle":
			var sphm := SphereMesh.new()
			sphm.radius = 0.35
			sphm.height = 0.7
			mi.mesh = sphm
			mat.albedo_color = Color(0.95, 0.85, 0.3)
			mat.emission = Color(1.0, 0.9, 0.4)
			mat.emission_energy_multiplier = 0.8
			mi.position = Vector3(0, 0.6, 0)
		"chime":
			var box := BoxMesh.new()
			box.size = Vector3(0.25, 1.4, 0.25)
			mi.mesh = box
			mat.albedo_color = Color(0.6, 0.9, 1.0)
			mat.emission = Color(0.5, 0.85, 1.0)
			mat.emission_energy_multiplier = 0.7
			mi.position = Vector3(0, 0.9, 0)
		_:
			var tor := TorusMesh.new()
			tor.inner_radius = 0.9
			tor.outer_radius = 1.2
			mi.mesh = tor
			mat.albedo_color = Color(0.85, 0.55, 0.95)
			mat.emission = Color(0.7, 0.4, 0.9)
			mat.emission_energy_multiplier = 0.5
			mi.position = Vector3(0, 0.15, 0)
	mi.material_override = mat
	area.add_child(mi)
	var lab := Label3D.new()
	lab.text = title
	lab.font_size = 36
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(1, 0.9, 0.95)
	lab.position = Vector3(0, 1.8, 0)
	area.add_child(lab)
	area.body_entered.connect(func(b):
		if b.is_in_group("player") or b.is_in_group("party"):
			if not area.get_meta("taken"):
				_near_whimsy = area
	)
	area.body_exited.connect(func(b):
		if (b.is_in_group("player") or b.is_in_group("party")) and _near_whimsy == area:
			_near_whimsy = null
	)

func _collect_whimsy(area: Area3D) -> void:
	if area == null or area.get_meta("taken"):
		return
	area.set_meta("taken", true)
	var kind := str(area.get_meta("kind"))
	var pts := 5
	match kind:
		"bounce":
			pts = 8
			var actor := _interact_actor()
			if actor is CharacterBody3D:
				(actor as CharacterBody3D).velocity.y = 9.5
			hud.set_prompt("Boing! +%d whimsy" % pts)
		"giggle":
			pts = 6
			hud.set_prompt("*giggle* +%d whimsy" % pts)
			var d := get_node_or_null("/root/DialogueUI")
			if d and d.has_method("say"):
				d.say("Bloom", "Hee-hee!", true, 1.5)
		"chime":
			pts = 7
			hud.set_prompt("Ting-a-ling! +%d whimsy" % pts)
		"dance":
			pts = 10
			hud.set_prompt("You spin a little. +%d whimsy" % pts)
		_:
			pts = 5
	whimsy_points += pts
	_refresh_whimsy_hud()
	area.visible = false
	area.monitoring = false
	if _near_whimsy == area:
		_near_whimsy = null
	get_tree().create_timer(1.4).timeout.connect(func():
		if hud and not _near_west_gate:
			pass
	)

func _go_west_castle() -> void:
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("go_to"):
		lt.go_to(WEST_SCENE, "The hourglass turns — Winkie Country…", "Winkie Country · the West castle")
	else:
		get_tree().change_scene_to_file(WEST_SCENE)

func _go_emerald_city() -> void:
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("go_to"):
		lt.go_to(EMERALD_SCENE, "The hourglass turns — Emerald City…", "Emerald City · the Wizard's tower")
	else:
		get_tree().change_scene_to_file(EMERALD_SCENE)

func _update_proximity_prompt() -> void:
	if _inside_building and _active_interior != null:
		var title_in := str(_active_interior.get_meta("title"))
		hud.set_prompt("E  —  Exit %s" % title_in)
	elif _near_door != null:
		var title := str(_near_door.get_meta("title"))
		if _inside_building:
			hud.set_prompt("E  —  Exit %s" % title)
		else:
			hud.set_prompt("E  —  Enter %s" % title)
	elif _near_west_gate:
		hud.set_prompt("E  —  Take the Yellow Brick Road to the West castle")
	elif _near_whimsy != null and not _near_whimsy.get_meta("taken"):
		hud.set_prompt("E  —  %s (+whimsy)" % str(_near_whimsy.get_meta("title")))
	elif _near_locasta and not locasta_done:
		if _locasta_line == 0:
			hud.set_prompt("E  —  Speak with Locasta, Good Witch of the North")
		elif _locasta_line < _locasta_lines.size():
			hud.set_prompt("E  —  Continue Locasta's counsel (%d/%d)" % [_locasta_line + 1, _locasta_lines.size()])
		else:
			hud.set_prompt("E  —  Thank Locasta and take the road")
	elif _near_scarecrow:
		hud.set_prompt("E  —  Free Scarecrow from the pole (any Lead)")
	elif scarecrow and not scarecrow.freed and _interact_actor().global_position.distance_to(scarecrow.global_position) < 2.8:
		if beat == Beat.MEET_LOCASTA:
			hud.set_prompt("Locasta first (E) — then Shoes — then free Scarecrow")
		elif beat == Beat.SHOES:
			hud.set_prompt("Shoes first — then E frees Scarecrow")
		elif beat == Beat.CLEAR_LANDING:
			hud.set_prompt("Clear swarm %d/%d — then E frees Scarecrow" % [landing_kills, landing_need])
		else:
			hud.set_prompt("E  —  Free Scarecrow from the pole")
	elif _near_lion:
		hud.set_prompt("E  —  Calm the Lion (any Lead)")
	elif _near_oil and not has_oil and tinman and tinman.rusted and beat >= Beat.FREE_TIN:
		hud.set_prompt("E  —  Take the oil can (any Lead)")
	elif _near_tin:
		hud.set_prompt("E  —  Oil the Tin Man (any Lead)")
	elif beat == Beat.MEET_LOCASTA:
		hud.set_prompt("Find the glowing North witch ahead · E to speak")
	elif beat == Beat.CLEAR_LANDING:
		hud.set_prompt("F  —  Kick   ·   Space blink   ·   swarm sneaks in")
	elif beat == Beat.FREE_SCARECROW:
		hud.set_prompt("Follow SCARECROW posts  ·  E free (not kill)")
	elif beat == Beat.CROW_FIELD:
		hud.set_prompt("Leading Scarecrow  ·  F CAW confuses swarms")
	elif beat == Beat.LION_PACK:
		hud.set_prompt("Leading Lion  ·  F ROAR scatters the pack")
	elif beat == Beat.TREE_GATE:
		hud.set_prompt("Leading Tin Man  ·  F AXE chops armor")

func _on_oil_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.is_in_group("party"):
		_near_oil = true

func _on_oil_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.is_in_group("party"):
		_near_oil = false

func _on_shoes_claimed() -> void:
	shoes_done = true
	if player.has_method("empower_shoes"):
		player.empower_shoes()
	if not locasta_done:
		# Can claim early; still need Locasta counsel before the swarm beat.
		hud.set_prompt("Shoes claimed — finish speaking with Locasta (E).")
		if beat != Beat.MEET_LOCASTA:
			_set_beat(Beat.MEET_LOCASTA)
		return
	_set_beat(Beat.CLEAR_LANDING)
	# _set_beat may auto-skip to FREE_SCARECROW if swarm already dead.
	if beat == Beat.CLEAR_LANDING:
		hud.set_prompt("Rogue Munchkins sneak closer — F kick when they commit")
	elif beat == Beat.FREE_SCARECROW:
		hud.set_prompt("Square clear — SCARECROW posts, E free")

func _free_scarecrow() -> void:
	if scarecrow == null or scarecrow.freed:
		return
	if scarecrow.has_method("free_from_pole"):
		scarecrow.free_from_pole()
	if pole:
		pole.queue_free()
		pole = null
	_auto_lead(Party.ID_SCARECROW)
	hud.set_prompt("You are Scarecrow now. F = CAW · Tab cycles Lead")
	_set_beat(Beat.CROW_FIELD)

func _calm_lion() -> void:
	if lion and lion.has_method("calm_and_join"):
		lion.calm_and_join()
	_auto_lead(Party.ID_LION)
	hud.set_prompt("You are the Lion now. F = ROAR · Tab cycles Lead")
	_set_beat(Beat.LION_PACK)

func _take_oil() -> void:
	has_oil = true
	if oil_can:
		oil_can.visible = false
		oil_can.monitoring = false
	hud.set_objective("Oil can in hand — oil the Tin Man (E).")
	hud.set_prompt("Oil can taken.")
	_refresh_roster()

func _free_tinman() -> void:
	if tinman and tinman.has_method("oil_and_free"):
		tinman.oil_and_free()
	_auto_lead(Party.ID_TINMAN)
	hud.set_prompt("You are the Tin Man now. F = AXE · Tab cycles Lead")
	_set_beat(Beat.TREE_GATE)

func _on_leader_changed(id: StringName, _body: Node3D) -> void:
	match id:
		Party.ID_DOROTHY:
			hud.set_prompt("Dorothy leads. Party follows her. F = KICK · Space blink.")
		Party.ID_SCARECROW:
			hud.set_prompt("Scarecrow Leads. Whole party follows. F = CAW.")
		Party.ID_LION:
			hud.set_prompt("Lion Leads. Whole party follows. F = ROAR.")
		Party.ID_TINMAN:
			hud.set_prompt("Tin Man Leads. Whole party follows. F = AXE.")
		_:
			hud.set_prompt("")
	_refresh_roster()

func _on_swap_failed(reason: String) -> void:
	hud.set_prompt(reason)

func _refresh_roster() -> void:
	if hud and hud.has_method("set_party_roster") and Party:
		hud.set_party_roster(Party.roster_line())
	if beat == Beat.CLEAR_LANDING:
		hud.set_objective("Rogue Munchkins sneak in — kick them down (F). %d/%d" % [landing_kills, landing_need])
	elif beat == Beat.CROW_FIELD:
		hud.set_objective("Crow field: you Lead Scarecrow — F = CAW. %d/%d" % [crow_kills, crow_need])
	elif beat == Beat.LION_PACK:
		hud.set_objective("Lion pack: you Lead Lion — F = ROAR. %d/%d" % [lion_pack_kills, lion_pack_need])
