extends Node3D

## 2026 Flagship Character — The Cowardly Lion ("The Burden of Courage")
## Matches char_04_cowardly_lion.jpg & Boutique Couture (lion_classic, lion_primal).
## Soft directional feline fur shader, 22-tuft windswept mane + braided mane locks with gold beads,
## blinking amber eyes with twin catchlights, articulated fanged jaw & twitching ears, 2-segment
## feline legs & 4-toe clawed paws, physics-swaying 2-segment S-tail, courage medal / gilded ruby
## war-harness, rearing roar choreography, and whimsical mane-shake flourish.

@export var outfit_id: String = "lion_classic"

static var _fur_shader: Shader = null

var _body: Node3D
var _head: Node3D
var _mane_piv: Node3D
var _jaw: Node3D
var _ear_l: Node3D
var _ear_r: Node3D
var _eyelid_l: Node3D
var _eyelid_r: Node3D
var _tail_base: Node3D
var _tail_tip: Node3D
var _medal_piv: Node3D
var _leg_fl: Node3D
var _leg_fr: Node3D
var _leg_bl: Node3D
var _leg_br: Node3D

var _phase: float = 0.0
var _idle_t: float = 0.0
var _still_t: float = 0.0
var _speed_amt: float = 0.0
var _roar_t: float = 0.0
var _flourish_t: float = 0.0
var _next_flourish: float = 6.5
var _eye_blink_cd: float = 3.2
var _eye_blink_t: float = 0.0
var _air_vy: float = 0.0
var _on_floor: bool = true
var _land_squash: float = 0.0
var _turn_rate: float = 0.0
var _viseme_open: float = 0.0
var cowering: bool = true
var sleeping: bool = false

const ROAR_DUR := 0.56
const FLOURISH_DUR := 0.76

func _ready() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm and "equipped_outfits" in sm:
		var eq: String = str(sm.equipped_outfits.get("lion", ""))
		if eq != "":
			outfit_id = eq
		if sm.has_signal("state_changed") and not sm.state_changed.is_connected(_on_save_state_changed):
			sm.state_changed.connect(_on_save_state_changed)
	_rebuild_character()

func _on_save_state_changed() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm and "equipped_outfits" in sm:
		var eq: String = str(sm.equipped_outfits.get("lion", ""))
		if eq != "" and eq != outfit_id:
			set_outfit(eq)

func set_outfit(new_outfit_id: String) -> void:
	var clean_id := new_outfit_id.strip_edges()
	if clean_id == "":
		clean_id = "lion_classic"
	outfit_id = clean_id
	_rebuild_character()

func _rebuild_character() -> void:
	for c in get_children():
		c.free()
	_build()
	_apply_pose(0.016)

func play_roar() -> void:
	_roar_t = ROAR_DUR
	_still_t = 0.0

func play_flourish() -> void:
	_flourish_t = FLOURISH_DUR
	_still_t = 0.0

func set_viseme(viseme_id: int, open_amt: float) -> void:
	_viseme_open = clampf(open_amt, 0.0, 1.0)
	if _jaw:
		var mul := 0.42 if viseme_id == 1 else (0.28 if viseme_id == 2 else 0.24)
		_jaw.rotation.x = _viseme_open * mul

func set_cowering(on: bool) -> void:
	cowering = on
	_apply_pose(0.016)

func set_sleeping(on: bool) -> void:
	sleeping = on
	_apply_pose(0.016)

func set_airborne(vel_y: float, floor_flag: bool, turn_vel: float = 0.0) -> void:
	if not _on_floor and floor_flag and _air_vy < -3.5:
		_land_squash = clampf(-_air_vy / 15.0, 0.14, 0.42)
	_air_vy = vel_y
	_on_floor = floor_flag
	_turn_rate = clampf(turn_vel, -8.0, 8.0)

