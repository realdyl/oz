extends CanvasLayer

const OzThemeFactory := preload("res://ui/theme/oz_theme_factory.gd")
const ThreatRadarScript := preload("res://ui/widgets/threat_radar.gd")
const PauseMenuScript := preload("res://ui/shell/pause_menu.gd")
const GrimoireMenuScript := preload("res://ui/grimoire_menu.gd")
const ShopMenuScript := preload("res://ui/shop_menu.gd")
const OrnateFrame := preload("res://ui/widgets/ornate_frame.gd")
const RoseVitalityBar := preload("res://ui/widgets/rose_vitality_bar.gd")
const PartyMedallionWheel := preload("res://ui/widgets/party_medallion_wheel.gd")
const ArmamentDock := preload("res://ui/widgets/armament_dock.gd")
const AllureGauge := preload("res://ui/widgets/allure_gauge.gd")
const FrostedShader := preload("res://ui/shaders/frosted_velvet_backdrop.gdshader")
const RaptureShader := preload("res://ui/shaders/rapture_vignette.gdshader")
const SpectaclesShader := preload("res://ui/shaders/emerald_spectacles.gdshader")
const WorldKit := preload("res://systems/world_kit.gd")
const TotoCompanionScript := preload("res://actors/companions/toto_companion.gd")

## Modern 2026 PlayHUD for Oz: The Road Home.
## Preserves 100% API and node contract compatibility (Fade, ThreatCompass,
## set_objective, set_prompt, set_kansas_mode, set_party_roster) while upgrading
## all chrome to sleek storybook / film-noir widgets via OzThemeFactory.

@onready var objective_panel: PanelContainer = $SafeRoot/ObjectivePanel
@onready var accent_bar: ColorRect = $SafeRoot/ObjectivePanel/ObjHBox/AccentBar
@onready var kicker: Label = $SafeRoot/ObjectivePanel/ObjHBox/ObjVBox/Kicker
@onready var objective: Label = $SafeRoot/ObjectivePanel/ObjHBox/ObjVBox/Objective

@onready var threat_radar: Control = $SafeRoot/ThreatRadar
@onready var toast_panel: PanelContainer = $SafeRoot/ToastPanel
@onready var toast_label: Label = $SafeRoot/ToastPanel/ToastLabel

@onready var lead_bar: HBoxContainer = $SafeRoot/LeadBar
@onready var prompt_center: CenterContainer = $SafeRoot/PromptCenter
@onready var prompt_panel: PanelContainer = $SafeRoot/PromptCenter/PromptPanel
@onready var keycap_panel: PanelContainer = $SafeRoot/PromptCenter/PromptPanel/PromptHBox/KeycapPanel
@onready var keycap_label: Label = $SafeRoot/PromptCenter/PromptPanel/PromptHBox/KeycapPanel/KeycapLabel
@onready var prompt_label: Label = $SafeRoot/PromptCenter/PromptPanel/PromptHBox/PromptLabel

@onready var controls_panel: PanelContainer = $SafeRoot/ControlsCenter/ControlsPanel
@onready var controls: Label = $SafeRoot/ControlsCenter/ControlsPanel/Controls

var kansas_mode: bool = false
var threat_compass: Label
var pause_menu: CanvasLayer
var grimoire_menu: CanvasLayer
var shop_menu: CanvasLayer
var _vitality_panel: Control
var _rose_bar: Control
var _petal_labels: Array[Label] = []
var _allure_bar: ProgressBar
var _allure_gauge: Control
var _party_wheel: Control
var _armament_dock: Control
var _desire_lbl: Label
var _armament_icon: TextureRect
var _armament_lbl: Label
var _rapture_overlay: ColorRect
var _boss_panel: PanelContainer
var _boss_name_lbl: Label
var _boss_phase_lbl: Label
var _boss_bar: ProgressBar
var _wheel_root: Control
var _wheel_open: bool = false
var _wheel_buttons: Dictionary = {}
var _style_panel: PanelContainer
var _style_rank_lbl: Label
var _style_mult_lbl: Label
var _spectacles_overlay: ColorRect
var _sub_objective_lbl: Label
var _act_key: String = ""

var _is_final_step: bool = false
var _last_objective: String = ""
var _last_prompt: String = ""
var _roster_text: String = ""
var _toast_timer: float = 0.0
var _obj_tween: Tween = null
var _prompt_tween: Tween = null

var _lead_slots: Dictionary = {} # StringName -> Dictionary {panel, key_lbl, name_lbl}
var _kit_panel: PanelContainer
var _kit_key_lbl: Label
var _kit_verb_lbl: Label

const LEAD_DEFS := [
	{"id": &"dorothy", "key": "1", "name": "Dorothy", "verb": "KICK"},
	{"id": &"scarecrow", "key": "2", "name": "Scarecrow", "verb": "CAW"},
	{"id": &"tinman", "key": "3", "name": "Tin Man", "verb": "AXE"},
	{"id": &"lion", "key": "4", "name": "Lion", "verb": "ROAR"},
	{"id": &"toto", "key": "5", "name": "Toto", "verb": "BARK"},
]

func _ready() -> void:
	add_to_group("hud")
	_ensure_fade()
	_ensure_threat_compass()
	_build_lead_bar()
	_build_vitality_ribbon()
	_build_quick_wheel()
	_ensure_pause_menu()
	_ensure_grimoire_menu()
	_connect_party()
	_connect_save_manager()
	child_entered_tree.connect(_on_child_entered_tree)

	_apply_theme()
	if prompt_center:
		prompt_center.visible = false
	set_prompt("")
	if objective:
		_last_objective = objective.text
		if pause_menu:
			pause_menu.call("set_objective_text", _last_objective)
	call_deferred("_cull_scene_labels")

