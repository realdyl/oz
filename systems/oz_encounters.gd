extends RefCounted

## Phase P5.3–P11.3: Reusable 2026 Retail Gameplay Expansion Engine ("OzEncounters").
## Spawns interactive Companion Synergy Puzzles, Secret "Velvet Sanctums", Side-Quest Monuments,
## Toto Scent Caches, and the Kalidah Chimera Mini-Boss across Acts L1–L7!

const WorldKit := preload("res://systems/world_kit.gd")
const PUPPET_SCENE := preload("res://actors/enemies/puppet_munchkin.tscn")

# ============================================================================
# 1. COMPANION SYNERGY PUZZLES & SIDE-QUEST MONUMENTS (Triggered by [E] or [F]!)
# ============================================================================
class SynergyMonument extends StaticBody3D:
	var kind: String = "chime" # "crow_bell" | "rusted_chain" | "bramble_shrine" | "toto_scent" | "chime"
	var quest_id: String = ""
	var charm_id: String = ""
	var memory_id: String = ""
	var desire_reward: int = 20
	var title_text: String = "Ancient Monument"
	var solved: bool = false
	var _t: float = 0.0
	var _spin_node: Node3D = null

	func _ready() -> void:
		add_to_group("destructibles")
		add_to_group("synergy_puzzles")
		collision_layer = 1 | 4
		collision_mask = 0

	func _process(delta: float) -> void:
		if solved:
			return
		_t += delta
		if _spin_node and is_instance_valid(_spin_node):
			_spin_node.rotation.y = _t * 1.4
			_spin_node.position.y = 1.65 + sin(_t * 2.4) * 0.10
		# Allow effortless proximity [E] activation by any active Lead within 3.2m!
		if Input.is_action_just_pressed("interact"):
			var p := get_node_or_null("/root/Party")
			var actor: Node3D = p.call("leader_body") as Node3D if (p and p.has_method("leader_body")) else null
			if actor == null:
				actor = get_tree().get_first_node_in_group("player") as Node3D
			if actor and actor.global_position.distance_to(global_position) <= 3.3:
				_activate(actor.global_position)

	func take_damage(_amount: int, source_position: Vector3, tags: Dictionary = {}) -> void:
		if solved:
			return
		if kind == "rusted_chain" and not bool(tags.get("armor_break", false)) and _amount < 18:
			if CombatFx:
				CombatFx.label(self, global_position + Vector3(0, 1.8, 0), "CHAINED — USE TIN AXE OR [E]!", Color(0.95, 0.78, 0.38))
			return
		_activate(source_position)

	func _activate(_src: Vector3) -> void:
		if solved:
			return
		solved = true
		collision_layer = 0
		remove_from_group("destructibles")
		var sm := get_node_or_null("/root/SaveManager")
		if sm:
			if quest_id != "" and sm.has_method("advance_side_quest"):
				sm.call("advance_side_quest", quest_id, 1)
			if charm_id != "" and sm.has_method("grant_charm"):
				sm.call("grant_charm", charm_id)
			if memory_id != "" and sm.has_method("unlock_memory"):
				sm.call("unlock_memory", memory_id)
			if desire_reward > 0 and sm.has_method("add_desire"):
				sm.add_desire(desire_reward, title_text)
		var afx := get_node_or_null("/root/AudioFx")
		if afx and afx.has_method("play"):
			afx.play("buy", -5.0)
		if CombatFx:
			if kind == "crow_bell" and CombatFx.has_method("crow_storm"):
				CombatFx.crow_storm(get_parent(), global_position)
			CombatFx.ring(get_parent(), global_position + Vector3(0, 0.2, 0), Color(0.98, 0.84, 0.42), 3.2, 0.42)
			CombatFx.flash_sphere(get_parent(), global_position + Vector3(0, 1.2, 0), Color(0.98, 0.86, 0.46), 0.9, 0.28)
			CombatFx.label(get_parent(), global_position + Vector3(0, 1.8, 0), "✦ %s (+%d ♦)" % [title_text.to_upper(), desire_reward], Color(1.0, 0.88, 0.46))
		if DisplayServer.get_name() in ["headless", "Dummy"]:
			queue_free()
		else:
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.28).set_ease(Tween.EASE_IN)
			tw.tween_callback(queue_free)


