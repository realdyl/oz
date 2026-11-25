extends CanvasLayer

## Storybook hourglass transition between levels — enter and exit only.
## Original prop read (time / road turning) with refined vector brass/glass art
## and a storybook chapter title plaque.

const DEFAULT_HOLD := 2.15
const EXIT_HOLD := 2.0
const OzThemeFactory := preload("res://ui/theme/oz_theme_factory.gd")

class HourglassCanvas extends Control:
	var stream_phase: float = 0.0

	func _draw() -> void:
		var cx := size.x * 0.5
		var cy := size.y * 0.5

		# Soft ambient gold aura behind the hourglass
		draw_circle(Vector2(cx, cy), 86.0, Color(0.84, 0.69, 0.36, 0.08))
		draw_circle(Vector2(cx, cy), 58.0, Color(0.95, 0.80, 0.42, 0.11))

		# Glass bulbs (upper and lower silhouettes + subtle glass sheen)
		var glass_fill := Color(0.62, 0.84, 0.96, 0.24)
		var glass_edge := Color(0.85, 0.94, 1.0, 0.52)

		var upper_bulb := PackedVector2Array([
			Vector2(cx - 50, cy - 96),
			Vector2(cx + 50, cy - 96),
			Vector2(cx + 46, cy - 58),
			Vector2(cx + 8, cy - 6),
			Vector2(cx - 8, cy - 6),
			Vector2(cx - 46, cy - 58),
		])
		draw_colored_polygon(upper_bulb, glass_fill)
		draw_polyline(upper_bulb + PackedVector2Array([upper_bulb[0]]), glass_edge, 1.6, true)

		var lower_bulb := PackedVector2Array([
			Vector2(cx - 8, cy + 6),
			Vector2(cx + 8, cy + 6),
			Vector2(cx + 46, cy + 58),
			Vector2(cx + 50, cy + 96),
			Vector2(cx - 50, cy + 96),
			Vector2(cx - 46, cy + 58),
		])
		draw_colored_polygon(lower_bulb, glass_fill)
		draw_polyline(lower_bulb + PackedVector2Array([lower_bulb[0]]), glass_edge, 1.6, true)

		# Glass specular highlight arcs
		draw_line(Vector2(cx - 38, cy - 86), Vector2(cx - 18, cy - 28), Color(1, 1, 1, 0.32), 2.0, true)
		draw_line(Vector2(cx - 18, cy + 28), Vector2(cx - 38, cy + 84), Color(1, 1, 1, 0.22), 2.0, true)

		# Warm gold sand — upper mound + animated falling stream + lower cone
		var sand_col := Color(0.94, 0.74, 0.30, 0.92)
		var sand_hi := Color(1.0, 0.88, 0.52, 0.95)
		var upper_sand := PackedVector2Array([
			Vector2(cx - 30, cy - 58),
			Vector2(cx + 30, cy - 58),
			Vector2(cx + 5, cy - 10),
			Vector2(cx - 5, cy - 10),
		])
		draw_colored_polygon(upper_sand, sand_col)

		# Falling sand stream
		var stream_w := 2.2 + 0.6 * sin(stream_phase * 8.0)
		draw_line(Vector2(cx, cy - 8), Vector2(cx, cy + 88), sand_hi, stream_w, true)

		# Lower sand pyramid
		var lower_sand := PackedVector2Array([
			Vector2(cx, cy + 52),
			Vector2(cx + 38, cy + 92),
			Vector2(cx - 38, cy + 92),
		])
		draw_colored_polygon(lower_sand, sand_col)
		draw_line(Vector2(cx, cy + 52), Vector2(cx + 38, cy + 92), sand_hi, 1.2, true)

		# Brass frame pillars with finials
		var brass := Color(0.76, 0.60, 0.28, 1.0)
		var brass_dark := Color(0.42, 0.30, 0.14, 1.0)
		var brass_hi := Color(0.98, 0.84, 0.45, 0.95)

		for sx in [-62.0, 62.0]:
			var px: float = cx + float(sx)
			draw_line(Vector2(px, cy - 106), Vector2(px, cy + 106), brass_dark, 6.0, true)
			draw_line(Vector2(px, cy - 106), Vector2(px, cy + 106), brass, 3.2, true)
			draw_circle(Vector2(px, cy - 110), 4.5, brass_hi)
			draw_circle(Vector2(px, cy + 110), 4.5, brass_hi)

		# Ornate top and bottom brass caps + waist collar
		draw_rect(Rect2(cx - 72, cy - 112, 144, 14), brass_dark, true)
		draw_rect(Rect2(cx - 68, cy - 109, 136, 8), brass, true)
		draw_line(Vector2(cx - 64, cy - 107), Vector2(cx + 64, cy - 107), brass_hi, 1.2, true)

		draw_rect(Rect2(cx - 72, cy + 98, 144, 14), brass_dark, true)
		draw_rect(Rect2(cx - 68, cy + 101, 136, 8), brass, true)
		draw_line(Vector2(cx - 64, cy + 103), Vector2(cx + 64, cy + 103), brass_hi, 1.2, true)

		# Waist ring
		draw_rect(Rect2(cx - 16, cy - 4, 32, 8), brass_dark, true)
		draw_line(Vector2(cx - 14, cy), Vector2(cx + 14, cy), brass_hi, 2.0, true)

