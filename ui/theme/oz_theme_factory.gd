extends RefCounted

## Central 2026 design-system factory for Oz: The Road Home.
## Generates cached high-DPI StyleBoxFlat styles and Themes for both
## Oz Storybook (warm parchment + antique gold + deep plum glass) and
## Kansas Prairie (austere film-noir slate + silver-ash monochrome).

static var _theme_oz: Theme = null
static var _theme_kansas: Theme = null

# --- Color Tokens: Oz Storybook (Sampled from Approved Master GUI References) ---
const OZ_SURFACE := Color(0.086, 0.051, 0.102, 0.88)      # #160D1A Smoked Glass HUD
const OZ_SURFACE_DEEP := Color(0.071, 0.035, 0.078, 0.96) # #120914 Obsidian Plum
const OZ_VELVET_CARD := Color(0.157, 0.094, 0.188, 0.94)  # #281830 Velvet Parchment
const OZ_BORDER_GOLD := Color(0.769, 0.620, 0.353, 0.88)  # #C49E5A Hammered Antique Brass
const OZ_BORDER_SUBTLE := Color(0.769, 0.620, 0.353, 0.36)
const OZ_PARCHMENT := Color(0.937, 0.878, 0.761, 0.96)    # #EFE0C2 Warm Ivory Serif
const OZ_INK := Color(0.110, 0.060, 0.125, 1.0)
const OZ_TEXT := Color(0.937, 0.878, 0.761, 1.0)          # #EFE0C2 Warm Ivory
const OZ_TEXT_MUTED := Color(0.722, 0.659, 0.604, 0.92)   # #B8A89A Muted Parchment
const OZ_GOLD_BRIGHT := Color(0.910, 0.776, 0.478, 1.0)   # #E8C67A Burnished Gold
const OZ_ROSE_CRIMSON := Color(0.851, 0.220, 0.376, 1.0)  # #D93860 Crimson Silver-Rose
const OZ_SILVER_MIST := Color(0.784, 0.831, 0.902, 1.0)   # #C8D4E6 Silver Mist
const OZ_FINAL_SURFACE := Color(0.19, 0.05, 0.11, 0.95)
const OZ_FINAL_BORDER := Color(0.910, 0.776, 0.478, 0.96)
const OZ_KEYCAP_BG := Color(0.937, 0.878, 0.761, 0.98)
const OZ_KEYCAP_BEVEL := Color(0.65, 0.52, 0.30, 1.0)
const OZ_THREAT := Color(0.851, 0.220, 0.376, 1.0)
const OZ_MARSHAL := Color(0.910, 0.776, 0.478, 1.0)

# --- Color Tokens: Kansas Prairie (Film-Noir Monochrome) ---
const KS_SURFACE := Color(0.09, 0.10, 0.11, 0.88)
const KS_SURFACE_DEEP := Color(0.07, 0.08, 0.09, 0.95)
const KS_BORDER := Color(0.62, 0.64, 0.68, 0.55)
const KS_BORDER_SUBTLE := Color(0.62, 0.64, 0.68, 0.25)
const KS_PARCHMENT := Color(0.90, 0.91, 0.92, 0.95)
const KS_INK := Color(0.10, 0.11, 0.12, 1.0)
const KS_TEXT := Color(0.94, 0.94, 0.95, 1.0)
const KS_TEXT_MUTED := Color(0.68, 0.70, 0.73, 0.90)
const KS_ACCENT_BRIGHT := Color(0.95, 0.95, 0.97, 1.0)
const KS_FINAL_SURFACE := Color(0.15, 0.16, 0.18, 0.94)
const KS_FINAL_BORDER := Color(0.95, 0.95, 0.97, 0.95)
const KS_KEYCAP_BG := Color(0.90, 0.91, 0.92, 0.95)
const KS_KEYCAP_BEVEL := Color(0.42, 0.44, 0.48, 1.0)


