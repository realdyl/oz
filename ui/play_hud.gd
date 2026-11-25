extends CanvasLayer

const OzThemeFactory := preload("res://ui/theme/oz_theme_factory.gd")
const ThreatRadarScript := preload("res://ui/widgets/threat_radar.gd")
const PauseMenuScript := preload("res://ui/shell/pause_menu.gd")
const GrimoireMenuScript := preload("res://ui/grimoire_menu.gd")
const ShopMenuScript := preload("res://ui/shop_menu.gd")
const OrnateFrame := preload("res://ui/widgets/ornate_frame.gd")
const RoseVitalityBar := preload("res://ui/widgets/rose_vitality_bar.gd")
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
var _vitality_panel: PanelContainer
var _rose_bar: Control
var _petal_labels: Array[Label] = []
var _allure_bar: ProgressBar
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
		lead_bar.visible = not on and _roster_text != ""
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
		lead_bar.visible = not kansas_mode and text != ""
	_refresh_lead_bar()

func set_objective(text: String) -> void:
	if objective == null:
		return
	var changed := (text != _last_objective)
	_last_objective = text
	objective.text = text

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
	_update_grass_rustle()
	_update_threat_compass()
	_update_controls_strip()

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
		var want_lead := (not kansas_mode) and (_roster_text != "") and (not dia_open)
		if lead_bar.visible != want_lead:
			lead_bar.visible = want_lead
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
	_refresh_vitality_ribbon()

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
	_vitality_panel = PanelContainer.new()
	_vitality_panel.name = "VitalityRibbon"
	_vitality_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_vitality_panel.offset_left = -326.0
	_vitality_panel.offset_right = -16.0
	_vitality_panel.offset_top = 14.0
	_vitality_panel.offset_bottom = 132.0
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.086, 0.051, 0.102, 0.90) # #160D1A Smoked Glass
	st.border_color = Color(0.769, 0.620, 0.353, 0.92) # #C49E5A Antique Brass
	st.set_border_width_all(2)
	st.set_corner_radius_all(6)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	_vitality_panel.add_theme_stylebox_override("panel", st)
	safe.add_child(_vitality_panel)

	var v_frame := OrnateFrame.new()
	v_frame.inset = 4.0
	v_frame.corner_size = 10.0
	v_frame.show_diamonds = false
	_vitality_panel.add_child(v_frame)

	if objective_panel and objective_panel.get_node_or_null("OrnateObjFrame") == null:
		var o_frame := OrnateFrame.new()
		o_frame.name = "OrnateObjFrame"
		o_frame.inset = 4.0
		o_frame.corner_size = 10.0
		o_frame.show_diamonds = false
		objective_panel.add_child(o_frame)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_vitality_panel.add_child(vb)

	# Row 1: 5 Crimson-Silver Rose Buds on a thorny silver vine (ref_03_gameplay_hud.jpg)
	var petal_row := HBoxContainer.new()
	petal_row.add_theme_constant_override("separation", 6)
	vb.add_child(petal_row)
	var vit_tag := Label.new()
	vit_tag.text = "VITALITY"
	vit_tag.add_theme_font_size_override("font_size", 11)
	vit_tag.add_theme_color_override("font_color", Color(0.910, 0.776, 0.478))
	vit_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	petal_row.add_child(vit_tag)
	_rose_bar = RoseVitalityBar.new()
	petal_row.add_child(_rose_bar)

	# Row 2: Allure / Desire Filigree Progress Bar
	_allure_bar = ProgressBar.new()
	_allure_bar.min_value = 0.0
	_allure_bar.max_value = 100.0
	_allure_bar.value = 35.0
	_allure_bar.show_percentage = false
	_allure_bar.custom_minimum_size = Vector2(220, 8)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.14, 0.10, 0.18, 0.9)
	bg_sb.set_corner_radius_all(4)
	var fg_sb := StyleBoxFlat.new()
	fg_sb.bg_color = Color(0.92, 0.30, 0.56, 0.95)
	fg_sb.set_corner_radius_all(4)
	_allure_bar.add_theme_stylebox_override("background", bg_sb)
	_allure_bar.add_theme_stylebox_override("fill", fg_sb)
	vb.add_child(_allure_bar)

	# Row 3: Desire Fragments + Grimoire/Wheel Shortcuts
	_desire_lbl = Label.new()
	_desire_lbl.text = "♦ 0 Desire  ·  [J] Grimoire  ·  [Q] Wheel"
	_desire_lbl.add_theme_font_size_override("font_size", 11)
	_desire_lbl.add_theme_color_override("font_color", Color(0.94, 0.84, 0.56))
	vb.add_child(_desire_lbl)

	# Row 4: Phase P7/P10.1 Active Rated-M Armament Icon + Rapture Mode Prompt
	var arm_row := HBoxContainer.new()
	arm_row.add_theme_constant_override("separation", 6)
	vb.add_child(arm_row)
	var arm_frame := PanelContainer.new()
	var af_st := StyleBoxFlat.new()
	af_st.bg_color = Color(0.10, 0.05, 0.12, 0.92)
	af_st.border_color = Color(0.82, 0.66, 0.36, 0.90)
	af_st.set_border_width_all(1)
	af_st.set_corner_radius_all(3)
	af_st.set_content_margin_all(1)
	arm_frame.add_theme_stylebox_override("panel", af_st)
	arm_row.add_child(arm_frame)
	_armament_icon = TextureRect.new()
	_armament_icon.custom_minimum_size = Vector2(24, 24)
	_armament_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_armament_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_armament_icon.texture = _load_hud_portrait("res://assets/art/icons/arm_whip.png")
	arm_frame.add_child(_armament_icon)
	_armament_lbl = Label.new()
	_armament_lbl.text = "[C] Lace Whip  ·  [Z/X] Swap  ·  [H] Rapture"
	_armament_lbl.add_theme_font_size_override("font_size", 11)
	_armament_lbl.add_theme_color_override("font_color", Color(0.98, 0.48, 0.72))
	arm_row.add_child(_armament_lbl)

	# Full-screen Rapture / Hysteria crimson edge overlay (hidden until H triggers!)
	_rapture_overlay = ColorRect.new()
	_rapture_overlay.name = "RaptureOverlay"
	_rapture_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rapture_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rapture_overlay.color = Color(0.75, 0.04, 0.22, 0.16)
	_rapture_overlay.visible = false
	safe.add_child(_rapture_overlay)
	safe.move_child(_rapture_overlay, 0)