func set_locomotion(horizontal_speed: float, delta: float) -> void:
	_idle_t += delta
	_roar_t = maxf(_roar_t - delta, 0.0)
	_flourish_t = maxf(_flourish_t - delta, 0.0)
	_land_squash = move_toward(_land_squash, 0.0, delta * 3.0)

	_eye_blink_cd -= delta
	if _eye_blink_cd <= 0.0:
		_eye_blink_t = 0.14
		_eye_blink_cd = randf_range(2.8, 5.4)
	if _eye_blink_t > 0.0:
		_eye_blink_t = maxf(_eye_blink_t - delta, 0.0)

	_speed_amt = clampf(horizontal_speed / 5.5, 0.0, 1.85) if not sleeping else 0.0
	if _speed_amt > 0.08:
		_phase += delta * (9.0 + _speed_amt * 6.5)
		_still_t = 0.0
	else:
		_phase = move_toward(_phase, 0.0, delta * 4.5)
		_speed_amt = move_toward(_speed_amt, 0.0, delta * 3.8)
		if not sleeping and not cowering and _on_floor and _roar_t <= 0.0:
			_still_t += delta
			if _still_t >= _next_flourish:
				_still_t = 0.0
				_next_flourish = randf_range(7.0, 11.5)
				_flourish_t = FLOURISH_DUR
	_apply_pose(delta)