func _cull_scene_labels() -> void:
	var host := get_parent()
	if host:
		WorldKit.apply_label3d_culling(host, 12.0, 3.5)
		_ensure_toto_present(host)

func _ensure_toto_present(host: Node) -> void:
	if host == null or not (host is Node3D):
		return
	# If the level already has Toto (e.g., L1 Kansas farmyard), don't duplicate him.
	if not get_tree().get_nodes_in_group("toto").is_empty():
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var toto_node: Node3D = TotoCompanionScript.new()
	toto_node.set("greyscale", kansas_mode)
	host.add_child(toto_node)
	toto_node.global_position = player.global_position + Vector3(1.15, 0.0, 0.75)

func _is_headless() -> bool:
	var n := DisplayServer.get_name()
	return n == "headless" or n == "Dummy"

func _ensure_fade() -> void:
	var fade := get_node_or_null("Fade") as ColorRect
	if fade == null:
		fade = ColorRect.new()
		fade.name = "Fade"
		fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.color = Color(0, 0, 0, 0)
		fade.z_index = 20
		add_child(fade)

func _ensure_threat_compass() -> void:
	# Keep hidden ThreatCompass Label as a direct child for headless play_sim.gd contract.
	threat_compass = get_node_or_null("ThreatCompass") as Label
	if threat_compass == null:
		threat_compass = Label.new()
		threat_compass.name = "ThreatCompass"
		add_child(threat_compass)
	threat_compass.visible = false
	threat_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	threat_compass.text = ""

func _ensure_pause_menu() -> void:
	pause_menu = get_node_or_null("PauseMenu") as CanvasLayer
	if pause_menu == null:
		pause_menu = PauseMenuScript.new()
		pause_menu.name = "PauseMenu"
		add_child(pause_menu)
	pause_menu.call("apply_theme_mode", kansas_mode)

func _connect_party() -> void:
	var party := get_node_or_null("/root/Party")
	if party == null:
		return
	if party.has_signal("leader_changed") and not party.leader_changed.is_connected(_on_party_changed):
		party.leader_changed.connect(_on_party_changed)
	if party.has_signal("unlock_changed") and not party.unlock_changed.is_connected(_on_unlock_changed):
		party.unlock_changed.connect(_on_unlock_changed)
	if party.has_signal("swap_failed") and not party.swap_failed.is_connected(_on_swap_failed):
		party.swap_failed.connect(_on_swap_failed)

func _on_party_changed(_id: StringName, _body: Node3D) -> void:
	_refresh_lead_bar()

func _on_unlock_changed(_id: StringName, _unlocked: bool) -> void:
	_refresh_lead_bar()

func _on_swap_failed(reason: String) -> void:
	show_toast(reason, 2.8)

func _build_lead_bar() -> void:
	if lead_bar == null:
		return
	for c in lead_bar.get_children():
		c.queue_free()
	_lead_slots.clear()

	for def in LEAD_DEFS:
		var slot := PanelContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hbox := HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 6)
		slot.add_child(hbox)

		# Painted 36x36 character portrait medallion (Phase P3.1)
		var cid_str := str(def["id"])
		var tex := _load_hud_portrait("res://assets/art/portraits/%s.png" % cid_str)
		var port_tr: TextureRect = null
		if tex != null:
			port_tr = TextureRect.new()
			port_tr.texture = tex
			port_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			port_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			port_tr.custom_minimum_size = Vector2(36, 36)
			port_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(port_tr)

		var k_lbl := Label.new()
		k_lbl.text = def["key"]
		k_lbl.add_theme_font_size_override("font_size", 12)
		k_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(k_lbl)

		var n_lbl := Label.new()
		n_lbl.text = def["name"]
		n_lbl.add_theme_font_size_override("font_size", 13)
		n_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(n_lbl)

		lead_bar.add_child(slot)
		_lead_slots[def["id"]] = {"panel": slot, "key": k_lbl, "name": n_lbl, "portrait": port_tr, "verb": def["verb"]}

	# Attached Kit Verb Chip ([F] KICK / CAW / AXE / ROAR)
	_kit_panel = PanelContainer.new()
	_kit_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var khbox := HBoxContainer.new()
	khbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	khbox.add_theme_constant_override("separation", 6)
	_kit_panel.add_child(khbox)

	var kcap := PanelContainer.new()
	kcap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kcap.add_theme_stylebox_override("panel", OzThemeFactory.make_keycap_style(false))
	_kit_key_lbl = Label.new()
	_kit_key_lbl.text = "F"
	_kit_key_lbl.add_theme_font_size_override("font_size", 12)
	_kit_key_lbl.add_theme_color_override("font_color", OzThemeFactory.ink_color(false))
	_kit_key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kcap.add_child(_kit_key_lbl)
	khbox.add_child(kcap)

	_kit_verb_lbl = Label.new()
	_kit_verb_lbl.text = "KICK"
	_kit_verb_lbl.add_theme_font_size_override("font_size", 13)
	_kit_verb_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	khbox.add_child(_kit_verb_lbl)

	lead_bar.add_child(_kit_panel)
	lead_bar.visible = false

