extends Control

## Phase P2.3: 2026 Retail Title Screen ("OZ: THE ROAD HOME — THE FORBIDDEN ROAD")
## Modeled 1:1 from ref_02_main_menu.jpg & ref_04_hero_art.jpg:
## - Ken Burns animated hero backdrop + smoked obsidian-plum mist + drifting emerald/gold embers
## - Clockwork-Gear & Thorny-Vine Antique-Gold Outer Frame
## - Winged Silver-Rose & Clockwork Crest
## - Smoked Bronzed-Obsidian & Double-Gold Filigree Plaque Buttons with live Glowing Silver-Rose Cursor
## - Full Chapter Select (Acts I–VII), 3-Slot Load Game, Tailor of Vices Boutique, Grimoire & Settings!

const OzThemeFactory := preload("res://ui/theme/oz_theme_factory.gd")
const OrnateFrame := preload("res://ui/widgets/ornate_frame.gd")
const GothicCrest := preload("res://ui/widgets/gothic_crest.gd")
const FrostedShader := preload("res://ui/shaders/frosted_velvet_backdrop.gdshader")
const SettingsMenuScript := preload("res://ui/shell/settings_menu.gd")
const ShopMenuScript := preload("res://ui/shop_menu.gd")
const GrimoireMenuScript := preload("res://ui/grimoire_menu.gd")

const CHAPTERS := [
	{"title": "Act I · Kansas — The Gale Farm (Ch. I)", "scene": "res://regions/kansas/farmyard.tscn", "art": "res://assets/art/scenes/title_kansas_cyclone.jpg"},
	{"title": "Act II · Munchkinland — Crash Square (Ch. II–VI)", "scene": "res://regions/munchkinland/landing_square.tscn", "art": "res://assets/art/scenes/munchkinland.jpg"},
	{"title": "Act IIIa · The Kalidah Wilds & Great Chasms (Ch. VII)", "scene": "res://regions/wilds/kalidah_wilds.tscn", "art": "res://assets/art/scenes/poppy_field.jpg"},
	{"title": "Act IIIb · The Deadly Poppy Field (Ch. VIII–IX)", "scene": "res://regions/poppy/poppy_road.tscn", "art": "res://assets/art/scenes/poppy_field.jpg"},
	{"title": "Act IV · Winkie Country — Iron Keep (Ch. XII–XIII)", "scene": "res://regions/winkie/west_castle.tscn", "art": "res://assets/art/scenes/winkie_castle.jpg"},
	{"title": "Act V · The Emerald City — Wizard's Palace (Ch. X–XVII)", "scene": "res://regions/emerald_city/wizard_tower.tscn", "art": "res://assets/art/scenes/emerald_city.jpg"},
	{"title": "Act VIa · Fighting Trees & Dainty China Country (Ch. XVIII–XXI)", "scene": "res://regions/south/china_country.tscn", "art": "res://assets/art/scenes/glinda_court.jpg"},
	{"title": "Act VIb · Quadling Country — Glinda's Court (Ch. XXII–XXIII)", "scene": "res://regions/quadling/glinda_court.tscn", "art": "res://assets/art/scenes/glinda_court.jpg"},
	{"title": "Act VII · Kansas — Homecoming (Ch. XXIV)", "scene": "res://regions/kansas/homecoming.tscn", "art": "res://assets/art/scenes/kansas_homecoming.jpg"},
]

var _bg_tex: TextureRect
var _ember_canvas: Control
var _embers: Array[Dictionary] = []
var _main_col: VBoxContainer
var _chapters_card: PanelContainer
var _saves_card: PanelContainer
var _saves_list: VBoxContainer
var _settings_view: Control
var _shop_layer: CanvasLayer
var _grimoire_layer: CanvasLayer
var _rose_cursor: Control
var _active_btn: Button
var _t: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	var dui := get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("clear"):
		dui.call("clear")
	var p := get_node_or_null("/root/Party")
	if p and p.has_method("exit_dialogue_shot"):
		p.call("exit_dialogue_shot")
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_init_embers()
	_build_ui()

