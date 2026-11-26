extends CharacterBody3D


## Dorothy. Feet at the origin. The camera lives on this body so Play
## works without wiring a separate rig.
##
## The Shoes are silver (book canon). Blink and kick work before the claim
## so the first minute is playable; claiming them lengthens the blink.

@export var move_speed: float = 5.4
@export var acceleration: float = 18.0
@export var friction: float = 14.0
@export var gravity: float = 24.0

@export var blink_distance: float = 3.3
@export var blink_cooldown: float = 0.42
@export var iframe_time: float = 0.18

@export var kick_damage: int = 10
@export var kick_cooldown: float = 0.5
@export var kick_range: float = 1.15

@export var mouse_sensitivity: float = 0.0028
@export var follow_distance: float = 2.2
@export var step_height: float = 1.15

var blink_timer: float = 0.0
var _sprint_surge_t: float = 0.0
var _sprint_surge_dir: Vector3 = Vector3.ZERO
var kick_timer: float = 0.0
var kick_active: float = 0.0
var iframe_timer: float = 0.0
var stun_timer: float = 0.0
var shoes_claimed: bool = false
var looking: bool = false
var leading: bool = true
var follow_target: Node3D = null
## Level scripts park her (asleep / safe south) so she does not trail Lead back into danger.
var parked: bool = false
var park_pos: Vector3 = Vector3.ZERO

# Phase P7 / P1.4: 3-Hit Combo, 5 Selectable Z/X/C Armaments (including Silver Heel-Click!) & Rapture Mode (H)
const ARMAMENT_NAMES := ["Lace Whip", "Silk Bindings", "Hypnotic Perfume", "Gilded Chain", "Silver Heel-Click"]
var _armament_idx: int = 0
var _armament_cd: float = 0.0
var _combo_step: int = 0
var _combo_reset_t: float = 0.0
var _rapture_t: float = 0.0
var _prev_vis_yaw: float = 0.0

@onready var visual: Node3D = $Visual
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var body: Node3D = $Visual/Body

func _ready() -> void:
	add_to_group("player")
	add_to_group("party")
	floor_snap_length = 0.3
	# Godot 4 SpringArm places children along local +Z. Enable Layer 1 collision + floor-safe pitch.
	spring_arm.collision_mask = 1
	spring_arm.margin = 0.24
	if spring_arm.shape == null:
		var cam_sph := SphereShape3D.new()
		cam_sph.radius = 0.22
		spring_arm.shape = cam_sph
	spring_arm.add_excluded_object(get_rid())
	_set_arm_pitch(-18.0)
	looking = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Party.register(Party.ID_DOROTHY, self, true)
	set_leading(true)
	var sm_r := get_node_or_null("/root/SaveManager")
	if sm_r:
		if sm_r.has_signal("state_changed") and not sm_r.state_changed.is_connected(_sync_whip_visibility):
			sm_r.state_changed.connect(_sync_whip_visibility)
		if bool(sm_r.get("resume_pending_apply")):
			sm_r.set("resume_pending_apply", false)
			var rp: Vector3 = sm_r.get("resume_player_pos")
			if rp != Vector3.ZERO:
				call_deferred("set_global_position", rp)
	call_deferred("_sync_whip_visibility")

func set_leading(on: bool) -> void:
	leading = on
	follow_target = null if on else Party.follow_body()

func set_player_controlled(on: bool) -> void:
	set_leading(on)

func set_parked(on: bool, pos: Vector3 = Vector3.ZERO) -> void:
	parked = on
	if on:
		if pos != Vector3.ZERO:
			park_pos = pos
			global_position = pos
		else:
			park_pos = global_position
		velocity = Vector3.ZERO
		follow_target = null
	else:
		park_pos = Vector3.ZERO
		set_sleeping(false)

func set_sleeping(on: bool) -> void:
	if body and body.has_method("set_sleeping"):
		body.call("set_sleeping", on)

func can_take_lead() -> bool:
	return not parked

func _set_arm_pitch(pitch_deg: float) -> void:
	if spring_arm and is_instance_valid(spring_arm):
		spring_arm.rotation_degrees = Vector3(pitch_deg, 0.0, 0.0)

