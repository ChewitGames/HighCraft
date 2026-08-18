extends Node

var loaded_chunks: Array = []
var max_chunks := 16

func toggle_chunk_loading(chunk_pos: Vector2i) -> void:
	if chunk_pos in loaded_chunks:
		loaded_chunks.erase(chunk_pos)
		print("Chunk unloading: ", chunk_pos)
	else:
		if loaded_chunks.size() < max_chunks:
			loaded_chunks.append(chunk_pos)
			print("Force loading chunk: ", chunk_pos)
		else:
			print("Chunk loader full!")
