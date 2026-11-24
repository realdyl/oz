extends StaticBody3D

## Haunted Living Oak — solid gnarled dark-fairytale tree blocking the Yellow Brick Road.
## Soft: kick stagger. Hard: Tin Man's axe shatters its armored bark!

@export var health: int = 40
@export var armored: bool = true

var alive: bool = true
var visual: Node3D
var body_mat: StandardMaterial3D
var _throw_arm: Node3D = null
var _pod_cd: float = 2.6

func _physics_process(delta: float) -> void:
	if not alive:
		return
	# Baum-canon Fighting Tree (Ch. 19): periodically whips branches & hurls thorny seed-pods at nearby travelers!
	_pod_cd -= delta
	if _pod_cd <= 0.0:
		_pod_cd = randf_range(2.8, 4.2)
		var p := get_node_or_null("/root/Party")
		var lead: Node3D = p.call("leader_body") as Node3D if (p and p.has_method("leader_body")) else null
		if lead and lead.global_position.distance_to(global_position) < 16.0:
			_throw_seed_pod(lead.global_position)

func _throw_seed_pod(target_pos: Vector3) -> void:
	var pod := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.42
	pod.mesh = sph
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.45, 0.24, 0.12)
	pm.emission_enabled = true
	pm.emission = Color(0.75, 0.35, 0.12)
	pm.emission_energy_multiplier = 0.7
	pod.material_override = pm
	get_parent().add_child(pod)
	var start_p := _throw_arm.global_position + Vector3(0, 0.6, 0) if _throw_arm else (global_position + Vector3(0, 3.1, 0))
	pod.global_position = start_p
	# Articulated tree arm visibly winds back and flings the seed-pod!
	if _throw_arm:
		var atw := create_tween()
		atw.tween_property(_throw_arm, "rotation_degrees:x", -48.0, 0.14).set_ease(Tween.EASE_OUT)
		atw.tween_property(_throw_arm, "rotation_degrees:x", 52.0, 0.16).set_ease(Tween.EASE_IN)
		atw.tween_property(_throw_arm, "rotation_degrees:x", 0.0, 0.25)
	elif visual:
		var sway := create_tween()
		sway.tween_property(visual, "rotation_degrees:z", 12.0, 0.14)
		sway.tween_property(visual, "rotation_degrees:z", 0.0, 0.24)
	var tw := create_tween()
	tw.tween_property(pod, "global_position", target_pos + Vector3(0, 0.4, 0), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		CombatFx.flash_sphere(self, target_pos + Vector3(0, 0.4, 0), Color(0.65, 0.35, 0.15), 0.55, 0.18)
		pod.queue_free()
	)

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

	# Articulated throwing tree-arm boughs on left & right shoulders!
	for sx in [-1.0, 1.0]:
		var arm_piv := Node3D.new()
		arm_piv.position = Vector3(float(sx) * 0.55, 2.35, 0.0)
		visual.add_child(arm_piv)
		var arm_m := MeshInstance3D.new()
		var ac := CylinderMesh.new()
		ac.top_radius = 0.09
		ac.bottom_radius = 0.18
		ac.height = 1.65
		arm_m.mesh = ac
		arm_m.material_override = body_mat
		arm_m.position = Vector3(float(sx) * 0.45, 0.35, 0.25)
		arm_m.rotation_degrees = Vector3(24, 0, -float(sx) * 58)
		arm_piv.add_child(arm_m)
		if sx > 0:
			_throw_arm = arm_piv
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
	# Switch to solid world-only layer 1 with a horizontal fallen-log collider so characters walk AROUND the fallen trunk!
	collision_layer = 1
	set_physics_process(false)
	add_to_group("enemies_dead")
	for c in get_children():
		if c is CollisionShape3D:
			var cs := c as CollisionShape3D
			cs.rotation_degrees = Vector3(0, 0, 86.0)
			cs.position = Vector3(-1.45, 0.52, 0.0)
	var tw := create_tween()
	tw.tween_property(visual, "rotation:z", deg_to_rad(86.0), 0.65).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(visual, "position:y", 0.48, 0.65)
	var land := get_tree().current_scene
	if land and land.has_method("on_enemy_down"):
		land.on_enemy_down(self)
