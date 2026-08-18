# texture_manager.gd
extends Node

var _cache: Dictionary = {}

func get_texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	
	# Echte Textur zuerst versuchen
	var path = "res://textures/" + id + ".png"
	if ResourceLoader.exists(path):
		var tex = load(path)
		_cache[id] = tex
		return tex
	
	# Prozedurale Fallback-Textur generieren
	var tex = _generate_fallback(id)
	_cache[id] = tex
	return tex
	
func preload_all() -> void:
	print("Texture Generator: Preloading all textures...")

	# Alle Blöcke
	for id in Registry.blocks.keys():
		get_texture(id)

	# Alle Items
	for id in Registry.items.keys():
		get_texture(id)

	# Alle Mobs
	for id in Registry.mobs.keys():
		get_texture(id)

	print("Texture Generator: Preloading finished. Cached textures: ", _cache.size())


func _generate_fallback(id: String) -> ImageTexture:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var color = _get_color(id)
	var name = id.to_lower()

	img.fill(Color(0, 0, 0, 0))

	if "dragon_egg" in name:
		_draw_dragon_egg(img, color)
	elif "name_tag" in name:
		_draw_name_tag(img, color)
	elif "saddle" in name:
		_draw_saddle(img, color)
	elif "flint_and_steel" in name:
		_draw_flint_and_steel(img, color)
	elif "helmet" in name:
		_draw_helmet(img, color)
	elif "chestplate" in name:
		_draw_chestplate(img, color)
	elif "leggings" in name:
		_draw_leggings(img, color)
	elif "boots" in name:
		_draw_boots(img, color)
	elif "clock" in name:
		_draw_clock(img, color)
	elif "compass" in name:
		_draw_compass(img, color)
	elif "map" in name:
		_draw_map(img, color)
	elif "lead" in name:
		_draw_lead(img, color)
	elif "bow" in name:
		_draw_bow(img, color)
	elif "arrow" in name:
		_draw_arrow(img, color)
	elif "bucket" in name:
		_draw_bucket(img, color)
	elif "fishing_rod" in name:
		_draw_fishing_rod(img, color)
	elif "elytra" in name:
		_draw_elytra(img, color)
	elif "disc" in name or "record" in name:
		_draw_disc(img, color)
	elif "pickaxe" in name or "axe" in name or "shovel" in name or "sword" in name:
		_draw_tool(img, color, name)
	elif "cake" in name:
		_draw_cake(img, color)
	elif "pumpkin_pie" in name:
		_draw_pumpkin_pie(img, color)
	elif "cookie" in name:
		_draw_cookie(img, color)
	elif "golden_apple" in name:
		_draw_golden_apple(img, color)
	elif "paper" in name:
		_draw_paper(img, color)
	elif "book" in name:
		_draw_book(img, color)
	elif "bone_meal" in name:
		_draw_bone_meal(img, color)
	elif "firework_rocket" in name:
		_draw_firework_rocket(img, color)
	elif "firework_star" in name:
		_draw_firework_star(img, color)
	elif Registry.items.has(id) and Registry.items[id].get("category", "") == "food":
		_draw_food(img, color, name)
	elif Registry.mobs.has(id):
		_draw_mob(img, color, name)
		
	elif "mutton" in name or "steak" in name or "cooked_beef" in name or "beef" in name:
		_draw_food(img, color, name)
	elif "porkchop" in name:
		_draw_food(img, color, name)
	elif "chicken" in name and Registry.items.has(id):
		_draw_food(img, color, name)
	elif "carrot" in name:
		_draw_food(img, color, name)
	elif "potato" in name:
		_draw_food(img, color, name)
	elif "apple" in name:
		_draw_food(img, color, name)
	elif "melon" in name:
		_draw_food(img, color, name)
	elif "bread" in name:
		_draw_food(img, color, name)
	elif "rotten_flesh" in name:
		_draw_food(img, color, name)
	elif "spider_eye" in name:
		_draw_food(img, color, name)
	
	elif "water_bucket" in name:
		_draw_water_bucket(img, color)
	elif "lava_bucket" in name:
		_draw_lava_bucket(img, color)
	elif "milk_bucket" in name:
		_draw_milk_bucket(img, color)
	elif "shears" in name:
		_draw_shears(img, color)
	elif Registry.items.has(id) and id in ["coal","charcoal","iron_ingot","gold_ingot","copper_ingot","diamond","emerald","redstone","lapis_lazuli","nether_quartz","stick","string","leather","feather","bone","gunpowder","ender_pearl","blaze_rod","blaze_powder","ghast_tear","magma_cream","slimeball","clay_ball","glowstone_dust","snowball","flint","wheat","sugar","egg","rose","fire_charge","banner","rotten_flesh","spider_eye","ink_sac","gold_nugget","rabbit_hide","shulker_shell","dragon_egg","nether_star"]:
		_draw_material(img, color, name)
	elif Registry.items.has(id) and id in ["bread","cooked_beef","cooked_porkchop","cooked_chicken","cooked_fish","apple","golden_apple","enchanted_golden_apple","carrot","potato","baked_potato","melon_slice","pumpkin_pie","cake","cookie","mushroom_stew","beef","porkchop","chicken","fish","mutton"]:
		_draw_food(img, color, name)	
		
	elif id in ["sharpness","protection","efficiency","unbreaking","power"]:
		_draw_enchantment(img, color, name)
		
	elif "wool" in name:
		_draw_wool(img, color, name)
	elif id == "clay":
		_draw_clay(img, color)
	elif "redstone" in name and Registry.blocks.has(id):
		_draw_redstone_wire(img, color)
	elif "potion" in name or "awkward_potion" in name:
		_draw_potion(img, color, name)
	elif id in ["sharpness","protection","efficiency","unbreaking","power"]:
		_draw_enchantment(img, color, name)
		
	else:
		_draw_block(img, color, name)

	return ImageTexture.create_from_image(img)
	
func _draw_wool(img: Image, color: Color, name: String):
	img.fill(color)
	for i in range(24):
		var x = randi() % 16
		var y = randi() % 16
		img.set_pixel(x, y, color.darkened(0.12))
	for i in range(14):
		var x = randi() % 16
		var y = randi() % 16
		img.set_pixel(x, y, color.lightened(0.1))
	for x in range(16):
		for y in range(16):
			if x < 1 or x > 14 or y < 1 or y > 14:
				img.set_pixel(x, y, color.darkened(0.3))


func _draw_clay(img: Image, color: Color):
	img.fill(color)
	for gx in range(0, 16, 4):
		for y in range(16):
			img.set_pixel(gx, y, color.darkened(0.2))
	for gy in range(0, 16, 4):
		for x in range(16):
			img.set_pixel(x, gy, color.darkened(0.2))
	for i in range(10):
		var x = randi() % 16
		var y = randi() % 16
		img.set_pixel(x, y, color.lightened(0.08))


