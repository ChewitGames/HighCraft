class_name VoxelWorld
extends RefCounted
# Holds all loaded chunks. Region edits are isolated per world_id and only
# applied from disk when Config.load_regions_from_disk is true (never on New World).

const CHUNK_SIZE = 16
const WORLD_BORDER: int = 60000
const WORLD_HEIGHT = 128
const SEA_LEVEL = 63

var chunks: Dictionary = {}
var generator
var edits: Dictionary = {}
var regions: RegionManager = null


func _init(p_generator) -> void:
	generator = p_generator
	var seed_val = 1337
	var world_id = ""
	var dimension_id = "overworld"
	var load_disk = false
	if p_generator != null and "seed_val" in p_generator:
		seed_val = int(p_generator.seed_val)
	if p_generator != null and "dimension" in p_generator:
		dimension_id = str(p_generator.dimension)
	# Prefer Config for isolation
	if Engine.get_main_loop() != null:
		var root = Engine.get_main_loop().root
		if root != null and root.has_node("Config"):
			var cfg = root.get_node("Config")
			seed_val = int(cfg.seed_val)
			world_id = str(cfg.world_id)
			load_disk = bool(cfg.load_regions_from_disk)
	if world_id == "":
		world_id = "seed_%d" % seed_val
	# Region coordinates repeat in every dimension. Sharing the same directory
	# lets edits at (cx, cz) from Heaven overwrite/apply to Overworld chunks.
	# Keep the historical Overworld path for save compatibility and isolate every
	# other dimension in its own namespace.
	if dimension_id != "overworld":
		world_id += "__" + dimension_id.replace("/", "_")
	regions = RegionManager.new()
	regions.setup(seed_val, world_id, load_disk)
	print("[VoxelWorld] seed=", seed_val, " world_id=", world_id, " dimension=", dimension_id, " load_disk=", load_disk)


func get_chunk(cx: int, cz: int) -> Chunk:
	var key = Vector2i(cx, cz)
	if not chunks.has(key):
		var c = Chunk.new(cx, cz)
		generator.generate(c)
		if regions != null:
			regions.apply_region_to_chunk(c)
		chunks[key] = c
	return chunks[key]


func get_block(x: int, y: int, z: int) -> String:
	if y < 0 or y >= WORLD_HEIGHT:
		return "air"
	var cx = floori(float(x) / CHUNK_SIZE)
	var cz = floori(float(z) / CHUNK_SIZE)
	var c = get_chunk(cx, cz)
	return c.get_local(x - cx * CHUNK_SIZE, y, z - cz * CHUNK_SIZE)


func get_block_no_gen(x: int, y: int, z: int) -> String:
	if y < 0 or y >= WORLD_HEIGHT:
		return "air"
	var cx = floori(float(x) / CHUNK_SIZE)
	var cz = floori(float(z) / CHUNK_SIZE)
	var key = Vector2i(cx, cz)
	if not chunks.has(key):
		# Missing neighbours are treated as open at the streaming frontier. Using
		# stone suppresses boundary faces and produces visible holes until the
		# neighbouring chunk has finished generating.
		return "air"
	var c = chunks[key]
	return c.get_local(x - cx * CHUNK_SIZE, y, z - cz * CHUNK_SIZE)


func set_block(x: int, y: int, z: int, id: String) -> void:
	if abs(x) > WORLD_BORDER or abs(z) > WORLD_BORDER:
		return
	if y < 0 or y >= WORLD_HEIGHT:
		return
	var cx = floori(float(x) / CHUNK_SIZE)
	var cz = floori(float(z) / CHUNK_SIZE)
	var c = get_chunk(cx, cz)
	var lx = x - cx * CHUNK_SIZE
	var lz = z - cz * CHUNK_SIZE
	c.set_local(lx, y, lz, id)
	edits[Vector3i(x, y, z)] = id
	if regions != null:
		regions.mark_edit(cx, cz, lx, y, lz, id)


func flush_regions() -> void:
	if regions != null:
		regions.flush_all()


func flush_next_region() -> bool:
	if regions != null:
		return regions.flush_next()
	return false


func evict_chunks_outside(center_x: int, center_z: int, radius: int) -> int:
	return evict_chunks_outside_centers([Vector2i(center_x, center_z)], radius)


func evict_chunks_outside_centers(centers: Array, radius: int) -> int:
	# Mesh nodes and raw Chunk data have separate lifetimes. Discard generated
	# block dictionaries only when no player's streaming cache needs them.
	var removed := 0
	for key in chunks.keys():
		var keep := false
		for center in centers:
			if abs(key.x - center.x) <= radius and abs(key.y - center.y) <= radius:
				keep = true
				break
		if not keep:
			chunks.erase(key)
			removed += 1
	return removed


func export_edits() -> Array:
	var out: Array = []
	for k in edits.keys():
		out.append([k.x, k.y, k.z, edits[k]])
	return out


func import_edits(arr: Array) -> void:
	for e in arr:
		if not (e is Array) or e.size() < 4:
			continue
		var x := int(e[0])
		var y := int(e[1])
		var z := int(e[2])
		var id := str(e[3])
		if y < 0 or y >= WORLD_HEIGHT:
			continue
		var cx := floori(float(x) / CHUNK_SIZE)
		var cz := floori(float(z) / CHUNK_SIZE)
		var lx := x - cx * CHUNK_SIZE
		var lz := z - cz * CHUNK_SIZE
		edits[Vector3i(x, y, z)] = id
		if regions != null:
			regions.mark_edit(cx, cz, lx, y, lz, id)
		var loaded_chunk = chunks.get(Vector2i(cx, cz), null)
		if loaded_chunk != null:
			loaded_chunk.set_local(lx, y, lz, id)


func surface_height(x: int, z: int) -> int:
	# Hell has a solid bedrock ceiling at y=120. It is not a walkable surface;
	# searching from world height spawned players and mobs on the Nether roof.
	var start_y := WORLD_HEIGHT - 1
	if generator != null and "dimension" in generator and str(generator.dimension) == "hell":
		start_y = 115
	for y in range(start_y, -1, -1):
		var b = get_block(x, y, z)
		if b != "air" and b != "water" and b != "lava":
			return y
	return 0
