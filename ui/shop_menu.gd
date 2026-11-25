extends CanvasLayer

## Phase P2.1: "The Tailor of Vices" — Remodeled directly from ref_05_boutique_ui.jpg.
## Left 42%: Live 3D spotlight turntable on obsidian-marble gilded ring pedestal (drag to spin).
## Right 58%: 5 Character tabs + 2x3 Gilded Medallion Grid + Segmented Gold-Pip Detail Bar + BUY & EQUIP CTA.
## Toggle with [B] key, from Pause Menu (Esc), or at the Emerald Plaza Boutique!

const ShopItemIcon := preload("res://ui/widgets/shop_item_icon.gd")
const OrnateFrame := preload("res://ui/widgets/ornate_frame.gd")
const FrostedShader := preload("res://ui/shaders/frosted_velvet_backdrop.gdshader")
const TotoCompanion := preload("res://actors/companions/toto_companion.gd")
const OzThemeFactory := preload("res://ui/theme/oz_theme_factory.gd")

const VISUAL_SCRIPTS := {
	"dorothy": preload("res://actors/dorothy/dorothy_visual.gd"),
	"scarecrow": preload("res://actors/companions/scarecrow_visual.gd"),
	"tinman": preload("res://actors/companions/tinman_visual.gd"),
	"lion": preload("res://actors/companions/lion_visual.gd"),
}

const CHAR_TITLES := {
	"dorothy": "DOROTHY GALE  ·  THE SEEKER",
	"scarecrow": "THE SCARECROW  ·  WIT OF STRAW",
	"tinman": "THE TIN WOODMAN  ·  STEEL HEART",
	"lion": "THE COWARDLY LION  ·  PRIMAL ROAR",
	"toto": "TOTO  ·  FAITHFUL TERRIER",
}

var _backdrop: ColorRect
var _panel: PanelContainer
var _balance_lbl: Label
var _tab_buttons: Array[Button] = []
var _grid: GridContainer
var _active_char: String = "dorothy"
var _selected_item_id: String = ""

# Left 3D Turntable Stage
var _vp_container: SubViewportContainer
var _vp: SubViewport
var _turntable: Node3D
var _stage_cam: Camera3D
var _cam_dist: float = 3.25
var _preview_actor: Node3D
var _char_plaque_lbl: Label
var _dragging_stage: bool = false
var _last_drag_x: float = 0.0
var _spin_yaw: float = 0.35
var _toto_preview_parts: Dictionary = {}
var _toto_preview_t: float = 0.0