func _apply_pose(_delta: float = 0.016) -> void:
	if _leg_fl == null or _body == null:
		return

	# Blinking eyelids
	var blink_u := sin((_eye_blink_t / 0.14) * PI) if _eye_blink_t > 0.0 else 0.0
	if sleeping:
		blink_u = 1.0
	if _eyelid_l and _eyelid_r:
		_eyelid_l.visible = blink_u > 0.05
		_eyelid_r.visible = blink_u > 0.05
		_eyelid_l.scale.y = lerpf(0.15, 1.05, blink_u)
		_eyelid_r.scale.y = lerpf(0.15, 1.05, blink_u)

	if sleeping:
		var breath_s := sin(_idle_t * 1.8) * 0.015
		_body.position = Vector3(0, 0.24 + breath_s, 0)
		_body.rotation = Vector3(0.0, 0.0, 1.38)
		_leg_fl.rotation.x = 0.55
		_leg_fr.rotation.x = 0.35
		_leg_bl.rotation.x = -0.45
		_leg_br.rotation.x = -0.65
		if _head:
			_head.rotation = Vector3(0.25, 0.2, -0.3)
			_head.scale = Vector3.ONE
		if _jaw:
			_jaw.rotation.x = 0.08 + absf(sin(_idle_t * 1.8)) * 0.14
		if _tail_base:
			_tail_base.rotation.y = 0.45
		return

	_body.rotation.z = -_turn_rate * 0.025

	# Priority 1: Rearing Primal Roar Shockwave!
	if _roar_t > 0.0:
		var u := sin((1.0 - _roar_t / ROAR_DUR) * PI)
		_body.position = Vector3(0, 0.58 + 0.36 * u, 0)
		_body.rotation.x = -0.62 * u
		_leg_fl.rotation.x = -1.02 * u
		_leg_fr.rotation.x = -1.02 * u
		_leg_bl.rotation.x = 0.48 * u
		_leg_br.rotation.x = 0.48 * u
		_set_lower(_leg_fl, 0.55 * u)
		_set_lower(_leg_fr, 0.55 * u)
		if _head:
			_head.rotation = Vector3(0.34 * u, 0.0, 0.0)
			_head.scale = Vector3.ONE * (1.0 + 0.10 * u)
		if _mane_piv:
			var ms := 1.0 + 0.16 * u
			_mane_piv.scale = Vector3(ms, ms, ms)
		if _jaw:
			_jaw.rotation.x = 0.62 * u
		if _ear_l and _ear_r:
			_ear_l.rotation.z = 0.45 * u
			_ear_r.rotation.z = -0.45 * u
		if _tail_base:
			_tail_base.rotation.x = -0.35 * u
		return

	if _mane_piv:
		_mane_piv.scale = Vector3.ONE

	# Priority 2: Airborne Feline Pounce Pose
	if not _on_floor and absf(_air_vy) > 1.2:
		_body.position = Vector3(0, 0.60, 0)
		_body.rotation.x = clampf(-_air_vy * 0.045, -0.32, 0.32)
		_leg_fl.rotation.x = -0.68
		_leg_fr.rotation.x = -0.58
		_leg_bl.rotation.x = 0.62
		_leg_br.rotation.x = 0.52
		if _tail_base:
			_tail_base.rotation.x = -0.25
		return

	# Priority 3: Whimsical Mane-Shake & Ear-Twitch Flourish!
	if _flourish_t > 0.0:
		var fu := 1.0 - (_flourish_t / FLOURISH_DUR)
		var farc := sin(fu * PI)
		var shake := sin(fu * PI * 6.0) * farc
		_body.position = Vector3(0, 0.58 + 0.03 * farc, 0)
		_body.rotation.x = -0.06 * farc
		if _head:
			_head.rotation = Vector3(0.08 * farc, shake * 0.24, shake * 0.34)
		if _mane_piv:
			_mane_piv.rotation.z = -shake * 0.22
		if _ear_l and _ear_r:
			_ear_l.rotation.z = shake * 0.28
			_ear_r.rotation.z = -shake * 0.28
		if _tail_base:
			_tail_base.rotation.y = sin(_idle_t * 8.0) * 0.52
		return

	if _mane_piv:
		_mane_piv.rotation.z = 0.0

	# Fluid Feline Stride + Breathing Idle
	var squash := _land_squash * 0.11
	var swing := sin(_phase) * 0.58 * _speed_amt
	var still_blend := 1.0 - clampf(_speed_amt, 0.0, 1.0)

	# Quadrupedal Feline Walk/Trot vs Full Rotary Bounding Gallop when Sprinting!
	var run_blend := clampf((_speed_amt - 1.05) / 0.65, 0.0, 1.0)
	var trot_fl := swing
	var trot_fr := -swing
	var trot_bl := -swing
	var trot_br := swing
	var gal_fl := sin(_phase) * 0.92
	var gal_fr := sin(_phase + 0.32) * 0.92
	var gal_bl := -sin(_phase) * 0.98
	var gal_br := -sin(_phase + 0.32) * 0.98
	_leg_fl.rotation.x = lerpf(trot_fl, gal_fl, run_blend) - _land_squash * 0.28
	_leg_fr.rotation.x = lerpf(trot_fr, gal_fr, run_blend) - _land_squash * 0.28
	_leg_bl.rotation.x = lerpf(trot_bl, gal_bl, run_blend) + _land_squash * 0.24
	_leg_br.rotation.x = lerpf(trot_br, gal_br, run_blend) + _land_squash * 0.24
	_set_lower(_leg_fl, maxf(-_leg_fl.rotation.x, 0.0) * 0.78 + _land_squash * 0.50)
	_set_lower(_leg_fr, maxf(-_leg_fr.rotation.x, 0.0) * 0.78 + _land_squash * 0.50)
	_set_lower(_leg_bl, maxf(_leg_bl.rotation.x, 0.0) * 0.65)
	_set_lower(_leg_br, maxf(_leg_br.rotation.x, 0.0) * 0.65)

	_body.position = Vector3(0, 0.58 - squash + absf(sin(_phase)) * lerpf(0.042, 0.105, run_blend) * minf(_speed_amt, 1.35) + sin(_idle_t * 2.2) * 0.012 * still_blend, 0)
	_body.rotation.x = (0.26 if cowering else 0.0) + lerpf(sin(_phase * 2.0) * 0.045 * _speed_amt, cos(_phase) * 0.16, run_blend)

	if _head:
		_head.scale = Vector3.ONE
		_head.rotation = Vector3(
			sin(_idle_t * 1.7) * 0.04 * still_blend + (-0.18 if cowering else 0.0),
			sin(_idle_t * 0.85) * 0.12 * still_blend - _turn_rate * 0.03,
			0.0
		)
	if _jaw:
		_jaw.rotation.x = _viseme_open * 0.36 if _viseme_open > 0.03 else absf(sin(_idle_t * 2.2)) * 0.06 * (0.4 + _speed_amt * 0.6)
	if _ear_l and _ear_r:
		var cow_ear := 0.36 if cowering else 0.0
		_ear_l.rotation.z = cow_ear + sin(_idle_t * 3.1) * 0.05 * still_blend
		_ear_r.rotation.z = -cow_ear - sin(_idle_t * 2.7) * 0.05 * still_blend
	if _tail_base and _tail_tip:
		_tail_base.rotation.y = sin(_idle_t * 3.8 + _phase) * (0.34 + _speed_amt * 0.22) - _turn_rate * 0.06
		_tail_base.rotation.x = 0.0
		_tail_tip.rotation.y = sin(_idle_t * 3.8 + _phase - 0.8) * 0.42
	if _medal_piv:
		_medal_piv.rotation.x = _speed_amt * 0.25 + sin(_phase * 2.0) * 0.10 * _speed_amt

