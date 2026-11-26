extends CanvasLayer

## Phase P3.3: The Oz Grimoire / Codex — Reference-True Open Two-Page Antique Leather Book (ref_01_grimoire_ui.jpg).
## Features:
## - GPU Purple-Velvet Aged Parchment Shader (ui_book_parchment.gdshader) with spine shadow & deckle edges
## - Stacked cream-parchment page-fan edges + 3 sculpted antique-brass clasps on right cover
## - Left-edge leather bookmark tabs with glowing Silver-Rose emblem on active tab
## - 6 Tabs: Quests & Vile Requests · Companions · Armaments · Curios · Bestiary · Shattered Memories
## - Generous >= 30px safe-zone margins so text never touches Art-Nouveau corner scrolls!

const OrnateFrame := preload("res://ui/widgets/ornate_frame.gd")
const GothicCrest := preload("res://ui/widgets/gothic_crest.gd")
const ShopItemIcon := preload("res://ui/widgets/shop_item_icon.gd")
const OzThemeFactory := preload("res://ui/theme/oz_theme_factory.gd")
const FrostedShader := preload("res://ui/shaders/frosted_velvet_backdrop.gdshader")
const ParchmentShader := preload("res://ui/shaders/ui_book_parchment.gdshader")

class BookmarkRibbon extends Control:
	func _draw() -> void:
		var pts := PackedVector2Array([
			Vector2(10, 0),
			Vector2(30, 0),
			Vector2(24, size.y - 4),
			Vector2(14, size.y - 18),
			Vector2(4, size.y),
		])
		var sh := PackedVector2Array()
		for p in pts:
			sh.append(p + Vector2(3, 5))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.48))
		draw_colored_polygon(pts, Color(0.84, 0.68, 0.32, 0.96))
		draw_line(Vector2(16, 0), Vector2(11, size.y - 16), Color(0.98, 0.88, 0.56, 0.76), 1.6, true)

class BrassBookClasps extends Control:
	func _draw() -> void:
		var brass := Color(0.68, 0.54, 0.30, 0.98)
		var hi := Color(0.92, 0.78, 0.46, 0.98)
		var dark := Color(0.24, 0.17, 0.09, 0.98)
		for frac in [0.18, 0.50, 0.82]:
			var cy := size.y * float(frac)
			var r := Rect2(0, cy - 22, 26, 44)
			draw_rect(r, brass, true)
			draw_rect(r, dark, false, 1.8)
			draw_line(Vector2(3, cy - 18), Vector2(3, cy + 18), hi, 1.6)
			# Keyhole hasp loop extending right
			draw_circle(Vector2(27, cy), 10.0, brass)
			draw_circle(Vector2(27, cy), 4.2, Color(0.06, 0.03, 0.07, 1.0))
			draw_circle(Vector2(10, cy - 12), 2.2, hi)
			draw_circle(Vector2(10, cy + 12), 2.2, hi)

const TABS := [
	{"id": "quests", "label": "QUESTS", "page_title": "CHRONICLES & VILE REQUESTS"},
	{"id": "companions", "label": "COMPANIONS", "page_title": "THE COMPANIONS OF THE ROAD"},
	{"id": "armaments", "label": "ARMAMENTS", "page_title": "TOOLS OF ALLURE & COMBAT"},
	{"id": "curios", "label": "CURIOS", "page_title": "SILVER-SHOE RELICS & CHARMS"},
	{"id": "bestiary", "label": "BESTIARY", "page_title": "DENIZENS & FOES OF OZ"},
	{"id": "memories", "label": "SHATTERED\nMEMORIES", "page_title": "SHATTERED MEMORIES"},
]