func wants_look_hint() -> bool:
	return not Party.looking

func _physics_process(delta: float) -> void:
	blink_timer = maxf(blink_timer - delta, 0.0)
	_sprint_surge_t = maxf(_sprint_surge_t - delta, 0.0)
	kick_timer = maxf(kick_timer - delta, 0.0)
	kick_active = maxf(kick_active - delta, 0.0)
	iframe_timer = maxf(iframe_timer - delta, 0.0)
	stun_timer = maxf(stun_timer - delta, 0.0)
	_armament_cd = maxf(_armament_cd - delta, 0.0)
	if _combo_reset_t > 0.0:
		_combo_reset_t = maxf(_combo_reset_t - delta, 0.0)
		if _combo_reset_t <= 0.0:
			_combo_step = 0
	if _rapture_t > 0.0:
		_rapture_t = maxf(_rapture_t - delta, 0.0)
		iframe_timer = maxf(iframe_timer, 0.2)
		if _rapture_t <= 0.0:
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("set_rapture_visual"):
				hud.call("set_rapture_visual", false)

	# Anti-oblivion safety net
	if global_position.y < -3.5:
		global_position = Vector3(clampf(global_position.x, -30.0, 30.0), 0.25, clampf(global_position.z, -50.0, 120.0))
		velocity = Vector3.ZERO

	if parked:
		global_position = Vector3(park_pos.x, global_position.y, park_pos.z)
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = -0.5
		_animate_visual(delta)
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5

	# When a companion leads, Dorothy trails — and still fights on her own.
	if not leading:
		_ally_or_follow(delta)
		_animate_visual(delta)
		move_and_slide()
		return

	var locked := kick_active > 0.0 or stun_timer > 0.0
	if not locked:
		_move(delta)
		if Input.is_action_just_pressed("blink") and blink_timer <= 0.0:
			_blink()
		elif Input.is_action_just_pressed("kick") and kick_timer <= 0.0:
			_kick()
		elif Input.is_action_just_pressed("summon"):
			print("No one answers yet.")
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)

	_animate_visual(delta)
	move_and_slide()

func _ally_or_follow(delta: float) -> void:
	var foe: Node3D = Party.nearest_enemy(self, 16.0) if Party else null
	var lead := Party.follow_body() if Party else null
	var leash_ok := true
	if lead and is_instance_valid(lead) and lead != self and foe:
		if global_position.distance_to(lead.global_position) > 26.0 \
				and foe.global_position.distance_to(lead.global_position) > 20.0:
			leash_ok = false
	if foe and leash_ok and stun_timer <= 0.0:
		_ally_fight(delta, foe)
	else:
		_follow_lead(delta)

func _ally_fight(delta: float, foe: Node3D) -> void:
	var to := foe.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var hold := kick_range + 0.15
	if kick_active > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
		return
	if dist > 0.05:
		var dir := to / dist
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)
		if dist > hold:
			var steered: Vector3 = Locomotion.steer(self, dir)
			if steered.length() > 0.05:
				velocity.x = steered.x * move_speed * 0.95
				velocity.z = steered.z * move_speed * 0.95
				Locomotion.try_step(self, steered, step_height)
			else:
				velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
				velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
			if kick_timer <= 0.0:
				_kick()
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)

func _follow_lead(delta: float) -> void:
	follow_target = Party.follow_body()
	if follow_target == null or follow_target == self:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
		return
	var to := follow_target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > follow_distance:
		var dir := to / dist
		var steered: Vector3 = Locomotion.steer(self, dir)
		if steered.length() > 0.05:
			velocity.x = steered.x * move_speed * 0.95
			velocity.z = steered.z * move_speed * 0.95
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-steered.x, -steered.z), 10.0 * delta)
			Locomotion.try_step(self, steered, step_height)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)

func _camera_basis() -> Basis:
	var node := Party.camera_basis_node()
	if node:
		return node.global_transform.basis
	if camera_pivot and is_instance_valid(camera_pivot):
		return camera_pivot.global_transform.basis
	return global_transform.basis