func _init_embers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in range(34):
		_embers.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"vel": Vector2(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.028, -0.008)),
			"rad": rng.randf_range(1.4, 3.4),
			"emerald": (i % 3 == 0),
			"phase": rng.randf() * TAU,
		})

func _process(delta: float) -> void:
	if DisplayServer.get_name() in ["headless", "Dummy"]:
		return
	_t += delta
	# Subtle Ken Burns slow breathing zoom on hero backdrop
	if _bg_tex:
		var z := 1.04 + 0.025 * sin(_t * 0.18)
		_bg_tex.scale = Vector2(z, z)
		_bg_tex.pivot_offset = _bg_tex.size * 0.5
	if _ember_canvas:
		for e in _embers:
			var p: Vector2 = e["pos"] + e["vel"] * delta
			if p.y < -0.05:
				p.y = 1.05
			if p.x < -0.05:
				p.x = 1.05
			elif p.x > 1.05:
				p.x = -0.05
			e["pos"] = p
		_ember_canvas.queue_redraw()
	if _rose_cursor and _active_btn and is_instance_valid(_active_btn) and _main_col and _main_col.visible:
		_rose_cursor.visible = true
		var target_pos := _active_btn.global_position + Vector2(_active_btn.size.x + 12.0, (_active_btn.size.y - 28.0) * 0.5)
		_rose_cursor.global_position = _rose_cursor.global_position.lerp(target_pos, clampf(delta * 16.0, 0.0, 1.0))
	elif _rose_cursor:
		_rose_cursor.visible = false

