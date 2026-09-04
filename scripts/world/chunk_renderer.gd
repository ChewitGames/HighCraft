class_name ChunkRenderer
extends Node3D
## Mesh pipeline:
##  - MeshPool (recycle holders)
##  - Multiple Mesher clones (one per worker, no shared _mat_cache race)
##  - WorkerThreadPool builds ArrayMesh only
##  - Main thread applies meshes

class MeshingWorldView:
	var cx: int
	var cz: int
	var center_blocks: Dictionary
	var west: Dictionary
	var east: Dictionary
	var north: Dictionary
	var south: Dictionary

	func get_block_no_gen(x: int, y: int, z: int) -> String:
		if y < 0 or y >= VoxelWorld.WORLD_HEIGHT:
			return "air"
		var qx := floori(float(x) / VoxelWorld.CHUNK_SIZE)
		var qz := floori(float(z) / VoxelWorld.CHUNK_SIZE)
		var lx := x - qx * VoxelWorld.CHUNK_SIZE
		var lz := z - qz * VoxelWorld.CHUNK_SIZE
		if qx == cx and qz == cz:
			return str(center_blocks.get(Vector3i(lx, y, lz), "air"))
		if qx == cx - 1 and qz == cz:
			return str(west.get(Vector2i(y, lz), "air"))
		if qx == cx + 1 and qz == cz:
			return str(east.get(Vector2i(y, lz), "air"))
		if qx == cx and qz == cz - 1:
			return str(north.get(Vector2i(lx, y), "air"))
		if qx == cx and qz == cz + 1:
			return str(south.get(Vector2i(lx, y), "air"))
		return "air"

var world
var mesher: ChunkMesher  # main-thread mesher (preload / edits)
var loaded: Dictionary = {}
var max_builds_per_call: int = 8

var _shape_cache: Dictionary = {}
var _holder_pool: Array = []
var _pool_target: int = 96

var _pending: Dictionary = {}
var _build_queue: Array = []
var _ready_results: Array = []
var _result_mutex: Mutex = Mutex.new()
var _use_threads: bool = true
var _max_inflight: int = 2
var _inflight: int = 0
var _center: Vector2i = Vector2i.ZERO
var _last_radius: int = -1
var _last_centers: Array = []
var _visibility_centers: Array = []
var _last_visibility_centers: Array = []
var _visibility_radius: int = -1
var _split_visibility_enabled: bool = false
var _request_epoch: int = 0
var _last_thread_start_frame: int = -1
var _last_result_apply_frame: int = -1
var _deferred_pump_scheduled: bool = false
var _rebuild_versions: Dictionary = {}

# Pool of warm meshers for workers (each has own mat cache)
var _mesher_pool: Array = []
var _mesher_pool_mutex: Mutex = Mutex.new()
const MESHER_POOL_SIZE := 3
# Render layers 2-5 are private terrain layers for local split players 1-4.
# Layer 1 remains the normal single-player/shared-world layer.
const SPLIT_CHUNK_FIRST_BIT := 1


func setup(p_world) -> void:
	world = p_world
	mesher = ChunkMesher.new()
	if mesher.has_method("warm_cache"):
		mesher.warm_cache()
	_mesher_pool.clear()
	for i in range(MESHER_POOL_SIZE):
		var m = ChunkMesher.new()
		if m.has_method("warm_cache"):
			m.warm_cache()
		_mesher_pool.append(m)
	_shape_cache.clear()
	loaded.clear()
	_pending.clear()
	_build_queue.clear()
	_ready_results.clear()
	_rebuild_versions.clear()
	_inflight = 0
	_last_radius = -1
	_last_centers.clear()
	_visibility_centers.clear()
	_last_visibility_centers.clear()
	_visibility_radius = -1
	_split_visibility_enabled = false
	_request_epoch += 1
	max_builds_per_call = 10
	for i in range(mini(32, _pool_target)):
		_holder_pool.append(_make_holder())
	print("[ChunkRenderer] meshers=", _mesher_pool.size() + 1, " pool=", _holder_pool.size())


func _acquire_mesher() -> ChunkMesher:
	_mesher_pool_mutex.lock()
	var m: ChunkMesher = null
	if _mesher_pool.size() > 0:
		m = _mesher_pool.pop_back()
	_mesher_pool_mutex.unlock()
	if m == null:
		m = ChunkMesher.new()
		if m.has_method("warm_cache"):
			m.warm_cache()
	return m