func _move(delta: float) -> void:
	# RMB steals WASD/arrows for camera orbit (Party)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * move_speed)
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish := Vector3.ZERO
	if input.length() > 0.05:
		wish = (_camera_basis() * Vector3(input.x, 0.0, input.y))
		wish.y = 0.0
		if wish.length() > 0.01:
			wish = wish.normalized()
			var face := atan2(-wish.x, -wish.z)
			visual.rotation.y = lerp_angle(visual.rotation.y, face, 12.0 * delta)
	var cur_speed := move_speed * (1.85 if Locomotion.is_sprinting() else 1.0)
	if _sprint_surge_t > 0.0:
		# Smooth high-speed sprint burst via move_and_slide() (never a single-frame teleport!)
		var surge_spd := maxf(blink_distance / 0.10, 34.0)
		velocity.x = _sprint_surge_dir.x * surge_spd
		velocity.z = _sprint_surge_dir.z * surge_spd
		Locomotion.try_step(self, _sprint_surge_dir, step_height)
		return
	if wish.length() > 0.05:
		var steered: Vector3 = Locomotion.steer(self, wish)
		if steered.length() < 0.05:
			steered = wish
		velocity.x = move_toward(velocity.x, steered.x * cur_speed, acceleration * delta * cur_speed)
		velocity.z = move_toward(velocity.z, steered.z * cur_speed, acceleration * delta * cur_speed)
		Locomotion.try_step(self, steered, step_height)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta * move_speed)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta * move_speed)

func _try_step(dir: Vector3) -> void:
	Locomotion.try_step(self, dir, step_height)

func _blink() -> void:
	var sm_b := get_node_or_null("/root/SaveManager")
	var sov_fast := 0.85 if (sm_b and str(sm_b.equipped_outfits.get("dorothy", "")) == "dorothy_sovereign") else 1.0
	if sm_b and sm_b.has_method("has_charm") and bool(sm_b.call("has_charm", "charm_winged_cap")):
		sov_fast *= 0.75
	blink_timer = blink_cooldown * sov_fast
	iframe_timer = iframe_time + 0.08
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var dir := Vector3.ZERO
	if input.length() > 0.05:
		dir = _camera_basis() * Vector3(input.x, 0.0, input.y)
		dir.y = 0.0
		if dir.length() > 0.01:
			dir = dir.normalized()
	else:
		dir = -visual.global_transform.basis.z
		dir.y = 0.0
		if dir.length() < 0.01:
			return
		dir = dir.normalized()
	_sprint_surge_dir = dir
	_sprint_surge_t = 0.10
	var dep_pos := global_position
	var dep_yaw := visual.rotation.y
	var burst_spd := maxf(blink_distance / 0.10, 34.0)
	velocity.x = dir.x * burst_spd
	velocity.z = dir.z * burst_spd
	if is_on_floor():
		velocity.y = 7.4 # physical hop onto curbs/platforms!
	visual.rotation.y = atan2(-dir.x, -dir.z)
	if body and body.has_method("play_blink"):
		body.call("play_blink")
	if CombatFx.has_method("blink_afterimage"):
		CombatFx.blink_afterimage(self, dep_pos, dir, dep_yaw)
	# Phase P4.3: "Silver Mirage" Perfect Blink-Dodge when dodging right near an active threat!
	var near_foes := _find_live_enemies(3.6)
	if not near_foes.is_empty() and DisplayServer.get_name() not in ["headless", "Dummy"]:
		CombatFx.ring(self, dep_pos, Color(0.86, 0.95, 1.0), 2.8, 0.36)
		CombatFx.label(self, dep_pos + Vector3(0, 0.6, 0), "✦ SILVER MIRAGE!", Color(0.88, 0.96, 1.0))
		for nf in near_foes:
			if nf.has_method("apply_bind"):
				nf.call("apply_bind", 1.4)
		if sm_b:
			if sm_b.has_method("register_style_action"):
				sm_b.call("register_style_action", 26.0, "Silver Mirage")
			if sm_b.has_method("add_desire"):
				sm_b.add_desire(4, "Silver Mirage Dodge")