func _build_ui() -> void:
	# 1. Hero Key Art Backdrop + Smoked Obsidian-Bramble Vignette
	var solid_bg := ColorRect.new()
	solid_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	solid_bg.color = Color(0.055, 0.028, 0.070, 1.0)
	add_child(solid_bg)

	_bg_tex = TextureRect.new()
	_bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_tex.modulate = Color(0.42, 0.34, 0.46, 0.58)
	if ResourceLoader.exists("res://assets/art/scenes/title_hero_oz.jpg"):
		_bg_tex.texture = ResourceLoader.load("res://assets/art/scenes/title_hero_oz.jpg") as Texture2D
	add_child(_bg_tex)

	var mist := ColorRect.new()
	mist.set_anchors_preset(Control.PRESET_FULL_RECT)
	mist.color = Color(0.06, 0.025, 0.075, 0.76)
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		var bmat := ShaderMaterial.new()
		bmat.shader = FrostedShader
		mist.material = bmat
	add_child(mist)

	# Drifting Emerald & Gold Embers + Thorny Bramble Silhouettes
	_ember_canvas = Control.new()
	_ember_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ember_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ember_canvas.draw.connect(_draw_embers_and_brambles)
	add_child(_ember_canvas)

	# 2. Clockwork-Gear & Antique-Gold Perimeter Frame (ref_02_main_menu.jpg)
	var outer_frame := OrnateFrame.new()
	outer_frame.outer_pad = 16.0
	outer_frame.inset = 7.0
	outer_frame.corner_size = 34.0
	outer_frame.clockwork_gears = true
	outer_frame.animated_sheen = true
	add_child(outer_frame)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# 3. Central Crest + Plaque Menu Column
	_main_col = VBoxContainer.new()
	_main_col.custom_minimum_size = Vector2(440, 0)
	_main_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_col.add_theme_constant_override("separation", 12)
	center.add_child(_main_col)

	# Winged Clockwork & Silver-Rose Crest Stack
	var crest_holder := Control.new()
	crest_holder.custom_minimum_size = Vector2(440, 146)
	crest_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_col.add_child(crest_holder)

	var crest := GothicCrest.new()
	crest.set_anchors_preset(Control.PRESET_FULL_RECT)
	crest_holder.add_child(crest)

	var oz_lbl := Label.new()
	oz_lbl.text = "OZ:"
	oz_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	oz_lbl.offset_top = 26.0
	oz_lbl.offset_bottom = 82.0
	oz_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	oz_lbl.add_theme_font_size_override("font_size", 46)
	oz_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.58))
	oz_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.06, 0.95))
	oz_lbl.add_theme_constant_override("outline_size", 6)
	crest_holder.add_child(oz_lbl)

	var sub_title := Label.new()
	sub_title.text = "THE ROAD HOME"
	sub_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub_title.offset_top = 76.0
	sub_title.offset_bottom = 104.0
	sub_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_title.add_theme_font_size_override("font_size", 20)
	sub_title.add_theme_color_override("font_color", Color(0.93, 0.82, 0.56))
	sub_title.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.06, 0.95))
	sub_title.add_theme_constant_override("outline_size", 4)
	crest_holder.add_child(sub_title)

	var sm_ng := get_node_or_null("/root/SaveManager")
	var ng_plus := bool(sm_ng.get("velvet_road_unlocked")) if (sm_ng and "velvet_road_unlocked" in sm_ng) else false
	var rib_lbl := Label.new()
	rib_lbl.text = "★ THE VELVET ROAD (NG+)" if ng_plus else "THE FORBIDDEN ROAD"
	rib_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	rib_lbl.offset_top = 105.0
	rib_lbl.offset_bottom = 126.0
	rib_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rib_lbl.add_theme_font_size_override("font_size", 11)
	rib_lbl.add_theme_color_override("font_color", Color(0.88, 0.76, 0.52))
	crest_holder.add_child(rib_lbl)

	var btn_stack := VBoxContainer.new()
	btn_stack.custom_minimum_size = Vector2(360, 0)
	btn_stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_stack.add_theme_constant_override("separation", 10)
	_main_col.add_child(btn_stack)

	var can_resume := sm_ng != null and bool(sm_ng.get("resume_active"))
	var b_resume := _make_plaque_btn("▶  RESUME CURRENT GAME", true, func():
		if sm_ng and sm_ng.has_method("resume_live_session"):
			sm_ng.call("resume_live_session")
	)
	b_resume.visible = can_resume
	btn_stack.add_child(b_resume)

	var has_save := sm_ng != null and sm_ng.has_method("has_any_save") and bool(sm_ng.call("has_any_save"))
	var b_cont := _make_plaque_btn("CONTINUE SAVED SLOT", (not can_resume) and has_save, _on_continue)
	b_cont.visible = has_save
	btn_stack.add_child(b_cont)

	var b_new := _make_plaque_btn("NEW JOURNEY", (not can_resume) and (not has_save), _on_new_journey)
	btn_stack.add_child(b_new)

	var b_chap := _make_plaque_btn("CHAPTER SELECT", false, _show_chapters)
	btn_stack.add_child(b_chap)

	var b_load := _make_plaque_btn("LOAD SAVE", false, _show_saves)
	btn_stack.add_child(b_load)

	var b_boutique := _make_plaque_btn("THE TAILOR OF VICES", false, _open_boutique)
	btn_stack.add_child(b_boutique)

	var b_settings := _make_plaque_btn("SETTINGS", false, _show_settings)
	btn_stack.add_child(b_settings)

	var b_quit := _make_plaque_btn("QUIT", false, func(): get_tree().quit())
	btn_stack.add_child(b_quit)

	_active_btn = b_resume if can_resume else (b_cont if has_save else b_new)
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		_active_btn.call_deferred("grab_focus")

	# Glowing Silver-Rose Cursor floating beside the focused/hovered plaque button (ref_02_main_menu.jpg!)
	_rose_cursor = GothicCrest.new()
	_rose_cursor.mode = "rose_cursor"
	_rose_cursor.size = Vector2(28, 28)
	add_child(_rose_cursor)

	# Bottom Footer Version & Navigation Legend (ref_02_main_menu.jpg)
	var ver_lbl := Label.new()
	ver_lbl.text = "v1.3 · THE FORBIDDEN ROAD"
	ver_lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver_lbl.offset_left = 34.0
	ver_lbl.offset_top = -36.0
	ver_lbl.offset_right = 320.0
	ver_lbl.offset_bottom = -14.0
	ver_lbl.add_theme_font_size_override("font_size", 11)
	ver_lbl.add_theme_color_override("font_color", Color(0.68, 0.62, 0.56, 0.85))
	add_child(ver_lbl)

	var nav_lbl := Label.new()
	nav_lbl.text = "SELECT [ENTER / CLICK]  ·  NAVIGATE [W/S · ARROWS]"
	nav_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	nav_lbl.offset_left = -420.0
	nav_lbl.offset_top = -36.0
	nav_lbl.offset_right = -34.0
	nav_lbl.offset_bottom = -14.0
	nav_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nav_lbl.add_theme_font_size_override("font_size", 11)
	nav_lbl.add_theme_color_override("font_color", Color(0.68, 0.62, 0.56, 0.85))
	add_child(nav_lbl)

	# Sub-Modals: Chapter Select, Save/Load, Settings, Boutique, Grimoire
	_build_chapters_modal(center)
	_build_saves_modal(center)

	_settings_view = SettingsMenuScript.new()
	_settings_view.visible = false
	_settings_view.connect("back_pressed", _show_main)
	center.add_child(_settings_view)

	_shop_layer = ShopMenuScript.new()
	add_child(_shop_layer)
	_grimoire_layer = GrimoireMenuScript.new()
	add_child(_grimoire_layer)

