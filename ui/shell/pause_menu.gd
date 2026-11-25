extends CanvasLayer

const OzThemeFactory := preload("res://ui/theme/oz_theme_factory.gd")
const SettingsMenuScript := preload("res://ui/shell/settings_menu.gd")
const OrnateFrame := preload("res://ui/widgets/ornate_frame.gd")
const GothicCrest := preload("res://ui/widgets/gothic_crest.gd")
const FrostedShader := preload("res://ui/shaders/frosted_velvet_backdrop.gdshader")
const PlaqueShader := preload("res://ui/shaders/ui_velvet_plaque.gdshader")

## Phase P2.3 / P3.3: Reference-True 2026 Gothic Filigree Pause & Chapter Shell (ref_02_main_menu.jpg).
## Unifies the Pause Menu 1:1 with the Main Title Screen & Tailor of Vices Boutique:
## - Clockwork-Gear & Thorny-Vine Antique-Gold Screen Frame
## - Winged Silver-Rose & Clockwork Crest ("OZ: THE ROAD HOME — GAME PAUSED")
## - Smoked Bronzed-Obsidian & Double-Gold Filigree Plaque Buttons (zero rainbow clash!)
## - Live Glowing Silver-Rose Focus Cursor beside the hovered/focused button
## - Embedded Save/Load (Slots 1–3), Chapter Select (Acts I–VII), Settings, Grimoire & Boutique!

const CHAPTERS := [
	{"title": "Act I · Kansas — The Gale Farm", "scene": "res://regions/kansas/farmyard.tscn"},
	{"title": "Act II · Munchkinland — Crash Square", "scene": "res://regions/munchkinland/landing_square.tscn"},
	{"title": "Act III · The Deadly Poppy Field", "scene": "res://regions/poppy/poppy_road.tscn"},
	{"title": "Act IV · Winkie Country — Iron Keep", "scene": "res://regions/winkie/west_castle.tscn"},
	{"title": "Act V · The Emerald City — Wizard's Palace", "scene": "res://regions/emerald_city/wizard_tower.tscn"},
	{"title": "Act VI · Quadling Country — Glinda's Court", "scene": "res://regions/quadling/glinda_court.tscn"},
	{"title": "Act VII · Kansas — Homecoming", "scene": "res://regions/kansas/homecoming.tscn"},
]

var kansas_mode: bool = false
var is_open: bool = false

var _root: Control
var _backdrop: ColorRect
var _screen_frame: Control
var _crest: Control
var _main_card: PanelContainer
var _title: Label
var _subtitle: Label
var _objective_recap: Label
var _settings_view: Control
var _saves_card: PanelContainer
var _saves_list: VBoxContainer
var _chapters_card: PanelContainer
var _rose_cursor: Control
var _active_btn: Button

var _resume_btn: Button
var _grimoire_btn: Button
var _shop_btn: Button
var _saves_btn: Button
var _chapters_btn: Button
var _settings_btn: Button
var _restart_btn: Button
var _title_btn: Button
var _quit_btn: Button
var _all_plaque_btns: Array[Button] = []

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	apply_theme_mode(kansas_mode)

func _process(delta: float) -> void:
	if not is_open or DisplayServer.get_name() in ["headless", "Dummy"]:
		return
	if _rose_cursor and _active_btn and is_instance_valid(_active_btn) and _main_card and _main_card.visible:
		_rose_cursor.visible = true
		var t_pos := _active_btn.global_position + Vector2(_active_btn.size.x + 10.0, (_active_btn.size.y - 26.0) * 0.5)
		_rose_cursor.global_position = _rose_cursor.global_position.lerp(t_pos, clampf(delta * 18.0, 0.0, 1.0))
	elif _rose_cursor:
		_rose_cursor.visible = false

func _input(event: InputEvent) -> void:
	if DisplayServer.get_name() in ["headless", "Dummy"]:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if is_open:
			if (_settings_view and _settings_view.visible) or (_saves_card and _saves_card.visible) or (_chapters_card and _chapters_card.visible):
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
		_main_card.scale = Vector2(0.95, 0.95)
		_main_card.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_main_card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_main_card, "modulate:a", 1.0, 0.16)
	if _resume_btn:
		_active_btn = _resume_btn
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
	_shop_btn.text = "BOUTIQUE (B)  ·  ♦ %d" % df

