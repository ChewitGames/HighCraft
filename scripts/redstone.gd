class_name Redstone
extends RefCounted
# Minecraft 1.6.4-style redstone: signal strength 0–15, wires, torches,
# repeaters, comparators (basic), quasi-connectivity for pistons.

const MAX_WIRE_STEPS := 512
const MAX_STRENGTH := 15
const MAX_PISTON_PUSH := 12

# cell -> strength (computed during pulse)
static var _power: Dictionary = {}


static func neighbors(cell: Vector3i) -> Array[Vector3i]:
	return [
		cell + Vector3i(1, 0, 0), cell + Vector3i(-1, 0, 0),
		cell + Vector3i(0, 1, 0), cell + Vector3i(0, -1, 0),
		cell + Vector3i(0, 0, 1), cell + Vector3i(0, 0, -1),
	]


static func is_power_source(id: String) -> bool:
	return id in [
		"lever_on", "stone_button_on", "pressure_plate_on",
		"daylight_sensor_on", "redstone_torch_on", "redstone_torch",
		"repeater_on",
	]


static func is_wire(id: String) -> bool:
	return id == "redstone"


static func is_repeater(id: String) -> bool:
	return id == "repeater" or id == "repeater_on"


static func is_comparator(id: String) -> bool:
	return id == "comparator" or id == "comparator_on"


static func source_strength(id: String) -> int:
	if is_power_source(id):
		return MAX_STRENGTH
	return 0


## BFS: compute strength for every wire cell reachable from strong sources near origin.
static func _compute_power(world, origin: Vector3i) -> void:
	_power.clear()
	var queue: Array = []  # Vector3i
	# Seed from origin and neighbors that are sources
	var seeds: Array[Vector3i] = [origin]
	for n in neighbors(origin):
		seeds.append(n)
	for c in seeds:
		var id = world.get_block(c.x, c.y, c.z)
		var s = source_strength(id)
		if s > 0:
			_power[c] = s
			queue.append(c)
		elif is_wire(id):
			# wire itself gets power only from neighbors — seed enqueue for search
			queue.append(c)

	# Also walk outward from every known source in a small radius around origin
	var visited: Dictionary = {}
	var i = 0
	while i < queue.size() and i < MAX_WIRE_STEPS:
		var c: Vector3i = queue[i]
		i += 1
		var cur = int(_power.get(c, 0))
		var cid = world.get_block(c.x, c.y, c.z)
		# Repeaters refresh to 15 when input side has power
		if is_repeater(cid):
			if cur > 0 or _input_powered(world, c):
				_power[c] = MAX_STRENGTH
				cur = MAX_STRENGTH
			else:
				_power[c] = 0
				cur = 0
		if cur <= 1:
			continue
		var next_s = cur - 1
		for n in neighbors(c):
			var nid = world.get_block(n.x, n.y, n.z)
			if is_wire(nid) or is_repeater(nid) or is_comparator(nid):
				var old = int(_power.get(n, 0))
				if next_s > old:
					_power[n] = next_s
					queue.append(n)


static func _input_powered(world, cell: Vector3i) -> bool:
	# Simple: any neighbor source or wire with power
	for n in neighbors(cell):
		var id = world.get_block(n.x, n.y, n.z)
		if source_strength(id) > 0:
			return true
		if is_wire(id) and int(_power.get(n, 0)) > 0:
			return true
	return false


static func get_strength(cell: Vector3i) -> int:
	return int(_power.get(cell, 0))


static func is_powered(world, cell: Vector3i) -> bool:
	# Direct: neighbor source or powered wire/repeater
	for n in neighbors(cell):
		var id = world.get_block(n.x, n.y, n.z)
		if source_strength(id) > 0:
			return true
		if is_wire(id) and get_strength(n) > 0:
			return true
		if is_repeater(id) and get_strength(n) > 0:
			return true
		if id == "repeater_on":
			return true
	# Quasi-connectivity: block above cell is powered (classic MC QC)
	var above = cell + Vector3i(0, 1, 0)
	for n in neighbors(above):
		var id = world.get_block(n.x, n.y, n.z)
		if source_strength(id) > 0:
			return true
		if is_wire(id) and get_strength(n) > 0:
			return true
	# Soft power through solid block above
	var ab_id = world.get_block(above.x, above.y, above.z)
	if ab_id != "air" and Registry.is_opaque(ab_id):
		for n in neighbors(above):
			var id = world.get_block(n.x, n.y, n.z)
			if source_strength(id) > 0 or (is_wire(id) and get_strength(n) > 0):
				return true
	return false


