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
		var t := stream_phase

		# 1. Arcane 2026 Celestial Halo + Counter-Rotating Astrolabe Rune Ring
		var pulse := 0.85 + 0.15 * sin(t * 3.8)
		draw_circle(Vector2(cx, cy), 118.0, Color(0.28, 0.88, 0.62, 0.05 * pulse))
		draw_circle(Vector2(cx, cy), 92.0, Color(0.92, 0.74, 0.34, 0.10 * pulse))
		draw_circle(Vector2(cx, cy), 64.0, Color(0.98, 0.84, 0.45, 0.14 * pulse))
		draw_arc(Vector2(cx, cy), 112.0, 0.0, TAU, 64, Color(0.92, 0.76, 0.36, 0.42), 1.6, true)
		draw_arc(Vector2(cx, cy), 102.0, 0.0, TAU, 48, Color(0.45, 0.96, 0.72, 0.28), 1.1, true)
		for ri in range(12):
			var ra := float(ri) / 12.0 * TAU - t * 1.1
			var rp := Vector2(cx + cos(ra) * 112.0, cy + sin(ra) * 112.0)
			var is_card := (ri % 3 == 0)
			draw_circle(rp, 4.2 if is_card else 2.2, Color(1.0, 0.90, 0.54, 0.92) if is_card else Color(0.48, 0.98, 0.76, 0.75))

		# 2. Enchanted Crystal Amphora Bulbs (Emerald-Violet Refractive Glass + Crystalline Rim)
		var glass_fill := Color(0.32, 0.76, 0.86, 0.22)
		var glass_inner := Color(0.68, 0.46, 0.92, 0.14)
		var glass_edge := Color(0.92, 0.98, 1.0, 0.68)

		var upper_bulb := PackedVector2Array([
			Vector2(cx - 52, cy - 94),
			Vector2(cx + 52, cy - 94),
			Vector2(cx + 50, cy - 62),
			Vector2(cx + 34, cy - 30),
			Vector2(cx + 8, cy - 6),
			Vector2(cx - 8, cy - 6),
			Vector2(cx - 34, cy - 30),
			Vector2(cx - 50, cy - 62),
		])
		draw_colored_polygon(upper_bulb, glass_fill)
		draw_colored_polygon(upper_bulb, glass_inner)
		draw_polyline(upper_bulb + PackedVector2Array([upper_bulb[0]]), glass_edge, 1.8, true)

		var lower_bulb := PackedVector2Array([
			Vector2(cx - 8, cy + 6),
			Vector2(cx + 8, cy + 6),
			Vector2(cx + 34, cy + 30),
			Vector2(cx + 50, cy + 62),
			Vector2(cx + 52, cy + 94),
			Vector2(cx - 52, cy + 94),
			Vector2(cx - 50, cy + 62),
			Vector2(cx - 34, cy + 30),
		])
		draw_colored_polygon(lower_bulb, glass_fill)
		draw_colored_polygon(lower_bulb, glass_inner)
		draw_polyline(lower_bulb + PackedVector2Array([lower_bulb[0]]), glass_edge, 1.8, true)

		# Dual Specular Crystal Sheen Arcs
		draw_line(Vector2(cx - 38, cy - 84), Vector2(cx - 17, cy - 26), Color(1, 1, 1, 0.48), 2.4, true)
		draw_line(Vector2(cx + 32, cy - 78), Vector2(cx + 18, cy - 34), Color(0.55, 1.0, 0.85, 0.30), 1.5, true)
		draw_line(Vector2(cx - 17, cy + 26), Vector2(cx - 38, cy + 82), Color(1, 1, 1, 0.36), 2.2, true)

		# 3. Luminous Liquid-Gold Starlight Sand + 24 Animated Sparkling Falling Grains + Waist Vortex!
		var sand_col := Color(0.96, 0.76, 0.28, 0.94)
		var sand_hi := Color(1.0, 0.94, 0.66, 0.98)
		var upper_sand := PackedVector2Array([
			Vector2(cx - 34, cy - 56),
			Vector2(cx + 34, cy - 56),
			Vector2(cx + 5, cy - 9),
			Vector2(cx - 5, cy - 9),
		])
		draw_colored_polygon(upper_sand, sand_col)
		draw_line(Vector2(cx - 34, cy - 56), Vector2(cx + 34, cy - 56), sand_hi, 2.0, true)

		# Glowing waist vortex + shimmering golden sand stream
		draw_circle(Vector2(cx, cy), 8.5 * pulse, Color(1.0, 0.92, 0.56, 0.42))
		var stream_w := 2.6 + 0.8 * sin(t * 10.0)
		draw_line(Vector2(cx, cy - 8), Vector2(cx, cy + 88), sand_hi, stream_w, true)
		for gi in range(24):
			var frac := fmod(t * 1.45 + float(gi) / 24.0, 1.0)
			var py := lerpf(cy - 6.0, cy + 86.0, frac)
			var px := cx + sin(frac * 14.0 + float(gi) * 1.7) * (2.5 + frac * 7.5)
			var spark_a := sin(frac * PI)
			draw_circle(Vector2(px, py), 1.4 + 1.2 * spark_a, Color(1.0, 0.94, 0.62, spark_a))

		var lower_sand := PackedVector2Array([
			Vector2(cx, cy + 48),
			Vector2(cx + 42, cy + 92),
			Vector2(cx - 42, cy + 92),
		])
		draw_colored_polygon(lower_sand, sand_col)
		draw_line(Vector2(cx, cy + 48), Vector2(cx + 42, cy + 92), sand_hi, 1.6, true)

		# 4. Ornate Filigree Antique-Brass Frame, Spiral Pillars & Emerald-Capped Finials
		var brass := Color(0.84, 0.66, 0.30, 1.0)
		var brass_dark := Color(0.38, 0.25, 0.10, 1.0)
		var brass_hi := Color(1.0, 0.90, 0.54, 0.98)
		var em_gem := Color(0.32, 0.96, 0.62, 0.98)

		for sx in [-64.0, 64.0]:
			var px: float = cx + float(sx)
			draw_line(Vector2(px, cy - 108), Vector2(px, cy + 108), brass_dark, 7.5, true)
			draw_line(Vector2(px, cy - 108), Vector2(px, cy + 108), brass, 3.8, true)
			draw_line(Vector2(px - 1.2, cy - 104), Vector2(px - 1.2, cy + 104), brass_hi, 1.2, true)
			draw_circle(Vector2(px, cy - 114), 5.5, brass_hi)
			draw_circle(Vector2(px, cy - 114), 2.6, em_gem)
			draw_circle(Vector2(px, cy + 114), 5.5, brass_hi)
			draw_circle(Vector2(px, cy + 114), 2.6, em_gem)

		# Stepped Beveled Brass Caps + Center Emerald Medallions
		for cap_y in [-112.0, 98.0]:
			draw_rect(Rect2(cx - 76, cy + cap_y, 152, 15), brass_dark, true)
			draw_rect(Rect2(cx - 72, cy + cap_y + 3, 144, 9), brass, true)
			draw_line(Vector2(cx - 68, cy + cap_y + 5), Vector2(cx + 68, cy + cap_y + 5), brass_hi, 1.5, true)
			draw_circle(Vector2(cx, cy + cap_y + 7.5), 5.0, brass_hi)
			draw_circle(Vector2(cx, cy + cap_y + 7.5), 2.8, em_gem)

		# Sculpted Waist Ring + Emerald Star Jewel
		draw_rect(Rect2(cx - 18, cy - 5, 36, 10), brass_dark, true)
		draw_line(Vector2(cx - 16, cy), Vector2(cx + 16, cy), brass_hi, 2.4, true)
		draw_circle(Vector2(cx, cy), 3.4, em_gem)

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
	elif "kalidah" in lt or "wilds" in lt or "chasm" in lt:
		res_path = "res://assets/art/scenes/kalidah_wilds.jpg"
	elif "poppy" in lt or "meadow" in lt:
		res_path = "res://assets/art/scenes/poppy_field.jpg"
	elif "winkie" in lt or "west" in lt or "castle" in lt or "witch" in lt:
		res_path = "res://assets/art/scenes/winkie_castle.jpg"
	elif "emerald" in lt or "wizard" in lt or "palace" in lt:
		res_path = "res://assets/art/scenes/emerald_city.jpg"
	elif "china" in lt or "porcelain" in lt or "spider" in lt or "fighting" in lt:
		res_path = "res://assets/art/scenes/china_country.jpg"
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