func apply_theme_mode(p_kansas: bool) -> void:
	kansas_mode = p_kansas
	if _main_card == null:
		return
	var modal_sb := StyleBoxFlat.new()
	modal_sb.bg_color = Color(0.075, 0.082, 0.092, 0.96) if p_kansas else Color(0.068, 0.036, 0.082, 0.96)
	modal_sb.border_color = OzThemeFactory.KS_BORDER if p_kansas else OzThemeFactory.OZ_BORDER_GOLD
	modal_sb.set_border_width_all(2)
	modal_sb.border_width_bottom = 4
	modal_sb.set_corner_radius_all(12)
	modal_sb.content_margin_left = 48
	modal_sb.content_margin_right = 48
	modal_sb.content_margin_top = 34
	modal_sb.content_margin_bottom = 32
	modal_sb.shadow_size = 36
	modal_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.78)
	modal_sb.shadow_offset = Vector2(0, 12)
	_main_card.add_theme_stylebox_override("panel", modal_sb)
	if _saves_card:
		_saves_card.add_theme_stylebox_override("panel", modal_sb.duplicate())
	if _chapters_card:
		_chapters_card.add_theme_stylebox_override("panel", modal_sb.duplicate())

	if _title:
		_title.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98) if p_kansas else Color(0.95, 0.85, 0.58))
	if _subtitle:
		_subtitle.add_theme_color_override("font_color", Color(0.84, 0.86, 0.90) if p_kansas else Color(0.88, 0.76, 0.52))
	if _crest:
		_crest.set("kansas_mode", p_kansas)
		_crest.queue_redraw()
	if _screen_frame:
		_screen_frame.set("kansas_mode", p_kansas)
		_screen_frame.queue_redraw()

	for b in _all_plaque_btns:
		if b and is_instance_valid(b):
			OzThemeFactory.style_gothic_plaque_button(b, b == _resume_btn, p_kansas, 15 if b != _resume_btn else 17)
			for ch in b.get_children():
				if ch.has_method("queue_redraw") and "kansas_mode" in ch:
					ch.set("kansas_mode", p_kansas)
					ch.queue_redraw()

	if _settings_view:
		_settings_view.call("apply_theme_mode", p_kansas)
	if _backdrop and _backdrop.material is ShaderMaterial:
		(_backdrop.material as ShaderMaterial).set_shader_parameter("kansas_mix", 1.0 if p_kansas else 0.0)

