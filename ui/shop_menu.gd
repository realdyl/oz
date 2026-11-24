extends CanvasLayer

## Phase P1.1: "The Tailor of Vices" — Retail Split-Screen 3D Boutique Stage & Armory.
## Left: Live 3D SubViewport rotating marble pedestal (drag to spin + hover to preview outfits live!).
## Right: 5 character tabs + 64x64 illustrated gilded medallion cards + Stat Comparison Strip.
## Toggle with [B] key, from Pause Menu (Esc), or at the Emerald Plaza Boutique!

const ShopItemIcon := preload("res://ui/widgets/shop_item_icon.gd")
const TotoCompanion := preload("res://actors/companions/toto_companion.gd")

const VISUAL_SCRIPTS := {
	"dorothy": preload("res://actors/dorothy/dorothy_visual.gd"),
	"scarecrow": preload("res://actors/companions/scarecrow_visual.gd"),
	"tinman": preload("res://actors/companions/tinman_visual.gd"),
	"lion": preload("res://actors/companions/lion_visual.gd"),
}

var _backdrop: ColorRect
var _panel: PanelContainer
var _balance_lbl: Label
var _tab_buttons: Array[Button] = []
var _items_box: VBoxContainer
var _active_char: String = "dorothy"

# Phase P1.1: Live 3D Boutique Turntable Stage
var _vp_container: SubViewportContainer
var _vp: SubViewport
var _turntable: Node3D
var _preview_actor: Node3D
var _preview_name_lbl: Label
var _stat_allure: ProgressBar
var _stat_agility: ProgressBar
var _stat_power: ProgressBar
var _dragging_stage: bool = false
var _last_drag_x: float = 0.0
var _spin_yaw: float = 0.35

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

func _process(delta: float) -> void:
	if not visible or _turntable == null or not is_instance_valid(_turntable):
		return
	if not _dragging_stage:
		_spin_yaw += delta * 0.55
	_turntable.rotation.y = _spin_yaw

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
	_dragging_stage = false
	get_tree().paused = false
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.04, 0.01, 0.05, 0.82)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(980, 560)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.04, 0.11, 0.97)
	st.border_color = Color(0.94, 0.72, 0.34, 0.95)
	st.set_border_width_all(2)
	st.set_corner_radius_all(12)
	st.content_margin_left = 22
	st.content_margin_right = 22
	st.content_margin_top = 18
	st.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", st)
	center.add_child(_panel)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 12)
	_panel.add_child(root_vb)

	# Header
	var hdr := HBoxContainer.new()
	root_vb.add_child(hdr)
	var title := Label.new()
	title.text = "✦  THE TAILOR OF VICES  ·  BOUTIQUE & ARMORY"
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

	# Character Tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root_vb.add_child(tabs)
	for t in CHAR_TABS:
		var b := Button.new()
		b.text = t["label"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cid: String = t["id"]
		b.pressed.connect(func():
			_active_char = cid
			var afx := get_node_or_null("/root/AudioFx")
			if afx and afx.has_method("play"):
				afx.play("ui_click", -8.0)
			_refresh()
		)
		tabs.add_child(b)
		_tab_buttons.append(b)

	root_vb.add_child(HSeparator.new())

	# Split-Screen Body: Left 3D Turntable Stage | Right Illustrated Catalog
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	root_vb.add_child(split)

	# LEFT: 3D Boutique Turntable + Stat Comparison Strip
	var stage_col := VBoxContainer.new()
	stage_col.custom_minimum_size = Vector2(300, 0)
	stage_col.add_theme_constant_override("separation", 8)
	split.add_child(stage_col)

	var stage_frame := PanelContainer.new()
	stage_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sf_st := StyleBoxFlat.new()
	sf_st.bg_color = Color(0.06, 0.02, 0.09, 1.0)
	sf_st.border_color = Color(0.76, 0.58, 0.30, 0.85)
	sf_st.set_border_width_all(1)
	sf_st.set_corner_radius_all(8)
	stage_frame.add_theme_stylebox_override("panel", sf_st)
	stage_col.add_child(stage_frame)

	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		_vp_container = SubViewportContainer.new()
		_vp_container.stretch = true
		_vp_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_vp_container.gui_input.connect(_on_stage_input)
		stage_frame.add_child(_vp_container)

		_vp = SubViewport.new()
		_vp.own_world_3d = true
		_vp.transparent_bg = false
		_vp.msaa_3d = Viewport.MSAA_2X
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_vp_container.add_child(_vp)
		_build_turntable_world()

	_preview_name_lbl = Label.new()
	_preview_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_name_lbl.add_theme_font_size_override("font_size", 14)
	_preview_name_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.52))
	_preview_name_lbl.text = "Drag stage to rotate · Hover to preview"
	stage_col.add_child(_preview_name_lbl)

	# Stat Comparison Strip
	var stats_panel := PanelContainer.new()
	var sp_st := StyleBoxFlat.new()
	sp_st.bg_color = Color(0.12, 0.06, 0.16, 0.90)
	sp_st.border_color = Color(0.48, 0.34, 0.56, 0.55)
	sp_st.set_border_width_all(1)
	sp_st.set_corner_radius_all(6)
	sp_st.content_margin_left = 10
	sp_st.content_margin_right = 10
	sp_st.content_margin_top = 8
	sp_st.content_margin_bottom = 8
	stats_panel.add_theme_stylebox_override("panel", sp_st)
	stage_col.add_child(stats_panel)

	var stats_vb := VBoxContainer.new()
	stats_vb.add_theme_constant_override("separation", 5)
	stats_panel.add_child(stats_vb)
	_stat_allure = _make_stat_bar(stats_vb, "Allure Gain", Color(0.98, 0.34, 0.62))
	_stat_agility = _make_stat_bar(stats_vb, "Agility / Aura", Color(0.45, 0.82, 1.0))
	_stat_power = _make_stat_bar(stats_vb, "Combat Edge", Color(0.98, 0.78, 0.30))

	# RIGHT: Scrollable Illustrated Catalog
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)

	_items_box = VBoxContainer.new()
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_items_box)

