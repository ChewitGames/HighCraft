class_name TerrainGenerator
extends RefCounted
# Generates chunk terrain: layered noise heightmap, bedrock floor, stone body,
# dirt cap, grass/sand surface, water up to sea level, depth-based ore veins,
# and oak trees. Uses Godot's built-in FastNoiseLite (no external deps).

const CHUNK_SIZE = 16
const WORLD_HEIGHT = 128
const SEA_LEVEL = 63

# ore_id -> [min_y, max_y, veins_per_chunk, vein_size]
const ORES = {
	"coal_ore": [5, 110, 12, 8],
	"copper_ore": [5, 90, 8, 6],
	"iron_ore": [5, 64, 8, 5],
	"gold_ore": [5, 32, 3, 4],
	"redstone_ore": [5, 20, 4, 5],
	"lapis_ore": [12, 30, 2, 4],
	"diamond_ore": [5, 16, 2, 4],
	"emerald_ore": [5, 30, 1, 2]
}

var seed_val: int = 0
var world_type: String = "normal"
var dimension: String = "overworld"
var structures_enabled: bool = true
var _noise: FastNoiseLite
var _noise2: FastNoiseLite
var _biome_noise: FastNoiseLite
var _moisture_noise: FastNoiseLite
var _cave_noise: FastNoiseLite
var _cave_noise2: FastNoiseLite


func _init(p_seed: int = 0, p_world_type: String = "normal",
		p_dimension: String = "overworld") -> void:
	seed_val = p_seed
	world_type = p_world_type
	dimension = p_dimension
	_noise = FastNoiseLite.new()
	_noise.seed = p_seed
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = 0.012
	_noise2 = FastNoiseLite.new()
	_noise2.seed = p_seed + 7
	_noise2.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise2.frequency = 0.03
	_biome_noise = FastNoiseLite.new()
	_biome_noise.seed = p_seed + 41
	_biome_noise.frequency = 0.0035
	_moisture_noise = FastNoiseLite.new()
	_moisture_noise.seed = p_seed + 97
	_moisture_noise.frequency = 0.0045
	_cave_noise = FastNoiseLite.new()
	_cave_noise.seed = p_seed + 131
	_cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_cave_noise.frequency = 0.030
	_cave_noise2 = FastNoiseLite.new()
	_cave_noise2.seed = p_seed + 277
	_cave_noise2.noise_type = FastNoiseLite.TYPE_PERLIN
	_cave_noise2.frequency = 0.011


func biome_at(wx: int, wz: int) -> String:
	if dimension != "overworld":
		return dimension
	var temperature := _biome_noise.get_noise_2d(wx, wz)
	var moisture := _moisture_noise.get_noise_2d(wx, wz)
	if temperature < -0.48:
		return "ice"
	if temperature < -0.18:
		return "snow"
	if temperature > 0.42 and moisture < 0.18:
		return "desert"
	if moisture > 0.25:
		return "spruce_forest"
	return "overworld"


func height_at(wx: int, wz: int) -> int:
	var n = _noise.get_noise_2d(wx, wz) * 0.8 + _noise2.get_noise_2d(wx, wz) * 0.2
	var h = int(SEA_LEVEL + n * 28.0)
	return clampi(h, 2, WORLD_HEIGHT - 20)


func generate(chunk) -> void:
	if world_type == "flat":
		_generate_flat(chunk)
	elif dimension == "hell":
		_generate_hell(chunk)
	elif dimension == "the_end":
		_generate_end(chunk)
	elif dimension == "heaven":
		_generate_heaven(chunk)
	elif dimension == "red_dimension":
		_generate_red_dimension(chunk)
	else:
		_generate_normal(chunk)
	chunk.generated = true


func _generate_hell(chunk) -> void:
	var base_x = chunk.cx * CHUNK_SIZE
	var base_z = chunk.cz * CHUNK_SIZE
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(seed_val, chunk.cx, chunk.cz))
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			var n = (_noise.get_noise_2d(base_x + x, base_z + z) + 1.0) * 0.5
			var h = 36 + int(n * 26.0)
			chunk.set_local(x, 0, z, "bedrock")
			for y in range(1, h):
				chunk.set_local(x, y, z, "netherrack")
			if rng.randf() < 0.06:
				chunk.set_local(x, h, z, "glowstone")
			elif rng.randf() < 0.08:
				chunk.set_local(x, h, z, "soul_sand")
			chunk.set_local(x, 120, z, "bedrock")
			# Lava sea in the lower caverns
			for y in range(24, 32):
				if str(chunk.get_local(x, y, z)) == "air":
					chunk.set_local(x, y, z, "lava")
			if h < 32:
				chunk.set_local(x, 31, z, "lava")
	if structures_enabled:
		Structures.maybe_build_nether(chunk, rng)