func _blink_destination(dir: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0, 0.7, 0)
	var travel := dir * blink_distance
	var query := PhysicsRayQueryParameters3D.create(origin, origin + travel, 1)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	var dest := global_position + travel
	if hit:
		var hit_pos: Vector3 = hit.position
		dest = hit_pos - dir * 0.45
		dest.y = global_position.y
		var above: Vector3 = hit_pos + Vector3(0, 1.35, 0) - dir * 0.15
		var down := PhysicsRayQueryParameters3D.create(above, above + Vector3(0, -1.8, 0), 1)
		down.exclude = [get_rid()]
		var top := space.intersect_ray(down)
		if top and top.position.y - global_position.y <= 1.25 and top.position.y >= global_position.y - 0.2:
			dest = top.position + Vector3(0, 0.05, 0)
	else:
		var drop_from := dest + Vector3(0, 1.4, 0)
		var drop := PhysicsRayQueryParameters3D.create(drop_from, drop_from + Vector3(0, -3.0, 0), 1)
		drop.exclude = [get_rid()]
		var ground := space.intersect_ray(drop)
		if ground:
			dest.y = ground.position.y + 0.05
	return dest

func _kick() -> void:
	kick_timer = kick_cooldown
	kick_active = 0.22
	# 3-Hit Melee Combo: Hit 1 = 10 (keeps sim contract green!), Hit 2 = 14, Hit 3 Finisher = 22!
	_combo_step = (_combo_step % 3) + 1
	_combo_reset_t = 1.35
	var step_dmg := kick_damage if _combo_step == 1 else (14 if _combo_step == 2 else 22)
	if _rapture_t > 0.0:
		step_dmg = int(float(step_dmg) * 2.5)
	var forward := -visual.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = -global_transform.basis.z
	forward = forward.normalized()
	# Choreographed 3-Stage Martial Arts Stiletto Kicks + Combo Arcs!
	if body and body.has_method("play_combo_kick"):
		body.call("play_combo_kick", _combo_step)
	elif body and body.has_method("play_kick"):
		body.call("play_kick")
	if _combo_step == 3 and CombatFx.has_method("combo_finisher_burst"):
		CombatFx.combo_finisher_burst(self, global_position, forward)
	elif CombatFx.has_method("kick_arc"):
		CombatFx.kick_arc(self, global_position, forward)
	else:
		CombatFx.slash_box(self, global_position, forward, Color(0.85, 0.9, 1.0), Vector3(0.95, 0.22, 1.2), 0.16)
	CombatFx.flash_sphere(self, global_position + Vector3(0, 0.7, 0) + forward * 0.95, Color(0.98, 0.35, 0.58) if _rapture_t > 0.0 else Color(0.92, 0.96, 1.0), 0.38 + float(_combo_step) * 0.08, 0.14)
	var afx := get_node_or_null("/root/AudioFx")
	if afx and afx.has_method("play"):
		afx.play("kick", -6.0)
	var lbl_txt := "KICK" if _combo_step == 1 else ("HEEL SWEEP ×2" if _combo_step == 2 else "✦ FINISHER ×3")
	CombatFx.label(self, global_position, lbl_txt, Color(1.0, 0.38, 0.62) if _combo_step == 3 else Color(0.95, 0.95, 1.0))
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.55 + (0.25 if _combo_step == 3 else 0.0)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = 4
	params.exclude = [get_rid()]
	params.transform = Transform3D(Basis(), global_position + Vector3(0, 0.55, 0) + forward * kick_range)
	var hits := space.intersect_shape(params, 6)
	var connected := false
	var sm := get_node_or_null("/root/SaveManager")
	var has_thorn: bool = sm != null and sm.has_method("has_charm") and bool(sm.call("has_charm", "charm_velvet_thorn"))
	var has_echo: bool = sm != null and sm.has_method("has_charm") and bool(sm.call("has_charm", "charm_echo_heel"))
	for hit in hits:
		var collider: Object = hit.collider
		if collider and collider.has_method("take_damage"):
			var final_dmg := step_dmg
			var is_afflicted := ("bind_t" in collider and float(collider.get("bind_t")) > 0.0) \
				or ("enamored_t" in collider and float(collider.get("enamored_t")) > 0.0) \
				or ("_bind_t" in collider and float(collider.get("_bind_t")) > 0.0) \
				or ("_enamored_t" in collider and float(collider.get("_enamored_t")) > 0.0)
			if has_thorn and is_afflicted:
				final_dmg = int(round(float(final_dmg) * 1.35))
				if sm:
					sm.add_desire(3, "Thorn of Allure")
			collider.take_damage(final_dmg, global_position, {"knockback": 8.5 + float(_combo_step) * 1.5, "launch": true})
			connected = true
	if _combo_step == 3 and has_echo:
		CombatFx.ring(self, global_position + forward * 1.1, Color(0.86, 0.94, 1.0), 3.4, 0.34)
		for echo_foe in _find_live_enemies(3.4):
			if echo_foe.has_method("take_damage"):
				echo_foe.take_damage(10, global_position, {"knockback": 6.0})
				connected = true
	if connected:
		_hitstop()
		velocity += forward * 3.2
		if sm:
			if sm.has_method("register_style_action"):
				sm.call("register_style_action", 14.0 + float(_combo_step) * 5.0, "Silver Kick")
			if sm.has_method("add_desire") and (_combo_step == 3 or _rapture_t > 0.0):
				sm.add_desire(5 if _combo_step == 3 else 3, "")

