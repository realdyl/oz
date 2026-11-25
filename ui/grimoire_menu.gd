extends CanvasLayer

## Phase P2.1: The Oz Grimoire / Codex — Remodeled directly from ref_01_grimoire_ui.jpg.
## Open Two-Page Antique Book Spread with left-edge leather bookmark tabs,
## glowing silver-rose active tab, selectable left-page entries, and framed right-page lore view.
## Toggle with [J] key (or from Pause Menu).

const OrnateFrame := preload("res://ui/widgets/ornate_frame.gd")
const ShopItemIcon := preload("res://ui/widgets/shop_item_icon.gd")

const TABS := [
	{"id": "quests", "label": "QUESTS", "page_title": "THE ROAD & OBJECTIVES"},
	{"id": "companions", "label": "COMPANIONS", "page_title": "THE COMPANIONS OF THE ROAD"},
	{"id": "armaments", "label": "ARMAMENTS", "page_title": "TOOLS OF ALLURE & COMBAT"},
	{"id": "bestiary", "label": "BESTIARY", "page_title": "FOES OF THE REALM"},
	{"id": "memories", "label": "SHATTERED\nMEMORIES", "page_title": "SHATTERED MEMORIES"},
]

const ARMAMENT_LORE := [
	{"id": "dorothy_whip_plus", "portrait": "res://assets/art/icons/arm_whip.png", "name": "The Lace Whip", "sub": "Slot 1 · Bind & Yank [C]", "body": "A braided crimson-silk lash with an engraved brass rose hilt and faceted ruby tip that snares distant foes and drags them straight into Silver-Shoe Kick range."},
	{"id": "dorothy_velvet", "portrait": "res://assets/art/icons/arm_ribbon.png", "name": "Silk Bindings", "sub": "Slot 2 · Multi-Cocoon [C]", "body": "Unspools iridescent dusty-rose and lavender silk ribbon embroidered with glowing golden knotwork around up to three nearby foes, multiplying Allure generation."},
	{"id": "dorothy_sovereign", "portrait": "res://assets/art/icons/arm_atomizer.png", "name": "Hypnotic Perfume", "sub": "Slot 3 · Enamored Mist [C]", "body": "Sprays a shimmering amethyst-violet and rose narcotic mist from a filigree crystal atomizer. Caught enemies become ♥ ENAMORED, pausing their assault in dazed devotion."},
	{"id": "lion_primal", "portrait": "res://assets/art/icons/arm_chain.png", "name": "The Gilded Chain", "sub": "Slot 4 · Damage Tether [C]", "body": "Links the two nearest adversaries in hammered antique-gold links and engraved rose-copper shackle clasps so 75% of all damage dealt to one mirrors onto the other."},
]

var _backdrop: ColorRect
var _tab_buttons: Array[Button] = []
var _left_title: Label
var _left_list: VBoxContainer
var _right_title: Label
var _right_icon_holder: CenterContainer
var _right_sub: Label
var _right_body: Label
var _stats_lbl: Label
var _active_tab: int = 1
var _selected_idx: int = 0
var _entries: Array[Dictionary] = []

