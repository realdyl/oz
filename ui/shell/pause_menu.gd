extends CanvasLayer

const OzThemeFactory := preload("res://ui/theme/oz_theme_factory.gd")
const SettingsMenuScript := preload("res://ui/shell/settings_menu.gd")
const OrnateFrame := preload("res://ui/widgets/ornate_frame.gd")

## Full in-game Pause Shell for Oz: The Road Home.
## Handles Esc toggle, tree pause, mouse capture release/restore,
## objective recap, restart checkpoint, and embedded Settings menu.

var kansas_mode: bool = false
var is_open: bool = false

var _root: Control
var _backdrop: ColorRect
var _main_card: PanelContainer
var _title: Label
var _subtitle: Label
var _objective_recap: Label
var _settings_view: Control
var _saves_card: PanelContainer
var _saves_list: VBoxContainer

var _resume_btn: Button
var _grimoire_btn: Button
var _saves_btn: Button
var _settings_btn: Button
var _restart_btn: Button
var _quit_btn: Button

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	apply_theme_mode(kansas_mode)

func _input(event: InputEvent) -> void:
	if DisplayServer.get_name() in ["headless", "Dummy"]:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if is_open:
			if _settings_view and _settings_view.visible:
				_show_main_card()
			else:
				close()
			get_viewport().set_input_as_handled()
		else:
			# Do not open pause if level is actively transitioning
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
	_show_main_card()
	if _resume_btn:
		_resume_btn.grab_focus()

func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	# Restore mouse capture if in normal gameplay
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_objective_text(text: String) -> void:
	if _objective_recap:
		_objective_recap.text = "Current Goal: " + text

func apply_theme_mode(p_kansas: bool) -> void:
	kansas_mode = p_kansas
	if _main_card == null:
		return
	_main_card.theme = OzThemeFactory.make_button_theme(p_kansas)
	_main_card.add_theme_stylebox_override("panel", OzThemeFactory.make_modal_style(p_kansas))
	var accent := OzThemeFactory.accent_color(p_kansas)
	_title.add_theme_color_override("font_color", accent)
	_subtitle.add_theme_color_override("font_color", OzThemeFactory.muted_text_color(p_kansas))
	if _settings_view:
		_settings_view.call("apply_theme_mode", p_kansas)

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Full-screen dark obsidian-plum backdrop + ornate filigree frame (ref_02_main_menu_ui.jpg)
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.071, 0.035, 0.078, 0.84)
	_root.add_child(_backdrop)

	var screen_frame := OrnateFrame.new()
	screen_frame.inset = 14.0
	screen_frame.corner_size = 24.0
	_root.add_child(screen_frame)

	# Full-screen CenterContainer guarantees dead-center modals at any resolution / UI scale
	var center := CenterContainer.new()
	center.name = "ModalCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	# Main card container
	_main_card = PanelContainer.new()
	_main_card.custom_minimum_size = Vector2(500, 460)
	center.add_child(_main_card)

	var card_frame := OrnateFrame.new()
	card_frame.inset = 6.0
	card_frame.corner_size = 14.0
	_main_card.add_child(card_frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_main_card.add_child(vbox)

	# Silver-Rose Crest Title & Subtitle (ref_02_main_menu_ui.jpg)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 3)
	var crest := Label.new()
	crest.text = "✦   ✿   ✦"
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.add_theme_font_size_override("font_size", 18)
	crest.add_theme_color_override("font_color", Color(0.784, 0.831, 0.902))
	header.add_child(crest)

	_title = Label.new()
	_title.text = "OZ: THE ROAD HOME"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	header.add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = "— Game Paused —"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 14)
	header.add_child(_subtitle)
	vbox.add_child(header)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Objective Recap Card
	var recap_panel := PanelContainer.new()
	recap_panel.add_theme_stylebox_override("panel", OzThemeFactory.make_pill_style(kansas_mode, 14, 8))
	_objective_recap = Label.new()
	_objective_recap.text = "Current Goal: Follow the Yellow Brick Road"
	_objective_recap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_recap.add_theme_font_size_override("font_size", 14)
	recap_panel.add_child(_objective_recap)
	vbox.add_child(recap_panel)

	# Buttons
	_resume_btn = Button.new()
	_resume_btn.text = "Resume Game"
	_resume_btn.pressed.connect(close)
	vbox.add_child(_resume_btn)

	_grimoire_btn = Button.new()
	_grimoire_btn.text = "Oz Grimoire / Codex (J)"
	_grimoire_btn.pressed.connect(_open_grimoire)
	vbox.add_child(_grimoire_btn)

	var shop_btn := Button.new()
	shop_btn.text = "The Tailor of Vices — Shop (B)"
	shop_btn.pressed.connect(_open_shop)
	vbox.add_child(shop_btn)

	_saves_btn = Button.new()
	_saves_btn.text = "Save / Load Game (Slots 1–3)"
	_saves_btn.pressed.connect(_show_saves)
	vbox.add_child(_saves_btn)

	_settings_btn = Button.new()
	_settings_btn.text = "Settings"
	_settings_btn.pressed.connect(_show_settings)
	vbox.add_child(_settings_btn)

	_restart_btn = Button.new()
	_restart_btn.text = "Restart Checkpoint"
	_restart_btn.pressed.connect(_on_restart_checkpoint)
	vbox.add_child(_restart_btn)

	_quit_btn = Button.new()
	_quit_btn.text = "Quit to Desktop"
	_quit_btn.pressed.connect(func(): get_tree().quit())
	vbox.add_child(_quit_btn)

	# Embedded Settings View (inside the same CenterContainer so it is always dead-center)
	_settings_view = SettingsMenuScript.new()
	_settings_view.visible = false
	_settings_view.connect("back_pressed", _show_main_card)
	center.add_child(_settings_view)

	# Embedded 3-Slot Save / Load Panel
	_saves_card = PanelContainer.new()
	_saves_card.custom_minimum_size = Vector2(540, 400)
	_saves_card.visible = false
	_saves_card.add_theme_stylebox_override("panel", OzThemeFactory.make_modal_style(kansas_mode))
	center.add_child(_saves_card)
	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 12)
	_saves_card.add_child(svb)
	var shdr := Label.new()
	shdr.text = "✦  SAVE & LOAD SLOTS"
	shdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shdr.add_theme_font_size_override("font_size", 20)
	shdr.add_theme_color_override("font_color", Color(0.95, 0.82, 0.44))
	svb.add_child(shdr)
	_saves_list = VBoxContainer.new()
	_saves_list.add_theme_constant_override("separation", 10)
	_saves_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svb.add_child(_saves_list)
	var sback := Button.new()
	sback.text = "Back to Pause Menu"
	sback.pressed.connect(_show_main_card)
	svb.add_child(sback)

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
	_saves_card.visible = true
	_refresh_saves_list()

