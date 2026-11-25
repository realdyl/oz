extends Control

## Phase P3.2: Displays real painted "Tailor of Vices" couture product icons framed in antique brass,
## with procedural vector fallback if a texture is unavailable.

const ICON_MAP := {
	"dorothy_gingham": "res://assets/art/icons/shop/dorothy_gingham.png",
	"dorothy_velvet": "res://assets/art/icons/shop/dorothy_velvet.png",
	"dorothy_sovereign": "res://assets/art/icons/shop/dorothy_sovereign.png",
	"dorothy_whip_plus": "res://assets/art/icons/shop/dorothy_whip_plus.png",
	"scarecrow_classic": "res://assets/art/icons/shop/scarecrow_classic.png",
	"scarecrow_leather": "res://assets/art/icons/shop/scarecrow_classic.png",
	"scarecrow_obsidian": "res://assets/art/icons/shop/scarecrow_obsidian.png",
	"tinman_classic": "res://assets/art/portraits/tinman.png",
	"tinman_velvet": "res://assets/art/icons/shop/tinman_royal.png",
	"lion_classic": "res://assets/art/portraits/lion.png",
	"lion_primal": "res://assets/art/icons/shop/lion_primal.png",
	"toto_classic": "res://assets/art/portraits/toto.png",
	"toto_silver_collar": "res://assets/art/icons/shop/toto_spiked.png",
	"charm_echo_heel": "res://assets/art/icons/silver_shoes.png",
	"charm_velvet_thorn": "res://assets/art/icons/arm_whip.png",
	"charm_clockwork_heart": "res://assets/art/icons/mem_aunt_em_locket.png",
	"charm_winged_cap": "res://assets/art/icons/mem_emerald_spectacles.png",
}

static var _tex_cache: Dictionary = {}

var item_id: String = ""
var primary_tint: Color = Color(0.7, 0.5, 0.8)
var is_equipped: bool = false
var _art_tex: Texture2D = null

static func _load_icon_tex(res_path: String) -> Texture2D:
	if _tex_cache.has(res_path):
		return _tex_cache[res_path]
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		tex = ResourceLoader.load(res_path) as Texture2D
	if tex == null:
		var abs_path := ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	_tex_cache[res_path] = tex
	return tex

func setup(id: String, tint: Color, equipped: bool = false) -> void:
	item_id = id
	primary_tint = tint
	is_equipped = equipped
	custom_minimum_size = Vector2(74, 74)
	var path: String = str(ICON_MAP.get(id, ""))
	_art_tex = _load_icon_tex(path) if path != "" else null
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var cx := r.size.x * 0.5
	var cy := r.size.y * 0.5

	# Dark velvet medallion frame with painted couture artwork (Phase P3.2)
	draw_rect(r, Color(0.08, 0.04, 0.12, 1.0), true)
	var border_col := Color(0.98, 0.82, 0.40, 1.0) if is_equipped else Color(0.68, 0.52, 0.36, 0.85)
	if _art_tex != null:
		draw_texture_rect(_art_tex, r.grow(-2.0), false)
		draw_rect(r.grow(-1.0), border_col, false, 2.0)
		for p in [Vector2(5, 5), Vector2(r.size.x - 5, 5), Vector2(5, r.size.y - 5), Vector2(r.size.x - 5, r.size.y - 5)]:
			draw_circle(p, 2.0, border_col)
		return
	draw_circle(Vector2(cx, cy), r.size.x * 0.44, Color(primary_tint.r * 0.25, primary_tint.g * 0.20, primary_tint.b * 0.30, 0.85))
	draw_rect(r.grow(-1.0), border_col, false, 2.0)
	# Corner filigree dots
	for p in [Vector2(5, 5), Vector2(r.size.x - 5, 5), Vector2(5, r.size.y - 5), Vector2(r.size.x - 5, r.size.y - 5)]:
		draw_circle(p, 1.8, border_col)

	match item_id:
		"dorothy_gingham":
			_draw_dress(Color(0.24, 0.48, 0.90), Color(0.96, 0.97, 1.0), true, false)
		"dorothy_velvet":
			_draw_dress(Color(0.66, 0.08, 0.22), Color(0.95, 0.76, 0.34), false, true)
		"dorothy_sovereign":
			_draw_dress(Color(0.58, 0.44, 0.88), Color(0.92, 0.95, 1.0), false, true)
			# Silver sovereign star on bodice
			_draw_star(Vector2(cx, 25), 5.0, Color(0.96, 0.98, 1.0))
		"dorothy_whip_plus":
			_draw_whip()
		"scarecrow_classic":
			_draw_scarecrow(Color(0.74, 0.58, 0.34), Color(0.92, 0.80, 0.38), false)
		"scarecrow_leather":
			_draw_scarecrow(Color(0.32, 0.20, 0.16), Color(0.84, 0.68, 0.34), true)
		"scarecrow_obsidian":
			_draw_scarecrow(Color(0.16, 0.13, 0.24), Color(0.74, 0.42, 0.96), true)
		"tinman_classic":
			_draw_tinman(Color(0.78, 0.83, 0.90), Color(0.92, 0.28, 0.34), false)
		"tinman_velvet":
			_draw_tinman(Color(0.38, 0.40, 0.48), Color(0.84, 0.12, 0.26), true)
		"lion_classic":
			_draw_lion(Color(0.86, 0.58, 0.22), Color(0.96, 0.78, 0.42), false)
		"lion_primal":
			_draw_lion(Color(0.96, 0.74, 0.18), Color(1.0, 0.88, 0.48), true)
		"toto_classic":
			_draw_toto()
		"toto_silver_collar":
			_draw_collar()
		_:
			# Fallback gilded emblem
			_draw_star(Vector2(cx, cy), 14.0, primary_tint.lightened(0.25))

