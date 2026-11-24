extends Control

## Reusable art-nouveau antique-brass double-border & corner filigree overlay
## modeled directly after ref_01 (Grimoire), ref_02 (Main Menu), ref_03 (HUD), and ref_05 (Boutique).

@export var brass_color: Color = Color(0.769, 0.620, 0.353, 0.92) # #C49E5A
@export var glow_color: Color = Color(0.910, 0.776, 0.478, 0.98)  # #E8C67A
@export var inset: float = 5.0
@export var corner_size: float = 14.0
@export var show_diamonds: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x < 24.0 or r.size.y < 24.0:
		return
	var outer := r.grow(-1.0)
	var inner := r.grow(-inset)
	# Outer antique brass line + delicate inset hairline
	draw_rect(outer, brass_color, false, 1.8)
	draw_rect(inner, Color(brass_color.r, brass_color.g, brass_color.b, 0.42), false, 1.0)

	# 4 corner filigree brackets + golden corner pearls
	var c := corner_size
	var corners := [
		[Vector2(outer.position.x, outer.position.y), Vector2(1, 1)],
		[Vector2(outer.end.x, outer.position.y), Vector2(-1, 1)],
		[Vector2(outer.position.x, outer.end.y), Vector2(1, -1)],
		[Vector2(outer.end.x, outer.end.y), Vector2(-1, -1)],
	]
	for pair in corners:
		var p: Vector2 = pair[0]
		var s: Vector2 = pair[1]
		draw_line(p + Vector2(s.x * 2.0, s.y * 2.0), p + Vector2(s.x * c, s.y * 2.0), glow_color, 2.2)
		draw_line(p + Vector2(s.x * 2.0, s.y * 2.0), p + Vector2(s.x * 2.0, s.y * c), glow_color, 2.2)
		draw_line(p + Vector2(s.x * 5.0, s.y * 5.0), p + Vector2(s.x * (c * 0.65), s.y * (c * 0.65)), brass_color, 1.4)
		draw_circle(p + Vector2(s.x * 4.5, s.y * 4.5), 2.1, glow_color)

	# Center-edge diamond filigree accents (top, bottom, left, right)
	if show_diamonds:
		var mx := r.size.x * 0.5
		var my := r.size.y * 0.5
		for pt in [Vector2(mx, outer.position.y + 1.0), Vector2(mx, outer.end.y - 1.0), Vector2(outer.position.x + 1.0, my), Vector2(outer.end.x - 1.0, my)]:
			var d := PackedVector2Array([
				pt + Vector2(0, -4.0), pt + Vector2(4.0, 0),
				pt + Vector2(0, 4.0), pt + Vector2(-4.0, 0),
			])
			draw_colored_polygon(d, glow_color)
