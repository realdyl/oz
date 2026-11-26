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
var _should_show: bool = false

const TYPE_CPS := 75.0
const OzThemeFactory := preload("res://ui/theme/oz_theme_factory.gd")
const OrnateFrame := preload("res://ui/widgets/ornate_frame.gd")
const CircleShader := preload("res://ui/shaders/circle_medallion.gdshader")
const WorldKit := preload("res://systems/world_kit.gd")
var _ornate_frame: Control = null
var _portrait_mat: ShaderMaterial = null
var _bar_top: ColorRect = null
var _bar_bot: ColorRect = null

# Real-Time Phoneme/Viseme Lip-Sync & ElevenLabs Voice-Clone Ready Audio Engine!
var _voice_player: AudioStreamPlayer = null
var _lip_speaker_node: Node3D = null
var _lip_text: String = ""
var _lip_elapsed: float = 0.0
var _lip_duration: float = 0.0
var _lip_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "ElevenLabsVoicePlayer"
	add_child(_voice_player)
	_build()
	_hide()
	_pick_voice()

func _build() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DialogueLayer"
	# Strictly tucked below Grimoire (28), Boutique (30), and Pause Menu (100), above PlayHUD (10)
	layer.layer = 18
	add_child(layer)

	_box = Control.new()
	_box.name = "DialogueRoot"
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_box)

	# Sleek Spyro-style Cinema Letterbox Bars (tween in during interactive NPC dialogue scenes!)
	_bar_top = ColorRect.new()
	_bar_top.color = Color(0.03, 0.015, 0.045, 0.94)
	_bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar_top.offset_top = 0.0
	_bar_top.offset_bottom = 0.0
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_bar_top)

	_bar_bot = ColorRect.new()
	_bar_bot.color = Color(0.03, 0.015, 0.045, 0.94)
	_bar_bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_bot.offset_top = 0.0
	_bar_bot.offset_bottom = 0.0
	_bar_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_bar_bot)

	# Center container at bottom so card has refined modern margins on 720p and 1080p+
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	anchor.offset_left = 104.0
	anchor.offset_right = -104.0
	anchor.offset_top = -204.0
	anchor.offset_bottom = -22.0
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(anchor)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_top = 18.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_panel)

	_ornate_frame = OrnateFrame.new()
	_ornate_frame.outer_pad = 9.0
	_ornate_frame.inset = 5.0
	_ornate_frame.corner_size = 13.0
	_ornate_frame.animated_sheen = true
	_panel.add_child(_ornate_frame)

	var card_hbox := HBoxContainer.new()
	card_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_hbox.add_theme_constant_override("separation", 20)
	_panel.add_child(card_hbox)

	# Gilded Circular Speaker Portrait Medallion (strict 1:1 square so golden circle NEVER crops!)
	_portrait_frame = PanelContainer.new()
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait_frame.visible = false
	var pf_st := StyleBoxFlat.new()
	pf_st.bg_color = Color(0.06, 0.03, 0.08, 0.0)
	pf_st.set_border_width_all(0)
	pf_st.set_content_margin_all(4)
	_portrait_frame.add_theme_stylebox_override("panel", pf_st)
	card_hbox.add_child(_portrait_frame)

	_portrait_tex = TextureRect.new()
	_portrait_tex.custom_minimum_size = Vector2(96, 96)
	_portrait_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_portrait_tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _is_headless():
		_portrait_mat = ShaderMaterial.new()
		_portrait_mat.shader = CircleShader
		_portrait_mat.set_shader_parameter("is_active", 1.0)
		_portrait_tex.material = _portrait_mat
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
	_nameplate.position = Vector2(38, 0)
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
		var dlg_sb := OzThemeFactory.make_modal_style(kansas)
		dlg_sb.content_margin_left = 44
		dlg_sb.content_margin_right = 44
		dlg_sb.content_margin_top = 28
		dlg_sb.content_margin_bottom = 24
		_panel.add_theme_stylebox_override("panel", dlg_sb)
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
	if _ornate_frame:
		_ornate_frame.set("kansas_mode", kansas)
		_ornate_frame.queue_redraw()
	if _portrait_mat:
		_portrait_mat.set_shader_parameter("greyscale", 1.0 if kansas else 0.0)

