class_name GameSettings
extends RefCounted
# Game mode + difficulty rules. Pure helper functions so the player and
# interactor can ask about behaviour without hard-coding it everywhere.

enum GameMode { CREATIVE, SURVIVAL, ADVENTURE, HARDCORE }
enum Difficulty { PEACEFUL, EASY, NORMAL, HARD }


static func can_fly(mode: int) -> bool:
	return mode == GameMode.CREATIVE


static func can_take_damage(mode: int) -> bool:
	return mode != GameMode.CREATIVE


static func can_break_place(mode: int) -> bool:
	return mode != GameMode.ADVENTURE


static func uses_durability(mode: int) -> bool:
	return mode != GameMode.CREATIVE


static func unlimited_blocks(mode: int) -> bool:
	return mode == GameMode.CREATIVE


static func can_respawn(mode: int) -> bool:
	return mode != GameMode.HARDCORE


static func hunger_drops(diff: int) -> bool:
	return diff != Difficulty.PEACEFUL


static func spawns_hostiles(diff: int) -> bool:
	return diff != Difficulty.PEACEFUL


static func mob_damage_mult(diff: int) -> float:
	if diff == Difficulty.PEACEFUL:
		return 0.0
	if diff == Difficulty.EASY:
		return 0.5
	if diff == Difficulty.HARD:
		return 1.5
	return 1.0


static func starvation_floor(diff: int) -> float:
	if diff == Difficulty.PEACEFUL:
		return 20.0
	if diff == Difficulty.EASY:
		return 10.0
	if diff == Difficulty.HARD:
		return 0.0
	return 1.0


static func mode_name(mode: int) -> String:
	return ["Creative", "Survival", "Adventure", "Hardcore"][mode]


static func difficulty_name(diff: int) -> String:
	return ["Peaceful", "Easy", "Normal", "Hard"][diff]
