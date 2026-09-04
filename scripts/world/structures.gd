class_name Structures
extends RefCounted
## Real-ish structures kept mostly within one chunk (16×16) for seam safety.
## Overworld: village, caves, stronghold+library, mineshaft
## Nether: fortress corridors + blaze platform + nether wart
## End: proper towers with platforms
## Heaven: cloud villages

const SEA_LEVEL = 63
const SIZE = 16


static func maybe_build_overworld(chunk, rng: RandomNumberGenerator, heights: Dictionary) -> void:
	if rng.randf() < 0.07:
		_build_village(chunk, rng, heights)
	if rng.randf() < 0.018:
		_build_stronghold(chunk, rng)
	if rng.randf() < 0.028:
		_build_mineshaft(chunk, rng)
	if rng.randf() < 0.14:
		_build_cave_system(chunk, rng, heights)


static func maybe_build_nether(chunk, rng: RandomNumberGenerator) -> void:
	if rng.randf() < 0.16:
		_build_nether_fortress(chunk, rng)


static func maybe_build_end(chunk, rng: RandomNumberGenerator) -> void:
	# Towers only on the main island, never floating in the void
	var wx = chunk.cx * SIZE + 8
	var wz = chunk.cz * SIZE + 8
	if Vector2(wx, wz).length() > 48.0:
		return
	if rng.randf() < 0.35:
		_build_end_tower(chunk, rng)


static func maybe_build_heaven(chunk, rng: RandomNumberGenerator, heights: Dictionary = {}) -> void:
	if rng.randf() < 0.07:
		_build_heaven_village(chunk, rng)


static func _in(x: int, z: int) -> bool:
	return x >= 0 and x < SIZE and z >= 0 and z < SIZE


static func _put(chunk, x: int, y: int, z: int, id: String) -> void:
	if _in(x, z) and y >= 0 and y < 128:
		chunk.set_local(x, y, z, id)


# ---------------------------------------------------------------------------
# OVERWORLD — Village (several houses + path + farm)
# ---------------------------------------------------------------------------
static func _build_village(chunk, rng: RandomNumberGenerator, heights: Dictionary) -> void:
	var ox = rng.randi_range(1, 4)
	var oz = rng.randi_range(1, 4)
	var surface = heights.get(Vector2i(ox + 4, oz + 4), SEA_LEVEL + 4)
	if surface <= SEA_LEVEL:
		return
	# Path
	for t in range(0, 12):
		_put(chunk, ox + t, surface, oz + 5, "cobblestone")
		_put(chunk, ox + t, surface, oz + 6, "cobblestone")
	# House A + B with real doors
	_house(chunk, ox, oz, surface, "oak_planks", "oak_log", "oak_stairs")
	_house(chunk, ox + 7, oz, surface, "cobblestone", "oak_log", "cobblestone_stairs")
	# Blacksmith
	_blacksmith(chunk, ox, oz + 8, surface)
	# Church
	_church(chunk, ox + 8, oz + 8, surface)
	# Farm plot
	for fx in range(ox, ox + 5):
		for fz in range(oz + 8, oz + 12):
			if not _in(fx, fz):
				continue
			_put(chunk, fx, surface - 1, fz, "farmland_moist" if rng.randf() < 0.5 else "farmland")
			_put(chunk, fx, surface, fz, "wheat_3" if rng.randf() < 0.4 else "wheat_1")
	# Water for farm
	_put(chunk, ox + 2, surface - 1, oz + 10, "water")
	# Well
	for wx in range(ox + 9, ox + 12):
		for wz in range(oz + 8, oz + 11):
			_put(chunk, wx, surface, wz, "cobblestone")
	_put(chunk, ox + 10, surface, oz + 9, "water")
	_put(chunk, ox + 10, surface + 1, oz + 9, "air")


static func _house(chunk, ox: int, oz: int, surface: int, wall: String, log: String, stairs: String) -> void:
	for dx in range(0, 6):
		for dz in range(0, 5):
			var bx = ox + dx
			var bz = oz + dz
			if not _in(bx, bz):
				continue
			_put(chunk, bx, surface, bz, wall)
			var edge = dx == 0 or dz == 0 or dx == 5 or dz == 4
			for dy in range(1, 4):
				if edge:
					_put(chunk, bx, surface + dy, bz, wall if dy < 3 else log)
				else:
					_put(chunk, bx, surface + dy, bz, "air")
			# Roof
			_put(chunk, bx, surface + 4, bz, stairs if edge else wall)
	# Door (actual door block)
	_put(chunk, ox + 2, surface + 1, oz, "door_oak")
	_put(chunk, ox + 2, surface + 2, oz, "air")
	# Windows
	_put(chunk, ox, surface + 2, oz + 2, "glass")
	_put(chunk, ox + 5, surface + 2, oz + 2, "glass")
	# Furniture
	_put(chunk, ox + 1, surface + 1, oz + 2, "crafting_table")
	_put(chunk, ox + 3, surface + 1, oz + 3, "chest")