func _refresh_lead_bar() -> void:
	if lead_bar == null:
		return
	var party := get_node_or_null("/root/Party")
	var current_lead := &"dorothy"
	if party and party.has_method("leader_id"):
		current_lead = party.leader_id()

	var active_verb := "KICK"
	for def in LEAD_DEFS:
		var id: StringName = def["id"]
		var entry: Dictionary = _lead_slots.get(id, {})
		if entry.is_empty():
			continue
		var panel: PanelContainer = entry["panel"]
		var key_lbl: Label = entry["key"]
		var name_lbl: Label = entry["name"]

		var is_active := (id == current_lead)
		var is_unlocked := (id == &"dorothy")
		var is_present := true
		if party:
			if party.has_method("is_unlocked"):
				is_unlocked = party.is_unlocked(id)
			if party.has_method("is_present"):
				is_present = party.is_present(id)

		var locked := not is_unlocked or not is_present
		panel.add_theme_stylebox_override("panel", OzThemeFactory.make_roster_slot_style(is_active, locked, kansas_mode))
		var col := OzThemeFactory.accent_color(kansas_mode) if is_active else (
			Color(0.55, 0.52, 0.56, 0.55) if locked else OzThemeFactory.text_color(kansas_mode)
		)
		key_lbl.add_theme_color_override("font_color", OzThemeFactory.accent_color(kansas_mode) if is_active else OzThemeFactory.muted_text_color(kansas_mode))
		name_lbl.add_theme_color_override("font_color", col)
		var port_tr = entry.get("portrait", null)
		if port_tr is TextureRect:
			(port_tr as TextureRect).custom_minimum_size = Vector2(44, 44) if is_active else Vector2(32, 32)
			(port_tr as TextureRect).modulate = Color(1, 1, 1, 1.0) if not locked else Color(0.45, 0.42, 0.48, 0.55)
		if is_active:
			active_verb = str(def["verb"])

	if _kit_panel and _kit_verb_lbl:
		_kit_panel.add_theme_stylebox_override("panel", OzThemeFactory.make_pill_style(kansas_mode, 10, 5))
		_kit_verb_lbl.text = active_verb
		_kit_verb_lbl.add_theme_color_override("font_color", OzThemeFactory.accent_color(kansas_mode))
	if _party_wheel and _party_wheel.has_method("refresh_from_party"):
		_party_wheel.call("refresh_from_party")

func _apply_theme() -> void:
	var text_col := OzThemeFactory.text_color(kansas_mode)
	var muted_col := OzThemeFactory.muted_text_color(kansas_mode)
	var accent := OzThemeFactory.accent_color(kansas_mode)
	var ink := OzThemeFactory.ink_color(kansas_mode)

	if objective_panel:
		objective_panel.add_theme_stylebox_override("panel", OzThemeFactory.make_panel_style(kansas_mode, _is_final_step))
	if accent_bar:
		accent_bar.color = accent if _is_final_step else (OzThemeFactory.KS_BORDER if kansas_mode else OzThemeFactory.OZ_BORDER_GOLD)
	if kicker:
		kicker.add_theme_font_size_override("font_size", 11)
		kicker.add_theme_color_override("font_color", accent if _is_final_step else muted_col)
	if objective:
		objective.add_theme_font_size_override("font_size", 17)
		objective.add_theme_color_override("font_color", text_col)

	if prompt_panel:
		prompt_panel.add_theme_stylebox_override("panel", OzThemeFactory.make_pill_style(kansas_mode, 16, 8))
	if keycap_panel:
		keycap_panel.add_theme_stylebox_override("panel", OzThemeFactory.make_keycap_style(kansas_mode))
	if keycap_label:
		keycap_label.add_theme_font_size_override("font_size", 14)
		keycap_label.add_theme_color_override("font_color", ink)
	if prompt_label:
		prompt_label.add_theme_font_size_override("font_size", 16)
		prompt_label.add_theme_color_override("font_color", text_col)

	if controls_panel:
		controls_panel.add_theme_stylebox_override("panel", OzThemeFactory.make_pill_style(kansas_mode, 16, 6))
	if controls:
		controls.add_theme_font_size_override("font_size", 13)
		controls.add_theme_color_override("font_color", muted_col)

	if toast_panel:
		toast_panel.add_theme_stylebox_override("panel", OzThemeFactory.make_panel_style(kansas_mode, false))
	if toast_label:
		toast_label.add_theme_font_size_override("font_size", 14)
		toast_label.add_theme_color_override("font_color", accent)

	if pause_menu:
		pause_menu.call("apply_theme_mode", kansas_mode)
	if objective_panel:
		var ofr := objective_panel.get_node_or_null("OrnateObjFrame")
		if ofr:
			ofr.set("kansas_mode", kansas_mode)
			ofr.queue_redraw()
	if _party_wheel and _party_wheel.has_method("set_kansas"):
		_party_wheel.call("set_kansas", kansas_mode)
	_refresh_vitality_ribbon()

	_refresh_lead_bar()
	_style_all_external_children()

func _on_child_entered_tree(node: Node) -> void:
	call_deferred("_style_external_child", node)

func _style_all_external_children() -> void:
	for c in get_children():
		_style_external_child(c)

func _style_external_child(node: Node) -> void:
	if not is_instance_valid(node) or not (node is Label):
		return
	if node == threat_compass:
		return
	var lbl := node as Label
	if lbl.name in ["LevelCompass", "Compass", "SleepMeter", "WhimsyScore"]:
		lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.05, 0.92))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 2)
		if lbl.name == "Compass" and not kansas_mode:
			lbl.add_theme_color_override("font_color", OzThemeFactory.OZ_PARCHMENT)
		_relayout_left_external_labels()

func _relayout_left_external_labels() -> void:
	if objective_panel == null:
		return
	var base_y := maxf(102.0, objective_panel.position.y + objective_panel.size.y + 8.0)
	for cname in ["Compass", "SleepMeter"]:
		var n := get_node_or_null(cname) as Control
		if n:
			n.position.y = base_y
			base_y += 28.0
	var whimsy := get_node_or_null("WhimsyScore") as Control
	if whimsy:
		whimsy.position.y = base_y

func set_kansas_mode(on: bool) -> void:
	kansas_mode = on
	if lead_bar:
		lead_bar.visible = false
	if _party_wheel:
		_party_wheel.visible = not on and _roster_text != ""
	if _armament_dock:
		_armament_dock.visible = not on and _roster_text != ""
	if threat_radar:
		threat_radar.visible = not on
		if on and threat_radar.has_method("update_threat"):
			threat_radar.call("update_threat", false, 0, 0.0, 0.0, false, true)
	if threat_compass and on:
		threat_compass.text = ""
	_apply_theme()