# Bottom Selected Item Detail Panel (ref_05_boutique_ui.jpg)
var _detail_title: Label
var _detail_perk: Label
var _detail_cost: Label
var _buy_btn: Button
var _pip_vitality: Array[ColorRect] = []
var _pip_allure: Array[ColorRect] = []
var _pip_power: Array[ColorRect] = []
var _pip_vitality_lbl: Label
var _pip_allure_lbl: Label
var _pip_power_lbl: Label

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
		_spin_yaw += delta * 0.50
	_turntable.rotation.y = _spin_yaw
	if _preview_actor and is_instance_valid(_preview_actor):
		if _preview_actor.has_method("set_locomotion"):
			_preview_actor.call("set_locomotion", 0.0, delta)
		elif _active_char == "toto" and not _toto_preview_parts.is_empty():
			_toto_preview_t += delta
			TotoCompanion.animate_parts(_toto_preview_parts, 0.0, _toto_preview_t, 0.0, 0.0, 0.0, 0.0)

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
	_selected_item_id = ""
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
	_backdrop.color = Color(0.04, 0.015, 0.05, 0.88)
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		var bmat := ShaderMaterial.new()
		bmat.shader = FrostedShader
		_backdrop.material = bmat
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(1060, 620)
	var st := StyleBoxFlat.new()
	st.bg_color = OzThemeFactory.OZ_SURFACE_DEEP
	st.border_color = OzThemeFactory.OZ_BORDER_GOLD
	st.set_border_width_all(3)
	st.border_width_bottom = 6
	st.set_corner_radius_all(18)
	st.content_margin_left = 34
	st.content_margin_right = 34
	st.content_margin_top = 28
	st.content_margin_bottom = 26
	_panel.add_theme_stylebox_override("panel", st)
	center.add_child(_panel)

	var frame_overlay := OrnateFrame.new()
	frame_overlay.outer_pad = 10.0
	frame_overlay.inset = 5.0
	_panel.add_child(frame_overlay)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	_panel.add_child(split)

	# ========================================================================
	# LEFT 40%: Live 3D Spotlight Turntable + Character Nameplate
	# ========================================================================
	var stage_col := VBoxContainer.new()
	stage_col.custom_minimum_size = Vector2(360, 0)
	stage_col.add_theme_constant_override("separation", 8)
	split.add_child(stage_col)

	var stage_frame := PanelContainer.new()
	stage_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sf_st := StyleBoxFlat.new()
	sf_st.bg_color = Color(0.05, 0.025, 0.065, 1.0)
	sf_st.border_color = Color(0.769, 0.620, 0.353, 0.72)
	sf_st.set_border_width_all(1)
	sf_st.set_corner_radius_all(6)
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

	var rot_hint := Label.new()
	rot_hint.text = "◄  DRAG TO ROTATE  ·  SCROLL TO ZOOM  ►"
	rot_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rot_hint.add_theme_font_size_override("font_size", 11)
	rot_hint.add_theme_color_override("font_color", Color(0.722, 0.659, 0.604))
	stage_col.add_child(rot_hint)

	var plaque := PanelContainer.new()
	var pl_st := StyleBoxFlat.new()
	pl_st.bg_color = Color(0.11, 0.06, 0.13, 0.95)
	pl_st.border_color = Color(0.769, 0.620, 0.353, 0.85)
	pl_st.set_border_width_all(1)
	pl_st.set_corner_radius_all(4)
	pl_st.content_margin_top = 6
	pl_st.content_margin_bottom = 6
	plaque.add_theme_stylebox_override("panel", pl_st)
	stage_col.add_child(plaque)

	_char_plaque_lbl = Label.new()
	_char_plaque_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_plaque_lbl.add_theme_font_size_override("font_size", 13)
	_char_plaque_lbl.add_theme_color_override("font_color", Color(0.910, 0.776, 0.478))
	plaque.add_child(_char_plaque_lbl)

	# ========================================================================
	# RIGHT 60%: Boutique Header + Tabs + 2x3 Gilded Grid + Pip Detail Box
	# ========================================================================
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 10)
	split.add_child(right_col)

	var hdr := HBoxContainer.new()
	right_col.add_child(hdr)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	hdr.add_child(title_box)

	var title := Label.new()
	title.text = "THE TAILOR OF VICES"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.910, 0.776, 0.478))
	title_box.add_child(title)

	var sub := Label.new()
	sub.text = "✦  ATTIRE  ·  SPECIALTY COUTURE & ARMORY  ✦"
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.722, 0.659, 0.604))
	title_box.add_child(sub)

	var close_btn := Button.new()
	close_btn.text = "✕  Close (B / Esc)"
	OzThemeFactory.style_royal_button(close_btn, "secondary", false, 13, 12)
	close_btn.pressed.connect(close)
	hdr.add_child(close_btn)

	# Character Category Tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	right_col.add_child(tabs)
	for t in CHAR_TABS:
		var b := Button.new()
		b.text = t["label"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cid: String = t["id"]
		b.pressed.connect(func():
			_active_char = cid
			_selected_item_id = ""
			var afx := get_node_or_null("/root/AudioFx")
			if afx and afx.has_method("play"):
				afx.play("ui_click", -8.0)
			_refresh()
		)
		tabs.add_child(b)
		_tab_buttons.append(b)

	# 2x3 Gilded Square Medallion Grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)

	# Bottom Selected Item Detail Box + Segmented Gold Pip Bars + BUY & EQUIP CTA
	var detail_panel := PanelContainer.new()
	var dp_st := StyleBoxFlat.new()
	dp_st.bg_color = Color(0.115, 0.065, 0.145, 0.96)
	dp_st.border_color = Color(0.769, 0.620, 0.353, 0.85)
	dp_st.set_border_width_all(1)
	dp_st.set_corner_radius_all(6)
	dp_st.content_margin_left = 22
	dp_st.content_margin_right = 22
	dp_st.content_margin_top = 16
	dp_st.content_margin_bottom = 16
	detail_panel.add_theme_stylebox_override("panel", dp_st)
	var dp_frame := OrnateFrame.new()
	dp_frame.outer_pad = 6.0
	dp_frame.inset = 4.0
	dp_frame.corner_size = 10.0
	dp_frame.show_diamonds = false
	detail_panel.add_child(dp_frame)
	right_col.add_child(detail_panel)

	var detail_hb := HBoxContainer.new()
	detail_hb.add_theme_constant_override("separation", 14)
	detail_panel.add_child(detail_hb)

	var stats_col := VBoxContainer.new()
	stats_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_col.add_theme_constant_override("separation", 4)
	detail_hb.add_child(stats_col)

	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 15)
	_detail_title.add_theme_color_override("font_color", Color(0.937, 0.878, 0.761))
	stats_col.add_child(_detail_title)

	_detail_perk = Label.new()
	_detail_perk.add_theme_font_size_override("font_size", 11)
	_detail_perk.add_theme_color_override("font_color", Color(0.722, 0.659, 0.604))
	stats_col.add_child(_detail_perk)

	_pip_vitality = _make_pip_row(stats_col, "VITALITY", 0)
	_pip_allure = _make_pip_row(stats_col, "ALLURE", 1)
	_pip_power = _make_pip_row(stats_col, "RESISTANCE", 2)

	var cta_col := VBoxContainer.new()
	cta_col.custom_minimum_size = Vector2(185, 0)
	cta_col.alignment = BoxContainer.ALIGNMENT_CENTER
	cta_col.add_theme_constant_override("separation", 6)
	detail_hb.add_child(cta_col)

	_detail_cost = Label.new()
	_detail_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_cost.add_theme_font_size_override("font_size", 13)
	_detail_cost.add_theme_color_override("font_color", Color(0.910, 0.776, 0.478))
	cta_col.add_child(_detail_cost)

	_buy_btn = Button.new()
	_buy_btn.custom_minimum_size = Vector2(180, 44)
	OzThemeFactory.style_royal_button(_buy_btn, "primary", false, 14, 12)
	_buy_btn.pressed.connect(_on_buy_or_equip_pressed)
	cta_col.add_child(_buy_btn)

	# Footer Balance Strip
	var footer := HBoxContainer.new()
	right_col.add_child(footer)
	_balance_lbl = Label.new()
	_balance_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_balance_lbl.add_theme_font_size_override("font_size", 13)
	_balance_lbl.add_theme_color_override("font_color", Color(0.910, 0.776, 0.478))
	footer.add_child(_balance_lbl)
	var foot_hint := Label.new()
	foot_hint.text = "[CLICK CARD] PREVIEW  ·  [B / ESC] CLOSE"
	foot_hint.add_theme_font_size_override("font_size", 11)
	foot_hint.add_theme_color_override("font_color", Color(0.722, 0.659, 0.604))
	footer.add_child(foot_hint)

