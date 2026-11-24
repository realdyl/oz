extends Node

## On-screen dialogue v2 + optional OS TTS (when the platform has voices).
## Storybook card with raised Speaker Nameplate, smooth typewriter reveal,
## tactile [E] Continue keycap chip, and automatic Oz/Kansas palette matching.

var tts_enabled: bool = true

var _box: Control
var _panel: PanelContainer
var _nameplate: PanelContainer
var _speaker: Label
var _body: Label
var _hint_wrap: HBoxContainer
var _hint_cap: PanelContainer
var _hint_key: Label
var _hint_lbl: Label
var _divider: ColorRect
var _portrait_frame: PanelContainer
var _portrait_tex: TextureRect
var _portrait_cache: Dictionary = {}

var _visible_t: float = 0.0
var _tts_voice: String = ""
var _type_progress: float = 0.0
var _typing: bool = false
var _kansas_cached: bool = false

const TYPE_CPS := 75.0
const OzThemeFactory := preload("res://ui/theme/oz_theme_factory.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_hide()
	_pick_voice()

func _build() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DialogueLayer"
	layer.layer = 80
	add_child(layer)

	_box = Control.new()
	_box.name = "DialogueRoot"
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_box)

	# Center container at bottom so card has refined modern margins on 720p and 1080p+
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	anchor.offset_left = 110.0
	anchor.offset_right = -110.0
	anchor.offset_top = -188.0
	anchor.offset_bottom = -20.0
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(anchor)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_top = 18.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_panel)

	var card_hbox := HBoxContainer.new()
	card_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_hbox.add_theme_constant_override("separation", 16)
	_panel.add_child(card_hbox)

	# Gilded Speaker Portrait Medallion (auto-shown for Dorothy, Scarecrow, Tin Man, Lion, Toto!)
	_portrait_frame = PanelContainer.new()
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.visible = false
	var pf_st := StyleBoxFlat.new()
	pf_st.bg_color = Color(0.08, 0.04, 0.10, 1.0)
	pf_st.border_color = Color(0.769, 0.620, 0.353, 0.96)
	pf_st.set_border_width_all(2)
	pf_st.set_corner_radius_all(6)
	pf_st.content_margin_left = 3
	pf_st.content_margin_right = 3
	pf_st.content_margin_top = 3
	pf_st.content_margin_bottom = 3
	_portrait_frame.add_theme_stylebox_override("panel", pf_st)
	card_hbox.add_child(_portrait_frame)

	_portrait_tex = TextureRect.new()
	_portrait_tex.custom_minimum_size = Vector2(92, 92)
	_portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_portrait_tex)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	card_hbox.add_child(vbox)

	# Top breathing room below raised nameplate + subtle hairline divider
	var top_pad := Control.new()
	top_pad.custom_minimum_size = Vector2(0, 6)
	top_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(top_pad)

	_divider = ColorRect.new()
	_divider.custom_minimum_size = Vector2(0, 1)
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_divider)

	_body = Label.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 20)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_body)

	# Bottom-right tactile [E] Continue chip
	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_END
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bottom_row)

	_hint_wrap = HBoxContainer.new()
	_hint_wrap.add_theme_constant_override("separation", 8)
	_hint_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_child(_hint_wrap)

	_hint_cap = PanelContainer.new()
	_hint_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_wrap.add_child(_hint_cap)

	_hint_key = Label.new()
	_hint_key.text = "E"
	_hint_key.add_theme_font_size_override("font_size", 12)
	_hint_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_cap.add_child(_hint_key)

	_hint_lbl = Label.new()
	_hint_lbl.text = "continue ▸"
	_hint_lbl.add_theme_font_size_override("font_size", 14)
	_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_wrap.add_child(_hint_lbl)

	# Raised Speaker Nameplate overlapping top-left corner of the dialogue card
	_nameplate = PanelContainer.new()
	_nameplate.name = "Nameplate"
	_nameplate.position = Vector2(22, 0)
	_nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_nameplate)

	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 15)
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nameplate.add_child(_speaker)

	_apply_palette(false)

func _apply_palette(kansas: bool) -> void:
	_kansas_cached = kansas
	if _panel:
		_panel.add_theme_stylebox_override("panel", OzThemeFactory.make_modal_style(kansas))
	if _nameplate:
		_nameplate.add_theme_stylebox_override("panel", OzThemeFactory.make_nameplate_style(kansas))
	if _speaker:
		_speaker.add_theme_color_override("font_color", OzThemeFactory.ink_color(kansas))
	if _divider:
		_divider.color = OzThemeFactory.KS_BORDER_SUBTLE if kansas else OzThemeFactory.OZ_BORDER_SUBTLE
	if _body:
		_body.add_theme_color_override("font_color", OzThemeFactory.text_color(kansas))
	if _hint_cap:
		_hint_cap.add_theme_stylebox_override("panel", OzThemeFactory.make_keycap_style(kansas))
	if _hint_key:
		_hint_key.add_theme_color_override("font_color", OzThemeFactory.ink_color(kansas))
	if _hint_lbl:
		_hint_lbl.add_theme_color_override("font_color", OzThemeFactory.muted_text_color(kansas))

func _detect_kansas_mode() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var hud := tree.get_first_node_in_group("hud")
	if hud and "kansas_mode" in hud:
		return bool(hud.get("kansas_mode"))
	return false

