extends Node

## On-screen dialogue + optional OS TTS (when the platform has voices).
## AI voice pipeline (ElevenLabs / local XTTS / Godot AudioStreamPlayer clips) can plug into speak() later.

var _box: Control
var _speaker: Label
var _body: Label
var _hint: Label
var _panel: ColorRect
var _visible_t: float = 0.0
var _tts_voice: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer_hint()
	_build()
	_hide()
	_pick_voice()

func layer_hint() -> void:
	# Autoload is a Node; if we become CanvasLayer children of root, keep simple.
	pass

func _build() -> void:
	# Attach under a CanvasLayer so it draws above 3D.
	var layer := CanvasLayer.new()
	layer.name = "DialogueLayer"
	layer.layer = 80
	add_child(layer)
	_box = Control.new()
	_box.name = "DialogueRoot"
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_box)
	_panel = ColorRect.new()
	_panel.name = "Panel"
	_panel.color = Color(0.06, 0.04, 0.1, 0.88)
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -168.0
	_panel.offset_bottom = -16.0
	_panel.offset_left = 48.0
	_panel.offset_right = -48.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_panel)
	var border := ColorRect.new()
	border.color = Color(0.85, 0.72, 0.35, 0.55)
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.offset_top = 0.0
	border.offset_bottom = 3.0
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(border)
	_speaker = Label.new()
	_speaker.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_speaker.offset_left = 20.0
	_speaker.offset_right = -20.0
	_speaker.offset_top = 10.0
	_speaker.offset_bottom = 42.0
	_speaker.add_theme_font_size_override("font_size", 20)
	_speaker.add_theme_color_override("font_color", Color(0.95, 0.82, 0.4))
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_speaker)
	_body = Label.new()
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.offset_left = 20.0
	_body.offset_right = -20.0
	_body.offset_top = 44.0
	_body.offset_bottom = -28.0
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 22)
	_body.add_theme_color_override("font_color", Color(0.96, 0.94, 0.9))
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_body)
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_left = 20.0
	_hint.offset_right = -20.0
	_hint.offset_top = -26.0
	_hint.offset_bottom = -6.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62))
	_hint.text = "E — continue"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_hint)

func _process(delta: float) -> void:
	if _visible_t > 0.0:
		_visible_t = maxf(_visible_t - delta, 0.0)

func _pick_voice() -> void:
	_tts_voice = ""
	if not DisplayServer.has_method("tts_get_voices"):
		return
	var voices = DisplayServer.tts_get_voices()
	if voices == null:
		return
	# Prefer English voices.
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

## Show a dialogue line. speaker e.g. "Locasta", text without speaker prefix preferred.
func say(speaker: String, text: String, also_tts: bool = true, hold: float = 0.0) -> void:
	if _box == null:
		_build()
	_box.visible = true
	_panel.visible = true
	_speaker.text = speaker.to_upper()
	_body.text = text
	_visible_t = hold
	if also_tts:
		speak_tts("%s. %s" % [speaker, text])

func say_line(full_line: String, also_tts: bool = true) -> void:
	## Parse "Name: \"quote\"" or "Name: quote"
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
	if _box:
		_box.visible = false

func speak_tts(text: String) -> void:
	if _is_headless():
		return
	if not DisplayServer.has_method("tts_speak"):
		return
	stop_tts()
	# Godot 4 TTS: tts_speak(text, voice_id, volume, pitch, rate, utterance_id, interrupt)
	if _tts_voice != "":
		DisplayServer.tts_speak(text, _tts_voice, 50, 1.0, 1.0, 0, true)
	else:
		# Some builds accept empty voice id as default.
		DisplayServer.tts_speak(text, "", 50, 1.0, 1.0, 0, true)

func stop_tts() -> void:
	if DisplayServer.has_method("tts_stop"):
		DisplayServer.tts_stop()

func _is_headless() -> bool:
	var n := DisplayServer.get_name()
	return n == "headless" or n == "Dummy"
