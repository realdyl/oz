extends Control

## Phase P7.2: Circular 5-Portrait Party Medallion Wheel (modeled directly on ref_03_gameplay_hud.jpg).
## Bottom-left smoked-velvet & antique-brass dial:
## - Center 68x68 burnished-gold ring displays the active Lead portrait + pulsing crown halo + [F] Kit Verb pill.
## - 4 orbiting 42x42 brass portrait medallions display the rest of the circle with [1]-[5] keycap pips.
## - Spring-elastic transition on Lead change + clickable medallions when cursor is unlocked.

const CircleShader := preload("res://ui/shaders/circle_medallion.gdshader")
const OzThemeFactory := preload("res://ui/theme/oz_theme_factory.gd")

const MEMBERS := [
	{"id": &"dorothy", "key": "1", "name": "Dorothy", "verb": "KICK", "portrait": "res://assets/art/portraits/dorothy.png"},
	{"id": &"scarecrow", "key": "2", "name": "Scarecrow", "verb": "CAW", "portrait": "res://assets/art/portraits/scarecrow.png"},
	{"id": &"tinman", "key": "3", "name": "Tin Man", "verb": "AXE", "portrait": "res://assets/art/portraits/tinman.png"},
	{"id": &"lion", "key": "4", "name": "Lion", "verb": "ROAR", "portrait": "res://assets/art/portraits/lion.png"},
	{"id": &"toto", "key": "5", "name": "Toto", "verb": "BARK", "portrait": "res://assets/art/portraits/toto.png"},
]

# Orbit angles (in degrees) matching ref_03_gameplay_hud.jpg's crescent around the center Lead ring
const ORBIT_ANGLES_DEG := [-148.0, -90.0, -32.0, 34.0]

var kansas_mode: bool = false
var current_lead: StringName = &"dorothy"
var _unlocked_count: int = 1
var _pulse_t: float = 0.0

var _center_holder: Control
var _center_tex: TextureRect
var _center_mat: ShaderMaterial
var _lead_name_lbl: Label
var _verb_pill: PanelContainer
var _verb_lbl: Label

var _orbit_nodes: Array[Dictionary] = [] # {holder, tex, mat, key_lbl, id}
var _tex_cache: Dictionary = {}
var _pop_tween: Tween = null

func _is_headless() -> bool:
	var n := DisplayServer.get_name()
	return n == "headless" or n == "Dummy"

func _ready() -> void:
	custom_minimum_size = Vector2(248, 178)
	size = Vector2(248, 178)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_wheel()
	refresh_from_party()

func _load_tex(res_path: String) -> Texture2D:
	if _tex_cache.has(res_path):
		return _tex_cache[res_path]
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		tex = ResourceLoader.load(res_path) as Texture2D
	if tex == null:
		var abs_p := ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_p):
			var img := Image.load_from_file(abs_p)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	_tex_cache[res_path] = tex
	return tex

func _make_medallion_mat(active: bool) -> ShaderMaterial:
	if _is_headless():
		return null
	var sm := ShaderMaterial.new()
	sm.shader = CircleShader
	sm.set_shader_parameter("is_active", 1.0 if active else 0.0)
	sm.set_shader_parameter("is_locked", 0.0)
	sm.set_shader_parameter("greyscale", 1.0 if kansas_mode else 0.0)
	sm.set_shader_parameter("rim_color", Color(0.95, 0.82, 0.48, 1.0) if active else Color(0.769, 0.620, 0.353, 0.95))
	return sm