func _draw_redstone_wire(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(6, 10):
		for y in range(6, 10):
			img.set_pixel(x, y, Color(0.6, 0.05, 0.05))
	for x in range(0, 6):
		img.set_pixel(x, 7, Color(0.75, 0.1, 0.1))
		img.set_pixel(x, 8, Color(0.5, 0.05, 0.05))
	for x in range(10, 16):
		img.set_pixel(x, 7, Color(0.75, 0.1, 0.1))
		img.set_pixel(x, 8, Color(0.5, 0.05, 0.05))
	for y in range(0, 6):
		img.set_pixel(7, y, Color(0.75, 0.1, 0.1))
		img.set_pixel(8, y, Color(0.5, 0.05, 0.05))
	for y in range(10, 16):
		img.set_pixel(7, y, Color(0.75, 0.1, 0.1))
		img.set_pixel(8, y, Color(0.5, 0.05, 0.05))


func _draw_potion(img: Image, color: Color, name: String):
	img.fill(Color(0,0,0,0))
	for x in range(6, 10):
		for y in range(2, 5):
			img.set_pixel(x, y, Color(0.6, 0.5, 0.4))
	for x in range(5, 11):
		for y in range(5, 8):
			img.set_pixel(x, y, Color(0.8, 0.85, 0.9, 0.5))
	for x in range(4, 12):
		for y in range(8, 14):
			img.set_pixel(x, y, color)
	for x in range(5, 11):
		for y in range(9, 13):
			img.set_pixel(x, y, color.lightened(0.25))
	img.set_pixel(6, 6, Color(1, 1, 1, 0.6))
	img.set_pixel(9, 10, Color(1, 1, 1, 0.4))
	
func _draw_enchantment(img: Image, color: Color, name: String):
	img.fill(Color(0,0,0,0))
	for x in range(3, 13):
		for y in range(3, 13):
			img.set_pixel(x, y, Color(0.35, 0.15, 0.5))
	for x in range(4, 12):
		for y in range(4, 12):
			img.set_pixel(x, y, Color(0.55, 0.3, 0.75))
	if "sharpness" in name:
		for y in range(5, 11):
			img.set_pixel(7 + (y % 2), y, Color(0.9, 0.2, 0.2))
	elif "protection" in name:
		for x in range(6, 10):
			for y in range(5, 11):
				img.set_pixel(x, y, Color(0.3, 0.55, 0.95))
	elif "efficiency" in name:
		for i in range(6):
			img.set_pixel(6 + i, 5 + (i % 3), Color(0.3, 0.9, 0.4))
	elif "unbreaking" in name:
		for y in range(4, 12):
			img.set_pixel(7, y, Color(0.75, 0.4, 0.9))
			img.set_pixel(8, y, Color(0.75, 0.4, 0.9))
	elif "power" in name:
		for y in range(4, 12):
			img.set_pixel(6 + ((y+1) % 3), y, Color(0.2, 0.9, 0.9))
	for i in range(6):
		img.set_pixel(4 + randi() % 8, 4 + randi() % 8, Color(1, 1, 1, 0.4))


# ==================== ZEICHENFUNKTIONEN ====================

func _draw_block(img: Image, color: Color, name: String):
	img.fill(color)

	if "brick" in name:
		for y in range(16):
			var offset = 4 if (y / 4) % 2 == 0 else 0
			for x in range(16):
				if (x + offset) % 8 == 0 or y % 4 == 0:
					img.set_pixel(x, y, color.darkened(0.35))
		for x in range(16):
			for y2 in range(16):
				if x < 1 or x > 14 or y2 < 1 or y2 > 14:
					img.set_pixel(x, y2, color.darkened(0.3))
		return

	elif "flower" in name or "rose" in name or "tulip" in name:
		img.fill(Color(0,0,0,0))
		for y in range(9, 15):
			img.set_pixel(7, y, Color(0.2, 0.5, 0.15))
		var petal = color
		if "yellow" in name:
			petal = Color(0.95, 0.85, 0.2)
		elif "orange" in name:
			petal = Color(0.95, 0.55, 0.15)
		elif "red" in name:
			petal = Color(0.85, 0.15, 0.15)
		for x in range(5, 10):
			for y in range(4, 9):
				var dx = x - 7.0
				var dy = y - 6.5
				if dx*dx + dy*dy < 6:
					img.set_pixel(x, y, petal)
		img.set_pixel(7, 6, Color(0.9, 0.8, 0.2))
		return

	elif "fence_gate" in name:
		img.fill(Color(0,0,0,0))
		for y in range(5, 12):
			img.set_pixel(3, y, color)
			img.set_pixel(12, y, color)
		for x in range(4, 12):
			img.set_pixel(x, 6, color)
			img.set_pixel(x, 10, color)
		return

	elif "fence" in name:
		img.fill(Color(0,0,0,0))
		for y in range(2, 14):
			img.set_pixel(4, y, color)
			img.set_pixel(11, y, color)
		for x in range(3, 13):
			img.set_pixel(x, 5, color.darkened(0.15))
			img.set_pixel(x, 9, color.darkened(0.15))
		return

	elif "trapdoor" in name:
		img.fill(Color(0,0,0,0))
		for x in range(1, 15):
			for y in range(11, 15):
				img.set_pixel(x, y, color)
		for x in range(2, 14, 3):
			for y in range(11, 15):
				img.set_pixel(x, y, color.darkened(0.25))
		for x in range(1, 15):
			img.set_pixel(x, 11, color.lightened(0.2))
		img.set_pixel(1, 10, Color(0.7, 0.65, 0.55))
		img.set_pixel(14, 10, Color(0.7, 0.65, 0.55))
		return
	elif "door" in name:
		img.fill(Color(0,0,0,0))
		for x in range(2, 14):
			for y in range(0, 16):
				img.set_pixel(x, y, color.darkened(0.1))
		for x in range(4, 12):
			for y in range(2, 7):
				img.set_pixel(x, y, color)
		for x in range(5, 11):
			for y in range(3, 6):
				img.set_pixel(x, y, color.lightened(0.15))
		for x in range(4, 12):
			for y in range(9, 14):
				img.set_pixel(x, y, color)
		for x in range(5, 11):
			for y in range(10, 13):
				img.set_pixel(x, y, color.lightened(0.15))
		for x in range(2, 14):
			img.set_pixel(x, 7, color.darkened(0.3))
			img.set_pixel(x, 8, color.darkened(0.3))
		img.set_pixel(3, 8, Color(0.9, 0.8, 0.3))
		img.set_pixel(3, 9, Color(0.9, 0.8, 0.3))
		for x in range(16):
			for y in range(16):
				if x < 1 or x > 14:
					img.set_pixel(x, y, color.darkened(0.4))
		return

	elif "tnt" in name:
		for x in range(16):
			for y in range(16):
				if y < 4 or y > 11:
					img.set_pixel(x, y, Color(0.8, 0.7, 0.5))
		for x in range(16):
			img.set_pixel(x, 5, Color(0.95, 0.95, 0.9))
			img.set_pixel(x, 9, Color(0.95, 0.95, 0.9))
		for x in range(3, 13):
			img.set_pixel(x, 7, Color(0.9, 0.85, 0.8))
		return

	elif "dispenser" in name:
		img.fill(Color(0.5, 0.5, 0.5))
		for x in range(5, 11):
			for y in range(5, 11):
				img.set_pixel(x, y, Color(0.15, 0.15, 0.15))
		for x in range(6, 10):
			for y in range(6, 10):
				img.set_pixel(x, y, Color(0.05, 0.05, 0.05))
		for x in range(16):
			for y in range(16):
				if x < 1 or x > 14 or y < 1 or y > 14:
					img.set_pixel(x, y, color.darkened(0.3))
		return

	elif "quartz_stairs" in name or "brick_stairs" in name:
		img.fill(Color(0,0,0,0))
		var step_h = 5
		var step_w = 5
		for step in range(3):
			var x0 = step * step_w
			var y0 = 16 - (step + 1) * step_h
			for x in range(x0, 16):
				for y in range(max(y0, 0), 16):
					img.set_pixel(x, y, color)
			for x in range(x0, 16):
				img.set_pixel(x, max(y0, 0), color.lightened(0.2))
			for y in range(max(y0, 0), 16):
				img.set_pixel(min(x0, 15), y, color.darkened(0.25))
		if "brick" in name:
			for y in range(16):
				var offset = 4 if (y / 4) % 2 == 0 else 0
				for x in range(16):
					if (x + offset) % 8 == 0 or y % 4 == 0:
						if img.get_pixel(x, y).a > 0:
							img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.2))
		return
		# Textur je nach Material
		if "brick" in name:
			for y in range(16):
				var offset = 4 if (y / 4) % 2 == 0 else 0
				for x in range(16):
					if (x + offset) % 8 == 0 or y % 4 == 0:
						if img.get_pixel(x, y).a > 0:
							img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.2))
		return

	elif "quartz_block" in name:
		img.fill(color)
		for y in range(16):
			if y % 5 == 0:
				for x in range(16):
					img.set_pixel(x, y, color.darkened(0.1))
		for x in range(16):
			for y in range(16):
				if x < 1 or x > 14 or y < 1 or y > 14:
					img.set_pixel(x, y, color.darkened(0.3))
		return

	elif "anvil" in name:
		img.fill(Color(0,0,0,0))
		for x in range(3, 13):
			for y in range(3, 6):
				img.set_pixel(x, y, color)
		for x in range(6, 10):
			for y in range(6, 11):
				img.set_pixel(x, y, color)
		for x in range(4, 12):
			for y in range(11, 14):
				img.set_pixel(x, y, color)
		return

	elif "command_block" in name:
		for x in range(16):
			for y in range(16):
				if (x + y) % 4 == 0:
					img.set_pixel(x, y, Color(0.6, 0.3, 0.7))
		return

	elif "jukebox" in name:
		for x in range(3, 13):
			for y in range(3, 13):
				img.set_pixel(x, y, color)
		for x in range(5, 11):
			for y in range(5, 11):
				img.set_pixel(x, y, Color(0.2, 0.2, 0.2))
		return

	if "stone" in name or "cobblestone" in name or "ore" in name:
		for i in range(35):
			var x = randi() % 16
			var y = randi() % 16
			img.set_pixel(x, y, color.darkened(0.3))

	elif "log" in name or "planks" in name:
		for y in range(16):
			if y % 3 == 0:
				for x in range(16):
					img.set_pixel(x, y, color.darkened(0.25))

	elif "grass_block" in name:
		for x in range(16):
			for y in range(6):
				img.set_pixel(x, y, Color(0.25, 0.55, 0.2))

	elif "leaves" in name:
		for i in range(20):
			var x = randi() % 16
			var y = randi() % 16
			img.set_pixel(x, y, color.darkened(0.2))

	for x in range(16):
		for y in range(16):
			if x < 2 or x > 13 or y < 2 or y > 13:
				img.set_pixel(x, y, color.darkened(0.4))
	img.fill(color)
	if "command_block" in name:
		# Command Block (lila mit Pfeil-Muster)
		for x in range(16):
			for y in range(16):
				if (x + y) % 4 == 0:
					img.set_pixel(x, y, Color(0.6, 0.3, 0.7))
	
	elif "jukebox" in name:
		# Jukebox mit Schallplatten-Andeutung
		for x in range(3, 13):
			for y in range(3, 13):
				img.set_pixel(x, y, color)
		# Schallplatten-Loch
		for x in range(5, 11):
			for y in range(5, 11):
				img.set_pixel(x, y, Color(0.2, 0.2, 0.2))
	
	# Muster je nach Typ
	if "stone" in name or "cobblestone" in name or "ore" in name:
		for i in range(35):
			var x = randi() % 16
			var y = randi() % 16
			img.set_pixel(x, y, color.darkened(0.3))
	
	elif "log" in name or "planks" in name:
		for y in range(16):
			if y % 3 == 0:
				for x in range(16):
					img.set_pixel(x, y, color.darkened(0.25))
	
	elif "grass_block" in name:
		for x in range(16):
			for y in range(6):
				img.set_pixel(x, y, Color(0.25, 0.55, 0.2))
	
	elif "leaves" in name:
		for i in range(20):
			var x = randi() % 16
			var y = randi() % 16
			img.set_pixel(x, y, color.darkened(0.2))
	
	# Rand
	for x in range(16):
		for y in range(16):
			if x < 2 or x > 13 or y < 2 or y > 13:
				img.set_pixel(x, y, color.darkened(0.4))


func _draw_disc(img: Image, color: Color, name: String = ""):
	for x in range(16):
		for y in range(16):
			var dx = x - 7.5
			var dy = y - 7.5
			if dx*dx + dy*dy <= 49:
				img.set_pixel(x, y, Color(0.08, 0.08, 0.08))

	var label_color = color
	var n = name.to_lower()

	if "chris" in n:
		label_color = Color(0.6, 0.45, 0.3)
	elif "danny" in n:
		label_color = Color(0.35, 0.55, 0.75)
	elif "dryhands" in n:
		label_color = Color(0.7, 0.6, 0.4)
	elif "equinoxe" in n:
		label_color = Color(0.85, 0.55, 0.15)
	elif "excuse" in n:
		label_color = Color(0.55, 0.3, 0.65)
	elif "felt_weather" in n:
		label_color = Color(0.5, 0.7, 0.85)
	elif "haggstorm" in n:
		label_color = Color(0.3, 0.3, 0.45)
	elif "living mice" in n:
		label_color = Color(0.75, 0.5, 0.55)
	elif "mice on venus1" in n:
		label_color = Color(0.4, 0.65, 0.55)
	elif "mice on venus2" in n:
		label_color = Color(0.3, 0.55, 0.5)
	elif "nights" in n:
		label_color = Color(0.2, 0.2, 0.4)
	elif "oxygene" in n:
		label_color = Color(0.15, 0.6, 0.7)
	elif "subwoofer_lullaby" in n:
		label_color = Color(0.45, 0.35, 0.6)
	elif "sweeden" in n or "sweeten2" in n:
		label_color = Color(0.85, 0.85, 0.9)
	elif "wethands" in n:
		label_color = Color(0.4, 0.55, 0.75)
	elif "clark" in n:
		label_color = Color(0.55, 0.2, 0.2)
	elif "highcraft" in n:
		label_color = Color(0.9, 0.7, 0.15)
	elif "refuse" in n:
		label_color = Color(0.4, 0.4, 0.4)
	elif "regrets" in n:
		label_color = Color(0.3, 0.15, 0.25)
	elif "softly" in n:
		label_color = Color(0.75, 0.65, 0.8)
	elif "quiet between stars" in n:
		label_color = Color(0.15, 0.1, 0.3)
	elif "beginning" in n:
		label_color = Color(0.9, 0.75, 0.4)
	elif "mog city" in n:
		label_color = Color(0.55, 0.75, 0.35)
	elif "left behind" in n:
		label_color = Color(0.6, 0.1, 0.1)
	elif n == "x120" or n == "x120.mp3" or n == "x120_disc":
		label_color = Color(0.7, 0.7, 0.75)

	for x in range(5, 11):
		for y in range(5, 11):
			var dx = x - 7.5
			var dy = y - 7.5
			if dx*dx + dy*dy <= 9:
				img.set_pixel(x, y, label_color)

	img.set_pixel(7, 7, Color(0.05, 0.05, 0.05))
	img.set_pixel(8, 7, Color(0.05, 0.05, 0.05))
	img.set_pixel(7, 8, Color(0.05, 0.05, 0.05))
	img.set_pixel(8, 8, Color(0.05, 0.05, 0.05))

	for a in range(0, 360, 30):
		var rad = deg_to_rad(a)
		var rx = int(7.5 + cos(rad) * 6.5)
		var ry = int(7.5 + sin(rad) * 6.5)
		if rx >= 0 and rx < 16 and ry >= 0 and ry < 16:
			img.set_pixel(rx, ry, Color(0.2, 0.2, 0.2))

	for x in range(16):
		for y in range(16):
			var dx = x - 7.5
			var dy = y - 7.5
			if dx*dx + dy*dy > 49 and dx*dx + dy*dy < 58:
				img.set_pixel(x, y, Color(0.4, 0.4, 0.4))


func _draw_tool(img: Image, color: Color, name: String):
	# Griff
	for y in range(10, 16):
		for x in range(7, 9):
			img.set_pixel(x, y, Color(0.4, 0.3, 0.2))
	
	# Kopf je nach Werkzeug
	if "pickaxe" in name or "axe" in name:
		for x in range(3, 13):
			for y in range(3, 8):
				img.set_pixel(x, y, color)
	elif "sword" in name:
		for x in range(6, 10):
			for y in range(2, 10):
				img.set_pixel(x, y, color)
	else:  # Shovel
		for x in range(5, 11):
			for y in range(3, 9):
				img.set_pixel(x, y, color)