var _root: Control
var _backdrop: TextureRect
var _veil: ColorRect
var _glass: HourglassCanvas
var _card: PanelContainer
var _subtitle: Label
var _title: Label
var _busy: bool = false
var _pending_enter: String = ""
var _spin_deg: float = 0.0
var _active: bool = false

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	_build_ui()
	_hide_now()

func _process(delta: float) -> void:
	if not _active or _glass == null:
		return
	_spin_deg = fmod(_spin_deg + delta * 120.0, 360.0)
	_glass.rotation_degrees = _spin_deg
	_glass.stream_phase += delta
	_glass.queue_redraw()
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.035
	_glass.scale = Vector2.ONE * pulse

func _is_headless() -> bool:
	var n := DisplayServer.get_name()
	return n == "headless" or n == "Dummy"

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "HourglassRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Phase P1.2: Full-bleed 16:9 painted Act Backdrop behind the translucent veil
	_backdrop = TextureRect.new()
	_backdrop.name = "SceneBackdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.modulate = Color(1, 1, 1, 0)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_backdrop)

	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0.05, 0.03, 0.07, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_veil)

	_glass = HourglassCanvas.new()
	_glass.name = "Hourglass"
	_glass.custom_minimum_size = Vector2(220, 260)
	_glass.size = Vector2(220, 260)
	_glass.set_anchors_preset(Control.PRESET_CENTER)
	_glass.offset_left = -110.0
	_glass.offset_top = -170.0
	_glass.offset_right = 110.0
	_glass.offset_bottom = 90.0
	_glass.pivot_offset = Vector2(110, 130)
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_glass)

	# Storybook Chapter Title Plaque
	var card_center := CenterContainer.new()
	card_center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	card_center.offset_top = -165.0
	card_center.offset_bottom = -36.0
	card_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(card_center)

	_card = PanelContainer.new()
	_card.name = "ChapterCard"
	_card.custom_minimum_size = Vector2(460, 0)
	_card.add_theme_stylebox_override("panel", OzThemeFactory.make_panel_style(false, false))
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_center.add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(vbox)

	_subtitle = Label.new()
	_subtitle.text = "OZ: THE ROAD HOME"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 11)
	_subtitle.add_theme_color_override("font_color", OzThemeFactory.OZ_GOLD_BRIGHT)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_subtitle)

	var top_rule := ColorRect.new()
	top_rule.custom_minimum_size = Vector2(0, 1)
	top_rule.color = OzThemeFactory.OZ_BORDER_SUBTLE
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(top_rule)

	_title = Label.new()
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", OzThemeFactory.OZ_TEXT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title)

func _hide_now() -> void:
	_active = false
	_spin_deg = 0.0
	if _root:
		_root.visible = false
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _backdrop:
		_backdrop.modulate.a = 0.0
	if _veil:
		_veil.color.a = 0.0
	if _glass:
		_glass.modulate.a = 0.0
		_glass.rotation_degrees = 0.0
		_glass.scale = Vector2.ONE
	if _card:
		_card.modulate.a = 0.0
	if _title:
		_title.text = ""

