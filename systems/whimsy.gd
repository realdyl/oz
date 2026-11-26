extends Node

## Shared optional side-fun for every level. Same pattern, regional palette.
## Hosts call setup() once in _ready after HUD exists; try_collect on E;
## prompt_if_near() for HUD. Never story-gated.

const WorldKit := preload("res://systems/world_kit.gd")

var points: int = 0
var _near: Area3D = null
var _label: Label = null
var _hud: CanvasLayer = null
var _host: Node3D = null
var _palette: String = "candy"
var _anim_entries: Array[Dictionary] = []
var _anim_t: float = 0.0

func reset_for_level() -> void:
	points = 0
	_near = null
	_label = null
	_hud = null
	_host = null
	_palette = "candy"
	_anim_entries.clear()

func _process(delta: float) -> void:
	if _anim_entries.is_empty():
		return
	_anim_t += delta
	for i in range(_anim_entries.size() - 1, -1, -1):
		var entry: Dictionary = _anim_entries[i]
		var raw_area: Variant = entry.get("area")
		if raw_area == null or not is_instance_valid(raw_area):
			_anim_entries.remove_at(i)
			continue
		var area := raw_area as Node3D
		if area == null or area.get_meta("taken") == true:
			_anim_entries.remove_at(i)
			continue
		var phase_off: float = float(entry.get("off", 0.0))
		var raw_spin: Variant = entry.get("spin")
		if raw_spin != null and is_instance_valid(raw_spin):
			var spin := raw_spin as Node3D
			if spin:
				spin.rotate_y(delta * 1.15)
				spin.position.y = float(entry.get("base_y", 0.82)) + sin(_anim_t * 2.4 + phase_off) * 0.09
		var raw_sway: Variant = entry.get("sway")
		if raw_sway != null and is_instance_valid(raw_sway):
			var sway := raw_sway as Node3D
			if sway:
				sway.rotation.z = sin(_anim_t * 1.9 + phase_off) * 0.09
				sway.rotation.x = cos(_anim_t * 1.4 + phase_off) * 0.06
		var raw_bob: Variant = entry.get("bob")
		if raw_bob != null and is_instance_valid(raw_bob):
			var bob := raw_bob as Node3D
			if bob:
				var s := 1.0 + sin(_anim_t * 2.8 + phase_off) * 0.035
				bob.scale = Vector3(s, 2.0 - s, s)

func setup(host: Node3D, hud: CanvasLayer, spots: Array, palette: String = "candy") -> void:
	reset_for_level()
	_host = host
	_hud = hud
	_palette = palette
	_ensure_hud()
	for s in spots:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var pos: Vector3 = s.get("pos", Vector3.ZERO)
		var kind: String = str(s.get("kind", "giggle"))
		var title: String = str(s.get("name", "Whimsy"))
		_spawn(pos, kind, title)

func try_collect(actor: Node3D) -> bool:
	if _near == null or not is_instance_valid(_near):
		return false
	if _near.get_meta("taken") == true:
		return false
	_collect(_near, actor)
	return true

func prompt_if_near() -> String:
	if _near == null or not is_instance_valid(_near):
		return ""
	if _near.get_meta("taken") == true:
		return ""
	return "E  —  %s (+whimsy)" % str(_near.get_meta("title"))

func _ensure_hud() -> void:
	if _hud == null:
		return
	_label = _hud.get_node_or_null("WhimsyScore") as Label
	if _label == null:
		_label = Label.new()
		_label.name = "WhimsyScore"
		_label.position = Vector2(16, 128)
		_label.add_theme_font_size_override("font_size", 16)
		_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.9))
		_hud.add_child(_label)
	_refresh()

func _refresh() -> void:
	if _label:
		var tier := _blessing_tier()
		if tier == "":
			_label.text = "Whimsy  %d / 25" % points
		else:
			_label.text = "Whimsy  %d  ·  ★ %s" % [points, tier]

func _blessing_tier() -> String:
	if points >= 75:
		return "Silver Trail"
	if points >= 50:
		return "Bonded Courage"
	if points >= 25:
		return "Swift Heels"
	return ""

func _apply_blessing_boons() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and "blink_distance" in player and points >= 25:
		var base_d: float = 5.0 if bool(player.get("shoes_claimed")) else 3.3
		player.set("blink_distance", maxf(float(player.get("blink_distance")), base_d * 1.15))