func _draw_mob(img: Image, color: Color, name: String):
	img.fill(Color(0,0,0,0))

	if "creeper" in name:
		_draw_creeper(img, color)
	elif "cave_spider" in name:
		_draw_cave_spider(img, color)
	elif "spider" in name:
		_draw_spider(img, color)
	elif "wither_skeleton" in name:
		_draw_wither_skeleton(img, color)
	elif "stray" in name:
		_draw_stray(img, color)
	elif "skeleton" in name:
		_draw_skeleton(img, color)
	elif "husk" in name:
		_draw_husk(img, color)
	elif "zombie_villager" in name:
		_draw_zombie_villager(img, color)
	elif "zombie_pigman" in name:
		_draw_zombie_pigman(img, color)
	elif "zombie" in name:
		_draw_zombie(img, color)
	elif "blaze" in name:
		_draw_blaze(img, color)
	elif "shulker" in name:
		_draw_shulker(img, color)
	elif "erebus_sovereign" in name or "ender_dragon" in name:
		_draw_ender_dragon(img, color)
	elif "wither" in name:
		_draw_wither(img, color)
	elif "iron_golem" in name:
		_draw_iron_golem(img, color)
	elif "snow_golem" in name:
		_draw_snow_golem(img, color)
	elif "zombie_villager" in name:
		pass
	elif "villager" in name:
		_draw_villager(img, color)
	elif "erebite" in name:
		_draw_enderman(img, color)
	elif "endermite" in name:
		_draw_endermite(img, color)
	elif "soulwraith" in name:
		_draw_ghast(img, color)
	elif "witch" in name:
		_draw_witch(img, color)
	elif "slime" in name:
		_draw_slime(img, color)
	elif "magma_cube" in name:
		_draw_magma_cube(img, color)
	elif "silverfish" in name:
		_draw_silverfish(img, color)
	elif "wolf" in name:
		_draw_wolf(img, color)
	elif "sheep" in name:
		_draw_sheep(img, color)
	elif "mooshroom" in name:
		_draw_mooshroom(img, color)
	elif "cow" in name:
		_draw_cow(img, color)
	elif "pig" in name:
		_draw_pig(img, color)
	elif "chicken" in name:
		_draw_chicken(img, color)
	elif "rabbit" in name:
		_draw_rabbit(img, color)
	elif "horse" in name:
		_draw_horse(img, color)
	elif "ocelot" in name:
		_draw_ocelot(img, color)
	elif "squid" in name:
		_draw_squid(img, color)
	elif "bat" in name:
		_draw_bat(img, color)
	elif "hero_no_brain" in name:
		_draw_hero_no_brain(img, color)
	elif "charlie_emily" in name:
		_draw_charlie_emily(img, color)
	else:
		_draw_biped(img, color)


