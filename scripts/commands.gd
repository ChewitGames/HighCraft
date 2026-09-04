class_name CommandParser
extends RefCounted

const MAX_GIVE_COUNT := 4096
const MAX_SPAWN_COUNT := 256

static func execute(text: String, game, player) -> String:
	var line := text.strip_edges()
	if line.begins_with("/"): line = line.substr(1)
	if line.is_empty(): return ""
	var parts := Array(line.split(" ", false))
	var cmd := str(parts.pop_front()).to_lower()
	match cmd:
		"give": return _give(parts, game, player)
		"tp", "teleport": return _tp(parts, game, player)
		"gamemode", "gm": return _gamemode(parts, game, player)
		"difficulty", "diff": return _difficulty(parts, game, player)
		"time": return _time(parts, game, player)
		"weather": return _weather(parts, game, player)
		"heal": return _heal(parts, game, player)
		"kill": return _kill(parts, game, player)
		"summon", "spawn": return _summon(parts, game, player)
		"charlie": return _summon(["charlie_emily"] + parts, game, player)
		"hero": return _summon(["hero_no_brain"] + parts, game, player)
		"say": return _say(parts, game, player)
		"locate": return _locate(parts, game, player)
		"help": return "give tp gamemode difficulty time weather heal kill summon locate charlie hero say | targets: @s @p @a @name"
		_: return "Unknown command: " + cmd

static func _give(args: Array, game, executor) -> String:
	var request := _extract_targets(args, game, executor)
	if request.error != "": return request.error
	var parsed := _extract_count_and_name(request.args, MAX_GIVE_COUNT)
	if parsed.name == "": return "Usage: give [@target] [xCOUNT] <item> [xCOUNT]"
	var item_id := _resolve_registry_id(parsed.name, Registry.items, Registry.blocks)
	if item_id == "": return "No such item: " + parsed.name
	var changed := 0
	for target in request.targets:
		var inventory = target.get("inventory")
		if inventory != null: inventory.add(item_id, parsed.count); changed += 1
	if changed == 0: return "No target inventory."
	return "Gave %d x %s to %d player(s)." % [parsed.count, item_id, changed]

static func _tp(args: Array, game, executor) -> String:
	var request := _extract_targets(args, game, executor)
	if request.error != "": return request.error
	if request.args.size() < 3: return "Usage: tp [@target] <x> <y> <z>"
	for i in range(3):
		if not str(request.args[i]).is_valid_float(): return "Bad coordinates."
	var destination := Vector3(float(request.args[0]), float(request.args[1]), float(request.args[2]))
	for target in request.targets: target.global_position = destination; target.velocity = Vector3.ZERO
	return "Teleported %d player(s)." % request.targets.size()

static func _gamemode(args: Array, game, executor) -> String:
	var request := _extract_targets(args, game, executor)
	if request.error != "": return request.error
	if request.args.is_empty(): return "Usage: gamemode [@target] <creative|survival|adventure|hardcore>"
	var names := ["creative", "survival", "adventure", "hardcore"]
	var value := str(request.args[0]).to_lower()
	var mode := int(value) if value.is_valid_int() else names.find(value)
	if mode < 0 or mode > 3: return "Bad game mode."
	for target in request.targets: target.configure(mode, target.difficulty)
	return "Game mode: %s for %d player(s)." % [names[mode], request.targets.size()]

static func _difficulty(args: Array, game, executor) -> String:
	var request := _extract_targets(args, game, executor)
	if request.error != "": return request.error
	if request.args.is_empty(): return "Usage: difficulty [@target] <peaceful|easy|normal|hard>"
	var names := ["peaceful", "easy", "normal", "hard"]
	var value := str(request.args[0]).to_lower()
	var diff := int(value) if value.is_valid_int() else names.find(value)
	if diff < 0 or diff > 3: return "Bad difficulty."
	for target in request.targets: target.configure(target.game_mode, diff)
	return "Difficulty: %s for %d player(s)." % [names[diff], request.targets.size()]

