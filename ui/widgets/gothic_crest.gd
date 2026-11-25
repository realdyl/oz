extends Control

## 2026 Gothic Winged Clockwork & Silver-Rose Crest + Glowing Silver-Rose Focus Cursor
## Modeled directly from ref_02_main_menu.jpg ("OZ: THE ROAD HOME — THE FORBIDDEN ROAD").

@export var mode: String = "crest" # "crest" | "rose_cursor"
@export var subtitle_text: String = "THE FORBIDDEN ROAD"
@export var kansas_mode: bool = false

var _t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mode == "rose_cursor":
		custom_minimum_size = Vector2(28, 28)
	else:
		custom_minimum_size = Vector2(440, 128)

func _process(delta: float) -> void:
	if not visible or DisplayServer.get_name() in ["headless", "Dummy"]:
		return
	_t += delta
	queue_redraw()

func _draw() -> void:
	if mode == "rose_cursor":
		_draw_silver_rose(size * 0.5, minf(size.x, size.y) * 0.42, true)
		return
	_draw_winged_crest()

func _draw_silver_rose(center: Vector2, rad: float, glowing: bool) -> void:
	var pulse := 0.88 + 0.12 * sin(_t * 3.2)
	if glowing:
		draw_circle(center, rad * 1.45 * pulse, Color(0.68, 0.88, 1.0, 0.14))
		draw_circle(center, rad * 1.12 * pulse, Color(0.80, 0.94, 1.0, 0.24))
	# Outer 7 silver-ice petals
	for i in range(7):
		var a := _t * 0.18 + float(i) * TAU / 7.0
		var p := center + Vector2(cos(a), sin(a)) * (rad * 0.52)
		draw_circle(p, rad * 0.46, Color(0.58, 0.68, 0.78, 0.92))
		draw_arc(p, rad * 0.46, a - 1.1, a + 1.1, 10, Color(0.92, 0.97, 1.0, 0.95), 1.3, true)
	# Mid 5 petals
	for j in range(5):
		var a2 := -_t * 0.15 + float(j) * TAU / 5.0 + 0.3
		var p2 := center + Vector2(cos(a2), sin(a2)) * (rad * 0.28)
		draw_circle(p2, rad * 0.34, Color(0.76, 0.85, 0.94, 0.96))
	# Inner spiral bud
	draw_circle(center, rad * 0.22, Color(0.95, 0.98, 1.0, 1.0))
	draw_arc(center, rad * 0.15, 0.0, PI * 1.4, 10, Color(0.38, 0.48, 0.60, 0.9), 1.3, true)

func _draw_gear(center: Vector2, rad: float, teeth: int, spin: float, col: Color, rim: Color) -> void:
	draw_circle(center, rad * 0.82, Color(0.10, 0.07, 0.12, 0.92))
	draw_arc(center, rad, 0.0, TAU, 24, col, 2.2, true)
	draw_arc(center, rad * 0.46, 0.0, TAU, 16, rim, 1.5, true)
	for i in range(teeth):
		var a := spin + float(i) * TAU / float(teeth)
		var dv := Vector2(cos(a), sin(a))
		draw_line(center + dv * (rad - 1.0), center + dv * (rad + 3.4), rim, 2.4, true)
		if i % 2 == 0:
			draw_line(center + dv * (rad * 0.46), center + dv * (rad * 0.88), col, 1.3, true)

func _draw_winged_crest() -> void:
	var cx := size.x * 0.5
	var brass := Color(0.68, 0.70, 0.74, 0.92) if kansas_mode else Color(0.769, 0.620, 0.353, 0.94)
	var gold := Color(0.94, 0.95, 0.98, 0.98) if kansas_mode else Color(0.93, 0.80, 0.50, 0.98)
	var wing_silver := Color(0.80, 0.83, 0.88, 0.94) if kansas_mode else Color(0.82, 0.78, 0.72, 0.94)
	var wing_hi := Color(0.97, 0.98, 1.0, 0.98) if kansas_mode else Color(0.96, 0.90, 0.76, 0.98)

	# Background soft obsidian-gold halo behind crest
	draw_circle(Vector2(cx, 62), 62.0, Color(0.18, 0.11, 0.20, 0.34))

	# Thorny wreath ellipse framing the title
	draw_arc(Vector2(cx, 62), 54.0, -PI * 0.92, -PI * 0.08, 32, Color(0.54, 0.52, 0.56, 0.78), 2.0, true)
	draw_arc(Vector2(cx, 62), 54.0, PI * 0.08, PI * 0.92, 32, Color(0.54, 0.52, 0.56, 0.78), 2.0, true)

	# Symmetrical Clockwork Brass Gears behind left & right wings
	_draw_gear(Vector2(cx - 72, 42), 15.0, 9, _t * 0.32, brass, gold)
	_draw_gear(Vector2(cx + 72, 42), 15.0, 9, -_t * 0.32, brass, gold)
	_draw_gear(Vector2(cx - 92, 64), 10.5, 7, -_t * 0.48, brass, gold)
	_draw_gear(Vector2(cx + 92, 64), 10.5, 7, _t * 0.48, brass, gold)

	# Swept Sculpted Feather Wings (Left & Right — 6 layered pinions each!)
	for side in [-1.0, 1.0]:
		var s := float(side)
		var root := Vector2(cx + s * 66.0, 56.0)
		for fi in range(6):
			var frac := float(fi) / 5.0
			var len_f := lerpf(58.0, 26.0, frac)
			var ang := lerpf(-0.46, 0.38, frac)
			var dir := Vector2(s * cos(ang), sin(ang))
			var perp := Vector2(-dir.y, dir.x)
			var tip := root + dir * len_f
			var poly := PackedVector2Array([
				root,
				root + dir * (len_f * 0.48) + perp * 4.8 * s,
				tip,
				root + dir * (len_f * 0.56) - perp * 3.4 * s,
			])
			draw_colored_polygon(poly, wing_silver.darkened(frac * 0.16))
			draw_line(root, tip, wing_hi, 1.3, true)

	# Crown Apex Silver Rose (ref_02 signature centerpiece!)
	_draw_silver_rose(Vector2(cx, 18.0), 14.5, true)

	# Curved Gothic Ribbon Banner at bottom ("THE FORBIDDEN ROAD" / "GAME PAUSED")
	var rib_y := 106.0
	var rib_w := 116.0
	var rib_pts := PackedVector2Array([
		Vector2(cx - rib_w, rib_y + 4),
		Vector2(cx - rib_w * 0.5, rib_y - 3),
		Vector2(cx + rib_w * 0.5, rib_y - 3),
		Vector2(cx + rib_w, rib_y + 4),
		Vector2(cx + rib_w - 8, rib_y + 22),
		Vector2(cx + rib_w * 0.5, rib_y + 16),
		Vector2(cx - rib_w * 0.5, rib_y + 16),
		Vector2(cx - rib_w + 8, rib_y + 22),
	])
	draw_colored_polygon(rib_pts, Color(0.13, 0.10, 0.15, 0.96))
	for bi in range(rib_pts.size()):
		draw_line(rib_pts[bi], rib_pts[(bi + 1) % rib_pts.size()], brass, 1.5, true)