func _build_wheel() -> void:
	var dial_center := Vector2(88.0, 102.0)

	# 4 Orbiting Companion Medallions
	for i in range(4):
		var holder := Control.new()
		holder.size = Vector2(44, 44)
		holder.pivot_offset = Vector2(22, 22)
		holder.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(holder)

		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := _make_medallion_mat(false)
		if mat:
			tr.material = mat
		holder.add_child(tr)

		# Small brass keycap pip on bottom-right rim of each orbiting medallion
		var badge := PanelContainer.new()
		badge.position = Vector2(28, 27)
		badge.custom_minimum_size = Vector2(16, 16)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bst := StyleBoxFlat.new()
		bst.bg_color = Color(0.11, 0.06, 0.14, 0.96)
		bst.border_color = Color(0.84, 0.69, 0.38, 0.95)
		bst.set_border_width_all(1)
		bst.set_corner_radius_all(8)
		bst.content_margin_left = 3
		bst.content_margin_right = 3
		bst.content_margin_top = 0
		bst.content_margin_bottom = 0
		badge.add_theme_stylebox_override("panel", bst)
		holder.add_child(badge)

		var klbl := Label.new()
		klbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		klbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		klbl.add_theme_font_size_override("font_size", 10)
		klbl.add_theme_color_override("font_color", Color(0.95, 0.84, 0.52))
		klbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(klbl)

		var slot_idx := i
		holder.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_orbit_clicked(slot_idx)
		)

		var ang := deg_to_rad(ORBIT_ANGLES_DEG[i])
		var pos := dial_center + Vector2(cos(ang), sin(ang)) * 58.0 - Vector2(22, 22)
		holder.position = pos
		_orbit_nodes.append({"holder": holder, "tex": tr, "mat": mat, "key_lbl": klbl, "id": &"scarecrow"})

	# Center Active Lead Medallion (70x70)
	_center_holder = Control.new()
	_center_holder.size = Vector2(70, 70)
	_center_holder.pivot_offset = Vector2(35, 35)
	_center_holder.position = dial_center - Vector2(35, 35)
	_center_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center_holder)

	_center_tex = TextureRect.new()
	_center_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_center_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_center_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_mat = _make_medallion_mat(true)
	if _center_mat:
		_center_tex.material = _center_mat
	_center_holder.add_child(_center_tex)

	# Lead Name + [F] Kit Verb Plaque extending cleanly to the right of the lower dial
	var info_vb := VBoxContainer.new()
	info_vb.position = Vector2(154, 108)
	info_vb.add_theme_constant_override("separation", 3)
	info_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info_vb)

	_lead_name_lbl = Label.new()
	_lead_name_lbl.text = "DOROTHY"
	_lead_name_lbl.add_theme_font_size_override("font_size", 11)
	_lead_name_lbl.add_theme_color_override("font_color", Color(0.94, 0.84, 0.56))
	_lead_name_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.05, 0.92))
	_lead_name_lbl.add_theme_constant_override("outline_size", 3)
	_lead_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vb.add_child(_lead_name_lbl)

	_verb_pill = PanelContainer.new()
	_verb_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_verb_pill.add_theme_stylebox_override("panel", OzThemeFactory.make_pill_style(false, 10, 4))
	info_vb.add_child(_verb_pill)

	var vh := HBoxContainer.new()
	vh.add_theme_constant_override("separation", 6)
	vh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_verb_pill.add_child(vh)

	var f_cap := PanelContainer.new()
	f_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f_cap.add_theme_stylebox_override("panel", OzThemeFactory.make_keycap_style(false))
	vh.add_child(f_cap)
	var f_lbl := Label.new()
	f_lbl.text = "F"
	f_lbl.add_theme_font_size_override("font_size", 11)
	f_lbl.add_theme_color_override("font_color", OzThemeFactory.ink_color(false))
	f_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f_cap.add_child(f_lbl)

	_verb_lbl = Label.new()
	_verb_lbl.text = "KICK"
	_verb_lbl.add_theme_font_size_override("font_size", 12)
	_verb_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.48))
	_verb_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vh.add_child(_verb_lbl)