static func _make_box(
	bg: Color,
	border: Color,
	border_w: int = 1,
	radius: int = 8,
	pad_x: int = 16,
	pad_y: int = 10,
	shadow_sz: int = 12,
	shadow_col: Color = Color(0.0, 0.0, 0.0, 0.45),
	shadow_off: Vector2 = Vector2(0, 4)
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_w
	sb.border_width_top = border_w
	sb.border_width_right = border_w
	sb.border_width_bottom = border_w
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_bottom_left = radius
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	sb.shadow_size = shadow_sz
	sb.shadow_color = shadow_col
	sb.shadow_offset = shadow_off
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.0
	return sb


static func make_panel_style(kansas: bool, final_step: bool = false) -> StyleBoxFlat:
	if final_step:
		if kansas:
			return _make_box(
				KS_FINAL_SURFACE, KS_FINAL_BORDER, 2, 10, 26, 18, 16,
				Color(0.92, 0.92, 0.96, 0.25), Vector2(0, 4)
			)
		return _make_box(
			OZ_FINAL_SURFACE, OZ_FINAL_BORDER, 2, 10, 26, 18, 18,
			Color(0.98, 0.80, 0.32, 0.32), Vector2(0, 4)
		)
	if kansas:
		return _make_box(KS_SURFACE, KS_BORDER, 1, 8, 24, 16, 12)
	return _make_box(OZ_SURFACE, OZ_BORDER_GOLD, 2, 10, 26, 18, 14)


static func make_pill_style(kansas: bool, pad_x: int = 14, pad_y: int = 7) -> StyleBoxFlat:
	if kansas:
		return _make_box(
			Color(0.08, 0.09, 0.10, 0.78), KS_BORDER_SUBTLE, 1, 999, pad_x, pad_y, 8,
			Color(0.0, 0.0, 0.0, 0.35), Vector2(0, 2)
		)
	return _make_box(
		Color(0.08, 0.06, 0.10, 0.78), OZ_BORDER_SUBTLE, 1, 999, pad_x, pad_y, 8,
		Color(0.0, 0.0, 0.0, 0.38), Vector2(0, 2)
	)


static func make_keycap_style(kansas: bool) -> StyleBoxFlat:
	var bg := KS_KEYCAP_BG if kansas else OZ_KEYCAP_BG
	var bevel := KS_KEYCAP_BEVEL if kansas else OZ_KEYCAP_BEVEL
	var sb := _make_box(bg, bevel, 1, 6, 9, 3, 4, Color(0, 0, 0, 0.35), Vector2(0, 2))
	sb.border_width_bottom = 3
	return sb


static func make_nameplate_style(kansas: bool) -> StyleBoxFlat:
	var bg := KS_PARCHMENT if kansas else OZ_PARCHMENT
	var border := KS_BORDER if kansas else OZ_BORDER_GOLD
	return _make_box(bg, border, 2, 6, 16, 5, 8, Color(0, 0, 0, 0.35), Vector2(0, 2))


static func make_roster_slot_style(active: bool, locked: bool, kansas: bool) -> StyleBoxFlat:
	if kansas:
		var bg := Color(0.16, 0.17, 0.19, 0.92) if active else Color(0.08, 0.09, 0.10, 0.65)
		var border := KS_ACCENT_BRIGHT if active else KS_BORDER_SUBTLE
		return _make_box(bg, border, 2 if active else 1, 6, 10, 6, 8 if active else 4)
	if active:
		return _make_box(
			Color(0.16, 0.11, 0.20, 0.95), OZ_GOLD_BRIGHT, 2, 8, 12, 7, 12,
			Color(0.95, 0.78, 0.32, 0.28), Vector2(0, 2)
		)
	if locked:
		return _make_box(
			Color(0.06, 0.05, 0.07, 0.55), Color(0.45, 0.40, 0.38, 0.25), 1, 8, 10, 6, 2
		)
	return _make_box(
		Color(0.09, 0.07, 0.12, 0.78), OZ_BORDER_SUBTLE, 1, 8, 10, 6, 6
	)


static func make_modal_style(kansas: bool) -> StyleBoxFlat:
	if kansas:
		return _make_box(
			KS_SURFACE_DEEP, KS_BORDER, 2, 14, 38, 30, 24,
			Color(0.0, 0.0, 0.0, 0.65), Vector2(0, 8)
		)
	return _make_box(
		OZ_SURFACE_DEEP, OZ_BORDER_GOLD, 2, 16, 40, 30, 28,
		Color(0.0, 0.0, 0.0, 0.72), Vector2(0, 10)
	)


## Unified 2026 Royal Jewel button styling shared across Pause Menu, Tailor of Vices Boutique,
## Grimoire, and Save/Load panels so every screen shares ONE cohesive Obsidian-Plum,
## Burnished Antique Gold, and Imperial Emerald luxury visual identity.
static func style_royal_button(btn: Button, role: String = "secondary", kansas: bool = false, font_sz: int = 15, radius: int = 14) -> void:
	if btn == null:
		return
	var bg_col := Color(0.135, 0.082, 0.175)
	var bevel_col := Color(0.070, 0.038, 0.095)
	var rim_col := OZ_GOLD_BRIGHT
	var top_border := Color(0.769, 0.620, 0.353, 0.58)
	if kansas:
		match role:
			"primary":
				bg_col = Color(0.32, 0.34, 0.38)
				bevel_col = Color(0.18, 0.19, 0.22)
				rim_col = Color(0.92, 0.94, 0.98)
			"featured", "crimson":
				bg_col = Color(0.24, 0.25, 0.29)
				bevel_col = Color(0.13, 0.14, 0.17)
				rim_col = Color(0.84, 0.86, 0.90)
			"danger":
				bg_col = Color(0.26, 0.20, 0.22)
				bevel_col = Color(0.14, 0.10, 0.12)
				rim_col = Color(0.76, 0.60, 0.62)
			_:
				bg_col = Color(0.17, 0.18, 0.21)
				bevel_col = Color(0.10, 0.11, 0.13)
				rim_col = Color(0.72, 0.74, 0.78)
		top_border = Color(0.68, 0.70, 0.74, 0.50)
	else:
		match role:
			"primary":
				# Imperial Emerald — singular hero CTA across Pause Menu & Boutique
				bg_col = Color(0.086, 0.420, 0.294)
				bevel_col = Color(0.035, 0.220, 0.150)
				rim_col = Color(0.94, 0.82, 0.50)
				top_border = Color(0.42, 0.82, 0.62, 0.75)
			"featured":
				# Royal Velvet Amethyst with Burnished Gold Trim (Grimoire / Active Shop Tab)
				bg_col = Color(0.215, 0.118, 0.305)
				bevel_col = Color(0.105, 0.052, 0.165)
				rim_col = OZ_GOLD_BRIGHT
				top_border = Color(0.84, 0.68, 0.38, 0.78)
			"crimson":
				# Velvet Crimson-Rose with Burnished Gold Trim (Boutique / Desire Accent)
				bg_col = Color(0.390, 0.102, 0.192)
				bevel_col = Color(0.205, 0.045, 0.098)
				rim_col = Color(0.96, 0.82, 0.52)
				top_border = Color(0.90, 0.66, 0.42, 0.76)
			"danger":
				# Muted Velvet Garnet (Quit / Delete)
				bg_col = Color(0.265, 0.082, 0.122)
				bevel_col = Color(0.135, 0.035, 0.060)
				rim_col = Color(0.90, 0.52, 0.58)
				top_border = Color(0.72, 0.38, 0.44, 0.55)
			_:
				# Unified Obsidian Velvet (All secondary utility buttons & inactive tabs)
				bg_col = Color(0.135, 0.082, 0.175)
				bevel_col = Color(0.068, 0.038, 0.094)
				rim_col = OZ_GOLD_BRIGHT
				top_border = Color(0.769, 0.620, 0.353, 0.52)

	var norm := StyleBoxFlat.new()
	norm.bg_color = bg_col
	norm.border_color = bevel_col
	norm.border_width_left = 2
	norm.border_width_right = 2
	norm.border_width_top = 2
	norm.border_width_bottom = 5
	norm.set_corner_radius_all(radius)
	norm.content_margin_left = 22
	norm.content_margin_right = 22
	norm.content_margin_top = 12
	norm.content_margin_bottom = 12
	norm.shadow_size = 10
	norm.shadow_color = Color(0.0, 0.0, 0.0, 0.44)
	norm.shadow_offset = Vector2(0, 4)
	norm.anti_aliasing = true

	var hov := norm.duplicate() as StyleBoxFlat
	hov.bg_color = bg_col.lightened(0.12)
	hov.border_color = rim_col
	hov.border_width_top = 2
	hov.border_width_bottom = 5
	hov.shadow_size = 14
	hov.shadow_color = Color(rim_col.r, rim_col.g, rim_col.b, 0.26)

	var prs := norm.duplicate() as StyleBoxFlat
	prs.bg_color = bg_col.darkened(0.12)
	prs.border_color = top_border
	prs.border_width_top = 4
	prs.border_width_bottom = 2
	prs.shadow_size = 4

	var dis := norm.duplicate() as StyleBoxFlat
	dis.bg_color = bg_col.darkened(0.32)
	dis.border_color = Color(bevel_col.r, bevel_col.g, bevel_col.b, 0.45)
	dis.shadow_size = 2

	btn.add_theme_stylebox_override("normal", norm)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("focus", hov)
	btn.add_theme_stylebox_override("pressed", prs)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.92))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 0.98, 0.92))
	btn.add_theme_color_override("font_disabled_color", Color(0.62, 0.58, 0.56, 0.72))
	btn.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.06, 0.85))
	btn.add_theme_constant_override("outline_size", 3)


