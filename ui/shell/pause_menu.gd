extends CanvasLayer

const OzThemeFactory := preload("res://ui/theme/oz_theme_factory.gd")
const SettingsMenuScript := preload("res://ui/shell/settings_menu.gd")
const OrnateFrame := preload("res://ui/widgets/ornate_frame.gd")
const FrostedShader := preload("res://ui/shaders/frosted_velvet_backdrop.gdshader")

## Phase P11.2: 2026 Glossy Tactile Jewel Pause & Main Menu Shell.
## Features generous breathing room, distinct color-coded 3D-cushion beveled jewel buttons
## (Emerald Hero CTA, 2-column Amethyst Grimoire & Crimson Boutique tiles, Sapphire Utility row,
## Garnet Exit footer), springy hover/press juice, and embedded Settings & 3-Slot Save/Load.

var kansas_mode: bool = false
var is_open: bool = false

var _root: Control
var _backdrop: ColorRect
var _main_card: PanelContainer
var _title: Label
var _subtitle_pill: PanelContainer
var _subtitle: Label
var _objective_recap: Label
var _settings_view: Control
var _saves_card: PanelContainer
var _saves_list: VBoxContainer

var _resume_btn: Button
var _grimoire_btn: Button
var _shop_btn: Button
var _saves_btn: Button
var _settings_btn: Button
var _restart_btn: Button
var _quit_btn: Button

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	apply_theme_mode(kansas_mode)

func _input(event: InputEvent) -> void:
	if DisplayServer.get_name() in ["headless", "Dummy"]:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if is_open:
			if (_settings_view and _settings_view.visible) or (_saves_card and _saves_card.visible):
				_show_main_card()
			else:
				close()
			get_viewport().set_input_as_handled()
		else:
			var lt := get_node_or_null("/root/LevelTransition")
			if lt and lt.get("_active") == true:
				return
			open()
			get_viewport().set_input_as_handled()