func _release_mesher(m: ChunkMesher) -> void:
	if m == null:
		return
	_mesher_pool_mutex.lock()
	if _mesher_pool.size() < MESHER_POOL_SIZE + 2:
		_mesher_pool.append(m)
	_mesher_pool_mutex.unlock()


func _make_holder() -> Node3D:
	var h = Node3D.new()
	h.visible = false
	var mi = MeshInstance3D.new()
	mi.name = "Solid"
	h.add_child(mi)
	var li = MeshInstance3D.new()
	li.name = "Liquid"
	h.add_child(li)
	var body = StaticBody3D.new()
	body.name = "Body"
	h.add_child(body)
	return h


func _acquire_holder() -> Node3D:
	if _holder_pool.size() > 0:
		var h = _holder_pool.pop_back()
		h.visible = true
		return h
	var n = _make_holder()
	n.visible = true
	return n


func _release_holder(h: Node3D) -> void:
	if h == null or not is_instance_valid(h):
		return
	var solid = h.get_node_or_null("Solid") as MeshInstance3D
	var liquid = h.get_node_or_null("Liquid") as MeshInstance3D
	var body = h.get_node_or_null("Body") as StaticBody3D
	if solid:
		solid.mesh = null
	if liquid:
		liquid.mesh = null
	if body:
		for c in body.get_children():
			body.remove_child(c)
			c.queue_free()
	h.visible = false
	if h.get_parent() == self:
		remove_child(h)
	if _holder_pool.size() < _pool_target:
		_holder_pool.append(h)
	else:
		h.queue_free()


func _box_shape(size: Vector3) -> BoxShape3D:
	var key = str(size)
	if not _shape_cache.has(key):
		var s = BoxShape3D.new()
		s.size = size
		_shape_cache[key] = s
	return _shape_cache[key]


static func _merge_colliders(cells: Array) -> Array:
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
	# Rebuild in place. Destroying first made placed blocks / portals vanish
	# until the next mesh upload finished.
	_pending.erase(Vector2i(cx, cz))
	if world == null or mesher == null:
		return
	var chunk = world.get_chunk(cx, cz)
	if chunk == null:
		return
	var meshes = mesher.build(world, chunk)
	_apply_meshes(cx, cz, meshes)


func remesh_chunk_now(cx: int, cz: int) -> void:
	# Never mesh on the main thread — that was the freeze spike. Prioritize the
	# worker job so the existing holder stays visible until the new mesh lands.
	_queue_chunk_rebuild(Vector2i(cx, cz), true)


func _apply_meshes(cx: int, cz: int, meshes: Dictionary) -> void:
	var key = Vector2i(cx, cz)
	# Runtime changes update the existing holder atomically. Keeping the node in
	# the tree avoids a visible unload/reload and preserves its render layers.
	var holder: Node3D
	if loaded.has(key) and is_instance_valid(loaded[key]):
		holder = loaded[key]
	else:
		holder = _acquire_holder()
		holder.name = "Chunk_%d_%d" % [cx, cz]
		holder.position = Vector3(cx * VoxelWorld.CHUNK_SIZE, 0, cz * VoxelWorld.CHUNK_SIZE)
		add_child(holder)
	var solid = holder.get_node_or_null("Solid") as MeshInstance3D
	var liquid = holder.get_node_or_null("Liquid") as MeshInstance3D
	var body = holder.get_node_or_null("Body") as StaticBody3D
	# Assign fully prepared resources only after meshing has completed.
	if solid:
		solid.mesh = meshes.get("collide", null)
		solid.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var shadows := false
		var hs = get_node_or_null("/root/HCSettings")
		if hs != null and int(hs.shadow_quality) >= 2:
			shadows = true
		if str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) == "mobile":
			# Default mobile path: no terrain shadow maps (Adreno fill-rate).
			shadows = hs != null and int(hs.shadow_quality) >= 2
		solid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if liquid:
		liquid.mesh = meshes.get("liquid", null)
		liquid.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		liquid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_apply_chunk_render_layers(holder, key)
	if body:
		for c in body.get_children():
			body.remove_child(c)
			c.queue_free()
		# The expensive cell-to-box merge is already performed by the mesh worker.
		# Keep the fallback for synchronous spawn/rebuild paths only.
		var boxes = meshes.get("collider_boxes", null)
		if not (boxes is Array):
			var cells = meshes.get("collider_cells", [])
			boxes = _merge_colliders(cells) if cells is Array else []
		if boxes.size() > 0:
			for box in boxes:
				var cshape = CollisionShape3D.new()
				cshape.shape = _box_shape(Vector3(box["w"], 1, box["d"]))
				cshape.position = Vector3(box["x"] + box["w"] / 2.0, box["y"] + 0.5, box["z"] + box["d"] / 2.0)
				body.add_child(cshape)
	loaded[key] = holder
	_pending.erase(key)