func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J:
			toggle()
			get_viewport().set_input_as_handled()
		elif visible and event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		elif visible and event.keycode in [KEY_LEFT, KEY_Q]:
			_switch_tab((_active_tab - 1 + TABS.size()) % TABS.size())
			get_viewport().set_input_as_handled()
		elif visible and event.keycode in [KEY_RIGHT, KEY_E]:
			_switch_tab((_active_tab + 1) % TABS.size())
			get_viewport().set_input_as_handled()
		elif visible and event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]:
			_switch_tab(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()

func _switch_tab(idx: int) -> void:
	_active_tab = clampi(idx, 0, TABS.size() - 1)
	_selected_idx = 0
	var afx := get_node_or_null("/root/AudioFx")
	if afx and afx.has_method("play"):
		afx.play("ui_click", -8.0)
	_refresh_tab()

func toggle() -> void:
	if visible:
		close()
	else:
		open(_active_tab)

func open(tab_index: int = 1) -> void:
	_active_tab = clampi(tab_index, 0, TABS.size() - 1)
	_selected_idx = 0
	visible = true
	get_tree().paused = true
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_tab()

func close() -> void:
	visible = false
	get_tree().paused = false
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.035, 0.015, 0.045, 0.86)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Outer Book Row: Left-Edge Stitched Bookmark Tabs + Antique Leather Book Spread
	var book_row := HBoxContainer.new()
	book_row.add_theme_constant_override("separation", 0)
	center.add_child(book_row)

	# LEFT-EDGE BOOKMARK TABS (ref_01_grimoire_ui.jpg)
	var tab_col := VBoxContainer.new()
	tab_col.custom_minimum_size = Vector2(132, 0)
	tab_col.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_col.add_theme_constant_override("separation", 10)
	book_row.add_child(tab_col)

	for i in range(TABS.size()):
		var b := Button.new()
		b.custom_minimum_size = Vector2(126, 62)
		b.text = TABS[i]["label"]
		var idx := i
		b.pressed.connect(func(): _switch_tab(idx))
		tab_col.add_child(b)
		_tab_buttons.append(b)

	# ANTIQUE LEATHER COVER FRAME
	var cover := PanelContainer.new()
	cover.custom_minimum_size = Vector2(920, 580)
	var cov_st := StyleBoxFlat.new()
	cov_st.bg_color = Color(0.11, 0.06, 0.09, 0.99)
	cov_st.border_color = Color(0.68, 0.54, 0.30, 0.96)
	cov_st.set_border_width_all(3)
	cov_st.set_corner_radius_all(8)
	cov_st.content_margin_left = 14
	cov_st.content_margin_right = 14
	cov_st.content_margin_top = 14
	cov_st.content_margin_bottom = 14
	cover.add_theme_stylebox_override("panel", cov_st)
	book_row.add_child(cover)

	# TWO-PAGE SPREAD
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 0)
	cover.add_child(spread)

	# LEFT VELVET PARCHMENT PAGE
	var left_page := _make_page_panel()
	spread.add_child(left_page)
	var left_vb := VBoxContainer.new()
	left_vb.add_theme_constant_override("separation", 10)
	left_page.add_child(left_vb)

	_left_title = Label.new()
	_left_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_title.add_theme_font_size_override("font_size", 19)
	_left_title.add_theme_color_override("font_color", Color(0.910, 0.776, 0.478))
	left_vb.add_child(_left_title)
	left_vb.add_child(HSeparator.new())

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vb.add_child(left_scroll)
	_left_list = VBoxContainer.new()
	_left_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_list.add_theme_constant_override("separation", 8)
	left_scroll.add_child(_left_list)

	_stats_lbl = Label.new()
	_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_lbl.add_theme_font_size_override("font_size", 12)
	_stats_lbl.add_theme_color_override("font_color", Color(0.88, 0.62, 0.74))
	left_vb.add_child(_stats_lbl)

	# CENTER BOOK SPINE CREASE
	var spine := ColorRect.new()
	spine.custom_minimum_size = Vector2(14, 0)
	spine.color = Color(0.05, 0.025, 0.055, 0.98)
	spread.add_child(spine)

	# RIGHT VELVET PARCHMENT PAGE
	var right_page := _make_page_panel()
	spread.add_child(right_page)
	var right_vb := VBoxContainer.new()
	right_vb.add_theme_constant_override("separation", 12)
	right_page.add_child(right_vb)

	_right_title = Label.new()
	_right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_title.add_theme_font_size_override("font_size", 20)
	_right_title.add_theme_color_override("font_color", Color(0.910, 0.776, 0.478))
	right_vb.add_child(_right_title)

	_right_icon_holder = CenterContainer.new()
	_right_icon_holder.custom_minimum_size = Vector2(0, 148)
	right_vb.add_child(_right_icon_holder)

	_right_sub = Label.new()
	_right_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right_sub.add_theme_font_size_override("font_size", 13)
	_right_sub.add_theme_color_override("font_color", Color(0.86, 0.66, 0.76))
	right_vb.add_child(_right_sub)

	right_vb.add_child(HSeparator.new())

	_right_body = Label.new()
	_right_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right_body.add_theme_font_size_override("font_size", 14)
	_right_body.add_theme_color_override("font_color", Color(0.937, 0.878, 0.761))
	right_vb.add_child(_right_body)

	var foot := HBoxContainer.new()
	right_vb.add_child(foot)
	var hint := Label.new()
	hint.text = "[Q/E] CHANGE TAB  ·  [J/ESC] CLOSE"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.722, 0.659, 0.604))
	foot.add_child(hint)
	var close_btn := Button.new()
	close_btn.text = " Close "
	close_btn.pressed.connect(close)
	foot.add_child(close_btn)

func _make_page_panel() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.157, 0.094, 0.188, 0.98) # #281830 Velvet Parchment
	st.border_color = Color(0.769, 0.620, 0.353, 0.72)
	st.set_border_width_all(1)
	st.content_margin_left = 22
	st.content_margin_right = 22
	st.content_margin_top = 18
	st.content_margin_bottom = 16
	pc.add_theme_stylebox_override("panel", st)
	var frame := OrnateFrame.new()
	frame.inset = 7.0
	frame.corner_size = 12.0
	pc.add_child(frame)
	return pc

