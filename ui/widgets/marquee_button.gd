extends Button
class_name MarqueeButton

## Fixed-width gothic plaque button whose label smoothly ping-pongs
## right-to-left -> pause -> left-to-right whenever text exceeds the button width,
## eliminating horizontal scrollbars inside Chapter Select & fixed-size menus.

var marquee_text: String = ""
var _clip: Control
var _lbl: Label
var _dir: float = -1.0
var _pause_t: float = 1.0
var _offset_x: float = 0.0
var _scroll_speed: float = 42.0

func setup_marquee(p_text: String, font_size: int = 14, col: Color = Color(0.95, 0.90, 0.78)) -> void:
	marquee_text = p_text
	text = ""
	clip_contents = true
	if _clip == null:
		_clip = Control.new()
		_clip.name = "MarqueeClip"
		_clip.clip_contents = true
		_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clip.set_anchors_preset(Control.PRESET_FULL_RECT)
		_clip.offset_left = 18.0
		_clip.offset_right = -18.0
		add_child(_clip)
	if _lbl == null:
		_lbl = Label.new()
		_lbl.name = "MarqueeLabel"
		_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_clip.add_child(_lbl)
	_lbl.text = marquee_text
	_lbl.add_theme_font_size_override("font_size", font_size)
	_lbl.add_theme_color_override("font_color", col)
	_lbl.size = Vector2(_lbl.get_minimum_size().x, maxf(size.y, 38.0))
	_offset_x = 0.0
	_dir = -1.0
	_pause_t = 1.0

func _process(delta: float) -> void:
	if _clip == null or _lbl == null or not is_visible_in_tree():
		return
	if DisplayServer.get_name() in ["headless", "Dummy"]:
		return
	var clip_w := _clip.size.x
	var clip_h := _clip.size.y
	if clip_w <= 10.0:
		return
	var text_w := _lbl.get_minimum_size().x
	_lbl.size = Vector2(maxf(text_w, clip_w), clip_h)
	var overflow := text_w - clip_w
	if overflow <= 4.0:
		_lbl.position = Vector2(0.0, 0.0)
		return
	if _pause_t > 0.0:
		_pause_t -= delta
		_lbl.position = Vector2(_offset_x, 0.0)
		return
	_offset_x += _dir * _scroll_speed * delta
	if _offset_x <= -overflow:
		_offset_x = -overflow
		_dir = 1.0
		_pause_t = 1.15
	elif _offset_x >= 0.0:
		_offset_x = 0.0
		_dir = -1.0
		_pause_t = 1.15
	_lbl.position = Vector2(_offset_x, 0.0)
