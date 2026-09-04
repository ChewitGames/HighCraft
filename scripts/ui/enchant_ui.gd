class_name EnchantUI
extends CanvasLayer
## Enchanting table: item + lapis via GameUI cursor (or hotbar fallback).

signal closed

var player: Node = null
var game_ui: Node = null  # GameUI — holds _cursor
var _panel: Panel
var _slot_item: Panel
var _slot_lapis: Panel
var _item_stack = null
var _lapis_count: int = 0
var _offers: Array = []
var _offer_btns: Array = []
var _label: Label
var _item_count_lbl: Label
var _lapis_count_lbl: Label


func setup(p_player: Node, p_ui: Node = null) -> void:
	player = p_player
	game_ui = p_ui
	layer = 80
	_build()
	_refresh()


func _build() -> void:
	_panel = Panel.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.1, 0.18, 0.96)
	st.border_color = Color(0.45, 0.35, 0.7)
	st.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", st)
	_panel.custom_minimum_size = Vector2(440, 360)
	_panel.position = Vector2(200, 100)
	add_child(_panel)

	var v = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_top = 12
	v.offset_right = -12
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)

	var title = Label.new()
	title.text = "Enchanting Table"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	v.add_child(title)

	var hint = Label.new()
	hint.text = "Click slots with an item on your cursor (or selected hotbar)."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	v.add_child(row)

	_slot_item = _make_slot("Item")
	_slot_lapis = _make_slot("Lapis")
	row.add_child(_slot_item)
	row.add_child(_slot_lapis)

	_item_count_lbl = _slot_item.get_node("Count") as Label
	_lapis_count_lbl = _slot_lapis.get_node("Count") as Label

	_label = Label.new()
	_label.text = "Place an item and Lapis Lazuli"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_label)

	for i in range(3):
		var b = Button.new()
		b.text = "—"
		b.custom_minimum_size = Vector2(380, 36)
		b.pressed.connect(_on_offer.bind(i))
		v.add_child(b)
		_offer_btns.append(b)

	var close = Button.new()
	close.text = "Close"
	close.pressed.connect(_close)
	v.add_child(close)

	_slot_item.gui_input.connect(_on_item_slot)
	_slot_lapis.gui_input.connect(_on_lapis_slot)


func _make_slot(hint: String) -> Panel:
	var p = Panel.new()
	p.custom_minimum_size = Vector2(64, 64)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.2, 0.2, 0.25)
	s.set_border_width_all(2)
	s.border_color = Color(0.5, 0.45, 0.3)
	p.add_theme_stylebox_override("panel", s)
	var l = Label.new()
	l.name = "Hint"
	l.text = hint
	l.add_theme_font_size_override("font_size", 10)
	l.position = Vector2(4, 2)
	p.add_child(l)
	var ic = TextureRect.new()
	ic.name = "Icon"
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(8, 8)
	ic.size = Vector2(48, 48)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(ic)
	var c = Label.new()
	c.name = "Count"
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.position = Vector2(4, 44)
	c.size = Vector2(56, 16)
	c.add_theme_font_size_override("font_size", 12)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(c)
	return p


func _get_cursor_stack():
	# Prefer GameUI mouse cursor (what the player actually holds in UI)
	if game_ui != null and "_cursor" in game_ui and game_ui._cursor != null:
		return game_ui._cursor
	if player != null and player.inventory != null:
		return player.inventory.held()
	return null


func _set_cursor_stack(stack) -> void:
	if game_ui != null and "_cursor" in game_ui:
		game_ui._cursor = stack
		if game_ui.has_method("_refresh_cursor"):
			game_ui._refresh_cursor()
		return
	# hotbar fallback: only clear/replace selected
	if player != null and player.inventory != null:
		if stack == null:
			player.inventory.hotbar[player.inventory.selected] = null
		else:
			player.inventory.hotbar[player.inventory.selected] = stack


func _consume_cursor(n: int = 1) -> void:
	var c = _get_cursor_stack()
	if c == null:
		return
	c.count -= n
	if c.count <= 0:
		_set_cursor_stack(null)
	else:
		_set_cursor_stack(c)


func _is_lapis(id: String) -> bool:
	var s = id.to_lower()
	return s == "lapis_lazuli" or s == "lapis" or s == "lapis_lazuli_block" or s.ends_with("lapis")


