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
	var canonical_id := Registry.require_dimension(dim_id)
	if not worlds.has(canonical_id):
		var profile := Registry.get_dimension(canonical_id)
		if str(profile.get("id", "")) != canonical_id:
			push_error("[DimensionManager] Registry profile mismatch for " + canonical_id)
			canonical_id = "overworld"
		var wt = world_type if canonical_id == "overworld" else "normal"
		var gen = TerrainGenerator.new(seed_val + abs(hash(canonical_id)) % 100000, wt, canonical_id)
		gen.structures_enabled = structures
		worlds[canonical_id] = VoxelWorld.new(gen)
	return worlds[canonical_id]
