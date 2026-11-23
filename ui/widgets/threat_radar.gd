extends Control

## Modern 2026 Minimalist Threat Compass / Radar Bar.
## Replaces raw debug strings with a sleek, translucent curved HUD rail,
## bearing pip (diamond for Marshal, circle for rogue), distance badge, and live count.

var live_count: int = 0
var distance_m: float = 0.0
var angle_deg: float = 0.0
var is_marshal: bool = false
var kansas_mode: bool = false
var has_threat: bool = false

var _target_alpha: float = 0.0
var _current_alpha: float = 0.0
var _smoothed_angle: float = 0.0
var _pill_sb: StyleBoxFlat = null

func _ready() -> void:
	custom_minimum_size = Vector2(360, 42)
	mouse_filter = MOUSE_FILTER_IGNORE
	_pill_sb = StyleBoxFlat.new()
	_pill_sb.bg_color = Color(0.06, 0.04, 0.08, 0.72)
	_pill_sb.border_color = Color(0.84, 0.69, 0.36, 0.35)
	_pill_sb.set_border_width_all(1)
	_pill_sb.set_corner_radius_all(14)
	_pill_sb.anti_aliasing = true

func update_threat(p_has_threat: bool, p_live: int, p_dist: float, p_ang_deg: float, p_marshal: bool, p_kansas: bool) -> void:
	has_threat = p_has_threat and not p_kansas and p_live > 0
	live_count = p_live
	distance_m = p_dist
	angle_deg = p_ang_deg
	is_marshal = p_marshal
	kansas_mode = p_kansas
	_target_alpha = 1.0 if has_threat else 0.0

func _process(delta: float) -> void:
	_current_alpha = move_toward(_current_alpha, _target_alpha, delta * 4.0)
	modulate.a = _current_alpha
	if _current_alpha > 0.01:
		# Angle wrap interpolation
		var diff := fposmod(angle_deg - _smoothed_angle + 180.0, 360.0) - 180.0
		_smoothed_angle += diff * clampf(delta * 14.0, 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	if _current_alpha <= 0.01:
		return

	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var cy := h * 0.5

	var rail_w := w * 0.75
	var rail_left := cx - rail_w * 0.5
	var rail_right := cx + rail_w * 0.5

	# 1. Subtle dark glass background pill for the rail
	var bg_rect := Rect2(rail_left - 12.0, cy - 14.0, rail_w + 24.0, 28.0)
	if _pill_sb:
		draw_style_box(_pill_sb, bg_rect)

	# 2. Horizontal guideline with tick marks
	var line_col := Color(0.84, 0.69, 0.36, 0.40)
	draw_line(Vector2(rail_left, cy), Vector2(rail_right, cy), line_col, 1.5)

	# Cardinal ticks: center (ahead), left (-90), right (+90)
	draw_line(Vector2(cx, cy - 6), Vector2(cx, cy + 6), Color(0.98, 0.82, 0.38, 0.85), 2.0)
	draw_line(Vector2(rail_left, cy - 4), Vector2(rail_left, cy + 4), line_col, 1.0)
	draw_line(Vector2(rail_right, cy - 4), Vector2(rail_right, cy + 4), line_col, 1.0)

	# 3. Threat Pip position along rail (-180° to +180° mapped to rail bounds)
	# Normal forward field is [-90°, +90°]. Clamp gracefully with overflow indicator.
	var norm := clampf(_smoothed_angle / 90.0, -1.0, 1.0)
	var pip_x := cx + norm * (rail_w * 0.45)
	var is_behind := absf(_smoothed_angle) > 90.0

	var pip_col := Color(0.98, 0.78, 0.28, 1.0) if is_marshal else Color(0.94, 0.28, 0.34, 1.0)

	if is_behind:
		# Draw a down-chevron arrow below the edge to show it's behind
		var edge_x := cx + (1.0 if _smoothed_angle > 0 else -1.0) * (rail_w * 0.48)
		var pts: PackedVector2Array = [
			Vector2(edge_x - 5, cy - 2),
			Vector2(edge_x + 5, cy - 2),
			Vector2(edge_x, cy + 6)
		]
		draw_colored_polygon(pts, pip_col)
	elif is_marshal:
		# Diamond pip for Marshal (distinct shape for accessibility)
		var d_pts: PackedVector2Array = [
			Vector2(pip_x, cy - 7),
			Vector2(pip_x + 7, cy),
			Vector2(pip_x, cy + 7),
			Vector2(pip_x - 7, cy)
		]
		draw_colored_polygon(d_pts, pip_col)
		draw_polyline(d_pts, Color(1, 1, 1, 0.9), 1.5)
	else:
		# Circular pip with glowing inner core for standard rogues
		draw_circle(Vector2(pip_x, cy), 6.0, Color(0, 0, 0, 0.5))
		draw_circle(Vector2(pip_x, cy), 5.0, pip_col)
		draw_circle(Vector2(pip_x, cy), 2.0, Color(1.0, 0.95, 0.9, 0.95))

	# 4. Text labels: Distance badge (left) & Live count pill (right)
	var font := ThemeDB.fallback_font
	var font_sz := 13

	var dist_txt := "%.0fm" % distance_m
	if is_marshal:
		dist_txt = "★ Marshal  " + dist_txt
	draw_string(
		font,
		Vector2(rail_left - 8.0 - font.get_string_size(dist_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x, cy + 4.5),
		dist_txt,
		HORIZONTAL_ALIGNMENT_RIGHT,
		-1,
		font_sz,
		Color(0.96, 0.90, 0.82, 0.95)
	)

	var live_txt := "%d live" % live_count
	draw_string(
		font,
		Vector2(rail_right + 10.0, cy + 4.5),
		live_txt,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_sz,
		Color(0.85, 0.78, 0.70, 0.85)
	)
