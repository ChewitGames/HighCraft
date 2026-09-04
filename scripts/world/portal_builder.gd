class_name PortalBuilder
extends RefCounted
## Lights Hell / Heaven portals and completes End portal rings.

const MIN_INNER_W := 2
const MIN_INNER_H := 3
const MAX_INNER := 21

static func try_light_hell(world, renderer, origin: Vector3i) -> bool:
	return _try_light_frame(world, renderer, origin, "obsidian", "nether_portal")

static func try_light_heaven(world, renderer, origin: Vector3i) -> bool:
	return _try_light_frame(world, renderer, origin, "glowstone", "heaven_portal")

static func _try_light_frame(world, renderer, origin: Vector3i, frame_id: String, portal_id: String) -> bool:
	for axis in ["x", "z"]:
		var found = _find_from_cell(world, origin, axis, frame_id, portal_id)
		if found.is_empty():
			continue
		_fill_portal(world, renderer, found)
		return true
	return false

static func _find_from_cell(world, origin: Vector3i, axis: String, frame_id: String, portal_id: String) -> Dictionary:
	var seeds: Array = [origin]
	if axis == "x":
		seeds.append(origin + Vector3i(0, 1, 0))
		seeds.append(origin + Vector3i(0, 0, 1))
		seeds.append(origin + Vector3i(0, 0, -1))
	else:
		seeds.append(origin + Vector3i(0, 1, 0))
		seeds.append(origin + Vector3i(1, 0, 0))
		seeds.append(origin + Vector3i(-1, 0, 0))
	for seed in seeds:
		var sid = _block_at(world, axis, _fixed(axis, seed), seed.y, _along(axis, seed))
		if sid != "air" and sid != portal_id:
			continue
		var rect = _grow(world, seed, axis, frame_id, portal_id)
		if not rect.is_empty():
			return rect
	return {}

static func _fixed(axis: String, p: Vector3i) -> int:
	return p.x if axis == "x" else p.z

static func _along(axis: String, p: Vector3i) -> int:
	return p.z if axis == "x" else p.x

static func _grow(world, seed: Vector3i, axis: String, frame_id: String, portal_id: String) -> Dictionary:
	var fixed := _fixed(axis, seed)
	var a := _along(axis, seed)
	var y := seed.y
	var a0 := a
	var a1 := a
	while _is_inner(world, axis, fixed, y, a0 - 1, portal_id) and (a1 - (a0 - 1) + 1) <= MAX_INNER:
		a0 -= 1
	while _is_inner(world, axis, fixed, y, a1 + 1, portal_id) and ((a1 + 1) - a0 + 1) <= MAX_INNER:
		a1 += 1
	var w = a1 - a0 + 1
	if w < MIN_INNER_W or w > MAX_INNER:
		return {}
	var y0 := y
	var y1 := y
	while _row_inner(world, axis, fixed, y0 - 1, a0, a1, portal_id) and (y1 - (y0 - 1) + 1) <= MAX_INNER:
		y0 -= 1
	while _row_inner(world, axis, fixed, y1 + 1, a0, a1, portal_id) and ((y1 + 1) - y0 + 1) <= MAX_INNER:
		y1 += 1
	var h = y1 - y0 + 1
	if h < MIN_INNER_H or h > MAX_INNER:
		return {}
	for aa in range(a0 - 1, a1 + 2):
		if _block_at(world, axis, fixed, y0 - 1, aa) != frame_id:
			return {}
		if _block_at(world, axis, fixed, y1 + 1, aa) != frame_id:
			return {}
	for yy in range(y0, y1 + 1):
		if _block_at(world, axis, fixed, yy, a0 - 1) != frame_id:
			return {}
		if _block_at(world, axis, fixed, yy, a1 + 1) != frame_id:
			return {}
	return {"axis": axis, "fixed": fixed, "a0": a0, "a1": a1, "y0": y0, "y1": y1, "portal": portal_id}

static func _is_inner(world, axis: String, fixed: int, y: int, a: int, portal_id: String) -> bool:
	var id = _block_at(world, axis, fixed, y, a)
	return id == "air" or id == portal_id

static func _row_inner(world, axis: String, fixed: int, y: int, a0: int, a1: int, portal_id: String) -> bool:
	for a in range(a0, a1 + 1):
		if not _is_inner(world, axis, fixed, y, a, portal_id):
			return false
	return true

static func _block_at(world, axis: String, fixed: int, y: int, a: int) -> String:
	if axis == "x":
		return str(world.get_block(fixed, y, a))
	return str(world.get_block(a, y, fixed))

static func _write_block(world, renderer, axis: String, fixed: int, y: int, a: int, id: String) -> void:
	var x = fixed if axis == "x" else a
	var z = a if axis == "x" else fixed
	if renderer != null and renderer.has_method("edit_block"):
		renderer.edit_block(x, y, z, id)
	else:
		world.set_block(x, y, z, id)

static func _fill_portal(world, renderer, rect: Dictionary) -> void:
	for a in range(int(rect.a0), int(rect.a1) + 1):
		for y in range(int(rect.y0), int(rect.y1) + 1):
			_write_block(world, renderer, str(rect.axis), int(rect.fixed), y, a, str(rect.portal))

static func place_eye(world, renderer, cell: Vector3i) -> bool:
	var id = str(world.get_block(cell.x, cell.y, cell.z))
	if id != "end_portal_frame":
		return false
	if renderer != null and renderer.has_method("edit_block"):
		renderer.edit_block(cell.x, cell.y, cell.z, "end_portal_frame_filled")
	else:
		world.set_block(cell.x, cell.y, cell.z, "end_portal_frame_filled")
	_try_complete_end_portal(world, renderer, cell)
	return true

static func _try_complete_end_portal(world, renderer, cell: Vector3i) -> void:
	for dx in range(-4, 1):
		for dz in range(-4, 1):
			var ox = cell.x + dx
			var oz = cell.z + dz
			if _end_ring_complete(world, ox, cell.y, oz):
				for ix in range(ox + 1, ox + 4):
					for iz in range(oz + 1, oz + 4):
						if renderer != null and renderer.has_method("edit_block"):
							renderer.edit_block(ix, cell.y, iz, "end_portal")
						else:
							world.set_block(ix, cell.y, iz, "end_portal")
				return

static func _end_ring_complete(world, ox: int, y: int, oz: int) -> bool:
	var filled := 0
	for x in range(ox, ox + 5):
		for z in range(oz, oz + 5):
			var edge = x == ox or x == ox + 4 or z == oz or z == oz + 4
			var corner = (x == ox or x == ox + 4) and (z == oz or z == oz + 4)
			if not edge or corner:
				continue
			if str(world.get_block(x, y, z)) == "end_portal_frame_filled":
				filled += 1
	return filled >= 12
