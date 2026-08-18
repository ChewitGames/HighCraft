class_name ItemStack
extends RefCounted

var enchantments: Dictionary = {}   # { "sharpness": 3, "unbreaking": 2 }
var custom_name: String = ""        # ← NEU

func add_enchantment(enchant_id: String, level: int) -> void:
	enchantments[enchant_id] = level
func has_enchantment(enchant_id: String) -> bool:
	return enchantments.has(enchant_id)
func get_enchantment_level(enchant_id: String) -> int:
	return enchantments.get(enchant_id, 0)
func get_enchantment_names() -> Array:
	var names = []
	for id in enchantments.keys():
		names.append(id + " " + str(enchantments[id]))
	return names

var item_id: String
var count: int
var durability: int = -1

func _init(p_id: String, p_count: int = 1) -> void:
	item_id = p_id
	count = p_count
	var it = Registry.get_item(p_id)
	if it != null and it.has("durability"):
		durability = int(it["durability"])

func max_stack() -> int:
	return Registry.max_stack_of(item_id)
func stackable_with(other) -> bool:
	if other == null:
		return false
	return other.item_id == item_id and durability == -1 and other.durability == -1
func display_name() -> String:
	if custom_name.strip_edges() != "":
		return custom_name
	var it = Registry.get_item(item_id)
	if it != null:
		return it.get("name", item_id)
	var b = Registry.get_block(item_id)
	if b != null:
		return b.get("name", item_id)
	return item_id