func _destroy_chunk(cx: int, cz: int) -> void:
	var key = Vector2i(cx, cz)
	if not loaded.has(key):
		return
	var h = loaded[key]
	loaded.erase(key)
	_release_holder(h)


func rebuild(cx: int, cz: int) -> void:
	_queue_chunk_rebuild(Vector2i(cx, cz))


func rebuild_chunk(cx: int, cz: int) -> void:
	_queue_chunk_rebuild(Vector2i(cx, cz))


func _queue_chunk_rebuild(key: Vector2i, priority: bool = false) -> void:
	# Coalesce runtime edits onto the worker pipeline. Keep the current mesh
	# visible; _apply_meshes replaces it in place when the worker returns.
	_rebuild_versions[key] = int(_rebuild_versions.get(key, 0)) + 1
	if not _pending.has(key):
		_pending[key] = true
		if priority:
			_build_queue.push_front(key)
		else:
			_build_queue.append(key)
	elif priority:
		_build_queue.erase(key)
		_build_queue.push_front(key)
	if not _deferred_pump_scheduled:
		_deferred_pump_scheduled = true
		call_deferred("_pump_deferred_rebuilds")


func _pump_deferred_rebuilds() -> void:
	_deferred_pump_scheduled = false
	_pump_queue()


func update_around(world_pos: Vector3, radius: int) -> void:
	update_around_many([world_pos], radius)


func update_around_many(world_positions: Array, radius: int) -> void:
	if world == null:
		return
	var centers: Array = []
	var visibility_centers: Array = []
	for pos in world_positions:
		if pos is Vector3:
			var c := Vector2i(
				floori(pos.x / float(VoxelWorld.CHUNK_SIZE)),
				floori(pos.z / float(VoxelWorld.CHUNK_SIZE)))
			visibility_centers.append(c)
			if not centers.has(c):
				centers.append(c)
	if centers.is_empty():
		return
	var new_center: Vector2i = centers[0]
	# Streaming work only changes after crossing a chunk boundary (or changing
	# render distance). Calling this every frame must remain O(1).
	if centers == _last_centers and radius == _last_radius \
			and visibility_centers == _last_visibility_centers:
		return
	_center = new_center
	_last_radius = radius
	_last_centers = centers.duplicate()
	_last_visibility_centers = visibility_centers.duplicate()
	_visibility_centers = visibility_centers
	_visibility_radius = radius
	_split_visibility_enabled = visibility_centers.size() > 1
	# Existing chunks may change ownership when a player crosses a chunk border.
	# Update only their render masks; collision and world data remain shared.
	for key in loaded.keys():
		_apply_chunk_render_layers(loaded[key], key)
	var want: Dictionary = {}
	for center in centers:
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				want[Vector2i(center.x + dx, center.y + dz)] = true
	var unload_r = radius + 2
	var to_unload: Array = []
	for key in loaded.keys():
		if not _inside_any_center(key, centers, unload_r):
			to_unload.append(key)
	for key in to_unload:
		_destroy_chunk(key.x, key.y)
		_pending.erase(key)
	for key in _pending.keys():
		if not _inside_any_center(key, centers, unload_r):
			_pending.erase(key)
	if world.has_method("evict_chunks_outside_centers"):
		world.evict_chunks_outside_centers(centers, unload_r + 1)
	# Drop queued requests that are no longer inside the requested view. Worker
	# results are validated again when they return.
	var kept_queue: Array = []
	for key in _build_queue:
		if want.has(key):
			kept_queue.append(key)
		else:
			_pending.erase(key)
	_build_queue = kept_queue
	var queue_changed := false
	for key in want.keys():
		if loaded.has(key) or _pending.has(key):
			continue
		_pending[key] = true
		_build_queue.append(key)
		queue_changed = true
	# Sort once per chunk/radius transition, never once per rendered frame.
	if queue_changed or not _build_queue.is_empty():
		_build_queue.sort_custom(func(a, b): return _closer_to_any_center(a, b, centers))
	_pump_queue()