func _unhandled_input(event: InputEvent) -> void:
	if not leading or parked:
		return
	if event.is_action_pressed("ability_prev") or event.is_action_pressed("ability_next") or event.is_action_pressed("ability_cast"):
		get_viewport().set_input_as_handled()
		if not shoes_claimed:
			var hud_n := get_tree().get_first_node_in_group("hud")
			if hud_n and hud_n.has_method("show_toast"):
				hud_n.call("show_toast", "Claim the Silver Shoes to unlock Dorothy's Armaments!", 2.4)
			return
		if event.is_action_pressed("ability_prev"):
			_cycle_armament(-1)
		elif event.is_action_pressed("ability_next"):
			_cycle_armament(1)
		elif event.is_action_pressed("ability_cast"):
			_use_armament()

func _unhandled_key_input(event: InputEvent) -> void:
	if not leading or parked:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_Z, KEY_X, KEY_C]:
			get_viewport().set_input_as_handled()
			if not shoes_claimed:
				var hud_n := get_tree().get_first_node_in_group("hud")
				if hud_n and hud_n.has_method("show_toast"):
					hud_n.call("show_toast", "Claim the Silver Shoes to unlock Dorothy's Armaments (Z/X swap · C cast)!", 2.4)
				return
			if event.keycode == KEY_Z:
				_cycle_armament(-1)
			elif event.keycode == KEY_X:
				_cycle_armament(1)
			elif event.keycode == KEY_C:
				_use_armament()
		elif event.keycode == KEY_H and shoes_claimed:
			_try_rapture_mode()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_V and shoes_claimed and body and body.has_method("play_heel_click"):
			body.call("play_heel_click")
			CombatFx.ring(self, global_position, Color(0.88, 0.94, 1.0), 1.05, 0.34)
			get_viewport().set_input_as_handled()

func _sync_whip_visibility() -> void:
	if body == null or not body.has_method("set_whip_equipped"):
		return
	var sm := get_node_or_null("/root/SaveManager")
	var owns_whip: bool = sm != null and sm.has_method("has_whip_mastery") and bool(sm.call("has_whip_mastery"))
	body.call("set_whip_equipped", shoes_claimed and owns_whip and _armament_idx == 0)

func _cycle_armament(dir: int) -> void:
	_armament_idx = (_armament_idx + dir + ARMAMENT_NAMES.size()) % ARMAMENT_NAMES.size()
	_sync_whip_visibility()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_active_armament"):
		hud.call("set_active_armament", ARMAMENT_NAMES[_armament_idx])

func select_armament_by_name(target_name: String) -> void:
	for i in range(ARMAMENT_NAMES.size()):
		if target_name.to_lower() in str(ARMAMENT_NAMES[i]).to_lower():
			_armament_idx = i
			_sync_whip_visibility()
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("set_active_armament"):
				hud.call("set_active_armament", ARMAMENT_NAMES[_armament_idx])
			return

