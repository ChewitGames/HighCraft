class_name Redstone
extends RefCounted
# Minecraft 1.6.4-style redstone: signal strength 0–15, wires, torches,
# repeaters, comparators (basic), quasi-connectivity for pistons.

const MAX_WIRE_STEPS := 512
const MAX_STRENGTH := 15

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
	_compute_power(world, origin)

	# Update repeater visual on/off near network
	var check: Dictionary = {}
	check[origin] = true
	for n in neighbors(origin):
		check[n] = true
	for c in _power.keys():
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


static func _try_extend_piston(game, world, renderer, cell: Vector3i, sticky: bool) -> void:
	var dir = Vector3i(1, 0, 0)
	if game != null and game.get("piston_facing") != null:
		var fac = game.piston_facing
		if fac is Dictionary and fac.has(cell):
			dir = fac[cell]
	var head = cell + dir
	var push = head + dir
	var head_id = world.get_block(head.x, head.y, head.z)
	if head_id == "piston_head":
		return
	if head_id != "air" and head_id != "water":
		var beyond = world.get_block(push.x, push.y, push.z)
		if beyond != "air" and beyond != "water":
			return
		if renderer:
			renderer.edit_block(push.x, push.y, push.z, head_id)
		else:
			world.set_block(push.x, push.y, push.z, head_id)
	if renderer:
		renderer.edit_block(head.x, head.y, head.z, "piston_head")
	else:
		world.set_block(head.x, head.y, head.z, "piston_head")


static func _try_retract_piston(game, world, renderer, cell: Vector3i, sticky: bool) -> void:
	var dir = Vector3i(1, 0, 0)
	if game != null and game.get("piston_facing") != null:
		var fac = game.piston_facing
		if fac is Dictionary and fac.has(cell):
			dir = fac[cell]
	var head = cell + dir
	var head_id = world.get_block(head.x, head.y, head.z)
	if head_id != "piston_head":
		return
	if renderer:
		renderer.edit_block(head.x, head.y, head.z, "air")
	else:
		world.set_block(head.x, head.y, head.z, "air")
	if sticky:
		var pull = head + dir
		var pulled = world.get_block(pull.x, pull.y, pull.z)
		if pulled != "air" and pulled != "water" and pulled != "bedrock" and pulled != "obsidian":
			if renderer:
				renderer.edit_block(head.x, head.y, head.z, pulled)
				renderer.edit_block(pull.x, pull.y, pull.z, "air")
			else:
				world.set_block(head.x, head.y, head.z, pulled)
				world.set_block(pull.x, pull.y, pull.z, "air")
