extends Control

## Phase P7.2: Alice-Class 5 Crimson-Silver Rose Buds on a Curved Thorny Silver Vine (ref_03_gameplay_hud.jpg).
## Includes live ambient crimson bloom, multi-layered rose petals, thorny silver leaves,
## critical-HP heartbeat pulse, and animated scattering petals on hit!

var current_hp: int = 5
var max_hp: int = 5
var kansas_mode: bool = false
var _time: float = 0.0
var _falling_petals: Array[Dictionary] = []

func _is_headless() -> bool:
	var n := DisplayServer.get_name()
	return n == "headless" or n == "Dummy"

func _ready() -> void:
	custom_minimum_size = Vector2(264, 46)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_vitality(hp: int, mhp: int = 5, p_kansas: bool = false) -> void:
	var clamped := clampi(hp, 0, maxi(1, mhp))
	if clamped < current_hp and not _is_headless() and size.x > 20.0:
		_spawn_scatter_petals(clamped, current_hp)
	current_hp = clamped
	max_hp = maxi(1, mhp)
	kansas_mode = p_kansas
	queue_redraw()

func _spawn_scatter_petals(from_idx: int, to_idx: int) -> void:
	var step := (size.x - 48.0) / maxf(1.0, float(max_hp - 1))
	for r_i in range(from_idx, mini(to_idx, max_hp)):
		var rx := 24.0 + float(r_i) * step
		var ry := size.y * 0.48
		for p in range(5):
			var ang := -PI * 0.5 + float(p) * 1.25
			_falling_petals.append({
				"pos": Vector2(rx, ry),
				"vel": Vector2(cos(ang) * 26.0, sin(ang) * 18.0 - 12.0),
				"life": 0.85,
				"max_life": 0.85,
				"rot": ang,
			})

func _process(delta: float) -> void:
	if not visible or _is_headless():
		return
	_time += delta
	for i in range(_falling_petals.size() - 1, -1, -1):
		var pt: Dictionary = _falling_petals[i]
		var vel: Vector2 = pt["vel"]
		vel.y += 68.0 * delta
		pt["vel"] = vel
		pt["pos"] = (pt["pos"] as Vector2) + vel * delta
		pt["life"] = float(pt["life"]) - delta
		if float(pt["life"]) <= 0.0:
			_falling_petals.remove_at(i)
	if current_hp <= 2 or not _falling_petals.is_empty():
		queue_redraw()
	elif int(_time * 20.0) != int((_time - delta) * 20.0):
		queue_redraw()

