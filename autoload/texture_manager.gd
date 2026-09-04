extends Node
# HighCraft - texture manager (autoload singleton "Textures").
# You have no textures, so HighCraft generates its own 16x16 placeholders at
# runtime (no external tools needed). Fully swappable: put a real PNG named
# "<id>.png" in res://assets/textures/ and it is used instead.

const SIZE = 16
const TEX_DIR = "res://assets/textures/"

var _cache: Dictionary = {}

# explicit palette for the important blocks (rgb 0-255)
var _palette: Dictionary = {
	"grass_block": [95, 159, 53], "dirt": [134, 96, 67], "stone": [127, 127, 127],
	"cobblestone": [122, 122, 122], "sand": [219, 207, 163], "sandstone": [215, 202, 157],
	"gravel": [136, 126, 125], "clay": [160, 165, 178], "water": [60, 100, 220],
	"lava": [220, 110, 40], "obsidian": [20, 18, 33], "bedrock": [40, 40, 40],
	"netherrack": [110, 50, 50], "soul_sand": [85, 66, 54], "glowstone": [228, 199, 108],
	"end_stone": [221, 223, 165], "ice": [145, 183, 240], "snow_block": [240, 246, 250],
	"oak_log": [109, 86, 52], "birch_log": [200, 198, 185], "spruce_log": [84, 66, 41],
	"jungle_log": [120, 90, 60], "oak_planks": [162, 130, 78], "oak_leaves": [60, 120, 45],
	"coal_ore": [70, 70, 70], "iron_ore": [180, 150, 130], "gold_ore": [210, 190, 90],
	"copper_ore": [200, 130, 90], "redstone_ore": [180, 50, 50], "lapis_ore": [40, 70, 160],
	"diamond_ore": [90, 200, 210], "emerald_ore": [40, 180, 90],
	"iron_block": [216, 216, 216], "gold_block": [240, 220, 90], "copper_block": [200, 120, 80],
	"diamond_block": [110, 220, 225], "crafting_table": [140, 100, 60], "toolbench": [120, 90, 70],
	"furnace": [100, 100, 100], "chest": [160, 120, 60], "bookshelf": [150, 110, 70],
	"glass": [200, 230, 245], "tnt": [200, 60, 50], "cloud_wool": [245, 248, 252],
	"redstone": [190, 30, 30], "daylight_sensor": [80, 90, 70], "daylight_sensor_on": [120, 140, 60],
	"piston": [140, 120, 90], "sticky_piston": [90, 140, 70], "piston_head": [160, 140, 110],
	"fence_oak": [162, 130, 78], "fence_gate_oak": [162, 130, 78], "fence_gate_oak_open": [162, 130, 78],
	"lever": [120, 120, 120], "lever_on": [140, 140, 100],
	# Mobs – distinct colors so they are recognizable without unique PNGs
	"sheep": [240, 240, 240], "cow": [90, 60, 40], "mooshroom": [180, 50, 50],
	"pig": [255, 170, 170], "chicken": [250, 250, 240], "rabbit": [200, 170, 140],
	"horse": [160, 110, 70], "ocelot": [230, 190, 80], "squid": [40, 50, 90],
	"bat": [50, 40, 35], "villager": [90, 70, 50], "snow_golem": [230, 240, 250],
	"iron_golem": [180, 180, 185], "erebite": [40, 10, 50], "zombie_pigman": [200, 150, 80],
	"wolf": [180, 180, 185], "spider": [50, 40, 40], "cave_spider": [40, 70, 40],
	"zombie": [50, 90, 50], "husk": [180, 160, 110], "zombie_villager": [60, 100, 55],
	"skeleton": [220, 220, 210], "stray": [180, 200, 220], "creeper": [60, 160, 60],
	"witch": [60, 40, 70], "slime": [90, 200, 80], "silverfish": [120, 120, 130],
	"endermite": [60, 20, 70], "soulwraith": [230, 230, 240], "magma_cube": [200, 80, 30],
	"blaze": [240, 180, 40], "wither_skeleton": [30, 30, 30], "shulker": [140, 80, 160],
	"erebus_sovereign": [30, 10, 40], "wither": [40, 40, 40], "hero_no_brain": [80, 200, 80],
	"charlie_emily": [240, 200, 180], "ender_dragon": [30, 10, 40]
}

