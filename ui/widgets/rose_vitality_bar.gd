extends Control

## Custom-drawn 5 Crimson-Silver Rose Buds on a thorny silver vine (ref_03_gameplay_hud.jpg).

var current_hp: int = 5
var max_hp: int = 5
var kansas_mode: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(210, 32)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_vitality(hp: int, mhp: int = 5, p_kansas: bool = false) -> void:
	current_hp = clampi(hp, 0, mhp)
	max_hp = maxi(1, mhp)
	kansas_mode = p_kansas
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var cy := size.y * 0.56
	var vine_col := Color(0.68, 0.70, 0.74, 0.85) if kansas_mode else Color(0.76, 0.80, 0.88, 0.90)

	# Curved thorny silver vine stem spanning beneath all 5 roses
	var pts := PackedVector2Array()
	for i in range(18):
		var t := float(i) / 17.0
		var x := lerpf(10.0, w - 10.0, t)
		var y := cy + 7.5 + sin(t * TAU * 2.0) * 2.4
		pts.append(Vector2(x, y))
	draw_polyline(pts, vine_col, 1.8, true)

	# 5 sculpted rose blossoms spaced evenly along the vine
	var step := (w - 36.0) / maxf(1.0, float(max_hp - 1))
	for i in range(max_hp):
		var rx := 18.0 + float(i) * step
		var ry := cy - 1.5
		var lit := i < current_hp
		# Small thorns / leaves flanking stem
		draw_line(Vector2(rx - 7.0, ry + 9.0), Vector2(rx - 11.0, ry + 5.0), vine_col, 1.4)
		draw_line(Vector2(rx + 7.0, ry + 9.0), Vector2(rx + 11.0, ry + 5.0), vine_col, 1.4)
		var outer_col: Color
		var inner_col: Color
		var core_col: Color
		if kansas_mode:
			outer_col = Color(0.84, 0.84, 0.86) if lit else Color(0.24, 0.24, 0.26, 0.65)
			inner_col = Color(0.95, 0.95, 0.98) if lit else Color(0.18, 0.18, 0.20, 0.65)
			core_col = Color(0.62, 0.62, 0.66) if lit else Color(0.14, 0.14, 0.16, 0.65)
		else:
			outer_col = Color(0.76, 0.12, 0.30) if lit else Color(0.22, 0.14, 0.24, 0.72)
			inner_col = Color(0.94, 0.28, 0.48) if lit else Color(0.16, 0.10, 0.18, 0.72)
			core_col = Color(1.0, 0.72, 0.82) if lit else Color(0.12, 0.08, 0.14, 0.72)
		# Layered rose petals
		for p in range(5):
			var a := -PI * 0.5 + float(p) * TAU / 5.0
			draw_circle(Vector2(rx + cos(a) * 4.2, ry + sin(a) * 4.2), 5.2, outer_col)
		draw_circle(Vector2(rx, ry), 5.6, inner_col)
		draw_arc(Vector2(rx, ry), 3.2, 0.2, PI * 1.6, 12, core_col, 1.6)
		draw_circle(Vector2(rx, ry), 1.6, core_col)
		if lit:
			draw_arc(Vector2(rx, ry), 9.4, 0.0, TAU, 18, Color(0.91, 0.78, 0.48, 0.45), 1.0)