static func powered_neighbors(world, cell: Vector3i) -> bool:
	return is_powered(world, cell)


static func pulse(game, world, renderer, origin: Vector3i) -> void:
	# Keep the previously powered cells: after a source switches off the freshly
	# computed map is empty, but consumers beside the old wire still need an
	# explicit off/retract update.
	var previous_power: Dictionary = _power.duplicate()
	_compute_power(world, origin)
	# Persist for mesher glow + rebuild touched wire chunks
	if game != null:
		game.redstone_power = _power.duplicate()
	_rebuild_powered_chunks(world, renderer, previous_power)
	_rebuild_powered_chunks(world, renderer, _power)

	# Update repeater visual on/off near network
	var check: Dictionary = {}
	check[origin] = true
	for n in neighbors(origin):
		check[n] = true
	for c in _power.keys():
		check[c] = true
		for n in neighbors(c):
			check[n] = true
	for c in previous_power.keys():
		check[c] = true
		for n in neighbors(c):
			check[n] = true

	for c in check.keys():
		var id = str(world.get_block(c.x, c.y, c.z))
		match id:
			"door_oak":
				if is_powered(world, c):
					renderer.edit_block(c.x, c.y, c.z, "door_oak_open")
			"door_oak_open":
				if not is_powered(world, c):
					renderer.edit_block(c.x, c.y, c.z, "door_oak")
			"trapdoor_oak":
				if is_powered(world, c):
					renderer.edit_block(c.x, c.y, c.z, "trapdoor_oak_open")
			"trapdoor_oak_open":
				if not is_powered(world, c):
					renderer.edit_block(c.x, c.y, c.z, "trapdoor_oak")
			"fence_gate_oak":
				if is_powered(world, c):
					renderer.edit_block(c.x, c.y, c.z, "fence_gate_oak_open")
			"fence_gate_oak_open":
				if not is_powered(world, c):
					renderer.edit_block(c.x, c.y, c.z, "fence_gate_oak")
			"dispenser":
				if is_powered(world, c) and game != null and game.has_method("activate_dispenser"):
					game.activate_dispenser(c)
			"dropper":
				if is_powered(world, c) and game != null and game.has_method("activate_dropper"):
					game.activate_dropper(c)
			"command_block":
				if is_powered(world, c) and game != null and game.has_method("run_command_block"):
					game.run_command_block(c)
			"piston", "sticky_piston":
				if is_powered(world, c):
					_try_extend_piston(game, world, renderer, c, id.begins_with("sticky"))
				else:
					_try_retract_piston(game, world, renderer, c, id.begins_with("sticky"))
			"repeater":
				if is_powered(world, c) or get_strength(c) > 0 or _input_powered(world, c):
					renderer.edit_block(c.x, c.y, c.z, "repeater_on")
			"repeater_on":
				if not (is_powered(world, c) or get_strength(c) > 0 or _input_powered(world, c)):
					# only turn off if no input
					if not _input_powered(world, c):
						renderer.edit_block(c.x, c.y, c.z, "repeater")
			"powered_rail":
				pass  # visual power later


static func piston_dir_from_meta(world, cell: Vector3i) -> Vector3i:
	# Meta stored as soft block above? Use game facing dict if present
	return Vector3i(1, 0, 0)


static func _piston_dir(game, cell: Vector3i) -> Vector3i:
	if game != null and game.get("piston_facing") is Dictionary:
		var fac = game.piston_facing
		if fac.has(cell):
			return fac[cell]
	return Vector3i(0, 1, 0)  # default: push up so head is visible