func _apply_chunk_render_layers(holder: Node, key: Vector2i) -> void:
	if holder == null or not is_instance_valid(holder):
		return
	var layer_mask := 1
	if _split_visibility_enabled:
		layer_mask = 0
		for i in range(mini(_visibility_centers.size(), 4)):
			var center: Vector2i = _visibility_centers[i]
			if abs(key.x - center.x) <= _visibility_radius \
					and abs(key.y - center.y) <= _visibility_radius:
				layer_mask |= 1 << (SPLIT_CHUNK_FIRST_BIT + i)
	# A queued result can finish just outside all current player ranges. Keep it
	# hidden until streaming removes it instead of leaking it into every camera.
	for child in holder.get_children():
		if child is VisualInstance3D:
			(child as VisualInstance3D).layers = layer_mask


func _inside_any_center(key: Vector2i, centers: Array, radius: int) -> bool:
	for center in centers:
		if abs(key.x - center.x) <= radius and abs(key.y - center.y) <= radius:
			return true
	return false


func _closer_to_any_center(a: Vector2i, b: Vector2i, centers: Array) -> bool:
	var da := 2147483647
	var db := 2147483647
	for center in centers:
		da = mini(da, (a.x - center.x) * (a.x - center.x) + (a.y - center.y) * (a.y - center.y))
		db = mini(db, (b.x - center.x) * (b.x - center.x) + (b.y - center.y) * (b.y - center.y))
	return da < db


func _pump_queue() -> void:
	_apply_ready_results()
	# Do not combine a collision/mesh upload with synchronous terrain generation
	# in the same frame. Either operation alone can consume the frame budget.
	if _last_result_apply_frame == Engine.get_process_frames():
		return
	var budget = max_builds_per_call
	while budget > 0 and _build_queue.size() > 0:
		# Never fall back to synchronous meshing merely because all workers are
		# occupied. That fallback was the largest source of main-thread freezes.
		if _use_threads and _inflight >= _max_inflight:
			break
		# Generation (missing chunk) stays limited to one new job per frame.
		# Rebuilds of already-loaded chunks only snapshot dictionaries — safe to
		# start in the same frame so placed blocks don't sit invisible.
		var peek: Vector2i = _build_queue[0]
		var already_loaded = world != null and world.chunks.has(peek)
		if _use_threads and _last_thread_start_frame == Engine.get_process_frames() and not already_loaded:
			break
		var key: Vector2i = _build_queue.pop_front()
		if _use_threads:
			_start_thread_build(key)
			budget -= 1
		else:
			build_chunk(key.x, key.y)
			budget -= 1


