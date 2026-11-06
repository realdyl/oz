extends Node

## Shared optional side-fun for every level. Same pattern, regional palette.
## Hosts call setup() once in _ready after HUD exists; try_collect on E;
## prompt_if_near() for HUD. Never story-gated.

var points: int = 0
var _near: Area3D = null
var _label: Label = null
var _hud: CanvasLayer = null
var _host: Node3D = null
var _palette: String = "candy"

func reset_for_level() -> void:
	points = 0
	_near = null
	_label = null
	_hud = null
	_host = null
	_palette = "candy"

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
		_label.text = "Whimsy  %d" % points

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
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.6
	col.shape = sph
	area.add_child(col)
	_host.add_child(area)
	area.global_position = at + Vector3(0, 0.2, 0)
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	var cols: Dictionary = _colors(kind)
	mat.albedo_color = cols["a"]
	mat.emission = cols["e"]
	mat.emission_energy_multiplier = 0.7
	match kind:
		"bounce":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.55
			cyl.bottom_radius = 0.75
			cyl.height = 0.55
			mi.mesh = cyl
			mi.position = Vector3(0, 0.3, 0)
		"giggle":
			var sphm := SphereMesh.new()
			sphm.radius = 0.35
			sphm.height = 0.7
			mi.mesh = sphm
			mi.position = Vector3(0, 0.6, 0)
		"chime":
			var box := BoxMesh.new()
			box.size = Vector3(0.25, 1.4, 0.25)
			mi.mesh = box
			mi.position = Vector3(0, 0.9, 0)
		_:
			var tor := TorusMesh.new()
			tor.inner_radius = 0.9
			tor.outer_radius = 1.2
			mi.mesh = tor
			mi.position = Vector3(0, 0.15, 0)
	mi.material_override = mat
	area.add_child(mi)
	var lab := Label3D.new()
	lab.text = title
	lab.font_size = 36
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(1, 0.9, 0.95)
	lab.position = Vector3(0, 1.8, 0)
	area.add_child(lab)
	area.body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group("player") or b.is_in_group("party"):
			if area.get_meta("taken") != true:
				_near = area
	)
	area.body_exited.connect(func(b: Node3D) -> void:
		if (b.is_in_group("player") or b.is_in_group("party")) and _near == area:
			_near = null
	)

func _collect(area: Area3D, actor: Node3D) -> void:
	area.set_meta("taken", true)
	var kind := str(area.get_meta("kind"))
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
	points += pts
	_refresh()
	area.visible = false
	area.monitoring = false
	if _near == area:
		_near = null
