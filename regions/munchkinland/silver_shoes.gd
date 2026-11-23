extends Node3D

## The Witch of the East's Silver Shoes, resting in front of the fallen house.
## Sculpted high-heeled silver stilettos with hovering sparkle halo & pickup vortex spectacle.

signal claimed
signal prompt_changed(text: String)

var player_near: bool = false
var taken: bool = false
var _t: float = 0.0
var _display: Node3D

func _ready() -> void:
	$Area3D.body_entered.connect(_on_body_entered)
	$Area3D.body_exited.connect(_on_body_exited)
	_build_stilettos()

func _build_stilettos() -> void:
	# Hide crude prototype blocks if present
	for c in get_children():
		if c is MeshInstance3D:
			c.visible = false

	_display = Node3D.new()
	_display.name = "SilverStilettosDisplay"
	add_child(_display)

	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color(0.92, 0.95, 1.0)
	silver.metallic = 0.96
	silver.roughness = 0.12
	silver.emission_enabled = true
	silver.emission = Color(0.75, 0.85, 1.0)
	silver.emission_energy_multiplier = 0.85

	var halo_m := StandardMaterial3D.new()
	halo_m.albedo_color = Color(0.82, 0.92, 1.0, 0.55)
	halo_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_m.emission_enabled = true
	halo_m.emission = Color(0.8, 0.9, 1.0)
	halo_m.emission_energy_multiplier = 1.6

	# Pair of sculpted high-heeled silver stilettos angled invitingly
	for sx in [-0.22, 0.22]:
		var s: float = float(sx)
		var sh := Node3D.new()
		sh.position = Vector3(s, 0.32, 0)
		sh.rotation_degrees = Vector3(0, -14.0 if s < 0 else 18.0, 0)
		_display.add_child(sh)
		var vamp := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.11
		sp.height = 0.14
		vamp.mesh = sp
		vamp.scale = Vector3(0.9, 0.65, 1.85)
		vamp.position = Vector3(0, 0.0, -0.08)
		vamp.rotation_degrees = Vector3(14, 0, 0)
		vamp.material_override = silver
		sh.add_child(vamp)
		var spike := MeshInstance3D.new()
		var hc := CylinderMesh.new()
		hc.top_radius = 0.03
		hc.bottom_radius = 0.016
		hc.height = 0.22
		spike.mesh = hc
		spike.position = Vector3(0, -0.02, 0.11)
		spike.material_override = silver
		sh.add_child(spike)

	# Glowing silver rune ring on the ground
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.58
	tor.outer_radius = 0.68
	ring.mesh = tor
	ring.material_override = halo_m
	ring.position = Vector3(0, 0.06, 0)
	ring.rotation_degrees.x = 90.0
	add_child(ring)

func _process(delta: float) -> void:
	if taken or _display == null:
		return
	_t += delta
	_display.position.y = sin(_t * 2.6) * 0.08
	_display.rotation.y = _t * 0.85

func _unhandled_input(event: InputEvent) -> void:
	if taken or not player_near:
		return
	if event.is_action_pressed("interact"):
		take()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node) -> void:
	if taken:
		return
	if not (body.is_in_group("player") or body.is_in_group("party")):
		return
	player_near = true
	prompt_changed.emit("E  —  Claim the Silver Shoes")

func _on_body_exited(body: Node) -> void:
	if not (body.is_in_group("player") or body.is_in_group("party")):
		return
	player_near = false
	if not taken:
		prompt_changed.emit("")

func take() -> void:
	if taken:
		return
	taken = true
	player_near = false
	prompt_changed.emit("")
	claimed.emit()
	# Swirling starlight pickup spectacle (three silver heel-click shockwaves)
	var fx := get_node_or_null("/root/CombatFx")
	if fx:
		if fx.has_method("ring"):
			fx.call("ring", self, global_position, Color(0.88, 0.94, 1.0), 1.8, 0.45)
			fx.call("ring", self, global_position + Vector3(0, 0.5, 0), Color(0.95, 0.98, 1.0), 2.8, 0.65)
		if fx.has_method("flash_sphere"):
			fx.call("flash_sphere", self, global_position + Vector3(0, 0.6, 0), Color(0.92, 0.96, 1.0), 0.9, 0.35)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 1.6, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation:y", rotation.y + TAU * 1.5, 0.65)
	tween.tween_property(self, "scale", Vector3(0.12, 0.12, 0.12), 0.65)
	await tween.finished
	visible = false
