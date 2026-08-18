class_name DispenserInventory
extends RefCounted
# 9 slots, like a Minecraft dispenser

var slots: Array = []   # ItemStack or null

func _init() -> void:
	slots.resize(9)

func first_non_empty() -> int:
	for i in range(slots.size()):
		if slots[i] != null and slots[i].count > 0:
			return i
	return -1

func take_one() -> ItemStack:
	var idx = first_non_empty()
	if idx < 0:
		return null
	var s = slots[idx]
	var out = ItemStack.new(s.item_id, 1)
	if s.durability >= 0:
		out.durability = s.durability
	out.enchantments = s.enchantments.duplicate()
	out.custom_name = s.custom_name
	s.count -= 1
	if s.count <= 0:
		slots[idx] = null
	return out

func is_empty() -> bool:
	return first_non_empty() < 0
