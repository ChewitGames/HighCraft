class_name DimensionManager
extends RefCounted
# Lazily creates and holds one VoxelWorld per dimension, each with a generator
# configured for that dimension (overworld/hell/the_end/heaven).

var seed_val: int = 1337
var world_type: String = "normal"
var structures: bool = true
var worlds: Dictionary = {}


func _init(p_seed: int = 1337, p_world_type: String = "normal", p_structures: bool = true) -> void:
	seed_val = p_seed
	world_type = p_world_type
	structures = p_structures


func get_world(dim_id: String) -> VoxelWorld:
	if not worlds.has(dim_id):
		var wt = world_type if dim_id == "overworld" else "normal"
		var gen = TerrainGenerator.new(seed_val + abs(hash(dim_id)) % 100000, wt, dim_id)
		gen.structures_enabled = structures
		worlds[dim_id] = VoxelWorld.new(gen)
	return worlds[dim_id]