func _colors(kind: String) -> Dictionary:
	# albedo, emission — per palette + kind
	match _palette:
		"kansas":
			match kind:
				"bounce":
					return {"a": Color(0.55, 0.55, 0.58), "e": Color(0.7, 0.7, 0.75)}
				"giggle":
					return {"a": Color(0.62, 0.62, 0.55), "e": Color(0.75, 0.75, 0.6)}
				"chime":
					return {"a": Color(0.5, 0.52, 0.58), "e": Color(0.65, 0.7, 0.8)}
				_:
					return {"a": Color(0.48, 0.48, 0.5), "e": Color(0.6, 0.6, 0.65)}
		"winkie":
			match kind:
				"bounce":
					return {"a": Color(0.7, 0.25, 0.15), "e": Color(0.9, 0.35, 0.12)}
				"giggle":
					return {"a": Color(0.85, 0.45, 0.2), "e": Color(1.0, 0.5, 0.15)}
				"chime":
					return {"a": Color(0.55, 0.35, 0.55), "e": Color(0.7, 0.4, 0.75)}
				_:
					return {"a": Color(0.6, 0.2, 0.25), "e": Color(0.8, 0.25, 0.3)}
		"emerald":
			match kind:
				"bounce":
					return {"a": Color(0.25, 0.85, 0.45), "e": Color(0.3, 1.0, 0.5)}
				"giggle":
					return {"a": Color(0.55, 0.95, 0.4), "e": Color(0.6, 1.0, 0.45)}
				"chime":
					return {"a": Color(0.4, 0.9, 0.75), "e": Color(0.45, 1.0, 0.85)}
				_:
					return {"a": Color(0.35, 0.8, 0.55), "e": Color(0.4, 0.95, 0.6)}
		"glinda":
			match kind:
				"bounce":
					return {"a": Color(0.95, 0.55, 0.75), "e": Color(1.0, 0.6, 0.8)}
				"giggle":
					return {"a": Color(1.0, 0.85, 0.55), "e": Color(1.0, 0.9, 0.5)}
				"chime":
					return {"a": Color(0.75, 0.7, 1.0), "e": Color(0.8, 0.75, 1.0)}
				_:
					return {"a": Color(0.9, 0.5, 0.85), "e": Color(1.0, 0.55, 0.9)}
		_: # candy / munchkin
			match kind:
				"bounce":
					return {"a": Color(0.95, 0.35, 0.55), "e": Color(0.9, 0.3, 0.5)}
				"giggle":
					return {"a": Color(0.95, 0.85, 0.3), "e": Color(1.0, 0.9, 0.4)}
				"chime":
					return {"a": Color(0.6, 0.9, 1.0), "e": Color(0.5, 0.85, 1.0)}
				_:
					return {"a": Color(0.85, 0.55, 0.95), "e": Color(0.7, 0.4, 0.9)}

func _spawn(at: Vector3, kind: String, title: String) -> void:
	if _host == null:
		return
	var area := Area3D.new()
	area.name = "Whimsy_%s" % kind
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.set_meta("kind", kind)
	area.set_meta("title", title)
	area.set_meta("taken", false)
	area.set_meta("perfumed", false)
	area.add_to_group("whimsies")
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.6
	col.shape = sph
	area.add_child(col)
	_host.add_child(area)
	area.global_position = at + Vector3(0, 0.05, 0)
	var anim: Dictionary = WorldKit.build_whimsy_visual(area, kind, _palette)
	if not anim.is_empty():
		anim["area"] = area
		anim["off"] = float(_anim_entries.size()) * 1.37
		if anim.has("spin"):
			anim["base_y"] = (anim["spin"] as Node3D).position.y
		_anim_entries.append(anim)
	var badge_col := Color(0.95, 0.95, 0.98) if _palette == "kansas" else Color(1.0, 0.90, 0.95)
	WorldKit.make_world_badge(area, Vector3(0, 2.25 if kind == "chime" else 1.75, 0), "✦  %s" % title, badge_col, 10.0)
	area.body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group("player") or b.is_in_group("party"):
			if area.get_meta("taken") != true:
				_near = area
	)
	area.body_exited.connect(func(b: Node3D) -> void:
		if (b.is_in_group("player") or b.is_in_group("party")) and _near == area:
			_near = null
	)