const ARMAMENT_LORE := [
	{"id": "dorothy_whip_plus", "portrait": "res://assets/art/icons/arm_whip.png", "name": "The Lace Whip", "sub": "Slot 1 · Bind & Yank [C]", "body": "ORIGIN & PURPOSE\nA braided crimson-silk lash with an engraved brass rose hilt and faceted ruby tip that snares distant foes and drags them straight into Silver-Shoe Kick range.\n\nCOMBAT SYNERGY\nBinds snared targets for 2.2s, opening them to +35% Thorn of Allure bonus damage."},
	{"id": "dorothy_velvet", "portrait": "res://assets/art/icons/arm_ribbon.png", "name": "Silk Bindings", "sub": "Slot 2 · Multi-Cocoon [C]", "body": "ORIGIN & PURPOSE\nUnspools iridescent dusty-rose and lavender silk ribbon embroidered with glowing golden knotwork around up to three nearby foes.\n\nCOMBAT SYNERGY\nImmobilizes packs and accelerates Allure buildup toward Rapture Mode [H]."},
	{"id": "dorothy_sovereign", "portrait": "res://assets/art/icons/arm_atomizer.png", "name": "Hypnotic Perfume", "sub": "Slot 3 · Enamored Mist [C]", "body": "ORIGIN & PURPOSE\nSprays a shimmering amethyst-violet and rose narcotic mist from a filigree crystal atomizer.\n\nCOMBAT SYNERGY\nCaught enemies become ♥ ENAMORED, pausing their assault in dazed devotion while yielding bonus Desire Fragments."},
	{"id": "lion_primal", "portrait": "res://assets/art/icons/arm_chain.png", "name": "The Gilded Chain", "sub": "Slot 4 · Damage Tether [C]", "body": "ORIGIN & PURPOSE\nLinks the two nearest adversaries in hammered antique-gold links and engraved rose-copper shackle clasps.\n\nCOMBAT SYNERGY\n75% of all damage dealt to one tethered enemy mirrors directly onto the other."},
]

