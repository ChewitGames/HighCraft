class_name RegionManager
extends RefCounted
## Per-world region files. Path includes world_id so worlds never share builds.

const REGION_SIZE := 32
const DIR := "user://highcraft_regions/"

var world_seed: int = 0
var world_id: String = "default"
var load_from_disk: bool = false
var _dirty: Dictionary = {}
var _cache: Dictionary = {}


static func chunk_to_region(cx: int, cz: int) -> Vector2i:
	return Vector2i(int(floor(float(cx) / REGION_SIZE)), int(floor(float(cz) / REGION_SIZE)))


func region_path(rx: int, rz: int) -> String:
	var safe_id = world_id.replace("/", "_").replace("..", "_")
	if safe_id == "":
		safe_id = "seed_%d" % world_seed
	return "%s%s/r.%d.%d.hc" % [DIR, safe_id, rx, rz]


func setup(p_seed: int, p_world_id: String = "", p_load_disk: bool = false) -> void:
	world_seed = p_seed
	world_id = p_world_id if p_world_id != "" else ("seed_%d" % p_seed)
	load_from_disk = p_load_disk
	_dirty.clear()
	_cache.clear()
	DirAccess.make_dir_recursive_absolute(DIR + world_id.replace("/", "_"))


func mark_edit(cx: int, cz: int, lx: int, y: int, lz: int, id: String) -> void:
	var rk = chunk_to_region(cx, cz)
	_dirty[rk] = true
	if not _cache.has(rk):
		_cache[rk] = {} if not load_from_disk else _load_region(rk.x, rk.y)
	var reg: Dictionary = _cache[rk]
	var ck = Vector2i(cx, cz)
	if not reg.has(ck):
		reg[ck] = {}
	var blocks: Dictionary = reg[ck]
	var key = Vector3i(lx, y, lz)
	# "air" is a real edit (a mined generated block), not absence of an edit.
	# Keeping the tombstone is required when a chunk is evicted and regenerated.
	blocks[key] = id


func apply_region_to_chunk(chunk) -> void:
	if chunk == null:
		return
	var rk = chunk_to_region(chunk.cx, chunk.cz)
	if not _cache.has(rk):
		# Fresh worlds must never read another world's files, but their in-memory
		# edit cache still has to survive chunk eviction and regeneration.
		if not load_from_disk:
			return
		_cache[rk] = _load_region(rk.x, rk.y)
	var reg: Dictionary = _cache[rk]
	var ck = Vector2i(chunk.cx, chunk.cz)
	if not reg.has(ck):
		return
	var blocks: Dictionary = reg[ck]
	for key in blocks.keys():
		chunk.set_local(key.x, key.y, key.z, str(blocks[key]))


func flush_all() -> void:
	for rk in _dirty.keys():
		_save_region(rk.x, rk.y)
	_dirty.clear()


func flush_next() -> bool:
	# Amortize autosaves: one region file per tick instead of serializing every
	# dirty region in a single frame.
	if _dirty.is_empty():
		return false
	var rk: Vector2i = _dirty.keys()[0]
	_save_region(rk.x, rk.y)
	_dirty.erase(rk)
	return true


func _load_region(rx: int, rz: int) -> Dictionary:
	var path = region_path(rx, rz)
	var out: Dictionary = {}
	if not FileAccess.file_exists(path):
		return out
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var text = f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if not (data is Dictionary):
		return out
	for ck_str in data.keys():
		var parts = str(ck_str).split(",")
		if parts.size() != 2:
			continue
		var ck = Vector2i(int(parts[0]), int(parts[1]))
		var bd = data[ck_str]
		if not (bd is Dictionary):
			continue
		var blocks: Dictionary = {}
		for bk in bd.keys():
			var bp = str(bk).split(",")
			if bp.size() != 3:
				continue
			blocks[Vector3i(int(bp[0]), int(bp[1]), int(bp[2]))] = str(bd[bk])
		out[ck] = blocks
	return out


func _save_region(rx: int, rz: int) -> void:
	var rk = Vector2i(rx, rz)
	var reg: Dictionary = _cache.get(rk, {})
	var path = region_path(rx, rz)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var serial: Dictionary = {}
	for ck in reg.keys():
		var blocks: Dictionary = reg[ck]
		var bs: Dictionary = {}
		for key in blocks.keys():
			bs["%d,%d,%d" % [key.x, key.y, key.z]] = blocks[key]
		serial["%d,%d" % [ck.x, ck.y]] = bs
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(serial))
	f.close()
