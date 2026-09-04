class_name Farming
extends RefCounted
# Hoe till, plant seeds, growth with water + rain.

const CROP_STAGES := {
	"wheat": ["wheat_0", "wheat_1", "wheat_2", "wheat_3"],
	"carrot": ["carrots_0", "carrots_3"],
	"potato": ["potatoes_0", "potatoes_3"],
}

static func is_hoe(item_id: String) -> bool:
	return item_id.ends_with("_hoe") or item_id == "hoe"


static func seed_crop(item_id: String) -> String:
	match item_id:
		"wheat_seeds":
			return "wheat"
		"carrot":
			return "carrot"
		"potato":
			return "potato"
	return ""


static func try_till(world, renderer, cell: Vector3i) -> bool:
	var id = world.get_block(cell.x, cell.y, cell.z)
	if id != "dirt" and id != "grass_block":
		return false
	var above = world.get_block(cell.x, cell.y + 1, cell.z)
	if above != "air":
		return false
	if renderer:
		renderer.edit_block(cell.x, cell.y, cell.z, "farmland")
	else:
		world.set_block(cell.x, cell.y, cell.z, "farmland")
	return true


static func try_plant(world, renderer, cell: Vector3i, crop: String) -> bool:
	var soil = world.get_block(cell.x, cell.y, cell.z)
	if soil != "farmland" and soil != "farmland_moist":
		return false
	var above = Vector3i(cell.x, cell.y + 1, cell.z)
	if world.get_block(above.x, above.y, above.z) != "air":
		return false
	var stages = CROP_STAGES.get(crop, [])
	if stages.is_empty():
		return false
	if renderer:
		renderer.edit_block(above.x, above.y, above.z, stages[0])
	else:
		world.set_block(above.x, above.y, above.z, stages[0])
	return true


static func has_water_near(world, cell: Vector3i, radius: int = 4) -> bool:
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			for dy in range(-1, 2):
				if world.get_block(cell.x + dx, cell.y + dy, cell.z + dz) == "water":
					return true
	return false


static func tick_chunk(world, renderer, chunk, is_raining: bool) -> void:
	# Light random growth ticks on farmland crops in this chunk
	if chunk == null or not "blocks" in chunk:
		return
	var keys = chunk.blocks.keys()
	if keys.is_empty():
		return
	# Sample a few cells per call
	for _i in range(mini(8, keys.size())):
		var key = keys[randi() % keys.size()]
		var id = str(chunk.blocks[key])
		var crop = ""
		var stage = -1
		for cname in CROP_STAGES.keys():
			var stages: Array = CROP_STAGES[cname]
			var idx = stages.find(id)
			if idx >= 0:
				crop = cname
				stage = idx
				break
		if crop == "" or stage < 0:
			continue
		var stages2: Array = CROP_STAGES[crop]
		if stage >= stages2.size() - 1:
			continue
		var wx = chunk.cx * 16 + key.x
		var wz = chunk.cz * 16 + key.z
		var soil = world.get_block(wx, key.y - 1, wz)
		var moist = soil == "farmland_moist" or has_water_near(world, Vector3i(wx, key.y - 1, wz))
		if moist and soil == "farmland":
			if renderer:
				renderer.edit_block(wx, key.y - 1, wz, "farmland_moist")
		var chance = 0.08
		if moist:
			chance *= 2.5
		if is_raining:
			chance *= 2.0
		if randf() > chance:
			continue
		var nxt = stages2[stage + 1]
		if renderer:
			renderer.edit_block(wx, key.y, wz, nxt)
		else:
			world.set_block(wx, key.y, wz, nxt)