func _make_pip_row(parent: VBoxContainer, label_txt: String, slot_kind: int = 0) -> Array[ColorRect]:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	parent.add_child(hb)
	var l := Label.new()
	l.text = "• %s" % label_txt
	l.custom_minimum_size = Vector2(104, 0)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.84, 0.78, 0.70))
	hb.add_child(l)
	var pips: Array[ColorRect] = []
	for i in range(12):
		var cr := ColorRect.new()
		cr.custom_minimum_size = Vector2(10, 8)
		cr.color = Color(0.22, 0.16, 0.26, 0.85)
		hb.add_child(cr)
		pips.append(cr)
	var pct := Label.new()
	pct.custom_minimum_size = Vector2(44, 0)
	pct.add_theme_font_size_override("font_size", 11)
	pct.add_theme_color_override("font_color", Color(0.95, 0.84, 0.52))
	hb.add_child(pct)
	if slot_kind == 0:
		_pip_vitality_lbl = pct
	elif slot_kind == 1:
		_pip_allure_lbl = pct
	else:
		_pip_power_lbl = pct
	return pips

func _set_pips(pips: Array[ColorRect], count: int, lit_col: Color) -> void:
	for i in range(pips.size()):
		pips[i].color = lit_col if i < count else Color(0.20, 0.14, 0.24, 0.80)

func _build_turntable_world() -> void:
	if _vp == null:
		return
	var stage := Node3D.new()
	stage.name = "BoutiqueStage"
	_vp.add_child(stage)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.03, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.46, 0.36, 0.50)
	e.ambient_light_energy = 0.90
	env.environment = e
	stage.add_child(env)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.90, 0.74)
	key.light_energy = 1.55
	key.rotation_degrees = Vector3(-34, 24, 0)
	stage.add_child(key)

	var rim := OmniLight3D.new()
	rim.light_color = Color(0.92, 0.32, 0.52)
	rim.light_energy = 2.4
	rim.omni_range = 8.0
	rim.position = Vector3(-1.8, 1.9, -1.6)
	stage.add_child(rim)

	_stage_cam = Camera3D.new()
	_stage_cam.fov = 36.0
	_stage_cam.position = Vector3(0.0, 1.08, _cam_dist)
	_stage_cam.look_at(Vector3(0.0, 0.80, 0.0), Vector3.UP)
	_stage_cam.current = true
	stage.add_child(_stage_cam)

	_turntable = Node3D.new()
	_turntable.name = "Turntable"
	stage.add_child(_turntable)

	# Obsidian-Marble Pedestal with Concentric Golden Zodiac Rings (ref_05_boutique_ui.jpg)
	var ped := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.86
	cyl.bottom_radius = 0.96
	cyl.height = 0.22
	ped.mesh = cyl
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.10, 0.08, 0.13)
	pm.roughness = 0.24
	pm.metallic = 0.32
	ped.material_override = pm
	ped.position = Vector3(0, -0.11, 0)
	_turntable.add_child(ped)

	for rad in [0.85, 0.62, 0.38]:
		var ring := MeshInstance3D.new()
		var rc := CylinderMesh.new()
		rc.top_radius = rad
		rc.bottom_radius = rad
		rc.height = 0.025
		ring.mesh = rc
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.88, 0.70, 0.34)
		rm.metallic = 0.88
		rm.roughness = 0.22
		ring.material_override = rm
		ring.position = Vector3(0, -0.005, 0)
		_turntable.add_child(ring)

