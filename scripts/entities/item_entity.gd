class_name ItemEntity
extends Node3D
# A dropped item that any player picks up by walking near it. Spins for visual
# flair; auto-collects within range and adds to the picking player's inventory.
# Items sitting in fire or lava burn away (unless the world option is off).

var item_id: String = ""
var count: int = 1
var player: Node3D
var _age: float = 0.0
var _burn_t: float = 0.0
const DESPAWN_SECONDS := 300.0
const ACTIVE_DISTANCE_SQ := 48.0 * 48.0
const PICKUP_DELAY := 0.6          # nobody re-grabs a fresh throw instantly
const PICKUP_DISTANCE_SQ := 1.7 * 1.7
const BURN_SECONDS := 1.0


func setup(p_item_id: String, p_count: int, p_player: Node3D = null) -> void:
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
	# Icon-Hintergrund ist im Modelltransparent -> auf Basisfarbe kompositiert,
	# damit der Drop nicht als schwarze Box rendert.
	mat.albedo_texture = Textures.get_model_texture(item_id)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh.material_override = mat
	mesh.position = Vector3(0, 0.3, 0)
	add_child(mesh)


func _process(delta: float) -> void:
	_age += delta
	if _age >= DESPAWN_SECONDS:
		queue_free()
		return
	if _burning():
		_burn_t += delta
		if _burn_t >= BURN_SECONDS:
			Audio.play("fire_ignite", -8.0)
			queue_free()
			return
	else:
		_burn_t = 0.0
	if _is_near_player():
		rotate_y(delta * 2.0)
	# Jeder Spieler darf aufsammeln; der Werfer bekommt erst nach Pickupdate.
	if _age <= PICKUP_DELAY:
		return
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		var inv = p.get("inventory")
		if inv == null or not p.has_method("_is_locally_controlled"):
			continue
		if not p._is_locally_controlled():
			continue
		if global_position.distance_squared_to(p.global_position) < PICKUP_DISTANCE_SQ:
			inv.add(item_id, count)
			Audio.play("player_item_pickup", -10.0)
			queue_free()
			return


func _burning() -> bool:
	if not has_node("/root/Config") or not get_node("/root/Config").items_burn_enabled:
		return false
	var game_node = get_tree().get_first_node_in_group("game")
	if game_node == null:
		return false
	var w = game_node.get("world")
	if w == null or not w.has_method("get_block_no_gen"):
		return false
	var c := global_position
	return str(w.get_block_no_gen(floori(c.x), floori(c.y), floori(c.z))) in ["fire", "lava"]


func _is_near_player() -> bool:
	for p in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(p) and global_position.distance_squared_to(p.global_position) <= ACTIVE_DISTANCE_SQ:
			return true
	return false