var _backdrop: ColorRect
var _book_wrap: HBoxContainer
var _tab_buttons: Array[Button] = []
var _rose_tab_icon: Control
var _left_title: Label
var _left_list: VBoxContainer
var _right_title: Label
var _right_icon_holder: CenterContainer
var _right_sub: Label
var _right_body: Label
var _stats_lbl: Label
var _equip_curio_btn: Button
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
		elif visible and event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]:
			_switch_tab(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()

func _switch_tab(idx: int) -> void:
	_active_tab = clampi(idx, 0, TABS.size() - 1)
	_selected_idx = 0
	var afx := get_node_or_null("/root/AudioFx")
	if afx and afx.has_method("play"):
		afx.play("page_turn", -7.0)
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
		if _book_wrap:
			_book_wrap.pivot_offset = _book_wrap.size * 0.5
			_book_wrap.scale = Vector2(0.95, 0.95)
			var tw := create_tween()
			tw.tween_property(_book_wrap, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_refresh_tab()

func close() -> void:
	visible = false
	get_tree().paused = false
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.035, 0.015, 0.045, 0.90)
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		var bmat := ShaderMaterial.new()
		bmat.shader = FrostedShader
		_backdrop.material = bmat
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_book_wrap = HBoxContainer.new()
	_book_wrap.add_theme_constant_override("separation", 0)
	center.add_child(_book_wrap)

	# LEFT-EDGE STITCHED LEATHER BOOKMARK TABS (ref_01_grimoire_ui.jpg)
	var tab_col := VBoxContainer.new()
	tab_col.custom_minimum_size = Vector2(138, 0)
	tab_col.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_col.add_theme_constant_override("separation", 8)
	_book_wrap.add_child(tab_col)

	for i in range(TABS.size()):
		var b := Button.new()
		b.custom_minimum_size = Vector2(134, 54)
		b.text = TABS[i]["label"]
		var idx := i
		b.pressed.connect(func(): _switch_tab(idx))
		tab_col.add_child(b)
		_tab_buttons.append(b)

	# ANTIQUE LEATHER COVER FRAME + BRASS CORNER PLATES
	var cover := PanelContainer.new()
	cover.custom_minimum_size = Vector2(960, 610)
	var cov_st := StyleBoxFlat.new()
	cov_st.bg_color = Color(0.11, 0.068, 0.062, 0.99) # Deep antique leather
	cov_st.border_color = Color(0.72, 0.58, 0.32, 0.98)
	cov_st.set_border_width_all(4)
	cov_st.set_corner_radius_all(8)
	cov_st.content_margin_left = 10
	cov_st.content_margin_right = 10
	cov_st.content_margin_top = 12
	cov_st.content_margin_bottom = 12
	cov_st.shadow_size = 36
	cov_st.shadow_color = Color(0, 0, 0, 0.78)
	cov_st.shadow_offset = Vector2(0, 12)
	cover.add_theme_stylebox_override("panel", cov_st)
	_book_wrap.add_child(cover)

	# RIGHT-EDGE BRASS CLASPS & HINGES (ref_01_grimoire_ui.jpg)
	var clasps := BrassBookClasps.new()
	clasps.custom_minimum_size = Vector2(38, 580)
	clasps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_wrap.add_child(clasps)

	# STACKED AGED PAGE-FAN STRIPS + TWO-PAGE SPREAD
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 0)
	cover.add_child(spread)

	# Left stacked paper fan edge
	var left_fan := ColorRect.new()
	left_fan.custom_minimum_size = Vector2(8, 0)
	left_fan.color = Color(0.56, 0.48, 0.38, 0.92)
	spread.add_child(left_fan)

	# LEFT VELVET PARCHMENT PAGE
	var left_page := _make_page_panel(true)
	spread.add_child(left_page)
	var left_vb := VBoxContainer.new()
	left_vb.add_theme_constant_override("separation", 10)
	left_page.add_child(left_vb)

	_left_title = Label.new()
	_left_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_title.add_theme_font_size_override("font_size", 19)
	_left_title.add_theme_color_override("font_color", Color(0.93, 0.80, 0.50))
	left_vb.add_child(_left_title)
	left_vb.add_child(HSeparator.new())

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vb.add_child(left_scroll)
	_left_list = VBoxContainer.new()
	_left_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_list.add_theme_constant_override("separation", 8)
	left_scroll.add_child(_left_list)

	_stats_lbl = Label.new()
	_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_lbl.add_theme_font_size_override("font_size", 12)
	_stats_lbl.add_theme_color_override("font_color", Color(0.88, 0.76, 0.52))
	left_vb.add_child(_stats_lbl)

	# CENTER BOOK SPINE CREASE
	var spine := ColorRect.new()
	spine.custom_minimum_size = Vector2(12, 0)
	spine.color = Color(0.045, 0.020, 0.052, 0.99)
	spread.add_child(spine)

	# RIGHT VELVET PARCHMENT PAGE + Draping Golden Silk Bookmark Ribbon
	var right_page := _make_page_panel(false)
	spread.add_child(right_page)

	# Right stacked paper fan edge
	var right_fan := ColorRect.new()
	right_fan.custom_minimum_size = Vector2(8, 0)
	right_fan.color = Color(0.56, 0.48, 0.38, 0.92)
	spread.add_child(right_fan)

	var ribbon := BookmarkRibbon.new()
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ribbon.offset_left = -46.0
	ribbon.offset_right = -14.0
	ribbon.offset_top = 8.0
	ribbon.offset_bottom = 140.0
	# Attach to outer cover (not right_page PanelContainer) so PanelContainer never pulls it over text!
	var rib_overlay := Control.new()
	rib_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rib_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	rib_overlay.add_child(ribbon)
	cover.add_child(rib_overlay)

	var right_vb := VBoxContainer.new()
	right_vb.add_theme_constant_override("separation", 10)
	right_page.add_child(right_vb)

	_right_title = Label.new()
	_right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_title.add_theme_font_size_override("font_size", 20)
	_right_title.add_theme_color_override("font_color", Color(0.93, 0.80, 0.50))
	right_vb.add_child(_right_title)

	_right_icon_holder = CenterContainer.new()
	_right_icon_holder.custom_minimum_size = Vector2(0, 144)
	right_vb.add_child(_right_icon_holder)

	_right_sub = Label.new()
	_right_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right_sub.add_theme_font_size_override("font_size", 13)
	_right_sub.add_theme_color_override("font_color", Color(0.86, 0.72, 0.54))
	right_vb.add_child(_right_sub)

	right_vb.add_child(HSeparator.new())

	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vb.add_child(body_scroll)

	_right_body = Label.new()
	_right_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right_body.add_theme_font_size_override("font_size", 13)
	_right_body.add_theme_color_override("font_color", Color(0.937, 0.878, 0.761))
	body_scroll.add_child(_right_body)

	_equip_curio_btn = Button.new()
	_equip_curio_btn.visible = false
	_equip_curio_btn.custom_minimum_size = Vector2(0, 38)
	OzThemeFactory.style_gothic_plaque_button(_equip_curio_btn, true, false, 13)
	_equip_curio_btn.pressed.connect(_on_equip_curio)
	right_vb.add_child(_equip_curio_btn)

	var foot := HBoxContainer.new()
	right_vb.add_child(foot)
	var hint := Label.new()
	hint.text = "[CLICK] SELECT  ·  [Q/E] CHANGE TAB  ·  [J/ESC] CLOSE GRIMOIRE"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.722, 0.659, 0.604))
	foot.add_child(hint)
	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	OzThemeFactory.style_gothic_plaque_button(close_btn, false, false, 11)
	close_btn.pressed.connect(close)
	foot.add_child(close_btn)

	_rose_tab_icon = GothicCrest.new()
	_rose_tab_icon.mode = "rose_cursor"
	_rose_tab_icon.size = Vector2(22, 22)
	add_child(_rose_tab_icon)