func _detect_kansas_mode() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var hud := tree.get_first_node_in_group("hud")
	if hud and "kansas_mode" in hud:
		return bool(hud.get("kansas_mode"))
	return false

func _is_menu_or_title_blocking() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	if tree.paused:
		return true
	if tree.current_scene and "title_screen" in tree.current_scene.scene_file_path.to_lower():
		return true
	var hud := tree.get_first_node_in_group("hud")
	if hud:
		for prop in ["shop_menu", "grimoire_menu", "pause_menu"]:
			var m = hud.get(prop)
			if m is CanvasLayer and is_instance_valid(m) and (m as CanvasLayer).visible:
				return true
	return false

func _process(delta: float) -> void:
	# Strictly hide dialogue whenever on Title Screen or while Pause / Settings / Shop / Grimoire is open!
	if _box:
		var blocked := _is_menu_or_title_blocking()
		if blocked and get_tree() != null and get_tree().current_scene and "title_screen" in get_tree().current_scene.scene_file_path.to_lower():
			_should_show = false
		_box.visible = _should_show and not blocked
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
	_tick_viseme_lip_sync(delta)

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

	_should_show = true
	_box.visible = not (get_tree() != null and get_tree().paused)
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
		_start_voice_and_lipsync(speaker, text)
	else:
		_start_lipsync_only(speaker, text)

func _resolve_speaker_3d(speaker: String) -> Node3D:
	var party := get_node_or_null("/root/Party")
	var s := speaker.to_lower()
	if party:
		if "dorothy" in s:
			var db = party.call("member_body", &"dorothy") if party.has_method("member_body") else null
			if db is Node3D: return db as Node3D
		elif "scarecrow" in s:
			var sb = party.call("member_body", &"scarecrow") if party.has_method("member_body") else null
			if sb is Node3D: return sb as Node3D
		elif "tin" in s:
			var tb = party.call("member_body", &"tinman") if party.has_method("member_body") else null
			if tb is Node3D: return tb as Node3D
		elif "lion" in s:
			var lb = party.call("member_body", &"lion") if party.has_method("member_body") else null
			if lb is Node3D: return lb as Node3D
	var scene := get_tree().current_scene if get_tree() else null
	if scene:
		if "dorothy" in s:
			var pl := scene.find_child("Player", true, false) as Node3D
			if pl: return pl
		for pair in [
			["locasta", "Locasta"], ["glinda", "Glinda"], ["em", "AuntEm"], ["em", "Aunt Em"],
			["henry", "UncleHenry"], ["henry", "Uncle Henry"], ["wizard", "WizardBody"],
			["oz", "WizardProjection"], ["witch", "WitchOfTheWest"],
			["scarecrow", "Scarecrow"], ["tin", "TinMan"], ["lion", "Lion"],
		]:
			if str(pair[0]) in s:
				var found := scene.find_child(str(pair[1]), true, false) as Node3D
				if found:
					return found
	if party and "active_dialogue_speaker" in party and party.active_dialogue_speaker is Node3D:
		return party.active_dialogue_speaker as Node3D
	return null

func _reset_current_speaker_mouth() -> void:
	if _lip_speaker_node and is_instance_valid(_lip_speaker_node):
		WorldKit.apply_viseme_to_actor(_lip_speaker_node, 0, 0.0)
	_lip_active = false

## ElevenLabs Voice-Clone Hook (`res://assets/audio/voices/<char>/<hash>.mp3|.ogg|.wav`) + OS TTS + Real-Time Viseme Lip-Sync!
func _start_voice_and_lipsync(speaker: String, text: String) -> void:
	_reset_current_speaker_mouth()
	_lip_speaker_node = _resolve_speaker_3d(speaker)
	_lip_text = text.strip_edges()
	_lip_elapsed = 0.0
	var word_cnt := maxi(2, _lip_text.split(" ", false).size())
	_lip_duration = clampf(float(word_cnt) / 2.75, 0.85, 9.5)
	_lip_active = (_lip_speaker_node != null and not _is_headless())

	# 1) Try pre-rendered ElevenLabs voice clone file first (`res://assets/audio/voices/<speaker_key>/<hash>.ogg|.mp3`)
	var char_slug := speaker.to_lower().replace(" ", "_")
	var line_hash := str(absi(_lip_text.hash()))
	for ext in ["ogg", "mp3", "wav"]:
		var vpath := "res://assets/audio/voices/%s/%s.%s" % [char_slug, line_hash, ext]
		if ResourceLoader.exists(vpath) and _voice_player:
			var stream := ResourceLoader.load(vpath) as AudioStream
			if stream:
				stop_tts()
				_voice_player.stream = stream
				_voice_player.play()
				if stream.get_length() > 0.1:
					_lip_duration = stream.get_length()
				return
	# 2) Fallback to live OS TTS (speak ONLY the clean dialogue text — not the speaker prefix — so mouth timing matches!)
	speak_tts(text)

