class_name MobManager
extends Node3D
# Spawns mobs in a ring around the player and lets mobs despawn when far.
# Passive mobs spawn by day, hostiles by night (night provider injected by the
# game in Part 10). Boss/special mobs are never spawned naturally here.

const MAX_MOBS = 16
const SPAWN_INTERVAL = 4.0
const SPAWN_MIN = 12.0
const SPAWN_MAX = 30.0

var world
var player
var game
var dimension: String = "overworld"
var get_is_night: Callable = Callable()
var get_is_raining: Callable = Callable()

var _t: float = 2.0
var _passive: Array = []
var _hostile: Array = []


func setup(p_world, p_player) -> void:
	world = p_world
	player = p_player
	_build_pools()


func _build_pools() -> void:
	_passive.clear()
	_hostile.clear()
	for id in Registry.mobs.keys():
		var m = Registry.mobs[id]
		if not m.get("dims", []).has(dimension):
			continue
		var cat = m.get("category", "passive")
		if cat == "special" or cat == "boss":
			continue
		if cat == "hostile":
			_hostile.append(id)
		else:
			_passive.append(id)


func set_dimension(p_world, dim: String) -> void:
	world = p_world
	dimension = dim
	_build_pools()


func _process(delta: float) -> void:
	if player == null:
		return
	_t -= delta
	if _t <= 0.0:
		_t = SPAWN_INTERVAL
		_try_spawn()


func _is_night() -> bool:
	if get_is_night.is_valid():
		return get_is_night.call()
	return false


func mob_count() -> int:
	return get_tree().get_nodes_in_group("mobs").size()


func _try_spawn() -> void:
	var night = _is_night()
	var raining := false
	if get_is_raining.is_valid():
		raining = bool(get_is_raining.call())
	var pool = _hostile if (night or raining) else _passive
	if pool.is_empty() or mob_count() >= MAX_MOBS:
		return
	var ang = randf() * TAU
	var r = randf_range(SPAWN_MIN, SPAWN_MAX)
	var px = int(player.global_position.x + cos(ang) * r)
	var pz = int(player.global_position.z + sin(ang) * r)
	var sy = world.surface_height(px, pz)
	var ground = str(world.get_block(px, sy, pz))
	if ground == "water" or ground == "lava" or ground == "air":
		return
	# Villagers only near village-like blocks
	var mid = pool[randi() % pool.size()]
	if mid == "villager":
		var ok := false
		for d in [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1)]:
			var b = str(world.get_block(px + d.x, sy, pz + d.z))
			if b in ["oak_planks", "cobblestone", "oak_log", "door_oak", "farmland", "farmland_moist"]:
				ok = true
		if not ok:
			return
	# Hostiles need darkness (night/rain) — already gated by pool
	spawn(mid, Vector3(px + 0.5, sy + 1, pz + 0.5))


func spawn(mob_id: String, pos: Vector3):
	var m
	if mob_id == "villager":
		m = Villager.new()
	elif mob_id == "hero_no_brain":
		m = HeroNoBrain.new()
	elif mob_id == "charlie_emily":
		m = CharlieEmily.new()
	else:
		m = Mob.new()
	m.setup(mob_id, player)
	add_child(m)
	m.global_position = pos
	return m