func _on_item_slot(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var held = _get_cursor_stack()
	if _item_stack == null and held != null and not _is_lapis(str(held.item_id)):
		# Take one (or whole stack for tools)
		_item_stack = ItemStack.new(held.item_id, 1)
		if "enchantments" in held and held.enchantments is Dictionary:
			_item_stack.enchantments = held.enchantments.duplicate()
		if "durability" in held:
			_item_stack.durability = held.durability
		_consume_cursor(1)
		_refresh()
	elif _item_stack != null:
		# Return item to cursor/inventory
		if held == null:
			_set_cursor_stack(_item_stack)
		elif player and player.inventory:
			player.inventory.add(_item_stack.item_id, _item_stack.count)
		_item_stack = null
		_refresh()


func _on_lapis_slot(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var held = _get_cursor_stack()
	if held != null and _is_lapis(str(held.item_id)):
		var take = mini(held.count, 64 - _lapis_count)
		if take <= 0:
			return
		_lapis_count += take
		_consume_cursor(take)
		_refresh()
	elif held == null and _lapis_count > 0:
		# Pick lapis back onto cursor
		_set_cursor_stack(ItemStack.new("lapis_lazuli", _lapis_count))
		_lapis_count = 0
		_refresh()


func _refresh() -> void:
	# Icons
	var icon_i = _slot_item.get_node_or_null("Icon") as TextureRect
	var icon_l = _slot_lapis.get_node_or_null("Icon") as TextureRect
	if icon_i:
		if _item_stack != null:
			icon_i.texture = Textures.get_texture(_item_stack.item_id)
			icon_i.visible = true
		else:
			icon_i.texture = null
			icon_i.visible = false
	if icon_l:
		if _lapis_count > 0:
			icon_l.texture = Textures.get_texture("lapis_lazuli")
			icon_l.visible = true
		else:
			icon_l.texture = null
			icon_l.visible = false
	if _item_count_lbl:
		_item_count_lbl.text = "" if _item_stack == null else str(_item_stack.count)
	if _lapis_count_lbl:
		_lapis_count_lbl.text = "" if _lapis_count <= 0 else str(_lapis_count)

	_offers.clear()
	if _item_stack == null:
		_label.text = "Place an item and Lapis Lazuli"
		for b in _offer_btns:
			b.text = "—"
			b.disabled = true
		return

	var pool: Array = []
	if Registry.enchantments.size() > 0:
		for eid in Registry.enchantments.keys():
			pool.append(eid)
	else:
		pool = ["sharpness", "protection", "efficiency", "unbreaking"]
	pool.shuffle()
	for i in range(mini(3, pool.size())):
		var eid = pool[i]
		var max_l = 1
		if Registry.enchantments.has(eid):
			max_l = int(Registry.enchantments[eid].get("max_level", 1))
		var lvl = randi_range(1, maxi(1, max_l))
		var cost = lvl + i
		_offers.append({"id": eid, "level": lvl, "cost": cost})
	for i in range(3):
		if i < _offers.size():
			var o = _offers[i]
			_offer_btns[i].text = "%s %d  (needs %d Lapis)" % [str(o.id).capitalize(), o.level, o.cost]
			_offer_btns[i].disabled = _lapis_count < int(o.cost)
		else:
			_offer_btns[i].text = "—"
			_offer_btns[i].disabled = true
	_label.text = "Lapis: %d" % _lapis_count


func _on_offer(i: int) -> void:
	if i < 0 or i >= _offers.size() or _item_stack == null:
		return
	var o = _offers[i]
	if _lapis_count < int(o.cost):
		return
	_lapis_count -= int(o.cost)
	if not ("enchantments" in _item_stack) or _item_stack.enchantments == null:
		_item_stack.enchantments = {}
	_item_stack.enchantments[str(o.id)] = int(o.level)
	# Give enchanted item to cursor or inventory
	var held = _get_cursor_stack()
	if held == null:
		_set_cursor_stack(_item_stack)
	elif player and player.inventory:
		player.inventory.add(_item_stack.item_id, 1)
	_item_stack = null
	_refresh()
	if has_node("/root/Audio") or true:
		Audio.play("ui_click")


func _close() -> void:
	if _item_stack != null:
		var held = _get_cursor_stack()
		if held == null:
			_set_cursor_stack(_item_stack)
		elif player and player.inventory:
			player.inventory.add(_item_stack.item_id, _item_stack.count)
		_item_stack = null
	if _lapis_count > 0 and player and player.inventory:
		player.inventory.add("lapis_lazuli", _lapis_count)
		_lapis_count = 0
	closed.emit()
	queue_free()
