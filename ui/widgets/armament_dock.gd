extends Control

## Phase P7.2: Bottom-Right Circular Brass Armament Medallion Dock (ref_03_gameplay_hud.jpg).
## Displays all 4 Tools of Allure (Lace Whip, Silk Bindings, Hypnotic Perfume, Gilded Chain)
## as circular brass-framed painted icons with spring selection pop, live radial cooldown wipe,
## [Z/X] cycle hint, and pulsing [H] RAPTURE READY indicator.

const CircleShader := preload("res://ui/shaders/circle_medallion.gdshader")
const OzThemeFactory := preload("res://ui/theme/oz_theme_factory.gd")

const SLOTS := [
	{"idx": 0, "num": "1", "name": "Lace Whip", "icon": "res://assets/art/icons/arm_whip.png"},
	{"idx": 1, "num": "2", "name": "Silk Bindings", "icon": "res://assets/art/icons/arm_ribbon.png"},
	{"idx": 2, "num": "3", "name": "Hypnotic Perfume", "icon": "res://assets/art/icons/arm_atomizer.png"},
	{"idx": 3, "num": "4", "name": "Gilded Chain", "icon": "res://assets/art/icons/arm_chain.png"},
]

var active_idx: int = 0
var rapture_ready: bool = false
var rapture_active: bool = false
var _slots_ui: Array[Dictionary] = []
var _active_name_lbl: Label
var _rapture_badge: PanelContainer
var _rapture_lbl: Label
var _tex_cache: Dictionary = {}
var _pulse_t: float = 0.0

func _is_headless() -> bool:
	var n := DisplayServer.get_name()
	return n == "headless" or n == "Dummy"

func _ready() -> void:
	custom_minimum_size = Vector2(246, 98)
	size = Vector2(246, 98)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_dock()
	set_active_slot(0)

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

func _build_dock() -> void:
	var root_vb := VBoxContainer.new()
	root_vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vb.alignment = BoxContainer.ALIGNMENT_END
	root_vb.add_theme_constant_override("separation", 5)
	root_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_vb)

	# Top row: Pulsing [H] RAPTURE badge + Active Armament label
	var top_hb := HBoxContainer.new()
	top_hb.alignment = BoxContainer.ALIGNMENT_END
	top_hb.add_theme_constant_override("separation", 8)
	top_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_vb.add_child(top_hb)

	_rapture_badge = PanelContainer.new()
	_rapture_badge.visible = false
	_rapture_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rst := StyleBoxFlat.new()
	rst.bg_color = Color(0.32, 0.05, 0.14, 0.94)
	rst.border_color = Color(0.96, 0.36, 0.56, 0.98)
	rst.set_border_width_all(1)
	rst.set_corner_radius_all(99)
	rst.content_margin_left = 9
	rst.content_margin_right = 9
	rst.content_margin_top = 2
	rst.content_margin_bottom = 2
	_rapture_badge.add_theme_stylebox_override("panel", rst)
	top_hb.add_child(_rapture_badge)

	_rapture_lbl = Label.new()
	_rapture_lbl.text = "✦ [H] RAPTURE"
	_rapture_lbl.add_theme_font_size_override("font_size", 10)
	_rapture_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.86))
	_rapture_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rapture_badge.add_child(_rapture_lbl)

	_active_name_lbl = Label.new()
	_active_name_lbl.text = "[C] LACE WHIP  ·  [Z/X]"
	_active_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_active_name_lbl.add_theme_font_size_override("font_size", 11)
	_active_name_lbl.add_theme_color_override("font_color", Color(0.937, 0.878, 0.761))
	_active_name_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.05, 0.92))
	_active_name_lbl.add_theme_constant_override("outline_size", 3)
	_active_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hb.add_child(_active_name_lbl)

	# Bottom row: 4 Circular Brass Medallion Slots (ref_03_gameplay_hud.jpg)
	var medallions_hb := HBoxContainer.new()
	medallions_hb.alignment = BoxContainer.ALIGNMENT_END
	medallions_hb.add_theme_constant_override("separation", 10)
	medallions_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_vb.add_child(medallions_hb)

	for s in SLOTS:
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		medallions_hb.add_child(col)

		var holder := Control.new()
		holder.custom_minimum_size = Vector2(46, 46)
		holder.pivot_offset = Vector2(23, 23)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(holder)

		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture = _load_tex(str(s["icon"]))
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat: ShaderMaterial = null
		if not _is_headless():
			mat = ShaderMaterial.new()
			mat.shader = CircleShader
			mat.set_shader_parameter("rim_color", Color(0.769, 0.620, 0.353, 0.95))
			tr.material = mat
		holder.add_child(tr)

		var num_lbl := Label.new()
		num_lbl.text = str(s["num"])
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.add_theme_font_size_override("font_size", 10)
		num_lbl.add_theme_color_override("font_color", Color(0.769, 0.620, 0.353))
		num_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.05, 0.92))
		num_lbl.add_theme_constant_override("outline_size", 3)
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(num_lbl)

		_slots_ui.append({"holder": holder, "tex": tr, "mat": mat, "num": num_lbl, "name": s["name"]})

