class_name Inventory
extends RefCounted
# Player inventory: 9 hotbar slots + 27 main slots + 4 armor slots.
# Slots hold an ItemStack or null. The hotbar selection drives the held item.

const HOTBAR = 9
const MAIN = 27
const ARMOR = 4

var hotbar: Array = []
var main: Array = []
var armor: Array = []
var selected: int = 0


func _init() -> void:
	hotbar.resize(HOTBAR)
	main.resize(MAIN)
	armor.resize(ARMOR)


func held():
	return hotbar[selected]


func select(i: int) -> void:
	selected = clampi(i, 0, HOTBAR - 1)


func scroll(d: int) -> void:
	selected = (selected + d + HOTBAR) % HOTBAR


func add(item_id: String, amount: int) -> int:
	var bags = [hotbar, main]
	var ms = Registry.max_stack_of(item_id)
	# merge into existing stacks
	for bag in bags:
		for i in range(bag.size()):
			var s = bag[i]
			if s != null and s.item_id == item_id and s.durability == -1 and s.count < ms:
				var moved = mini(ms - s.count, amount)
				s.count += moved
				amount -= moved
				if amount <= 0:
					return 0
	# fill empty slots
	for bag in bags:
		for i in range(bag.size()):
			if bag[i] == null and amount > 0:
				var put = mini(ms, amount)
				bag[i] = ItemStack.new(item_id, put)
				amount -= put
				if amount <= 0:
					return 0
	return amount


func count_of(item_id: String) -> int:
	var total = 0
	for bag in [hotbar, main]:
		for s in bag:
			if s != null and s.item_id == item_id:
				total += s.count
	return total


func has(item_id: String, amount: int) -> bool:
	return count_of(item_id) >= amount


func remove(item_id: String, amount: int) -> bool:
	if count_of(item_id) < amount:
		return false
	for bag in [hotbar, main]:
		for i in range(bag.size()):
			var s = bag[i]
			if s != null and s.item_id == item_id:
				var take = mini(s.count, amount)
				s.count -= take
				amount -= take
				if s.count <= 0:
					bag[i] = null
				if amount <= 0:
					return true
	return amount <= 0


func consume_held(n: int = 1) -> bool:
	var s = hotbar[selected]
	if s == null:
		return false
	s.count -= n
	if s.count <= 0:
		hotbar[selected] = null
	return true


func to_data() -> Dictionary:
	return {"hotbar": _bag_data(hotbar), "main": _bag_data(main),
		"armor": _bag_data(armor), "selected": selected}


func _bag_data(bag: Array) -> Array:
	var out: Array = []
	for s in bag:
		if s == null:
			out.append(null)
		else:
			out.append({"id": s.item_id, "count": s.count, "dur": s.durability})
	return out


func from_data(data: Dictionary) -> void:
	selected = int(data.get("selected", 0))
	_load_bag(hotbar, data.get("hotbar", []))
	_load_bag(main, data.get("main", []))
	_load_bag(armor, data.get("armor", []))


func _load_bag(bag: Array, arr: Array) -> void:
	for i in range(bag.size()):
		bag[i] = null
		if i < arr.size() and arr[i] != null:
			var d = arr[i]
			var st = ItemStack.new(d["id"], int(d["count"]))
			st.durability = int(d.get("dur", -1))
			bag[i] = st