func _start_thread_build(key: Vector2i) -> void:
	if world == null:
		_pending.erase(key)
		return
	# Workers must never iterate dictionaries owned by the live world. The main
	# thread may generate, edit, or evict them concurrently, which corrupts
	# Godot's copy-on-write arrays. Snapshot the center and four boundary strips.
	var chunk_snapshot := Chunk.new(key.x, key.y)
	var existing = world.chunks.get(key, null)
	var needs_generation := existing == null
	var saved_edits: Dictionary = {}
	if existing != null:
		chunk_snapshot.blocks = existing.blocks.duplicate()
		chunk_snapshot.generated = true
	elif world.regions != null:
		# Region I/O/cache ownership stays on the main thread. Apply edits to a
		# temporary empty chunk, then overlay them after worker terrain generation.
		var edit_snapshot := Chunk.new(key.x, key.y)
		world.regions.apply_region_to_chunk(edit_snapshot)
		saved_edits = edit_snapshot.blocks.duplicate()
	var view := _make_meshing_view(key, chunk_snapshot.blocks)
	_last_thread_start_frame = Engine.get_process_frames()
	_inflight += 1
	var cx = key.x
	var cz = key.y
	var w = view
	var m = _acquire_mesher()
	# Give each generation job its own noise objects; concurrent reads from one
	# shared FastNoiseLite instance are not assumed to be thread-safe.
	var generator_ref = world.generator
	if needs_generation and world.generator is TerrainGenerator:
		generator_ref = TerrainGenerator.new(
			int(world.generator.seed_val),
			str(world.generator.world_type),
			str(world.generator.dimension))
		generator_ref.structures_enabled = bool(world.generator.structures_enabled)
	var epoch := _request_epoch
	var rebuild_version := int(_rebuild_versions.get(key, 0))
	WorkerThreadPool.add_task(func():
		if needs_generation:
			generator_ref.generate(chunk_snapshot)
			for block_pos in saved_edits.keys():
				chunk_snapshot.blocks[block_pos] = saved_edits[block_pos]
			w.center_blocks = chunk_snapshot.blocks
		# CPU arrays only. ArrayMesh/RenderingServer creation from this worker can
		# corrupt triangle buffers on Mobile/Adreno.
		var meshes = m.build(w, chunk_snapshot, true)
		# Collision merging used to happen in _apply_meshes on the main thread,
		# stalling physics and camera movement whenever a chunk became ready.
		var cells = meshes.get("collider_cells", [])
		meshes["collider_boxes"] = _merge_colliders(cells) if cells is Array else []
		meshes.erase("collider_cells")
		_result_mutex.lock()
		_ready_results.append({
			"key": Vector2i(cx, cz),
			"meshes": meshes,
			"chunk": chunk_snapshot if needs_generation else null,
			"epoch": epoch,
			"rebuild_version": rebuild_version
		})
		_result_mutex.unlock()
		_release_mesher(m)
	)


func _make_meshing_view(key: Vector2i, center_blocks: Dictionary) -> MeshingWorldView:
	var view := MeshingWorldView.new()
	view.cx = key.x
	view.cz = key.y
	view.center_blocks = center_blocks
	view.west = _snapshot_x_edge(key.x - 1, key.y, VoxelWorld.CHUNK_SIZE - 1)
	view.east = _snapshot_x_edge(key.x + 1, key.y, 0)
	view.north = _snapshot_z_edge(key.x, key.y - 1, VoxelWorld.CHUNK_SIZE - 1)
	view.south = _snapshot_z_edge(key.x, key.y + 1, 0)
	return view


func _snapshot_x_edge(cx: int, cz: int, lx: int) -> Dictionary:
	var out: Dictionary = {}
	var chunk = world.chunks.get(Vector2i(cx, cz), null)
	if chunk == null:
		return out
	for key in chunk.blocks.keys():
		if key.x == lx:
			out[Vector2i(key.y, key.z)] = chunk.blocks[key]
	return out


func _snapshot_z_edge(cx: int, cz: int, lz: int) -> Dictionary:
	var out: Dictionary = {}
	var chunk = world.chunks.get(Vector2i(cx, cz), null)
	if chunk == null:
		return out
	for key in chunk.blocks.keys():
		if key.z == lz:
			out[Vector2i(key.x, key.y)] = chunk.blocks[key]
	return out


func _apply_ready_results() -> void:
	# Uploading meshes and creating chunk collision shapes are main-thread work.
	# Never apply two completed chunks in one rendered frame, even when this
	# method is reached once from game streaming and once from our own process.
	var frame := Engine.get_process_frames()
	if _last_result_apply_frame == frame:
		return
	_result_mutex.lock()
	if _ready_results.is_empty():
		_result_mutex.unlock()
		return
	var item = _ready_results.pop_front()
	_result_mutex.unlock()
	_last_result_apply_frame = frame
	_inflight = maxi(0, _inflight - 1)
	var key: Vector2i = item["key"]
	if int(item.get("epoch", -1)) != _request_epoch or not _pending.has(key):
		return
	# A lever/clock/explosion may edit this chunk again while its worker is still
	# meshing. Never install that stale snapshot; queue the newest state instead.
	if int(item.get("rebuild_version", 0)) != int(_rebuild_versions.get(key, 0)):
		_pending.erase(key)
		_queue_chunk_rebuild(key)
		return
	var generated_chunk = item.get("chunk", null)
	if generated_chunk != null and not world.chunks.has(key):
		world.chunks[key] = generated_chunk
	# Upload packed CPU arrays and assign materials exclusively on the main thread.
	var gpu_meshes: Dictionary = mesher.materialize(item["meshes"])
	_apply_meshes(key.x, key.y, gpu_meshes)