func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_shop_badge()
	_show_main_card()
	if _main_card and DisplayServer.get_name() not in ["headless", "Dummy"]:
		_main_card.pivot_offset = _main_card.size * 0.5
		_main_card.scale = Vector2(0.92, 0.92)
		var tw := create_tween()
		tw.tween_property(_main_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _resume_btn:
		_resume_btn.grab_focus()

func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_objective_text(text: String) -> void:
	if _objective_recap:
		_objective_recap.text = text

func _refresh_shop_badge() -> void:
	if _shop_btn == null:
		return
	var sm := get_node_or_null("/root/SaveManager")
	var df: int = int(sm.desire_fragments) if (sm and "desire_fragments" in sm) else 0
	_shop_btn.text = "♦  BOUTIQUE (B)\n%d Desire" % df

func apply_theme_mode(p_kansas: bool) -> void:
	kansas_mode = p_kansas
	if _main_card == null:
		return
	var modal_sb := StyleBoxFlat.new()
	modal_sb.bg_color = Color(0.08, 0.09, 0.10, 0.97) if p_kansas else Color(0.085, 0.042, 0.112, 0.97)
	modal_sb.border_color = Color(0.76, 0.78, 0.82, 0.95) if p_kansas else Color(0.90, 0.74, 0.36, 0.96)
	modal_sb.set_border_width_all(3)
	modal_sb.border_width_bottom = 6
	modal_sb.set_corner_radius_all(22)
	modal_sb.content_margin_left = 30
	modal_sb.content_margin_right = 30
	modal_sb.content_margin_top = 24
	modal_sb.content_margin_bottom = 26
	modal_sb.shadow_size = 32
	modal_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	modal_sb.shadow_offset = Vector2(0, 12)
	_main_card.add_theme_stylebox_override("panel", modal_sb)
	if _saves_card:
		_saves_card.add_theme_stylebox_override("panel", modal_sb.duplicate())

	_title.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98) if p_kansas else Color(0.98, 0.86, 0.48))
	_subtitle.add_theme_color_override("font_color", Color(0.84, 0.86, 0.90) if p_kansas else Color(0.96, 0.88, 0.72))

	if p_kansas:
		_style_jewel_button(_resume_btn, Color(0.38, 0.40, 0.44), Color(0.24, 0.25, 0.28), Color(0.86, 0.88, 0.92), 18)
		_style_jewel_button(_grimoire_btn, Color(0.26, 0.27, 0.30), Color(0.16, 0.17, 0.19), Color(0.72, 0.74, 0.78), 14)
		_style_jewel_button(_shop_btn, Color(0.30, 0.31, 0.34), Color(0.18, 0.19, 0.21), Color(0.78, 0.80, 0.84), 14)
		_style_jewel_button(_saves_btn, Color(0.20, 0.21, 0.24), Color(0.12, 0.13, 0.15), Color(0.60, 0.62, 0.66), 15)
		_style_jewel_button(_settings_btn, Color(0.20, 0.21, 0.24), Color(0.12, 0.13, 0.15), Color(0.60, 0.62, 0.66), 15)
		_style_jewel_button(_restart_btn, Color(0.22, 0.23, 0.26), Color(0.13, 0.14, 0.16), Color(0.64, 0.66, 0.70), 15)
		_style_jewel_button(_quit_btn, Color(0.28, 0.22, 0.24), Color(0.16, 0.12, 0.14), Color(0.70, 0.56, 0.58), 15)
	else:
		# Glossy 2026 Candy-Jewel Hierarchy: Emerald Hero, Amethyst Grimoire, Crimson Boutique, Sapphire Utilities, Garnet Exit!
		_style_jewel_button(_resume_btn, Color(0.14, 0.66, 0.42), Color(0.06, 0.38, 0.24), Color(0.62, 1.0, 0.78), 18)
		_style_jewel_button(_grimoire_btn, Color(0.42, 0.20, 0.62), Color(0.24, 0.10, 0.38), Color(0.88, 0.74, 1.0), 14)
		_style_jewel_button(_shop_btn, Color(0.74, 0.16, 0.32), Color(0.44, 0.08, 0.18), Color(1.0, 0.76, 0.56), 14)
		_style_jewel_button(_saves_btn, Color(0.20, 0.26, 0.46), Color(0.12, 0.15, 0.28), Color(0.72, 0.82, 0.98), 15)
		_style_jewel_button(_settings_btn, Color(0.22, 0.22, 0.38), Color(0.13, 0.13, 0.24), Color(0.78, 0.74, 0.92), 15)
		_style_jewel_button(_restart_btn, Color(0.32, 0.24, 0.36), Color(0.19, 0.13, 0.22), Color(0.90, 0.76, 0.52), 15)
		_style_jewel_button(_quit_btn, Color(0.42, 0.12, 0.18), Color(0.24, 0.06, 0.10), Color(0.96, 0.54, 0.60), 15)

	if _settings_view:
		_settings_view.call("apply_theme_mode", p_kansas)
	if _backdrop and _backdrop.material is ShaderMaterial:
		(_backdrop.material as ShaderMaterial).set_shader_parameter("kansas_mix", 1.0 if p_kansas else 0.0)

func _style_jewel_button(btn: Button, bg_col: Color, bevel_col: Color, rim_col: Color, font_sz: int = 16) -> void:
	if btn == null:
		return
	var norm := StyleBoxFlat.new()
	norm.bg_color = bg_col
	norm.border_color = bevel_col
	norm.border_width_left = 2
	norm.border_width_right = 2
	norm.border_width_top = 3
	norm.border_width_bottom = 6 # Tactile 3D-cushion bevel!
	norm.set_corner_radius_all(16)
	norm.content_margin_left = 20
	norm.content_margin_right = 20
	norm.content_margin_top = 11
	norm.content_margin_bottom = 11
	norm.shadow_size = 10
	norm.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	norm.shadow_offset = Vector2(0, 4)
	norm.anti_aliasing = true

	var hov := norm.duplicate() as StyleBoxFlat
	hov.bg_color = bg_col.lightened(0.15)
	hov.border_color = rim_col
	hov.shadow_size = 16
	hov.shadow_color = Color(rim_col.r, rim_col.g, rim_col.b, 0.32)

	var prs := norm.duplicate() as StyleBoxFlat
	prs.bg_color = bg_col.darkened(0.12)
	prs.border_width_top = 5
	prs.border_width_bottom = 2
	prs.shadow_size = 4

	btn.add_theme_stylebox_override("normal", norm)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("focus", hov)
	btn.add_theme_stylebox_override("pressed", prs)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", Color(0.99, 0.98, 0.95))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.06, 0.85))
	btn.add_theme_constant_override("outline_size", 3)

