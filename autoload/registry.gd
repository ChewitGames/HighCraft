extends Node
# HighCraft - central data registry (autoload singleton "Registry").
# Loads every block / item / recipe / mob / dimension / music entry from
# res://data/*.json so the game is fully data-driven. Tools and armor are
# expanded from a compact config instead of being listed one by one.

const DATA_DIR = "res://data/"

var blocks: Dictionary = {}
var items: Dictionary = {}
var recipes: Array = []
var smelting: Array = []
var mobs: Dictionary = {}
var dimensions: Dictionary = {}
var records: Array = []
var music: Dictionary = {}
var trades: Dictionary = {}
var block_models: Dictionary = {}
var mob_models: Dictionary = {}

func is_solid(id: String) -> bool:
	var b = get_block(id)
	if b == null:
		return true
	return bool(b.get("solid", true))


func _ready() -> void:
	load_block_models()
	load_mob_models()
	_load_blocks()
	_load_items()
	_load_mobs()
	_load_dimensions()
	_load_music()
	_load_recipes()
	_load_trades()
	load_enchantments()
	load_potions()
	_register_potion_items()
	_register_enchanted_books()
	print("[HighCraft] Registry loaded -> ", summary())
	
func load_block_models() -> void:
	var file = FileAccess.open("res://data/block_models.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			block_models = json.data.get("models", {})
		file.close()

func load_mob_models() -> void:
	var file = FileAccess.open("res://data/mob_models.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			mob_models = json.data.get("mobs", {})
		file.close()

func get_block_model(id: String) -> Dictionary:
	return block_models.get(id, {})

func get_mob_model(id: String) -> Dictionary:
	return mob_models.get(id, {"type": "biped"})


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		push_warning("Missing data file: " + path)
		return null
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open: " + path)
		return null
	var text = f.get_as_text()
	f.close()
	var result = JSON.parse_string(text)
	if result == null:
		push_error("Invalid JSON: " + path)
	return result


func _title(s: String) -> String:
	var parts = s.split("_")
	var out: Array = []
	for p in parts:
		if p.length() > 0:
			out.append(p.substr(0, 1).to_upper() + p.substr(1))
	return " ".join(out)


# ---------------------------------------------------------------- blocks
func _load_blocks() -> void:
	var data = _read_json(DATA_DIR + "blocks.json")
	if data == null:
		return
	for b in data["blocks"]:
		blocks[b["id"]] = b
	for c in data.get("wool_colors", []):
		var wool_id = c + "_wool"
		blocks[wool_id] = {"id": wool_id, "name": _title(c) + " Wool", "hardness": 0.8,
			"tool": "shears", "tier": 0, "light": 0, "transparent": false, "drops": []}
		var clay_id = c + "_hardened_clay"
		blocks[clay_id] = {"id": clay_id, "name": _title(c) + " Hardened Clay", "hardness": 1.25,
			"tool": "pickaxe", "tier": 1, "light": 0, "transparent": false, "drops": []}


# ---------------------------------------------------------------- items
func _load_items() -> void:
	var data = _read_json(DATA_DIR + "items.json")
	if data == null:
		return
	for m in data["materials"]:
		items[m[0]] = {"id": m[0], "name": m[1], "type": "material", "max_stack": 64}
	for fd in data["foods"]:
		items[fd[0]] = {"id": fd[0], "name": fd[1], "type": "food",
			"hunger": int(fd[2]), "saturation": float(fd[3]), "max_stack": 64}
	for ms in data["misc"]:
		items[ms[0]] = {"id": ms[0], "name": ms[1], "type": "misc", "max_stack": 1}
	if not items.has("boat"):
		items["boat"] = {"id": "boat", "name": "Boat", "type": "misc", "max_stack": 1}

	var tier_stats = data["tier_stats"]
	var dmg_bonus = data["damage_bonus"]
	for mat in data["tool_materials"]:
		for tt in data["tool_types"]:
			var tid = mat + "_" + tt
			var stats = tier_stats[mat]
			var dmg = int(stats["damage"]) + int(dmg_bonus.get(tt, 0))
			items[tid] = {"id": tid, "name": _title(mat) + " " + _title(tt), "type": "tool",
				"tool_type": tt, "material": mat, "tier": int(stats["tier"]),
				"durability": int(stats["durability"]), "damage": dmg, "max_stack": 1}

	var apoints = data["armor_points"]
	var adur = data["armor_durability"]
	for mat in data["armor_materials"]:
		for slot in data["armor_slots"]:
			var aid = mat + "_" + slot
			items[aid] = {"id": aid, "name": _title(mat) + " " + _title(slot), "type": "armor",
				"material": mat, "slot": slot, "armor_points": int(apoints[mat][slot]),
				"durability": int(adur[mat]), "max_stack": 1}


# ---------------------------------------------------------------- mobs
func _load_mobs() -> void:
	var data = _read_json(DATA_DIR + "mobs.json")
	if data == null:
		return
	for m in data["mobs"]:
		mobs[m["id"]] = m
	_generate_spawn_eggs()


## Spawn eggs for creative + survival use. Excludes story/special mobs.
func _generate_spawn_eggs() -> void:
	const EXCLUDE := ["charlie_emily", "hero_no_brain", "ender_dragon", "erebus_sovereign", "wither"]
	for mid in mobs.keys():
		if mid in EXCLUDE:
			continue
		var egg_id := "spawn_egg_%s" % mid
		items[egg_id] = {
			"id": egg_id,
			"name": "%s Spawn Egg" % _title(mid),
			"type": "spawn_egg",
			"mob": mid,
			"max_stack": 64,
		}


# ---------------------------------------------------------------- dimensions
func _load_dimensions() -> void:
	var data = _read_json(DATA_DIR + "dimensions.json")
	if data == null:
		return
	for d in data["dimensions"]:
		dimensions[d["id"]] = d


# ---------------------------------------------------------------- music
func _load_music() -> void:
	var data = _read_json(DATA_DIR + "music.json")
	if data == null:
		music = {}
		return
	music = data
	var seen: Dictionary = {}
	var all_tracks: Array = []
	all_tracks.append_array(data.get("overworld_tracks", []))
	all_tracks.append_array(data.get("beta_tracks", []))
	all_tracks.append_array(data.get("menu_tracks", []))
	var charlie = data.get("charlie_emily_track", "")
	if charlie != "":
		all_tracks.append(charlie)
	for t in all_tracks:
		if t == "" or seen.has(t):
			continue
		seen[t] = true
		var rid = "record_" + t.to_lower().replace(".mp3", "").replace(" ", "_").replace(".", "_")
		records.append({"id": rid, "track": t})
		items[rid] = {"id": rid, "name": "Music Disc - " + t.replace(".mp3", ""),
			"type": "record", "track": t, "max_stack": 1}


# ---------------------------------------------------------------- recipes
func _expand_shape(shape: Array, ingredients: Dictionary) -> Array:
	var grid: Array = []
	var width = 0
	for row in shape:
		width = max(width, row.length())
	for row in shape:
		var cells: Array = []
		for i in range(width):
			var ch = " "
			if i < row.length():
				ch = row.substr(i, 1)
			if ch == " ":
				cells.append("")
			else:
				cells.append(ingredients[ch])
		grid.append(cells)
	return grid


func _load_recipes() -> void:
	var files = ["basics", "tools", "armor", "misc_and_food"]
	for name in files:
		var data = _read_json(DATA_DIR + "recipes/" + name + ".json")
		if data == null:
			continue
		for entry in data:
			if entry.has("shapeless"):
				recipes.append({"type": "shapeless", "result": entry["result"],
					"count": int(entry.get("count", 1)), "ingredients": entry["shapeless"]})
			else:
				recipes.append({"type": "shaped", "result": entry["result"],
					"count": int(entry.get("count", 1)),
					"pattern": _expand_shape(entry["shape"], entry["ingredients"])})
	var sm = _read_json(DATA_DIR + "recipes/smelting.json")
	if sm != null:
		for entry in sm:
			smelting.append({"result": entry["result"], "count": int(entry.get("count", 1)),
				"input": entry["input"]})
				
# Add this code to your existing Registry.gd
# Best place: After loading other data (e.g. after smelting)

var enchantments: Dictionary = {}
var potions: Dictionary = {}

func load_enchantments() -> void:
	var file = FileAccess.open("res://data/enchantments.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var result = json.parse(file.get_as_text())
		if result == OK:
			var data = json.data
			for ench in data:
				enchantments[ench["id"]] = ench
			print("[Registry] Loaded ", enchantments.size(), " enchantments")
		file.close()

func load_potions() -> void:
	var file = FileAccess.open("res://data/potions.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var result = json.parse(file.get_as_text())
		if result == OK:
			var data = json.data
			for pot in data:
				potions[pot["id"]] = pot
			print("[Registry] Loaded ", potions.size(), " potions")
		file.close()


func _register_potion_items() -> void:
	for pid in potions.keys():
		var pot = potions[pid]
		if not items.has(pid):
			items[pid] = {
				"id": pid,
				"name": str(pot.get("name", _title(pid))),
				"type": "potion",
				"max_stack": 1,
				"effects": pot.get("effects", []),
			}
		else:
			items[pid]["type"] = "potion"
			items[pid]["effects"] = pot.get("effects", [])
		# Splash variant
		var sid = "splash_" + pid
		if pid.begins_with("potion_") or pid in ["awkward_potion", "mundane_potion", "thick_potion", "water_bottle"]:
			if not items.has(sid):
				items[sid] = {
					"id": sid,
					"name": "Splash " + str(pot.get("name", _title(pid))),
					"type": "potion",
					"max_stack": 1,
					"effects": pot.get("effects", []),
					"splash": true,
				}
			if not potions.has(sid):
				var splash = pot.duplicate(true)
				splash["id"] = sid
				splash["name"] = "Splash " + str(pot.get("name", _title(pid)))
				splash["base"] = pid
				splash["ingredient"] = "gunpowder"
				potions[sid] = splash
	# Ensure bottles exist as items
	if not items.has("glass_bottle"):
		items["glass_bottle"] = {"id": "glass_bottle", "name": "Glass Bottle", "type": "material", "max_stack": 64}
	if not items.has("water_bottle"):
		items["water_bottle"] = {"id": "water_bottle", "name": "Water Bottle", "type": "potion", "max_stack": 1}


func _register_enchanted_books() -> void:
	if not items.has("enchanted_book"):
		items["enchanted_book"] = {"id": "enchanted_book", "name": "Enchanted Book", "type": "book", "max_stack": 1}
	if not items.has("book"):
		items["book"] = {"id": "book", "name": "Book", "type": "material", "max_stack": 64}
	for eid in enchantments.keys():
		var book_id = "enchanted_book_" + str(eid)
		if items.has(book_id):
			continue
		var ench = enchantments[eid]
		items[book_id] = {
			"id": book_id,
			"name": "Enchanted Book: " + str(ench.get("name", _title(eid))),
			"type": "book",
			"max_stack": 1,
			"stored_enchant": eid,
		}


func brew_result(base_id: String, ingredient: String) -> String:
	for pid in potions.keys():
		var pot = potions[pid]
		if str(pot.get("base", "")) == base_id and str(pot.get("ingredient", "")) == ingredient:
			return str(pid)
	if ingredient == "gunpowder":
		if base_id.begins_with("splash_"):
			return ""
		if potions.has(base_id) or items.has(base_id):
			return "splash_" + base_id
	return ""


func normalize_dimension_id(id: String) -> String:
	var s := id.strip_edges().to_lower()
	if s in ["nether", "the_nether", "the_hell", "hell_dimension"]:
		return "hell"
	if s in ["end", "theend", "the_end"]:
		return "the_end"
	if s in ["the_heaven", "sky", "aether"]:
		return "heaven"
	if dimensions.has(s):
		return s
	return "overworld"


func require_dimension(id: String) -> String:
	return normalize_dimension_id(id)


func get_dimension(id: String) -> Dictionary:
	var canon := normalize_dimension_id(id)
	return dimensions.get(canon, {"id": canon, "name": _title(canon)})


func roman_level(level: int) -> String:
	var map = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	if level >= 0 and level < map.size():
		return map[level]
	return str(level)


func enchantment_display(eid: String, level: int) -> String:
	var name := _title(eid)
	if enchantments.has(eid):
		name = str(enchantments[eid].get("name", name))
	return name + " " + roman_level(level)

# Call these two functions in your _ready() or after loading other data:
# load_enchantments()
# load_potions()



func _load_trades() -> void:
	var data = _read_json(DATA_DIR + "trades.json")
	if data == null:
		return
	for prof in data.keys():
		if prof.begins_with("_"):
			continue
		trades[prof] = data[prof]


# ---------------------------------------------------------------- lookups
func get_block(id: String):
	return blocks.get(id, null)


func get_item(id: String):
	return items.get(id, null)


func get_mob(id: String):
	return mobs.get(id, null)


func is_opaque(id: String) -> bool:
	if id.is_empty() or id == "air":
		return false
	var b = blocks.get(id, null)
	if b == null:
		return true
	if bool(b.get("transparent", false)):
		return false
	# Non-full unique models must NOT hide the block underneath / beside
	var model = get_block_model(id)
	var mt = str(model.get("type", ""))
	if mt in [
		"redstone_wire", "torch", "rail", "pressure_plate", "button",
		"lever", "fence", "fence_gate", "cross", "hopper", "anvil", "bed", "fire",
		"stairs", "door", "trapdoor", "chest", "piston", "piston_head",
		"dropper", "dispenser", "repeater", "comparator", "daylight_sensor",
		"skull", "enchanting_table", "portal"
	]:
		return false
	if id in ["nether_portal", "heaven_portal", "end_portal", "fire", "end_crystal", "brewing_stand"]:
		return false
	return true


func max_stack_of(id: String) -> int:
	var it = items.get(id, null)
	if it != null:
		return int(it.get("max_stack", 64))
	return 64


func summary() -> String:
	return "blocks=%d items=%d recipes=%d smelting=%d mobs=%d dimensions=%d records=%d" % [
		blocks.size(), items.size(), recipes.size(), smelting.size(),
		mobs.size(), dimensions.size(), records.size()]
