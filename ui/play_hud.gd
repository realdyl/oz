extends CanvasLayer

@onready var objective: Label = $Paper/Objective
@onready var prompt: Label = $Prompt
@onready var controls: Label = $Controls
@onready var paper: ColorRect = $Paper

var kansas_mode: bool = false
var roster_label: Label
## Sticky live threat compass — nearest live munchkin / rogue (always on-screen in Oz).
var threat_compass: Label

func _ready() -> void:
	add_to_group("hud")
	_style(objective, 22)
	_style(prompt, 22)
	_style(controls, 15)
	set_prompt("")
	roster_label = get_node_or_null("Roster") as Label
	if roster_label == null:
		roster_label = Label.new()
		roster_label.name = "Roster"
		roster_label.position = Vector2(16, 64)
		add_child(roster_label)
	_style(roster_label, 14)
	roster_label.visible = false
	_ensure_threat_compass()
	if not has_node("Fade"):
		var fade := ColorRect.new()
		fade.name = "Fade"
		fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.color = Color(0, 0, 0, 0)
		fade.z_index = 20
		add_child(fade)

func _ensure_threat_compass() -> void:
	threat_compass = get_node_or_null("ThreatCompass") as Label
	if threat_compass == null:
		threat_compass = Label.new()
		threat_compass.name = "ThreatCompass"
		add_child(threat_compass)
	# Top-center sticky strip — always readable while fighting.
	threat_compass.set_anchors_preset(Control.PRESET_TOP_WIDE)
	threat_compass.offset_top = 8.0
	threat_compass.offset_bottom = 44.0
	threat_compass.offset_left = 120.0
	threat_compass.offset_right = -120.0
	threat_compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	threat_compass.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	threat_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	threat_compass.z_index = 5
	threat_compass.add_theme_font_size_override("font_size", 22)
	threat_compass.add_theme_color_override("font_color", Color(0.55, 0.08, 0.18))
	threat_compass.add_theme_color_override("font_shadow_color", Color(1.0, 0.95, 0.9, 0.95))
	threat_compass.add_theme_constant_override("shadow_offset_x", 1)
	threat_compass.add_theme_constant_override("shadow_offset_y", 1)
	threat_compass.visible = not kansas_mode
	threat_compass.text = ""

func set_kansas_mode(on: bool) -> void:
	kansas_mode = on
	if roster_label:
		roster_label.visible = not on
	if threat_compass:
		threat_compass.visible = not on
		if on:
			threat_compass.text = ""
	if on:
		paper.color = Color(0.12, 0.12, 0.14, 0.88)
		objective.add_theme_color_override("font_color", Color(0.92, 0.92, 0.94))
		objective.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		prompt.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
		controls.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))

func set_party_roster(text: String) -> void:
	if roster_label:
		roster_label.text = text
		roster_label.visible = not kansas_mode and text != ""

func _process(_delta: float) -> void:
	_update_threat_compass()
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("wants_look_hint") and player.wants_look_hint():
		controls.text = "Click to look (360°). Esc releases. RMB+WASD orbit."
		return
	if kansas_mode:
		controls.text = "Arrows/WASD move · Mouse 360° · RMB+WASD orbit · Z/C · E take · F9 → Munchkinland"
		return
	var lead := "Dorothy"
	if Party:
		match Party.leader_id():
			Party.ID_SCARECROW:
				lead = "Scarecrow"
			Party.ID_TINMAN:
				lead = "Tin Man"
			Party.ID_LION:
				lead = "Lion"
	controls.text = "Arrows move · Mouse look · Space blink · F act · E interact · Tab cycle Lead · 1–4 pick · Lead: %s" % lead

func _update_threat_compass() -> void:
	if threat_compass == null or kansas_mode:
		return
	var actor: Node3D = null
	if Party and Party.has_method("leader_body"):
		actor = Party.leader_body() as Node3D
	if actor == null:
		actor = get_tree().get_first_node_in_group("player") as Node3D
	if actor == null:
		threat_compass.text = ""
		return
	var best: Node3D = null
	var best_d := 1.0e9
	var live := 0
	for n in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(n) or not (n is Node3D):
			continue
		if n.is_in_group("enemies_dead"):
			continue
		var st = n.get("state")
		# puppet_munchkin.State.DEAD == last enum; also health gate.
		if st != null and int(st) == 8:
			continue
		var hp = n.get("health")
		if hp != null and int(hp) <= 0:
			continue
		live += 1
		var d: float = actor.global_position.distance_to((n as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = n as Node3D
	if best == null or live <= 0:
		threat_compass.text = ""
		return
	var to: Vector3 = best.global_position - actor.global_position
	to.y = 0.0
	var dist := to.length()
	var forward := Vector3(0, 0, -1)
	var basis_node: Node3D = null
	if Party and Party.has_method("camera_basis_node"):
		basis_node = Party.camera_basis_node()
	if basis_node == null and actor.has_node("CameraPivot"):
		basis_node = actor.get_node_or_null("CameraPivot") as Node3D
	if basis_node:
		forward = -basis_node.global_transform.basis.z
		forward.y = 0.0
		if forward.length() > 0.01:
			forward = forward.normalized()
		else:
			forward = Vector3(0, 0, -1)
	var right := Vector3.UP.cross(forward)
	if right.length() < 0.01:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var local := Vector2(to.dot(right), to.dot(forward))
	var ang := rad_to_deg(atan2(local.x, local.y))
	var arrow := _threat_arrow(ang)
	var dir := "ahead"
	if ang > 30.0 and ang < 150.0:
		dir = "right"
	elif ang < -30.0 and ang > -150.0:
		dir = "left"
	elif absf(ang) >= 150.0:
		dir = "behind"
	var kind := "rogue"
	var marshal_v = best.get("is_marshal")
	if marshal_v == true:
		kind = "Marshal"
	elif best.has_meta("wave"):
		kind = str(best.get_meta("wave")).replace("_", " ")
	threat_compass.text = "%s  nearest %s  ·  %s  ·  %.0fm   (%d live)" % [arrow, kind, dir, dist, live]

func _threat_arrow(ang_deg: float) -> String:
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

func set_objective(text: String) -> void:
	objective.text = text

func set_prompt(text: String) -> void:
	prompt.text = text
	prompt.visible = text != ""

func _style(label: Label, size: int) -> void:
	label.add_theme_color_override("font_color", Color(0.18, 0.07, 0.14))
	label.add_theme_color_override("font_shadow_color", Color(1, 0.96, 0.9, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_font_size_override("font_size", size)
