extends CanvasLayer

## Phase P10: Interactive "The Tailor of Vices" Outfit & Armory Shop UI.
## Toggle with [B] key, from Pause Menu (Esc), or at the Emerald Plaza Boutique!

const ShopItemIcon := preload("res://ui/widgets/shop_item_icon.gd")

var _backdrop: ColorRect
var _panel: PanelContainer
var _balance_lbl: Label
var _tab_buttons: Array[Button] = []
var _items_box: VBoxContainer
var _active_char: String = "dorothy"

const CHAR_TABS := [
	{"id": "dorothy", "label": "Dorothy"},
	{"id": "scarecrow", "label": "Scarecrow"},
	{"id": "tinman", "label": "Tin Man"},
	{"id": "lion", "label": "Lion"},
	{"id": "toto", "label": "Toto"},
]

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			toggle()
			get_viewport().set_input_as_handled()
		elif visible and event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()

func toggle() -> void:
	if visible:
		close()
	else:
		open(_active_char)

func open(char_id: String = "dorothy") -> void:
	_active_char = char_id
	visible = true
	get_tree().paused = true
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()

func close() -> void:
	visible = false
	get_tree().paused = false
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.04, 0.01, 0.05, 0.80)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(780, 520)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.04, 0.11, 0.97)
	st.border_color = Color(0.94, 0.72, 0.34, 0.95)
	st.set_border_width_all(2)
	st.set_corner_radius_all(12)
	st.content_margin_left = 24
	st.content_margin_right = 24
	st.content_margin_top = 18
	st.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", st)
	center.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_panel.add_child(vb)

	var hdr := HBoxContainer.new()
	vb.add_child(hdr)
	var title := Label.new()
	title.text = "✦  THE TAILOR OF VICES  ·  OUTFITS & ARMORY"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.46))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)

	_balance_lbl = Label.new()
	_balance_lbl.add_theme_font_size_override("font_size", 15)
	_balance_lbl.add_theme_color_override("font_color", Color(1.0, 0.56, 0.78))
	hdr.add_child(_balance_lbl)

	var close_btn := Button.new()
	close_btn.text = "  Close (B / Esc)  "
	close_btn.pressed.connect(close)
	hdr.add_child(close_btn)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	vb.add_child(tabs)
	for t in CHAR_TABS:
		var b := Button.new()
		b.text = t["label"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cid: String = t["id"]
		b.pressed.connect(func():
			_active_char = cid
			_refresh()
		)
		tabs.add_child(b)
		_tab_buttons.append(b)

	vb.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)

	_items_box = VBoxContainer.new()
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_items_box)

func _refresh() -> void:
	for c in _items_box.get_children():
		c.queue_free()
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	_balance_lbl.text = "♦ %d Desire Fragments   " % int(sm.desire_fragments)
	for i in range(CHAR_TABS.size()):
		_tab_buttons[i].modulate = Color(1.0, 0.88, 0.48) if CHAR_TABS[i]["id"] == _active_char else Color(0.76, 0.70, 0.84)

	var items: Array = sm.SHOP_CATALOG.get(_active_char, [])
	var equipped_id: String = str(sm.equipped_outfits.get(_active_char, ""))
	for it in items:
		var pc := PanelContainer.new()
		var pst := StyleBoxFlat.new()
		pst.bg_color = Color(0.14, 0.08, 0.18, 0.92)
		pst.border_color = Color(0.95, 0.76, 0.34, 0.85) if str(it["id"]) == equipped_id else Color(0.45, 0.32, 0.52, 0.55)
		pst.set_border_width_all(1)
		pst.set_corner_radius_all(8)
		pst.content_margin_left = 14
		pst.content_margin_right = 14
		pst.content_margin_top = 10
		pst.content_margin_bottom = 10
		pc.add_theme_stylebox_override("panel", pst)
		_items_box.add_child(pc)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		pc.add_child(row)

		var icon := ShopItemIcon.new()
		icon.setup(str(it["id"]), it.get("tint", Color.WHITE), str(it["id"]) == equipped_id)
		row.add_child(icon)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var n_lbl := Label.new()
		n_lbl.text = str(it["name"])
		n_lbl.add_theme_font_size_override("font_size", 16)
		n_lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 0.58))
		info.add_child(n_lbl)

		var p_lbl := Label.new()
		p_lbl.text = str(it["perk"])
		p_lbl.add_theme_font_size_override("font_size", 12)
		p_lbl.add_theme_color_override("font_color", Color(0.86, 0.82, 0.92))
		info.add_child(p_lbl)

		var iid: String = str(it["id"])
		var cost: int = int(it["cost"])
		var owned: bool = iid in sm.owned_items
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(145, 36)
		if iid == equipped_id:
			btn.text = "✓ Equipped"
			btn.disabled = true
		elif owned:
			btn.text = "Equip"
		else:
			btn.text = "Buy (♦ %d)" % cost
			btn.disabled = int(sm.desire_fragments) < cost
		btn.pressed.connect(func():
			if sm.buy_and_equip(_active_char, iid):
				var afx := get_node_or_null("/root/AudioFx")
				if afx and afx.has_method("play"):
					afx.play("buy", -5.0)
				_refresh()
		)
		row.add_child(btn)
