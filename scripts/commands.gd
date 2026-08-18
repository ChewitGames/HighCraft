class_name CommandParser
extends RefCounted

static func execute(text: String, game, player) -> String:
	var line = text.strip_edges()
	if line.begins_with("/"):
		line = line.substr(1)
	if line == "":
		return ""
	var parts = line.split(" ", false)
	var cmd = parts[0].to_lower()
	var args = parts.slice(1)

	match cmd:
		"give":
			return _give(args, player)
		"tp", "teleport":
			return _tp(args, player)
		"gamemode", "gm":
			return _gamemode(args, player)
		"difficulty", "diff":
			return _difficulty(args, player)
		"time":
			return _time(args, game)
		"heal":
			if player == null: return "No player."
			player.health = player.max_health
			player.hunger = player.max_hunger
			return "Healed."
		"kill":
			if player == null: return "No player."
			player._die()
			return "Ouch."
		"summon", "spawn":
			return _summon(args, game, player)
		"charlie":
			return _summon(["charlie_emily"], game, player)
		"hero":
			return _summon(["hero_no_brain"], game, player)
		"say":
			var msg = " ".join(args) if args.size() > 0 else ""
			if msg == "":
				return "Usage: say <message>"
			if game != null and game.get("ui") != null:
				var ui = game.ui
				if ui.has_method("_show_chat_line"):
					ui._show_chat_line(1, msg)
				elif ui.get("_chat_msg") != null:
					ui._chat_msg.text = msg
			return msg
		"help":
			return "give tp gamemode difficulty time heal kill summon <id> charlie hero say"
		_:
			return "Unknown command: " + cmd


static func _give(args: Array, player) -> String:
	if player == null or player.inventory == null: return "No inventory."
	if args.is_empty(): return "Usage: give <item> [count]"
	var item_id = args[0]
	if Registry.get_item(item_id) == null and Registry.get_block(item_id) == null:
		return "No such item: " + item_id
	var count = 1
	if args.size() > 1 and args[1].is_valid_int():
		count = int(args[1])
	player.inventory.add(item_id, count)
	return "Gave %d x %s" % [count, item_id]


static func _tp(args: Array, player) -> String:
	if player == null: return "No player."
	if args.size() < 3: return "Usage: tp <x> <y> <z>"
	player.global_position = Vector3(float(args[0]), float(args[1]), float(args[2]))
	player.velocity = Vector3.ZERO
	return "Teleported."


static func _gamemode(args: Array, player) -> String:
	if player == null: return "No player."
	if args.is_empty(): return "Usage: gamemode <creative|survival|adventure|hardcore>"
	var names = ["creative", "survival", "adventure", "hardcore"]
	var a = args[0].to_lower()
	var mode = -1
	if a.is_valid_int(): mode = int(a)
	elif names.has(a): mode = names.find(a)
	if mode < 0 or mode > 3: return "Bad game mode."
	player.configure(mode, player.difficulty)
	return "Game mode: " + names[mode]


static func _difficulty(args: Array, player) -> String:
	if player == null: return "No player."
	if args.is_empty(): return "Usage: difficulty <peaceful|easy|normal|hard>"
	var names = ["peaceful", "easy", "normal", "hard"]
	var a = args[0].to_lower()
	var diff = -1
	if a.is_valid_int(): diff = int(a)
	elif names.has(a): diff = names.find(a)
	if diff < 0 or diff > 3: return "Bad difficulty."
	player.configure(player.game_mode, diff)
	return "Difficulty: " + names[diff]


static func _time(args: Array, game) -> String:
	if game == null: return "No game."
	if args.is_empty(): return "Usage: time <day|night|0..1>"
	var a = args[0].to_lower()
	if a == "day": game.time_of_day = 0.3
	elif a == "night": game.time_of_day = 0.8
	elif a.is_valid_float(): game.time_of_day = clampf(float(a), 0.0, 1.0)
	else: return "Bad time."
	return "Time set."


static func _summon(args: Array, game, player) -> String:
	if player == null: return "No player."
	if args.is_empty(): return "Usage: summon <mob_id>"
	var mob_id = args[0].to_lower()
	if not Registry.mobs.has(mob_id): return "Unknown mob: " + mob_id
	var pos = player.global_position + Vector3(2.0, 1.0, 0.0)
	if game != null and game.get("mob_manager") != null:
		var m = game.mob_manager.spawn(mob_id, pos)
		if m != null:
			if mob_id == "hero_no_brain" and game.get("event_manager") != null:
				game.event_manager._hero = m
			if mob_id == "charlie_emily":
				# Always swap to her theme + register timer so she leaves a rose and vanishes
				var folders = Registry.music.get("folders", {})
				Music.play_event(Registry.music.get("charlie_emily_track", "X120 Left Behind.mp3"),
					folders.get("charlie", "Charlie Emily"))
				if game.get("event_manager") != null:
					game.event_manager._charlie = m
					game.event_manager._charlie_timer = 30.0
					game.event_manager.player = player
			return "Summoned " + mob_id
		return "Spawn failed"
	# Fallback
	var scene_root = player.get_tree().current_scene
	var m2
	if mob_id == "villager": m2 = Villager.new()
	elif mob_id == "hero_no_brain": m2 = HeroNoBrain.new()
	elif mob_id == "charlie_emily": m2 = CharlieEmily.new()
	else: m2 = Mob.new()
	m2.setup(mob_id, player)
	scene_root.add_child(m2)
	m2.global_position = pos
	return "Summoned " + mob_id
	
	# in commands oder beim Rechtsklick mit boat-Item:
	var b = Boat.new()
	b.global_position = player.global_position + Vector3(0, 0.2, 2)
	game.add_child(b)