# ============================================================================
# 2. HIDDEN "VELVET SANCTUMS" (Secret Trial Portals Rewarding Curios + 40 Desire!)
# ============================================================================
class VelvetSanctumPortal extends Node3D:
	var sanctum_id: String = "sanctum_munchkin"
	var reward_charm: String = "charm_echo_heel"
	var sanctum_title: String = "Velvet Sanctum of Echoes"
	var state: int = 0 # 0 = idle, 1 = trial_active, 2 = cleared
	var _spawned_foes: Array[Node3D] = []
	var _ring_mesh: MeshInstance3D = null
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _ring_mesh and is_instance_valid(_ring_mesh):
			_ring_mesh.rotation.z = _t * (2.6 if state == 1 else 0.85)
		if state == 2:
			return
		if state == 1:
			var alive := 0
			for f in _spawned_foes:
				if f and is_instance_valid(f) and not f.is_in_group("enemies_dead") and int(f.get("health")) > 0:
					alive += 1
			if alive == 0:
				_complete_trial()
			return
		if Input.is_action_just_pressed("interact"):
			var p := get_node_or_null("/root/Party")
			var actor: Node3D = p.call("leader_body") as Node3D if (p and p.has_method("leader_body")) else null
			if actor == null:
				actor = get_tree().get_first_node_in_group("player") as Node3D
			if actor and actor.global_position.distance_to(global_position) <= 3.8:
				_begin_trial()

	func _begin_trial() -> void:
		var sm := get_node_or_null("/root/SaveManager")
		if sm and sanctum_id in sm.completed_sanctums:
			state = 2
			return
		state = 1
		if CombatFx:
			CombatFx.ring(get_parent(), global_position, Color(0.95, 0.20, 0.48), 5.0, 0.5)
			CombatFx.label(get_parent(), global_position + Vector3(0, 2.8, 0), "✦ VELVET SANCTUM TRIAL BEGINS! ✦", Color(1.0, 0.42, 0.66))
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_toast"):
			hud.call("show_toast", "✦ %s — Defeat the 3 Gilded Phantoms!" % sanctum_title, 3.5)
		var host := get_parent()
		for i in range(3):
			var ang := float(i) * TAU / 3.0
			var f := PUPPET_SCENE.instantiate() as CharacterBody3D
			f.name = "SanctumPhantom_%d" % i
			host.add_child(f)
			f.global_position = global_position + Vector3(cos(ang) * 4.5, 0.12, sin(ang) * 4.5)
			if "health" in f:
				f.set("health", 26)
			if "combat_ready" in f:
				f.set("combat_ready", true)
			if f.has_method("_finish_arming"):
				f.call("_finish_arming")
			_spawned_foes.append(f)

	func _complete_trial() -> void:
		state = 2
		var sm := get_node_or_null("/root/SaveManager")
		if sm:
			if sanctum_id not in sm.completed_sanctums:
				sm.completed_sanctums.append(sanctum_id)
			sm.grant_charm(reward_charm)
			sm.add_desire(40, sanctum_title)
			sm.heal_full()
			if sm.has_method("register_style_action"):
				sm.call("register_style_action", 55.0, "Sanctum Cleared")
		if CombatFx:
			CombatFx.rapture_burst(get_parent(), global_position)
			CombatFx.label(get_parent(), global_position + Vector3(0, 3.0, 0), "★ SANCTUM CLEARED — CURIO UNLOCKED! ★", Color(1.0, 0.88, 0.46))
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_toast"):
			hud.call("show_toast", "★ %s Cleared! Unlocked Curio in Boutique/Grimoire!" % sanctum_title, 4.2)


