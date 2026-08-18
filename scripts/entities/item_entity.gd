class_name ItemEntity
extends Node3D
# A dropped item that the player picks up by walking near it. Spins for visual
# flair; auto-collects within range and adds to the player's inventory.

var item_id: String = ""
var count: int = 1
var player: Node3D
var _age: float = 0.0


func setup(p_item_id: String, p_count: int, p_player: Node3D) -> void:
	item_id = p_item_id
	count = p_count
	player = p_player


func _ready() -> void:
	var mesh = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.3, 0.3, 0.3)
	mesh.mesh = bm
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = Textures.get_texture(item_id)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mesh.material_override = mat
	mesh.position = Vector3(0, 0.3, 0)
	add_child(mesh)


func _process(delta: float) -> void:
	_age += delta
	rotate_y(delta * 2.0)
	if player == null:
		return
	if _age > 0.4 and global_position.distance_to(player.global_position) < 1.6:
		player.inventory.add(item_id, count)
		Audio.play("click", -12.0)
		queue_free()