func _make_page_panel(is_left: bool) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(452, 586)
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pc.clip_contents = true
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.165, 0.098, 0.198, 0.99)
	st.border_color = Color(0.769, 0.620, 0.353, 0.72)
	st.set_border_width_all(1)
	# Generous >= 32px safe-zone margins so text NEVER collides with Art-Nouveau corner scrolls!
	st.content_margin_left = 34
	st.content_margin_right = 34
	st.content_margin_top = 28
	st.content_margin_bottom = 24
	pc.add_theme_stylebox_override("panel", st)
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		var bg_rect := ColorRect.new()
		bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pmat := ShaderMaterial.new()
		pmat.shader = ParchmentShader
		pmat.set_shader_parameter("is_left_page", 1.0 if is_left else 0.0)
		bg_rect.material = pmat
		# Expand shader backdrop slightly to cover outer page bounds
		pc.draw.connect(func():
			bg_rect.position = -bg_rect.position + Vector2.ZERO
		)
	var frame := OrnateFrame.new()
	frame.outer_pad = 10.0
	frame.inset = 5.0
	frame.corner_size = 15.0
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
	var q_done: int = sm.completed_quests.size() if sm else 0
	var q_tot: int = sm.SIDE_QUEST_CATALOG.size() if sm else 6
	_stats_lbl.text = "♦ %d Desire  ·  ◈ %d/%d Requests  ·  ✦ %d/%d Memories" % [desires, q_done, q_tot, mem_n, mem_tot]
	_left_title.text = TABS[_active_tab]["page_title"]

	for i in range(_tab_buttons.size()):
		var active := (i == _active_tab)
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.245, 0.155, 0.285, 0.99) if active else Color(0.115, 0.072, 0.135, 0.94)
		st.border_color = Color(0.95, 0.82, 0.50, 1.0) if active else Color(0.55, 0.44, 0.26, 0.65)
		st.set_border_width_all(2 if active else 1)
		st.border_width_right = 0
		st.corner_radius_top_left = 6
		st.corner_radius_bottom_left = 6
		st.shadow_size = 12 if active else 0
		st.shadow_color = Color(0.96, 0.82, 0.44, 0.28)
		_tab_buttons[i].add_theme_stylebox_override("normal", st)
		_tab_buttons[i].add_theme_stylebox_override("hover", st)
		_tab_buttons[i].add_theme_font_size_override("font_size", 11)
		_tab_buttons[i].add_theme_color_override("font_color", Color(0.99, 0.92, 0.72) if active else Color(0.76, 0.70, 0.66))
		_tab_buttons[i].text = ("   " if active else "") + TABS[i]["label"]
		if active and _rose_tab_icon and DisplayServer.get_name() not in ["headless", "Dummy"]:
			var b := _tab_buttons[i]
			_rose_tab_icon.call_deferred("set_global_position", b.global_position + Vector2(8, (b.size.y - 22) * 0.5))

	match _active_tab:
		0: # Quests, Controls & Vile Requests
			var chap := str(sm.current_chapter) if sm else "Oz: The Road Home"
			_entries.append({"icon": "dorothy_gingham", "portrait": "res://assets/art/icons/silver_shoes.png", "name": "Main Chronicle", "sub": chap, "body": "ORIGIN & PURPOSE\nFollow the Yellow Brick Road across seven acts, bind the lost companions to your circle, shatter the gilded illusions of Oz, and claim your road home.\n\nCONTROLS & TACTICS\nWASD / Arrows: Move  ·  Right-Stick / Mouse: 360° Camera\nSpace: Jump / Silver Mirage Dodge  ·  F: Lead Power\nC / Z-X: Kinky Armaments  ·  G: Emerald Spectacles\n1–5 / Tab / Q: Swap Companion  ·  B: Boutique  ·  Esc: Pause"})
			if sm:
				for qid in sm.SIDE_QUEST_CATALOG.keys():
					var qm: Dictionary = sm.SIDE_QUEST_CATALOG[qid]
					var done: bool = qid in sm.completed_quests
					var cur: int = int(sm.quest_progress.get(qid, 0))
					var goal: int = int(qm.get("goal", 1))
					var status_str := "✓ COMPLETED (+%d Desire)" % int(qm["reward"]) if done else "Progress: %d / %d  ·  Reward: ♦ %d Desire" % [cur, goal, int(qm["reward"])]
					_entries.append({
						"icon": "dorothy_velvet" if done else "scarecrow_classic",
						"portrait": "res://assets/art/icons/desire_chest.png",
						"name": ("✓ " if done else "◈ ") + str(qm["title"]),
						"sub": status_str,
						"body": str(qm["desc"]) + "\n\nCompleting Vile Requests restores full Silver-Rose Vitality and awards bonus Desire Fragments.",
					})
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
						"body": "ORIGIN & PURPOSE\n%s\n\nTHE BONDS OF THE ROAD\nSwitch seamlessly with [1–5] or [Tab] to solve regional synergy puzzles and chain Style Rank combos." % str(comp["lore"]),
					})
		2: # Armaments
			for arm in ARMAMENT_LORE:
				_entries.append({"icon": arm["id"], "portrait": arm.get("portrait", ""), "name": arm["name"], "sub": arm["sub"], "body": arm["body"]})
		3: # Silver-Shoe Curios / Charms
			if sm:
				var eq_charm := str(sm.equipped_outfits.get("charms", ""))
				for ch in sm.SHOP_CATALOG.get("charms", []):
					var cid := str(ch["id"])
					var owned: bool = cid in sm.owned_items
					var is_eq: bool = (cid == eq_charm)
					_entries.append({
						"charm_id": cid,
						"owned": owned,
						"equipped": is_eq,
						"icon": cid,
						"portrait": "res://assets/art/icons/silver_shoes.png",
						"name": ("★ " if is_eq else ("" if owned else "🔒 ")) + str(ch["name"]),
						"sub": "EQUIPPED CURIO" if is_eq else ("OWNED — Click Below to Equip" if owned else "Find in Velvet Sanctums or Boutique (♦ %d)" % int(ch["cost"])),
						"body": "%s\n\nHidden Velvet Sanctums across Oz or The Tailor of Vices Boutique [B] grant Silver-Shoe Curios that permanently augment your combat kit." % str(ch["perk"]),
					})
		4: # Bestiary
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
					elif "kalidah" in fn:
						b_port = "res://assets/art/portraits/kalidah_beast.png"
					elif "spider" in fn:
						b_port = "res://assets/art/portraits/giant_spider.png"
					_entries.append({
						"icon": "scarecrow_obsidian",
						"portrait": b_port,
						"name": str(foe["name"]),
						"sub": "%s  ·  %s" % [foe["region"], foe["threat"]],
						"body": str(foe["lore"]),
					})
		5: # Shattered Memories
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
						_entries.append({"icon": "scarecrow_classic", "name": "✧ [Locked Memory]", "sub": str(entry["region"]), "body": "Explore cottage interiors, Toto scent caches, and Velvet Sanctums to recover this shattered memory."})

	_selected_idx = clampi(_selected_idx, 0, maxi(0, _entries.size() - 1))
	for i in range(_entries.size()):
		var ent := _entries[i]
		var is_sel := (i == _selected_idx)
		var row_btn := Button.new()
		row_btn.custom_minimum_size = Vector2(0, 56)
		row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_btn.text = ("▸  " if is_sel else "   ") + str(ent["name"]).to_upper()
		var r_tex := _load_portrait_texture(str(ent.get("portrait", "")))
		if r_tex != null:
			row_btn.icon = r_tex
			row_btn.expand_icon = true
		var rst := StyleBoxFlat.new()
		rst.bg_color = Color(0.245, 0.155, 0.285, 0.97) if is_sel else Color(0.125, 0.075, 0.165, 0.86)
		rst.border_color = Color(0.95, 0.82, 0.50, 1.0) if is_sel else Color(0.62, 0.50, 0.30, 0.60)
		rst.set_border_width_all(2 if is_sel else 1)
		rst.set_corner_radius_all(5)
		rst.content_margin_left = 12
		rst.content_margin_right = 12
		rst.content_margin_top = 7
		rst.content_margin_bottom = 7
		rst.shadow_size = 10 if is_sel else 0
		rst.shadow_color = Color(0.96, 0.82, 0.44, 0.26)
		row_btn.add_theme_stylebox_override("normal", rst)
		row_btn.add_theme_stylebox_override("hover", rst)
		row_btn.add_theme_font_size_override("font_size", 13)
		row_btn.add_theme_color_override("font_color", Color(0.99, 0.92, 0.68) if is_sel else Color(0.90, 0.84, 0.74))
		var ei := i
		row_btn.pressed.connect(func():
			_selected_idx = ei
			var afx := get_node_or_null("/root/AudioFx")
			if afx and afx.has_method("play"):
				afx.play("page_turn", -9.0)
			_refresh_tab()
		)
		_left_list.add_child(row_btn)

	_show_right_entry()