# ---------------------------------------------------------------------------
# OVERWORLD — Cave system (worm tunnels)
# ---------------------------------------------------------------------------
static func _blacksmith(chunk, ox: int, oz: int, surface: int) -> void:
	for dx in range(0, 5):
		for dz in range(0, 5):
			if not _in(ox + dx, oz + dz):
				continue
			_put(chunk, ox + dx, surface, oz + dz, "cobblestone")
			var edge = dx == 0 or dz == 0 or dx == 4 or dz == 4
			for dy in range(1, 4):
				_put(chunk, ox + dx, surface + dy, oz + dz, "cobblestone" if edge else "air")
	_put(chunk, ox + 2, surface + 1, oz, "door_oak")
	_put(chunk, ox + 1, surface + 1, oz + 2, "furnace")
	_put(chunk, ox + 3, surface + 1, oz + 2, "lava")
	_put(chunk, ox + 2, surface + 1, oz + 3, "anvil")


static func _church(chunk, ox: int, oz: int, surface: int) -> void:
	for dx in range(0, 5):
		for dz in range(0, 6):
			if not _in(ox + dx, oz + dz):
				continue
			_put(chunk, ox + dx, surface, oz + dz, "stone_bricks")
			var edge = dx == 0 or dz == 0 or dx == 4 or dz == 5
			for dy in range(1, 5):
				_put(chunk, ox + dx, surface + dy, oz + dz, "stone_bricks" if edge else "air")
	_put(chunk, ox + 2, surface + 1, oz, "door_oak")
	_put(chunk, ox + 2, surface + 5, oz + 2, "stone_bricks")
	_put(chunk, ox + 2, surface + 6, oz + 2, "stone_bricks")
	_put(chunk, ox + 2, surface + 1, oz + 3, "enchanting_table")


static func _build_cave_system(chunk, rng: RandomNumberGenerator, heights: Dictionary) -> void:
	var x = rng.randi_range(2, 13)
	var z = rng.randi_range(2, 13)
	var surface = int(heights.get(Vector2i(x, z), SEA_LEVEL + 8))
	# Mouth opens at the surface so caves are visible from above
	var y = surface
	for step in range(28):
		var r = rng.randi_range(1, 2)
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				for dz in range(-r, r + 1):
					if dx * dx + dy * dy + dz * dz <= r * r + 1:
						_put(chunk, x + dx, y + dy, z + dz, "air")
		x += rng.randi_range(-1, 1)
		y += rng.randi_range(-2, 0) if step < 10 else rng.randi_range(-1, 1)
		z += rng.randi_range(-1, 1)
		x = clampi(x, 1, 14)
		y = clampi(y, 5, surface)
		z = clampi(z, 1, 14)
	# Occasional ore pocket
	if rng.randf() < 0.4:
		_put(chunk, x, y, z, "coal_ore")
		_put(chunk, x + 1, y, z, "iron_ore")


