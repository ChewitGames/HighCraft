class_name BrewingStand
extends RefCounted
## Minecraft 1.6.4-style brewing stand.
## Slots: 0-2 bottles, 3 ingredient, 4 blaze powder (fuel).

const BREW_TIME := 8.0

var bottles: Array = [null, null, null]
var ingredient = null
var fuel = null
var brew_progress: float = 0.0
var brewing: bool = false

func tick(delta: float) -> void:
	if not _can_brew():
		brewing = false
		brew_progress = 0.0
		return
	brewing = true
	brew_progress += delta
	if brew_progress >= BREW_TIME:
		_finish_brew()
		brew_progress = 0.0

func _can_brew() -> bool:
	if ingredient == null:
		return false
	if fuel == null or str(fuel.item_id) != "blaze_powder" or int(fuel.count) <= 0:
		return false
	var any := false
	for i in range(3):
		if bottles[i] != null and _result_for(str(bottles[i].item_id), str(ingredient.item_id)) != "":
			any = true
	return any

func _finish_brew() -> void:
	var ing = str(ingredient.item_id)
	var changed := false
	for i in range(3):
		if bottles[i] == null:
			continue
		var nxt = _result_for(str(bottles[i].item_id), ing)
		if nxt == "":
			continue
		bottles[i] = ItemStack.new(nxt, 1)
		changed = true
	if not changed:
		return
	ingredient.count -= 1
	if ingredient.count <= 0:
		ingredient = null
	if fuel != null:
		fuel.count -= 1
		if fuel.count <= 0:
			fuel = null

func _result_for(base_id: String, ing: String) -> String:
	if Registry == null:
		return ""
	if "brew_result" in Registry and Registry.has_method("brew_result"):
		return str(Registry.brew_result(base_id, ing))
	for pid in Registry.potions.keys():
		var pot = Registry.potions[pid]
		if str(pot.get("base", "")) == base_id and str(pot.get("ingredient", "")) == ing:
			return str(pid)
	# Splash conversion
	if ing == "gunpowder" and base_id.begins_with("potion_"):
		return "splash_" + base_id
	if ing == "gunpowder" and base_id in ["awkward_potion", "mundane_potion", "thick_potion", "water_bottle"]:
		return "splash_" + base_id
	return ""