func _draw_dress(body_col: Color, accent_col: Color, gingham: bool, corset_lace: bool) -> void:
	var cx := size.x * 0.5
	# Puffed sleeves
	draw_circle(Vector2(cx - 12, 20), 6.0, accent_col if gingham else body_col.lightened(0.15))
	draw_circle(Vector2(cx + 12, 20), 6.0, accent_col if gingham else body_col.lightened(0.15))
	# Bodice
	var bodice := PackedVector2Array([
		Vector2(cx - 9, 15), Vector2(cx + 9, 15),
		Vector2(cx + 6, 30), Vector2(cx - 6, 30),
	])
	draw_colored_polygon(bodice, body_col)
	# Flared skirt
	var skirt := PackedVector2Array([
		Vector2(cx - 6, 30), Vector2(cx + 6, 30),
		Vector2(cx + 20, 54), Vector2(cx - 20, 54),
	])
	draw_colored_polygon(skirt, body_col)
	# Skirt hem trim
	draw_line(Vector2(cx - 19, 52), Vector2(cx + 19, 52), accent_col, 2.2)
	if gingham:
		# Crisp gingham check lines & white apron bow
		for x_off in [-8.0, 0.0, 8.0]:
			draw_line(Vector2(cx + x_off * 0.6, 31), Vector2(cx + x_off * 1.4, 53), Color(1, 1, 1, 0.35), 1.5)
		for y_off in [37.0, 44.0]:
			draw_line(Vector2(cx - 12, y_off), Vector2(cx + 12, y_off), Color(1, 1, 1, 0.35), 1.5)
		# Waist ribbon & bow
		draw_rect(Rect2(cx - 7, 28, 14, 3.5), accent_col, true)
		draw_circle(Vector2(cx, 30), 2.5, accent_col)
	elif corset_lace:
		# Gold/silver corset cross-lacing on bodice
		for y in [18.0, 22.0, 26.0]:
			draw_line(Vector2(cx - 4, y), Vector2(cx + 4, y + 3), accent_col, 1.4)
			draw_line(Vector2(cx + 4, y), Vector2(cx - 4, y + 3), accent_col, 1.4)
		# Waist belt
		draw_line(Vector2(cx - 7, 30), Vector2(cx + 7, 30), accent_col, 2.2)