## Reference-True 2026 Smoked Bronzed-Obsidian & Double-Gold Filigree Plaque Button
## (Matches ref_02_main_menu.jpg "CONTINUE / NEW JOURNEY / LOAD SAVE / SETTINGS / QUIT" & ref_05 Boutique!).
static func style_gothic_plaque_button(btn: Button, hero: bool = false, kansas: bool = false, font_sz: int = 16) -> void:
	if btn == null:
		return
	var norm_bg := Color(0.14, 0.15, 0.17, 0.94) if kansas else (
		Color(0.215, 0.165, 0.130, 0.95) if hero else Color(0.125, 0.095, 0.125, 0.93)
	)
	var norm_border := KS_BORDER if kansas else (OZ_GOLD_BRIGHT if hero else OZ_BORDER_GOLD)
	var norm := StyleBoxFlat.new()
	norm.bg_color = norm_bg
	norm.border_color = norm_border
	norm.border_width_left = 2
	norm.border_width_right = 2
	norm.border_width_top = 2
	norm.border_width_bottom = 3
	norm.set_corner_radius_all(6)
	norm.content_margin_left = 28
	norm.content_margin_right = 28
	norm.content_margin_top = 11
	norm.content_margin_bottom = 11
	norm.shadow_size = 14 if hero else 8
	norm.shadow_color = Color(0.92, 0.76, 0.38, 0.20) if (hero and not kansas) else Color(0.0, 0.0, 0.0, 0.48)
	norm.shadow_offset = Vector2(0, 3)
	norm.anti_aliasing = true

	var hov := norm.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.24, 0.25, 0.28, 0.98) if kansas else Color(0.285, 0.215, 0.155, 0.98)
	hov.border_color = KS_ACCENT_BRIGHT if kansas else Color(0.98, 0.88, 0.58, 1.0)
	hov.set_border_width_all(2)
	hov.border_width_bottom = 3
	hov.shadow_size = 18
	hov.shadow_color = Color(0.95, 0.96, 1.0, 0.22) if kansas else Color(0.96, 0.80, 0.42, 0.34)

	var prs := norm.duplicate() as StyleBoxFlat
	prs.bg_color = norm_bg.darkened(0.18)
	prs.border_color = hov.border_color
	prs.shadow_size = 4

	var dis := norm.duplicate() as StyleBoxFlat
	dis.bg_color = Color(0.08, 0.07, 0.09, 0.65)
	dis.border_color = Color(norm_border.r, norm_border.g, norm_border.b, 0.32)
	dis.shadow_size = 0

	btn.add_theme_stylebox_override("normal", norm)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("focus", hov)
	btn.add_theme_stylebox_override("pressed", prs)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", KS_TEXT if kansas else Color(0.95, 0.89, 0.78))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.88))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 0.97, 0.88))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.94, 0.78))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.50, 0.48, 0.60))
	btn.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.05, 0.90))
	btn.add_theme_constant_override("outline_size", 3)