func _process(_delta: float) -> void:
	# Do not inspect _ready_results without its mutex while a worker may append.
	if _inflight > 0 or (_build_queue.size() > 0 and _inflight < _max_inflight):
		_pump_queue()


func loaded_count() -> int:
	return loaded.size()


func collision_ready_at(world_pos: Vector3, margin: float = 0.42) -> bool:
	# Check the complete player footprint. At a chunk edge the center can still be
	# inside a loaded chunk while half of the collision body is already over void.
	for offset_x in [-margin, margin]:
		for offset_z in [-margin, margin]:
			var cx := floori((world_pos.x + offset_x) / float(VoxelWorld.CHUNK_SIZE))
			var cz := floori((world_pos.z + offset_z) / float(VoxelWorld.CHUNK_SIZE))
			if not loaded.has(Vector2i(cx, cz)):
				return false
	return true


func prioritize_collision_at(world_pos: Vector3, margin: float = 0.42) -> void:
	var requested: Dictionary = {}
	for offset_x in [-margin, margin]:
		for offset_z in [-margin, margin]:
			var key := Vector2i(
				floori((world_pos.x + offset_x) / float(VoxelWorld.CHUNK_SIZE)),
				floori((world_pos.z + offset_z) / float(VoxelWorld.CHUNK_SIZE))
			)
			if requested.has(key) or loaded.has(key):
				continue
			requested[key] = true
			var queued_index := _build_queue.find(key)
			if queued_index >= 0:
				_build_queue.remove_at(queued_index)
				_build_queue.push_front(key)
			elif not _pending.has(key):
				_pending[key] = true
				_build_queue.push_front(key)
	_pump_queue()


func set_world(p_world) -> void:
	# Full dimension switch: drop every mesh from the previous world
	var keys = loaded.keys()
	for key in keys:
		_destroy_chunk(key.x, key.y)
	loaded.clear()
	_pending.clear()
	_build_queue.clear()
	_rebuild_versions.clear()
	_request_epoch += 1
	_last_radius = -1
	_last_centers.clear()
	# Keep already-finished old results so applying them can decrement _inflight;
	# their epoch prevents them from ever reaching the new world.
	world = p_world
	print("[ChunkRenderer] set_world — unloaded previous dimension meshes")


func edit_block(x: int, y: int, z: int, id: String) -> void:
	if world == null:
		return
	world.set_block(x, y, z, id)
	var cx = floori(float(x) / VoxelWorld.CHUNK_SIZE)
	var cz = floori(float(z) / VoxelWorld.CHUNK_SIZE)
	_queue_chunk_rebuild(Vector2i(cx, cz), true)
	var lx = x - cx * VoxelWorld.CHUNK_SIZE
	var lz = z - cz * VoxelWorld.CHUNK_SIZE
	if lx <= 0:
		_queue_chunk_rebuild(Vector2i(cx - 1, cz), true)
	if lx >= VoxelWorld.CHUNK_SIZE - 1:
		_queue_chunk_rebuild(Vector2i(cx + 1, cz), true)
	if lz <= 0:
		_queue_chunk_rebuild(Vector2i(cx, cz - 1), true)
	if lz >= VoxelWorld.CHUNK_SIZE - 1:
		_queue_chunk_rebuild(Vector2i(cx, cz + 1), true)


func remesh_cells(cells: Array) -> void:
	var seen: Dictionary = {}
	for cell in cells:
		if cell is Vector3i:
			var cx = floori(float(cell.x) / VoxelWorld.CHUNK_SIZE)
			var cz = floori(float(cell.z) / VoxelWorld.CHUNK_SIZE)
			seen[Vector2i(cx, cz)] = true
	for key in seen.keys():
		_queue_chunk_rebuild(key, true)


func _rebuild_if_loaded(cx: int, cz: int) -> void:
	_queue_chunk_rebuild(Vector2i(cx, cz), true)