func _process(delta: float) -> void:
	if _visible_t > 0.0:
		_visible_t = maxf(_visible_t - delta, 0.0)
	if _box and _box.visible:
		if _typing and _body:
			_type_progress += delta * TYPE_CPS
			var total := _body.get_total_character_count()
			var shown := int(_type_progress)
			if shown >= total:
				_body.visible_characters = -1
				_typing = false
			else:
				_body.visible_characters = shown
		if _hint_lbl and not _is_headless():
			var pulse := 0.72 + 0.28 * sin(Time.get_ticks_msec() * 0.006)
			_hint_wrap.modulate.a = pulse

func _pick_voice() -> void:
	_tts_voice = ""
	if not DisplayServer.has_method("tts_get_voices"):
		return
	var voices = DisplayServer.tts_get_voices()
	if voices == null:
		return
	for v in voices:
		if typeof(v) == TYPE_DICTIONARY:
			var id := str(v.get("id", ""))
			var name := str(v.get("name", "")).to_lower()
			var lang := str(v.get("language", "")).to_lower()
			if lang.begins_with("en") or "english" in name:
				_tts_voice = id
				break
		elif typeof(v) == TYPE_STRING:
			_tts_voice = str(v)
			break
	if _tts_voice == "" and voices is Array and voices.size() > 0:
		var first = voices[0]
		if typeof(first) == TYPE_DICTIONARY:
			_tts_voice = str(first.get("id", ""))
		else:
			_tts_voice = str(first)

func set_tts_enabled(on: bool) -> void:
	tts_enabled = on
	if not on:
		stop_tts()

## Show a dialogue line. speaker e.g. "Locasta", text without speaker prefix preferred.
func say(speaker: String, text: String, also_tts: bool = true, hold: float = 0.0) -> void:
	if _box == null:
		_build()
	var kansas := _detect_kansas_mode()
	if kansas != _kansas_cached:
		_apply_palette(kansas)

	_box.visible = true
	_panel.visible = true
	_speaker.text = speaker.to_upper()
	_nameplate.visible = speaker.strip_edges() != ""
	_update_speaker_portrait(speaker)
	_body.text = text
	_visible_t = hold

	if _is_headless():
		_body.visible_characters = -1
		_typing = false
	else:
		_type_progress = 0.0
		_body.visible_characters = 0
		_typing = true
		_panel.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_panel, "modulate:a", 1.0, 0.16)

	if also_tts and tts_enabled:
		speak_tts("%s. %s" % [speaker, text])

func say_line(full_line: String, also_tts: bool = true) -> void:
	var speaker := "Voice"
	var body := full_line
	var idx := full_line.find(":")
	if idx > 0 and idx < 40:
		speaker = full_line.substr(0, idx).strip_edges()
		body = full_line.substr(idx + 1).strip_edges()
		if body.begins_with("\""):
			body = body.trim_prefix("\"").trim_suffix("\"")
	say(speaker, body, also_tts)

func clear() -> void:
	_hide()
	stop_tts()

func _hide() -> void:
	_typing = false
	if _box:
		_box.visible = false

func speak_tts(text: String) -> void:
	if not tts_enabled or _is_headless():
		return
	if not DisplayServer.has_method("tts_speak"):
		return
	stop_tts()
	if _tts_voice != "":
		DisplayServer.tts_speak(text, _tts_voice, 50, 1.0, 1.0, 0, true)
	else:
		DisplayServer.tts_speak(text, "", 50, 1.0, 1.0, 0, true)

func stop_tts() -> void:
	if DisplayServer.has_method("tts_stop"):
		DisplayServer.tts_stop()

func _update_speaker_portrait(speaker: String) -> void:
	if _portrait_frame == null or _portrait_tex == null:
		return
	var s := speaker.to_lower()
	var key := ""
	if "dorothy" in s:
		key = "dorothy"
	elif "scarecrow" in s:
		key = "scarecrow"
	elif "tin" in s:
		key = "tinman"
	elif "lion" in s:
		key = "lion"
	elif "toto" in s:
		key = "toto"
	elif "em" in s or "aunt" in s:
		key = "aunt_em"
	elif "henry" in s or "uncle" in s:
		key = "uncle_henry"
	elif "locasta" in s or "north" in s:
		key = "locasta"
	elif "glinda" in s or "south" in s:
		key = "glinda"
	elif "wizard" in s or "oscar" in s or "oz" in s:
		key = "wizard"
	elif "witch" in s or "west" in s:
		key = "wicked_witch"
	if key == "":
		_portrait_frame.visible = false
		return
	var tex: Texture2D = _portrait_cache.get(key, null)
	if tex == null:
		var path := "res://assets/art/portraits/%s.png" % key
		if ResourceLoader.exists(path):
			tex = ResourceLoader.load(path) as Texture2D
		else:
			var abs_p := ProjectSettings.globalize_path(path)
			if FileAccess.file_exists(abs_p):
				var img := Image.load_from_file(abs_p)
				if img != null and not img.is_empty():
					tex = ImageTexture.create_from_image(img)
		if tex != null:
			_portrait_cache[key] = tex
	_portrait_tex.texture = tex
	_portrait_frame.visible = (tex != null)

func _is_headless() -> bool:
	var n := DisplayServer.get_name()
	return n == "headless" or n == "Dummy"