func set_active_by_name(arm_name: String) -> void:
	var ln := arm_name.to_lower()
	var idx := 0
	if "silk" in ln or "ribbon" in ln or "bind" in ln:
		idx = 1
	elif "perfume" in ln or "atomizer" in ln or "mist" in ln:
		idx = 2
	elif "chain" in ln or "tether" in ln:
		idx = 3
	set_active_slot(idx)

func set_active_slot(idx: int) -> void:
	active_idx = clampi(idx, 0, SLOTS.size() - 1)
	if _active_name_lbl:
		_active_name_lbl.text = "[C] %s  ·  [Z/X]" % str(SLOTS[active_idx]["name"]).to_upper()
	for i in range(_slots_ui.size()):
		var ui: Dictionary = _slots_ui[i]
		var is_sel := (i == active_idx)
		var holder: Control = ui["holder"]
		var tr: TextureRect = ui["tex"]
		var num_lbl: Label = ui["num"]
		var mat: ShaderMaterial = ui["mat"]
		tr.modulate = Color(1, 1, 1, 1.0) if is_sel else Color(0.72, 0.68, 0.76, 0.88)
		num_lbl.text = "[C]" if is_sel else str(SLOTS[i]["num"])
		num_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.48) if is_sel else Color(0.72, 0.65, 0.58))
		if mat:
			mat.set_shader_parameter("is_active", 1.0 if is_sel else 0.0)
			mat.set_shader_parameter("rim_color", Color(0.96, 0.80, 0.44, 1.0) if is_sel else Color(0.68, 0.54, 0.32, 0.85))
		if not _is_headless():
			var target_sc := Vector2(1.14, 1.14) if is_sel else Vector2(0.94, 0.94)
			var tw := create_tween()
			tw.tween_property(holder, "scale", target_sc, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func update_live_state(cooldown_ratio: float, can_rapture: bool, is_rapture_on: bool) -> void:
	rapture_ready = can_rapture
	rapture_active = is_rapture_on
	if _rapture_badge:
		_rapture_badge.visible = can_rapture or is_rapture_on
		if _rapture_lbl:
			_rapture_lbl.text = "✦ RAPTURE ACTIVE!" if is_rapture_on else "✦ [H] RAPTURE READY"
	for i in range(_slots_ui.size()):
		var mat: ShaderMaterial = _slots_ui[i]["mat"]
		if mat:
			mat.set_shader_parameter("cooldown_ratio", cooldown_ratio if i == active_idx else 0.0)

func _process(delta: float) -> void:
	if not visible or _is_headless():
		return
	if _rapture_badge and _rapture_badge.visible:
		_pulse_t += delta * 5.0
		_rapture_badge.modulate.a = 0.78 + 0.22 * sin(_pulse_t)
