class_name ChunkStreamConfig
extends RefCounted
# Hook into VoxelWorld / ChunkLoader: only re-evaluate streaming when player
# moved more than threshold. Prevents "new chunk" spam every frame.

var last_eval_pos: Vector3 = Vector3(INF, INF, INF)


func should_reeval(player_pos: Vector3, threshold: float = -1.0) -> bool:
	if threshold < 0.0 and Engine.get_main_loop() != null:
		var hs = Engine.get_main_loop().root.get_node_or_null("HCSettings")
		if hs:
			threshold = hs.chunk_reload_threshold
		else:
			threshold = 16.0
	if last_eval_pos.x > 1e20:
		last_eval_pos = player_pos
		return true
	if player_pos.distance_to(last_eval_pos) >= threshold:
		last_eval_pos = player_pos
		return true
	return false


func load_radius() -> int:
	var hs = Engine.get_main_loop().root.get_node_or_null("HCSettings")
	if hs:
		return hs.effective_load_radius()
	return 8


func unload_radius() -> int:
	var hs = Engine.get_main_loop().root.get_node_or_null("HCSettings")
	if hs:
		return hs.effective_unload_radius()
	return 12