func _make_gothic_btn(txt: String, hero: bool, min_h: float, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(0, min_h)
	OzThemeFactory.style_gothic_plaque_button(btn, hero, kansas_mode, 17 if hero else 14)
	var fr := OrnateFrame.new()
	fr.outer_pad = 3.0
	fr.inset = 3.0
	fr.corner_size = 9.0
	fr.show_diamonds = false
	btn.add_child(fr)
	btn.mouse_entered.connect(func():
		_active_btn = btn
		var afx := get_node_or_null("/root/AudioFx")
		if afx and afx.has_method("play"):
			afx.play("ui_hover", -12.0)
	)
	btn.focus_entered.connect(func(): _active_btn = btn)
	btn.pressed.connect(func():
		var afx := get_node_or_null("/root/AudioFx")
		if afx and afx.has_method("play"):
			afx.play("ui_click", -8.0)
		cb.call()
	)
	_all_plaque_btns.append(btn)
	return btn

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.055, 0.024, 0.070, 0.90)
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		var bmat := ShaderMaterial.new()
		bmat.shader = FrostedShader
		_backdrop.material = bmat
	_root.add_child(_backdrop)

	_screen_frame = OrnateFrame.new()
	_screen_frame.outer_pad = 14.0
	_screen_frame.inset = 6.0
	_screen_frame.corner_size = 30.0
	_screen_frame.clockwork_gears = true
	_screen_frame.animated_sheen = true
	_root.add_child(_screen_frame)

	var center := CenterContainer.new()
	center.name = "ModalCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_main_card = PanelContainer.new()
	_main_card.custom_minimum_size = Vector2(610, 646)
	center.add_child(_main_card)

	var card_frame := OrnateFrame.new()
	card_frame.outer_pad = 10.0
	card_frame.inset = 5.0
	card_frame.corner_size = 16.0
	_main_card.add_child(card_frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_main_card.add_child(vbox)

	# 1. Winged Clockwork & Silver-Rose Crest Header (ref_02_main_menu.jpg)
	var crest_box := Control.new()
	crest_box.custom_minimum_size = Vector2(440, 128)
	crest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(crest_box)

	_crest = GothicCrest.new()
	_crest.set_anchors_preset(Control.PRESET_FULL_RECT)
	crest_box.add_child(_crest)

	_title = Label.new()
	_title.text = "OZ: THE ROAD HOME"
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 46.0
	_title.offset_bottom = 86.0
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.06, 0.95))
	_title.add_theme_constant_override("outline_size", 5)
	crest_box.add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = "GAME PAUSED"
	_subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_subtitle.offset_top = 104.0
	_subtitle.offset_bottom = 124.0
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 11)
	crest_box.add_child(_subtitle)

	# 2. Recessed Current Objective Plaque with Safe-Zone Margins
	var recap_panel := PanelContainer.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.105, 0.064, 0.135, 0.95)
	rsb.border_color = Color(0.769, 0.620, 0.353, 0.65)
	rsb.set_border_width_all(1)
	rsb.set_corner_radius_all(8)
	rsb.content_margin_left = 22
	rsb.content_margin_right = 22
	rsb.content_margin_top = 12
	rsb.content_margin_bottom = 12
	recap_panel.add_theme_stylebox_override("panel", rsb)
	var recap_vb := VBoxContainer.new()
	recap_vb.add_theme_constant_override("separation", 4)
	var goal_hdr := Label.new()
	goal_hdr.text = "◈  CURRENT OBJECTIVE"
	goal_hdr.add_theme_font_size_override("font_size", 11)
	goal_hdr.add_theme_color_override("font_color", Color(0.91, 0.78, 0.48))
	recap_vb.add_child(goal_hdr)
	_objective_recap = Label.new()
	_objective_recap.text = "Follow the Yellow Brick Road"
	_objective_recap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_recap.add_theme_font_size_override("font_size", 14)
	_objective_recap.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	recap_vb.add_child(_objective_recap)
	recap_panel.add_child(recap_vb)
	vbox.add_child(recap_panel)

	# 3. Harmonized Gothic Filigree Plaque Buttons
	_resume_btn = _make_gothic_btn("CONTINUE JOURNEY", true, 48.0, close)
	vbox.add_child(_resume_btn)

	var feat_row := HBoxContainer.new()
	feat_row.add_theme_constant_override("separation", 12)
	vbox.add_child(feat_row)

	_grimoire_btn = _make_gothic_btn("OZ GRIMOIRE (J)", false, 44.0, _open_grimoire)
	_grimoire_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feat_row.add_child(_grimoire_btn)

	_shop_btn = _make_gothic_btn("BOUTIQUE (B)  ·  ♦ 0", false, 44.0, _open_shop)
	_shop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feat_row.add_child(_shop_btn)

	var mid_row := HBoxContainer.new()
	mid_row.add_theme_constant_override("separation", 12)
	vbox.add_child(mid_row)

	_saves_btn = _make_gothic_btn("SAVE / LOAD", false, 42.0, _show_saves)
	_saves_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_row.add_child(_saves_btn)

	_chapters_btn = _make_gothic_btn("CHAPTER SELECT", false, 42.0, _show_chapters)
	_chapters_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_row.add_child(_chapters_btn)

	var util_row := HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 12)
	vbox.add_child(util_row)

	_settings_btn = _make_gothic_btn("SETTINGS", false, 42.0, _show_settings)
	_settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	util_row.add_child(_settings_btn)

	_restart_btn = _make_gothic_btn("RESTART ACT", false, 42.0, _on_restart_checkpoint)
	_restart_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	util_row.add_child(_restart_btn)

	var exit_row := HBoxContainer.new()
	exit_row.add_theme_constant_override("separation", 12)
	vbox.add_child(exit_row)

	_title_btn = _make_gothic_btn("TITLE SCREEN", false, 40.0, _go_title_screen)
	_title_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_row.add_child(_title_btn)

	_quit_btn = _make_gothic_btn("QUIT TO DESKTOP", false, 40.0, func(): get_tree().quit())
	_quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_row.add_child(_quit_btn)

	# Glowing Silver-Rose Focus Cursor
	_rose_cursor = GothicCrest.new()
	_rose_cursor.mode = "rose_cursor"
	_rose_cursor.size = Vector2(26, 26)
	_root.add_child(_rose_cursor)

	# Embedded Settings View
	_settings_view = SettingsMenuScript.new()
	_settings_view.visible = false
	_settings_view.connect("back_pressed", _show_main_card)
	center.add_child(_settings_view)

	# Embedded 3-Slot Save / Load Panel
	_saves_card = PanelContainer.new()
	_saves_card.custom_minimum_size = Vector2(600, 440)
	_saves_card.visible = false
	var sv_fr := OrnateFrame.new()
	sv_fr.outer_pad = 10.0
	sv_fr.inset = 5.0
	_saves_card.add_child(sv_fr)
	center.add_child(_saves_card)
	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 14)
	_saves_card.add_child(svb)
	var shdr := Label.new()
	shdr.text = "✦   SAVE & LOAD SLOTS   ✦"
	shdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shdr.add_theme_font_size_override("font_size", 20)
	shdr.add_theme_color_override("font_color", Color(0.95, 0.85, 0.56))
	svb.add_child(shdr)
	_saves_list = VBoxContainer.new()
	_saves_list.add_theme_constant_override("separation", 10)
	_saves_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svb.add_child(_saves_list)
	var sback := _make_gothic_btn("◀   BACK TO PAUSE MENU", false, 44.0, _show_main_card)
	svb.add_child(sback)

	# Embedded Chapter Select Panel (Acts I–VII)
	_chapters_card = PanelContainer.new()
	_chapters_card.custom_minimum_size = Vector2(610, 520)
	_chapters_card.visible = false
	var ch_fr := OrnateFrame.new()
	ch_fr.outer_pad = 10.0
	ch_fr.inset = 5.0
	_chapters_card.add_child(ch_fr)
	center.add_child(_chapters_card)
	var cvb := VBoxContainer.new()
	cvb.add_theme_constant_override("separation", 10)
	_chapters_card.add_child(cvb)
	var chdr := Label.new()
	chdr.text = "✦   CHAPTER SELECT  (ACTS I–VII)   ✦"
	chdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chdr.add_theme_font_size_override("font_size", 19)
	chdr.add_theme_color_override("font_color", Color(0.95, 0.85, 0.56))
	cvb.add_child(chdr)
	var c_scroll := ScrollContainer.new()
	c_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cvb.add_child(c_scroll)
	var clist := VBoxContainer.new()
	clist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clist.add_theme_constant_override("separation", 8)
	c_scroll.add_child(clist)
	for ch in CHAPTERS:
		var ch_ref: Dictionary = ch
		var cb_btn := _make_gothic_btn("◈   %s" % str(ch["title"]), false, 40.0, func():
			close()
			var lt := get_node_or_null("/root/LevelTransition")
			if lt and lt.has_method("go_to"):
				lt.go_to(str(ch_ref["scene"]), "Traveling to %s…" % str(ch_ref["title"]), str(ch_ref["title"]))
			else:
				get_tree().change_scene_to_file(str(ch_ref["scene"]))
		)
		cb_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		clist.add_child(cb_btn)
	var cback := _make_gothic_btn("◀   BACK TO PAUSE MENU", false, 44.0, _show_main_card)
	cvb.add_child(cback)

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
	_chapters_card.visible = false
	_saves_card.visible = true
	_refresh_saves_list()