func _refresh_tab() -> void:
	for c in _left_list.get_children():
		c.queue_free()
	_entries.clear()
	var sm := get_node_or_null("/root/SaveManager")
	var desires: int = int(sm.desire_fragments) if sm else 0
	var mem_n: int = sm.unlocked_memories.size() if sm else 0
	var mem_tot: int = sm.MEMORY_CATALOG.size() if sm else 5
	_stats_lbl.text = "♦ %d Desire   ·   ✦ %d/%d Memories" % [desires, mem_n, mem_tot]
	_left_title.text = TABS[_active_tab]["page_title"]

	for i in range(_tab_buttons.size()):
		var active := (i == _active_tab)
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.22, 0.13, 0.26, 0.98) if active else Color(0.11, 0.06, 0.13, 0.92)
		st.border_color = Color(0.910, 0.776, 0.478, 1.0) if active else Color(0.55, 0.44, 0.26, 0.65)
		st.set_border_width_all(2 if active else 1)
		st.corner_radius_top_left = 6
		st.corner_radius_bottom_left = 6
		_tab_buttons[i].add_theme_stylebox_override("normal", st)
		_tab_buttons[i].add_theme_stylebox_override("hover", st)
		_tab_buttons[i].add_theme_color_override("font_color", Color(0.98, 0.88, 0.58) if active else Color(0.76, 0.70, 0.68))
		_tab_buttons[i].text = ("✿ " if active else "") + TABS[i]["label"]

	match _active_tab:
		0: # Quests & Controls
			var chap := str(sm.current_chapter) if sm else "Oz: The Road Home"
			_entries.append({"icon": "dorothy_gingham", "portrait": "res://assets/art/icons/silver_shoes.png", "name": "Current Chapter", "sub": chap, "body": "Follow the Yellow Brick Road, gather your circle, and confront the gilded illusions of Oz."})
			_entries.append({"icon": "dorothy_sovereign", "portrait": "res://assets/art/icons/wicker_basket.png", "name": "Controls & Keybindings", "sub": "Keyboard & Mouse", "body": "WASD / Arrows: Move   ·   Space: Jump / Heel-Blink\nF: Companion Power   ·   C / Z-X: Armaments\nE: Interact / Interiors   ·   B: Tailor of Vices Boutique\n1–5 / Tab: Switch Lead   ·   Q: Party Wheel\nJ: Oz Grimoire   ·   Esc: Pause & Save Slots"})
		1: # Companions
			if sm:
				var icon_map := {"dorothy": "dorothy_gingham", "scarecrow": "scarecrow_classic", "tinman": "tinman_classic", "lion": "lion_classic", "toto": "toto_classic"}
				var port_map := {
					"dorothy": "res://assets/art/portraits/dorothy.png",
					"scarecrow": "res://assets/art/portraits/scarecrow.png",
					"tinman": "res://assets/art/portraits/tinman.png",
					"lion": "res://assets/art/portraits/lion.png",
					"toto": "res://assets/art/portraits/toto.png",
				}
				for comp in sm.COMPANION_CATALOG:
					var cid := str(comp.get("id", ""))
					_entries.append({
						"icon": icon_map.get(cid, "dorothy_gingham"),
						"portrait": port_map.get(cid, ""),
						"name": str(comp["name"]),
						"sub": "%s  ·  %s" % [comp["role"], comp["kit"]],
						"body": str(comp["lore"]),
					})
		2: # Armaments
			for arm in ARMAMENT_LORE:
				_entries.append({"icon": arm["id"], "portrait": arm.get("portrait", ""), "name": arm["name"], "sub": arm["sub"], "body": arm["body"]})
		3: # Bestiary
			if sm:
				for foe in sm.BESTIARY_CATALOG:
					var fn := str(foe["name"]).to_lower()
					var b_port := "res://assets/art/portraits/munchkin_enforcer.png"
					if "marshal" in fn:
						b_port = "res://assets/art/portraits/marshal.png"
					elif "witch" in fn:
						b_port = "res://assets/art/portraits/wicked_witch.png"
					elif "oscar" in fn or "wizard" in fn:
						b_port = "res://assets/art/portraits/oz_hologram.png"
					elif "tree" in fn:
						b_port = "res://assets/art/portraits/living_tree.png"
					elif "monkey" in fn:
						b_port = "res://assets/art/portraits/winged_monkey.png"
					_entries.append({
						"icon": "scarecrow_obsidian",
						"portrait": b_port,
						"name": str(foe["name"]),
						"sub": "%s  ·  %s" % [foe["region"], foe["threat"]],
						"body": str(foe["lore"]),
					})
		4: # Shattered Memories
			if sm:
				var mem_ports := {
					"kansas_locket": "res://assets/art/icons/mem_aunt_em_locket.png",
					"kansas_barn_diary": "res://assets/art/icons/mem_cyclone_ledger.png",
					"munchkin_porcelain_mask": "res://assets/art/icons/mem_porcelain_mask.png",
					"munchkin_silver_ledger": "res://assets/art/icons/mem_guild_ledger.png",
					"emerald_spectacles": "res://assets/art/icons/mem_emerald_spectacles.png",
				}
				for mem_id in sm.MEMORY_CATALOG.keys():
					var entry: Dictionary = sm.MEMORY_CATALOG[mem_id]
					var unlocked: bool = mem_id in sm.unlocked_memories
					if unlocked:
						_entries.append({"icon": "dorothy_sovereign", "portrait": mem_ports.get(mem_id, ""), "name": "✦ " + str(entry["title"]), "sub": str(entry["region"]), "body": str(entry["text"])})
					else:
						_entries.append({"icon": "scarecrow_classic", "name": "✧ [Locked Memory]", "sub": str(entry["region"]), "body": "Explore cottage and farm interiors to recover this shattered memory fragment."})

	_selected_idx = clampi(_selected_idx, 0, maxi(0, _entries.size() - 1))
	for i in range(_entries.size()):
		var ent := _entries[i]
		var is_sel := (i == _selected_idx)
		var row_btn := Button.new()
		row_btn.custom_minimum_size = Vector2(0, 52)
		row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_btn.text = ("✦  " if is_sel else "   ") + str(ent["name"]).to_upper()
		var rst := StyleBoxFlat.new()
		rst.bg_color = Color(0.24, 0.14, 0.28, 0.96) if is_sel else Color(0.12, 0.07, 0.16, 0.84)
		rst.border_color = Color(0.910, 0.776, 0.478, 1.0) if is_sel else Color(0.58, 0.46, 0.28, 0.55)
		rst.set_border_width_all(2 if is_sel else 1)
		rst.set_corner_radius_all(4)
		rst.content_margin_left = 14
		row_btn.add_theme_stylebox_override("normal", rst)
		row_btn.add_theme_stylebox_override("hover", rst)
		row_btn.add_theme_color_override("font_color", Color(0.98, 0.88, 0.58) if is_sel else Color(0.88, 0.82, 0.72))
		var ei := i
		row_btn.pressed.connect(func():
			_selected_idx = ei
			_refresh_tab()
		)
		_left_list.add_child(row_btn)

	_show_right_entry()