# ---------------------------------------------------------------------------
# OVERWORLD — Stronghold + library + portal room
# ---------------------------------------------------------------------------
static func _build_stronghold(chunk, rng: RandomNumberGenerator) -> void:
	var base = rng.randi_range(12, 22)
	# Main hall
	for x in range(2, 14):
		for z in range(2, 14):
			_put(chunk, x, base, z, "stone_bricks")
			for y in range(base + 1, base + 6):
				var edge = x == 2 or x == 13 or z == 2 or z == 13
				if edge:
					_put(chunk, x, y, z, "mossy_stone_bricks" if rng.randf() < 0.3 else "stone_bricks")
				else:
					_put(chunk, x, y, z, "air")
			_put(chunk, x, base + 6, z, "stone_bricks")
	# Library wing
	for x in range(3, 8):
		for z in range(3, 7):
			for y in range(base + 1, base + 5):
				if x == 3 or x == 7 or z == 3 or z == 6:
					_put(chunk, x, y, z, "bookshelf")
				else:
					_put(chunk, x, y, z, "air")
	_put(chunk, 5, base + 1, 4, "crafting_table")
	_put(chunk, 5, base + 1, 5, "chest")
	# Corridor to portal
	for z in range(7, 12):
		_put(chunk, 9, base + 1, z, "air")
		_put(chunk, 10, base + 1, z, "air")
		_put(chunk, 9, base + 2, z, "air")
		_put(chunk, 10, base + 2, z, "air")
	# End portal frame room
	for x in range(8, 13):
		for z in range(10, 14):
			_put(chunk, x, base + 1, z, "air")
			_put(chunk, x, base + 2, z, "air")
	# Real 12-frame ring (empty until Eyes of Ender)
	for i in range(1, 4):
		_put(chunk, 8 + i, base + 1, 10, "end_portal_frame")
		_put(chunk, 8 + i, base + 1, 14, "end_portal_frame")
		_put(chunk, 8, base + 1, 10 + i, "end_portal_frame")
		_put(chunk, 12, base + 1, 10 + i, "end_portal_frame")
	for ix in range(9, 12):
		for iz in range(11, 14):
			_put(chunk, ix, base + 1, iz, "air")
	# Iron bars cage feel
	_put(chunk, 9, base + 3, 11, "iron_bars")
	_put(chunk, 12, base + 3, 13, "iron_bars")


# ---------------------------------------------------------------------------
# OVERWORLD — Mineshaft
# ---------------------------------------------------------------------------
static func _build_mineshaft(chunk, rng: RandomNumberGenerator) -> void:
	var y = rng.randi_range(10, 28)
	# Main tunnel NS
	for z in range(1, 15):
		for x in range(6, 10):
			_put(chunk, x, y, z, "air")
			_put(chunk, x, y + 1, z, "air")
			_put(chunk, x, y + 2, z, "air")
		# Supports
		if z % 4 == 0:
			_put(chunk, 6, y, z, "oak_log")
			_put(chunk, 9, y, z, "oak_log")
			_put(chunk, 6, y + 1, z, "oak_log")
			_put(chunk, 9, y + 1, z, "oak_log")
			_put(chunk, 6, y + 2, z, "oak_planks")
			_put(chunk, 7, y + 2, z, "oak_planks")
			_put(chunk, 8, y + 2, z, "oak_planks")
			_put(chunk, 9, y + 2, z, "oak_planks")
		# Rails
		_put(chunk, 7, y, z, "rail")
		_put(chunk, 8, y, z, "rail")
	# Side branch
	for x in range(2, 7):
		_put(chunk, x, y, 8, "air")
		_put(chunk, x, y + 1, 8, "air")
		_put(chunk, x, y, 9, "air")
		_put(chunk, x, y + 1, 9, "air")
	_put(chunk, 3, y, 8, "chest")
	_put(chunk, 4, y + 1, 8, "cobweb")
	_put(chunk, 5, y + 2, 9, "cobweb")
	if rng.randf() < 0.5:
		_put(chunk, 2, y, 8, "rail")


# ---------------------------------------------------------------------------
# NETHER — Fortress (corridors, stairs, wart garden, blaze platform)
# ---------------------------------------------------------------------------
static func _build_nether_fortress(chunk, rng: RandomNumberGenerator) -> void:
	# Sit the fortress on existing netherrack instead of floating in the cavern
	var ground = 40
	for y in range(80, 8, -1):
		if str(chunk.get_local(8, y, 8)) == "netherrack":
			ground = y
			break
	var base = clampi(ground, 20, 90)
	var nb = "nether_bricks"
	var st = "nether_brick_stairs"
	# Main corridor X
	for x in range(1, 15):
		for z in range(6, 10):
			_put(chunk, x, base, z, nb)
			for y in range(base + 1, base + 5):
				if z == 6 or z == 9:
					_put(chunk, x, y, z, nb)
				else:
					_put(chunk, x, y, z, "air")
			_put(chunk, x, base + 5, z, nb)
		# Fence battlements
		if x % 2 == 0:
			_put(chunk, x, base + 6, 6, nb)
			_put(chunk, x, base + 6, 9, nb)
	# Cross corridor Z
	for z in range(1, 15):
		for x in range(6, 10):
			_put(chunk, x, base, z, nb)
			for y in range(base + 1, base + 5):
				if x == 6 or x == 9:
					_put(chunk, x, y, z, nb)
				else:
					_put(chunk, x, y, z, "air")
	# Stair flight
	for i in range(0, 5):
		_put(chunk, 3, base + i, 3 + i, st)
		_put(chunk, 4, base + i, 3 + i, st)
		_put(chunk, 3, base + i + 1, 3 + i, "air")
	# Blaze platform
	for x in range(11, 15):
		for z in range(11, 15):
			_put(chunk, x, base + 1, z, nb)
			_put(chunk, x, base + 2, z, "air")
	_put(chunk, 12, base + 2, 12, "glowstone")
	_put(chunk, 13, base + 2, 13, "glowstone")
	# Nether wart garden on soul sand
	for x in range(2, 6):
		for z in range(11, 15):
			_put(chunk, x, base, z, "soul_sand")
			_put(chunk, x, base + 1, z, "nether_wart")
	# Lava moat bit
	_put(chunk, 1, base - 1, 7, "lava")
	_put(chunk, 1, base - 1, 8, "lava")