func perfume_near(origin: Vector3, radius: float = 7.5) -> int:
	var count := 0
	for w in get_tree().get_nodes_in_group("whimsies"):
		if not (w is Area3D) or not is_instance_valid(w):
			continue
		var area := w as Area3D
		if area.get_meta("taken") == true or area.get_meta("perfumed") == true:
			continue
		if area.global_position.distance_to(origin) <= radius:
			area.set_meta("perfumed", true)
			count += 1
			var fx := get_node_or_null("/root/CombatFx")
			if fx and fx.has_method("label"):
				fx.call("label", area, area.global_position + Vector3(0, 1.35, 0), "♥ PERFUMED · 2× WHIMSY!", Color(0.98, 0.52, 0.94))
	return count

func smash_collect_near(origin: Vector3, forward: Vector3, max_dist: float, actor: Node3D) -> int:
	var count := 0
	var fwd := forward
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.05 else Vector3.FORWARD
	for w in get_tree().get_nodes_in_group("whimsies"):
		if not (w is Area3D) or not is_instance_valid(w):
			continue
		var area := w as Area3D
		if area.get_meta("taken") == true:
			continue
		var delta := area.global_position - origin
		delta.y = 0.0
		var d := delta.length()
		if d <= max_dist and (d < 2.2 or delta.normalized().dot(fwd) > 0.32):
			_collect(area, actor)
			count += 1
	return count

func _collect(area: Area3D, actor: Node3D) -> void:
	area.set_meta("taken", true)
	var kind := str(area.get_meta("kind"))
	var is_perfumed: bool = (area.get_meta("perfumed", false) == true)
	var pts := 5
	match kind:
		"bounce":
			pts = 8
			if actor is CharacterBody3D:
				(actor as CharacterBody3D).velocity.y = 9.5
			if _hud and _hud.has_method("set_prompt"):
				_hud.set_prompt("Boing! +%d whimsy" % pts)
		"giggle":
			pts = 6
			if _hud and _hud.has_method("set_prompt"):
				_hud.set_prompt("*giggle* +%d whimsy" % pts)
			var d := get_node_or_null("/root/DialogueUI")
			if d and d.has_method("say"):
				d.say("Whimsy", "Hee-hee!", true, 1.2)
		"chime":
			pts = 7
			if _hud and _hud.has_method("set_prompt"):
				_hud.set_prompt("Ting-a-ling! +%d whimsy" % pts)
		"dance":
			pts = 10
			if _hud and _hud.has_method("set_prompt"):
				_hud.set_prompt("You spin a little. +%d whimsy" % pts)
		_:
			pts = 5
	if is_perfumed:
		pts *= 2
		if _hud and _hud.has_method("set_prompt"):
			_hud.set_prompt("♥ Perfumed Bonus! +%d whimsy (2×!)" % pts)
	var old_tier := _blessing_tier()
	points += pts
	_refresh()
	_apply_blessing_boons()
	var new_tier := _blessing_tier()
	if new_tier != old_tier and new_tier != "" and _hud and _hud.has_method("show_toast"):
		_hud.call("show_toast", "★ Road's Blessing Unlocked: %s!" % new_tier, 3.4)

	# Interactive 3D pickup celebration instead of popping invisible instantly
	var fx := get_node_or_null("/root/CombatFx")
	if fx and fx.has_method("ring"):
		fx.call("ring", area, area.global_position, Color(1.0, 0.86, 0.42), 1.6, 0.42)
		if fx.has_method("flash_sphere"):
			fx.call("flash_sphere", area, area.global_position + Vector3(0, 0.5, 0), Color(1.0, 0.90, 0.65), 0.55, 0.25)

	area.monitoring = false
	if _near == area:
		_near = null
	if DisplayServer.get_name() in ["headless", "Dummy"]:
		area.visible = false
		return
	var tw := area.create_tween()
	tw.set_parallel(true)
	tw.tween_property(area, "scale", Vector3(1.45, 0.65, 1.45), 0.12)
	tw.chain().tween_property(area, "position:y", area.position.y + 1.35, 0.35).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(area, "rotation:y", area.rotation.y + TAU, 0.35)
	tw.parallel().tween_property(area, "scale", Vector3(0.05, 0.05, 0.05), 0.35)
	tw.chain().tween_callback(func(): area.visible = false)