func _set_lower(leg: Node3D, rx: float) -> void:
	if leg and leg.has_node("Lower"):
		(leg.get_node("Lower") as Node3D).rotation.x = rx

# ============================================================================
# MATERIAL & PRIMITIVE HELPERS
# ============================================================================

func _mat(c: Color, rough: float = 0.82, metal: float = 0.0, emit_col: Color = Color.BLACK, emit_e: float = 0.0, rim_amt: float = 0.25) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if rim_amt > 0.01:
		m.rim_enabled = true
		m.rim = rim_amt
		m.rim_tint = 0.45
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit_col
		m.emission_energy_multiplier = emit_e
	return m

func _mi(p: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	n.rotation_degrees = rot_deg
	n.scale = scl
	p.add_child(n)
	return n

func _cyl(t: float, b: float, h: float, segs: int = 20) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = t
	c.bottom_radius = b
	c.height = h
	c.radial_segments = segs
	return c

func _sph(r: float, segs: int = 20, rings_n: int = 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = rings_n
	return s

func _cap(r: float, h: float, segs: int = 14) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.02)
	c.radial_segments = segs
	return c

func _torus(ir: float, orad: float, rings_n: int = 20) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = ir
	t.outer_radius = orad
	t.rings = rings_n
	return t

# ============================================================================
# 2026 COWARDLY LION GEOMETRY & COUTURE BUILDS
# ============================================================================

func _build() -> void:
	var is_primal := (outfit_id == "lion_primal")
	var fur := _make_fur_material(Color(0.80, 0.56, 0.26), Color(0.58, 0.36, 0.14))
	var fur_belly := _mat(Color(0.92, 0.78, 0.52), 0.86)
	var mane_dark := _make_fur_material(Color(0.46, 0.22, 0.08), Color(0.28, 0.12, 0.04))
	var mane_hi := _make_fur_material(
		Color(0.86, 0.58, 0.20) if is_primal else Color(0.68, 0.38, 0.14),
		Color(0.56, 0.30, 0.09) if is_primal else Color(0.42, 0.20, 0.07)
	)
	var dark := _mat(Color(0.14, 0.09, 0.06), 0.42)
	var leather := _mat(Color(0.24, 0.14, 0.09), 0.48, 0.08)
	var gold := _mat(Color(0.94, 0.76, 0.28), 0.22, 0.92, Color(0.88, 0.68, 0.22), 0.18 if is_primal else 0.06)
	var crimson := _mat(Color(0.76, 0.08, 0.16), 0.42, 0.12, Color(0.88, 0.10, 0.20), 0.35 if is_primal else 0.0)
	var ruby_gem := _mat(Color(0.98, 0.08, 0.20), 0.08, 0.25, Color(1.0, 0.12, 0.24), 2.2)
	var eye_amber := _mat(Color(0.92, 0.62, 0.14), 0.14, 0.05, Color(0.85, 0.52, 0.10), 0.25)
	var pupil := _mat(Color(0.03, 0.02, 0.02), 0.08, 0.0, Color.BLACK, 0.0, 0.0)
	var glint := _mat(Color(1.0, 1.0, 1.0), 0.05, 0.0, Color(1.0, 1.0, 1.0), 1.4, 0.0)
	var fang_m := _mat(Color(0.97, 0.95, 0.88), 0.22)
	var tongue_m := _mat(Color(0.84, 0.34, 0.40), 0.40)

	# ========================================================================
	# 1. MUSCULAR HORIZONTAL FELINE TORSO & HARNESS / PRIMAL WAR-ARMOR
	# ========================================================================
	_body = Node3D.new()
	_body.name = "Body"
	_body.position = Vector3(0, 0.58, 0)
	add_child(_body)

	_mi(_body, _sph(0.31, 24, 14), fur, Vector3(0, 0.09, -0.22), Vector3.ZERO, Vector3(0.96, 0.98, 1.22)) # deep lion ribcage
	_mi(_body, _cyl(0.23, 0.26, 0.58, 22), fur, Vector3(0, 0.07, 0.09), Vector3(90, 0, 0), Vector3(0.90, 1.0, 0.92)) # athletic lumbar waist
	_mi(_body, _sph(0.28, 22, 14), fur, Vector3(0, 0.08, 0.36), Vector3.ZERO, Vector3(0.92, 0.96, 1.15)) # muscular haunches
	_mi(_body, _sph(0.22, 16, 10), fur_belly, Vector3(0, -0.06, 0.05), Vector3.ZERO, Vector3(0.82, 0.62, 1.80))

	# Muscular shoulder & hip contours
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		_mi(_body, _sph(0.155, 16, 10), fur, Vector3(s * 0.21, 0.04, -0.24), Vector3.ZERO, Vector3(0.80, 1.15, 1.08))
		_mi(_body, _sph(0.165, 16, 10), fur, Vector3(s * 0.20, 0.04, 0.34), Vector3.ZERO, Vector3(0.82, 1.18, 1.16))

	# Ornate Harness: Classic Leather Courage-Medal OR Primal Gold Ruby War-Harness (lion_primal.png!)
	_mi(_body, _torus(0.245, 0.280, 24), leather, Vector3(0, 0.07, -0.04), Vector3(90, 0, 0), Vector3(0.96, 1.0, 1.0))
	_mi(_body, _torus(0.255, 0.292, 24), gold if is_primal else leather, Vector3(0, 0.09, -0.29), Vector3(58, 0, 0))

	if is_primal:
		# Primal Gold Harness: Spiked Gold Neck Gorget + Embossed Lion Shoulder Pauldrons + Giant Faceted Ruby!
		for sx in [-1.0, 1.0]:
			var s := float(sx)
			_mi(_body, _sph(0.18, 20, 12), gold, Vector3(s * 0.26, 0.14, -0.26), Vector3(0, s * -16, s * -18), Vector3(0.82, 0.95, 1.15))
			_mi(_body, _torus(0.12, 0.145, 16), crimson, Vector3(s * 0.26, 0.08, -0.26), Vector3(0, 0, s * -18))
		# Spiked golden crown collar behind mane
		for gi in range(5):
			var ga := lerpf(-0.85, 0.85, float(gi) / 4.0)
			_mi(_body, _cyl(0.008, 0.036, 0.14, 8), gold, Vector3(sin(ga) * 0.24, 0.36 + cos(ga) * 0.08, -0.34), Vector3(-22, 0, -rad_to_deg(ga) * 0.5))
		# Giant Glowing Faceted Crimson Ruby Chest Medallion
		_medal_piv = Node3D.new()
		_medal_piv.position = Vector3(0, 0.01, -0.54)
		_body.add_child(_medal_piv)
		_mi(_medal_piv, _torus(0.068, 0.092, 18), gold, Vector3.ZERO, Vector3(90, 0, 0), Vector3(0.95, 1.25, 0.55))
		_mi(_medal_piv, _sph(0.064, 14, 10), ruby_gem, Vector3(0, 0, -0.015), Vector3.ZERO, Vector3(0.85, 1.18, 0.52))
	else:
		# Classic Courage Medal on Crimson Ribbon (char_04_cowardly_lion.jpg!)
		_medal_piv = Node3D.new()
		_medal_piv.position = Vector3(0, 0.02, -0.52)
		_body.add_child(_medal_piv)
		_mi(_medal_piv, _cap(0.026, 0.12, 10), crimson, Vector3(0, -0.03, 0), Vector3.ZERO, Vector3(1.15, 1.0, 0.30))
		_mi(_medal_piv, _cyl(0.056, 0.056, 0.018, 8), gold, Vector3(0, -0.10, -0.015), Vector3(90, 0, 0))
		_mi(_medal_piv, _sph(0.024, 12, 8), crimson, Vector3(0, -0.10, -0.026))

	# ========================================================================
	# 2. SCULPTED LION HEAD, 22-TUFT MANE + BRAIDED LOCKS & EXPRESSIVE FACE
	# ========================================================================
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.25, -0.51)
	_body.add_child(_head)

	# 2-Tier Windswept Mane + Braided Locks with Gold Beads (char_04 inset!)
	_mane_piv = Node3D.new()
	_mane_piv.name = "ManePivot"
	_head.add_child(_mane_piv)
	_mi(_mane_piv, _sph(0.245, 22, 14), mane_dark, Vector3(0, 0.04, 0.08), Vector3.ZERO, Vector3(1.26, 1.26, 1.14))
	for mi_i in range(14):
		var a := float(mi_i) / 14.0 * TAU
		var tmat := mane_hi if mi_i % 2 == 0 else mane_dark
		_mi(_mane_piv, _sph(0.115, 12, 10), tmat, Vector3(cos(a) * 0.27, 0.05 + sin(a) * 0.26, 0.06), Vector3.ZERO, Vector3(1.0, 1.05, 1.22))
	for mi_j in range(8):
		var a2 := float(mi_j) / 8.0 * TAU + 0.25
		_mi(_mane_piv, _sph(0.098, 12, 8), mane_hi, Vector3(cos(a2) * 0.195, 0.06 + sin(a2) * 0.185, -0.03))
	# Twin braided mane locks with antique gold beads hanging beside his neck!
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		for bi in range(3):
			_mi(_mane_piv, _sph(0.028, 10, 8), mane_dark, Vector3(s * 0.24, -0.08 - float(bi) * 0.045, 0.04), Vector3.ZERO, Vector3(0.85, 1.35, 0.85))
		_mi(_mane_piv, _torus(0.014, 0.022, 10), gold, Vector3(s * 0.24, -0.19, 0.04))

	# Noble Lion Cranium, Brow Ridge, Whisker Pads, Whiskers & Velvety Nose
	_mi(_head, _sph(0.175, 22, 14), fur, Vector3(0, 0.03, -0.10), Vector3.ZERO, Vector3(1.02, 0.96, 1.10))
	_mi(_head, _cap(0.042, 0.14, 12), fur, Vector3(0, 0.05, -0.22), Vector3(-72, 0, 0), Vector3(1.15, 1.0, 0.85)) # nasal bridge
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		_mi(_head, _sph(0.082, 14, 10), fur_belly, Vector3(s * 0.056, -0.032, -0.245))
		# 3 delicate sculpted whiskers per cheek
		for wi in range(3):
			_mi(_head, _cap(0.0025, 0.13, 6), fang_m, Vector3(s * 0.125, -0.026 - float(wi) * 0.012, -0.255), Vector3(0, s * -16.0, 88.0 + float(wi - 1) * 10.0 * s))
	_mi(_head, _sph(0.046, 14, 10), dark, Vector3(0, 0.006, -0.315), Vector3.ZERO, Vector3(1.26, 0.72, 0.86))

	# Articulated Lower Jaw with Sculpted White Fangs & Pink Tongue!
	_jaw = Node3D.new()
	_jaw.name = "Jaw"
	_jaw.position = Vector3(0, -0.072, -0.155)
	_head.add_child(_jaw)
	_mi(_jaw, _sph(0.072, 14, 10), fur_belly, Vector3(0, -0.024, -0.095), Vector3.ZERO, Vector3(1.08, 0.62, 1.25))
	_mi(_jaw, _sph(0.042, 10, 8), tongue_m, Vector3(0, -0.006, -0.085), Vector3.ZERO, Vector3(0.95, 0.35, 1.35))
	for sx in [-1.0, 1.0]:
		_mi(_jaw, _cyl(0.004, 0.012, 0.036, 8), fang_m, Vector3(float(sx) * 0.038, 0.016, -0.128))
		_mi(_head, _cyl(0.013, 0.004, 0.040, 8), fang_m, Vector3(float(sx) * 0.044, -0.068, -0.280)) # upper canine fangs

	# Articulated Ears + Blinking Amber-Gold Eyes with Pupils & Twin Catchlights
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		var ear := Node3D.new()
		ear.position = Vector3(s * 0.155, 0.172, -0.035)
		_head.add_child(ear)
		_mi(ear, _sph(0.068, 14, 10), fur, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.92, 0.62))
		_mi(ear, _sph(0.038, 10, 8), dark, Vector3(0, 0, -0.034), Vector3.ZERO, Vector3(0.9, 0.8, 0.45))
		if s < 0:
			_ear_l = ear
		else:
			_ear_r = ear

		var ex := s * 0.074
		var ey := 0.068
		var ez := -0.232
		_mi(_head, _sph(0.032, 14, 10), eye_amber, Vector3(ex, ey, ez))
		_mi(_head, _sph(0.015, 10, 8), pupil, Vector3(ex, ey, ez - 0.022), Vector3.ZERO, Vector3(0.75, 1.05, 0.50))
		_mi(_head, _sph(0.0085, 8, 6), glint, Vector3(ex - s * 0.008, ey + 0.010, ez - 0.028))
		_mi(_head, _sph(0.0045, 6, 6), glint, Vector3(ex + s * 0.007, ey - 0.007, ez - 0.027))

		var lid := Node3D.new()
		lid.position = Vector3(ex, ey + 0.002, ez - 0.004)
		lid.visible = false
		_head.add_child(lid)
		_mi(lid, _sph(0.034, 12, 8), fur, Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 0.95, 0.85))
		if s < 0:
			_eyelid_l = lid
		else:
			_eyelid_r = lid

	# ========================================================================
	# 3. 2-SEGMENT PHYSICS S-TAIL & ARTICULATED 4-TOE CLAWED LEGS
	# ========================================================================
	_tail_base = Node3D.new()
	_tail_base.name = "TailBase"
	_tail_base.position = Vector3(0, 0.14, 0.52)
	_body.add_child(_tail_base)
	_mi(_tail_base, _cyl(0.034, 0.044, 0.34, 12), fur, Vector3(0, -0.05, 0.14), Vector3(68, 0, 0))

	_tail_tip = Node3D.new()
	_tail_tip.name = "TailTip"
	_tail_tip.position = Vector3(0, -0.08, 0.28)
	_tail_base.add_child(_tail_tip)
	_mi(_tail_tip, _cyl(0.024, 0.032, 0.32, 12), fur, Vector3(0, 0.08, 0.13), Vector3(114, 0, 0))
	_mi(_tail_tip, _sph(0.084, 14, 10), mane_dark, Vector3(0, 0.18, 0.28), Vector3.ZERO, Vector3(0.9, 0.92, 1.40))

	_leg_fl = _make_leg(_body, -1.0, -1.0, fur, fur_belly, fang_m)
	_leg_fr = _make_leg(_body, 1.0, -1.0, fur, fur_belly, fang_m)
	_leg_bl = _make_leg(_body, -1.0, 1.0, fur, fur_belly, fang_m)
	_leg_br = _make_leg(_body, 1.0, 1.0, fur, fur_belly, fang_m)