static func _set_blk(renderer, world, x: int, y: int, z: int, id: String) -> void:
	if renderer != null and renderer.has_method("edit_block"):
		renderer.edit_block(x, y, z, id)
	elif world != null:
		world.set_block(x, y, z, id)


static func _try_extend_piston(game, world, renderer, cell: Vector3i, sticky: bool) -> void:
	var dir = _piston_dir(game, cell)
	var head = cell + dir
	# The real world state is authoritative. A stale cache entry must never block
	# a new extension after an interrupted update.
	if game != null:
		if game.get("piston_extended") == null:
			game.piston_extended = {}
	var head_id = str(world.get_block(head.x, head.y, head.z))
	if head_id == "piston_head":
		if game != null:
			game.piston_extended[cell] = true
		return
	# Collect a Minecraft-style line of up to 12 movable blocks. Move it from the
	# far end backwards so no block is overwritten by the following one.
	var chain_cells: Array[Vector3i] = []
	var chain_ids: Array[String] = []
	var cursor = head
	var cursor_id = head_id
	while cursor_id != "air" and cursor_id != "water" and cursor_id != "lava":
		if cursor_id in ["bedrock", "obsidian", "piston_head"]:
			return
		if chain_cells.size() >= MAX_PISTON_PUSH:
			return
		chain_cells.append(cursor)
		chain_ids.append(cursor_id)
		cursor += dir
		cursor_id = str(world.get_block(cursor.x, cursor.y, cursor.z))
	for i in range(chain_cells.size() - 1, -1, -1):
		var from_cell: Vector3i = chain_cells[i]
		var destination = from_cell + dir
		_set_blk(renderer, world, destination.x, destination.y, destination.z, chain_ids[i])
	# Place head
	_set_blk(renderer, world, head.x, head.y, head.z, "piston_head")
	if game != null:
		if game.get("piston_extended") == null:
			game.piston_extended = {}
		game.piston_extended[cell] = true
		# remember dir for retract
		if game.get("piston_facing") == null:
			game.piston_facing = {}
		if not game.piston_facing.has(cell):
			game.piston_facing[cell] = dir


static func _try_retract_piston(game, world, renderer, cell: Vector3i, sticky: bool) -> void:
	var dir = _piston_dir(game, cell)
	var head = cell + dir
	var head_id = str(world.get_block(head.x, head.y, head.z))
	# Not extended / no head
	if head_id != "piston_head":
		# sticky may have left a pulled block where head was — still clear state
		if game != null and game.get("piston_extended") is Dictionary:
			game.piston_extended[cell] = false
		return
	if sticky:
		var pulled = head + dir
		var pid = str(world.get_block(pulled.x, pulled.y, pulled.z))
		if pid != "air" and pid != "water" and pid != "lava" and pid != "piston_head":
			# Pull block into the cell the head occupied
			_set_blk(renderer, world, head.x, head.y, head.z, pid)
			_set_blk(renderer, world, pulled.x, pulled.y, pulled.z, "air")
			if game != null:
				if game.get("piston_extended") == null:
					game.piston_extended = {}
				game.piston_extended[cell] = false
			return
	# Normal retract: remove head only (block stays pushed)
	_set_blk(renderer, world, head.x, head.y, head.z, "air")
	if game != null:
		if game.get("piston_extended") == null:
			game.piston_extended = {}
		game.piston_extended[cell] = false


static func _rebuild_powered_chunks(world, renderer, power_cells: Dictionary) -> void:
	if renderer == null or world == null:
		return
	var seen: Dictionary = {}
	for c in power_cells.keys():
		var cell: Vector3i = c
		var cx = int(floor(float(cell.x) / 16.0))
		var cz = int(floor(float(cell.z) / 16.0))
		var key = Vector2i(cx, cz)
		if seen.has(key):
			continue
		seen[key] = true
		if renderer.has_method("rebuild"):
			renderer.rebuild(cx, cz)
		elif renderer.has_method("rebuild_chunk"):
			renderer.rebuild_chunk(cx, cz)