static func _time(args: Array, game, executor) -> String:
	if game == null: return "No game."
	var request := _extract_targets(args, game, executor)
	if request.error != "": return request.error
	if request.args.is_empty(): return "Usage: time [@target] <day|night|0..1>"
	var value := str(request.args[0]).to_lower()
	if value == "day": game.time_of_day = 0.3
	elif value == "night": game.time_of_day = 0.8
	elif value.is_valid_float(): game.time_of_day = clampf(float(value), 0.0, 1.0)
	else: return "Bad time."
	return "Time set."

static func _weather(args: Array, game, executor) -> String:
	if game == null: return "No game."
	var request := _extract_targets(args, game, executor)
	if request.error != "": return request.error
	if request.args.is_empty(): return "Usage: weather [@target] <clear|rainy|thunderstorm>"
	var mode := str(request.args[0]).to_lower()
	if mode in ["clear", "sunny", "sun"]: mode = "clear"
	elif mode in ["rain", "rainy"]: mode = "rainy"
	elif mode in ["thunder", "storm", "thunderstorm"]: mode = "thunderstorm"
	else: return "Bad weather. Use clear, rainy or thunderstorm."
	if game.has_method("set_weather"): game.set_weather(mode)
	else: game.is_raining = mode != "clear"; game.is_thunderstorm = mode == "thunderstorm"
	return "Weather: " + mode

static func _say(args: Array, game, executor) -> String:
	var request := _extract_targets(args, game, executor)
	if request.error != "": return request.error
	var msg := " ".join(request.args)
	if msg.is_empty(): return "Usage: say [@target] <message>"
	var delivered := 0
	for target in request.targets:
		var target_ui = target.get_meta("ui", null)
		if target_ui == null and game != null: target_ui = game.get("ui")
		if target_ui != null and is_instance_valid(target_ui):
			if target_ui.has_method("_show_chat_line"): target_ui._show_chat_line(1, msg)
			elif target_ui.get("_chat_msg") != null: target_ui._chat_msg.text = msg
			delivered += 1
	return msg + " (%d recipient(s))" % delivered

static func _heal(args: Array, game, executor) -> String:
	var request := _extract_targets(args, game, executor)
	if request.error != "": return request.error
	for target in request.targets: target.health = target.max_health; target.hunger = target.max_hunger
	return "Healed %d player(s)." % request.targets.size()

static func _kill(args: Array, game, executor) -> String:
	var request := _extract_targets(args, game, executor)
	if request.error != "": return request.error
	for target in request.targets:
		if target.has_method("_die"): target._die()
	return "Killed %d player(s)." % request.targets.size()

static func _summon(args: Array, game, executor) -> String:
	var request := _extract_targets(args, game, executor)
	if request.error != "": return request.error
	var parsed := _extract_count_and_name(request.args, MAX_SPAWN_COUNT)
	if parsed.name == "": return "Usage: spawn [@target] [xCOUNT] <mob> [xCOUNT]"
	var mob_id := _resolve_registry_id(parsed.name, Registry.mobs)
	if mob_id == "": return "Unknown mob: " + parsed.name
	var spawned := 0
	for target in request.targets:
		for i in range(parsed.count):
			var angle := float(i) * 2.399963
			var radius := 2.0 + 0.55 * sqrt(float(i))
			var pos = target.global_position + Vector3(cos(angle) * radius, 1.0, sin(angle) * radius)
			var mob = _spawn_one(mob_id, pos, game, target)
			if mob != null: _configure_special_mob(mob_id, mob, game, target); spawned += 1
	return "Spawned %d x %s." % [spawned, mob_id] if spawned > 0 else "Spawn failed."

static func _locate(args: Array, game, executor) -> String:
	if game == null or not game.has_method("locate_structure"):
		return "No locator."
	if args.is_empty():
		return "Usage: locate <stronghold|village|mineshaft|fortress>"
	var kind := str(args[0]).to_lower()
	var pos: Vector3 = game.locate_structure(kind)
	return "Nearest %s: %d %d %d" % [kind, int(pos.x), int(pos.y), int(pos.z)]


static func _spawn_one(mob_id: String, pos: Vector3, game, target):
	if game != null and game.get("mob_manager") != null: return game.mob_manager.spawn(mob_id, pos)
	var scene_root = target.get_tree().current_scene
	var mob
	if mob_id == "villager": mob = Villager.new()
	elif mob_id == "hero_no_brain": mob = HeroNoBrain.new()
	elif mob_id == "charlie_emily": mob = CharlieEmily.new()
	else: mob = Mob.new()
	mob.setup(mob_id, target); scene_root.add_child(mob); mob.global_position = pos
	return mob