func set_party_roster(text: String) -> void:
	_roster_text = text
	if lead_bar:
		lead_bar.visible = false
	if _party_wheel:
		_party_wheel.visible = not kansas_mode and text != ""
	if _armament_dock:
		_armament_dock.visible = not kansas_mode and text != ""
	_refresh_lead_bar()

func set_objective(text: String) -> void:
	if objective == null:
		return
	var changed := (text != _last_objective)
	_last_objective = text
	var clean_txt := text if text.begins_with("◈") else ("◈  " + text)
	objective.text = clean_txt
	if kicker and not _is_final_step:
		kicker.text = "CURRENT OBJECTIVE"
	_refresh_sub_objective()

	var now_final := text.to_upper().contains("FINAL STEP")
	if now_final != _is_final_step:
		_is_final_step = now_final
		if kicker:
			kicker.text = "★  FINAL STEP" if _is_final_step else "OBJECTIVE"
		if objective_panel:
			objective_panel.add_theme_stylebox_override("panel", OzThemeFactory.make_panel_style(kansas_mode, _is_final_step))
		if accent_bar:
			accent_bar.color = OzThemeFactory.accent_color(kansas_mode) if _is_final_step else (
				OzThemeFactory.KS_BORDER if kansas_mode else OzThemeFactory.OZ_BORDER_GOLD
			)
		if kicker:
			kicker.add_theme_color_override("font_color", OzThemeFactory.accent_color(kansas_mode) if _is_final_step else OzThemeFactory.muted_text_color(kansas_mode))

	if pause_menu:
		pause_menu.call("set_objective_text", text)

	call_deferred("_relayout_left_external_labels")

	if changed and objective_panel and not _is_headless():
		if _obj_tween and _obj_tween.is_valid():
			_obj_tween.kill()
		objective_panel.modulate.a = 0.65
		_obj_tween = create_tween()
		_obj_tween.tween_property(objective_panel, "modulate:a", 1.0, 0.28).set_ease(Tween.EASE_OUT)

func set_prompt(text: String) -> void:
	if prompt_center == null or prompt_label == null:
		return
	if text == "":
		_last_prompt = ""
		if _is_headless():
			prompt_center.visible = false
			return
		if not prompt_center.visible:
			return
		if _prompt_tween and _prompt_tween.is_valid():
			_prompt_tween.kill()
		_prompt_tween = create_tween()
		_prompt_tween.tween_property(prompt_center, "modulate:a", 0.0, 0.14)
		_prompt_tween.tween_callback(func():
			if _last_prompt == "":
				prompt_center.visible = false
		)
		return

	var changed := (text != _last_prompt)
	_last_prompt = text

	# Parse "KEY  —  Action" into tactile keycap + action label
	var sep_idx := text.find("—")
	if sep_idx > 0:
		var lhs := text.substr(0, sep_idx).strip_edges()
		var rhs := text.substr(sep_idx + 1).strip_edges()
		if lhs.length() > 0 and lhs.length() <= 6 and rhs != "":
			keycap_panel.visible = true
			keycap_label.text = lhs
			prompt_label.text = rhs
		else:
			keycap_panel.visible = false
			prompt_label.text = text
	else:
		keycap_panel.visible = false
		prompt_label.text = text

	if _is_headless():
		prompt_center.visible = true
		prompt_center.modulate.a = 1.0
		return

	if not prompt_center.visible or changed:
		if _prompt_tween and _prompt_tween.is_valid():
			_prompt_tween.kill()
		var was_visible := prompt_center.visible
		prompt_center.visible = true
		prompt_center.modulate.a = 0.0 if not was_visible else 0.75
		_prompt_tween = create_tween()
		_prompt_tween.tween_property(prompt_center, "modulate:a", 1.0, 0.16).set_ease(Tween.EASE_OUT)

func show_toast(text: String, duration: float = 2.6) -> void:
	if toast_panel == null or toast_label == null or text == "":
		return
	toast_label.text = text
	_toast_timer = duration
	toast_panel.visible = true
	if not _is_headless():
		toast_panel.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(toast_panel, "modulate:a", 1.0, 0.18)

func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and toast_panel:
			toast_panel.visible = false

	_sync_dialogue_quiet_hours()
	_sync_live_combat_chrome(delta)
	_update_grass_rustle()
	_update_threat_compass()
	_update_controls_strip()

func _sync_live_combat_chrome(delta: float) -> void:
	if _is_headless():
		return
	var sm := get_node_or_null("/root/SaveManager")
	var player := get_tree().get_first_node_in_group("player")
	if _armament_dock and _armament_dock.visible:
		var cd_ratio := 0.0
		var rap_on := false
		if player:
			var cd_val := float(player.get("_armament_cd")) if "_armament_cd" in player else 0.0
			cd_ratio = clampf(cd_val / 0.85, 0.0, 1.0)
			rap_on = (float(player.get("_rapture_t")) if "_rapture_t" in player else 0.0) > 0.0
		var can_rap := sm != null and (float(sm.allure) >= 35.0 or int(sm.hp) <= 2)
		_armament_dock.call("update_live_state", cd_ratio, can_rap, rap_on)

	# Adaptive Exploration Restraint + High-Contrast A11y hook
	var hi_con: bool = sm != null and bool(sm.high_contrast_hud)
	var in_threat: bool = threat_radar != null and bool(threat_radar.get("has_threat"))
	var target_a := 1.0 if (hi_con or in_threat or kansas_mode) else 0.88
	if _vitality_panel:
		_vitality_panel.modulate.a = move_toward(_vitality_panel.modulate.a, target_a, delta * 3.0)
	if _party_wheel and _party_wheel.visible:
		_party_wheel.modulate.a = move_toward(_party_wheel.modulate.a, target_a, delta * 3.0)

