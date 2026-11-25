extends Control

## Phase P7.2: Art-Nouveau Antique-Brass Double-Border, Scroll Flourishes & Specular Shimmer
## Modeled after ref_01 (Grimoire), ref_02 (Main Menu), ref_03 (HUD), and ref_05 (Boutique).

@export var brass_color: Color = Color(0.769, 0.620, 0.353, 0.92) # #C49E5A
@export var glow_color: Color = Color(0.910, 0.776, 0.478, 0.98)  # #E8C67A
@export var outer_pad: float = 7.0
@export var inset: float = 5.0
@export var corner_size: float = 14.0
@export var show_diamonds: bool = true
@export var kansas_mode: bool = false
@export var animated_sheen: bool = false
@export var clockwork_gears: bool = false

var _sheen_t: float = 0.0

func _is_headless() -> bool:
	var n := DisplayServer.get_name()
	return n == "headless" or n == "Dummy"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if not animated_sheen or not visible or _is_headless():
		return
	_sheen_t += delta * 1.35
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var p := get_parent()
	if p is PanelContainer:
		# PanelContainer shrinks direct children to its inner content_margin rect.
		# Expand back to the parent's full outer bounds so filigree hugs the card edge
		# and NEVER overlaps text, buttons, or keycaps inside the content safe zone!
		r = Rect2(-position, (p as Control).size).grow(-outer_pad)
	if r.size.x < 24.0 or r.size.y < 24.0:
		return
	var b_col := Color(0.64, 0.66, 0.70, brass_color.a) if kansas_mode else brass_color
	var g_col := Color(0.94, 0.95, 0.98, glow_color.a) if kansas_mode else glow_color
	if animated_sheen:
		var pulse := 0.5 + 0.5 * sin(_sheen_t)
		g_col = g_col.lightened(pulse * 0.14)

	var outer := r.grow(-1.0)
	var inner := r.grow(-inset)
	# Outer antique brass line + delicate inset hairline
	draw_rect(outer, b_col, false, 1.8)
	draw_rect(inner, Color(b_col.r, b_col.g, b_col.b, 0.42), false, 1.0)

	# 4 Art-Nouveau corner filigree brackets + stepped inner scrolls + golden pearls
	var c := corner_size
	var corners := [
		[Vector2(outer.position.x, outer.position.y), Vector2(1, 1)],
		[Vector2(outer.end.x, outer.position.y), Vector2(-1, 1)],
		[Vector2(outer.position.x, outer.end.y), Vector2(1, -1)],
		[Vector2(outer.end.x, outer.end.y), Vector2(-1, -1)],
	]
	for pair in corners:
		var pt_c: Vector2 = pair[0]
		var s: Vector2 = pair[1]
		draw_line(pt_c + Vector2(s.x * 1.5, s.y * 1.5), pt_c + Vector2(s.x * (c + 3.0), s.y * 1.5), g_col, 2.3, true)
		draw_line(pt_c + Vector2(s.x * 1.5, s.y * 1.5), pt_c + Vector2(s.x * 1.5, s.y * (c + 3.0)), g_col, 2.3, true)
		# Inner stepped filigree L-bracket
		draw_line(pt_c + Vector2(s.x * 5.0, s.y * 5.0), pt_c + Vector2(s.x * (c * 0.78), s.y * 5.0), b_col, 1.2, true)
		draw_line(pt_c + Vector2(s.x * 5.0, s.y * 5.0), pt_c + Vector2(s.x * 5.0, s.y * (c * 0.78)), b_col, 1.2, true)
		# Diagonal Art-Nouveau leaf spear + corner pearl
		draw_line(pt_c + Vector2(s.x * 4.5, s.y * 4.5), pt_c + Vector2(s.x * (c * 0.72), s.y * (c * 0.72)), g_col, 1.4, true)
		draw_circle(pt_c + Vector2(s.x * 4.5, s.y * 4.5), 2.3, g_col)
		draw_circle(pt_c + Vector2(s.x * (c + 3.0), s.y * 1.5), 1.5, b_col)
		draw_circle(pt_c + Vector2(s.x * 1.5, s.y * (c + 3.0)), 1.5, b_col)
		if clockwork_gears:
			# Interlocking antique-brass corner cogwheels + thorny bramble vine arcs (ref_02 Main Menu!)
			var g_center := pt_c + Vector2(s.x * (c * 0.56), s.y * (c * 0.56))
			var g_rad := clampf(c * 0.34, 5.5, 13.0)
			var spin := _sheen_t * 0.35 * s.x * s.y
			draw_arc(g_center, g_rad, 0.0, TAU, 24, b_col, 2.0, true)
			draw_arc(g_center, g_rad * 0.48, 0.0, TAU, 16, g_col, 1.4, true)
			for ti in range(8):
				var ta := spin + float(ti) * TAU / 8.0
				var dir_v := Vector2(cos(ta), sin(ta))
				draw_line(g_center + dir_v * (g_rad - 1.0), g_center + dir_v * (g_rad + 3.2), g_col, 2.2, true)
			# Secondary smaller interlocking gear
			var g2 := pt_c + Vector2(s.x * (c * 1.12), s.y * (c * 0.32))
			var r2 := g_rad * 0.58
			draw_arc(g2, r2, 0.0, TAU, 18, b_col, 1.5, true)
			for ti2 in range(6):
				var ta2 := -spin * 1.3 + float(ti2) * TAU / 6.0
				var dv2 := Vector2(cos(ta2), sin(ta2))
				draw_line(g2 + dv2 * (r2 - 0.8), g2 + dv2 * (r2 + 2.2), b_col, 1.8, true)

	# Center-edge diamond filigree accents (top, bottom, left, right)
	if show_diamonds:
		var mx := outer.position.x + outer.size.x * 0.5
		var my := outer.position.y + outer.size.y * 0.5
		for pt in [Vector2(mx, outer.position.y + 1.0), Vector2(mx, outer.end.y - 1.0), Vector2(outer.position.x + 1.0, my), Vector2(outer.end.x - 1.0, my)]:
			var d := PackedVector2Array([
				pt + Vector2(0, -4.5), pt + Vector2(4.5, 0),
				pt + Vector2(0, 4.5), pt + Vector2(-4.5, 0),
			])
			draw_colored_polygon(d, g_col)
