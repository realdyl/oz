extends Node

## Shared natural stair step-up + wall-steer for party, allies, and rogues.
## Smooth hills are climbed naturally by CharacterBody3D.move_and_slide() (NO 25m/s hill teleport!).
## Vertical stair/terrace risers step cleanly upward with a natural per-step rhythm.

const DEFAULT_STEP := 1.15
const STEP_COOLDOWN_MS := 110

func try_step(body: CharacterBody3D, dir: Vector3, step_height: float = DEFAULT_STEP) -> bool:
	if body == null or not body.is_on_floor() or dir.length() < 0.05:
		return false
	var now_ms := Time.get_ticks_msec()
	if body.has_meta("_last_step_ms") and (now_ms - int(body.get_meta("_last_step_ms"))) < STEP_COOLDOWN_MS:
		return false
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	if space == null:
		return false
	var d: Vector3 = dir.normalized()
	var rid: RID = body.get_rid()
	for dist_mul in [0.42, 0.62]:
		var feet: Vector3 = body.global_position + Vector3(0, 0.025, 0)
		var ahead: Vector3 = feet + d * float(dist_mul)
		var hit_wall: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(feet, ahead, 1, [rid]))
		# Only step up when an actual VERTICAL riser wall blocks feet (normal.y < 0.35).
		# Smooth grassy hills (hit_wall.is_empty() or normal.y >= 0.35) are walked naturally!
		if hit_wall.is_empty():
			continue
		var norm: Vector3 = hit_wall.get("normal", Vector3.UP)
		if norm.y >= 0.35:
			continue
		var hit_top: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
			ahead + Vector3(0, step_height + 0.45, 0),
			ahead + Vector3(0, 0.01, 0),
			1,
			[rid]
		))
		if hit_top.is_empty():
			continue
		var land_y: float = hit_top.position.y
		if land_y <= body.global_position.y + 0.02 or land_y > body.global_position.y + step_height + 0.22:
			continue
		if not _head_clear(space, rid, ahead.x, land_y, ahead.z):
			continue
		# Smoothly lift onto the stair tread with minimal horizontal clearance (no sudden forward launch)
		var micro_fwd: Vector3 = body.global_position + d * 0.14
		body.global_position = Vector3(micro_fwd.x, land_y + 0.02, micro_fwd.z)
		body.velocity.y = 0.0
		body.set_meta("_last_step_ms", now_ms)
		return true
	return false

func _head_clear(space: PhysicsDirectSpaceState3D, rid: RID, x: float, land_y: float, z: float) -> bool:
	var blocked: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(x, land_y + 0.25, z),
		Vector3(x, land_y + 1.35, z),
		1,
		[rid]
	))
	return blocked.is_empty()

func steer(body: CharacterBody3D, wish: Vector3, probe_dist: float = 1.15) -> Vector3:
	if body == null or wish.length() < 0.05:
		return Vector3.ZERO
	var d: Vector3 = wish.normalized()
	d.y = 0.0
	if d.length() < 0.01:
		return Vector3.ZERO
	d = d.normalized()
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	if space == null:
		return d
	var rid: RID = body.get_rid()
	var origin: Vector3 = body.global_position + Vector3(0, 0.55, 0)
	if not _blocked_tall(space, rid, origin, d, probe_dist, body.global_position.y):
		return d
	var best: Vector3 = Vector3.ZERO
	var best_score: float = -1.0e9
	for ang_deg in [25.0, -25.0, 45.0, -45.0, 70.0, -70.0, 90.0, -90.0, 120.0, -120.0]:
		var ang: float = deg_to_rad(float(ang_deg))
		var side: Vector3 = Vector3(d.x * cos(ang) - d.z * sin(ang), 0.0, d.x * sin(ang) + d.z * cos(ang)).normalized()
		if _blocked_tall(space, rid, origin, side, probe_dist * 0.9, body.global_position.y):
			continue
		var score: float = side.dot(d) * 2.0 - absf(float(ang_deg)) * 0.01
		if score > best_score:
			best_score = score
			best = side
	if best.length() > 0.01:
		return best
	return Vector3.ZERO

func _blocked_tall(space: PhysicsDirectSpaceState3D, rid: RID, origin: Vector3, dir: Vector3, dist: float, floor_y: float) -> bool:
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + dir * dist, 1, [rid]))
	if hit.is_empty():
		return false
	var hit_y: float = hit.position.y
	if hit_y <= floor_y + DEFAULT_STEP + 0.15:
		var top: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
			hit.position + Vector3(0, DEFAULT_STEP + 0.4, 0),
			hit.position + Vector3(0, 0.02, 0),
			1,
			[rid]
		))
		if not top.is_empty() and top.position.y <= floor_y + DEFAULT_STEP + 0.25:
			return false
	return true