func _show_right_entry() -> void:
	for c in _right_icon_holder.get_children():
		c.queue_free()
	_equip_curio_btn.visible = false
	if _entries.is_empty():
		_right_title.text = ""
		_right_sub.text = ""
		_right_body.text = ""
		return
	var ent := _entries[_selected_idx]
	_right_title.text = str(ent["name"]).to_upper()
	_right_sub.text = str(ent["sub"])
	_right_body.text = str(ent["body"])
	if ent.has("charm_id") and bool(ent.get("owned", false)):
		_equip_curio_btn.visible = true
		_equip_curio_btn.disabled = bool(ent.get("equipped", false))
		_equip_curio_btn.text = "✓ CURIO EQUIPPED" if bool(ent.get("equipped", false)) else "✦ EQUIP THIS CURIO"

	var port_path: String = str(ent.get("portrait", ""))
	var tex: Texture2D = _load_portrait_texture(port_path)
	if tex != null:
		var frame_pc := PanelContainer.new()
		var fst := StyleBoxFlat.new()
		fst.bg_color = Color(0.10, 0.055, 0.125, 1.0)
		fst.border_color = Color(0.88, 0.72, 0.38, 1.0)
		fst.set_border_width_all(3)
		fst.set_corner_radius_all(6)
		fst.content_margin_left = 8
		fst.content_margin_right = 8
		fst.content_margin_top = 8
		fst.content_margin_bottom = 8
		fst.shadow_size = 14
		fst.shadow_color = Color(0, 0, 0, 0.55)
		frame_pc.add_theme_stylebox_override("panel", fst)
		var p_orn := OrnateFrame.new()
		p_orn.outer_pad = 3.0
		p_orn.inset = 3.0
		p_orn.corner_size = 9.0
		p_orn.show_diamonds = false
		frame_pc.add_child(p_orn)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(126, 126)
		frame_pc.add_child(tr)
		_right_icon_holder.add_child(frame_pc)
	else:
		var icon := ShopItemIcon.new()
		icon.setup(str(ent.get("icon", "dorothy_gingham")), Color(0.769, 0.620, 0.353), true)
		_right_icon_holder.add_child(icon)

func _on_equip_curio() -> void:
	if _entries.is_empty():
		return
	var ent := _entries[_selected_idx]
	var cid := str(ent.get("charm_id", ""))
	var sm := get_node_or_null("/root/SaveManager")
	if sm and cid != "":
		sm.buy_and_equip("charms", cid)
		_refresh_tab()

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