# ============================================================================
# 3. THE KALIDAH CHIMERA (Baum Ch.VII Bear-Tiger Shadow Mini-Boss!)
# ============================================================================
class KalidahBeast extends CharacterBody3D:
	var health: int = 65
	var max_health: int = 65
	var _pounce_cd: float = 3.2
	var _bind_t: float = 0.0
	var _enamored_t: float = 0.0
	var _t: float = 0.0
	var home_pos: Vector3 = Vector3.ZERO

	func _ready() -> void:
		add_to_group("enemies")
		collision_layer = 4
		collision_mask = 1
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.65
		cap.height = 1.6
		cs.shape = cap
		cs.position = Vector3(0, 0.8, 0)
		add_child(cs)
		_build_visual()

	func _build_visual() -> void:
		var fur := StandardMaterial3D.new()
		fur.albedo_color = Color(0.14, 0.09, 0.16)
		fur.roughness = 0.82
		var stripe := StandardMaterial3D.new()
		stripe.albedo_color = Color(0.56, 0.16, 0.26)
		stripe.emission_enabled = true
		stripe.emission = Color(0.75, 0.14, 0.30)
		stripe.emission_energy_multiplier = 0.8
		var eye_m := StandardMaterial3D.new()
		eye_m.albedo_color = Color(1.0, 0.78, 0.20)
		eye_m.emission_enabled = true
		eye_m.emission = Color(1.0, 0.65, 0.12)
		eye_m.emission_energy_multiplier = 2.4

		# Bear-massive barrel chest + tiger stripes + jagged dorsal spines + glowing amber eyes
		var torso := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.48
		cap.height = 1.45
		torso.mesh = cap
		torso.rotation_degrees.x = 90.0
		torso.position = Vector3(0, 0.78, 0)
		torso.material_override = fur
		add_child(torso)

		var head := MeshInstance3D.new()
		var hs := SphereMesh.new()
		hs.radius = 0.38
		hs.height = 0.72
		head.mesh = hs
		head.position = Vector3(0, 1.05, -0.72)
		head.material_override = fur
		add_child(head)

		for sx in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			var es := SphereMesh.new()
			es.radius = 0.065
			eye.mesh = es
			eye.position = Vector3(float(sx) * 0.16, 1.14, -1.04)
			eye.material_override = eye_m
			add_child(eye)

		for lx in [-0.34, 0.34]:
			for lz in [-0.46, 0.46]:
				var leg := MeshInstance3D.new()
				var lc := CylinderMesh.new()
				lc.top_radius = 0.13
				lc.bottom_radius = 0.10
				lc.height = 0.72
				leg.mesh = lc
				leg.position = Vector3(float(lx), 0.36, float(lz))
				leg.material_override = fur
				add_child(leg)

		for si in range(4):
			var sp := MeshInstance3D.new()
			var pr := PrismMesh.new()
			pr.size = Vector3(0.14, 0.28, 0.22)
			sp.mesh = pr
			sp.position = Vector3(0, 1.28, -0.35 + float(si) * 0.26)
			sp.material_override = stripe
			add_child(sp)

	func apply_bind(dur: float) -> void:
		_bind_t = maxf(_bind_t, dur)

	func apply_enamored(dur: float) -> void:
		_enamored_t = maxf(_enamored_t, dur)

	func take_damage(amount: int, source_position: Vector3, _tags: Dictionary = {}) -> void:
		if health <= 0:
			return
		health -= amount
		if CombatFx:
			CombatFx.flash_sphere(get_parent(), global_position + Vector3(0, 0.9, 0), Color(1.0, 0.36, 0.48), 0.55, 0.16)
			CombatFx.label(get_parent(), global_position + Vector3(0, 1.5, 0), "-%d" % amount, Color(1.0, 0.75, 0.35))
		var away := (global_position - source_position)
		away.y = 0.0
		if away.length() > 0.05:
			velocity = away.normalized() * 5.0
		if health <= 0:
			add_to_group("enemies_dead")
			var sm := get_node_or_null("/root/SaveManager")
			if sm:
				sm.add_desire(30, "Slain Kalidah Chimera")
				if sm.has_method("register_style_action"):
					sm.call("register_style_action", 45.0, "Kalidah Slain")
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("hide_boss_bar"):
				hud.call("hide_boss_bar")
			queue_free()

	func _physics_process(delta: float) -> void:
		if health <= 0:
			return
		_t += delta
		_bind_t = maxf(_bind_t - delta, 0.0)
		_enamored_t = maxf(_enamored_t - delta, 0.0)
		if not is_on_floor():
			velocity.y -= 22.0 * delta
		else:
			velocity.y = -0.5
		if _bind_t > 0.0 or _enamored_t > 0.0:
			velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
			move_and_slide()
			return
		var p := get_node_or_null("/root/Party")
		var tgt: Node3D = p.call("leader_body") as Node3D if (p and p.has_method("leader_body")) else null
		if tgt == null:
			return
		var dist := global_position.distance_to(tgt.global_position)
		var hud := get_tree().get_first_node_in_group("hud")
		if dist < 18.0 and global_position.distance_to(home_pos) < 26.0:
			if hud and hud.has_method("show_boss_bar"):
				hud.call("show_boss_bar", "KALIDAH SHADOW-CHIMERA", "POPPY RIDGE PREDATOR", float(health), float(max_health))
			var dir := (tgt.global_position - global_position)
			dir.y = 0.0
			if dir.length() > 0.1:
				dir = dir.normalized()
				rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)
				if dist > 2.1:
					velocity.x = dir.x * 4.2
					velocity.z = dir.z * 4.2
				else:
					velocity.x = 0.0
					velocity.z = 0.0
			_pounce_cd -= delta
			if _pounce_cd <= 0.0 and CombatFx and CombatFx.has_method("aoe_telegraph"):
				_pounce_cd = 3.8
				var strike := tgt.global_position
				CombatFx.aoe_telegraph(get_parent(), strike, 2.6, 0.95, Color(0.95, 0.25, 0.35), func():
					if is_instance_valid(tgt) and tgt.global_position.distance_to(strike) < 2.7:
						if tgt.has_method("stumble"):
							tgt.call("stumble", global_position)
				)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		move_and_slide()