func _wire_button_juice(btn: Button) -> void:
	btn.mouse_entered.connect(func():
		var afx := get_node_or_null("/root/AudioFx")
		if afx and afx.has_method("play"):
			afx.play("ui_hover", -12.0)
	)
	btn.pressed.connect(func():
		var afx := get_node_or_null("/root/AudioFx")
		if afx and afx.has_method("play"):
			afx.play("ui_click", -8.0)
	)

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.06, 0.025, 0.075, 0.88)
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		var bmat := ShaderMaterial.new()
		bmat.shader = FrostedShader
		_backdrop.material = bmat
	_root.add_child(_backdrop)

	var screen_frame := OrnateFrame.new()
	screen_frame.inset = 14.0
	screen_frame.corner_size = 24.0
	screen_frame.animated_sheen = true
	_root.add_child(screen_frame)

	var center := CenterContainer.new()
	center.name = "ModalCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	# Generously padded 2026 Tactile Modal Card
	_main_card = PanelContainer.new()
	_main_card.custom_minimum_size = Vector2(560, 610)
	center.add_child(_main_card)

	var card_frame := OrnateFrame.new()
	card_frame.inset = 8.0
	card_frame.corner_size = 16.0
	_main_card.add_child(card_frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_main_card.add_child(vbox)

	# 1. Hero Jeweled Crest Header
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var crest := Label.new()
	crest.text = "✦   ♦   ✿   ♦   ✦"
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.add_theme_font_size_override("font_size", 18)
	crest.add_theme_color_override("font_color", Color(0.95, 0.82, 0.46))
	header.add_child(crest)

	_title = Label.new()
	_title.text = "OZ: THE ROAD HOME"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.07, 0.90))
	_title.add_theme_constant_override("outline_size", 5)
	header.add_child(_title)

	var sub_center := CenterContainer.new()
	_subtitle_pill = PanelContainer.new()
	var pill_sb := StyleBoxFlat.new()
	pill_sb.bg_color = Color(0.18, 0.10, 0.24, 0.92)
	pill_sb.border_color = Color(0.86, 0.70, 0.36, 0.75)
	pill_sb.set_border_width_all(1)
	pill_sb.set_corner_radius_all(999)
	pill_sb.content_margin_left = 18
	pill_sb.content_margin_right = 18
	pill_sb.content_margin_top = 4
	pill_sb.content_margin_bottom = 4
	_subtitle_pill.add_theme_stylebox_override("panel", pill_sb)
	_subtitle = Label.new()
	_subtitle.text = "GAME PAUSED"
	_subtitle.add_theme_font_size_override("font_size", 12)
	_subtitle_pill.add_child(_subtitle)
	sub_center.add_child(_subtitle_pill)
	header.add_child(sub_center)
	vbox.add_child(header)

	# 2. Distinct Recessed Objective Ribbon Card
	var recap_panel := PanelContainer.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.13, 0.08, 0.17, 0.94)
	rsb.border_color = Color(0.84, 0.68, 0.36, 0.72)
	rsb.set_border_width_all(2)
	rsb.set_corner_radius_all(14)
	rsb.content_margin_left = 18
	rsb.content_margin_right = 18
	rsb.content_margin_top = 12
	rsb.content_margin_bottom = 12
	recap_panel.add_theme_stylebox_override("panel", rsb)
	var recap_vb := VBoxContainer.new()
	recap_vb.add_theme_constant_override("separation", 4)
	var goal_hdr := Label.new()
	goal_hdr.text = "✦  CURRENT OBJECTIVE"
	goal_hdr.add_theme_font_size_override("font_size", 11)
	goal_hdr.add_theme_color_override("font_color", Color(0.95, 0.80, 0.44))
	recap_vb.add_child(goal_hdr)
	_objective_recap = Label.new()
	_objective_recap.text = "Follow the Yellow Brick Road"
	_objective_recap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_recap.add_theme_font_size_override("font_size", 14)
	_objective_recap.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	recap_vb.add_child(_objective_recap)
	recap_panel.add_child(recap_vb)
	vbox.add_child(recap_panel)

	# 3. Primary Emerald Hero CTA Button
	_resume_btn = Button.new()
	_resume_btn.text = "▶   RESUME GAME"
	_resume_btn.custom_minimum_size = Vector2(0, 56)
	_resume_btn.pressed.connect(close)
	_wire_button_juice(_resume_btn)
	vbox.add_child(_resume_btn)

	# 4. 2-Column Chunky Feature Jewel Tiles (Grimoire & Tailor of Vices Boutique!)
	var feat_row := HBoxContainer.new()
	feat_row.add_theme_constant_override("separation", 14)
	vbox.add_child(feat_row)

	_grimoire_btn = Button.new()
	_grimoire_btn.text = "📖  GRIMOIRE (J)\nCodex & Lore"
	_grimoire_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grimoire_btn.custom_minimum_size = Vector2(0, 58)
	_grimoire_btn.pressed.connect(_open_grimoire)
	_wire_button_juice(_grimoire_btn)
	feat_row.add_child(_grimoire_btn)

	_shop_btn = Button.new()
	_shop_btn.text = "♦  BOUTIQUE (B)\n0 Desire"
	_shop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_btn.custom_minimum_size = Vector2(0, 58)
	_shop_btn.pressed.connect(_open_shop)
	_wire_button_juice(_shop_btn)
	feat_row.add_child(_shop_btn)

	# 5. Secondary Utility Stack with Generous Spacing
	var util_box := VBoxContainer.new()
	util_box.add_theme_constant_override("separation", 12)
	vbox.add_child(util_box)

	_saves_btn = Button.new()
	_saves_btn.text = "💾   Save / Load Game  (Slots 1–3)"
	_saves_btn.custom_minimum_size = Vector2(0, 48)
	_saves_btn.pressed.connect(_show_saves)
	_wire_button_juice(_saves_btn)
	util_box.add_child(_saves_btn)

	_settings_btn = Button.new()
	_settings_btn.text = "⚙   Settings & Controls"
	_settings_btn.custom_minimum_size = Vector2(0, 48)
	_settings_btn.pressed.connect(_show_settings)
	_wire_button_juice(_settings_btn)
	util_box.add_child(_settings_btn)

	_restart_btn = Button.new()
	_restart_btn.text = "↺   Restart Checkpoint"
	_restart_btn.custom_minimum_size = Vector2(0, 48)
	_restart_btn.pressed.connect(_on_restart_checkpoint)
	_wire_button_juice(_restart_btn)
	util_box.add_child(_restart_btn)

	# 6. Distinct Divider & Garnet Exit Footer
	var div := HSeparator.new()
	vbox.add_child(div)

	_quit_btn = Button.new()
	_quit_btn.text = "✕   Quit to Desktop"
	_quit_btn.custom_minimum_size = Vector2(0, 46)
	_quit_btn.pressed.connect(func(): get_tree().quit())
	_wire_button_juice(_quit_btn)
	vbox.add_child(_quit_btn)

	# Embedded Settings View
	_settings_view = SettingsMenuScript.new()
	_settings_view.visible = false
	_settings_view.connect("back_pressed", _show_main_card)
	center.add_child(_settings_view)

	# Embedded 3-Slot Save / Load Panel
	_saves_card = PanelContainer.new()
	_saves_card.custom_minimum_size = Vector2(560, 430)
	_saves_card.visible = false
	center.add_child(_saves_card)
	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 16)
	_saves_card.add_child(svb)
	var shdr := Label.new()
	shdr.text = "✦   SAVE & LOAD SLOTS   ✦"
	shdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shdr.add_theme_font_size_override("font_size", 22)
	shdr.add_theme_color_override("font_color", Color(0.98, 0.86, 0.48))
	svb.add_child(shdr)
	_saves_list = VBoxContainer.new()
	_saves_list.add_theme_constant_override("separation", 12)
	_saves_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svb.add_child(_saves_list)
	var sback := Button.new()
	sback.text = "◀   Back to Pause Menu"
	sback.custom_minimum_size = Vector2(0, 48)
	_style_jewel_button(sback, Color(0.24, 0.22, 0.36), Color(0.14, 0.12, 0.22), Color(0.84, 0.74, 0.96), 15)
	_wire_button_juice(sback)
	sback.pressed.connect(_show_main_card)
	svb.add_child(sback)