func _on_orbit_clicked(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _orbit_nodes.size():
		return
	var target_id: StringName = _orbit_nodes[slot_idx]["id"]
	var party := get_node_or_null("/root/Party")
	if party and party.has_method("set_leader"):
		party.call("set_leader", target_id)

func set_kansas(on: bool) -> void:
	kansas_mode = on
	if _center_mat:
		_center_mat.set_shader_parameter("greyscale", 1.0 if on else 0.0)
	for ob in _orbit_nodes:
		var m: ShaderMaterial = ob["mat"]
		if m:
			m.set_shader_parameter("greyscale", 1.0 if on else 0.0)
	queue_redraw()

func refresh_from_party() -> void:
	var party := get_node_or_null("/root/Party")
	var new_lead := &"dorothy"
	if party and party.has_method("leader_id"):
		new_lead = party.leader_id()
	var lead_switched := (new_lead != current_lead)
	current_lead = new_lead

	var lead_def: Dictionary = MEMBERS[0]
	var others: Array[Dictionary] = []
	var unlocked_n := 0

	for raw_def in MEMBERS:
		var def: Dictionary = raw_def
		var cid: StringName = def["id"]
		var is_unl := (cid == &"dorothy" or cid == &"toto")
		var is_pres := true
		if party:
			if cid != &"toto" and party.has_method("is_unlocked"):
				is_unl = party.is_unlocked(cid)
			if cid != &"toto" and party.has_method("is_present"):
				is_pres = party.is_present(cid)
		if is_unl and is_pres:
			unlocked_n += 1
		if cid == current_lead:
			lead_def = def
		else:
			var copy_def: Dictionary = def.duplicate()
			copy_def["locked"] = (not is_unl or not is_pres)
			others.append(copy_def)

	_unlocked_count = clampi(unlocked_n, 1, 5)
	if _center_tex:
		_center_tex.texture = _load_tex(str(lead_def["portrait"]))
	if _lead_name_lbl:
		_lead_name_lbl.text = "%s · LEAD" % str(lead_def["name"]).to_upper()
	if _verb_lbl:
		_verb_lbl.text = str(lead_def["verb"])

	for i in range(mini(4, others.size())):
		var od: Dictionary = others[i]
		var slot: Dictionary = _orbit_nodes[i]
		slot["id"] = od["id"]
		var tr: TextureRect = slot["tex"]
		tr.texture = _load_tex(str(od["portrait"]))
		var locked: bool = bool(od.get("locked", false))
		tr.modulate = Color(1, 1, 1, 1.0) if not locked else Color(0.55, 0.50, 0.60, 0.78)
		var m: ShaderMaterial = slot["mat"]
		if m:
			m.set_shader_parameter("is_locked", 1.0 if locked else 0.0)
		var kl: Label = slot["key_lbl"]
		kl.text = str(od["key"])
		kl.modulate.a = 0.45 if locked else 1.0

	if lead_switched and _center_holder and not _is_headless():
		if _pop_tween and _pop_tween.is_valid():
			_pop_tween.kill()
		_center_holder.scale = Vector2(0.82, 0.82)
		_pop_tween = create_tween()
		_pop_tween.tween_property(_center_holder, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	queue_redraw()

func _process(delta: float) -> void:
	if not visible or _is_headless():
		return
	_pulse_t += delta
	queue_redraw()

func _draw() -> void:
	var c := Vector2(88.0, 102.0)
	var brass := Color(0.769, 0.620, 0.353, 0.90)
	var gold_hi := Color(0.95, 0.82, 0.48, 0.95)
	var glass := Color(0.075, 0.042, 0.095, 0.90)

	# Smoked-velvet circular dial plate + double antique-brass filigree rings (ref_03_gameplay_hud.jpg)
	draw_circle(c + Vector2(0, 3), 62.0, Color(0, 0, 0, 0.48))
	draw_circle(c, 60.0, glass)
	draw_arc(c, 60.0, 0.0, TAU, 48, brass, 2.0, true)
	draw_arc(c, 55.0, 0.0, TAU, 48, Color(brass.r, brass.g, brass.b, 0.38), 1.0, true)

	# Golden tether spokes linking center Lead to each orbiting companion slot
	for deg in ORBIT_ANGLES_DEG:
		var a := deg_to_rad(deg)
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * 35.0, c + dir * 56.0, Color(brass.r, brass.g, brass.b, 0.45), 1.4, true)

	# Pulsing burnished-gold aura around the center Lead portrait
	var pulse := 0.55 + 0.35 * sin(_pulse_t * 3.2)
	draw_arc(c, 37.5, 0.0, TAU, 40, Color(gold_hi.r, gold_hi.g, gold_hi.b, pulse), 2.2, true)

	# 4 small bond-circle pips along bottom-left arc of the dial (ref_03_gameplay_hud.jpg)
	for i in range(4):
		var px := c.x - 18.0 + float(i) * 12.0
		var py := c.y + 47.0
		var lit := (i < _unlocked_count - 1)
		draw_circle(Vector2(px, py), 3.6, gold_hi if lit else Color(0.18, 0.12, 0.22, 0.9))
		draw_arc(Vector2(px, py), 3.8, 0.0, TAU, 12, brass, 1.0, true)