func _generate_end(chunk) -> void:
	var base_x = chunk.cx * CHUNK_SIZE
	var base_z = chunk.cz * CHUNK_SIZE
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			var wx = base_x + x
			var wz = base_z + z
			var d = Vector2(wx, wz).length()
			if d >= 58.0:
				continue
			var n = _noise.get_noise_2d(wx, wz)
			var top = 52 + int(n * 4.0)
			for y in range(top - 6, top + 1):
				if y > 0:
					chunk.set_local(x, y, z, "end_stone")
	if chunk.cx == 0 and chunk.cz == 0:
		Structures.build_end_spike(chunk)
	var erng = RandomNumberGenerator.new()
	erng.seed = hash(Vector3i(seed_val, chunk.cx, chunk.cz))
	if structures_enabled:
		Structures.maybe_build_end(chunk, erng)


func _generate_heaven(chunk) -> void:
	var base_x = chunk.cx * CHUNK_SIZE
	var base_z = chunk.cz * CHUNK_SIZE
	var hrng = RandomNumberGenerator.new()
	hrng.seed = hash(Vector3i(seed_val, chunk.cx, chunk.cz))
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			var n = _noise2.get_noise_2d(base_x + x, base_z + z)
			if n > 0.12:
				for y in range(68, 72):
					chunk.set_local(x, y, z, "cloud_wool")
	if structures_enabled:
		Structures.maybe_build_heaven(chunk, hrng)


func _generate_flat(chunk) -> void:
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			chunk.set_local(x, 0, z, "bedrock")
			for y in range(1, 4):
				chunk.set_local(x, y, z, "dirt")
			chunk.set_local(x, 4, z, "grass_block")


func _generate_red_dimension(chunk) -> void:
	# Familiar terrain under a permanent clear deep-blue sky.
	_generate_normal(chunk)


func _generate_normal(chunk) -> void:
	var base_x = chunk.cx * CHUNK_SIZE
	var base_z = chunk.cz * CHUNK_SIZE
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(seed_val, chunk.cx, chunk.cz))
	var heights = {}

	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			var h = height_at(base_x + x, base_z + z)
			heights[Vector2i(x, z)] = h
			chunk.set_local(x, 0, z, "bedrock")
			for y in range(1, 3):
				if rng.randf() < 0.5:
					chunk.set_local(x, y, z, "bedrock")
				else:
					chunk.set_local(x, y, z, "stone")
			for y in range(3, h - 3):
				chunk.set_local(x, y, z, "stone")
			for y in range(maxi(3, h - 3), h):
				chunk.set_local(x, y, z, "dirt")
			var biome := biome_at(base_x + x, base_z + z)
			var near_water = h <= SEA_LEVEL + 1
			if biome == "desert" or near_water:
				chunk.set_local(x, h, z, "sand")
				if biome == "desert":
					for sy in range(maxi(3, h - 3), h):
						chunk.set_local(x, sy, z, "sandstone")
			elif biome == "ice":
				chunk.set_local(x, h, z, "snow_block")
			elif biome == "snow":
				chunk.set_local(x, h, z, "snow_block")
			else:
				chunk.set_local(x, h, z, "grass_block")
			for y in range(h + 1, SEA_LEVEL):
				chunk.set_local(x, y, z, "ice" if biome in ["ice", "snow"] and y == SEA_LEVEL - 1 else "water")

	_place_ores(chunk, rng, heights)
	_carve_caves(chunk, heights)
	_place_trees(chunk, rng, heights)
	if structures_enabled:
		Structures.maybe_build_overworld(chunk, rng, heights, biome_at(base_x + 8, base_z + 8))


# ore_id -> [min_y, max_y, chance per cave-wall block]
# Rare ore is exposed in cave walls so caving is the rewarding way to mine.
const CAVE_ORES = {
	"coal_ore": [5, 100, 0.006],
	"copper_ore": [5, 80, 0.004],
	"iron_ore": [5, 60, 0.005],
	"gold_ore": [5, 32, 0.0025],
	"redstone_ore": [5, 18, 0.0025],
	"lapis_ore": [10, 30, 0.0015],
	"diamond_ore": [5, 15, 0.0012],
	"emerald_ore": [5, 28, 0.0008],
}

const _CAVE_NEIGHBOURS = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