func _make_leg(parent: Node3D, x_sign: float, z_sign: float, fur: Material, belly: Material, claw: Material) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.195 * x_sign, -0.06, 0.28 * z_sign)
	parent.add_child(root)
	_mi(root, _cyl(0.088, 0.066, 0.27, 16), fur, Vector3(0, -0.135, 0))
	_mi(root, _sph(0.066, 14, 10), fur, Vector3(0, -0.27, 0))

	var lower := Node3D.new()
	lower.name = "Lower"
	lower.position = Vector3(0, -0.27, 0)
	root.add_child(lower)
	_mi(lower, _cyl(0.062, 0.048, 0.25, 16), fur, Vector3(0, -0.125, 0))
	# Sculpted 4-toe Lion Paw with Curved Ivory Claws (char_04 inset!)
	_mi(lower, _sph(0.074, 16, 10), belly, Vector3(0, -0.24, -0.035), Vector3.ZERO, Vector3(1.08, 0.62, 1.38))
	for ti in range(4):
		var tx := (float(ti) - 1.5) * 0.034
		_mi(lower, _sph(0.024, 10, 8), fur, Vector3(tx, -0.245, -0.105))
		_mi(lower, _cyl(0.002, 0.009, 0.034, 6), claw, Vector3(tx, -0.255, -0.135), Vector3(72, 0, 0))
	return root

# ============================================================================
# SOFT DIRECTIONAL FELINE FUR SPATIAL SHADER
# ============================================================================

func _make_fur_material(c_light: Color, c_dark: Color) -> ShaderMaterial:
	if _fur_shader == null:
		_fur_shader = Shader.new()
		_fur_shader.code = """
shader_type spatial;
uniform vec4 col_light : source_color = vec4(0.80, 0.56, 0.26, 1.0);
uniform vec4 col_dark : source_color = vec4(0.56, 0.34, 0.14, 1.0);
void fragment() {
	float strand = sin(UV.x * 160.0 + sin(UV.y * 55.0) * 2.0) * 0.5 + 0.5;
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = mix(col_dark.rgb, col_light.rgb, clamp(strand * 0.45 + 0.42 + f * 0.32, 0.0, 1.0));
	ROUGHNESS = 0.84;
	RIM = 0.42;
	RIM_TINT = 0.52;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _fur_shader
	sm.set_shader_parameter("col_light", c_light)
	sm.set_shader_parameter("col_dark", c_dark)
	return sm
