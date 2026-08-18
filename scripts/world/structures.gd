class_name Structures
extends RefCounted
# Simple chunk-local structures: village huts on the overworld surface, a rare
# underground stronghold room containing an end portal, and the central End
# spike. Kept within one chunk to avoid cross-chunk seams (good enough for now;
# larger multi-chunk structures can come later).

const SEA_LEVEL = 63
const SIZE = 16


static func maybe_build_overworld(chunk, rng: RandomNumberGenerator, heights: Dictionary) -> void:
	if rng.randf() < 0.05:
		_build_hut(chunk, rng, heights)
	if rng.randf() < 0.015:
		_build_stronghold(chunk)


static func _build_hut(chunk, rng: RandomNumberGenerator, heights: Dictionary) -> void:
	var x = rng.randi_range(1, 9)
	var z = rng.randi_range(1, 9)
	var surface = heights.get(Vector2i(x, z), 0)
	if surface <= SEA_LEVEL:
		return
	for dx in range(0, 5):
		for dz in range(0, 5):
			var bx = x + dx
			var bz = z + dz
			if bx >= SIZE or bz >= SIZE:
				continue
			chunk.set_local(bx, surface, bz, "oak_planks")
			var edge = dx == 0 or dz == 0 or dx == 4 or dz == 4
			for dy in range(1, 4):
				if edge:
					chunk.set_local(bx, surface + dy, bz, "oak_planks")
				else:
					chunk.set_local(bx, surface + dy, bz, "air")
			chunk.set_local(bx, surface + 4, bz, "oak_planks")
	# door
	chunk.set_local(x + 2, surface + 1, z, "air")
	chunk.set_local(x + 2, surface + 2, z, "air")
	# a crafting table inside
	chunk.set_local(x + 2, surface + 1, z + 2, "crafting_table")


static func _build_stronghold(chunk) -> void:
	var x = 4
	var z = 4
	var y = 16
	for dx in range(0, 7):
		for dz in range(0, 7):
			for dy in range(0, 5):
				var bx = x + dx
				var bz = z + dz
				if bx >= SIZE or bz >= SIZE:
					continue
				var edge = (dx == 0 or dz == 0 or dx == 6 or dz == 6
					or dy == 0 or dy == 4)
				if edge:
					chunk.set_local(bx, y + dy, bz, "stone")
				else:
					chunk.set_local(bx, y + dy, bz, "air")
	# end portal pad in the centre
	for px in range(x + 2, x + 5):
		for pz in range(z + 2, z + 5):
			chunk.set_local(px, y + 1, pz, "end_portal")


static func build_end_spike(chunk) -> void:
	# obsidian pillar near the centre of the End island
	var x = 8
	var z = 8
	for y in range(53, 70):
		chunk.set_local(x, y, z, "obsidian")
