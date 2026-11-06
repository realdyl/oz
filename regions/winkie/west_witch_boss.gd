extends CharacterBody3D

## Witch of the West boss stub — vault phases compressed for prototype.
## P1 hover + monkey-tint adds feel via winkie wave; P2 ground pressure; water melt finish.

var level: Node = null
var fighting: bool = false
var health: int = 120
var grounded: bool = false
var melting: bool = false
var _t: float = 0.0
var _hover_y: float = 0.08
var gravity: float = 18.0
var body_mat: StandardMaterial3D

func setup(host: Node) -> void:
	level = host
	add_to_group("enemies")
	add_to_group("boss")
	_hover_y = 2.4
	global_position.y = _hover_y

func begin_fight() -> void:
	fighting = true
	grounded = false
	_hover_y = 2.6

func begin_melt() -> void:
	melting = true
	fighting = false
	var lab := get_node_or_null("WestLabel") as Label3D
	if lab:
		lab.text = "I'M MELTING—"
		lab.modulate = Color(0.4, 0.7, 1.0)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.2, 0.05, 1.2), 2.0)
	tw.parallel().tween_property(self, "global_position:y", 0.05, 2.0)
	await tw.finished
	add_to_group("enemies_dead")
	visible = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

func take_damage(amount: int, source_position: Vector3, tags: Dictionary = {}) -> void:
	if melting or not fighting:
		# Allow chip before begin_fight if player rushes.
		if melting:
			return
		fighting = true
	var dmg := amount
	var armor_break := bool(tags.get("armor_break", false))
	if not grounded and not armor_break:
		dmg = maxi(1, int(amount * 0.35))
		if CombatFx and CombatFx.has_method("label"):
			CombatFx.label(self, global_position + Vector3(0, 2, 0), "SMOKE", Color(0.5, 0.4, 0.55))
	else:
		if armor_break and CombatFx and CombatFx.has_method("label"):
			CombatFx.label(self, global_position + Vector3(0, 2, 0), "SHATTER", Color(1.0, 0.8, 0.3))
	health -= dmg
	if CombatFx and CombatFx.has_method("flash_sphere"):
		CombatFx.flash_sphere(self, global_position + Vector3(0, 1.4, 0), Color(0.7, 0.2, 0.25), 0.5, 0.15)
	# Ground her after enough pressure or axe hits while low.
	if health <= 50 or (armor_break and health <= 90):
		grounded = true
		_hover_y = 0.08
	if level and level.has_method("on_west_damaged"):
		level.on_west_damaged(health, grounded)
	var away := global_position - source_position
	away.y = 0.0
	if away.length() > 0.01:
		away = away.normalized()
		velocity.x = away.x * 4.0
		velocity.z = away.z * 4.0
	if health <= 0 and not melting:
		# Force water path rather than raw HP kill — Baum water beat.
		health = 1
		grounded = true
		_hover_y = 0.08
		if level and level.has_method("on_west_damaged"):
			level.on_west_damaged(health, true)

func _physics_process(delta: float) -> void:
	if melting:
		return
	_t += delta
	var party := get_node_or_null("/root/Party")
	var target: Node3D = null
	if party and party.has_method("leader_body"):
		target = party.call("leader_body") as Node3D
	if target == null:
		target = get_tree().get_first_node_in_group("player") as Node3D

	if not grounded:
		# Hover circle above courtyard.
		var center := Vector3(0, _hover_y, -8)
		var ang := _t * 0.55
		var want := center + Vector3(cos(ang) * 7.0, sin(_t * 2.0) * 0.35, sin(ang) * 5.0)
		global_position = global_position.lerp(want, clampf(2.2 * delta, 0.0, 1.0))
		velocity = Vector3.ZERO
		if target:
			var look := target.global_position - global_position
			look.y = 0.0
			if look.length() > 0.1:
				rotation.y = atan2(-look.x, -look.z)
		# Occasional dive telegraph toward Lead.
		if fighting and int(_t * 2.0) % 11 == 0 and target:
			var dive := target.global_position - global_position
			dive.y = 0.0
			if dive.length() > 0.1:
				velocity = dive.normalized() * 6.0
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta
		elif velocity.y < 0.0:
			velocity.y = -1.0
		if target and fighting:
			var to := target.global_position - global_position
			to.y = 0.0
			var dist := to.length()
			if dist > 1.5:
				var dir := to / dist
				velocity.x = dir.x * 2.4
				velocity.z = dir.z * 2.4
				rotation.y = atan2(-dir.x, -dir.z)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