func _open_grimoire() -> void:
	close()
	var hud := get_parent()
	if hud and hud.get("grimoire_menu"):
		hud.get("grimoire_menu").call("open", 0)

func _open_shop() -> void:
	close()
	var hud := get_parent()
	if hud and hud.get("shop_menu"):
		hud.get("shop_menu").call("open", "dorothy")

func _show_saves() -> void:
	_main_card.visible = false
	_settings_view.visible = false
	_saves_card.visible = true
	_refresh_saves_list()

func _refresh_saves_list() -> void:
	for c in _saves_list.get_children():
		c.queue_free()
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	for slot in range(1, 4):
		var info: Dictionary = sm.get_slot_info(slot)
		var slot_card := PanelContainer.new()
		var sc_sb := StyleBoxFlat.new()
		sc_sb.bg_color = Color(0.14, 0.08, 0.19, 0.95)
		sc_sb.border_color = Color(0.76, 0.62, 0.35, 0.65)
		sc_sb.set_border_width_all(1)
		sc_sb.set_corner_radius_all(12)
		sc_sb.content_margin_left = 14
		sc_sb.content_margin_right = 14
		sc_sb.content_margin_top = 10
		sc_sb.content_margin_bottom = 10
		slot_card.add_theme_stylebox_override("panel", sc_sb)
		_saves_list.add_child(slot_card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		slot_card.add_child(row)
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if info.is_empty():
			lbl.text = "Slot %d  —  [Empty]" % slot
		else:
			lbl.text = "Slot %d  ·  %s\n♦ %d Desire  ·  %s" % [slot, str(info.get("chapter", "Oz")), int(info.get("desire_fragments", 0)), str(info.get("saved_at", ""))]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.91, 0.83))
		row.add_child(lbl)
		var s_idx := slot
		var b_save := Button.new()
		b_save.text = "Save"
		_style_jewel_button(b_save, Color(0.14, 0.56, 0.36), Color(0.06, 0.32, 0.20), Color(0.62, 1.0, 0.78), 13)
		b_save.pressed.connect(func():
			sm.save_slot(s_idx)
			_refresh_saves_list()
		)
		row.add_child(b_save)
		var b_load := Button.new()
		b_load.text = "Load"
		b_load.disabled = info.is_empty()
		_style_jewel_button(b_load, Color(0.24, 0.32, 0.58), Color(0.14, 0.18, 0.36), Color(0.76, 0.86, 1.0), 13)
		b_load.pressed.connect(func():
			close()
			sm.load_slot(s_idx)
		)
		row.add_child(b_load)
		var b_del := Button.new()
		b_del.text = "✕"
		b_del.disabled = info.is_empty()
		_style_jewel_button(b_del, Color(0.46, 0.12, 0.18), Color(0.26, 0.06, 0.10), Color(1.0, 0.56, 0.62), 13)
		b_del.pressed.connect(func():
			sm.delete_slot(s_idx)
			_refresh_saves_list()
		)
		row.add_child(b_del)

func _show_settings() -> void:
	_main_card.visible = false
	if _saves_card:
		_saves_card.visible = false
	_settings_view.visible = true

func _show_main_card() -> void:
	_settings_view.visible = false
	if _saves_card:
		_saves_card.visible = false
	_main_card.visible = true
	_refresh_shop_badge()
	_resume_btn.grab_focus()

func _on_restart_checkpoint() -> void:
	close()
	get_tree().reload_current_scene()