func _make_plaque_btn(label_txt: String, hero: bool, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_txt
	btn.custom_minimum_size = Vector2(360, 44)
	OzThemeFactory.style_gothic_plaque_button(btn, hero, false, 16)
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
	return btn

func _draw_embers_and_brambles() -> void:
	var sz := _ember_canvas.size
	# Subtle gothic thorny bramble arcs in the 4 corners
	var vine_col := Color(0.02, 0.01, 0.03, 0.55)
	for c_pt in [Vector2(0, 0), Vector2(sz.x, 0), Vector2(0, sz.y), Vector2(sz.x, sz.y)]:
		_ember_canvas.draw_arc(c_pt, 210.0, 0.0, TAU, 36, vine_col, 4.0, true)
		_ember_canvas.draw_arc(c_pt, 145.0, 0.0, TAU, 32, vine_col, 2.5, true)
	for e in _embers:
		var p := Vector2(float(e["pos"].x) * sz.x, float(e["pos"].y) * sz.y)
		var pulse := 0.45 + 0.55 * sin(_t * 2.2 + float(e["phase"]))
		var col := Color(0.38, 0.95, 0.62, 0.45 * pulse) if bool(e["emerald"]) else Color(0.96, 0.84, 0.48, 0.42 * pulse)
		_ember_canvas.draw_circle(p, float(e["rad"]) * 2.4, Color(col.r, col.g, col.b, col.a * 0.28))
		_ember_canvas.draw_circle(p, float(e["rad"]), col)

func _build_chapters_modal(center: CenterContainer) -> void:
	_chapters_card = PanelContainer.new()
	_chapters_card.custom_minimum_size = Vector2(640, 540)
	_chapters_card.visible = false
	var sb := OzThemeFactory.make_modal_style(false)
	sb.content_margin_left = 42
	sb.content_margin_right = 42
	sb.content_margin_top = 34
	sb.content_margin_bottom = 32
	_chapters_card.add_theme_stylebox_override("panel", sb)
	var fr := OrnateFrame.new()
	fr.outer_pad = 10.0
	fr.inset = 5.0
	fr.corner_size = 16.0
	_chapters_card.add_child(fr)
	center.add_child(_chapters_card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_chapters_card.add_child(vb)

	var hdr := Label.new()
	hdr.text = "✦   CHRONICLES OF THE ROAD  (CHAPTER SELECT)   ✦"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 19)
	hdr.add_theme_color_override("font_color", OzThemeFactory.OZ_GOLD_BRIGHT)
	vb.add_child(hdr)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	sc.add_child(list)

	for ch in CHAPTERS:
		var ch_ref: Dictionary = ch
		var b := Button.new()
		b.text = "◈   %s" % str(ch["title"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 44)
		OzThemeFactory.style_gothic_plaque_button(b, false, false, 14)
		b.pressed.connect(func(): _launch_scene(str(ch_ref["scene"]), str(ch_ref["title"])))
		list.add_child(b)

	var back := _make_plaque_btn("◀   BACK TO TITLE", false, _show_main)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(back)

func _build_saves_modal(center: CenterContainer) -> void:
	_saves_card = PanelContainer.new()
	_saves_card.custom_minimum_size = Vector2(600, 440)
	_saves_card.visible = false
	var sb := OzThemeFactory.make_modal_style(false)
	sb.content_margin_left = 42
	sb.content_margin_right = 42
	sb.content_margin_top = 34
	sb.content_margin_bottom = 32
	_saves_card.add_theme_stylebox_override("panel", sb)
	var fr := OrnateFrame.new()
	fr.outer_pad = 10.0
	fr.inset = 5.0
	fr.corner_size = 16.0
	_saves_card.add_child(fr)
	center.add_child(_saves_card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_saves_card.add_child(vb)

	var hdr := Label.new()
	hdr.text = "✦   LOAD SAVED JOURNEY   ✦"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 20)
	hdr.add_theme_color_override("font_color", OzThemeFactory.OZ_GOLD_BRIGHT)
	vb.add_child(hdr)

	_saves_list = VBoxContainer.new()
	_saves_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_saves_list.add_theme_constant_override("separation", 10)
	vb.add_child(_saves_list)

	var back := _make_plaque_btn("◀   BACK TO TITLE", false, _show_main)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(back)

func _refresh_saves() -> void:
	for c in _saves_list.get_children():
		c.queue_free()
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	for slot in range(1, 4):
		var info: Dictionary = sm.get_slot_info(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_saves_list.add_child(row)
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 52)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if info.is_empty():
			b.text = "Slot %d  —  [Empty]" % slot
			b.disabled = true
		else:
			b.text = "Slot %d  ·  %s   (♦ %d Desire)" % [slot, str(info.get("chapter", "Oz")), int(info.get("desire_fragments", 0))]
		OzThemeFactory.style_gothic_plaque_button(b, not info.is_empty(), false, 14)
		var s_idx := slot
		b.pressed.connect(func(): sm.load_slot(s_idx))
		row.add_child(b)

func _on_continue() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm:
		for s in range(1, 4):
			if not sm.get_slot_info(s).is_empty():
				sm.load_slot(s)
				return
	_on_new_journey()

func _on_new_journey() -> void:
	_launch_scene("res://regions/kansas/farmyard.tscn", "Act I · Kansas — The Gale Farm")

func _launch_scene(scene_path: String, title: String) -> void:
	get_tree().paused = false
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("set_current_location"):
		sm.set_current_location(scene_path, title)
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("go_to"):
		lt.go_to(scene_path, "Entering %s…" % title, title)
	else:
		get_tree().change_scene_to_file(scene_path)

func _show_chapters() -> void:
	_main_col.visible = false
	_saves_card.visible = false
	_settings_view.visible = false
	_chapters_card.visible = true

func _show_saves() -> void:
	_main_col.visible = false
	_chapters_card.visible = false
	_settings_view.visible = false
	_saves_card.visible = true
	_refresh_saves()

func _show_settings() -> void:
	_main_col.visible = false
	_chapters_card.visible = false
	_saves_card.visible = false
	_settings_view.visible = true

func _open_boutique() -> void:
	if _shop_layer:
		_shop_layer.call("open", "dorothy")

func _show_main() -> void:
	_chapters_card.visible = false
	_saves_card.visible = false
	_settings_view.visible = false
	_main_col.visible = true
	if _active_btn and is_instance_valid(_active_btn):
		_active_btn.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _chapters_card.visible or _saves_card.visible or _settings_view.visible:
			_show_main()
			get_viewport().set_input_as_handled()