func _draw_whip() -> void:
	# Gilded handle
	draw_line(Vector2(14, 50), Vector2(26, 36), Color(0.95, 0.78, 0.34), 4.5)
	draw_circle(Vector2(14, 50), 3.0, Color(1.0, 0.88, 0.48))
	# Coiled crimson-rose lash
	draw_arc(Vector2(37, 30), 14.0, -PI * 0.85, PI * 0.85, 24, Color(0.95, 0.18, 0.44), 3.0)
	draw_arc(Vector2(38, 30), 9.0, -PI * 0.6, PI * 0.95, 20, Color(1.0, 0.36, 0.62), 2.4)
	# Glowing whip tip crackle
	_draw_star(Vector2(47, 17), 5.5, Color(1.0, 0.88, 0.56))

func _draw_scarecrow(coat_col: Color, trim_col: Color, strapped: bool) -> void:
	var cx := size.x * 0.5
	# Pointed hat
	var hat := PackedVector2Array([
		Vector2(cx - 17, 24), Vector2(cx + 17, 24),
		Vector2(cx + 8, 20), Vector2(cx + 2, 8), Vector2(cx - 9, 20),
	])
	draw_colored_polygon(hat, coat_col.darkened(0.18))
	draw_line(Vector2(cx - 17, 24), Vector2(cx + 17, 24), trim_col, 2.0)
	# Straw collar tufts
	for dx in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		draw_line(Vector2(cx + dx, 25), Vector2(cx + dx * 1.25, 31), trim_col, 2.0)
	# Tunic body
	var coat := PackedVector2Array([
		Vector2(cx - 13, 30), Vector2(cx + 13, 30),
		Vector2(cx + 17, 54), Vector2(cx - 17, 54),
	])
	draw_colored_polygon(coat, coat_col)
	if strapped:
		# Crossed leather/obsidian bandolier + brass buckle
		draw_line(Vector2(cx - 11, 31), Vector2(cx + 12, 51), Color(0.12, 0.08, 0.10), 3.2)
		draw_line(Vector2(cx + 11, 31), Vector2(cx - 12, 51), Color(0.12, 0.08, 0.10), 3.2)
		draw_rect(Rect2(cx - 3.5, 38.5, 7, 7), trim_col, false, 1.8)
	else:
		# Burlap patch
		draw_rect(Rect2(cx + 3, 40, 8, 8), coat_col.lightened(0.22), true)
		draw_rect(Rect2(cx + 3, 40, 8, 8), Color(0.25, 0.18, 0.10), false, 1.2)

func _draw_tinman(metal_col: Color, heart_col: Color, crimson_sash: bool) -> void:
	var cx := size.x * 0.5
	# Iconic funnel cap
	var funnel := PackedVector2Array([
		Vector2(cx - 11, 21), Vector2(cx + 11, 21),
		Vector2(cx + 2, 8), Vector2(cx - 2, 8),
	])
	draw_colored_polygon(funnel, metal_col.lightened(0.1))
	draw_line(Vector2(cx - 12, 21), Vector2(cx + 12, 21), Color(0.95, 0.98, 1.0), 2.0)
	# Armored barrel chestplate
	var plate := PackedVector2Array([
		Vector2(cx - 15, 25), Vector2(cx + 15, 25),
		Vector2(cx + 12, 53), Vector2(cx - 12, 53),
	])
	draw_colored_polygon(plate, metal_col)
	# Specular vertical shine
	draw_line(Vector2(cx - 8, 27), Vector2(cx - 6, 51), Color(1, 1, 1, 0.45), 3.0)
	if crimson_sash:
		draw_line(Vector2(cx - 14, 27), Vector2(cx + 12, 51), heart_col, 6.0)
		draw_line(Vector2(cx - 14, 27), Vector2(cx + 12, 51), Color(0.98, 0.82, 0.42), 1.4)
	# Clockwork heart emblem
	draw_circle(Vector2(cx + 3, 36), 4.5, heart_col)
	draw_circle(Vector2(cx + 3, 36), 4.5, Color(0.98, 0.85, 0.46), false, 1.2)