func _use_armament() -> void:
	if _armament_cd > 0.0:
		return
	var sm := get_node_or_null("/root/SaveManager")
	var whip_plus: bool = sm != null and sm.has_method("has_whip_mastery") and bool(sm.call("has_whip_mastery"))
	if _armament_idx == 0 and not whip_plus:
		var hud_w := get_tree().get_first_node_in_group("hud")
		if hud_w and hud_w.has_method("show_toast"):
			hud_w.call("show_toast", "Purchase Lace Whip Mastery in The Tailor of Vices [B] to wield the Whip!", 2.8)
		_sync_whip_visibility()
		return
	_armament_cd = 0.85
	_sync_whip_visibility()
	if body and body.has_method("play_cast"):
		body.call("play_cast", _armament_idx)
	var enemies := _find_live_enemies(13.5 if (_armament_idx == 0 and whip_plus) else 11.0)
	match _armament_idx:
		0: # The Lace Whip — ALWAYS cracks visibly forward; shatters vases & smashes whimsies along the arc; binds & yanks foes!
			var fwd_w := -visual.global_transform.basis.z
			fwd_w.y = 0.0
			fwd_w = fwd_w.normalized() if fwd_w.length() > 0.01 else Vector3.FORWARD
			var hand_origin := global_position + Vector3(0, 1.05, 0) + visual.global_transform.basis.x * 0.24
			var whip_range := 9.5 if whip_plus else 7.5
			var afx_w := get_node_or_null("/root/AudioFx")
			if afx_w and afx_w.has_method("play"):
				afx_w.play("whip", -4.0)
			# Shatter any destructible porcelain vases in the whip's forward cone!
			var smashed_urn: Node3D = null
			for dp in get_tree().get_nodes_in_group("destructibles"):
				if dp is Node3D and is_instance_valid(dp) and dp.has_method("take_damage"):
					var dv := (dp as Node3D).global_position - global_position
					dv.y = 0.0
					var dd := dv.length()
					if dd <= whip_range and (dd < 2.2 or dv.normalized().dot(fwd_w) > 0.42):
						smashed_urn = dp as Node3D
						dp.call("take_damage", 20, global_position, {"whip": true})
						break
			# Trigger smashable whimsies along the whip arc too!
			var wh_sys := get_node_or_null("/root/Whimsy")
			if wh_sys and wh_sys.has_method("smash_collect_near"):
				wh_sys.call("smash_collect_near", global_position, fwd_w, whip_range, self)
			if enemies.is_empty():
				var tip_pos := (smashed_urn.global_position + Vector3(0, 0.55, 0)) if smashed_urn != null else (hand_origin + fwd_w * whip_range)
				CombatFx.whip_lash(self, hand_origin, tip_pos)
				if smashed_urn == null:
					CombatFx.label(self, tip_pos + Vector3(0, 0.4, 0), "✦ CRACK!", Color(1.0, 0.35, 0.62))
				return
			var foe: Node3D = enemies[0]
			CombatFx.whip_lash(self, hand_origin, foe.global_position + Vector3(0, 0.85, 0))
			var pull_pos := global_position + (foe.global_position - global_position).normalized() * 1.65
			pull_pos.y = foe.global_position.y
			var tw := create_tween()
			tw.tween_property(foe, "global_position", pull_pos, 0.22).set_ease(Tween.EASE_OUT)
			if foe.has_method("apply_bind"):
				foe.call("apply_bind", 2.6 if whip_plus else 2.2)
			if foe.has_method("take_damage"):
				var w_dmg := (20 if whip_plus else 12) if _rapture_t <= 0.0 else (44 if whip_plus else 28)
				foe.take_damage(w_dmg, global_position, {"knockback": 0.5})
			if sm and sm.has_method("add_desire"):
				sm.add_desire(5, "Lace Whip Bind")
		1: # Silk Bindings — cocoon up to 3 nearby enemies & gild nearby vases/whimsies for 2× rewards!
			var hit_any := false
			for i in range(mini(3, enemies.size())):
				var foe: Node3D = enemies[i]
				if foe.global_position.distance_to(global_position) <= 8.5 and foe.has_method("apply_bind"):
					foe.call("apply_bind", 3.5)
					hit_any = true
			for dp in get_tree().get_nodes_in_group("destructibles"):
				if dp is Node3D and is_instance_valid(dp) and (dp as Node3D).global_position.distance_to(global_position) <= 7.5 and dp.has_method("apply_perfume_bonus"):
					dp.call("apply_perfume_bonus")
			if hit_any and sm and sm.has_method("add_desire"):
				sm.add_desire(5, "Silk Bindings")
			else:
				CombatFx.silk_cocoon(self, global_position - visual.global_transform.basis.z * 2.5)
		2: # Hypnotic Perfume — directional crystal atomizer spray cone + swirling rose-amethyst mist!
			var fwd_p := -visual.global_transform.basis.z
			fwd_p.y = 0.0
			fwd_p = fwd_p.normalized() if fwd_p.length() > 0.01 else Vector3.FORWARD
			CombatFx.perfume_cloud(self, global_position, 6.8, fwd_p)
			var charmed := 0
			for foe in enemies:
				if foe.global_position.distance_to(global_position) <= 7.0 and foe.has_method("apply_enamored"):
					foe.call("apply_enamored", 5.0)
					charmed += 1
			for dp in get_tree().get_nodes_in_group("destructibles"):
				if dp is Node3D and is_instance_valid(dp) and (dp as Node3D).global_position.distance_to(global_position) <= 7.5 and dp.has_method("apply_perfume_bonus"):
					dp.call("apply_perfume_bonus")
			var wh_p := get_node_or_null("/root/Whimsy")
			if wh_p and wh_p.has_method("perfume_near"):
				wh_p.call("perfume_near", global_position, 7.5)
			if charmed > 0 and sm and sm.has_method("add_desire"):
				sm.add_desire(5 * charmed, "Hypnotic Perfume")
		3: # The Gilded Chain — tether 2 nearest foes so damage mirrors 75% (or shatter nearby urn if alone)!
			for dp in get_tree().get_nodes_in_group("destructibles"):
				if dp is Node3D and is_instance_valid(dp) and (dp as Node3D).global_position.distance_to(global_position) <= 6.5 and dp.has_method("take_damage"):
					CombatFx.gilded_chain(self, global_position + Vector3(0, 1.0, 0), (dp as Node3D).global_position + Vector3(0, 0.5, 0))
					dp.call("take_damage", 20, global_position, {"chain": true})
					break
			if enemies.size() >= 2:
				var a: Node3D = enemies[0]
				var b: Node3D = enemies[1]
				CombatFx.gilded_chain(self, a.global_position, b.global_position)
				if a.has_method("set_chain_partner"):
					a.call("set_chain_partner", b, 8.0)
				if b.has_method("set_chain_partner"):
					b.call("set_chain_partner", a, 8.0)
				if sm and sm.has_method("add_desire"):
					sm.add_desire(6, "Gilded Chain Tether")
			else:
				CombatFx.label(self, global_position, "Need 2 Foes to Chain", Color(1.0, 0.85, 0.35))
		4: # Silver Heel-Click — Graceful aerial heel-tap starburst! Triggers Road Home pad in Glinda's Court OR staggers/heals anywhere!
			_armament_cd = 0.62
			if is_on_floor():
				velocity.y = 4.6
			if body and body.has_method("play_heel_click"):
				body.call("play_heel_click")
			if CombatFx.has_method("heel_click_burst"):
				CombatFx.heel_click_burst(self, global_position)
			else:
				CombatFx.ring(self, global_position, Color(0.88, 0.94, 1.0), 2.8, 0.42)
			var afx_hc := get_node_or_null("/root/AudioFx")
			if afx_hc and afx_hc.has_method("play"):
				afx_hc.play("buy", -4.0)
			# Stagger nearby foes with radiant silver-shoe shockwave!
			for foe_hc in _find_live_enemies(4.6):
				if foe_hc.has_method("take_damage"):
					foe_hc.take_damage(8, global_position, {"knockback": 7.5})
			# Notify active scene (e.g., Glinda's Court Road Home Pad 3× Heel Click!)
			var cur_sc := get_tree().current_scene
			if cur_sc and cur_sc.has_method("on_dorothy_heel_click"):
				cur_sc.call("on_dorothy_heel_click", self)