func _draw_cave_spider(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = color.darkened(0.15)
	for x in range(5, 11):
		for y in range(7, 10):
			img.set_pixel(x, y, c)
	img.set_pixel(6, 8, Color(0.1, 0.6, 0.6))
	img.set_pixel(9, 8, Color(0.1, 0.6, 0.6))
	for i in range(3):
		img.set_pixel(4 - i, 6 + i, c)
		img.set_pixel(11 + i, 6 + i, c)
		img.set_pixel(4 - i, 9 - i, c)
		img.set_pixel(11 + i, 9 - i, c)


func _draw_wither_skeleton(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.15, 0.15, 0.15)
	for x in range(6, 10):
		for y in range(2, 6):
			img.set_pixel(x, y, c)
	img.set_pixel(6, 4, Color(0.9,0.1,0.1))
	img.set_pixel(9, 4, Color(0.9,0.1,0.1))
	for x in range(6, 10):
		for y in range(6, 14):
			img.set_pixel(x, y, c.lightened(0.1))
	for y in range(6, 13):
		img.set_pixel(5, y, c)
		img.set_pixel(10, y, c)
	for y in range(14, 15):
		img.set_pixel(6, y, c)
		img.set_pixel(9, y, c)


func _draw_stray(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.7, 0.85, 0.88)
	for x in range(6, 10):
		for y in range(3, 7):
			img.set_pixel(x, y, c)
	img.set_pixel(6, 5, Color(0,0,0))
	img.set_pixel(9, 5, Color(0,0,0))
	for x in range(6, 10):
		for y in range(7, 13):
			img.set_pixel(x, y, c.darkened(0.1))
	for y in range(7, 12):
		img.set_pixel(5, y, c.darkened(0.2))
		img.set_pixel(10, y, c.darkened(0.2))
	for y in range(13, 15):
		img.set_pixel(6, y, c.darkened(0.2))
		img.set_pixel(9, y, c.darkened(0.2))
	for i in range(6):
		img.set_pixel(4 + randi() % 8, 3 + randi() % 12, Color(0.85,0.9,0.95,0.5))


func _draw_husk(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.7, 0.6, 0.35)
	for x in range(5, 11):
		for y in range(3, 7):
			img.set_pixel(x, y, c)
	img.set_pixel(6, 5, Color(0.1,0.1,0.1))
	img.set_pixel(9, 5, Color(0.1,0.1,0.1))
	for x in range(4, 12):
		for y in range(7, 13):
			img.set_pixel(x, y, c.darkened(0.1))
	for y in range(7, 12):
		img.set_pixel(3, y, c.darkened(0.15))
		img.set_pixel(12, y, c.darkened(0.15))
	for y in range(13, 15):
		img.set_pixel(6, y, c.darkened(0.2))
		img.set_pixel(9, y, c.darkened(0.2))


func _draw_zombie_villager(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.4, 0.55, 0.35)
	for x in range(5, 11):
		for y in range(3, 8):
			img.set_pixel(x, y, c)
	for x in range(6, 9):
		for y in range(6, 9):
			img.set_pixel(x, y, c.darkened(0.2))
	for x in range(4, 12):
		for y in range(9, 15):
			img.set_pixel(x, y, c)
	img.set_pixel(6, 5, Color(0.1,0.1,0.1))
	img.set_pixel(9, 5, Color(0.1,0.1,0.1))


func _draw_zombie_pigman(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.75, 0.55, 0.5)
	for x in range(5, 11):
		for y in range(3, 7):
			img.set_pixel(x, y, c)
	img.set_pixel(7, 6, Color(0.9,0.6,0.6))
	img.set_pixel(8, 6, Color(0.9,0.6,0.6))
	img.set_pixel(6, 5, Color(0.1,0.1,0.1))
	img.set_pixel(9, 5, Color(0.1,0.1,0.1))
	for x in range(4, 12):
		for y in range(7, 13):
			img.set_pixel(x, y, Color(0.5, 0.35, 0.55))
	for y in range(13, 15):
		img.set_pixel(6, y, c.darkened(0.2))
		img.set_pixel(9, y, c.darkened(0.2))


func _draw_witch(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.35, 0.2, 0.4)
	for x in range(3, 13):
		for y in range(2, 5):
			img.set_pixel(x, y, c.darkened(0.2))
	for x in range(5, 11):
		for y in range(4, 8):
			img.set_pixel(x, y, Color(0.55, 0.65, 0.45))
	img.set_pixel(6, 6, Color(0,0,0))
	img.set_pixel(9, 6, Color(0,0,0))
	for x in range(4, 12):
		for y in range(8, 14):
			img.set_pixel(x, y, c)


func _draw_slime(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(16):
		for y in range(16):
			var dx = x - 7.5
			var dy = y - 9
			if (dx*dx)/36.0 + (dy*dy)/25.0 < 1.0:
				img.set_pixel(x, y, color)
	img.set_pixel(6, 8, Color(0,0,0))
	img.set_pixel(9, 8, Color(0,0,0))
	for x in range(3, 13):
		for y in range(11, 14):
			img.set_pixel(x, y, color.darkened(0.2))
			
			
func _draw_material(img: Image, color: Color, name: String):
	if "ingot" in name:
		for x in range(4, 12):
			for y in range(6, 10):
				img.set_pixel(x, y, color)
		for x in range(5, 11):
			img.set_pixel(x, 6, color.lightened(0.3))
	elif "nugget" in name:
		for x in range(6, 10):
			for y in range(6, 10):
				img.set_pixel(x, y, color)
		img.set_pixel(6, 6, color.lightened(0.2))
	elif name == "coal" or name == "charcoal":
		for i in range(10):
			var x = 4 + randi() % 8
			var y = 4 + randi() % 8
			img.set_pixel(x, y, color)
			img.set_pixel(x+1, y, color.darkened(0.2))
	elif "diamond" in name:
		var pts = [Vector2i(7,3),Vector2i(4,7),Vector2i(7,13),Vector2i(10,7)]
		for x in range(16):
			for y in range(16):
				var dx = x - 7.0
				var dy = y - 7.5
				if abs(dx) + abs(dy) < 5:
					img.set_pixel(x, y, color)
		img.set_pixel(7, 5, Color(1,1,1,0.7))
	elif "emerald" in name:
		for x in range(16):
			for y in range(16):
				var dx = x - 7.5
				var dy = y - 8
				if abs(dx) + abs(dy) < 5:
					img.set_pixel(x, y, color)
		img.set_pixel(7, 6, Color(1,1,1,0.6))
	elif "redstone" in name:
		for i in range(14):
			var x = 3 + randi() % 10
			var y = 3 + randi() % 10
			img.set_pixel(x, y, color)
	elif "redstone_wire" in name or (name == "redstone" and Registry.blocks.has(name)):
		img.fill(Color(0,0,0,0))
		for x in range(6, 10):
			for y in range(6, 10):
				img.set_pixel(x, y, Color(0.6, 0.05, 0.05))
		for x in range(0, 6):
			img.set_pixel(x, 7, Color(0.75, 0.1, 0.1))
			img.set_pixel(x, 8, Color(0.5, 0.05, 0.05))
		for x in range(10, 16):
			img.set_pixel(x, 7, Color(0.75, 0.1, 0.1))
			img.set_pixel(x, 8, Color(0.5, 0.05, 0.05))
		for y in range(0, 6):
			img.set_pixel(7, y, Color(0.75, 0.1, 0.1))
			img.set_pixel(8, y, Color(0.5, 0.05, 0.05))
		for y in range(10, 16):
			img.set_pixel(7, y, Color(0.75, 0.1, 0.1))
			img.set_pixel(8, y, Color(0.5, 0.05, 0.05))
		return
	elif "daylight_sensor" in name or "daylight_detector" in name:
		img.fill(Color(0,0,0,0))
		for x in range(1, 15):
			for y in range(11, 14):
				img.set_pixel(x, y, Color(0.55, 0.42, 0.3))
		for x in range(2, 14):
			for y in range(6, 11):
				var dx = x - 8.0
				var dy = y - 8.5
				if dx*dx + dy*dy < 20:
					img.set_pixel(x, y, Color(0.6, 0.75, 0.85, 0.7))
		for x in range(3, 13):
			for y in range(7, 10):
				var dx = x - 8.0
				var dy = y - 8.5
				if dx*dx + dy*dy < 10:
					img.set_pixel(x, y, Color(0.85, 0.9, 0.95, 0.9))
		return

	elif "lapis" in name:
		for i in range(12):
			var x = 3 + randi() % 10
			var y = 3 + randi() % 10
			img.set_pixel(x, y, color)
		img.set_pixel(7, 7, Color(0.9,0.85,0.3))
	elif "nether_quartz" in name:
		for x in range(5, 11):
			for y in range(3, 13):
				img.set_pixel(x, y, color)
		for y in range(3, 13):
			img.set_pixel(7, y, color.darkened(0.15))
	elif "stick" in name:
		for y in range(2, 14):
			img.set_pixel(7, y, color)
			img.set_pixel(8, y, color.darkened(0.15))
	elif "string" in name:
		for y in range(2, 14):
			img.set_pixel(7 + (1 if y % 4 < 2 else 0), y, color)
	elif "leather" in name:
		for x in range(3, 13):
			for y in range(4, 12):
				img.set_pixel(x, y, color)
		for i in range(6):
			img.set_pixel(4 + randi() % 8, 5 + randi() % 6, color.darkened(0.2))
	elif "feather" in name:
		for y in range(2, 14):
			var w = int(3 - abs(y - 8) / 3.0)
			for x in range(7 - w, 7 + w):
				img.set_pixel(x, y, color)
	elif "bone_meal" in name:
		for x in range(4, 12):
			for y in range(4, 12):
				img.set_pixel(x, y, Color(0.95, 0.95, 0.9))
		for i in range(12):
			img.set_pixel(randi() % 16, randi() % 16, Color(0.8, 0.8, 0.75))
	elif "bone" in name:
		for y in range(4, 12):
			img.set_pixel(7, y, color)
			img.set_pixel(8, y, color)
		for x in range(5, 7):
			img.set_pixel(x, 3, color)
			img.set_pixel(x, 12, color)
		for x in range(9, 11):
			img.set_pixel(x, 3, color)
			img.set_pixel(x, 12, color)
	elif "gunpowder" in name:
		for i in range(20):
			img.set_pixel(2 + randi() % 12, 2 + randi() % 12, color)
	elif "ender_pearl" in name:
		for x in range(16):
			for y in range(16):
				var dx = x - 7.5
				var dy = y - 7.5
				if dx*dx + dy*dy <= 45:
					img.set_pixel(x, y, color)
		img.set_pixel(6, 6, color.lightened(0.3))
		for i in range(5):
			img.set_pixel(5 + randi() % 6, 5 + randi() % 6, color.darkened(0.3))
	elif "blaze_rod" in name:
		for y in range(2, 14):
			img.set_pixel(7, y, color)
			img.set_pixel(8, y, color)
		img.set_pixel(6, 3, Color(1,0.9,0.3))
		img.set_pixel(9, 10, Color(1,0.9,0.3))
	elif "blaze_powder" in name:
		for i in range(16):
			img.set_pixel(2 + randi() % 12, 2 + randi() % 12, color)
	elif "ghast_tear" in name:
		for x in range(16):
			for y in range(16):
				var dx = x - 7.5
				var dy = y - 8
				if (dx*dx)/16.0 + (dy*dy)/36.0 < 1.0:
					img.set_pixel(x, y, color)
		img.set_pixel(7, 5, Color(1,1,1,0.6))
	elif "magma_cream" in name:
		for x in range(16):
			for y in range(16):
				var dx = x - 7.5
				var dy = y - 7.5
				if dx*dx + dy*dy <= 42:
					img.set_pixel(x, y, color)
		for i in range(5):
			img.set_pixel(5 + randi() % 6, 5 + randi() % 6, Color(1,0.6,0.1))
	elif "slimeball" in name:
		for x in range(16):
			for y in range(16):
				var dx = x - 7.5
				var dy = y - 7.5
				if dx*dx + dy*dy <= 44:
					img.set_pixel(x, y, color)
		img.set_pixel(6, 6, color.lightened(0.2))
	elif "clay_ball" in name:
		for x in range(16):
			for y in range(16):
				var dx = x - 7.5
				var dy = y - 7.5
				if dx*dx + dy*dy <= 40:
					img.set_pixel(x, y, color)
	elif "glowstone_dust" in name:
		for i in range(18):
			img.set_pixel(2 + randi() % 12, 2 + randi() % 12, color)
	elif "snowball" in name:
		for x in range(16):
			for y in range(16):
				var dx = x - 7.5
				var dy = y - 7.5
				if dx*dx + dy*dy <= 44:
					img.set_pixel(x, y, color)
	elif "flint" in name:
		for x in range(5, 11):
			for y in range(4, 12):
				img.set_pixel(x, y, color)
		img.set_pixel(6, 5, color.lightened(0.3))
	elif "wheat" in name:
		for y in range(3, 13):
			img.set_pixel(6, y, color)
			img.set_pixel(9, y, color)
		for x in range(5, 11):
			img.set_pixel(x, 3, color.darkened(0.2))
	elif "sugar" in name:
		for i in range(20):
			img.set_pixel(3 + randi() % 10, 3 + randi() % 10, Color(1,1,1))
	elif "egg" in name:
		for x in range(16):
			for y in range(16):
				var dx = x - 7.5
				var dy = y - 8
				if (dx*dx)/16.0 + (dy*dy)/30.0 < 1.0:
					img.set_pixel(x, y, Color(0.95, 0.9, 0.8))
	elif "rose" in name:
		for x in range(6, 10):
			for y in range(3, 8):
				img.set_pixel(x, y, color)
		for y in range(8, 14):
			img.set_pixel(7, y, Color(0.2,0.5,0.15))
	elif "fire_charge" in name:
		for x in range(16):
			for y in range(16):
				var dx = x - 7.5
				var dy = y - 7.5
				if dx*dx + dy*dy <= 46:
					img.set_pixel(x, y, Color(1.0, 0.5, 0.1))
		img.set_pixel(7, 7, Color(1,0.9,0.3))
	elif "banner" in name:
		for x in range(4, 12):
			for y in range(2, 13):
				img.set_pixel(x, y, color)
		for x in range(4, 12):
			img.set_pixel(x, 13, Color(0,0,0,0) if (x%2==0) else color)
	elif "ink_sac" in name:
		for x in range(16):
			for y in range(16):
				var dx = x - 7.5
				var dy = y - 8
				if (dx*dx)/20.0 + (dy*dy)/30.0 < 1.0:
					img.set_pixel(x, y, Color(0.1,0.1,0.15))
	elif "rabbit_hide" in name:
		for x in range(3, 13):
			for y in range(4, 12):
				img.set_pixel(x, y, color)
		for i in range(5):
			img.set_pixel(4 + randi()%8, 5 + randi()%6, color.darkened(0.15))
	elif "shulker_shell" in name:
		for x in range(4, 12):
			for y in range(4, 13):
				img.set_pixel(x, y, color)
		for x in range(3, 13):
			img.set_pixel(x, 4, color.darkened(0.3))
	elif "dragon_egg" in name:
		_draw_dragon_egg(img, color)
	elif "nether_star" in name:
		for x in range(16):
			for y in range(16):
				var dx = abs(x - 7.5)
				var dy = abs(y - 7.5)
				if dx + dy < 7 and dx * dy < 12:
					img.set_pixel(x, y, Color(0.9, 0.95, 0.85))
		img.set_pixel(7, 7, Color(1,1,1))
	else:
		img.fill(color)



func _draw_paper(img: Image, color: Color):
	for x in range(3, 13):
		for y in range(3, 13):
			img.set_pixel(x, y, Color(0.95, 0.95, 0.9))
	for y in [5, 7, 9, 11]:
		for x in range(4, 12):
			img.set_pixel(x, y, Color(0.7, 0.75, 0.85))


func _draw_book(img: Image, color: Color):
	for x in range(3, 13):
		for y in range(4, 12):
			img.set_pixel(x, y, Color(0.4, 0.25, 0.15))
	for x in range(4, 12):
		for y in range(5, 11):
			img.set_pixel(x, y, Color(0.95, 0.95, 0.85))


func _draw_firework_rocket(img: Image, color: Color):
	for x in range(6, 10):
		for y in range(3, 13):
			img.set_pixel(x, y, color)
	for x in range(5, 11):
		img.set_pixel(x, 2, color.darkened(0.2))


func _draw_firework_star(img: Image, color: Color):
	for x in range(4, 12):
		for y in range(4, 12):
			img.set_pixel(x, y, color)
	for i in range(8):
		img.set_pixel(randi() % 16, randi() % 16, Color(1, 1, 0.6))


func _draw_shears(img: Image, color: Color):
	for y in range(3, 13):
		img.set_pixel(6, y, color)
	for y in range(3, 13):
		img.set_pixel(10, y, color)
	img.set_pixel(8, 3, color.darkened(0.2))


func _draw_water_bucket(img: Image, color: Color):
	for x in range(4, 12):
		for y in range(4, 13):
			img.set_pixel(x, y, Color(0.65, 0.65, 0.68))
	for x in range(5, 11):
		for y in range(5, 11):
			img.set_pixel(x, y, Color(0.3, 0.55, 0.85))


func _draw_lava_bucket(img: Image, color: Color):
	for x in range(4, 12):
		for y in range(4, 13):
			img.set_pixel(x, y, Color(0.65, 0.65, 0.68))
	for x in range(5, 11):
		for y in range(5, 11):
			img.set_pixel(x, y, Color(0.95, 0.4, 0.1))


func _draw_milk_bucket(img: Image, color: Color):
	for x in range(4, 12):
		for y in range(4, 13):
			img.set_pixel(x, y, Color(0.65, 0.65, 0.68))
	for x in range(5, 11):
		for y in range(5, 11):
			img.set_pixel(x, y, Color(0.95, 0.95, 0.9))


func _draw_magma_cube(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(3, 13):
		for y in range(4, 14):
			img.set_pixel(x, y, Color(0.35, 0.12, 0.05))
	for i in range(6):
		var rx = 4 + randi() % 8
		var ry = 5 + randi() % 8
		img.set_pixel(rx, ry, Color(1.0, 0.55, 0.1))
	img.set_pixel(6, 7, Color(1,0.9,0.2))
	img.set_pixel(9, 7, Color(1,0.9,0.2))


func _draw_silverfish(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.65, 0.65, 0.6)
	for x in range(3, 13):
		for y in range(7, 10):
			img.set_pixel(x, y, c)
	img.set_pixel(11, 8, Color(0,0,0))
	for i in range(3):
		img.set_pixel(4 + i * 3, 6, c.darkened(0.3))
		img.set_pixel(4 + i * 3, 10, c.darkened(0.3))


func _draw_endermite(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.3, 0.15, 0.4)
	for x in range(4, 12):
		for y in range(7, 10):
			img.set_pixel(x, y, c)
	img.set_pixel(10, 8, Color(0.8,0.1,0.9))
	for i in range(3):
		img.set_pixel(3 + i * 3, 6, c.lightened(0.1))
		img.set_pixel(3 + i * 3, 10, c.lightened(0.1))


func _draw_wolf(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.6, 0.58, 0.55)
	for x in range(3, 12):
		for y in range(7, 11):
			img.set_pixel(x, y, c)
	for x in range(10, 15):
		for y in range(5, 9):
			img.set_pixel(x, y, c.darkened(0.1))
	img.set_pixel(13, 6, Color(0.9,0.6,0.1))
	img.set_pixel(12, 5, c.darkened(0.3))
	for y in range(11, 14):
		img.set_pixel(4, y, c.darkened(0.2))
		img.set_pixel(6, y, c.darkened(0.2))
		img.set_pixel(9, y, c.darkened(0.2))
		img.set_pixel(11, y, c.darkened(0.2))


func _draw_sheep(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(2, 13):
		for y in range(5, 11):
			img.set_pixel(x, y, Color(0.92, 0.92, 0.9))
	for x in range(11, 15):
		for y in range(6, 10):
			img.set_pixel(x, y, Color(0.35, 0.25, 0.2))
	for y in range(11, 15):
		img.set_pixel(3, y, Color(0.35,0.25,0.2))
		img.set_pixel(6, y, Color(0.35,0.25,0.2))
		img.set_pixel(9, y, Color(0.35,0.25,0.2))
		img.set_pixel(12, y, Color(0.35,0.25,0.2))


func _draw_mooshroom(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.55, 0.15, 0.15)
	for x in range(2, 13):
		for y in range(5, 11):
			img.set_pixel(x, y, c)
	img.set_pixel(4, 6, Color(0.9,0.9,0.85))
	img.set_pixel(7, 8, Color(0.9,0.9,0.85))
	img.set_pixel(10, 6, Color(0.9,0.9,0.85))
	for x in range(11, 15):
		for y in range(6, 10):
			img.set_pixel(x, y, c.darkened(0.2))
	for y in range(11, 15):
		img.set_pixel(3, y, Color(0.3,0.2,0.15))
		img.set_pixel(6, y, Color(0.3,0.2,0.15))
		img.set_pixel(9, y, Color(0.3,0.2,0.15))
		img.set_pixel(12, y, Color(0.3,0.2,0.15))


func _draw_cow(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.4, 0.25, 0.18)
	for x in range(2, 13):
		for y in range(6, 11):
			img.set_pixel(x, y, c)
	for x in range(6, 10):
		img.set_pixel(x, 7, Color(0.9,0.9,0.85))
	for x in range(11, 15):
		for y in range(5, 9):
			img.set_pixel(x, y, c.darkened(0.1))
	img.set_pixel(13, 6, Color(0,0,0))
	img.set_pixel(12, 4, Color(0.85,0.85,0.8))
	img.set_pixel(13, 4, Color(0.85,0.85,0.8))
	for y in range(11, 15):
		img.set_pixel(3, y, c.darkened(0.2))
		img.set_pixel(6, y, c.darkened(0.2))
		img.set_pixel(9, y, c.darkened(0.2))
		img.set_pixel(12, y, c.darkened(0.2))


func _draw_pig(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.92, 0.6, 0.65)
	for x in range(3, 12):
		for y in range(7, 11):
			img.set_pixel(x, y, c)
	for x in range(10, 15):
		for y in range(6, 10):
			img.set_pixel(x, y, c.darkened(0.05))
	img.set_pixel(14, 8, Color(0.7,0.4,0.45))
	img.set_pixel(13, 7, Color(0.1,0.1,0.1))
	for y in range(11, 14):
		img.set_pixel(4, y, c.darkened(0.15))
		img.set_pixel(6, y, c.darkened(0.15))
		img.set_pixel(9, y, c.darkened(0.15))
		img.set_pixel(11, y, c.darkened(0.15))


func _draw_chicken(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.95, 0.93, 0.85)
	for x in range(5, 11):
		for y in range(6, 12):
			img.set_pixel(x, y, c)
	img.set_pixel(11, 7, Color(0.95, 0.6, 0.1))
	img.set_pixel(4, 6, Color(0.9,0.1,0.1))
	img.set_pixel(7, 5, Color(0.1,0.1,0.1))
	for y in range(12, 15):
		img.set_pixel(6, y, Color(0.9,0.6,0.1))
		img.set_pixel(9, y, Color(0.9,0.6,0.1))


func _draw_rabbit(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.75, 0.6, 0.45)
	for x in range(5, 11):
		for y in range(8, 13):
			img.set_pixel(x, y, c)
	for x in range(6, 10):
		for y in range(5, 8):
			img.set_pixel(x, y, c.lightened(0.1))
	img.set_pixel(6, 3, c)
	img.set_pixel(6, 4, c)
	img.set_pixel(9, 3, c)
	img.set_pixel(9, 4, c)
	img.set_pixel(7, 6, Color(0,0,0))
	for y in range(13, 15):
		img.set_pixel(6, y, c.darkened(0.2))
		img.set_pixel(9, y, c.darkened(0.2))


func _draw_horse(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.5, 0.32, 0.18)
	for x in range(2, 13):
		for y in range(6, 11):
			img.set_pixel(x, y, c)
	for x in range(10, 15):
		for y in range(2, 9):
			img.set_pixel(x, y, c.darkened(0.1))
	img.set_pixel(13, 4, Color(0,0,0))
	for y in range(2, 6):
		img.set_pixel(11, y, c.darkened(0.3))
	for y in range(11, 15):
		img.set_pixel(3, y, c.darkened(0.25))
		img.set_pixel(6, y, c.darkened(0.25))
		img.set_pixel(9, y, c.darkened(0.25))
		img.set_pixel(12, y, c.darkened(0.25))


func _draw_ocelot(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.9, 0.75, 0.4)
	for x in range(3, 12):
		for y in range(7, 11):
			img.set_pixel(x, y, c)
	for x in range(10, 14):
		for y in range(5, 9):
			img.set_pixel(x, y, c)
	img.set_pixel(12, 6, Color(0.1,0.6,0.6))
	for i in range(6):
		img.set_pixel(4 + randi()%7, 7 + randi()%4, c.darkened(0.4))
	for y in range(11, 14):
		img.set_pixel(4, y, c.darkened(0.2))
		img.set_pixel(6, y, c.darkened(0.2))
		img.set_pixel(9, y, c.darkened(0.2))
		img.set_pixel(11, y, c.darkened(0.2))


func _draw_squid(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.3, 0.4, 0.6)
	for x in range(16):
		for y in range(9):
			var dx = x - 7.5
			var dy = y - 4
			if (dx*dx)/25.0 + (dy*dy)/16.0 < 1.0:
				img.set_pixel(x, y, c)
	for tx in [3, 6, 9, 12]:
		for y in range(9, 15):
			img.set_pixel(tx, y, c.darkened(0.2))
	img.set_pixel(5, 4, Color(0.1,0.1,0.15))
	img.set_pixel(10, 4, Color(0.1,0.1,0.15))


func _draw_bat(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.25, 0.22, 0.28)
	for x in range(6, 10):
		for y in range(6, 10):
			img.set_pixel(x, y, c)
	for x in range(1, 6):
		img.set_pixel(x, 7, c.darkened(0.1))
		img.set_pixel(x, 8, c.darkened(0.1))
	for x in range(10, 15):
		img.set_pixel(x, 7, c.darkened(0.1))
		img.set_pixel(x, 8, c.darkened(0.1))
	img.set_pixel(7, 7, Color(0.9,0.1,0.1))
	img.set_pixel(8, 7, Color(0.9,0.1,0.1))


func _draw_hero_no_brain(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(4, 12):
		for y in range(3, 14):
			img.set_pixel(x, y, Color(0.9, 0.3, 0.3))
	img.set_pixel(6, 5, Color(1,1,0))
	img.set_pixel(9, 5, Color(1,1,0))
	for x in range(5, 11):
		img.set_pixel(x, 8, Color(1,1,1))


func _draw_charlie_emily(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(3, 13):
		for y in range(2, 14):
			img.set_pixel(x, y, Color(0.3, 0.6, 0.9))
	img.set_pixel(6, 5, Color(1,1,1))
	img.set_pixel(9, 5, Color(1,1,1))
	for i in range(8):
		img.set_pixel(4 + randi()%8, 7 + randi()%6, Color(1,1,1,0.6))


# ==================== SPEZIAL MOB FUNKTIONEN ====================

func _draw_biped(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(6, 10):
		for y in range(2, 6):
			img.set_pixel(x, y, color)
	img.set_pixel(7, 4, Color(0,0,0))
	img.set_pixel(8, 4, Color(0,0,0))
	for x in range(5, 11):
		for y in range(6, 12):
			img.set_pixel(x, y, color.darkened(0.1))
	for y in range(6, 11):
		img.set_pixel(4, y, color)
		img.set_pixel(11, y, color)
	for y in range(12, 15):
		img.set_pixel(6, y, color.darkened(0.3))
		img.set_pixel(9, y, color.darkened(0.3))

func _draw_quadruped(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(2, 13):
		for y in range(7, 11):
			img.set_pixel(x, y, color)
	for x in range(11, 15):
		for y in range(5, 9):
			img.set_pixel(x, y, color.darkened(0.15))
	img.set_pixel(13, 6, Color(0,0,0))
	for y in range(11, 15):
		img.set_pixel(3, y, color.darkened(0.3))
		img.set_pixel(6, y, color.darkened(0.3))
		img.set_pixel(9, y, color.darkened(0.3))
		img.set_pixel(12, y, color.darkened(0.3))

func _draw_shulker(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(3, 13):
		for y in range(9, 15):
			img.set_pixel(x, y, color)
	for x in range(2, 14):
		for y in range(6, 9):
			img.set_pixel(x, y, color.lightened(0.2))
	img.set_pixel(7, 7, Color(0.9,0.2,0.2))
	img.set_pixel(8, 7, Color(0.9,0.2,0.2))

func _draw_ender_dragon(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(1, 15):
		for y in range(7, 11):
			img.set_pixel(x, y, color)
	for x in range(11, 16):
		for y in range(4, 9):
			img.set_pixel(x, y, color.darkened(0.2))
	img.set_pixel(14, 5, Color(0.9,0.15,0.15))
	for x in range(0, 3):
		img.set_pixel(x, 12, color.darkened(0.3))
	for y in range(2, 7):
		img.set_pixel(5, y, color.darkened(0.4))
		img.set_pixel(9, y, color.darkened(0.4))

func _draw_wither(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(4, 12):
		for y in range(8, 15):
			img.set_pixel(x, y, color)
	for hx in [3, 8, 13]:
		for x in range(hx - 1, hx + 2):
			for y in range(3, 8):
				img.set_pixel(clamp(x,0,15), y, color.darkened(0.25))
		img.set_pixel(hx, 6, Color(0.9,0.9,0.85))

func _draw_iron_golem(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.68, 0.68, 0.72)
	for x in range(4, 12):
		for y in range(6, 14):
			img.set_pixel(x, y, c)
	for x in range(5, 11):
		for y in range(2, 6):
			img.set_pixel(x, y, c.lightened(0.1))
	img.set_pixel(6, 4, Color(0.15,0.15,0.15))
	img.set_pixel(9, 4, Color(0.15,0.15,0.15))
	for y in range(6, 12):
		img.set_pixel(2, y, c.darkened(0.15))
		img.set_pixel(13, y, c.darkened(0.15))
	for x in range(4,8):
		img.set_pixel(x, 9, Color(0.6,0.4,0.25))

func _draw_snow_golem(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.95,0.95,0.98)
	for x in range(5, 11):
		for y in range(8, 15):
			img.set_pixel(x, y, c)
	for x in range(5, 11):
		for y in range(3, 8):
			img.set_pixel(x, y, c.darkened(0.05))
	img.set_pixel(6, 5, Color(0,0,0))
	img.set_pixel(9, 5, Color(0,0,0))
	for x in range(6,9):
		img.set_pixel(x, 6, Color(0.9,0.5,0.1))
	for x in range(3, 6):
		img.set_pixel(x, 3, Color(0.8,0.1,0.1))

func _draw_creeper(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(4, 12):
		for y in range(2, 13):
			img.set_pixel(x, y, color)
	for y in range(13, 15):
		img.set_pixel(5, y, color)
		img.set_pixel(6, y, color)
		img.set_pixel(9, y, color)
		img.set_pixel(10, y, color)
	img.set_pixel(6, 5, Color(0,0,0))
	img.set_pixel(7, 5, Color(0,0,0))
	img.set_pixel(9, 5, Color(0,0,0))
	img.set_pixel(8, 5, Color(0,0,0))
	img.set_pixel(6, 6, Color(0,0,0))
	img.set_pixel(9, 6, Color(0,0,0))
	img.set_pixel(7, 8, Color(0,0,0))
	img.set_pixel(8, 8, Color(0,0,0))
	img.set_pixel(6, 9, Color(0,0,0))
	img.set_pixel(9, 9, Color(0,0,0))

func _draw_spider(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(4, 12):
		for y in range(6, 11):
			img.set_pixel(x, y, color)
	img.set_pixel(5, 7, Color(0.9,0.1,0.1))
	img.set_pixel(10, 7, Color(0.9,0.1,0.1))
	for i in range(4):
		img.set_pixel(3 - i, 5 + i, color)
		img.set_pixel(12 + i, 5 + i, color)
		img.set_pixel(3 - i, 10 - i, color)
		img.set_pixel(12 + i, 10 - i, color)

func _draw_skeleton(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	var c = Color(0.92,0.92,0.88)
	for x in range(6, 10):
		for y in range(3, 7):
			img.set_pixel(x, y, c)
	img.set_pixel(6, 5, Color(0,0,0))
	img.set_pixel(9, 5, Color(0,0,0))
	for x in range(6, 10):
		for y in range(7, 13):
			img.set_pixel(x, y, c.darkened(0.1))
	for y in range(7, 12):
		img.set_pixel(5, y, c.darkened(0.2))
		img.set_pixel(10, y, c.darkened(0.2))
	for y in range(13, 15):
		img.set_pixel(6, y, c.darkened(0.2))
		img.set_pixel(9, y, c.darkened(0.2))

func _draw_zombie(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(5, 11):
		for y in range(3, 7):
			img.set_pixel(x, y, color.lightened(0.1))
	img.set_pixel(6, 5, Color(0.1,0.1,0.1))
	img.set_pixel(9, 5, Color(0.1,0.1,0.1))
	for x in range(4, 12):
		for y in range(7, 13):
			img.set_pixel(x, y, color)
	for y in range(7, 12):
		img.set_pixel(3, y, color.darkened(0.1))
	for y in range(3, 10):
		img.set_pixel(12, y, color.darkened(0.1))
	for y in range(13, 15):
		img.set_pixel(5, y, Color(0.15,0.2,0.5))
		img.set_pixel(9, y, Color(0.15,0.2,0.5))

func _draw_villager(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(5, 11):
		for y in range(3, 8):
			img.set_pixel(x, y, Color(0.85, 0.7, 0.55))
	for x in range(6, 9):
		for y in range(6, 9):
			img.set_pixel(x, y, Color(0.7, 0.55, 0.4))
	for x in range(4, 12):
		for y in range(9, 15):
			img.set_pixel(x, y, color)
	img.set_pixel(6, 5, Color(0.1,0.1,0.1))
	img.set_pixel(9, 5, Color(0.1,0.1,0.1))

func _draw_enderman(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(6, 10):
		for y in range(2, 15):
			img.set_pixel(x, y, color)
	img.set_pixel(6, 4, Color(0.75, 0.1, 0.85))
	img.set_pixel(9, 4, Color(0.75, 0.1, 0.85))
	for y in range(4, 13):
		img.set_pixel(4, y, color.darkened(0.1))
		img.set_pixel(11, y, color.darkened(0.1))

func _draw_ghast(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(16):
		for y in range(11):
			var dx = x - 7.5
			var dy = y - 5
			if (dx*dx)/56.0 + (dy*dy)/25.0 < 1.0:
				img.set_pixel(x, y, color)
	img.set_pixel(5, 5, Color(0.1,0.1,0.1))
	img.set_pixel(6, 5, Color(0.1,0.1,0.1))
	img.set_pixel(9, 5, Color(0.1,0.1,0.1))
	img.set_pixel(10, 5, Color(0.1,0.1,0.1))
	for x in [3, 6, 9, 12]:
		for y in range(10, 15):
			img.set_pixel(x, y, color.darkened(0.15))

func _draw_blaze(img: Image, color: Color):
	img.fill(Color(0,0,0,0))
	for x in range(6, 10):
		for y in range(4, 12):
			img.set_pixel(x, y, Color(0.3, 0.15, 0.05))
	img.set_pixel(7, 6, Color(1,0.9,0.3))
	img.set_pixel(8, 6, Color(1,0.9,0.3))
	for i in range(6):
		var rx = 4 + randi() % 8
		var ry = 2 + randi() % 12
		img.set_pixel(rx, ry, Color(1, 0.75, 0.2))


func _get_color(id: String) -> Color:
	var data = null
	if Registry.blocks.has(id):
		data = Registry.blocks[id]
	elif Registry.items.has(id):
		data = Registry.items[id]
	elif Registry.mobs.has(id):
		data = Registry.mobs[id]
	
	
	if data == null:
		return Color(0.85, 0.3, 0.85) # Pink = unbekannt
	
	var name = data.get("name", id).to_lower()
	var hardness = data.get("hardness", 1.0)
	var transparent = data.get("transparent", false)
	var light = data.get("light", 0)
	var tool = data.get("tool", "")
	
	# === SPEZIELLE BLÖCKE ===
	if "grass_block" in id:           return Color(0.35, 0.58, 0.25)
	if "dirt" in id:                  return Color(0.52, 0.36, 0.22)
	if "stone" in id or "cobblestone" in id: return Color(0.52, 0.52, 0.52)
	if "sand" in id and "sandstone" not in id: return Color(0.92, 0.85, 0.58)
	if "sandstone" in id:             return Color(0.85, 0.78, 0.55)
	if "gravel" in id:                return Color(0.58, 0.52, 0.48)
	if "clay" in id:                  return Color(0.6, 0.5, 0.45)
	if "obsidian" in id:              return Color(0.12, 0.08, 0.15)
	if "bedrock" in id:               return Color(0.22, 0.22, 0.22)
	if "netherrack" in id:            return Color(0.55, 0.2, 0.2)
	if "soul_sand" in id:             return Color(0.45, 0.35, 0.25)
	if "glowstone" in id:             return Color(1.0, 0.92, 0.55)
	if "end_stone" in id:             return Color(0.88, 0.88, 0.72)
	if "ice" in id:                   return Color(0.65, 0.82, 0.95, 0.75)
	if "snow_block" in id:            return Color(0.95, 0.95, 0.98)
	
	# Holz
	if "log" in id or "planks" in id:
		if "oak" in id:               return Color(0.55, 0.42, 0.25)
		if "birch" in id:             return Color(0.85, 0.78, 0.6)
		if "spruce" in id:            return Color(0.45, 0.32, 0.2)
		if "jungle" in id:            return Color(0.6, 0.4, 0.22)
		return Color(0.55, 0.4, 0.25)
	
	if "leaves" in id:                return Color(0.22, 0.52, 0.18)
	
	# Erze
	if "ore" in id:
		if "coal" in id:             return Color(0.25, 0.25, 0.28)
		if "iron" in id:              return Color(0.65, 0.6, 0.55)
		if "gold" in id:              return Color(0.95, 0.82, 0.25)
		if "copper" in id:            return Color(0.75, 0.45, 0.25)
		if "spawn_egg" in id:        return Color(0.55, 0.75, 0.35)
		if "redstone" in id:          return Color(0.75, 0.1, 0.1)
		if "lapis" in id:             return Color(0.2, 0.35, 0.85)
		if "diamond" in id:           return Color(0.35, 0.82, 0.95)
		if "emerald" in id:           return Color(0.15, 0.75, 0.35)
		if "quartz" in id:            return Color(0.9, 0.88, 0.82)
		return Color(0.6, 0.5, 0.45)
	
	# Blöcke aus Erzen
	if "block" in id and ("iron" in id or "gold" in id or "copper" in id or "diamond" in id):
		if "iron" in id:              return Color(0.72, 0.72, 0.75)
		if "gold" in id:              return Color(0.95, 0.85, 0.3)
		if "copper" in id:            return Color(0.72, 0.45, 0.28)
		if "diamond" in id:           return Color(0.4, 0.85, 0.95)
	
	# Funktionsblöcke
	if "crafting_table" in id:        return Color(0.55, 0.4, 0.25)
	if "furnace" in id:               return Color(0.45, 0.45, 0.45)
	if "chest" in id:                 return Color(0.6, 0.42, 0.22)
	if "jukebox" in id:               return Color(0.5, 0.32, 0.2)
	if "anvil" in id:                 return Color(0.42, 0.42, 0.45)
	if "dispenser" in id or "dropper" in id or "hopper" in id: return Color(0.48, 0.48, 0.48)
	if "piston" in id or "sticky_piston" in id: return Color(0.55, 0.48, 0.38)
	if "tnt" in id:                   return Color(0.85, 0.25, 0.2)
	if "bed" in id:                   return Color(0.75, 0.35, 0.35)
	if "torch" in id:                 return Color(0.95, 0.85, 0.4)
	if "glowstone" in id:             return Color(1.0, 0.92, 0.55)
	if "jack_o_lantern" in id:        return Color(0.95, 0.6, 0.15)
	if "pumpkin" in id:               return Color(0.9, 0.55, 0.15)
	if "hay_bale" in id:              return Color(0.85, 0.75, 0.35)
	if "bookshelf" in id:             return Color(0.55, 0.42, 0.25)
	
	# Quartz
	if "quartz" in id:                return Color(0.92, 0.9, 0.85)
	
	# Brick
	if "brick" in id:                 return Color(0.6, 0.35, 0.3)
	
	# Blumen
	if "flower" in id or "rose" in id: return Color(0.85, 0.3, 0.35)
	
	# Zäune & Türen
	if "fence" in id or "door" in id or "trapdoor" in id:
		return Color(0.55, 0.4, 0.25)
	
	# Wolle (falls vorhanden)
	if "wool" in id:
		if "white" in id:       return Color(0.93, 0.93, 0.93)
		if "orange" in id:      return Color(0.9, 0.5, 0.15)
		if "magenta" in id:     return Color(0.75, 0.25, 0.75)
		if "light_blue" in id:  return Color(0.45, 0.65, 0.9)
		if "yellow" in id:      return Color(0.9, 0.85, 0.2)
		if "lime" in id:        return Color(0.5, 0.85, 0.2)
		if "pink" in id:        return Color(0.95, 0.6, 0.7)
		if "light_gray" in id:  return Color(0.65, 0.65, 0.65)
		if "gray" in id:        return Color(0.35, 0.35, 0.35)
		if "cyan" in id:        return Color(0.15, 0.6, 0.65)
		if "purple" in id:      return Color(0.5, 0.2, 0.7)
		if "blue" in id:        return Color(0.2, 0.25, 0.7)
		if "brown" in id:       return Color(0.45, 0.3, 0.18)
		if "green" in id:       return Color(0.35, 0.45, 0.15)
		if "red" in id:         return Color(0.7, 0.15, 0.15)
		if "black" in id:       return Color(0.1, 0.1, 0.1)
		return Color(0.85, 0.85, 0.85)
	
	# Flüssigkeiten
	if "water" in id:                 return Color(0.25, 0.48, 0.85, 0.65)
	if "lava" in id:                  return Color(0.95, 0.35, 0.08)
	
	# Glas
	if "glass" in id:                 return Color(0.75, 0.88, 0.95, 0.55)
	
	# Fallback nach Härte + Tool
	if tool == "pickaxe":
		if hardness >= 3:             return Color(0.48, 0.48, 0.5)
		return Color(0.55, 0.55, 0.55)
	if tool == "axe":                 return Color(0.55, 0.42, 0.28)
	if tool == "shovel":              return Color(0.52, 0.38, 0.25)
	
	if transparent:                   return Color(0.65, 0.82, 0.92, 0.6)
	if hardness > 10:                 return Color(0.28, 0.28, 0.3)
	if hardness > 2:                  return Color(0.5, 0.5, 0.52)
	# === MATERIALS ===
	if "coal" in id and "ore" not in id:     return Color(0.2, 0.2, 0.22)
	if "charcoal" in id:                     return Color(0.25, 0.22, 0.2)
	if "iron_ingot" in id:                   return Color(0.75, 0.75, 0.78)
	if "gold_ingot" in id:                   return Color(1.0, 0.88, 0.3)
	if "copper_ingot" in id:                 return Color(0.75, 0.45, 0.28)
	if id == "diamond":                      return Color(0.35, 0.85, 0.95)
	if id == "emerald":                      return Color(0.2, 0.8, 0.4)
	if "redstone" in id:                     return Color(0.8, 0.1, 0.1)
	if "lapis_lazuli" in id:                 return Color(0.2, 0.35, 0.85)
	if "nether_quartz" in id:                return Color(0.92, 0.9, 0.85)
	if "stick" in id:                        return Color(0.6, 0.45, 0.28)
	if "string" in id:                       return Color(0.85, 0.85, 0.8)
	if "leather" in id:                      return Color(0.55, 0.35, 0.2)
	if "feather" in id:                      return Color(0.9, 0.88, 0.85)
	if "bone" in id:                         return Color(0.9, 0.88, 0.8)
	if "gunpowder" in id:                    return Color(0.3, 0.3, 0.3)
	if "ender_pearl" in id:                  return Color(0.25, 0.6, 0.55)
	if "blaze_rod" in id:                    return Color(1.0, 0.7, 0.2)
	if "blaze_powder" in id:                 return Color(1.0, 0.75, 0.25)
	if "ghast_tear" in id:                   return Color(0.85, 0.9, 0.95)
	if "magma_cream" in id:                  return Color(0.95, 0.5, 0.15)
	if "slimeball" in id:                    return Color(0.4, 0.75, 0.35)
	if "clay_ball" in id:                    return Color(0.6, 0.5, 0.45)
	if "glowstone_dust" in id:               return Color(1.0, 0.95, 0.5)
	if "snowball" in id:                     return Color(0.95, 0.95, 0.98)
	if "flint" in id:                        return Color(0.4, 0.4, 0.42)
	
	# === FOOD ===
	if "bread" in id:                        return Color(0.85, 0.65, 0.35)
	if "steak" in id or "cooked_beef" in id: return Color(0.7, 0.35, 0.25)
	if "cooked_porkchop" in id:              return Color(0.75, 0.4, 0.3)
	if "cooked_chicken" in id:               return Color(0.85, 0.6, 0.4)
	if "apple" in id:                        return Color(0.85, 0.2, 0.2)
	if "golden_apple" in id:                 return Color(1.0, 0.85, 0.2)
	if "carrot" in id:                       return Color(0.95, 0.55, 0.15)
	if "potato" in id or "baked_potato" in id: return Color(0.85, 0.7, 0.35)
	if "melon_slice" in id:                  return Color(0.85, 0.2, 0.25)
	if "pumpkin_pie" in id:                  return Color(0.9, 0.6, 0.25)
	if "cookie" in id:                       return Color(0.6, 0.4, 0.2)
	
	# === MISC ===
	if "flint_and_steel" in id:              return Color(0.4, 0.4, 0.42)
	if "shears" in id:                       return Color(0.7, 0.7, 0.72)
	if "bow" in id:                          return Color(0.55, 0.4, 0.25)
	if "arrow" in id:                        return Color(0.6, 0.55, 0.45)
	if "bucket" in id and "water" not in id and "lava" not in id: return Color(0.65, 0.65, 0.68)
	if "water_bucket" in id:                 return Color(0.3, 0.55, 0.85)
	if "lava_bucket" in id:                  return Color(0.9, 0.35, 0.1)
	if "elytra" in id:                       return Color(0.3, 0.25, 0.35)
	if "compass" in id:                      return Color(0.7, 0.65, 0.55)
	if "clock" in id:                        return Color(0.85, 0.75, 0.35)
	if "map" in id:                          return Color(0.6, 0.75, 0.55)
	if "name_tag" in id:                     return Color(0.9, 0.85, 0.6)
	if "lead" in id:                         return Color(0.5, 0.35, 0.2)

# === TOOLS (automatisch erkannt) ===
	if "pickaxe" in id:
		if "wood" in id:   return Color(0.55, 0.42, 0.28)
		if "stone" in id:  return Color(0.5, 0.5, 0.52)
		if "iron" in id:   return Color(0.72, 0.72, 0.75)
		if "diamond" in id:return Color(0.4, 0.82, 0.95)
	if "axe" in id:
		if "wood" in id:   return Color(0.55, 0.42, 0.28)
		if "stone" in id:  return Color(0.5, 0.5, 0.52)
		if "iron" in id:   return Color(0.72, 0.72, 0.75)
		if "diamond" in id:return Color(0.4, 0.82, 0.95)
	if "shovel" in id:
		if "wood" in id:   return Color(0.55, 0.42, 0.28)
		if "stone" in id:  return Color(0.5, 0.5, 0.52)
		if "iron" in id:   return Color(0.72, 0.72, 0.75)
		if "diamond" in id:return Color(0.4, 0.82, 0.95)
	if "sword" in id:
		if "wood" in id:   return Color(0.55, 0.42, 0.28)
		if "stone" in id:  return Color(0.5, 0.5, 0.52)
		if "iron" in id:   return Color(0.72, 0.72, 0.75)
		if "diamond" in id:return Color(0.4, 0.82, 0.95)

# === ARMOR ===
	if "helmet" in id or "chestplate" in id or "leggings" in id or "boots" in id:
		if "leather" in id:   return Color(0.55, 0.35, 0.2)
		if "iron" in id:      return Color(0.72, 0.72, 0.75)
		if "diamond" in id:   return Color(0.4, 0.82, 0.95)
		if "gold" in id:      return Color(1.0, 0.88, 0.3)
		if "chainmail" in id: return Color(0.6, 0.6, 0.62)
	# === ENCHANTMENTS (Bücher) ===
	if "sharpness" in id:                return Color(0.9, 0.25, 0.25)   # Rot
	if "protection" in id:               return Color(0.3, 0.55, 0.95)   # Blau
	if "efficiency" in id:               return Color(0.3, 0.85, 0.4)    # Grün
	if "unbreaking" in id:               return Color(0.7, 0.35, 0.85)   # Lila
	if "power" in id:                    return Color(0.2, 0.85, 0.85)   # Cyan

# === POTIONS ===
	if "potion_speed" in id or "swiftness" in id: return Color(0.4, 0.75, 1.0)
	if "potion_strength" in id:                   return Color(0.85, 0.15, 0.15)
	if "potion_regeneration" in id:                return Color(0.95, 0.4, 0.7)
	if "potion_fire_resistance" in id:             return Color(1.0, 0.55, 0.15)
	if "awkward_potion" in id:                     return Color(0.55, 0.45, 0.65)
	if "potion" in id:                             return Color(0.5, 0.4, 0.6)
	# === PASSIVE MOBS ===
	if "sheep" in id:                    return Color(0.85, 0.85, 0.85)
	if "cow" in id or "mooshroom" in id: return Color(0.55, 0.35, 0.25)
	if "pig" in id:                      return Color(0.95, 0.6, 0.65)
	if "chicken" in id:                  return Color(0.95, 0.85, 0.7)
	if "rabbit" in id:                   return Color(0.85, 0.7, 0.55)
	if "horse" in id:                    return Color(0.6, 0.4, 0.25)
	if "ocelot" in id:                   return Color(0.9, 0.75, 0.4)
	if "squid" in id:                    return Color(0.25, 0.35, 0.5)
	if "bat" in id:                      return Color(0.35, 0.3, 0.35)
	if "villager" in id:                 return Color(0.55, 0.4, 0.3)	
	if "snow_golem" in id:               return Color(0.9, 0.9, 0.95)
	if "iron_golem" in id:               return Color(0.7, 0.7, 0.75)

# === NEUTRAL MOBS ===
	if "erebite" in id:                  return Color(0.2, 0.15, 0.3)     # Enderman-Style
	if "zombie_pigman" in id:            return Color(0.7, 0.5, 0.45)
	if "wolf" in id:                     return Color(0.6, 0.55, 0.5)
	if "spider" in id or "cave_spider" in id: return Color(0.3, 0.25, 0.2)

# === HOSTILE MOBS ===
	if "zombie" in id or "husk" in id or "zombie_villager" in id: return Color(0.35, 0.55, 0.3)
	if "skeleton" in id or "stray" in id or "wither_skeleton" in id: return Color(0.9, 0.9, 0.85)
	if "creeper" in id:                  return Color(0.2, 0.55, 0.2)
	if "witch" in id:                    return Color(0.4, 0.25, 0.45)
	if "slime" in id:                    return Color(0.4, 0.75, 0.35)
	if "silverfish" in id:               return Color(0.7, 0.7, 0.65)
	if "endermite" in id:                return Color(0.35, 0.2, 0.4)
	if "soulwraith" in id:               return Color(0.85, 0.85, 0.9)   # Ghast
	if "magma_cube" in id:               return Color(0.8, 0.3, 0.1)
	if "blaze" in id:                    return Color(1.0, 0.7, 0.2)
	if "shulker" in id:                  return Color(0.6, 0.4, 0.7)

# === BOSSES ===
	if "erebus_sovereign" in id or "ender_dragon" in id: return Color(0.2, 0.1, 0.3)
	if "wither" in id:                   return Color(0.15, 0.15, 0.15)

# === SPECIAL ===
	if "hero_no_brain" in id:            return Color(0.9, 0.3, 0.3)
	if "charlie_emily" in id:            return Color(0.3, 0.6, 0.9)
	return Color(0.65, 0.5, 0.55) # Standard
	
	
func _draw_armor(img: Image, color: Color, name: String):
	# Grundform (Brustpanzer-ähnlich)
	for x in range(3, 13):
		for y in range(4, 13):
			img.set_pixel(x, y, color)
	
	# Schulterpolster
	for x in range(2, 5):
		for y in range(3, 7):
			img.set_pixel(x, y, color.darkened(0.2))
	for x in range(11, 14):
		for y in range(3, 7):
			img.set_pixel(x, y, color.darkened(0.2))
	
	# Gürtel
	for x in range(3, 13):
		for y in range(9, 11):
			img.set_pixel(x, y, color.darkened(0.3))


func _draw_clock(img: Image, color: Color):
	# Runde Uhr
	for x in range(16):
		for y in range(16):
			var dx = x - 7.5
			var dy = y - 7.5
			if dx*dx + dy*dy <= 50:
				img.set_pixel(x, y, color)
	
	# Ziffernblatt (dunkler)
	for x in range(4, 12):
		for y in range(4, 12):
			var dx = x - 7.5
			var dy = y - 7.5
			if dx*dx + dy*dy <= 35:
				img.set_pixel(x, y, color.darkened(0.3))
	
	# Uhrzeiger
	img.set_pixel(7, 7, Color(0,0,0))
	img.set_pixel(8, 7, Color(0,0,0))
	img.set_pixel(7, 5, Color(0,0,0))
	img.set_pixel(7, 6, Color(0,0,0))


func _draw_compass(img: Image, color: Color):
	# Runde Kompasshülle
	for x in range(16):
		for y in range(16):
			var dx = x - 7.5
			var dy = y - 7.5
			if dx*dx + dy*dy <= 52:
				img.set_pixel(x, y, color)
	
	# Nadel (rot oben, grau unten)
	for y in range(3, 8):
		img.set_pixel(7, y, Color(0.9, 0.2, 0.2))
		img.set_pixel(8, y, Color(0.9, 0.2, 0.2))
	
	for y in range(8, 13):
		img.set_pixel(7, y, Color(0.5, 0.5, 0.5))
		img.set_pixel(8, y, Color(0.5, 0.5, 0.5))


func _draw_map(img: Image, color: Color):
	# Rechteckige Karte mit Falten
	for x in range(2, 14):
		for y in range(2, 14):
			img.set_pixel(x, y, color)
	
	# Faltenlinien
	for x in range(2, 14):
		img.set_pixel(x, 7, color.darkened(0.25))
	for y in range(2, 14):
		img.set_pixel(7, y, color.darkened(0.25))
	
	# Rand
	for x in range(16):
		for y in range(16):
			if x < 2 or x > 13 or y < 2 or y > 13:
				img.set_pixel(x, y, color.darkened(0.4))


func _draw_lead(img: Image, color: Color):
	# Dünne Leine
	for x in range(5, 11):
		for y in range(2, 14):
			img.set_pixel(x, y, color)
	
	# Knoten oben und unten
	for x in range(4, 12):
		img.set_pixel(x, 2, color.darkened(0.3))
		img.set_pixel(x, 13, color.darkened(0.3))
		
		
		
func _draw_bow(img: Image, color: Color):
	# Gebogener Bogen
	for y in range(3, 13):
		img.set_pixel(5, y, color)
		img.set_pixel(10, y, color)
	for y in range(4, 12):
		img.set_pixel(6, y, color.darkened(0.2))
		img.set_pixel(9, y, color.darkened(0.2))

func _draw_arrow(img: Image, color: Color):
	# Pfeil
	for x in range(2, 14):
		img.set_pixel(x, 7, color)
		img.set_pixel(x, 8, color)
	# Spitze
	for x in range(12, 15):
		img.set_pixel(x, 7, color)
		img.set_pixel(x, 8, color)

func _draw_helmet(img: Image, color: Color):
	for x in range(4, 12):
		for y in range(3, 10):
			img.set_pixel(x, y, color)
	# Visier
	for x in range(5, 11):
		img.set_pixel(x, 6, color.darkened(0.3))

func _draw_chestplate(img: Image, color: Color):
	for x in range(3, 13):
		for y in range(4, 13):
			img.set_pixel(x, y, color)
	# Gürtel
	for x in range(3, 13):
		img.set_pixel(x, 9, color.darkened(0.3))

func _draw_leggings(img: Image, color: Color):
	for x in range(4, 12):
		for y in range(5, 14):
			img.set_pixel(x, y, color)

func _draw_boots(img: Image, color: Color):
	for x in range(4, 12):
		for y in range(8, 14):
			img.set_pixel(x, y, color)

func _draw_bucket(img: Image, color: Color):
	# Eimer-Form
	for x in range(4, 12):
		for y in range(4, 13):
			img.set_pixel(x, y, color)
	# Henkel
	for x in range(5, 11):
		img.set_pixel(x, 3, color.darkened(0.3))

func _draw_fishing_rod(img: Image, color: Color):
	for y in range(2, 14):
		img.set_pixel(7, y, color)
	# Rolle
	for x in range(5, 10):
		img.set_pixel(x, 10, color.darkened(0.3))

func _draw_elytra(img: Image, color: Color):
	for x in range(3, 13):
		for y in range(4, 12):
			img.set_pixel(x, y, color)
	# Flügel-Form
	for x in range(2, 6):
		img.set_pixel(x, 6, color.darkened(0.2))
	for x in range(10, 14):
		img.set_pixel(x, 6, color.darkened(0.2))
		
		
func _draw_name_tag(img: Image, color: Color):
	# Rechteckiges Namensschild
	for x in range(3, 13):
		for y in range(5, 11):
			img.set_pixel(x, y, color)
	# Loch oben
	img.set_pixel(7, 4, Color(0.2, 0.2, 0.2))
	img.set_pixel(8, 4, Color(0.2, 0.2, 0.2))

func _draw_saddle(img: Image, color: Color):
	# Sattel-Form
	for x in range(3, 13):
		for y in range(5, 12):
			img.set_pixel(x, y, color)
	# Sattelhorn
	for x in range(6, 10):
		for y in range(3, 6):
			img.set_pixel(x, y, color.darkened(0.25))

func _draw_flint_and_steel(img: Image, color: Color):
	# Feuerzeug
	for x in range(4, 12):
		for y in range(6, 11):
			img.set_pixel(x, y, color)
	# Stahl-Teil
	for x in range(3, 7):
		img.set_pixel(x, 5, Color(0.6, 0.6, 0.65))
	# Funken
	img.set_pixel(10, 4, Color(1, 0.8, 0.2))
	img.set_pixel(11, 5, Color(1, 0.8, 0.2))
	
	
func _draw_food(img: Image, color: Color, name: String):
	if "cake" in name:
		for x in range(3, 13):
			for y in range(6, 13):
				img.set_pixel(x, y, color)
		for x in range(3, 13):
			for y in range(6, 8):
				img.set_pixel(x, y, color.lightened(0.3))
	
	elif "pumpkin_pie" in name:
		for x in range(3, 13):
			for y in range(5, 12):
				img.set_pixel(x, y, color)
	
	elif "cookie" in name:
		for x in range(4, 12):
			for y in range(5, 11):
				img.set_pixel(x, y, color)
		img.set_pixel(6, 7, Color(0.3, 0.2, 0.1))
		img.set_pixel(9, 8, Color(0.3, 0.2, 0.1))
	
	elif "golden_apple" in name:
		for x in range(4, 12):
			for y in range(4, 12):
				img.set_pixel(x, y, Color(1.0, 0.85, 0.2))
		img.set_pixel(7, 3, Color(0.2, 0.7, 0.2))
	
	elif "mutton" in name:
		for x in range(3, 13):
			for y in range(5, 12):
				img.set_pixel(x, y, color)
		for x in range(4, 12):
			img.set_pixel(x, 7, color.lightened(0.3))
	
	elif "steak" in name or "cooked_beef" in name:
		for x in range(3, 13):
			for y in range(5, 12):
				img.set_pixel(x, y, color)
	
	elif "bread" in name:
		for x in range(3, 13):
			for y in range(6, 11):
				img.set_pixel(x, y, color)
	
	elif "carrot" in name:
		for x in range(6, 10):
			for y in range(3, 13):
				img.set_pixel(x, y, color)
	
	elif "potato" in name or "baked_potato" in name:
		for x in range(4, 12):
			for y in range(5, 12):
				img.set_pixel(x, y, color)
	
	elif "apple" in name:
		for x in range(4, 12):
			for y in range(4, 12):
				img.set_pixel(x, y, color)
		img.set_pixel(7, 3, Color(0.2, 0.6, 0.2))
	
	elif "melon" in name:
		for x in range(3, 13):
			for y in range(5, 12):
				img.set_pixel(x, y, color)
		for x in range(4, 12):
			img.set_pixel(x, 8, Color(0.3, 0.6, 0.2))
			
	if "cake" in name:
		for x in range(3, 13):
			for y in range(6, 13):
				img.set_pixel(x, y, color)
		for x in range(3, 13):
			for y in range(6, 8):
				img.set_pixel(x, y, color.lightened(0.3))
	elif "pumpkin_pie" in name:
		for x in range(3, 13):
			for y in range(5, 12):
				img.set_pixel(x, y, color)
		for x in range(3, 13):
			img.set_pixel(x, 5, Color(0.95, 0.6, 0.2))
			img.set_pixel(x, 11, Color(0.95, 0.6, 0.2))
	elif "cookie" in name:
		for x in range(4, 12):
			for y in range(5, 11):
				img.set_pixel(x, y, color)
		img.set_pixel(6, 7, Color(0.3, 0.2, 0.1))
		img.set_pixel(9, 8, Color(0.3, 0.2, 0.1))
	elif "enchanted_golden_apple" in name:
		for x in range(4, 12):
			for y in range(4, 12):
				img.set_pixel(x, y, Color(1.0, 0.85, 0.2))
		img.set_pixel(7, 3, Color(0.2, 0.7, 0.2))
		for i in range(6):
			img.set_pixel(4 + randi() % 8, 4 + randi() % 8, Color(1, 1, 1, 0.6))
	elif "golden_apple" in name:
		for x in range(4, 12):
			for y in range(4, 12):
				img.set_pixel(x, y, Color(1.0, 0.85, 0.2))
		img.set_pixel(7, 3, Color(0.2, 0.7, 0.2))
	elif "mutton" in name:
		for x in range(3, 13):
			for y in range(5, 12):
				img.set_pixel(x, y, color)
		for x in range(4, 12):
			img.set_pixel(x, 7, color.lightened(0.3))
	elif "cooked_beef" in name:
		for x in range(3, 13):
			for y in range(5, 12):
				img.set_pixel(x, y, color)
		for i in range(4):
			img.set_pixel(4 + i * 2, 6, color.darkened(0.3))
	elif "beef" in name:
		for x in range(3, 13):
			for y in range(5, 12):
				img.set_pixel(x, y, Color(0.85, 0.3, 0.3))
		for x in range(4, 12):
			img.set_pixel(x, 8, Color(0.95, 0.6, 0.6))
	elif "cooked_porkchop" in name:
		for x in range(3, 13):
			for y in range(5, 12):
				img.set_pixel(x, y, color)
		img.set_pixel(6, 7, Color(0.3, 0.15, 0.1))
	elif "porkchop" in name:
		for x in range(3, 13):
			for y in range(5, 12):
				img.set_pixel(x, y, Color(0.92, 0.55, 0.55))
		for x in range(4, 12):
			img.set_pixel(x, 8, Color(0.75, 0.35, 0.35))
	elif "cooked_chicken" in name:
		for x in range(4, 12):
			for y in range(5, 12):
				img.set_pixel(x, y, color)
		img.set_pixel(7, 7, Color(0.4, 0.25, 0.1))
	elif "chicken" in name:
		for x in range(4, 12):
			for y in range(5, 12):
				img.set_pixel(x, y, Color(0.95, 0.8, 0.75))
	elif "cooked_fish" in name:
		for x in range(3, 13):
			for y in range(6, 11):
				img.set_pixel(x, y, Color(0.8, 0.65, 0.35))
		img.set_pixel(11, 8, Color(0.5, 0.4, 0.2))
	elif "fish" in name:
		for x in range(3, 13):
			for y in range(6, 11):
				img.set_pixel(x, y, Color(0.5, 0.6, 0.75))
		img.set_pixel(11, 8, Color(0.3, 0.4, 0.55))
		img.set_pixel(5, 7, Color(0.1, 0.1, 0.1))
	elif "bread" in name:
		for x in range(3, 13):
			for y in range(6, 11):
				img.set_pixel(x, y, color)
		for x in range(3, 13):
			img.set_pixel(x, 6, color.darkened(0.2))
	elif "carrot" in name:
		for x in range(6, 10):
			for y in range(4, 13):
				img.set_pixel(x, y, color)
		for x in range(5, 11):
			img.set_pixel(x, 3, Color(0.2, 0.7, 0.2))
	elif "baked_potato" in name:
		for x in range(4, 12):
			for y in range(5, 12):
				img.set_pixel(x, y, color)
		for i in range(4):
			img.set_pixel(5 + randi() % 6, 6 + randi() % 4, color.darkened(0.3))
	elif "potato" in name:
		for x in range(4, 12):
			for y in range(5, 12):
				img.set_pixel(x, y, Color(0.85, 0.7, 0.45))
		for i in range(4):
			img.set_pixel(5 + randi() % 6, 6 + randi() % 4, Color(0.6, 0.45, 0.3))
	elif "apple" in name:
		for x in range(4, 12):
			for y in range(4, 12):
				img.set_pixel(x, y, color)
		img.set_pixel(7, 3, Color(0.2, 0.6, 0.2))
	elif "melon" in name:
		for x in range(3, 13):
			for y in range(5, 12):
				img.set_pixel(x, y, color)
		for x in range(4, 12):
			img.set_pixel(x, 8, Color(0.3, 0.6, 0.2))
	elif "mushroom_stew" in name:
		for x in range(3, 13):
			for y in range(7, 12):
				img.set_pixel(x, y, Color(0.55, 0.45, 0.35))
		for x in range(4, 12):
			img.set_pixel(x, 7, Color(0.8, 0.7, 0.6))
		img.set_pixel(6, 5, Color(0.85, 0.2, 0.2))
		img.set_pixel(9, 5, Color(0.85, 0.2, 0.2))
	elif "rotten_flesh" in name:
		for x in range(3, 13):
			for y in range(5, 12):
				img.set_pixel(x, y, Color(0.45, 0.4, 0.2))
		for i in range(5):
			img.set_pixel(4 + randi() % 8, 6 + randi() % 5, Color(0.25, 0.5, 0.15))
	elif "spider_eye" in name:
		for x in range(16):
			for y in range(16):
				var dx = x - 7.5
				var dy = y - 7.5
				if dx*dx + dy*dy <= 40:
					img.set_pixel(x, y, Color(0.6, 0.15, 0.15))
		img.set_pixel(7, 7, Color(0.9, 0.1, 0.1))
		img.set_pixel(8, 7, Color(0.9, 0.1, 0.1))
		img.set_pixel(7, 8, Color(0.1, 0.1, 0.1))
	else:
		for x in range(16):
			for y in range(16):
				var dx = x - 7.5
				var dy = y - 7.5
				if dx*dx + dy*dy < 55:
					img.set_pixel(x, y, color)
					
					
					
					
					
					
func _draw_dragon_egg(img: Image, color: Color):
	# Ei-Form (oval)
	for x in range(16):
		for y in range(16):
			var dx = x - 7.5
			var dy = y - 8
			if (dx*dx / 36) + (dy*dy / 49) < 1.0:   # Oval
				img.set_pixel(x, y, color)
	
	# Schuppen-Muster / Textur
	for x in range(4, 12):
		for y in range(4, 13):
			if (x + y) % 3 == 0:
				img.set_pixel(x, y, color.darkened(0.25))
	
	# Leichter Rand
	for x in range(16):
		for y in range(16):
			var dx = x - 7.5
			var dy = y - 8
			if (dx*dx / 36) + (dy*dy / 49) > 0.85:
				img.set_pixel(x, y, color.darkened(0.4))
				
				
				
				
func _draw_cake(img: Image, color: Color):
	# Kuchen mit Schichten
	for x in range(3, 13):
		for y in range(6, 13):
			img.set_pixel(x, y, color)
	# Obere Schicht (heller)
	for x in range(3, 13):
		for y in range(6, 8):
			img.set_pixel(x, y, color.lightened(0.25))
	# Kerzen-Andeutung
	img.set_pixel(6, 5, Color(1, 0.9, 0.3))
	img.set_pixel(9, 5, Color(1, 0.9, 0.3))

func _draw_pumpkin_pie(img: Image, color: Color):
	# Pie-Form (rundlich)
	for x in range(3, 13):
		for y in range(5, 12):
			img.set_pixel(x, y, color)
	# Orangener Rand
	for x in range(3, 13):
		img.set_pixel(x, 5, Color(0.95, 0.6, 0.2))
		img.set_pixel(x, 11, Color(0.95, 0.6, 0.2))

func _draw_cookie(img: Image, color: Color):
	# Kleiner runder Keks
	for x in range(4, 12):
		for y in range(5, 11):
			img.set_pixel(x, y, color)
	# Schokostückchen
	img.set_pixel(6, 7, Color(0.3, 0.2, 0.1))
	img.set_pixel(9, 8, Color(0.3, 0.2, 0.1))

func _draw_golden_apple(img: Image, color: Color):
	# Goldener Apfel
	for x in range(4, 12):
		for y in range(4, 12):
			img.set_pixel(x, y, Color(1.0, 0.85, 0.2))
	# Blatt
	img.set_pixel(7, 3, Color(0.2, 0.7, 0.2))

func _draw_bone_meal(img: Image, color: Color):
	# Knochenmehl (weißes Pulver)
	for x in range(4, 12):
		for y in range(4, 12):
			img.set_pixel(x, y, Color(0.95, 0.95, 0.9))
	# Kleine Körner
	for i in range(12):
		var x = randi() % 16
		var y = randi() % 16
		img.set_pixel(x, y, Color(0.8, 0.8, 0.75))