func _make_stat_bar(parent: VBoxContainer, label_txt: String, fill_col: Color) -> ProgressBar:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	parent.add_child(hb)
	var l := Label.new()
	l.text = label_txt
	l.custom_minimum_size = Vector2(96, 0)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.88, 0.84, 0.94))
	hb.add_child(l)
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 12)
	bar.max_value = 100.0
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.03, 0.08, 0.9)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill_col
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	hb.add_child(bar)
	return bar

func _build_turntable_world() -> void:
	if _vp == null:
		return
	var stage := Node3D.new()
	stage.name = "BoutiqueStage"
	_vp.add_child(stage)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.07, 0.03, 0.10)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.34, 0.52)
	e.ambient_light_energy = 0.95
	env.environment = e
	stage.add_child(env)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.92, 0.80)
	key.light_energy = 1.45
	key.rotation_degrees = Vector3(-32, 28, 0)
	stage.add_child(key)

	var rim := OmniLight3D.new()
	rim.light_color = Color(1.0, 0.28, 0.56)
	rim.light_energy = 2.6
	rim.omni_range = 8.0
	rim.position = Vector3(-1.8, 1.9, -1.6)
	stage.add_child(rim)

	var cam := Camera3D.new()
	cam.fov = 38.0
	cam.position = Vector3(0.0, 1.12, 3.15)
	cam.look_at(Vector3(0.0, 0.82, 0.0), Vector3.UP)
	cam.current = true
	stage.add_child(cam)

	_turntable = Node3D.new()
	_turntable.name = "Turntable"
	stage.add_child(_turntable)

	# Gilded Marble Pedestal
	var ped := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.78
	cyl.bottom_radius = 0.88
	cyl.height = 0.22
	ped.mesh = cyl
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.20, 0.14, 0.24)
	pm.roughness = 0.28
	pm.metallic = 0.25
	ped.material_override = pm
	ped.position = Vector3(0, -0.11, 0)
	_turntable.add_child(ped)

	var ring := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.81
	rc.bottom_radius = 0.81
	rc.height = 0.04
	ring.mesh = rc
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.95, 0.76, 0.34)
	rm.metallic = 0.85
	rm.roughness = 0.22
	ring.material_override = rm
	ring.position = Vector3(0, -0.01, 0)
	_turntable.add_child(ring)

