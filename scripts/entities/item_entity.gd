class_name ItemEntity
extends Node3D
# A dropped item that the player picks up by walking near it. Spins for visual
# flair; auto-collects within range and adds to the player's inventory.

var item_id: String = ""
var count: int = 1
var player: Node3D
var _age: float = 0.0
const DESPAWN_SECONDS := 300.0
const ACTIVE_DISTANCE_SQ := 48.0 * 48.0


func setup(p_item_id: String, p_count: int, p_player: Node3D) -> void:
	item_id = p_item_id
	count = p_count
	player = p_player


func _ready() -> void:
	add_to_group("item_entities")
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
	if _age >= DESPAWN_SECONDS:
		queue_free()
		return
	if player == null:
		return
	var distance_sq := global_position.distance_squared_to(player.global_position)
	if distance_sq <= ACTIVE_DISTANCE_SQ:
		rotate_y(delta * 2.0)
	if _age > 0.4 and distance_sq < 1.6 * 1.6:
		player.inventory.add(item_id, count)
		Audio.play("player_item_pickup", -10.0)
		queue_free()