static func _configure_special_mob(mob_id: String, mob, game, target) -> void:
	if game == null: return
	if mob_id == "hero_no_brain" and game.get("event_manager") != null: game.event_manager._hero = mob
	if mob_id == "charlie_emily":
		var folders = Registry.music.get("folders", {})
		Music.play_event(Registry.music.get("charlie_emily_track", "X120 Left Behind.mp3"), folders.get("charlie", "Charlie Emily"))
		if game.get("event_manager") != null:
			game.event_manager._charlie = mob; game.event_manager._charlie_timer = 30.0; game.event_manager.player = target

static func _extract_targets(args: Array, game, executor) -> Dictionary:
	var clean: Array = []
	var selector := ""
	for value in args:
		var token := str(value)
		if selector.is_empty() and token.begins_with("@"): selector = token
		else: clean.append(token)
	var effective := selector if not selector.is_empty() else "@s"
	var targets := _resolve_selector(effective, game, executor)
	if targets.is_empty(): return {"args": clean, "targets": [], "error": "No player matches " + effective}
	return {"args": clean, "targets": targets, "error": ""}

static func _resolve_selector(selector: String, game, executor) -> Array:
	var players := _all_players(game, executor)
	var key := selector.trim_prefix("@").to_lower()
	if key == "s": return [executor] if executor != null else []
	if key == "a": return players
	if key == "p":
		if players.is_empty(): return []
		var origin = executor.global_position if executor != null else Vector3.ZERO
		var nearest = players[0]
		var best = origin.distance_squared_to(nearest.global_position)
		for candidate in players:
			var distance = origin.distance_squared_to(candidate.global_position)
			if distance < best: nearest = candidate; best = distance
		return [nearest]
	var wanted := _normalize_name(key)
	for candidate in players:
		for candidate_name in _player_names(candidate):
			if _normalize_name(candidate_name) == wanted: return [candidate]
	return []

static func _all_players(game, executor) -> Array:
	var result: Array = []
	var tree: SceneTree = executor.get_tree() if executor != null else (game.get_tree() if game != null else null)
	if tree != null:
		for candidate in tree.get_nodes_in_group("players"):
			if candidate != null and is_instance_valid(candidate) and not result.has(candidate): result.append(candidate)
	if result.is_empty() and executor != null: result.append(executor)
	return result

static func _player_names(player) -> Array:
	var names: Array = [str(player.name)]
	var skin_name = player.get("current_skin_name")
	if skin_name != null: names.append(str(skin_name))
	for meta_name in ["player_name", "display_name", "username"]:
		if player.has_meta(meta_name): names.append(str(player.get_meta(meta_name)))
	return names

static func _extract_count_and_name(args: Array, maximum: int) -> Dictionary:
	var count := 1
	var name_parts: Array = []
	for value in args:
		var token := str(value)
		var parsed_count := _count_token(token)
		if parsed_count > 0: count = clampi(parsed_count, 1, maximum)
		else: name_parts.append(token)
	return {"name": _normalize_name("_".join(name_parts)), "count": count}

static func _count_token(token: String) -> int:
	var lower := token.to_lower()
	if lower.begins_with("x") and lower.substr(1).is_valid_int(): return int(lower.substr(1))
	if lower.is_valid_int(): return int(lower)
	return -1

static func _resolve_registry_id(raw_name: String, primary: Dictionary, secondary: Dictionary = {}) -> String:
	var wanted := _normalize_name(raw_name)
	for dictionary in [primary, secondary]:
		if dictionary.has(wanted): return wanted
		for id in dictionary.keys():
			var entry = dictionary[id]
			if _normalize_name(str(id)) == wanted: return str(id)
			if entry is Dictionary and _normalize_name(str(entry.get("name", ""))) == wanted: return str(id)
	if wanted.ends_with("s"): return _resolve_registry_id(wanted.substr(0, wanted.length() - 1), primary, secondary)
	return ""

static func _normalize_name(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