func _update_grass_rustle() -> void:
	var party := get_node_or_null("/root/Party")
	var actor: Node3D = null
	if party and party.has_method("leader_body"):
		actor = party.leader_body() as Node3D
	if actor == null:
		actor = get_tree().get_first_node_in_group("player") as Node3D
	if actor and is_instance_valid(actor):
		WorldKit.update_grass_rustle(actor.global_position)

func _sync_dialogue_quiet_hours() -> void:
	var dia := get_node_or_null("/root/DialogueUI")
	var dia_open := false
	if dia:
		var box = dia.get("_box")
		if box is Control and (box as Control).visible:
			dia_open = true
	if lead_bar:
		lead_bar.visible = false
	var want_combat_hud := (not kansas_mode) and (_roster_text != "") and (not dia_open)
	if _party_wheel and _party_wheel.visible != want_combat_hud:
		_party_wheel.visible = want_combat_hud
	if _armament_dock and _armament_dock.visible != want_combat_hud:
		_armament_dock.visible = want_combat_hud
	if _vitality_panel:
		_vitality_panel.visible = not dia_open
	if prompt_center and dia_open:
		prompt_center.visible = false
	if controls_panel:
		controls_panel.visible = not dia_open

func _update_controls_strip() -> void:
	if controls == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("wants_look_hint") and player.wants_look_hint():
		controls.text = "Click to look (360°) · Esc pause · RMB+WASD orbit"
		return
	if kansas_mode:
		controls.text = "Arrows/WASD move · Mouse 360° · E take · Esc pause · F9 → Munchkinland"
		return
	var party := get_node_or_null("/root/Party")
	var lead := "Dorothy"
	if party and party.has_method("leader_id"):
		var lid: StringName = party.leader_id()
		if lid == &"scarecrow":
			lead = "Scarecrow"
		elif lid == &"tinman":
			lead = "Tin Man"
		elif lid == &"lion":
			lead = "Lion"
	controls.text = "Arrows move · Space blink · F act · E interact · Tab/1–4 Lead (%s) · Esc pause" % lead

func _update_threat_compass() -> void:
	if kansas_mode:
		return
	var party := get_node_or_null("/root/Party")
	var actor: Node3D = null
	if party and party.has_method("leader_body"):
		actor = party.leader_body() as Node3D
	if actor == null:
		actor = get_tree().get_first_node_in_group("player") as Node3D
	if actor == null:
		if threat_compass:
			threat_compass.text = ""
		if threat_radar and threat_radar.has_method("update_threat"):
			threat_radar.call("update_threat", false, 0, 0.0, 0.0, false, kansas_mode)
		return

	var best: Node3D = null
	var best_d := 1.0e9
	var live := 0
	const BOUND_X := 56.0
	const BOUND_Z := 52.0
	for n in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(n) or not (n is Node3D):
			continue
		if n.is_in_group("enemies_dead"):
			continue
		var st = n.get("state")
		if st != null and int(st) == 8:
			continue
		var hp = n.get("health")
		if hp != null and int(hp) <= 0:
			continue
		var np := (n as Node3D).global_position
		if absf(np.x) > BOUND_X + 0.5 or absf(np.z) > BOUND_Z + 0.5:
			if n.has_method("_clamp_in_bounds"):
				n.call("_clamp_in_bounds")
			elif n.has_method("set_play_bounds"):
				n.call("set_play_bounds", BOUND_X, BOUND_Z)
			np = (n as Node3D).global_position
			if absf(np.x) > BOUND_X + 2.0 or absf(np.z) > BOUND_Z + 2.0:
				continue
		live += 1
		var d: float = actor.global_position.distance_to(np)
		if d < best_d:
			best_d = d
			best = n as Node3D

	if best == null or live <= 0:
		if threat_compass:
			threat_compass.text = ""
		if threat_radar and threat_radar.has_method("update_threat"):
			threat_radar.call("update_threat", false, 0, 0.0, 0.0, false, kansas_mode)
		return

	var to: Vector3 = best.global_position - actor.global_position
	to.y = 0.0
	var dist := to.length()
	var forward := Vector3(0, 0, -1)
	var basis_node: Node3D = null
	if party and party.has_method("camera_basis_node"):
		basis_node = party.camera_basis_node()
	if basis_node == null and actor.has_node("CameraPivot"):
		basis_node = actor.get_node_or_null("CameraPivot") as Node3D
	if basis_node:
		forward = -basis_node.global_transform.basis.z
		forward.y = 0.0
		if forward.length() > 0.01:
			forward = forward.normalized()
		else:
			forward = Vector3(0, 0, -1)
	var right := Vector3.UP.cross(forward)
	if right.length() < 0.01:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var local := Vector2(to.dot(right), to.dot(forward))
	var ang := rad_to_deg(atan2(local.x, local.y))
	var is_marshal: bool = (best.get("is_marshal") == true)

	if threat_radar and threat_radar.has_method("update_threat"):
		threat_radar.call("update_threat", true, live, dist, ang, is_marshal, kansas_mode)

	if threat_compass:
		var arrow := _threat_arrow(ang)
		var dir := "ahead"
		if ang > 30.0 and ang < 150.0:
			dir = "right"
		elif ang < -30.0 and ang > -150.0:
			dir = "left"
		elif absf(ang) >= 150.0:
			dir = "behind"
		var kind := "Marshal" if is_marshal else "rogue"
		if not is_marshal and best.has_meta("wave"):
			kind = str(best.get_meta("wave")).replace("_", " ")
		threat_compass.text = "%s  nearest %s  ·  %s  ·  %.0fm   (%d live)" % [arrow, kind, dir, dist, live]

