class_name VoxelWorld
extends RefCounted
# Holds all loaded chunks and answers block queries in world coordinates.
# Generation is delegated to a swappable generator (TerrainGenerator) so the
# heavy lifting can later move to a GDExtension / Rust module behind the same
# interface.

const CHUNK_SIZE = 16
# Soft world border (~Minecraft-style). Beyond this, blocks are void / not placeable.
# ~±60k blocks ≈ area supporting on the order of 10^9–10^10 block cells with height.
const WORLD_BORDER: int = 60000
const WORLD_HEIGHT = 128
const SEA_LEVEL = 63

var chunks: Dictionary = {}   # Vector2i -> Chunk
var generator
var edits: Dictionary = {}    # Vector3i -> block id (player edits, for saving)


func _init(p_generator) -> void:
	generator = p_generator


func get_chunk(cx: int, cz: int) -> Chunk:
	var key = Vector2i(cx, cz)
	if not chunks.has(key):
		var c = Chunk.new(cx, cz)
		generator.generate(c)   # ← teure Terrain-Generierung!
		chunks[key] = c
	return chunks[key]


func get_block(x: int, y: int, z: int) -> String:
	if y < 0 or y >= WORLD_HEIGHT:
		return "air"
	var cx = floori(float(x) / CHUNK_SIZE)
	var cz = floori(float(z) / CHUNK_SIZE)
	var c = get_chunk(cx, cz)
	return c.get_local(x - cx * CHUNK_SIZE, y, z - cz * CHUNK_SIZE)

# NEU: wie get_block, aber generiert NIE einen neuen Chunk.
# Für Meshing gedacht, damit Randprüfungen keine Chunk-Generierung auslösen.
func get_block_no_gen(x: int, y: int, z: int) -> String:
	if y < 0 or y >= WORLD_HEIGHT:
		return "air"
	var cx = floori(float(x) / CHUNK_SIZE)
	var cz = floori(float(z) / CHUNK_SIZE)
	var key = Vector2i(cx, cz)
	if not chunks.has(key):
		return "stone"
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
	c.set_local(x - cx * CHUNK_SIZE, y, z - cz * CHUNK_SIZE, id)
	edits[Vector3i(x, y, z)] = id


func export_edits() -> Array:
	var out: Array = []
	for k in edits.keys():
		out.append([k.x, k.y, k.z, edits[k]])
	return out


func import_edits(arr: Array) -> void:
	for e in arr:
		set_block(int(e[0]), int(e[1]), int(e[2]), e[3])


func surface_height(x: int, z: int) -> int:
	for y in range(WORLD_HEIGHT - 1, -1, -1):
		var b = get_block(x, y, z)
		if b != "air" and b != "water" and b != "lava":
			return y
	return 0
