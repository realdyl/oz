extends Control

## Phase P7.2: Ornate Magenta-to-Molten-Gold ALLURE Filigree Gauge + Faceted DESIRE Crystal Plaque
## Modeled pixel-for-pixel after top-right of ref_03_gameplay_hud.jpg.

var target_allure: float = 35.0
var display_allure: float = 35.0
var target_desire: int = 0
var display_desire: float = 0.0
var kansas_mode: bool = false
var _time: float = 0.0
var _desire_flash: float = 0.0

func _is_headless() -> bool:
	var n := DisplayServer.get_name()
	return n == "headless" or n == "Dummy"

func _ready() -> void:
	custom_minimum_size = Vector2(264, 68)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_values(p_allure: float, p_desire: int, p_kansas: bool = false) -> void:
	if p_desire > target_desire:
		_desire_flash = 1.0
	target_allure = clampf(p_allure, 0.0, 100.0)
	target_desire = maxi(0, p_desire)
	kansas_mode = p_kansas
	if _is_headless():
		display_allure = target_allure
		display_desire = float(target_desire)
	queue_redraw()

func _process(delta: float) -> void:
	if not visible or _is_headless():
		return
	_time += delta
	display_allure = lerpf(display_allure, target_allure, clampf(delta * 8.0, 0.0, 1.0))
	display_desire = move_toward(display_desire, float(target_desire), maxf(18.0, absf(float(target_desire) - display_desire) * 7.0) * delta)
	_desire_flash = maxf(_desire_flash - delta * 2.4, 0.0)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var brass := Color(0.66, 0.68, 0.72, 0.88) if kansas_mode else Color(0.769, 0.620, 0.353, 0.94)
	var gold_hi := Color(0.94, 0.95, 0.97, 1.0) if kansas_mode else Color(0.94, 0.80, 0.48, 1.0)
	var dark_bg := Color(0.08, 0.08, 0.10, 0.92) if kansas_mode else Color(0.086, 0.045, 0.102, 0.92)

	# ========================================================================
	# 1. TOP BAR: Ornate Crested ALLURE Liquid Gauge + Hung Nameplate
	# ========================================================================
	var bar_rect := Rect2(8.0, 6.0, w - 16.0, 15.0)
	draw_rect(bar_rect, dark_bg, true)

	# Multi-stop Magenta -> Crimson-Rose -> Molten-Gold gradient fill
	var ratio := clampf(display_allure / 100.0, 0.0, 1.0)
	var fill_w := (bar_rect.size.x - 4.0) * ratio
	if fill_w > 1.5:
		var segs := maxi(4, int(fill_w / 6.0))
		var sx0 := bar_rect.position.x + 2.0
		var sy0 := bar_rect.position.y + 2.0
		var sh := bar_rect.size.y - 4.0
		var seg_w := fill_w / float(segs)
		for i in range(segs):
			var t := float(i) / float(segs)
			var c_start := Color(0.46, 0.48, 0.52) if kansas_mode else Color(0.48, 0.09, 0.34)
			var c_mid := Color(0.72, 0.74, 0.78) if kansas_mode else Color(0.86, 0.22, 0.48)
			var c_tip := Color(0.95, 0.95, 0.98) if kansas_mode else Color(1.0, 0.82, 0.42)
			var col := c_start.lerp(c_mid, clampf(t * 1.4, 0.0, 1.0)).lerp(c_tip, clampf((t - 0.55) * 2.2, 0.0, 1.0))
			var shimmer := 0.08 * sin(_time * 4.2 - t * 9.0)
			col = col.lightened(maxf(0.0, shimmer))
			draw_rect(Rect2(sx0 + float(i) * seg_w, sy0, seg_w + 0.6, sh), col, true)
		# Top glass tube highlight + glowing meniscus spark at fill tip
		draw_line(Vector2(sx0, sy0 + 1.5), Vector2(sx0 + fill_w, sy0 + 1.5), Color(1, 1, 1, 0.34), 1.2)
		var tip_x := sx0 + fill_w
		draw_circle(Vector2(tip_x, sy0 + sh * 0.5), 4.2, Color(1.0, 0.90, 0.62, 0.88))

	# Double brass frame + pointed side finials + center crown crest
	draw_rect(bar_rect, brass, false, 1.6)
	for side_s in [-1.0, 1.0]:
		var fx := bar_rect.position.x if side_s < 0.0 else bar_rect.end.x
		var cy_b := bar_rect.position.y + bar_rect.size.y * 0.5
		var fin := PackedVector2Array([
			Vector2(fx, cy_b - 4.0),
			Vector2(fx + side_s * 6.0, cy_b),
			Vector2(fx, cy_b + 4.0),
		])
		draw_colored_polygon(fin, gold_hi)

	# Hung "ALLURE" mini-plaque centered right below the bar (ref_03_gameplay_hud.jpg)
	var cx := w * 0.58
	var tag_rect := Rect2(cx - 34.0, bar_rect.end.y - 1.0, 68.0, 14.0)
	draw_rect(tag_rect, dark_bg, true)
	draw_rect(tag_rect, brass, false, 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(tag_rect.position.x, tag_rect.position.y + 10.5), "ALLURE", HORIZONTAL_ALIGNMENT_CENTER, tag_rect.size.x, 9, gold_hi)

	# ========================================================================
	# 2. BOTTOM PLAQUE: Faceted Glowing Desire Crystal + Rolling Counter
	# ========================================================================
	var p_rect := Rect2(w - 156.0, 39.0, 148.0, 24.0)
	var bevel := PackedVector2Array([
		Vector2(p_rect.position.x + 8.0, p_rect.position.y),
		Vector2(p_rect.end.x - 6.0, p_rect.position.y),
		Vector2(p_rect.end.x, p_rect.position.y + 12.0),
		Vector2(p_rect.end.x - 6.0, p_rect.end.y),
		Vector2(p_rect.position.x + 8.0, p_rect.end.y),
		Vector2(p_rect.position.x, p_rect.position.y + 12.0),
	])
	draw_colored_polygon(bevel, dark_bg)
	draw_polyline(bevel + PackedVector2Array([bevel[0]]), brass, 1.4, true)

	# Faceted Glowing Amber-Rose Desire Crystal on left point of plaque
	var gx := p_rect.position.x + 4.0
	var gy := p_rect.position.y + 12.0
	var glow_r := 13.0 + _desire_flash * 5.0
	draw_circle(Vector2(gx, gy), glow_r, Color(0.98, 0.72, 0.30, 0.20 + _desire_flash * 0.35))
	var gem_outer := PackedVector2Array([
		Vector2(gx, gy - 12.0),
		Vector2(gx + 9.0, gy),
		Vector2(gx, gy + 12.0),
		Vector2(gx - 9.0, gy),
	])
	var gem_col := Color(0.88, 0.88, 0.92) if kansas_mode else Color(0.96, 0.68, 0.24)
	var gem_hi := Color(1.0, 0.96, 0.82)
	draw_colored_polygon(gem_outer, gem_col)
	draw_colored_polygon(PackedVector2Array([Vector2(gx, gy - 12.0), Vector2(gx + 9.0, gy), Vector2(gx, gy)]), gem_hi)
	draw_colored_polygon(PackedVector2Array([Vector2(gx, gy - 6.0), Vector2(gx + 4.5, gy), Vector2(gx, gy + 6.0), Vector2(gx - 4.5, gy)]), Color(1.0, 0.92, 0.72, 0.85))
	draw_polyline(gem_outer + PackedVector2Array([gem_outer[0]]), gold_hi, 1.2, true)

	var d_str := "%d  DESIRE" % int(round(display_desire))
	draw_string(font, Vector2(p_rect.position.x + 18.0, p_rect.position.y + 16.5), d_str, HORIZONTAL_ALIGNMENT_CENTER, p_rect.size.x - 22.0, 13, Color(0.96, 0.90, 0.78))
