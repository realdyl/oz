extends RefCounted

## Central 2026 design-system factory for Oz: The Road Home.
## Generates cached high-DPI StyleBoxFlat styles and Themes for both
## Oz Storybook (warm parchment + antique gold + deep plum glass) and
## Kansas Prairie (austere film-noir slate + silver-ash monochrome).

static var _theme_oz: Theme = null
static var _theme_kansas: Theme = null

# --- Color Tokens: Oz Storybook ---
const OZ_SURFACE := Color(0.08, 0.06, 0.10, 0.86)
const OZ_SURFACE_DEEP := Color(0.06, 0.04, 0.08, 0.94)
const OZ_BORDER_GOLD := Color(0.84, 0.69, 0.36, 0.72)
const OZ_BORDER_SUBTLE := Color(0.84, 0.69, 0.36, 0.30)
const OZ_PARCHMENT := Color(0.96, 0.92, 0.84, 0.96)
const OZ_INK := Color(0.16, 0.09, 0.14, 1.0)
const OZ_TEXT := Color(0.97, 0.95, 0.90, 1.0)
const OZ_TEXT_MUTED := Color(0.76, 0.72, 0.66, 0.92)
const OZ_GOLD_BRIGHT := Color(0.98, 0.82, 0.38, 1.0)
const OZ_FINAL_SURFACE := Color(0.20, 0.05, 0.10, 0.94)
const OZ_FINAL_BORDER := Color(0.98, 0.82, 0.38, 0.95)
const OZ_KEYCAP_BG := Color(0.95, 0.90, 0.80, 0.98)
const OZ_KEYCAP_BEVEL := Color(0.65, 0.54, 0.34, 1.0)
const OZ_THREAT := Color(0.92, 0.28, 0.34, 1.0)
const OZ_MARSHAL := Color(0.98, 0.76, 0.28, 1.0)

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
				KS_FINAL_SURFACE, KS_FINAL_BORDER, 2, 8, 18, 12, 16,
				Color(0.92, 0.92, 0.96, 0.25), Vector2(0, 4)
			)
		return _make_box(
			OZ_FINAL_SURFACE, OZ_FINAL_BORDER, 2, 8, 18, 12, 18,
			Color(0.98, 0.80, 0.32, 0.32), Vector2(0, 4)
		)
	if kansas:
		return _make_box(KS_SURFACE, KS_BORDER, 1, 6, 16, 10, 12)
	return _make_box(OZ_SURFACE, OZ_BORDER_GOLD, 2, 8, 16, 10, 14)


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
			KS_SURFACE_DEEP, KS_BORDER, 2, 10, 28, 24, 24,
			Color(0.0, 0.0, 0.0, 0.65), Vector2(0, 8)
		)
	return _make_box(
		OZ_SURFACE_DEEP, OZ_BORDER_GOLD, 2, 12, 28, 24, 28,
		Color(0.0, 0.0, 0.0, 0.70), Vector2(0, 10)
	)


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