func _draw() -> void:
	var w := size.x
	var cy := size.y * 0.48
	var vine_col := Color(0.68, 0.70, 0.74, 0.90) if kansas_mode else Color(0.784, 0.831, 0.902, 0.92)
	var vine_shadow := Color(0.05, 0.02, 0.06, 0.75)

	# Curved thorny silver vine stem + scrolling end-curl (ref_03_gameplay_hud.jpg)
	var pts := PackedVector2Array()
	var sh_pts := PackedVector2Array()
	for i in range(24):
		var t := float(i) / 23.0
		var x := lerpf(8.0, w - 8.0, t)
		var y := cy + 10.5 + sin(t * TAU * 2.0) * 2.8
		pts.append(Vector2(x, y))
		sh_pts.append(Vector2(x, y + 2.0))
	draw_polyline(sh_pts, vine_shadow, 3.0, true)
	draw_polyline(pts, vine_col, 2.0, true)
	draw_arc(Vector2(10.0, cy + 8.0), 4.5, PI * 0.4, PI * 1.85, 12, vine_col, 1.5, true)

	var crit_pulse := (0.5 + 0.5 * sin(_time * 6.5)) if current_hp <= 2 else 0.25 + 0.15 * sin(_time * 2.2)

	# 5 sculpted rose blossoms spaced evenly along the vine
	var step := (w - 52.0) / maxf(1.0, float(max_hp - 1))
	for i in range(max_hp):
		var rx := 26.0 + float(i) * step
		var ry := cy - 1.0
		var lit := i < current_hp

		# Serrated silver briar leaves & sharp thorns beneath each rose
		var leaf_l := PackedVector2Array([Vector2(rx - 4, ry + 11), Vector2(rx - 14, ry + 6), Vector2(rx - 9, ry + 14)])
		var leaf_r := PackedVector2Array([Vector2(rx + 4, ry + 11), Vector2(rx + 14, ry + 6), Vector2(rx + 9, ry + 14)])
		draw_colored_polygon(leaf_l, vine_col.darkened(0.22 if lit else 0.55))
		draw_colored_polygon(leaf_r, vine_col.darkened(0.22 if lit else 0.55))

		if lit:
			var glow_col := Color(0.85, 0.85, 0.90, 0.18) if kansas_mode else Color(0.92, 0.18, 0.38, 0.22 + crit_pulse * 0.18)
			draw_circle(Vector2(rx, ry), 15.5, glow_col)

		var outer_col: Color
		var mid_col: Color
		var inner_col: Color
		var rim_col: Color
		if kansas_mode:
			outer_col = Color(0.58, 0.60, 0.64) if lit else Color(0.18, 0.18, 0.20, 0.72)
			mid_col = Color(0.80, 0.82, 0.86) if lit else Color(0.24, 0.24, 0.26, 0.72)
			inner_col = Color(0.96, 0.96, 0.99) if lit else Color(0.14, 0.14, 0.16, 0.72)
			rim_col = Color(0.95, 0.95, 0.98, 0.85) if lit else Color(0.35, 0.35, 0.38, 0.45)
		else:
			outer_col = Color(0.58, 0.07, 0.20) if lit else Color(0.16, 0.11, 0.19, 0.82)
			mid_col = Color(0.86, 0.18, 0.36) if lit else Color(0.22, 0.16, 0.26, 0.82)
			inner_col = Color(1.0, 0.46, 0.62) if lit else Color(0.12, 0.08, 0.15, 0.82)
			rim_col = Color(0.96, 0.86, 0.90, 0.88) if lit else Color(0.42, 0.38, 0.46, 0.45)

		# Drop shadow
		draw_circle(Vector2(rx, ry + 2.5), 10.2, Color(0, 0, 0, 0.45))

		# Outer 5-petal cup
		for p in range(5):
			var a := -PI * 0.5 + float(p) * TAU / 5.0
			var pp := Vector2(rx + cos(a) * 5.2, ry + sin(a) * 4.8)
			draw_circle(pp, 6.0, outer_col)
			draw_arc(pp, 6.0, a - 0.9, a + 0.9, 8, rim_col, 1.1, true)

		# Middle 4-petal whorl
		for p in range(4):
			var a := 0.35 + float(p) * TAU / 4.0
			draw_circle(Vector2(rx + cos(a) * 2.8, ry + sin(a) * 2.6), 4.8, mid_col)

		# Inner bud spiral + silver-dew highlight
		draw_circle(Vector2(rx, ry - 0.5), 3.6, inner_col)
		draw_arc(Vector2(rx, ry - 0.5), 3.2, -0.4, PI * 1.45, 12, rim_col, 1.3, true)
		if lit:
			draw_circle(Vector2(rx - 2.2, ry - 2.8), 1.3, Color(1, 1, 1, 0.90))

	# Scattering withered/crimson petals when taking damage
	for pt in _falling_petals:
		var ppos: Vector2 = pt["pos"]
		var alpha := clampf(float(pt["life"]) / float(pt["max_life"]), 0.0, 1.0)
		var pcol := Color(0.85, 0.85, 0.88, alpha) if kansas_mode else Color(0.94, 0.20, 0.40, alpha)
		draw_circle(ppos, 3.6 * alpha + 1.2, pcol)
