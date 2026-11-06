extends CanvasLayer

## Brief spinning hourglass between levels — enter and exit only, never stays up.
## Original prop read (time / road turning). Not a film-trade-dress recreation.

const DEFAULT_HOLD := 2.15
const EXIT_HOLD := 2.0

var _root: Control
var _veil: ColorRect
var _glass: Control
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
	_spin_deg = fmod(_spin_deg + delta * 140.0, 360.0)
	_glass.rotation_degrees = _spin_deg
	# Soft sand pulse (scale bob on lower bulb glow).
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.04
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

	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0.04, 0.02, 0.06, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_veil)

	_glass = Control.new()
	_glass.name = "Hourglass"
	_glass.custom_minimum_size = Vector2(220, 320)
	_glass.size = Vector2(220, 320)
	_glass.set_anchors_preset(Control.PRESET_CENTER)
	_glass.offset_left = -110.0
	_glass.offset_top = -180.0
	_glass.offset_right = 110.0
	_glass.offset_bottom = 140.0
	_glass.pivot_offset = Vector2(110, 160)
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_glass)
	_draw_hourglass(_glass)

	_title = Label.new()
	_title.name = "Title"
	_title.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_title.offset_top = -120.0
	_title.offset_bottom = -40.0
	_title.offset_left = -400.0
	_title.offset_right = 400.0
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	_title.add_theme_color_override("font_shadow_color", Color(0.15, 0.02, 0.05, 0.9))
	_title.add_theme_constant_override("shadow_offset_x", 2)
	_title.add_theme_constant_override("shadow_offset_y", 2)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title)

func _draw_hourglass(parent: Control) -> void:
	# Frame posts
	_box(parent, Color(0.35, 0.22, 0.12), Rect2(20, 8, 18, 304))
	_box(parent, Color(0.35, 0.22, 0.12), Rect2(182, 8, 18, 304))
	# Top / bottom caps
	_box(parent, Color(0.45, 0.28, 0.14), Rect2(30, 4, 160, 22))
	_box(parent, Color(0.45, 0.28, 0.14), Rect2(30, 294, 160, 22))
	# Glass bulbs (diamond-ish via rotated rects + center waist)
	var upper := _poly(parent, Color(0.55, 0.78, 0.92, 0.45), [
		Vector2(50, 30), Vector2(170, 30), Vector2(120, 150), Vector2(100, 150)
	])
	upper.z_index = 1
	var lower := _poly(parent, Color(0.55, 0.78, 0.92, 0.45), [
		Vector2(100, 170), Vector2(120, 170), Vector2(170, 290), Vector2(50, 290)
	])
	lower.z_index = 1
	# Sand — upper pile + falling stream + lower pile (warm gold, original palette)
	_poly(parent, Color(0.85, 0.65, 0.25, 0.9), [
		Vector2(70, 55), Vector2(150, 55), Vector2(118, 130), Vector2(102, 130)
	])
	_box(parent, Color(0.9, 0.7, 0.3, 0.95), Rect2(106, 140, 8, 40))
	_poly(parent, Color(0.82, 0.58, 0.2, 0.95), [
		Vector2(78, 250), Vector2(142, 250), Vector2(155, 285), Vector2(65, 285)
	])
	# Rim highlight
	_box(parent, Color(0.75, 0.55, 0.25, 0.7), Rect2(95, 148, 30, 8))

func _box(parent: Control, color: Color, rect: Rect2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = rect.position
	r.size = rect.size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func _poly(parent: Control, color: Color, pts: Array) -> Polygon2D:
	var p := Polygon2D.new()
	p.color = color
	var packed := PackedVector2Array()
	for v in pts:
		packed.append(v)
	p.polygon = packed
	parent.add_child(p)
	return p

func _hide_now() -> void:
	_active = false
	_spin_deg = 0.0
	if _root:
		_root.visible = false
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _veil:
		_veil.color.a = 0.0
	if _glass:
		_glass.modulate.a = 0.0
		_glass.rotation_degrees = 0.0
		_glass.scale = Vector2.ONE
	if _title:
		_title.modulate.a = 0.0
		_title.text = ""

## Call from a level's _ready — plays enter sting if a transition just landed, else a short open.
func on_level_start(level_title: String = "") -> void:
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
		# Still transition — queue path without stacking hourglasses.
		_pending_enter = enter_title
		get_tree().change_scene_to_file(scene_path)
		return
	_busy = true
	_pending_enter = enter_title if enter_title != "" else "A new country…"
	await play_exit(exit_title, EXIT_HOLD)
	get_tree().change_scene_to_file(scene_path)
	# Enter plays from the new scene's on_level_start; clear busy there.
	_busy = false

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
	_veil.color = Color(0.05, 0.02, 0.07, 0.0)
	_glass.modulate.a = 0.0
	_title.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_veil, "color:a", 0.88, 0.35)
	tw.tween_property(_glass, "modulate:a", 1.0, 0.4)
	tw.tween_property(_title, "modulate:a", 1.0, 0.45)
	await tw.finished
	await get_tree().create_timer(hold).timeout
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(_veil, "color:a", 0.0, 0.4)
	tw2.tween_property(_glass, "modulate:a", 0.0, 0.35)
	tw2.tween_property(_title, "modulate:a", 0.0, 0.3)
	await tw2.finished
	_hide_now()