func _show_right_entry() -> void:
	for c in _right_icon_holder.get_children():
		c.queue_free()
	if _entries.is_empty():
		_right_title.text = ""
		_right_sub.text = ""
		_right_body.text = ""
		return
	var ent := _entries[_selected_idx]
	_right_title.text = str(ent["name"]).to_upper()
	_right_sub.text = str(ent["sub"])
	_right_body.text = str(ent["body"])
	var port_path: String = str(ent.get("portrait", ""))
	var tex: Texture2D = _load_portrait_texture(port_path)
	if tex != null:
		var frame_pc := PanelContainer.new()
		var fst := StyleBoxFlat.new()
		fst.bg_color = Color(0.10, 0.05, 0.12, 1.0)
		fst.border_color = Color(0.84, 0.68, 0.36, 1.0)
		fst.set_border_width_all(3)
		fst.set_corner_radius_all(6)
		fst.content_margin_left = 4
		fst.content_margin_right = 4
		fst.content_margin_top = 4
		fst.content_margin_bottom = 4
		frame_pc.add_theme_stylebox_override("panel", fst)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(132, 132)
		frame_pc.add_child(tr)
		_right_icon_holder.add_child(frame_pc)
	else:
		var icon := ShopItemIcon.new()
		icon.setup(str(ent.get("icon", "dorothy_gingham")), Color(0.769, 0.620, 0.353), true)
		_right_icon_holder.add_child(icon)

func _load_portrait_texture(res_path: String) -> Texture2D:
	if res_path == "":
		return null
	if ResourceLoader.exists(res_path):
		var loaded := ResourceLoader.load(res_path) as Texture2D
		if loaded != null:
			return loaded
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null
