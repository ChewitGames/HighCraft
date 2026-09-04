extends Node
# HighCraft - world configuration (autoload singleton "Config").
# New World always gets a fresh seed + world_id so region files never leak.

var seed_val: int = 1337
var world_id: String = ""          # unique per world instance
var game_mode: int = 1
var difficulty: int = 2
var world_type: String = "normal"
var pvp_enabled: bool = true
var generate_structures: bool = true
var pending_save = null
var load_regions_from_disk: bool = false  # true only when continuing a saved world


func reset_defaults() -> void:
	seed_val = 1337
	world_id = ""
	game_mode = 1
	difficulty = 2
	world_type = "normal"
	pvp_enabled = true
	generate_structures = true
	pending_save = null
	load_regions_from_disk = false


## Call when starting a brand-new world (not load game).
## Pass null to generate a random seed, or an int for a user-selected seed.
func begin_new_world(custom_seed = null) -> void:
	seed_val = _fresh_seed() if custom_seed == null else int(custom_seed)
	world_id = _fresh_world_id()
	pending_save = null
	load_regions_from_disk = false
	if has_meta("splitscreen"):
		remove_meta("splitscreen")
	print("[Config] NEW WORLD seed=", seed_val, " world_id=", world_id)


## Call when loading a save file.
func begin_load_world(data: Dictionary) -> void:
	pending_save = data
	seed_val = int(data.get("seed", _fresh_seed()))
	world_id = str(data.get("world_id", ""))
	if world_id == "":
		world_id = "load_%d_%d" % [seed_val, Time.get_ticks_msec()]
	world_type = str(data.get("world_type", "normal"))
	game_mode = int(data.get("default_game_mode", data.get("player", {}).get("mode", 1)))
	difficulty = int(data.get("difficulty", data.get("player", {}).get("diff", 2)))
	pvp_enabled = bool(data.get("pvp_enabled", true))
	generate_structures = bool(data.get("structures", true))
	# Edits come from the save JSON — do NOT merge old region files from other sessions
	load_regions_from_disk = false
	print("[Config] LOAD WORLD seed=", seed_val, " world_id=", world_id)


func _fresh_seed() -> int:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	return int(rng.randi())


func _fresh_world_id() -> String:
	return "%d_%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_msec(), randi() % 100000]
