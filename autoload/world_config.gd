extends Node
# HighCraft - world configuration (autoload singleton "Config").
# Holds the settings chosen in the world-creation UI (Part 18 main menu sets
# these before loading the game). The game scene reads them on start.

var seed_val: int = 1337
var game_mode: int = 1          # GameSettings.GameMode.SURVIVAL
var difficulty: int = 2         # GameSettings.Difficulty.NORMAL
var world_type: String = "normal"   # "normal" | "flat"
var generate_structures: bool = true
var pending_save = null


func reset_defaults() -> void:
	seed_val = 1337
	game_mode = 1
	difficulty = 2
	world_type = "normal"
	generate_structures = true