func _threat_arrow(ang_deg: float) -> String:
	var a := ang_deg
	while a > 180.0:
		a -= 360.0
	while a < -180.0:
		a += 360.0
	if a >= -22.5 and a < 22.5:
		return "↑"
	if a >= 22.5 and a < 67.5:
		return "↗"
	if a >= 67.5 and a < 112.5:
		return "→"
	if a >= 112.5 and a < 157.5:
		return "↘"
	if a >= 157.5 or a < -157.5:
		return "↓"
	if a >= -157.5 and a < -112.5:
		return "↙"
	if a >= -112.5 and a < -67.5:
		return "←"
	return "↖"

# ============================================================================
# PHASE P6: DIEGETIC SILVER-ROSE VITALITY, ALLURE RIBBON, QUICK-WHEEL & CODEX
# ============================================================================

func _ensure_grimoire_menu() -> void:
	grimoire_menu = GrimoireMenuScript.new()
	grimoire_menu.name = "GrimoireMenu"
	add_child(grimoire_menu)
	shop_menu = ShopMenuScript.new()
	shop_menu.name = "ShopMenu"
	add_child(shop_menu)

func _connect_save_manager() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	if sm.has_signal("state_changed") and not sm.state_changed.is_connected(_refresh_vitality_ribbon):
		sm.state_changed.connect(_refresh_vitality_ribbon)
	if sm.has_signal("memory_unlocked") and not sm.memory_unlocked.is_connected(_on_memory_unlocked):
		sm.memory_unlocked.connect(_on_memory_unlocked)
	if sm.has_signal("desire_gained") and not sm.desire_gained.is_connected(_on_desire_gained):
		sm.desire_gained.connect(_on_desire_gained)
	if sm.has_signal("style_changed") and not sm.style_changed.is_connected(_on_style_changed):
		sm.style_changed.connect(_on_style_changed)
	if sm.has_signal("quest_updated") and not sm.quest_updated.is_connected(_on_quest_updated):
		sm.quest_updated.connect(_on_quest_updated)
	_refresh_vitality_ribbon()
	_refresh_sub_objective()

func _detect_act_key() -> String:
	var host := get_parent()
	if host == null:
		return ""
	var sp := host.scene_file_path.to_lower()
	if "farmyard" in sp:
		return "kansas"
	if "landing_square" in sp:
		return "munchkin"
	if "poppy" in sp:
		return "poppy"
	if "west_castle" in sp:
		return "winkie"
	if "wizard_tower" in sp:
		return "emerald"
	if "glinda" in sp:
		return "glinda"
	return ""

func _refresh_sub_objective() -> void:
	if objective == null:
		return
	if _sub_objective_lbl == null and objective.get_parent() is VBoxContainer:
		_sub_objective_lbl = Label.new()
		_sub_objective_lbl.name = "SubObjective"
		_sub_objective_lbl.add_theme_font_size_override("font_size", 12)
		_sub_objective_lbl.add_theme_color_override("font_color", Color(0.88, 0.76, 0.54, 0.92))
		_sub_objective_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		(objective.get_parent() as VBoxContainer).add_child(_sub_objective_lbl)
	if _sub_objective_lbl == null:
		return
	if _act_key == "":
		_act_key = _detect_act_key()
	var sm := get_node_or_null("/root/SaveManager")
	var sq := str(sm.call("active_side_quest_line", _act_key)) if (sm and _act_key != "" and sm.has_method("active_side_quest_line")) else ""
	_sub_objective_lbl.visible = (sq != "")
	_sub_objective_lbl.text = sq

func _on_quest_updated(_qid: String, title: String, completed: bool) -> void:
	_refresh_sub_objective()
	if has_method("show_toast"):
		call("show_toast", ("★ Vile Request Complete: %s!" if completed else "◈ Progress: %s") % title, 3.2)

