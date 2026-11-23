extends Area3D

## Authentic Kansas storm debris: tumbling wagon wheels, splintered fence rails,
## ripped wooden shutters, barn crates & corrugated tin sheets (replaces bare blocks).

signal soft_hit_player
signal final_hit_player

@export var is_final: bool = false
@export var speed: float = 8.5
@export var lifetime: float = 6.0

var _dir: Vector3 = Vector3(-1, 0, 0)
var _age: float = 0.0
var _armed: bool = true
var _spin: Vector3 = Vector3(2.8, 3.6, 2.1)
var _visual: Node3D = null

func launch(from: Vector3, toward: Vector3, final_piece: bool = false) -> void:
	global_position = from
	is_final = final_piece
	toward.y = from.y
	_dir = (toward - from)
	_dir.y = 0.0
	if _dir.length() < 0.01:
		_dir = Vector3(-1, 0, 0)
	else:
		_dir = _dir.normalized()
	look_at(global_position + _dir, Vector3.UP)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	collision_layer = 0
	collision_mask = 2
	_spin = Vector3(randf_range(-4.5, 4.5), randf_range(-5.0, 5.0), randf_range(-4.0, 4.0))
	_build_sculpted_debris()

func _build_sculpted_debris() -> void:
	# Hide bare prototype box mesh if present in debris.tscn
	for c in get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	_visual = Node3D.new()
	_visual.name = "SculptedDebris"
	add_child(_visual)
	var wood_dark := StandardMaterial3D.new()
	wood_dark.albedo_color = Color(0.24, 0.24, 0.26)
	wood_dark.roughness = 0.92
	var wood_light := StandardMaterial3D.new()
	wood_light.albedo_color = Color(0.44, 0.44, 0.47)
	wood_light.roughness = 0.88
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.18, 0.18, 0.21)
	iron.metallic = 0.72
	iron.roughness = 0.45
	var tin := StandardMaterial3D.new()
	tin.albedo_color = Color(0.58, 0.58, 0.62)
	tin.metallic = 0.65
	tin.roughness = 0.38

	var kind := randi() % 5
	match kind:
		0: # Wooden Wagon Wheel (rim + hub + 8 spokes)
			var rim := TorusMesh.new()
			rim.inner_radius = 0.48
			rim.outer_radius = 0.58
			_add_part(rim, wood_dark, Vector3.ZERO)
			var hub := CylinderMesh.new()
			hub.top_radius = 0.11
			hub.bottom_radius = 0.11
			hub.height = 0.22
			_add_part(hub, iron, Vector3.ZERO)
			for i in range(8):
				var sp := CylinderMesh.new()
				sp.top_radius = 0.025
				sp.bottom_radius = 0.025
				sp.height = 1.02
				var a := float(i) / 8.0 * PI
				_add_part(sp, wood_light, Vector3.ZERO, Vector3(0, rad_to_deg(a), 90))
		1: # Splintered Prairie Fence Section (2 posts + 2 rails + broken picket)
			for sx in [-0.55, 0.55]:
				var post := CylinderMesh.new()
				post.top_radius = 0.055
				post.bottom_radius = 0.068
				post.height = 1.15
				_add_part(post, wood_dark, Vector3(float(sx), 0, 0), Vector3(0, 0, randf_range(-8.0, 8.0)))
			for sy in [-0.24, 0.26]:
				var rail := BoxMesh.new()
				rail.size = Vector3(1.45, 0.10, 0.05)
				_add_part(rail, wood_light, Vector3(0, float(sy), 0.05), Vector3(0, 0, randf_range(-5.0, 5.0)))
		2: # Ripped Farmhouse Louvered Shutter
			var frame_l := BoxMesh.new()
			frame_l.size = Vector3(0.08, 1.25, 0.07)
			_add_part(frame_l, wood_dark, Vector3(-0.34, 0, 0))
			_add_part(frame_l, wood_dark, Vector3(0.34, 0, 0))
			for ly in range(7):
				var slat := BoxMesh.new()
				slat.size = Vector3(0.62, 0.10, 0.03)
				_add_part(slat, wood_light, Vector3(0, -0.48 + float(ly) * 0.16, 0), Vector3(26, 0, 0))
		3: # Wooden Farm Barrel (staves + iron hoops)
			var body := CylinderMesh.new()
			body.top_radius = 0.30
			body.bottom_radius = 0.34
			body.height = 0.82
			body.radial_segments = 12
			_add_part(body, wood_light, Vector3.ZERO)
			for hy in [-0.26, 0.0, 0.26]:
				var hoop := CylinderMesh.new()
				hoop.top_radius = 0.355
				hoop.bottom_radius = 0.355
				hoop.height = 0.05
				hoop.radial_segments = 12
				_add_part(hoop, iron, Vector3(0, float(hy), 0))
		_: # Bent Corrugated Tin Barn Roof Sheet
			for rx in range(5):
				var rib := BoxMesh.new()
				rib.size = Vector3(0.22, 0.04, 1.25)
				_add_part(rib, tin, Vector3(-0.44 + float(rx) * 0.22, sin(float(rx) * 1.1) * 0.08, 0), Vector3(0, 0, cos(float(rx)) * 18.0))

func _add_part(m: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	_visual.add_child(mi)

func _physics_process(delta: float) -> void:
	_age += delta
	global_position += _dir * speed * delta
	global_position.y += sin(_age * 7.5) * 0.025
	if _visual:
		_visual.rotation += _spin * delta
	if _age > lifetime:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if not _armed or not body.is_in_group("player"):
		return
	_armed = false
	if is_final:
		final_hit_player.emit()
	else:
		soft_hit_player.emit()
		if body.has_method("soft_hit"):
			body.soft_hit()
	if not is_final:
		queue_free()