func _refresh_saves_list() -> void:
	for c in _saves_list.get_children():
		c.queue_free()
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	for slot in range(1, 4):
		var info: Dictionary = sm.get_slot_info(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_saves_list.add_child(row)
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if info.is_empty():
			lbl.text = "Slot %d  —  [Empty]" % slot
		else:
			lbl.text = "Slot %d  ·  %s\n♦ %d Desire  ·  %s" % [slot, str(info.get("chapter", "Oz")), int(info.get("desire_fragments", 0)), str(info.get("saved_at", ""))]
		lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(lbl)
		var s_idx := slot
		var b_save := Button.new()
		b_save.text = "Save"
		b_save.pressed.connect(func():
			sm.save_slot(s_idx)
			_refresh_saves_list()
		)
		row.add_child(b_save)
		var b_load := Button.new()
		b_load.text = "Load"
		b_load.disabled = info.is_empty()
		b_load.pressed.connect(func():
			close()
			sm.load_slot(s_idx)
		)
		row.add_child(b_load)
		var b_del := Button.new()
		b_del.text = "✕"
		b_del.disabled = info.is_empty()
		b_del.pressed.connect(func():
			sm.delete_slot(s_idx)
			_refresh_saves_list()
		)
		row.add_child(b_del)

func _show_settings() -> void:
	_main_card.visible = false
	if _saves_card:
		_saves_card.visible = false
	_settings_view.visible = true

func _show_main_card() -> void:
	_settings_view.visible = false
	if _saves_card:
		_saves_card.visible = false
	_main_card.visible = true
	_resume_btn.grab_focus()

func _on_restart_checkpoint() -> void:
	close()
	get_tree().reload_current_scene()