func _on_style_changed(rank_label: String, _pts: float, mult: float) -> void:
	if _style_panel == null:
		return
	if rank_label == "" or kansas_mode:
		_style_panel.visible = false
		return
	_style_panel.visible = true
	_style_rank_lbl.text = rank_label
	_style_mult_lbl.text = "%.2f× DESIRE" % mult
	if not _is_headless():
		_style_panel.pivot_offset = _style_panel.size * 0.5
		_style_panel.scale = Vector2(1.08, 1.08)
		var tw := create_tween()
		tw.tween_property(_style_panel, "scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_OUT)

func _on_memory_unlocked(_mem_id: String, title: String) -> void:
	if has_method("show_toast"):
		call("show_toast", "✦ Shattered Memory: %s  (Grimoire [J])" % title)

func _on_desire_gained(amount: int, reason: String) -> void:
	if has_method("show_toast") and reason != "":
		call("show_toast", "♦ +%d Desire  ·  %s" % [amount, reason])

func _build_vitality_ribbon() -> void:
	var safe := get_node_or_null("SafeRoot") as Control
	if safe == null:
		return

	if objective_panel and objective_panel.get_node_or_null("OrnateObjFrame") == null:
		var o_frame := OrnateFrame.new()
		o_frame.name = "OrnateObjFrame"
		o_frame.inset = 4.0
		o_frame.corner_size = 11.0
		o_frame.show_diamonds = false
		o_frame.animated_sheen = true
		objective_panel.add_child(o_frame)

	# ========================================================================
	# TOP-RIGHT: Frameless Floating Alice-Class Rose Vine + Allure Gauge + Desire Crystal
	# Matches ref_03_gameplay_hud.jpg pixel-for-pixel!
	# ========================================================================
	var cluster := VBoxContainer.new()
	cluster.name = "VitalityRibbon"
	cluster.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cluster.offset_left = -284.0
	cluster.offset_right = -16.0
	cluster.offset_top = 10.0
	cluster.offset_bottom = 148.0
	cluster.add_theme_constant_override("separation", 2)
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(cluster)
	_vitality_panel = cluster

	_rose_bar = RoseVitalityBar.new()
	cluster.add_child(_rose_bar)

	_allure_gauge = AllureGauge.new()
	cluster.add_child(_allure_gauge)

	_desire_lbl = Label.new()
	_desire_lbl.text = "[B] Boutique  ·  [J] Grimoire  ·  [Q] Wheel  ·  [G] Lens"
	_desire_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_desire_lbl.add_theme_font_size_override("font_size", 10)
	_desire_lbl.add_theme_color_override("font_color", Color(0.84, 0.76, 0.68, 0.88))
	_desire_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.05, 0.90))
	_desire_lbl.add_theme_constant_override("outline_size", 3)
	_desire_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cluster.add_child(_desire_lbl)

	# ========================================================================
	# RIGHT-MIDDLE: Live 2026 Combo & Allure Style Rank Emblem (D -> ★ SOVEREIGN)
	# ========================================================================
	_style_panel = PanelContainer.new()
	_style_panel.name = "StyleRankEmblem"
	_style_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_style_panel.offset_left = -224.0
	_style_panel.offset_right = -18.0
	_style_panel.offset_top = 160.0
	_style_panel.offset_bottom = 216.0
	_style_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sp_st := StyleBoxFlat.new()
	sp_st.bg_color = Color(0.11, 0.055, 0.145, 0.92)
	sp_st.border_color = Color(0.95, 0.80, 0.44, 0.95)
	sp_st.set_border_width_all(2)
	sp_st.set_corner_radius_all(8)
	sp_st.content_margin_left = 16
	sp_st.content_margin_right = 16
	sp_st.content_margin_top = 8
	sp_st.content_margin_bottom = 8
	_style_panel.add_theme_stylebox_override("panel", sp_st)
	var s_vb := VBoxContainer.new()
	s_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s_vb.add_theme_constant_override("separation", 1)
	_style_panel.add_child(s_vb)
	_style_rank_lbl = Label.new()
	_style_rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_rank_lbl.add_theme_font_size_override("font_size", 16)
	_style_rank_lbl.add_theme_color_override("font_color", Color(0.99, 0.88, 0.52))
	s_vb.add_child(_style_rank_lbl)
	_style_mult_lbl = Label.new()
	_style_mult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_mult_lbl.add_theme_font_size_override("font_size", 10)
	_style_mult_lbl.add_theme_color_override("font_color", Color(0.92, 0.58, 0.74))
	s_vb.add_child(_style_mult_lbl)
	_style_panel.visible = false
	safe.add_child(_style_panel)

	# Full-screen Emerald Spectacles Lens Overlay ([G] toggle!)
	_spectacles_overlay = ColorRect.new()
	_spectacles_overlay.name = "EmeraldSpectaclesOverlay"
	_spectacles_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spectacles_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spectacles_overlay.color = Color(0.06, 0.48, 0.28, 0.14)
	if not _is_headless():
		var gmat := ShaderMaterial.new()
		gmat.shader = SpectaclesShader
		_spectacles_overlay.material = gmat
	_spectacles_overlay.visible = false
	safe.add_child(_spectacles_overlay)
	safe.move_child(_spectacles_overlay, 0)

	# ========================================================================
	# BOTTOM-LEFT: Circular 5-Portrait Party Medallion Wheel (ref_03_gameplay_hud.jpg)
	# ========================================================================
	_party_wheel = PartyMedallionWheel.new()
	_party_wheel.name = "PartyMedallionWheel"
	_party_wheel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_party_wheel.offset_left = 10.0
	_party_wheel.offset_right = 258.0
	_party_wheel.offset_top = -188.0
	_party_wheel.offset_bottom = -10.0
	_party_wheel.visible = false
	safe.add_child(_party_wheel)

	# ========================================================================
	# BOTTOM-RIGHT: 4 Circular Brass Armament Medallion Slots (ref_03_gameplay_hud.jpg)
	# ========================================================================
	_armament_dock = ArmamentDock.new()
	_armament_dock.name = "ArmamentDock"
	_armament_dock.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_armament_dock.offset_left = -264.0
	_armament_dock.offset_right = -18.0
	_armament_dock.offset_top = -112.0
	_armament_dock.offset_bottom = -14.0
	_armament_dock.visible = false
	safe.add_child(_armament_dock)

	# Full-screen Alice-Class Rapture / Hysteria Vignette Shader Overlay (hidden until H triggers!)
	_rapture_overlay = ColorRect.new()
	_rapture_overlay.name = "RaptureOverlay"
	_rapture_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rapture_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rapture_overlay.color = Color(0.75, 0.04, 0.22, 0.18)
	if not _is_headless():
		var rmat := ShaderMaterial.new()
		rmat.shader = RaptureShader
		_rapture_overlay.material = rmat
	_rapture_overlay.visible = false
	safe.add_child(_rapture_overlay)
	safe.move_child(_rapture_overlay, 0)

func set_active_armament(arm_name: String) -> void:
	if _armament_dock and _armament_dock.has_method("set_active_by_name"):
		_armament_dock.call("set_active_by_name", arm_name)
	if has_method("show_toast"):
		call("show_toast", "✦ Armament Equipped: %s (Press C)" % arm_name)

func set_rapture_visual(active: bool) -> void:
	if _rapture_overlay:
		_rapture_overlay.visible = active
	if has_method("show_toast"):
		call("show_toast", "✦ RAPTURE MODE ACTIVE — 2.5× Damage!" if active else "Rapture Mode faded.")