func _start_lipsync_only(speaker: String, text: String) -> void:
	_reset_current_speaker_mouth()
	_lip_speaker_node = _resolve_speaker_3d(speaker)
	_lip_text = text.strip_edges()
	_lip_elapsed = 0.0
	var word_cnt := maxi(2, _lip_text.split(" ", false).size())
	_lip_duration = clampf(float(word_cnt) / 2.9, 0.8, 8.0)
	_lip_active = (_lip_speaker_node != null and not _is_headless())

func _tick_viseme_lip_sync(delta: float) -> void:
	if not _lip_active or _lip_speaker_node == null or not is_instance_valid(_lip_speaker_node):
		return
	_lip_elapsed += delta
	var tts_still_going := false
	if DisplayServer.has_method("tts_is_speaking") and tts_enabled:
		tts_still_going = DisplayServer.tts_is_speaking()
	var voice_clip_going := (_voice_player != null and _voice_player.playing)
	var within_est := (_lip_elapsed < _lip_duration)
	if not voice_clip_going and not tts_still_going and not within_est:
		_reset_current_speaker_mouth()
		return
	# If OS TTS finished early (after min 0.45s startup window), close mouth cleanly right on time!
	if _lip_elapsed > 0.45 and tts_enabled and DisplayServer.has_method("tts_is_speaking") and not tts_still_going and not voice_clip_going:
		if _lip_elapsed > _lip_duration * 0.72:
			_reset_current_speaker_mouth()
			return

	var total_chars := maxi(1, _lip_text.length())
	var u := clampf(_lip_elapsed / maxf(0.4, _lip_duration), 0.0, 0.999)
	var idx := clampi(int(u * float(total_chars)), 0, total_chars - 1)
	var ch := _lip_text.substr(idx, 1).to_lower()
	var next_ch := _lip_text.substr(mini(idx + 1, total_chars - 1), 1).to_lower()

	# Map live English characters/digraphs to human visemes (0=Closed, 1=AH, 2=OO, 3=EE, 4=MID)
	var viseme := 4
	var env := 0.45 + 0.55 * absf(sin(_lip_elapsed * 13.5))
	if ch in [" ", ",", ".", "—", "-", ";", ":", "!", "?"]:
		viseme = 0
		env = 0.0
	elif ch in ["m", "b", "p", "f", "v"]:
		viseme = 0
		env = 0.06
	elif (ch == "o" and next_ch == "o") or ch in ["o", "u", "w", "q"]:
		viseme = 2 # Rounded "OO" / "OH"
		env = clampf(env * 1.15, 0.35, 1.0)
	elif ch in ["a"]:
		viseme = 1 # Wide open "AH"
		env = clampf(env * 1.22, 0.42, 1.0)
	elif ch in ["e", "i", "y", "s", "z"]:
		viseme = 3 # Wide smile "EE" / "IH"
		env = clampf(env * 0.95, 0.30, 0.92)
	else:
		viseme = 4
		env = clampf(env * 0.82, 0.22, 0.80)
	WorldKit.apply_viseme_to_actor(_lip_speaker_node, viseme, env)

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

func set_cinema_letterbox(on: bool) -> void:
	if _bar_top == null or _bar_bot == null or _is_headless():
		return
	var target_h := 44.0 if on else 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_bar_top, "offset_bottom", target_h, 0.28)
	tw.tween_property(_bar_bot, "offset_top", -target_h, 0.28)

func clear() -> void:
	_reset_current_speaker_mouth()
	if _voice_player and _voice_player.playing:
		_voice_player.stop()
	_hide()
	stop_tts()
	set_cinema_letterbox(false)

func _hide() -> void:
	_should_show = false
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
	elif "china" in s or "princess" in s:
		key = "china_princess"
	elif "mouse" in s or "queen" in s:
		key = "mouse_queen"
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