# ---------------------------------------------------------------------------
# END — Real tower (obsidian pillars with end stone base + crystal top)
# ---------------------------------------------------------------------------
static func _build_end_tower(chunk, rng: RandomNumberGenerator) -> void:
	var cx = rng.randi_range(5, 10)
	var cz = rng.randi_range(5, 10)
	# Find real island top; skip if this column is void
	var base_y = -1
	for y in range(70, 40, -1):
		if str(chunk.get_local(cx, y, cz)) == "end_stone":
			base_y = y
			break
	if base_y < 0:
		return
	var height = rng.randi_range(14, 22)
	# Wide end-stone footing
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			_put(chunk, cx + dx, base_y, cz + dz, "end_stone")
			_put(chunk, cx + dx, base_y - 1, cz + dz, "end_stone")
	# Obsidian pillar
	for y in range(base_y + 1, base_y + height):
		_put(chunk, cx, y, cz, "obsidian")
		_put(chunk, cx + 1, y, cz, "obsidian")
		_put(chunk, cx, y, cz + 1, "obsidian")
		if y % 4 == 0:
			_put(chunk, cx - 1, y, cz, "end_stone_bricks")
			_put(chunk, cx + 2, y, cz, "end_stone_bricks")
	# Platform top
	for dx in range(-1, 3):
		for dz in range(-1, 3):
			_put(chunk, cx + dx, base_y + height, cz + dz, "end_stone")
	# Bedrock + crystal stand-in (glowstone as end crystal base)
	_put(chunk, cx, base_y + height + 1, cz, "bedrock")
	_put(chunk, cx, base_y + height + 2, cz, "end_crystal")
	# Small purpur balcony
	_put(chunk, cx + 2, base_y + height - 3, cz, "purpur_block")
	_put(chunk, cx - 1, base_y + height - 3, cz, "purpur_block")


# ---------------------------------------------------------------------------
# HEAVEN — Cloud village
# ---------------------------------------------------------------------------
static func _build_heaven_village(chunk, rng: RandomNumberGenerator) -> void:
	var surface = 70
	# Cloud platform
	for x in range(2, 14):
		for z in range(2, 14):
			_put(chunk, x, surface, z, "cloud_wool" if rng.randf() < 0.75 else "quartz_block")
	_house(chunk, 3, 3, surface, "quartz_block", "oak_log", "quartz_stairs")
	_house(chunk, 9, 3, surface, "quartz_block", "oak_log", "quartz_stairs")
	# Center fountain
	_put(chunk, 7, surface + 1, 8, "water")
	_put(chunk, 8, surface + 1, 8, "water")


static func build_end_spike(chunk) -> void:
	# Central exit portal podium at 0,0
	for x in range(5, 11):
		for z in range(5, 11):
			_put(chunk, x, 54, z, "obsidian")
	for y in range(55, 58):
		_put(chunk, 5, y, 5, "obsidian")
		_put(chunk, 10, y, 5, "obsidian")
		_put(chunk, 5, y, 10, "obsidian")
		_put(chunk, 10, y, 10, "obsidian")
	# Central exit podium always exists; frames + interior appear after the dragon dies
	_put(chunk, 7, 55, 7, "air")
	_put(chunk, 8, 55, 7, "air")
	_put(chunk, 7, 55, 8, "air")
	_put(chunk, 8, 55, 8, "air")
	_put(chunk, 8, 56, 5, "end_crystal")
	_put(chunk, 8, 56, 11, "end_crystal")
	_put(chunk, 5, 56, 8, "end_crystal")
	_put(chunk, 11, 56, 8, "end_crystal")
