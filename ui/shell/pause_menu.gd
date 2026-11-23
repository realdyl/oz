extends CanvasLayer

const OzThemeFactory := preload("res://ui/theme/oz_theme_factory.gd")
const SettingsMenuScript := preload("res://ui/shell/settings_menu.gd")

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

var _resume_btn: Button
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

	# Full-screen dark vignette backdrop
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.04, 0.03, 0.05, 0.72)
	_root.add_child(_backdrop)

	# Main card container
	_main_card = PanelContainer.new()
	_main_card.custom_minimum_size = Vector2(480, 460)
	_main_card.set_anchors_preset(Control.PRESET_CENTER)
	_main_card.offset_left = -240.0
	_main_card.offset_top = -230.0
	_main_card.offset_right = 240.0
	_main_card.offset_bottom = 230.0
	_root.add_child(_main_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_main_card.add_child(vbox)

	# Title & Subtitle
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
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

	# Embedded Settings View
	_settings_view = SettingsMenuScript.new()
	_settings_view.visible = false
	_settings_view.connect("back_pressed", _show_main_card)
	_settings_view.set_anchors_preset(Control.PRESET_CENTER)
	_root.add_child(_settings_view)

func _show_settings() -> void:
	_main_card.visible = false
	_settings_view.visible = true

func _show_main_card() -> void:
	_settings_view.visible = false
	_main_card.visible = true
	_resume_btn.grab_focus()

func _on_restart_checkpoint() -> void:
	close()
	get_tree().reload_current_scene()