func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging_stage = event.pressed
			_last_drag_x = event.position.x
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var step := -0.22 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.22
			_cam_dist = clampf(_cam_dist + step, 2.25, 4.15)
			if _stage_cam:
				_stage_cam.position = Vector3(0.0, 1.08, _cam_dist)
				_stage_cam.look_at(Vector3(0.0, 0.80, 0.0), Vector3.UP)
	elif event is InputEventMouseMotion and _dragging_stage:
		var dx: float = event.position.x - _last_drag_x
		_last_drag_x = event.position.x
		_spin_yaw += dx * 0.015

func _rebuild_preview_actor(tint: Color, item_id: String = "") -> void:
	if _turntable == null or not is_instance_valid(_turntable):
		return
	if _preview_actor and is_instance_valid(_preview_actor):
		_preview_actor.queue_free()
		_preview_actor = null
	var actor := Node3D.new()
	actor.name = "PreviewActor"
	_toto_preview_parts.clear()
	var resolved_id := item_id if item_id != "" else _selected_item_id
	if _active_char == "toto":
		_toto_preview_parts = TotoCompanion.build_dog_visual(actor, false, resolved_id)
		actor.scale = Vector3(1.55, 1.55, 1.55)
		_turntable.add_child(actor)
		_preview_actor = actor
		return
	elif VISUAL_SCRIPTS.has(_active_char):
		actor.set_script(VISUAL_SCRIPTS[_active_char])
		if _active_char == "dorothy":
			actor.set("show_silver_shoes", true)
		elif _active_char == "lion":
			actor.set("cowering", false)
		actor.set("outfit_id", resolved_id)
	_turntable.add_child(actor)
	_preview_actor = actor
	if _preview_actor.has_method("set_outfit"):
		_preview_actor.call("set_outfit", resolved_id)
		return
	for mi in _preview_actor.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m and m.material_override is StandardMaterial3D:
			var dup := (m.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			dup.albedo_color = dup.albedo_color.lerp(tint, 0.56)
			m.material_override = dup

func _select_item(it: Dictionary) -> void:
	_selected_item_id = str(it.get("id", ""))
	_rebuild_preview_actor(it.get("tint", Color.WHITE), _selected_item_id)
	_update_detail_panel(it)

func _update_detail_panel(it: Dictionary) -> void:
	var sm := get_node_or_null("/root/SaveManager")
	var iid: String = str(it.get("id", ""))
	var cost: int = int(it.get("cost", 0))
	var owned: bool = sm != null and (iid in sm.owned_items)
	var equipped_id: String = str(sm.equipped_outfits.get(_active_char, "")) if sm else ""

	_detail_title.text = str(it.get("name", "")).to_upper()
	_detail_perk.text = str(it.get("perk", ""))
	var vit_pips := clampi(4 + int(cost / 10), 4, 12)
	var all_pips := clampi(5 + int(cost / 6), 5, 12)
	var pow_pips := clampi(5 + (5 if ("whip" in iid or "velvet" in iid or "primal" in iid or "obsidian" in iid) else int(cost / 12)), 4, 12)
	_set_pips(_pip_vitality, vit_pips, Color(0.910, 0.776, 0.478))
	_set_pips(_pip_allure, all_pips, Color(0.92, 0.34, 0.58))
	_set_pips(_pip_power, pow_pips, Color(0.86, 0.68, 0.34))
	if _pip_vitality_lbl:
		_pip_vitality_lbl.text = " +%d%%" % ((vit_pips - 4) * 5) if vit_pips > 4 else " BASE"
	if _pip_allure_lbl:
		var all_pct := 40 if "sovereign" in iid else (25 if "velvet" in iid else maxi(0, (all_pips - 5) * 6))
		_pip_allure_lbl.text = " +%d%%" % all_pct if all_pct > 0 else " BASE"
	if _pip_power_lbl:
		_pip_power_lbl.text = " +%d%%" % ((pow_pips - 4) * 5) if pow_pips > 4 else " BASE"

	if iid == equipped_id:
		_detail_cost.text = "✦ CURRENTLY EQUIPPED"
		_buy_btn.text = "✓ EQUIPPED"
		_buy_btn.disabled = true
	elif owned:
		_detail_cost.text = "✦ OWNED IN WARDROBE"
		_buy_btn.text = "EQUIP NOW"
		_buy_btn.disabled = false
	else:
		_detail_cost.text = "♦ %d DESIRE FRAGMENTS" % cost
		_buy_btn.text = "BUY & EQUIP"
		_buy_btn.disabled = (sm == null or int(sm.desire_fragments) < cost)

func _on_buy_or_equip_pressed() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null or _selected_item_id == "":
		return
	if sm.buy_and_equip(_active_char, _selected_item_id):
		var afx := get_node_or_null("/root/AudioFx")
		if afx and afx.has_method("play"):
			afx.play("buy", -5.0)
		_refresh()

func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	_balance_lbl.text = "DESIRE FRAGMENTS:  ♦ %d" % int(sm.desire_fragments)
	_char_plaque_lbl.text = CHAR_TITLES.get(_active_char, _active_char.to_upper())
	for i in range(CHAR_TABS.size()):
		var is_active: bool = (CHAR_TABS[i]["id"] == _active_char)
		OzThemeFactory.style_royal_button(_tab_buttons[i], "featured" if is_active else "secondary", false, 13, 10)
		_tab_buttons[i].modulate = Color.WHITE

	var items: Array = sm.SHOP_CATALOG.get(_active_char, [])
	var equipped_id: String = str(sm.equipped_outfits.get(_active_char, ""))
	var selected_it: Dictionary = items[0] if not items.is_empty() else {}
	for it in items:
		if str(it.get("id", "")) == (_selected_item_id if _selected_item_id != "" else equipped_id):
			selected_it = it
			break
	if not selected_it.is_empty():
		_selected_item_id = str(selected_it.get("id", ""))
		_rebuild_preview_actor(selected_it.get("tint", Color.WHITE), _selected_item_id)
		_update_detail_panel(selected_it)

	for it in items:
		var iid: String = str(it["id"])
		var is_eq: bool = (iid == equipped_id)
		var is_sel: bool = (iid == _selected_item_id)
		var card := Button.new()
		card.custom_minimum_size = Vector2(182, 134)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cst := StyleBoxFlat.new()
		cst.bg_color = Color(0.17, 0.10, 0.21, 0.96) if is_sel else Color(0.12, 0.07, 0.15, 0.92)
		cst.border_color = Color(0.95, 0.80, 0.44, 1.0) if (is_sel or is_eq) else Color(0.55, 0.44, 0.26, 0.65)
		cst.set_border_width_all(2 if is_sel else 1)
		cst.set_corner_radius_all(6)
		card.add_theme_stylebox_override("normal", cst)
		card.add_theme_stylebox_override("hover", cst)
		card.add_theme_stylebox_override("pressed", cst)
		var item_ref: Dictionary = it
		card.pressed.connect(func():
			var afx := get_node_or_null("/root/AudioFx")
			if afx and afx.has_method("play"):
				afx.play("ui_click", -8.0)
			_select_item(item_ref)
			_refresh()
		)
		card.mouse_entered.connect(func():
			var afx := get_node_or_null("/root/AudioFx")
			if afx and afx.has_method("play"):
				afx.play("ui_hover", -12.0)
			_rebuild_preview_actor(item_ref.get("tint", Color.WHITE), str(item_ref.get("id", "")))
			_update_detail_panel(item_ref)
		)
		_grid.add_child(card)

		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.offset_left = 8
		vb.offset_right = -8
		vb.offset_top = 8
		vb.offset_bottom = -8
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 6)
		card.add_child(vb)

		var icon_center := CenterContainer.new()
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(icon_center)
		var icon := ShopItemIcon.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.setup(iid, it.get("tint", Color.WHITE), is_eq)
		icon_center.add_child(icon)

		var lbl := Label.new()
		lbl.text = ("✓ " if is_eq else "") + str(it["name"])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.96, 0.86, 0.56) if is_sel else Color(0.90, 0.84, 0.74))
		vb.add_child(lbl)