func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging_stage = event.pressed
		_last_drag_x = event.position.x
	elif event is InputEventMouseMotion and _dragging_stage:
		var dx: float = event.position.x - _last_drag_x
		_last_drag_x = event.position.x
		_spin_yaw += dx * 0.015

func _rebuild_preview_actor(tint: Color) -> void:
	if _turntable == null or not is_instance_valid(_turntable):
		return
	if _preview_actor and is_instance_valid(_preview_actor):
		_preview_actor.queue_free()
		_preview_actor = null
	var actor := Node3D.new()
	actor.name = "PreviewActor"
	if _active_char == "toto":
		TotoCompanion.build_dog_visual(actor, false)
		actor.scale = Vector3(1.55, 1.55, 1.55)
	elif VISUAL_SCRIPTS.has(_active_char):
		actor.set_script(VISUAL_SCRIPTS[_active_char])
	_turntable.add_child(actor)
	_preview_actor = actor
	_apply_preview_tint(tint)

func _apply_preview_tint(tint: Color) -> void:
	if _preview_actor == null or not is_instance_valid(_preview_actor):
		return
	for mi in _preview_actor.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m and m.material_override is StandardMaterial3D:
			var dup := (m.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			dup.albedo_color = dup.albedo_color.lerp(tint, 0.56)
			m.material_override = dup

func _update_stats_for_item(it: Dictionary) -> void:
	var cost: int = int(it.get("cost", 0))
	var iid: String = str(it.get("id", ""))
	var allure_v := 40.0 + float(cost) * 1.1
	var agil_v := 45.0 + (35.0 if ("sovereign" in iid or "collar" in iid or "leather" in iid) else float(cost) * 0.65)
	var pow_v := 45.0 + (45.0 if ("whip" in iid or "velvet" in iid or "primal" in iid or "obsidian" in iid) else float(cost) * 0.55)
	if _stat_allure:
		_stat_allure.value = clampf(allure_v, 10.0, 100.0)
	if _stat_agility:
		_stat_agility.value = clampf(agil_v, 10.0, 100.0)
	if _stat_power:
		_stat_power.value = clampf(pow_v, 10.0, 100.0)
	if _preview_name_lbl:
		_preview_name_lbl.text = "%s  ·  Drag to Spin" % str(it.get("name", ""))

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
	var active_item: Dictionary = items[0] if not items.is_empty() else {}
	for it in items:
		if str(it.get("id", "")) == equipped_id:
			active_item = it
			break
	if not active_item.is_empty():
		_rebuild_preview_actor(active_item.get("tint", Color.WHITE))
		_update_stats_for_item(active_item)

	for it in items:
		var pc := PanelContainer.new()
		var pst := StyleBoxFlat.new()
		pst.bg_color = Color(0.14, 0.08, 0.18, 0.92)
		pst.border_color = Color(0.95, 0.76, 0.34, 0.85) if str(it["id"]) == equipped_id else Color(0.45, 0.32, 0.52, 0.55)
		pst.set_border_width_all(1)
		pst.set_corner_radius_all(8)
		pst.content_margin_left = 12
		pst.content_margin_right = 12
		pst.content_margin_top = 8
		pst.content_margin_bottom = 8
		pc.add_theme_stylebox_override("panel", pst)
		var preview_it: Dictionary = it
		pc.mouse_entered.connect(func():
			_rebuild_preview_actor(preview_it.get("tint", Color.WHITE))
			_update_stats_for_item(preview_it)
		)
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
		n_lbl.add_theme_font_size_override("font_size", 15)
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
		btn.custom_minimum_size = Vector2(138, 36)
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