func set_active_armament(arm_name: String) -> void:
	if _armament_lbl:
		_armament_lbl.text = "[C] %s  ·  [Z/X] Swap  ·  [H] Rapture" % arm_name
	if _armament_icon:
		var ln := arm_name.to_lower()
		var icon_path := "res://assets/art/icons/arm_whip.png"
		if "silk" in ln or "ribbon" in ln or "bind" in ln:
			icon_path = "res://assets/art/icons/arm_ribbon.png"
		elif "perfume" in ln or "atomizer" in ln or "mist" in ln:
			icon_path = "res://assets/art/icons/arm_atomizer.png"
		elif "chain" in ln or "tether" in ln:
			icon_path = "res://assets/art/icons/arm_chain.png"
		_armament_icon.texture = _load_hud_portrait(icon_path)
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
	if _allure_bar:
		_allure_bar.value = float(sm.allure)
	if _desire_lbl:
		_desire_lbl.text = "♦ %d Desire · [B] Shop · [J] Codex · [Q] Wheel" % int(sm.desire_fragments)

func _build_quick_wheel() -> void:
	_wheel_root = CenterContainer.new()
	_wheel_root.name = "CompanionQuickWheel"
	_wheel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wheel_root.visible = false
	add_child(_wheel_root)

	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(460, 260)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.04, 0.09, 0.93)
	st.border_color = Color(0.90, 0.74, 0.36, 0.95)
	st.set_border_width_all(2)
	st.set_corner_radius_all(18)
	st.content_margin_left = 20
	st.content_margin_right = 20
	st.content_margin_top = 16
	st.content_margin_bottom = 16
	pc.add_theme_stylebox_override("panel", st)
	_wheel_root.add_child(pc)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)

	var hdr := Label.new()
	hdr.text = "✦  CIRCLE QUICK-WHEEL  (Click or 1–5 · Q to Close)"
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
		btn.text = "[%s] %s  —  %s" % [def["key"], def["name"], def["verb"]]
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
