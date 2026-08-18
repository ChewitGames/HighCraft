class_name Furnace
extends RefCounted
# Furnace state: input + fuel + output slots, with burn time and cook progress.
# Call tick(delta) each frame. Fuels and cook time are simple, tunable values.

const COOK_TIME = 10.0   # seconds per item

const FUEL_TIME = {
	"coal": 80.0, "charcoal": 80.0, "lava_bucket": 1000.0,
	"oak_planks": 15.0, "birch_planks": 15.0, "spruce_planks": 15.0,
	"jungle_planks": 15.0, "oak_log": 15.0, "stick": 5.0
}

var input = null    # ItemStack or null
var fuel = null
var output = null

var burn_time_left: float = 0.0
var burn_time_total: float = 0.0
var cook_progress: float = 0.0


func is_burning() -> bool:
	return burn_time_left > 0.0


func _can_smelt() -> bool:
	if input == null:
		return false
	var res = Crafting.smelt(input.item_id)
	if res.is_empty():
		return false
	if output == null:
		return true
	if output.item_id != res["result"]:
		return false
	return output.count + res["count"] <= output.max_stack()


func tick(delta: float) -> void:
	# consume fuel if needed and there is something to smelt
	if not is_burning() and _can_smelt() and fuel != null:
		var ft = FUEL_TIME.get(fuel.item_id, 0.0)
		if ft > 0.0:
			burn_time_total = ft
			burn_time_left = ft
			fuel.count -= 1
			if fuel.count <= 0:
				fuel = null

	if is_burning():
		burn_time_left = maxf(0.0, burn_time_left - delta)
		if _can_smelt():
			cook_progress += delta
			if cook_progress >= COOK_TIME:
				cook_progress = 0.0
				_finish_smelt()
		else:
			cook_progress = 0.0
	else:
		cook_progress = maxf(0.0, cook_progress - delta)


func _finish_smelt() -> void:
	var res = Crafting.smelt(input.item_id)
	if res.is_empty():
		return
	if output == null:
		output = ItemStack.new(res["result"], res["count"])
	else:
		output.count += res["count"]
	input.count -= 1
	if input.count <= 0:
		input = null