func _show_chapters() -> void:
	_main_card.visible = false
	_settings_view.visible = false
	_saves_card.visible = false
	_chapters_card.visible = true

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
		sc_sb.bg_color = Color(0.11, 0.068, 0.145, 0.95)
		sc_sb.border_color = Color(0.769, 0.620, 0.353, 0.65)
		sc_sb.set_border_width_all(1)
		sc_sb.set_corner_radius_all(8)
		sc_sb.content_margin_left = 16
		sc_sb.content_margin_right = 16
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
		lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
		row.add_child(lbl)
		var s_idx := slot
		var b_save := Button.new()
		b_save.text = "SAVE"
		OzThemeFactory.style_gothic_plaque_button(b_save, true, kansas_mode, 12)
		b_save.pressed.connect(func():
			sm.save_slot(s_idx)
			_refresh_saves_list()
		)
		row.add_child(b_save)
		var b_load := Button.new()
		b_load.text = "LOAD"
		b_load.disabled = info.is_empty()
		OzThemeFactory.style_gothic_plaque_button(b_load, false, kansas_mode, 12)
		b_load.pressed.connect(func():
			close()
			sm.load_slot(s_idx)
		)
		row.add_child(b_load)
		var b_del := Button.new()
		b_del.text = "✕"
		b_del.disabled = info.is_empty()
		OzThemeFactory.style_gothic_plaque_button(b_del, false, kansas_mode, 12)
		b_del.pressed.connect(func():
			sm.delete_slot(s_idx)
			_refresh_saves_list()
		)
		row.add_child(b_del)

func _show_settings() -> void:
	_main_card.visible = false
	_saves_card.visible = false
	_chapters_card.visible = false
	_settings_view.visible = true

func _show_main_card() -> void:
	_settings_view.visible = false
	_saves_card.visible = false
	_chapters_card.visible = false
	_main_card.visible = true
	_refresh_shop_badge()
	if _resume_btn:
		_active_btn = _resume_btn
		_resume_btn.grab_focus()

func _go_title_screen() -> void:
	close()
	get_tree().change_scene_to_file("res://ui/shell/title_screen.tscn")

func _on_restart_checkpoint() -> void:
	close()
	get_tree().reload_current_scene()
