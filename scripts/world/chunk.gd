class_name Chunk
extends RefCounted
# A single chunk of the voxel world. Blocks are stored sparsely (only
# non-air cells) keyed by local Vector3i, which keeps memory low and meshing
# simple. World height runs 0..VoxelWorld.WORLD_HEIGHT-1.

var cx: int = 0
var cz: int = 0
var blocks: Dictionary = {}   # Vector3i(local x,y,z) -> String block id
var generated: bool = false


func _init(p_cx: int, p_cz: int) -> void:
	cx = p_cx
	cz = p_cz


func get_local(x: int, y: int, z: int) -> String:
	return blocks.get(Vector3i(x, y, z), "air")


func set_local(x: int, y: int, z: int, id: String) -> void:
	var key = Vector3i(x, y, z)
	if id == "air":
		blocks.erase(key)
	else:
		blocks[key] = id
