class_name VoxelRaycast
extends RefCounted
# Amanatides & Woo voxel DDA ray cast against a VoxelWorld. Used for breaking
# and placing blocks. Returns the first solid cell hit, the empty cell just
# before it (where a new block goes) and the hit face normal.

const NON_SOLID = {"air": true, "water": true, "lava": true}


static func cast(world, origin: Vector3, direction: Vector3, max_dist: float = 6.0) -> Dictionary:
	var dir = direction
	var length = dir.length()
	if length == 0.0:
		return {"ok": false}
	dir = dir / length

	var x = floori(origin.x)
	var y = floori(origin.y)
	var z = floori(origin.z)
	var step_x = 1 if dir.x > 0.0 else -1
	var step_y = 1 if dir.y > 0.0 else -1
	var step_z = 1 if dir.z > 0.0 else -1

	var inf = INF
	var t_delta_x = absf(1.0 / dir.x) if dir.x != 0.0 else inf
	var t_delta_y = absf(1.0 / dir.y) if dir.y != 0.0 else inf
	var t_delta_z = absf(1.0 / dir.z) if dir.z != 0.0 else inf

	var t_max_x = _t_max(origin.x, x, step_x, dir.x)
	var t_max_y = _t_max(origin.y, y, step_y, dir.y)
	var t_max_z = _t_max(origin.z, z, step_z, dir.z)

	var normal = Vector3i.ZERO
	var t = 0.0

	if _is_solid(world, x, y, z):
		return {"ok": true, "hit": Vector3i(x, y, z), "place": Vector3i(x, y, z), "normal": normal}

	while t <= max_dist:
		if t_max_x < t_max_y and t_max_x < t_max_z:
			x += step_x
			t = t_max_x
			t_max_x += t_delta_x
			normal = Vector3i(-step_x, 0, 0)
		elif t_max_y < t_max_z:
			y += step_y
			t = t_max_y
			t_max_y += t_delta_y
			normal = Vector3i(0, -step_y, 0)
		else:
			z += step_z
			t = t_max_z
			t_max_z += t_delta_z
			normal = Vector3i(0, 0, -step_z)

		if t > max_dist:
			break
		if _is_solid(world, x, y, z):
			var place = Vector3i(x + normal.x, y + normal.y, z + normal.z)
			return {"ok": true, "hit": Vector3i(x, y, z), "place": place, "normal": normal}

	return {"ok": false}


static func _t_max(o: float, cell: int, step: int, d: float) -> float:
	if d == 0.0:
		return INF
	var nxt = cell + (1 if step > 0 else 0)
	return (nxt - o) / d


static func _is_solid(world, x: int, y: int, z: int) -> bool:
	return not NON_SOLID.has(world.get_block(x, y, z))
