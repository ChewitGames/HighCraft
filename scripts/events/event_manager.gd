class_name EventManager
extends Node
# Drives HighCraft's special events:
#   Hero No Brain - April only; periodically spawns near the player, charges and
#                   explodes; one hit kills it (drops 64 diamonds).
#   Charlie Emily - every 3 minutes, 1% chance; sits beside the player, plays
#                   "Left Behind", then gifts a rose and vanishes (unkillable).

const HERO_INTERVAL = 60.0
const HERO_CHANCE = 0.4
const CHARLIE_INTERVAL = 180.0
const CHARLIE_CHANCE = 0.01
const CHARLIE_DURATION = 30.0

var player
var mob_root: Node

var _hero = null
var _charlie = null
var _hero_t: float = 0.0
var _charlie_check_t: float = 0.0
var _charlie_timer: float = 0.0


func setup(p_player, p_mob_root: Node) -> void:
	player = p_player
	mob_root = p_mob_root


func is_april() -> bool:
	return Time.get_datetime_dict_from_system().get("month", 0) == 4


func _process(delta: float) -> void:
	if player == null:
		return
	_hero_logic(delta)
	_charlie_logic(delta)


func _hero_logic(delta: float) -> void:
	if not is_april():
		return
	if _hero != null and is_instance_valid(_hero):
		return
	_hero_t += delta
	if _hero_t >= HERO_INTERVAL:
		_hero_t = 0.0
		if randf() < HERO_CHANCE:
			spawn_hero()


func spawn_hero():
	var h = HeroNoBrain.new()
	h.setup("hero_no_brain", player)
	mob_root.add_child(h)
	var ang = randf() * TAU
	h.global_position = player.global_position + Vector3(cos(ang) * 8.0, 2.0, sin(ang) * 8.0)
	_hero = h
	return h


func _charlie_logic(delta: float) -> void:
	if _charlie != null and is_instance_valid(_charlie):
		_charlie_timer -= delta
		if _charlie_timer <= 0.0:
			gift_charlie()
		return
	_charlie_check_t += delta
	if _charlie_check_t >= CHARLIE_INTERVAL:
		_charlie_check_t = 0.0
		if randf() < CHARLIE_CHANCE:
			spawn_charlie()


func spawn_charlie():
	var c = CharlieEmily.new()
	c.setup("charlie_emily", player)
	mob_root.add_child(c)
	c.global_position = player.global_position + Vector3(2.0, 1.0, 0.0)
	_charlie = c
	_charlie_timer = CHARLIE_DURATION
	var folders = Registry.music.get("folders", {})
	Music.play_event(Registry.music.get("charlie_emily_track", ""),
		folders.get("charlie", "Charlie Emily"))
	return c


func gift_charlie():
	if is_instance_valid(_charlie):
		var pos = _charlie.global_position
		# Rose in inventory + drop one on the ground so she "leaves a rose"
		if player != null and player.inventory != null:
			player.inventory.add("rose", 1)
		_drop_rose_at(pos)
		_charlie.queue_free()
	_charlie = null
	_charlie_timer = 0.0
	# Resume normal dimension music after her theme
	if player != null and player.get_tree() != null:
		var scene = player.get_tree().current_scene
		if scene != null and scene.has_method("_music_ctx") and scene.get("current_dim") != null:
			Music.play_for_dimension(scene._music_ctx(scene.current_dim))
		elif has_node("/root/Music"):
			Music.play_for_dimension("overworld")


func _drop_rose_at(pos: Vector3) -> void:
	var scene = null
	if player != null and player.get_tree() != null:
		scene = player.get_tree().current_scene
	if scene == null:
		return
	# Drop a spinning rose item entity she "leaves behind"
	var path = "res://scenes/item_entity.tscn"
	if ResourceLoader.exists(path):
		var ent = load(path).instantiate()
		if ent.has_method("setup"):
			ent.setup("rose", 1, player)
		scene.add_child(ent)
		ent.global_position = pos + Vector3(0.3, 0.6, 0.2)
	# Also plant a flower block on the ground as a visual marker
	if scene.get("world") != null and scene.get("renderer") != null:
		var wx = floori(pos.x)
		var wy = floori(pos.y)
		var wz = floori(pos.z)
		var world = scene.world
		var renderer = scene.renderer
		for dy in range(0, -4, -1):
			var below = world.get_block(wx, wy + dy - 1, wz)
			var here = world.get_block(wx, wy + dy, wz)
			if below != "air" and below != "water" and (here == "air" or here == ""):
				renderer.edit_block(wx, wy + dy, wz, "flower_red_rose")
				return
		renderer.edit_block(wx, wy, wz, "flower_red_rose")
