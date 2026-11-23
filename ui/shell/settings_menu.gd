extends Control

const OzThemeFactory := preload("res://ui/theme/oz_theme_factory.gd")

signal back_pressed

var kansas_mode: bool = false

var _card: PanelContainer
var _title: Label
var _volume_slider: HSlider
var _volume_val: Label
var _sens_slider: HSlider
var _sens_val: Label
var _scale_slider: HSlider
var _scale_val: Label
var _fullscreen_check: CheckButton
var _tts_check: CheckButton
var _back_btn: Button

func _ready() -> void:
	custom_minimum_size = Vector2(460, 480)
	_build_ui()
	apply_theme_mode(kansas_mode)

func _build_ui() -> void:
	# Centered card
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.set_anchors_preset(PRESET_CENTER)
	_card.custom_minimum_size = Vector2(460, 460)
	_card.offset_left = -230.0
	_card.offset_top = -230.0
	_card.offset_right = 230.0
	_card.offset_bottom = 230.0
	add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_card.add_child(vbox)

	# Title
	_title = Label.new()
	_title.text = "SETTINGS"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_title)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	# Master Volume
	var vol_box := VBoxContainer.new()
	vol_box.add_theme_constant_override("separation", 4)
	var vol_hdr := HBoxContainer.new()
	var vol_lbl := Label.new()
	vol_lbl.text = "Master Volume"
	vol_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	_volume_val = Label.new()
	_volume_val.text = "100%"
	vol_hdr.add_child(vol_lbl)
	vol_hdr.add_child(_volume_val)
	vol_box.add_child(vol_hdr)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.value = 1.0
	_volume_slider.value_changed.connect(_on_volume_changed)
	vol_box.add_child(_volume_slider)
	vbox.add_child(vol_box)

	# Mouse Sensitivity
	var sens_box := VBoxContainer.new()
	sens_box.add_theme_constant_override("separation", 4)
	var sens_hdr := HBoxContainer.new()
	var sens_lbl := Label.new()
	sens_lbl.text = "Mouse Sensitivity"
	sens_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	_sens_val = Label.new()
	_sens_val.text = "1.0x"
	sens_hdr.add_child(sens_lbl)
	sens_hdr.add_child(_sens_val)
	sens_box.add_child(sens_hdr)

	_sens_slider = HSlider.new()
	_sens_slider.min_value = 0.2
	_sens_slider.max_value = 2.5
	_sens_slider.step = 0.1
	_sens_slider.value = 1.0
	_sens_slider.value_changed.connect(_on_sens_changed)
	sens_box.add_child(_sens_slider)
	vbox.add_child(sens_box)

	# UI Scale (Accessibility)
	var scale_box := VBoxContainer.new()
	scale_box.add_theme_constant_override("separation", 4)
	var scale_hdr := HBoxContainer.new()
	var scale_lbl := Label.new()
	scale_lbl.text = "UI Scale (A11y)"
	scale_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	_scale_val = Label.new()
	_scale_val.text = "100%"
	scale_hdr.add_child(scale_lbl)
	scale_hdr.add_child(_scale_val)
	scale_box.add_child(scale_hdr)

	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.8
	_scale_slider.max_value = 1.4
	_scale_slider.step = 0.05
	_scale_slider.value = 1.0
	_scale_slider.value_changed.connect(_on_scale_changed)
	scale_box.add_child(_scale_slider)
	vbox.add_child(scale_box)

	# Fullscreen Toggle
	_fullscreen_check = CheckButton.new()
	_fullscreen_check.text = "Fullscreen"
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(_fullscreen_check)

	# Voice / TTS Toggle
	_tts_check = CheckButton.new()
	_tts_check.text = "Spoken Dialogue (TTS Voice)"
	_tts_check.toggled.connect(_on_tts_toggled)
	vbox.add_child(_tts_check)

	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Back button
	_back_btn = Button.new()
	_back_btn.text = "← Back to Pause Menu"
	_back_btn.pressed.connect(func(): back_pressed.emit())
	vbox.add_child(_back_btn)

func apply_theme_mode(p_kansas: bool) -> void:
	kansas_mode = p_kansas
	if _card == null:
		return
	theme = OzThemeFactory.make_button_theme(p_kansas)
	_card.add_theme_stylebox_override("panel", OzThemeFactory.make_modal_style(p_kansas))
	var accent := OzThemeFactory.accent_color(p_kansas)
	_title.add_theme_color_override("font_color", accent)

func _on_volume_changed(val: float) -> void:
	_volume_val.text = "%d%%" % int(val * 100.0)
	var db := linear_to_db(clampf(val, 0.0001, 1.0))
	AudioServer.set_bus_volume_db(0, db)

func _on_sens_changed(val: float) -> void:
	_sens_val.text = "%.1fx" % val
	var party := get_node_or_null("/root/Party")
	if party and "mouse_sensitivity" in party:
		party.set("mouse_sensitivity", 0.0025 * val)

func _on_scale_changed(val: float) -> void:
	_scale_val.text = "%d%%" % int(val * 100.0)
	if get_tree() and get_tree().root:
		get_tree().root.content_scale_factor = val

func _on_fullscreen_toggled(on: bool) -> void:
	if DisplayServer.get_name() in ["headless", "Dummy"]:
		return
	if on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_tts_toggled(on: bool) -> void:
	var dia := get_node_or_null("/root/DialogueUI")
	if dia and dia.has_method("set_tts_enabled"):
		dia.call("set_tts_enabled", on)