func _ensure_boss_bar() -> void:
	if _boss_panel != null:
		return
	var safe := get_node_or_null("SafeRoot") as Control
	if safe == null:
		return
	_boss_panel = PanelContainer.new()
	_boss_panel.name = "BossHealthBar"
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.offset_left = -240.0
	_boss_panel.offset_right = 240.0
	_boss_panel.offset_top = 16.0
	_boss_panel.offset_bottom = 80.0
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.03, 0.07, 0.92)
	st.border_color = Color(0.94, 0.76, 0.30, 0.95)
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 6
	st.content_margin_bottom = 8
	_boss_panel.add_theme_stylebox_override("panel", st)
	_boss_panel.visible = false
	safe.add_child(_boss_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_boss_panel.add_child(vb)
	var hdr := HBoxContainer.new()
	vb.add_child(hdr)
	_boss_name_lbl = Label.new()
	_boss_name_lbl.add_theme_font_size_override("font_size", 14)
	_boss_name_lbl.add_theme_color_override("font_color", Color(0.98, 0.86, 0.50))
	_boss_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(_boss_name_lbl)
	_boss_phase_lbl = Label.new()
	_boss_phase_lbl.add_theme_font_size_override("font_size", 11)
	_boss_phase_lbl.add_theme_color_override("font_color", Color(1.0, 0.42, 0.58))
	hdr.add_child(_boss_phase_lbl)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(420, 12)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.16, 0.08, 0.12, 0.95)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.86, 0.14, 0.28, 0.98)
	fg.set_corner_radius_all(4)
	_boss_bar.add_theme_stylebox_override("background", bg)
	_boss_bar.add_theme_stylebox_override("fill", fg)
	vb.add_child(_boss_bar)

func show_boss_bar(boss_name: String, phase_label: String, cur_hp: float, max_hp_val: float) -> void:
	_ensure_boss_bar()
	if _boss_panel == null:
		return
	_boss_panel.visible = true
	_boss_name_lbl.text = boss_name
	_boss_phase_lbl.text = phase_label
	_boss_bar.max_value = maxf(1.0, max_hp_val)
	_boss_bar.value = clampf(cur_hp, 0.0, max_hp_val)
	var lc := get_node_or_null("LevelCompass") as Control
	if lc:
		lc.offset_top = 86.0
		lc.offset_bottom = 114.0

func hide_boss_bar() -> void:
	if _boss_panel:
		_boss_panel.visible = false
	var lc := get_node_or_null("LevelCompass") as Control
	if lc:
		lc.offset_top = 48.0
		lc.offset_bottom = 78.0

func _refresh_vitality_ribbon() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	var cur_hp: int = int(sm.hp)
	if _rose_bar and _rose_bar.has_method("set_vitality"):
		_rose_bar.call("set_vitality", cur_hp, int(sm.max_hp), kansas_mode)
	if _allure_gauge and _allure_gauge.has_method("set_values"):
		_allure_gauge.call("set_values", float(sm.allure), int(sm.desire_fragments), kansas_mode)
		_allure_gauge.visible = not kansas_mode
	if _desire_lbl:
		_desire_lbl.visible = not kansas_mode
		_desire_lbl.text = "[B] Boutique  ·  [J] Grimoire  ·  [Q] Wheel"

func _build_quick_wheel() -> void:
	_wheel_root = CenterContainer.new()
	_wheel_root.name = "CompanionQuickWheel"
	_wheel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wheel_root.visible = false
	add_child(_wheel_root)

	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(500, 290)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.068, 0.036, 0.085, 0.95)
	st.border_color = Color(0.90, 0.74, 0.36, 0.95)
	st.set_border_width_all(2)
	st.set_corner_radius_all(16)
	st.content_margin_left = 30
	st.content_margin_right = 30
	st.content_margin_top = 24
	st.content_margin_bottom = 24
	pc.add_theme_stylebox_override("panel", st)
	var q_frame := OrnateFrame.new()
	q_frame.outer_pad = 8.0
	q_frame.inset = 5.0
	q_frame.corner_size = 13.0
	q_frame.animated_sheen = true
	pc.add_child(q_frame)
	_wheel_root.add_child(pc)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)

	var hdr := Label.new()
	hdr.text = "✦  THE CIRCLE OF THE ROAD  (Click or 1–5 · Q to Close)"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", Color(0.96, 0.84, 0.50))
	vb.add_child(hdr)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for def in LEAD_DEFS:
		var btn := Button.new()
		btn.text = "  [%s] %s  —  %s" % [def["key"], def["name"], def["verb"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(210, 46)
		btn.icon = _load_hud_portrait("res://assets/art/portraits/%s.png" % str(def["id"]))
		btn.expand_icon = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cid: StringName = def["id"]
		btn.pressed.connect(func():
			var p := get_node_or_null("/root/Party")
			if p and p.has_method("set_leader"):
				p.call("set_leader", cid)
			_toggle_quick_wheel(false)
		)
		grid.add_child(btn)
		_wheel_buttons[cid] = btn

func _toggle_quick_wheel(force_state = null) -> void:
	if _wheel_root == null:
		return
	_wheel_open = not _wheel_open if force_state == null else bool(force_state)
	_wheel_root.visible = _wheel_open
	if _wheel_open and not _is_headless():
		_wheel_root.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_wheel_root, "modulate:a", 1.0, 0.16)
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _wheel_open else Input.MOUSE_MODE_CAPTURED

func _load_hud_portrait(res_path: String) -> Texture2D:
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_toggle_quick_wheel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_G and not kansas_mode:
			if _spectacles_overlay:
				_spectacles_overlay.visible = not _spectacles_overlay.visible
				var sm := get_node_or_null("/root/SaveManager")
				if sm:
					sm.emerald_spectacles_on = _spectacles_overlay.visible
				show_toast("✦ Locked Green-Tinted Spectacles: ON (Illusions Revealed)" if _spectacles_overlay.visible else "Green-Tinted Spectacles removed.", 2.6)
			get_viewport().set_input_as_handled()
