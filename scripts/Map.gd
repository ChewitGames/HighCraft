extends Node
class_name Map

var discovered_chunks: Array = []

func use() -> void:
	print("Map opened (placeholder)")
	# TODO: Open map UI
	# TODO: Reveal chunks around player

func reveal_chunk(chunk_pos: Vector2i) -> void:
	if chunk_pos not in discovered_chunks:
		discovered_chunks.append(chunk_pos)
		print("Chunk revealed: ", chunk_pos)