func _try_rapture_mode() -> void:
	if _rapture_t > 0.0:
		return
	var sm := get_node_or_null("/root/SaveManager")
	if sm and float(sm.allure) < 35.0 and int(sm.hp) > 2:
		CombatFx.label(self, global_position, "Build Allure to Enter Rapture", Color(0.95, 0.45, 0.65))
		return
	_rapture_t = 10.0
	if sm:
		sm.allure = maxf(0.0, float(sm.allure) - 35.0)
		sm.state_changed.emit()
	CombatFx.rapture_burst(self, global_position)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_rapture_visual"):
		hud.call("set_rapture_visual", true)

func _find_live_enemies(max_dist: float) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == null or not is_instance_valid(e) or e.is_in_group("enemies_dead"):
			continue
		if e is Node3D and (e as Node3D).global_position.distance_to(global_position) <= max_dist:
			out.append(e)
	out.sort_custom(func(a, b): return (a as Node3D).global_position.distance_to(global_position) < (b as Node3D).global_position.distance_to(global_position))
	return out

func _hitstop() -> void:
	Engine.time_scale = 0.08
	await get_tree().create_timer(0.09, true, false, true).timeout
	Engine.time_scale = 1.0

func _animate_visual(delta: float) -> void:
	var yaw_diff := angle_difference(_prev_vis_yaw, visual.rotation.y)
	_prev_vis_yaw = visual.rotation.y
	var turn_vel := yaw_diff / maxf(delta, 0.001)
	var hs := Vector2(velocity.x, velocity.z).length()
	var bank_target := clampf(-turn_vel * 0.022 * clampf(hs / 4.5, 0.0, 1.2), -0.18, 0.18)
	visual.rotation.x = lerp_angle(visual.rotation.x, 0.0, 14.0 * delta)
	visual.rotation.z = lerp_angle(visual.rotation.z, bank_target, 10.0 * delta)
	visual.scale = visual.scale.lerp(Vector3.ONE, 10.0 * delta)
	if Input.is_action_just_pressed("interact") and body and body.has_method("play_interact"):
		body.call("play_interact")
	if body:
		if body.has_method("set_airborne"):
			body.call("set_airborne", velocity.y, is_on_floor(), turn_vel)
		if body.has_method("set_locomotion"):
			body.set_locomotion(hs, delta)