static func accent_color(kansas: bool) -> Color:
	return KS_ACCENT_BRIGHT if kansas else OZ_GOLD_BRIGHT


static func text_color(kansas: bool) -> Color:
	return KS_TEXT if kansas else OZ_TEXT


static func muted_text_color(kansas: bool) -> Color:
	return KS_TEXT_MUTED if kansas else OZ_TEXT_MUTED


static func ink_color(kansas: bool) -> Color:
	return KS_INK if kansas else OZ_INK


static func make_button_theme(kansas: bool) -> Theme:
	if kansas and _theme_kansas != null:
		return _theme_kansas
	if not kansas and _theme_oz != null:
		return _theme_oz

	var t := Theme.new()

	var text_col := text_color(kansas)
	var muted_col := muted_text_color(kansas)
	var accent := accent_color(kansas)
	var ink := ink_color(kansas)

	# PanelContainer default
	t.set_stylebox("panel", "PanelContainer", make_modal_style(kansas))

	# Button states
	var btn_normal := _make_box(
		Color(0.13, 0.14, 0.16, 0.90) if kansas else Color(0.14, 0.10, 0.18, 0.90),
		KS_BORDER if kansas else OZ_BORDER_GOLD,
		1, 8, 18, 10, 6, Color(0, 0, 0, 0.35), Vector2(0, 2)
	)
	var btn_hover := _make_box(
		Color(0.22, 0.24, 0.27, 0.96) if kansas else Color(0.24, 0.17, 0.28, 0.96),
		accent,
		2, 8, 18, 10, 10,
		Color(0.95, 0.95, 0.98, 0.18) if kansas else Color(0.98, 0.82, 0.38, 0.25),
		Vector2(0, 3)
	)
	var btn_pressed := _make_box(
		KS_PARCHMENT if kansas else OZ_PARCHMENT,
		accent,
		2, 8, 18, 10, 4, Color(0, 0, 0, 0.3), Vector2(0, 1)
	)
	var btn_focus := _make_box(
		Color(0.18, 0.20, 0.23, 0.95) if kansas else Color(0.20, 0.14, 0.24, 0.95),
		accent,
		2, 8, 18, 10, 10
	)
	t.set_stylebox("normal", "Button", btn_normal)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_stylebox("focus", "Button", btn_focus)
	t.set_color("font_color", "Button", text_col)
	t.set_color("font_hover_color", "Button", accent)
	t.set_color("font_focus_color", "Button", accent)
	t.set_color("font_pressed_color", "Button", ink)
	t.set_font_size("font_size", "Button", 17)

	# Labels
	t.set_color("font_color", "Label", text_col)
	t.set_font_size("font_size", "Label", 16)

	# HSlider
	var slider_bg := _make_box(
		Color(0.22, 0.24, 0.26, 0.85) if kansas else Color(0.20, 0.15, 0.24, 0.85),
		Color(0.5, 0.5, 0.5, 0.3), 1, 4, 4, 4, 0
	)
	var slider_fill := _make_box(accent, accent, 0, 4, 4, 4, 0)
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", slider_fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)

	# CheckButton
	t.set_color("font_color", "CheckButton", text_col)
	t.set_color("font_hover_color", "CheckButton", accent)
	t.set_color("font_pressed_color", "CheckButton", accent)
	t.set_font_size("font_size", "CheckButton", 16)

	# HSeparator
	var sep := StyleBoxFlat.new()
	sep.bg_color = KS_BORDER_SUBTLE if kansas else OZ_BORDER_SUBTLE
	sep.content_margin_top = 1
	sep.content_margin_bottom = 1
	t.set_stylebox("separator", "HSeparator", sep)

	# Muted helper via RichTextLabel
	t.set_color("default_color", "RichTextLabel", muted_col)

	if kansas:
		_theme_kansas = t
	else:
		_theme_oz = t
	return t