var _material: Dictionary = {
	"wood": [150, 110, 60], "stone": [120, 120, 120], "copper": [200, 120, 80],
	"iron": [210, 210, 210], "gold": [240, 220, 90], "diamond": [90, 215, 220],
	"leather": [150, 110, 70], "coal": [45, 45, 45], "redstone": [190, 30, 30],
	"lapis_lazuli": [35, 65, 160], "emerald": [40, 190, 95], "stick": [150, 115, 65]
}


func get_texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var tex: Texture2D = null
	if has_node("/root/Addons"):
		var external_path := str(get_node("/root/Addons").find_texture(id))
		if external_path != "":
			var image := Image.new()
			if image.load(external_path) == OK:
				tex = ImageTexture.create_from_image(image)
	var path = TEX_DIR + id + ".png"
	if tex == null and ResourceLoader.exists(path):
		tex = load(path)
	if tex == null:
		tex = _generate(id)
	_cache[id] = tex
	return tex


func clear_cache() -> void:
	_cache.clear()


func _base_color(id: String) -> Color:
	if _palette.has(id):
		var p = _palette[id]
		return Color(p[0] / 255.0, p[1] / 255.0, p[2] / 255.0)
	for key in _material.keys():
		if id.begins_with(key + "_") or id == key or id.find(key) >= 0:
			var m = _material[key]
			return Color(m[0] / 255.0, m[1] / 255.0, m[2] / 255.0)
	var h = abs(hash(id))
	return Color((h & 255) / 255.0, ((h >> 8) & 255) / 255.0, ((h >> 16) & 255) / 255.0)


func _is_item(id: String) -> bool:
	var it = Registry.get_item(id)
	return it != null and not Registry.blocks.has(id)


func _clampc(v: float) -> float:
	return clamp(v, 0.0, 1.0)


func _generate(id: String) -> ImageTexture:
	var img = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var base = _base_color(id)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(id)
	var item_mode = _is_item(id)
	var translucent = (id == "glass" or id == "water" or id == "ice")
	var is_tool = (id.ends_with("_pickaxe") or id.ends_with("_axe")
		or id.ends_with("_shovel") or id.ends_with("_sword"))

	for y in range(SIZE):
		for x in range(SIZE):
			if item_mode:
				var inside = false
				if is_tool:
					if abs((SIZE - 1 - x) - y) <= 2:
						inside = true
					if y <= 5 and x >= SIZE - 6:
						inside = true
				else:
					var dx = x - SIZE / 2.0 + 0.5
					var dy = y - SIZE / 2.0 + 0.5
					if dx * dx + dy * dy <= pow(SIZE * 0.42, 2):
						inside = true
				if inside:
					var n = (rng.randf() - 0.5) * 0.12
					var col = Color(_clampc(base.r + n), _clampc(base.g + n), _clampc(base.b + n), 1.0)
					img.set_pixel(x, y, col)
				else:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var n2 = (rng.randf() - 0.5) * 0.14
				var edge = 0.0
				if x == 0 or y == 0 or x == SIZE - 1 or y == SIZE - 1:
					edge = -0.1
				var a = 1.0
				if translucent:
					a = 0.6
				var cr = _clampc(base.r + n2 + edge)
				var cg = _clampc(base.g + n2 + edge)
				var cb = _clampc(base.b + n2 + edge)
				img.set_pixel(x, y, Color(cr, cg, cb, a))

	# ore speckles
	if id.ends_with("_ore"):
		var spec = _base_color(id.replace("_ore", ""))
		for i in range(10):
			var sx = rng.randi_range(0, SIZE - 2)
			var sy = rng.randi_range(0, SIZE - 2)
			img.set_pixel(sx, sy, spec)
			img.set_pixel(sx + 1, sy, spec)
			img.set_pixel(sx, sy + 1, spec)
			img.set_pixel(sx + 1, sy + 1, spec)

	return ImageTexture.create_from_image(img)