# ============================================================================
# PUBLIC FACTORY HELPERS FOR ALL 7 LEVELS
# ============================================================================
static func spawn_monument(
	host: Node,
	pos: Vector3,
	kind: String,
	title_txt: String,
	quest_id: String = "",
	accent: Color = Color(0.94, 0.78, 0.38),
	desire_amt: int = 20,
	charm_id: String = "",
	memory_id: String = ""
) -> Node3D:
	var m := SynergyMonument.new()
	m.name = "Monument_" + title_txt.replace(" ", "")
	m.kind = kind
	m.title_text = title_txt
	m.quest_id = quest_id
	m.desire_reward = desire_amt
	m.charm_id = charm_id
	m.memory_id = memory_id
	host.add_child(m)
	m.global_position = pos

	var col := CollisionShape3D.new()
	var cyl_s := CylinderShape3D.new()
	cyl_s.radius = 0.65
	cyl_s.height = 2.2
	col.shape = cyl_s
	col.position = Vector3(0, 1.1, 0)
	m.add_child(col)

	# Sculpted stone & antique-brass plinth + floating crystal/bell crest
	var base := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.48
	bc.bottom_radius = 0.62
	bc.height = 1.15
	base.mesh = bc
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.18, 0.14, 0.20)
	bm.roughness = 0.65
	bm.metallic = 0.35
	base.material_override = bm
	base.position = Vector3(0, 0.58, 0)
	m.add_child(base)

	var gem := MeshInstance3D.new()
	var gm: Mesh = PrismMesh.new() if kind != "crow_bell" else CylinderMesh.new()
	if gm is PrismMesh:
		(gm as PrismMesh).size = Vector3(0.46, 0.68, 0.46)
	elif gm is CylinderMesh:
		(gm as CylinderMesh).top_radius = 0.14
		(gm as CylinderMesh).bottom_radius = 0.34
		(gm as CylinderMesh).height = 0.52
	gem.mesh = gm
	var em := StandardMaterial3D.new()
	em.albedo_color = accent
	em.emission_enabled = true
	em.emission = accent
	em.emission_energy_multiplier = 1.65
	em.metallic = 0.65
	em.roughness = 0.18
	gem.material_override = em
	gem.position = Vector3(0, 1.65, 0)
	m.add_child(gem)
	m._spin_node = gem

	WorldKit.make_world_badge(m, Vector3(0, 2.45, 0), "◈  %s (E / F)" % title_txt, accent.lightened(0.25), 14.0)
	return m

static func spawn_velvet_sanctum(
	host: Node,
	pos: Vector3,
	sanctum_id: String,
	reward_charm: String,
	title_txt: String
) -> Node3D:
	var s := VelvetSanctumPortal.new()
	s.name = "VelvetSanctum_" + sanctum_id
	s.sanctum_id = sanctum_id
	s.reward_charm = reward_charm
	s.sanctum_title = title_txt
	host.add_child(s)
	s.global_position = pos

	# Sculpted Crimson-Obsidian & Antique-Gold Mirrored Portal Arch
	var obsidian := StandardMaterial3D.new()
	obsidian.albedo_color = Color(0.12, 0.05, 0.14)
	obsidian.metallic = 0.55
	obsidian.roughness = 0.25
	for sx in [-1.45, 1.45]:
		var pil := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.22
		pc.bottom_radius = 0.28
		pc.height = 3.4
		pil.mesh = pc
		pil.material_override = obsidian
		pil.position = Vector3(float(sx), 1.7, 0)
		s.add_child(pil)

	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.15
	tm.outer_radius = 1.38
	ring.mesh = tm
	ring.rotation_degrees.x = 90.0
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.92, 0.22, 0.46)
	rm.emission_enabled = true
	rm.emission = Color(0.95, 0.24, 0.50)
	rm.emission_energy_multiplier = 2.1
	ring.material_override = rm
	ring.position = Vector3(0, 2.0, 0)
	s.add_child(ring)
	s._ring_mesh = ring

	WorldKit.make_world_badge(s, Vector3(0, 3.75, 0), "✦  %s — Trial [E]" % title_txt, Color(1.0, 0.62, 0.78), 16.0)
	return s

static func spawn_kalidah_ambush(host: Node, pos: Vector3) -> CharacterBody3D:
	var k := KalidahBeast.new()
	k.name = "KalidahChimera"
	k.home_pos = pos
	host.add_child(k)
	k.global_position = pos
	WorldKit.make_world_badge(k, Vector3(0, 2.0, 0), "☠  Kalidah Shadow-Chimera", Color(1.0, 0.45, 0.45), 14.0)
	return k
