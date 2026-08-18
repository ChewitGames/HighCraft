class_name ChunkRenderer
extends Node3D
# Turns chunk meshes into scene nodes and streams them around a center point.
# Simple main-thread builds only (ChunkMesher uses autoloads — not thread-safe).

var world
var mesher: ChunkMesher
var loaded: Dictionary = {}   # Vector2i -> Node3D
var max_builds_per_call: int = 6
var _shape_cache: Dictionary = {}


func setup(p_world) -> void:
	world = p_world
	mesher = ChunkMesher.new()
	if mesher.has_method("warm_cache"):
		mesher.warm_cache()
	_shape_cache = {}
	loaded.clear()
	max_builds_per_call = 10


func _box_shape(size: Vector3) -> BoxShape3D:
	var key = str(size)
	if not _shape_cache.has(key):
		var s = BoxShape3D.new()
		s.size = size
		_shape_cache[key] = s
	return _shape_cache[key]


func _merge_colliders(cells: Array) -> Array:
	var by_y: Dictionary = {}
	for c in cells:
		if not by_y.has(c.y):
			by_y[c.y] = {}
		by_y[c.y][Vector2i(c.x, c.z)] = true
	var boxes: Array = []
	for y in by_y.keys():
		var plane = by_y[y]
		var used: Dictionary = {}
		for k in plane.keys():
			if used.has(k):
				continue
			var w = 1
			while plane.has(Vector2i(k.x + w, k.y)) and not used.has(Vector2i(k.x + w, k.y)):
				w += 1
			var d = 1
			var grow = true
			while grow:
				for ix in range(w):
					var probe = Vector2i(k.x + ix, k.y + d)
					if not plane.has(probe) or used.has(probe):
						grow = false
						break
				if grow:
					d += 1
			for ix in range(w):
				for iz in range(d):
					used[Vector2i(k.x + ix, k.y + iz)] = true
			boxes.append({"x": k.x, "z": k.y, "y": y, "w": w, "d": d})
	return boxes


func build_chunk(cx: int, cz: int) -> void:
	_destroy_chunk(cx, cz)
	if world == null:
		return
	var chunk = world.get_chunk(cx, cz)
	if chunk == null:
		return
	var meshes = mesher.build(world, chunk)
	var holder = Node3D.new()
	holder.name = "Chunk_%d_%d" % [cx, cz]
	holder.position = Vector3(cx * VoxelWorld.CHUNK_SIZE, 0, cz * VoxelWorld.CHUNK_SIZE)
	add_child(holder)

	if meshes.get("collide", null) != null:
		var mi = MeshInstance3D.new()
		mi.mesh = meshes["collide"]
		holder.add_child(mi)
	if meshes.get("liquid", null) != null:
		var lm = MeshInstance3D.new()
		lm.mesh = meshes["liquid"]
		holder.add_child(lm)

	var cells = meshes.get("collider_cells", [])
	if cells is Array and cells.size() > 0:
		var body = StaticBody3D.new()
		for box in _merge_colliders(cells):
			var cshape = CollisionShape3D.new()
			cshape.shape = _box_shape(Vector3(box["w"], 1, box["d"]))
			cshape.position = Vector3(box["x"] + box["w"] / 2.0,
				box["y"] + 0.5, box["z"] + box["d"] / 2.0)
			body.add_child(cshape)
		holder.add_child(body)

	loaded[Vector2i(cx, cz)] = holder


func _destroy_chunk(cx: int, cz: int) -> void:
	var key = Vector2i(cx, cz)
	if loaded.has(key):
		var h = loaded[key]
		loaded.erase(key)
		if is_instance_valid(h):
			h.queue_free()


func rebuild(cx: int, cz: int) -> void:
	if loaded.has(Vector2i(cx, cz)):
		build_chunk(cx, cz)


func update_around(world_pos: Vector3, radius: int) -> void:
	if world == null:
		return
	var pcx = floori(world_pos.x / VoxelWorld.CHUNK_SIZE)
	var pcz = floori(world_pos.z / VoxelWorld.CHUNK_SIZE)
	var wanted: Dictionary = {}
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			wanted[Vector2i(pcx + dx, pcz + dz)] = true

	# Keep a little extra so edges don't thrash
	var unload_r = radius + 2
	var keep: Dictionary = {}
	for dx in range(-unload_r, unload_r + 1):
		for dz in range(-unload_r, unload_r + 1):
			keep[Vector2i(pcx + dx, pcz + dz)] = true

	for key in loaded.keys():
		if not keep.has(key):
			_destroy_chunk(key.x, key.y)

	var missing: Array = []
	for key in wanted.keys():
		if not loaded.has(key):
			missing.append(key)
	missing.sort_custom(_closer_to_center.bind(pcx, pcz))

	var built = 0
	for key in missing:
		build_chunk(key.x, key.y)
		built += 1
		if built >= max_builds_per_call:
			break


func _closer_to_center(a: Vector2i, b: Vector2i, pcx: int, pcz: int) -> bool:
	var da = (a.x - pcx) * (a.x - pcx) + (a.y - pcz) * (a.y - pcz)
	var db = (b.x - pcx) * (b.x - pcx) + (b.y - pcz) * (b.y - pcz)
	return da < db


func loaded_count() -> int:
	return loaded.size()


func set_world(p_world) -> void:
	for key in loaded.keys():
		var h = loaded[key]
		if is_instance_valid(h):
			h.queue_free()
	loaded.clear()
	world = p_world


func edit_block(x: int, y: int, z: int, id: String) -> void:
	if world == null:
		return
	world.set_block(x, y, z, id)

	var cx = floori(float(x) / VoxelWorld.CHUNK_SIZE)
	var cz = floori(float(z) / VoxelWorld.CHUNK_SIZE)

	_rebuild_if_loaded(cx, cz)

	var lx = x - cx * VoxelWorld.CHUNK_SIZE
	var lz = z - cz * VoxelWorld.CHUNK_SIZE

	if lx == 0:
		_rebuild_if_loaded(cx - 1, cz)
	elif lx == VoxelWorld.CHUNK_SIZE - 1:
		_rebuild_if_loaded(cx + 1, cz)

	if lz == 0:
		_rebuild_if_loaded(cx, cz - 1)
	elif lz == VoxelWorld.CHUNK_SIZE - 1:
		_rebuild_if_loaded(cx, cz + 1)


func _rebuild_if_loaded(cx: int, cz: int) -> void:
	if loaded.has(Vector2i(cx, cz)):
		build_chunk(cx, cz)