func _draw_lion(mane_col: Color, face_col: Color, gilded_harness: bool) -> void:
	var cx := size.x * 0.5
	var cy := size.y * 0.5 + 1.0
	# Scalloped mane petals
	for i in range(10):
		var a := float(i) * TAU / 10.0
		draw_circle(Vector2(cx + cos(a) * 14.0, cy + sin(a) * 14.0), 7.5, mane_col)
	# Face
	draw_circle(Vector2(cx, cy), 11.5, face_col)
	# Eyes & nose
	draw_circle(Vector2(cx - 4.2, cy - 2.0), 1.8, Color(0.12, 0.08, 0.06))
	draw_circle(Vector2(cx + 4.2, cy - 2.0), 1.8, Color(0.12, 0.08, 0.06))
	var nose := PackedVector2Array([Vector2(cx - 3, cy + 2), Vector2(cx + 3, cy + 2), Vector2(cx, cy + 5.5)])
	draw_colored_polygon(nose, Color(0.32, 0.16, 0.10))
	if gilded_harness:
		# Crown & ruby gem
		var crown := PackedVector2Array([
			Vector2(cx - 9, cy - 11), Vector2(cx - 6, cy - 18), Vector2(cx, cy - 13),
			Vector2(cx + 6, cy - 18), Vector2(cx + 9, cy - 11),
		])
		draw_colored_polygon(crown, Color(1.0, 0.86, 0.34))
		draw_circle(Vector2(cx, cy - 12.5), 2.5, Color(0.95, 0.16, 0.34))

func _draw_toto() -> void:
	var cx := size.x * 0.5
	var cy := size.y * 0.5 + 4.0
	var fur := Color(0.28, 0.22, 0.18)
	# Perky triangular ears
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 13, cy - 4), Vector2(cx - 10, cy - 19), Vector2(cx - 2, cy - 9)]), fur)
	draw_colored_polygon(PackedVector2Array([Vector2(cx + 13, cy - 4), Vector2(cx + 10, cy - 19), Vector2(cx + 2, cy - 9)]), fur)
	# Terrier head & snout
	draw_circle(Vector2(cx, cy), 13.0, fur)
	draw_circle(Vector2(cx, cy + 4), 7.5, Color(0.36, 0.29, 0.24))
	# Bright eyes & nose
	draw_circle(Vector2(cx - 4.5, cy - 2.5), 2.0, Color(0.98, 0.94, 0.86))
	draw_circle(Vector2(cx + 4.5, cy - 2.5), 2.0, Color(0.98, 0.94, 0.86))
	draw_circle(Vector2(cx - 4.5, cy - 2.5), 1.0, Color(0.06, 0.05, 0.05))
	draw_circle(Vector2(cx + 4.5, cy - 2.5), 1.0, Color(0.06, 0.05, 0.05))
	draw_circle(Vector2(cx, cy + 2.5), 2.5, Color(0.08, 0.06, 0.06))

func _draw_collar() -> void:
	var cx := size.x * 0.5
	var cy := size.y * 0.5
	# Silver collar ring
	draw_arc(Vector2(cx, cy - 2), 16.0, 0.0, TAU, 32, Color(0.76, 0.82, 0.92), 6.0)
	draw_arc(Vector2(cx, cy - 2), 16.0, 0.0, TAU, 32, Color(0.26, 0.28, 0.36), 1.5)
	# Silver spikes around band
	for i in range(6):
		var a := float(i) * TAU / 6.0
		var p_in := Vector2(cx + cos(a) * 17.0, cy - 2 + sin(a) * 17.0)
		var p_out := Vector2(cx + cos(a) * 23.0, cy - 2 + sin(a) * 23.0)
		draw_line(p_in, p_out, Color(0.96, 0.98, 1.0), 2.5)
	# Star charm pendant
	_draw_star(Vector2(cx, cy + 16), 6.5, Color(0.96, 0.86, 0.44))

func _draw_star(center: Vector2, radius: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var a := -PI * 0.5 + float(i) * PI / 5.0
		var rad := radius if (i % 2 == 0) else radius * 0.44
		pts.append(center + Vector2(cos(a) * rad, sin(a) * rad))
	draw_colored_polygon(pts, col)
