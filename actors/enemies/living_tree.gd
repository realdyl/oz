extends StaticBody3D

## Living Tree — vault ambusher/hazard. Soft: kick stagger. Hard: Tin axe chops.

@export var health: int = 40
@export var armored: bool = true

var alive: bool = true
var visual: Node3D
var body_mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("living_tree")
	collision_layer = 4
	collision_mask = 0
	_build()

func _build() -> void:
	visual = Node3D.new()
	add_child(visual)
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.28, 0.42, 0.22)
	body_mat.roughness = 0.9
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.55
	cyl.height = 3.2
	trunk.mesh = cyl
	trunk.material_override = body_mat
	trunk.position = Vector3(0, 1.6, 0)
	visual.add_child(trunk)
	var canopy := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.1
	canopy.mesh = sph
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.2, 0.5, 0.25)
	canopy.material_override = cm
	canopy.position = Vector3(0, 3.2, 0)
	visual.add_child(canopy)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.55
	shape.height = 3.2
	col.shape = shape
	col.position = Vector3(0, 1.6, 0)
	add_child(col)

func take_damage(amount: int, source_position: Vector3, tags: Dictionary = {}) -> void:
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