func _carve_caves(chunk, heights: Dictionary) -> void:
	# 3D noise carves a connected network of winding tunnels and caverns. A
	# second, slower noise modulates the tunnel radius so caves vary in size
	# and shape instead of being a single straight hole.
	var base_x = chunk.cx * CHUNK_SIZE
	var base_z = chunk.cz * CHUNK_SIZE
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(seed_val + 53, chunk.cx, chunk.cz))
	var carved: Array[Vector3i] = []
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			var surface = heights[Vector2i(x, z)]
			if surface <= 6:
				continue
			for y in range(5, surface - 2):
				if chunk.get_local(x, y, z) != "stone":
					continue
				var wx = base_x + x
				var wz = base_z + z
				var n = _cave_noise.get_noise_3d(wx, y, wz)
				var radius = 0.016 + (_cave_noise2.get_noise_3d(wx, y, wz) + 1.0) * 0.034
				if abs(n) < radius:
					chunk.set_local(x, y, z, "air")
					carved.append(Vector3i(x, y, z))
	# Ore veins, loot chests, lava pools and cobwebs dress the cave walls so
	# caves have contents worth exploring for.
	for c in carved:
		for d in _CAVE_NEIGHBOURS:
			var p = c + d
			if p.x < 0 or p.x >= CHUNK_SIZE or p.z < 0 or p.z >= CHUNK_SIZE:
				continue
			if p.y <= 0 or p.y >= WORLD_HEIGHT:
				continue
			if chunk.get_local(p.x, p.y, p.z) != "stone":
				continue
			for ore in CAVE_ORES:
				var cfg = CAVE_ORES[ore]
				if p.y >= cfg[0] and p.y <= cfg[1] and rng.randf() < cfg[2]:
					chunk.set_local(p.x, p.y, p.z, ore)
					break
		if rng.randf() < 0.0004:
			chunk.set_local(c.x, c.y, c.z, "chest")
		elif c.y <= 14 and rng.randf() < 0.01:
			chunk.set_local(c.x, c.y, c.z, "lava")
		elif rng.randf() < 0.004:
			chunk.set_local(c.x, c.y, c.z, "cobweb")


func _place_ores(chunk, rng: RandomNumberGenerator, heights: Dictionary) -> void:
	for ore_id in ORES.keys():
		var cfg = ORES[ore_id]
		var ymin = cfg[0]
		var ymax = cfg[1]
		var veins = cfg[2]
		var size = cfg[3]
		for v in range(veins):
			var x = rng.randi_range(0, CHUNK_SIZE - 1)
			var z = rng.randi_range(0, CHUNK_SIZE - 1)
			var surface = heights[Vector2i(x, z)]
			var top = mini(ymax, surface - 2)
			if top <= ymin:
				continue
			var cy = rng.randi_range(ymin, top)
			for s in range(size):
				var ox = x + rng.randi_range(-1, 1)
				var oy = cy + rng.randi_range(-1, 1)
				var oz = z + rng.randi_range(-1, 1)
				if ox >= 0 and ox < CHUNK_SIZE and oz >= 0 and oz < CHUNK_SIZE and oy >= 1 and oy < surface - 1:
					if chunk.get_local(ox, oy, oz) == "stone":
						chunk.set_local(ox, oy, oz, ore_id)


func _place_trees(chunk, rng: RandomNumberGenerator, heights: Dictionary) -> void:
	var attempts = rng.randi_range(0, 4)
	for a in range(attempts):
		var x = rng.randi_range(2, CHUNK_SIZE - 3)
		var z = rng.randi_range(2, CHUNK_SIZE - 3)
		var surface = heights[Vector2i(x, z)]
		var biome := biome_at(chunk.cx * CHUNK_SIZE + x, chunk.cz * CHUNK_SIZE + z)
		if biome in ["desert", "ice"]:
			continue
		if surface <= SEA_LEVEL + 1:
			continue
		if chunk.get_local(x, surface, z) != "grass_block":
			continue
		var trunk = rng.randi_range(4, 6)
		var top = surface + trunk
		for ly in range(top - 2, top + 1):
			var radius = 2
			if ly >= top:
				radius = 1
			for lx in range(x - radius, x + radius + 1):
				for lz in range(z - radius, z + radius + 1):
					if lx >= 0 and lx < CHUNK_SIZE and lz >= 0 and lz < CHUNK_SIZE:
						if chunk.get_local(lx, ly, lz) == "air":
							chunk.set_local(lx, ly, lz, "oak_leaves")
		for ty in range(surface + 1, top):
			chunk.set_local(x, ty, z, "spruce_log" if biome in ["snow", "spruce_forest"] else "oak_log")
