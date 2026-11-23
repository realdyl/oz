extends StaticBody3D

## Haunted Living Oak — solid gnarled dark-fairytale tree blocking the Yellow Brick Road.
## Soft: kick stagger. Hard: Tin Man's axe shatters its armored bark!

@export var health: int = 40
@export var armored: bool = true

var alive: bool = true
var visual: Node3D
var body_mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("living_tree")
	# Layer 1 (solid world blocker so rogues NEVER walk inside trunk!) + Layer 4 (enemy hit-layer)
	collision_layer = 1 | 4
	collision_mask = 0
	_build()

func _build() -> void:
	visual = Node3D.new()
	add_child(visual)
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.22, 0.16, 0.12)
	body_mat.roughness = 0.94
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.14, 0.38, 0.20)
	leaf_mat.roughness = 0.88
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.65, 0.16)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.55, 0.10)
	eye_mat.emission_energy_multiplier = 2.4

	# Gnarled flared trunk + 5 splayed buttress roots
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.72
	cyl.height = 3.4
	cyl.radial_segments = 10
	trunk.mesh = cyl
	trunk.material_override = body_mat
	trunk.position = Vector3(0, 1.7, 0)
	visual.add_child(trunk)
	for ri in range(5):
		var a := float(ri) / 5.0 * TAU
		var root_m := MeshInstance3D.new()
		var rc := CylinderMesh.new()
		rc.top_radius = 0.12
		rc.bottom_radius = 0.24
		rc.height = 1.25
		root_m.mesh = rc
		root_m.material_override = body_mat
		root_m.position = Vector3(cos(a) * 0.68, 0.32, sin(a) * 0.68)
		root_m.rotation_degrees = Vector3(sin(a) * 48.0, 0, -cos(a) * 48.0)
		visual.add_child(root_m)
	# Crooked reaching boughs & multi-cluster haunted canopy
	for bi in range(4):
		var a := float(bi) / 4.0 * TAU + 0.4
		var bough := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = 0.08
		bc.bottom_radius = 0.20
		bc.height = 1.85
		bough.mesh = bc
		bough.material_override = body_mat
		bough.position = Vector3(cos(a) * 0.85, 2.95, sin(a) * 0.85)
		bough.rotation_degrees = Vector3(sin(a) * 52.0, 0, -cos(a) * 52.0)
		visual.add_child(bough)
		var leaf := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 1.05
		sph.height = 1.65
		leaf.mesh = sph
		leaf.material_override = leaf_mat
		leaf.position = Vector3(cos(a) * 1.25, 3.65, sin(a) * 1.25)
		visual.add_child(leaf)
	var crown := MeshInstance3D.new()
	var csph := SphereMesh.new()
	csph.radius = 1.35
	csph.height = 2.0
	crown.mesh = csph
	crown.material_override = leaf_mat
	crown.position = Vector3(0, 4.15, 0)
	visual.add_child(crown)
	# Glowing amber haunted eyes facing both -Z and +Z
	for fz in [-0.52, 0.52]:
		for sx in [-0.18, 0.18]:
			var eye := MeshInstance3D.new()
			var es := SphereMesh.new()
			es.radius = 0.075
			es.height = 0.11
			eye.mesh = es
			eye.material_override = eye_mat
			eye.position = Vector3(float(sx), 2.15, float(fz))
			visual.add_child(eye)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.85
	shape.height = 3.5
	col.shape = shape
	col.position = Vector3(0, 1.75, 0)
	add_child(col)

func take_damage(amount: int, _source_position: Vector3, tags: Dictionary = {}) -> void:
	if not alive:
		return
	var dmg := amount
	if armored and not bool(tags.get("armor_break", false)):
		dmg = maxi(1, int(amount * 0.25))
		CombatFx.label(self, global_position, "THUNK", Color(0.6, 0.7, 0.5))
	else:
		if bool(tags.get("armor_break", false)):
			armored = false
			CombatFx.label(self, global_position, "CHOP", Color(0.9, 0.7, 0.3))
	health -= dmg
	CombatFx.flash_sphere(self, global_position + Vector3(0, 1.5, 0), Color(0.4, 0.7, 0.3), 0.5, 0.15)
	visual.rotate_y(0.15)
	if health <= 0:
		_die()

func _die() -> void:
	alive = false
	collision_layer = 0
	add_to_group("enemies_dead")
	var tw := create_tween()
	tw.tween_property(visual, "rotation:z", 1.2, 0.5)
	tw.parallel().tween_property(visual, "position:y", -0.5, 0.5)
	tw.tween_callback(queue_free)
	var land := get_tree().current_scene
	if land and land.has_method("on_enemy_down"):
		land.on_enemy_down(self)