## Call from a level's _ready — plays enter sting if a transition just landed, else a short open.
func on_level_start(level_title: String = "") -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("set_current_location"):
		var cur := get_tree().current_scene
		sm.set_current_location(cur.scene_file_path if cur else "", level_title)
	if _is_headless():
		_pending_enter = ""
		_busy = false
		return
	var msg := _pending_enter
	_pending_enter = ""
	if msg == "":
		msg = level_title if level_title != "" else "The road begins…"
	else:
		if level_title != "":
			msg = level_title
	await play_enter(msg)

func play_enter(title: String = "The road begins…", hold: float = DEFAULT_HOLD) -> void:
	await _run(title, hold)

func play_exit(title: String = "The hourglass turns…", hold: float = EXIT_HOLD) -> void:
	await _run(title, hold)

## Exit sting, then change scene; next level calls on_level_start for enter sting.
func go_to(scene_path: String, exit_title: String = "The hourglass turns…", enter_title: String = "") -> void:
	if _is_headless():
		get_tree().change_scene_to_file(scene_path)
		return
	if _busy:
		_pending_enter = enter_title
		get_tree().change_scene_to_file(scene_path)
		return
	_busy = true
	_pending_enter = enter_title if enter_title != "" else "A new country…"
	await play_exit(exit_title, EXIT_HOLD)
	get_tree().change_scene_to_file(scene_path)
	_busy = false

func _pick_backdrop_for(title: String) -> Texture2D:
	var lt := title.to_lower()
	var res_path := "res://assets/art/scenes/title_hero_oz.jpg"
	if "homecoming" in lt or "home" in lt or "porch" in lt:
		res_path = "res://assets/art/scenes/kansas_homecoming.jpg"
	elif "cyclone" in lt or "storm" in lt or "twister" in lt:
		res_path = "res://assets/art/scenes/title_kansas_cyclone.jpg"
	elif "kansas" in lt or "farm" in lt or "prairie" in lt:
		res_path = "res://assets/art/scenes/kansas_calm.jpg"
	elif "munchkin" in lt or "landing" in lt:
		res_path = "res://assets/art/scenes/munchkinland.jpg"
	elif "poppy" in lt or "meadow" in lt:
		res_path = "res://assets/art/scenes/poppy_field.jpg"
	elif "winkie" in lt or "west" in lt or "castle" in lt or "witch" in lt:
		res_path = "res://assets/art/scenes/winkie_castle.jpg"
	elif "emerald" in lt or "wizard" in lt or "palace" in lt:
		res_path = "res://assets/art/scenes/emerald_city.jpg"
	elif "glinda" in lt or "quadling" in lt or "south" in lt or "court" in lt:
		res_path = "res://assets/art/scenes/glinda_court.jpg"
	if ResourceLoader.exists(res_path):
		var tex := ResourceLoader.load(res_path) as Texture2D
		if tex != null:
			return tex
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

func _run(title: String, hold: float) -> void:
	if _is_headless():
		return
	if _root == null:
		_build_ui()
	_active = true
	_root.visible = true
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.text = title
	_glass.rotation_degrees = 0.0
	_spin_deg = 0.0
	if _backdrop:
		_backdrop.texture = _pick_backdrop_for(title)
		_backdrop.modulate.a = 0.0
	_veil.color = Color(0.05, 0.03, 0.07, 0.0)
	_glass.modulate.a = 0.0
	_card.modulate.a = 0.0

	var has_art := _backdrop != null and _backdrop.texture != null
	var tw := create_tween()
	tw.set_parallel(true)
	if has_art:
		tw.tween_property(_backdrop, "modulate:a", 1.0, 0.35)
	tw.tween_property(_veil, "color:a", 0.56 if has_art else 0.90, 0.35)
	tw.tween_property(_glass, "modulate:a", 1.0, 0.4)
	tw.tween_property(_card, "modulate:a", 1.0, 0.45)
	await tw.finished
	await get_tree().create_timer(hold).timeout
	var tw2 := create_tween()
	tw2.set_parallel(true)
	if has_art:
		tw2.tween_property(_backdrop, "modulate:a", 0.0, 0.4)
	tw2.tween_property(_veil, "color:a", 0.0, 0.4)
	tw2.tween_property(_glass, "modulate:a", 0.0, 0.35)
	tw2.tween_property(_card, "modulate:a", 0.0, 0.3)
	await tw2.finished
	_hide_now()