func stumble(from: Vector3) -> void:
	if iframe_timer > 0.0 or stun_timer > 0.0:
		return
	stun_timer = 0.28
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.01:
		away = visual.global_transform.basis.z
	away = away.normalized()
	velocity.x = away.x * 5.5
	velocity.z = away.z * 5.5
	velocity.y = 2.4

func is_intangible() -> bool:
	return iframe_timer > 0.0

func empower_shoes() -> void:
	shoes_claimed = true
	blink_distance = 5.0
	blink_cooldown = 0.32
	if visual:
		visual.position.y = 0.03 # ensures Dorothy's entire Silver Shoes sit cleanly ON TOP of every road & floor!
	if body:
		body.set("show_silver_shoes", true)
		# Rebuild visual cleanly (clears joint arrays & preserves BasketMount!)
		if body.has_method("_rebuild_character"):
			body.call("_rebuild_character")
		elif body.has_method("_ready"):
			for c in body.get_children():
				c.free()
			body.call("_build")
	# Choreographed "putting on the Silver Shoes" dip-twirl + ankle sparkle ring!
	if visual and DisplayServer.get_name() not in ["headless", "Dummy"]:
		var tw := create_tween()
		tw.tween_property(visual, "position:y", -0.14, 0.22).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(visual, "rotation_degrees:x", 18.0, 0.22)
		tw.tween_property(visual, "position:y", 0.03, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(visual, "rotation_degrees:x", 0.0, 0.28)
		tw.parallel().tween_property(visual, "rotation:y", visual.rotation.y + TAU, 0.45)
		if CombatFx and CombatFx.has_method("flash_sphere"):
			CombatFx.flash_sphere(self, global_position + Vector3(0, 0.16, 0), Color(0.92, 0.96, 1.0), 0.95, 0.45)
			CombatFx.label(self, global_position, "✦ SILVER SHOES EQUIPPED ✦", Color(0.94, 0.98, 1.0))