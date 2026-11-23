extends CanvasLayer

## Phase P6 Retail Oz Grimoire / Codex Overlay (Thriveopedia-inspired modular Godot 4 UI).
## Toggle with J key (or from Pause Menu). Tabs: Quests, Companions, Bestiary, Shattered Memories.

var _backdrop: ColorRect
var _panel: PanelContainer
var _tab_bar: HBoxContainer
var _content: VBoxContainer
var _stats_label: Label
var _active_tab: int = 0
var _tab_buttons: Array[Button] = []

const TABS := ["Quests & Controls", "Companions", "Bestiary", "Shattered Memories"]

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
		elif visible and event.keycode == KEY_LEFT:
			_active_tab = (_active_tab - 1 + TABS.size()) % TABS.size()
			_refresh_tab()
			get_viewport().set_input_as_handled()
		elif visible and event.keycode == KEY_RIGHT:
			_active_tab = (_active_tab + 1) % TABS.size()
			_refresh_tab()
			get_viewport().set_input_as_handled()
		elif visible and event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
			_active_tab = event.keycode - KEY_1
			_refresh_tab()
			get_viewport().set_input_as_handled()

func toggle() -> void:
	if visible:
		close()
	else:
		open(_active_tab)

func open(tab_index: int = 0) -> void:
	_active_tab = clampi(tab_index, 0, TABS.size() - 1)
	visible = true
	get_tree().paused = true
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_tab()
	if _active_tab < _tab_buttons.size():
		_tab_buttons[_active_tab].grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.03, 0.02, 0.05, 0.78)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(780, 520)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.10, 0.96)
	style.border_color = Color(0.86, 0.72, 0.34, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 14)
	_panel.add_child(root_vb)

	# Header bar
	var hdr := HBoxContainer.new()
	root_vb.add_child(hdr)
	var title := Label.new()
	title.text = "✦  OZ GRIMOIRE  ·  CODEX"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.48))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 14)
	_stats_label.add_theme_color_override("font_color", Color(0.94, 0.62, 0.78))
	hdr.add_child(_stats_label)

	var close_btn := Button.new()
	close_btn.text = "  Close (J / Esc)  "
	close_btn.pressed.connect(close)
	hdr.add_child(close_btn)

	# Tab Bar
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 8)
	root_vb.add_child(_tab_bar)
	for i in range(TABS.size()):
		var b := Button.new()
		b.text = TABS[i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		b.pressed.connect(func():
			_active_tab = idx
			_refresh_tab()
		)
		_tab_bar.add_child(b)
		_tab_buttons.append(b)

	var sep := HSeparator.new()
	root_vb.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vb.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)

func _refresh_tab() -> void:
	for c in _content.get_children():
		c.queue_free()
	var sm := get_node_or_null("/root/SaveManager")
	var desires: int = int(sm.desire_fragments) if sm else 0
	var mem_n: int = sm.unlocked_memories.size() if sm else 0
	var mem_tot: int = sm.MEMORY_CATALOG.size() if sm else 5
	_stats_label.text = "♦ %d Desire   ·   ✦ %d/%d Memories   " % [desires, mem_n, mem_tot]

	for i in range(_tab_buttons.size()):
		_tab_buttons[i].modulate = Color(1.0, 0.90, 0.55) if i == _active_tab else Color(0.75, 0.72, 0.82)

	match _active_tab:
		0:
			var chap := str(sm.current_chapter) if sm else "Oz: The Road Home"
			_add_card("Current Chapter", chap, "Follow the Yellow Brick Road, gather your circle, and confront the gilded illusion of Oz.")
			_add_card("Controls & Keybindings", "Keyboard & Mouse",
				"Arrows / WASD: Move   ·   Space: Jump / Silver-Shoe Sprint\nF: Companion Signature Power   ·   E: Interact / Enter Interiors / Open Chests\n1–5 / Tab: Switch Party Lead   ·   Q: Companion Quick-Wheel\nJ: Open Oz Grimoire   ·   Esc: Pause & Save/Load Slots")
		1:
			if sm:
				for comp in sm.COMPANION_CATALOG:
					_add_card("%s  —  %s" % [comp["name"], comp["role"]], comp["kit"], comp["lore"])
		2:
			if sm:
				for foe in sm.BESTIARY_CATALOG:
					_add_card("%s  (%s)" % [foe["name"], foe["region"]], foe["threat"], foe["lore"])
		3:
			if sm:
				for mem_id in sm.MEMORY_CATALOG.keys():
					var entry: Dictionary = sm.MEMORY_CATALOG[mem_id]
					var unlocked: bool = mem_id in sm.unlocked_memories
					if unlocked:
						_add_card("✦  %s" % entry["title"], entry["region"], entry["text"])
					else:
						_add_card("✧  [Locked Shattered Memory]", entry["region"], "Explore cottage and farm interiors to recover this memory fragment.")

func _add_card(heading: String, sub: String, body: String) -> void:
	var pc := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.11, 0.08, 0.16, 0.88)
	st.border_color = Color(0.55, 0.44, 0.24, 0.55)
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	pc.add_theme_stylebox_override("panel", st)
	_content.add_child(pc)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pc.add_child(vb)

	var h := Label.new()
	h.text = heading
	h.add_theme_font_size_override("font_size", 16)
	h.add_theme_color_override("font_color", Color(0.98, 0.86, 0.54))
	vb.add_child(h)

	var s := Label.new()
	s.text = sub
	s.add_theme_font_size_override("font_size", 12)
	s.add_theme_color_override("font_color", Color(0.82, 0.62, 0.78))
	vb.add_child(s)

	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color(0.88, 0.86, 0.92))
	vb.add_child(b)
