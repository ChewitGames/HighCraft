class_name GameUI
extends CanvasLayer
var _pause_resume_btn: Button
var _coords_visible: bool = false
var _coords_label: Label
var _dispenser_panel: Panel
var _dispenser_widgets: Array = []
var _active_dispenser = null
var _dispenser_cell: Vector3i = Vector3i.ZERO
var _chest_panel: Panel
var _chest_widgets: Array = []
var _active_chest: Array = [] # 27 slots shared with game.chests
var _chest_cell: Vector3i = Vector3i.ZERO
# === CONTROLLER UI ===
var _focus_bag: String = "hotbar" # "hotbar", "main", "armor", "craft", "furnace", "anvil", "dispenser", "chest", "creative"
var _focus_index: int = 0
var _controller_nav_cooldown: float = 0.0
const CONTROLLER_NAV_DELAY = 0.18
var _focus_cursor: Control = null # gelber Fokus-Rahmen (Controller)
var _controller_focus_kind: String = "slot"
var _controller_focus_button: BaseButton = null
# HighCraft HUD + inventory/crafting/furnace screens.
# HUD (always): hotbar, hearts/hunger/armor bars, crosshair.
# Inventory (E): armor + main + hotbar + a 2x2 crafting grid.
# Crafting table (right-click block): 3x3 crafting grid.
# Furnace (right-click block): input/fuel/output + progress.
# Click a slot to pick up / place / swap the cursor stack.
var _chat_history: Array = [] # Strings
var _chat_history_box: VBoxContainer
var _chat_history_max: int = 12
var _chat_line_timers: Array = [] # optional: Ausblenden
var game # ← NEU
var _anvil_panel: Panel
var _anvil_input1: Dictionary
var _anvil_input2: Dictionary
var _anvil_result: Dictionary
var _anvil_text_edit: LineEdit
var _enchant_panel: Panel
var _enchant_item: Dictionary = {}   # slot widget + item
var _enchant_lapis: Dictionary = {}
var _enchant_offers: Array = []
var _enchant_offer_btns: Array = []
var _enchant_label: Label
var _hovered_slot: Dictionary = {} # aktuell gehovter Slot
const SLOT = 50
# Split-screen: scale full-size UI into each player's viewport
var _ui_scale: float = 1.0
var _is_split: bool = false
var _split_index: int = 0
var _input_device_index: int = 0
var _split_rect: Rect2 = Rect2()
const ARMOR_SLOT_NAMES = ["helmet", "chestplate", "leggings", "boots"]
var player
var interactor
var _mode: String = "closed"
var _input_device: String = "mouse" # "mouse" oder "controller" – wird laufend erkannt
var _hotbar_slots: Array = []
var _hotbar_name_label: Label
var _hotbar_name_last_key: String = ""
var _hotbar_name_timer: float = 0.0
var _hearts: Array = []
var _hunger: Array = []
var _armor_bar: Array = []
var _air_bar: Array = []
var _air_row: HBoxContainer
var _stats_box: VBoxContainer
var _panel: Panel
var _bag_widgets: Array = [] # [{w, bag, index}]
var _craft_container: GridContainer
var _craft_cells: Array = [] # ItemStack or null, len = size*size
var _craft_widgets: Array = []
var _craft_size: int = 2
var _craft_result = null
var _result_widget: Dictionary
var _furnace_box: VBoxContainer
var _furnace_widgets: Dictionary = {}
var _active_furnace = null
var _cursor = null
var _cursor_icon: TextureRect
var _content: VBoxContainer
var _trade_panel: Panel
var _trade_villager
var _info: Label
var _pause_panel: Panel
var _pause_mode_btn: Button
var _pause_diff_btn: Button
var _chat_edit: LineEdit
var _chat_msg: Label
var _tooltip_label: Label
var _creative_container: VBoxContainer
var _creative_scroll: ScrollContainer
var _creative_filter: String = ""
# Skin / Avatar selector controller list
var _skin_buttons: Array = []
var _skin_focus_idx: int = 0
var _skin_panel: Panel = null
var _command_block_panel: Panel
var _command_block_edit: LineEdit
var _command_block_cell: Vector3i
var _command_block_texts: Dictionary = {}
var _creative_search: LineEdit
var _creative_grid: GridContainer
var _creative_items: Array = [] # alle Items die aktuell angezeigt werden
# On-screen keyboard (shared OnScreenKeyboard — OS VK often missing on desktop)
var _osk: OnScreenKeyboard = null
var _osk_open: bool = false
var _osk_ignore_focus: bool = false
var _hud_refresh_t: float = 0.0
var _inventory_refresh_t: float = 0.0

func _is_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
func _is_right_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
func _handle_right_click(arr: Array, index: int) -> void:
	var s = arr[index]

	if _cursor == null:
		if s != null and s.count > 1:
			var half = s.count / 2
			_cursor = ItemStack.new(s.item_id, half)
			s.count -= half
			if s.count <= 0:
				arr[index] = null
		elif s != null and s.count == 1:
			_cursor = s
			arr[index] = null
	else:
		if s == null:
			arr[index] = ItemStack.new(_cursor.item_id, 1)
			_cursor.count -= 1
			if _cursor.count <= 0:
				_cursor = null
		elif s.stackable_with(_cursor) and s.count < s.max_stack():
			s.count += 1
			_cursor.count -= 1
			if _cursor.count <= 0:
				_cursor = null
			
func _build_cursor() -> void:
	if _cursor_icon != null:
		return
	_cursor_icon = TextureRect.new()
	_cursor_icon.size = Vector2(SLOT, SLOT)
	_cursor_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cursor_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_icon.z_index = 300
	_cursor_icon.z_as_relative = false
	_cursor_icon.visible = false
	add_child(_cursor_icon)
func setup_split(p_player, p_interactor, rect: Rect2 = Rect2(), split_index: int = 0) -> void:
	# Split-Screen: UI lives inside this player's SubViewport. Full-screen
	# inventory (1100x620) must be scaled down so it fits the half/quarter screen.
	_is_split = true
	_split_index = split_index
	_input_device_index = split_index
	_split_rect = rect
	if p_player != null:
		if "split_index" in p_player:
			p_player.split_index = split_index
		p_player.set_meta("split_index", split_index)
	var ref := Vector2(1920.0, 1080.0)
	if rect.size.x > 32.0 and rect.size.y > 32.0:
		# Fit design UI into this pane; slight boost so HUD stays readable
		_ui_scale = clampf(minf(rect.size.x / ref.x, rect.size.y / ref.y) * 1.2, 0.42, 0.92)
	else:
		_ui_scale = 0.55
	setup(p_player, p_interactor)
	call_deferred("_apply_split_ui_scale")


func _apply_split_ui_scale() -> void:
	if not _is_split:
		return
	var s := _ui_scale
	# Uniform scale on every root Control — pivot from anchors keeps HUD/panels in place
	for c in get_children():
		if c is Control:
			_scale_split_control(c as Control, s)


func _scale_split_control(ctrl: Control, s: float) -> void:
	var sz: Vector2 = ctrl.size
	if sz.x < 2.0 or sz.y < 2.0:
		sz = ctrl.custom_minimum_size
	if sz.x < 2.0:
		sz = Vector2(120, 40)
	# Pivot from anchors so bottom-HUD stays bottom, center panels stay centered
	var ax := (ctrl.anchor_left + ctrl.anchor_right) * 0.5
	var ay := (ctrl.anchor_top + ctrl.anchor_bottom) * 0.5
	ctrl.pivot_offset = Vector2(sz.x * ax, sz.y * ay)
	ctrl.scale = Vector2(s, s)


func _split_size(base: Vector2) -> Vector2:
	if _is_split:
		return base * _ui_scale
	return base

func _register_split_child(ctrl: Control) -> void:
	if _is_split and ctrl != null and is_instance_valid(ctrl):
		_scale_split_control(ctrl, _ui_scale)


## Public for BlockInteractor
var is_split: bool:
	get:
		return _is_split


func _joy_device() -> int:
	# Same mapping as Player / BlockInteractor: split slot == joypad index
	return _input_device_index if _is_split else 0


func _event_for_this_player(event: InputEvent) -> bool:
	# Solo: accept everything. Split: only this player's device.
	if not _is_split:
		return true
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return int(event.device) == _joy_device()
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		# Keyboard + mouse only drive player 0
		return _split_index <= 0
	return false


func _set_ui_mouse_mode(visible: bool) -> void:
	# Mouse mode is process-global — only P1 (or solo) may change it
	if _is_split and _split_index > 0:
		return
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED




func setup(p_player, p_interactor) -> void:
	player = p_player
	interactor = p_interactor
	set_process_input(true)
	set_process_unhandled_input(true)

	_build_stats()
	_build_hotbar()
	_build_crosshair()
	_create_tooltip()
	_build_panel()
	_build_cursor()
	_build_info()
	_build_coords_label()
	_build_pause()
	_build_chat()
	_build_effect_hud()
	
	if player != null and player.game_mode == GameSettings.GameMode.CREATIVE:
		if _creative_grid != null and _creative_grid.get_child_count() == 0:
			_build_creative_inventory()
		if _creative_container != null:
			_creative_container.visible = true
			
	print("[UI setup] player=", player, " interactor=", interactor)
	
	
	if Multiplayer != null and not Multiplayer.chat_received.is_connected(_on_multiplayer_chat):
		Multiplayer.chat_received.connect(_on_multiplayer_chat)
		
		
		
		

func _on_multiplayer_chat(player_num: int, msg: String) -> void:
	_show_chat_line(player_num, msg)


func _broadcast_chat(msg: String) -> void:
	var num = _player_number()
	if Multiplayer != null and Multiplayer.has_method("send_chat"):
		Multiplayer.send_chat(num, msg)
	else:
		_show_chat_line(num, msg)


func _player_number() -> int:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return 1
	return multiplayer.get_unique_id()


func _show_chat_line(player_num: int, msg: String) -> void:
	_push_chat_history("Player %d: %s" % [player_num, msg])


func _push_chat_history(line: String) -> void:
	if _chat_history_box == null:
		_build_chat()
	if _chat_history_box == null:
		return

	_chat_history.append(line)
	while _chat_history.size() > _chat_history_max:
		_chat_history.pop_front()

	for c in _chat_history_box.get_children():
		c.queue_free()

	for entry in _chat_history:
		var lbl = Label.new()
		lbl.text = entry
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chat_history_box.add_child(lbl)

	print("[Chat] ", line)
	
	
func _build_coords_label() -> void:
	if _coords_label != null:
		return
	_coords_label = Label.new()
	_coords_label.position = Vector2(16, 70)
	_coords_label.add_theme_font_size_override("font_size", 16)
	_coords_label.add_theme_color_override("font_color", Color(1, 1, 0.7))
	_coords_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_coords_label.add_theme_constant_override("outline_size", 4)
	_coords_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coords_label.visible = false
	add_child(_coords_label)


func _toggle_coords() -> void:
	_coords_visible = not _coords_visible
	if _coords_label == null:
		_build_coords_label()
	_coords_label.visible = _coords_visible
	if _coords_visible:
		_update_coords()
	Audio.play("click", -10.0)


func _copy_coords() -> void:
	if player == null:
		return
	var p = player.global_position
	var text = "%.1f %.1f %.1f" % [p.x, p.y, p.z]
	DisplayServer.clipboard_set(text)
	if _chat_msg != null:
		_chat_msg.text = "Copied: " + text
	print("[Coords] Copied: ", text)
	Audio.play("click", -10.0)


func _update_coords() -> void:
	if not _coords_visible or _coords_label == null or player == null:
		return
	var p = player.global_position
	var bx = floori(p.x)
	var by = floori(p.y)
	var bz = floori(p.z)
	_coords_label.text = "XYZ: %.1f / %.1f / %.1f Block: %d %d %d" % [
		p.x, p.y, p.z, bx, by, bz
	]
func _show_item_tooltip(item_id: String, mouse_pos: Vector2) -> void:
	if _tooltip_label == null:
		return
	var stack_ref = null
	
	if _cursor != null and _cursor.item_id == item_id:
		stack_ref = _cursor
	elif not _hovered_slot.is_empty():
		var arr = _bag(_hovered_slot["bag"])
		var idx = _hovered_slot.get("index", -1)
		if idx >= 0 and idx < arr.size():
			var s = arr[idx]
			if s != null and s.item_id == item_id:
				stack_ref = s
	
	var name = item_id
	if stack_ref != null and stack_ref.custom_name.strip_edges() != "":
		name = stack_ref.custom_name
	elif stack_ref == null:
		var item = Registry.get_item(item_id)
		if item != null:
			name = item.get("name", item_id)
	
	var extra_lines: PackedStringArray = []
	if stack_ref != null and not stack_ref.enchantments.is_empty():
		for n in stack_ref.get_enchantment_names():
			extra_lines.append(str(n))
	var it = Registry.get_item(item_id)
	if it != null and str(it.get("type", "")) == "potion":
		for eff in it.get("effects", []):
			var t = str(eff.get("type", "")).replace("_", " ").capitalize()
			var d = int(eff.get("duration", 0))
			var a = int(eff.get("amplifier", 0))
			extra_lines.append("%s %s (%ds)" % [t, Registry.roman_level(a + 1) if Registry.has_method("roman_level") else str(a + 1), d])
	if item_id.begins_with("enchanted_book_") and Registry.enchantments.has(item_id.replace("enchanted_book_", "")):
		var eid = item_id.replace("enchanted_book_", "")
		extra_lines.append(Registry.enchantment_display(eid, int(Registry.enchantments[eid].get("max_level", 1))))
	var count_text = ""
	if stack_ref != null and stack_ref.count > 1:
		count_text = " x" + str(stack_ref.count)
	var body = name + count_text
	if extra_lines.size() > 0:
		body += "\n" + "\n".join(extra_lines)
	_tooltip_label.add_theme_color_override("font_color", Color(0.78, 0.55, 1.0) if extra_lines.size() > 0 else Color(1, 1, 1))
	_tooltip_label.text = body
	_tooltip_label.position = mouse_pos + Vector2(16, -8)
	_tooltip_label.visible = true


func _hide_item_tooltip() -> void:
	if _tooltip_label == null:
		return
	_tooltip_label.visible = false


func _stack_for_tooltip(bag: String, idx: int):
	# Liefert den ItemStack (oder item_id für creative) für Tooltip-Zwecke.
	# _bag() kennt nur hotbar/main/armor als echte Arrays - craft/furnace/
	# anvil/dispenser/creative sind anders strukturiert (Dictionaries mit
	# "item"-Key bzw. eigene Widget-Listen), deshalb hier direkt auflösen.
	match bag:
		"hotbar":
			if player == null or player.inventory == null:
				return null
			var arr = player.inventory.hotbar
			return arr[idx] if idx >= 0 and idx < arr.size() else null
		"main":
			if player == null or player.inventory == null:
				return null
			var arr = player.inventory.main
			return arr[idx] if idx >= 0 and idx < arr.size() else null
		"armor":
			if player == null or player.inventory == null:
				return null
			var arr = player.inventory.armor
			return arr[idx] if idx >= 0 and idx < arr.size() else null
		"craft":
			return _craft_cells[idx] if idx >= 0 and idx < _craft_cells.size() else null
		"craft_result":
			return _result_widget.get("item")
		"furnace":
			if _active_furnace == null:
				return null
			var keys = ["input", "fuel", "output"]
			if idx < 0 or idx >= keys.size():
				return null
			return _active_furnace.get(keys[idx])
		"anvil":
			if idx == 0:
				return _anvil_input1.get("item")
			if idx == 1:
				return _anvil_input2.get("item")
			return _anvil_result.get("item") if _anvil_result.has("item") else null
		"dispenser":
			if idx < 0 or idx >= _dispenser_widgets.size():
				return null
			return _dispenser_widgets[idx].get("item")
		"chest":
			if idx < 0 or idx >= _active_chest.size():
				return null
			return _active_chest[idx]
		"creative":
			if _creative_grid != null and idx >= 0 and idx < _creative_grid.get_child_count():
				var ch = _creative_grid.get_child(idx)
				if ch is Control and ch.has_meta("item_id"):
					return str(ch.get_meta("item_id"))
			return _creative_items[idx] if idx >= 0 and idx < _creative_items.size() else null
	return null


func _update_controller_tooltip() -> void:
	# Zeigt Name + Anzahl des fokussierten Items an, auch ohne Maus -
	# nötig, da Controller-Navigation keine mouse_entered-Signale auslöst.
	if _controller_focus_kind != "slot" or _hovered_slot.is_empty():
		_hide_item_tooltip()
		return
	var bag = _hovered_slot.get("bag", "")
	var idx = _hovered_slot.get("index", -1)
	if bag == "":
		_hide_item_tooltip()
		return

	var panel = _get_focused_panel()
	var pos: Vector2
	if panel != null and is_instance_valid(panel):
		pos = panel.global_position + Vector2(panel.size.x, 0)
	else:
		pos = get_viewport().get_mouse_position()

	if bag == "creative":
		var item_id = _stack_for_tooltip(bag, idx)
		if item_id == null or item_id == "":
			_hide_item_tooltip()
			return
		_show_item_tooltip(item_id, pos)
		return

	var stack = _stack_for_tooltip(bag, idx)
	if stack == null:
		_hide_item_tooltip()
		return
	_show_item_tooltip(stack.item_id, pos)


func _build_pause() -> void:
	_focus_bag = "main"
	_focus_index = 0

	_hovered_slot = {
		"bag": _focus_bag,
		"index": _focus_index
	}
	_pause_panel = Panel.new()
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.custom_minimum_size = Vector2(340, 420)
	_pause_panel.position = -_pause_panel.custom_minimum_size / 2.0
	_pause_panel.visible = false
	add_child(_pause_panel)
	var vb = VBoxContainer.new()
	vb.position = Vector2(20, 16)
	vb.add_theme_constant_override("separation", 10)
	_pause_panel.add_child(vb)
	var title = Label.new()
	title.text = "Paused"
	vb.add_child(title)
	_pause_resume_btn = Button.new()
	_pause_resume_btn.text = "Resume"
	_pause_resume_btn.pressed.connect(_close_pause)
	vb.add_child(_pause_resume_btn)
	_pause_mode_btn = Button.new()
	_pause_mode_btn.pressed.connect(_cycle_mode)
	vb.add_child(_pause_mode_btn)
	_pause_diff_btn = Button.new()
	_pause_diff_btn.pressed.connect(_cycle_diff)
	vb.add_child(_pause_diff_btn)
	var save_btn = Button.new()
	save_btn.text = "Save World"
	save_btn.pressed.connect(_save_world)
	vb.add_child(save_btn)

	# === NEU: Avatar / Skin Button ===
	var skin_btn = Button.new()
	_focus_bag = "main"
	_focus_index = 0

	_hovered_slot = {
		"bag": _focus_bag,
		"index": _focus_index
	}

	_update_focus_visual()
	skin_btn.text = "Avatar / Skin"
	skin_btn.pressed.connect(func():
		_close_pause()
		open_skin_selector()
	)
	vb.add_child(skin_btn)

	var recipe_btn = Button.new()
	recipe_btn.text = "Recipe Book"
	recipe_btn.pressed.connect(func():
		_close_pause()
		open_recipe_book()
	)
	vb.add_child(recipe_btn)

	var ench_btn = Button.new()
	ench_btn.text = "Enchanting Guide"
	ench_btn.pressed.connect(func():
		_close_pause()
		open_enchant()
	)
	vb.add_child(ench_btn)

	var ach_btn = Button.new()
	ach_btn.text = "Achievements"
	ach_btn.pressed.connect(func():
		_close_pause()
		_show_achievements()
	)
	vb.add_child(ach_btn)

	var quit = Button.new()
	quit.text = "Leave Player" if _is_split else ("Leave Server" if _online_session_active() else "Exit to Menu")
	quit.pressed.connect(_leave_current_player)
	vb.add_child(quit)
	_pause_resume_btn.focus_mode = Control.FOCUS_ALL
	_pause_mode_btn.focus_mode = Control.FOCUS_ALL
	_pause_diff_btn.focus_mode = Control.FOCUS_ALL
	save_btn.focus_mode = Control.FOCUS_ALL
	skin_btn.focus_mode = Control.FOCUS_ALL
	recipe_btn.focus_mode = Control.FOCUS_ALL
	ench_btn.focus_mode = Control.FOCUS_ALL
	ach_btn.focus_mode = Control.FOCUS_ALL
	quit.focus_mode = Control.FOCUS_ALL
func _save_world() -> void:
	if interactor != null and interactor.game != null:
		_chat_msg.text = "Saved." if interactor.game.save_now() else "Save failed."


func _online_session_active() -> bool:
	return multiplayer != null and multiplayer.multiplayer_peer != null


func _leave_current_player() -> void:
	_close_pause()
	var game_node = game
	if game_node == null and interactor != null:
		game_node = interactor.game
	if game_node != null and game_node.has_method("request_player_leave"):
		game_node.request_player_leave(player)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
func _build_chat() -> void:
	
	_focus_bag = "main"
	_focus_index = 0

	_hovered_slot = {
		"bag": _focus_bag,
		"index": _focus_index
	}

	_update_focus_visual()
	if _chat_msg == null:
		_chat_msg = Label.new()
		_chat_msg.position = Vector2(16, 40)
		_chat_msg.add_theme_font_size_override("font_size", 16)
		_chat_msg.add_theme_color_override("font_color", Color(1, 1, 1))
		_chat_msg.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_chat_msg.add_theme_constant_override("outline_size", 4)
		_chat_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_chat_msg)
		
	if _chat_history_box == null:
		_chat_history_box = VBoxContainer.new()
		_chat_history_box.position = Vector2(16, 40)
		_chat_history_box.custom_minimum_size = Vector2(600, 280)
		_chat_history_box.add_theme_constant_override("separation", 2)
		_chat_history_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_chat_history_box)

	if _chat_edit == null:
		_chat_edit = LineEdit.new()
		_chat_edit.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_chat_edit.offset_left = 16
		_chat_edit.offset_right = -16
		_chat_edit.offset_top = -80
		_chat_edit.offset_bottom = -40
		_chat_edit.placeholder_text = "Message or /command …"
		_chat_edit.visible = false

		# Sichtbarer Text + dunkler Hintergrund
		_chat_edit.add_theme_font_size_override("font_size", 18)
		_chat_edit.add_theme_color_override("font_color", Color(1, 1, 1))
		_chat_edit.add_theme_color_override("font_placeholder_color", Color(0.6, 0.6, 0.6))
		_chat_edit.add_theme_color_override("caret_color", Color(1, 1, 1))

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.08, 0.1, 0.92)
		style.border_color = Color(0.5, 0.5, 0.55)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		_chat_edit.add_theme_stylebox_override("normal", style)
		_chat_edit.add_theme_stylebox_override("focus", style)

		_chat_edit.text_submitted.connect(_on_chat_submit)
		add_child(_chat_edit)
func _build_info() -> void:
	if _info != null:
		return
	_info = Label.new()
	_info.position = Vector2(16, 12)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info)
# ---------------------------------------------------------------- widgets
func _make_slot() -> Dictionary:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(SLOT, SLOT)

	var icon = TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)

	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	var dura = ColorRect.new()
	dura.position = Vector2(3, SLOT - 7)
	dura.size = Vector2(SLOT - 6, 4)
	dura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dura.visible = false
	panel.add_child(dura)

	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(1, 1, 1, 0.28)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	panel.add_child(overlay)

	return {"panel": panel, "icon": icon, "label": label, "dura": dura, "overlay": overlay}
func _make_bar(count: int, parent: Control) -> Array:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)

	var cells: Array = []
	for i in range(count):
		var r = ColorRect.new()
		r.custom_minimum_size = Vector2(16, 16)
		row.add_child(r)
		cells.append(r)

	return cells
func _build_stats() -> void:
	_stats_box = VBoxContainer.new()
	_stats_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_stats_box.position = Vector2(20, -150)
	add_child(_stats_box)
	_hearts = _make_bar(10, _stats_box)
	_hunger = _make_bar(10, _stats_box)
	_armor_bar = _make_bar(10, _stats_box)
	_air_row = HBoxContainer.new()
	_air_row.add_theme_constant_override("separation", 2)
	_stats_box.add_child(_air_row)
	var air_label := Label.new()
	air_label.text = "AIR"
	air_label.custom_minimum_size = Vector2(34, 16)
	air_label.add_theme_font_size_override("font_size", 11)
	_air_row.add_child(air_label)
	for i in range(10):
		var bubble := ColorRect.new()
		bubble.custom_minimum_size = Vector2(14, 14)
		_air_row.add_child(bubble)
		_air_bar.append(bubble)
	_air_row.visible = false
func _build_hotbar() -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.position = Vector2(-(SLOT * 9 + 32) / 2.0, -64)
	add_child(row)
	for i in range(9):
		var s = _make_slot()
		row.add_child(s["panel"])
		_hotbar_slots.append(s)

	_hotbar_name_label = Label.new()
	_hotbar_name_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar_name_label.position = Vector2(-140, -64 - SLOT - 26)
	_hotbar_name_label.custom_minimum_size = Vector2(280, 22)
	_hotbar_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hotbar_name_label.add_theme_font_size_override("font_size", 16)
	_hotbar_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hotbar_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_hotbar_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_hotbar_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotbar_name_label.modulate = Color(1, 1, 1, 0)
	add_child(_hotbar_name_label)
	_hotbar_name_last_key = ""
	_hotbar_name_timer = 0.0
func _build_crosshair() -> void:
	var c = Label.new()
	c.text = "+"
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
func _build_panel() -> void:
	_focus_bag = "main"
	_focus_index = 0

	_hovered_slot = {
		"bag": _focus_bag,
		"index": _focus_index
	}

	_update_focus_visual()
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(1100, 620)
	_panel.position = -_panel.custom_minimum_size / 2.0
	_panel.visible = false
	add_child(_panel)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	margin.add_child(_content)

	# === NEUES LAYOUT: Creative links + Normales Inventar rechts ===
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 30)
	_content.add_child(main_hbox)

	# --- CREATIVE INVENTORY (links) ---
	_creative_container = VBoxContainer.new()
	_creative_container.visible = false
	main_hbox.add_child(_creative_container)

	var creative_title = Label.new()
	creative_title.text = "Creative Items"
	creative_title.add_theme_font_size_override("font_size", 18)
	_creative_container.add_child(creative_title)

	_creative_search = LineEdit.new()
	_creative_search.placeholder_text = "Search... (controller: press Select)"
	_creative_search.text_changed.connect(_filter_creative_items)
	_creative_search.focus_entered.connect(func():
		if not _osk_ignore_focus:
			_show_virtual_keyboard_if_needed(_creative_search)
	)
	_creative_search.focus_exited.connect(func():
		if not _osk_open and not _osk_ignore_focus:
			DisplayServer.virtual_keyboard_hide()
	)
	_creative_container.add_child(_creative_search)

	var creative_scroll = ScrollContainer.new()
	creative_scroll.custom_minimum_size = Vector2(380, 420)
	_creative_container.add_child(creative_scroll)
	_creative_scroll = creative_scroll

	_creative_grid = GridContainer.new()
	_creative_grid.columns = 7
	creative_scroll.add_child(_creative_grid)

	# --- NORMALES INVENTAR (rechts) ---
	var normal_vbox = VBoxContainer.new()
	main_hbox.add_child(normal_vbox)

	# Top: Armor + Crafting/Furnace
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)

	var armor_box = VBoxContainer.new()
	for i in range(4):
		var sa = _make_slot()
		armor_box.add_child(sa["panel"])
		_register_bag_slot(sa, "armor", i)
	top.add_child(armor_box)

	_craft_container = GridContainer.new()
	top.add_child(_craft_container)

	_furnace_box = VBoxContainer.new()
	top.add_child(_furnace_box)

	normal_vbox.add_child(top)

	# Main Inventory Grid (27 Slots)
	var grid = GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for i in range(27):
		var s = _make_slot()
		grid.add_child(s["panel"])
		_register_bag_slot(s, "main", i)
	normal_vbox.add_child(grid)

	# Hotbar
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	for i in range(9):
		var s2 = _make_slot()
		hb.add_child(s2["panel"])
		_register_bag_slot(s2, "hotbar", i)
	normal_vbox.add_child(hb)
	
func _build_creative_inventory() -> void:
	if _creative_grid == null:
		return

	# Alte Slots entfernen
	for child in _creative_grid.get_children():
		child.queue_free()
	_creative_items.clear()

	var add_item = func(item_id: String):
		_creative_items.append(item_id)
		var slot = _make_slot()
		slot["panel"].set_meta("item_id", item_id)
		slot["panel"].set_meta("creative_index", _creative_items.size() - 1)
		slot["panel"].mouse_entered.connect(func():
			_show_item_tooltip(item_id, get_viewport().get_mouse_position())
		)
		slot["panel"].mouse_exited.connect(_hide_item_tooltip)
		slot["panel"].gui_input.connect(_on_creative_slot_input.bind(item_id))
		_creative_grid.add_child(slot["panel"])
		_refresh_slot(slot, ItemStack.new(item_id, 64))

	# === 1. Alle BLÖCKE ===
	for block_id in Registry.blocks.keys():
		add_item.call(block_id)

	# === 2. Alle ITEMS ===
	for item_id in Registry.items.keys():
		add_item.call(item_id)

	# === 3. Enchantments (aus enchantments.json) ===
	# Versucht verschiedene mögliche Speicherorte
	var ench_data = null
	if "enchantments" in Registry:
		ench_data = Registry.enchantments
	elif has_node("/root/Enchantments"):
		ench_data = get_node("/root/Enchantments").get("data")

	if ench_data != null:
		for ench_id in ench_data.keys():
			add_item.call("enchanted_book_" + str(ench_id))

	# === 4. Potions (aus potions.json) ===
	var pot_data = null
	if "potions" in Registry:
		pot_data = Registry.potions
	elif has_node("/root/Potions"):
		pot_data = get_node("/root/Potions").get("data")

	if pot_data != null:
		for pot_id in pot_data.keys():
			add_item.call(pot_id)

func _first_creative_match_index() -> int:
	# First item index that matches the current search filter (never assume 0 = stone)
	for i in range(_creative_items.size()):
		var item_id: String = str(_creative_items[i])
		if _creative_filter == "" or item_id.to_lower().contains(_creative_filter):
			return i
	return 0


func _creative_index_matches(index: int) -> bool:
	if index < 0 or index >= _creative_items.size():
		return false
	var item_id: String = str(_creative_items[index])
	return _creative_filter == "" or item_id.to_lower().contains(_creative_filter)


func _filter_creative_items(search_text: String) -> void:
	if _creative_grid == null:
		return
	_creative_filter = search_text.strip_edges().to_lower()
	var children = _creative_grid.get_children()
	var first_visible: int = -1
	for i in range(children.size()):
		if i >= _creative_items.size():
			continue
		var item_id: String = str(_creative_items[i])
		var vis: bool = _creative_filter == "" or item_id.to_lower().contains(_creative_filter)
		children[i].visible = vis
		if vis and first_visible < 0:
			first_visible = i
	# Snap focus onto a real match (LB/RB and search must never leave index 0/stone)
	if first_visible >= 0 and _focus_bag == "creative":
		var still_ok: bool = _creative_index_matches(_focus_index)
		if not still_ok:
			_focus_index = first_visible
			_hovered_slot = {"bag": "creative", "index": _focus_index}
		_update_focus_visual()
	elif first_visible >= 0 and _mode in ["inventory", "table"]:
		# Keep a pending correct index so zone-cycle into creative lands on a match
		if not _creative_index_matches(_focus_index):
			pass # only used when bag becomes creative
func _on_creative_slot_input(event: InputEvent, item_id: String) -> void:
	var is_left = _is_click(event)
	var is_right = _is_right_click(event)
	if is_left:
		if _cursor == null:
			_cursor = ItemStack.new(item_id, 64)
		elif _cursor.item_id == item_id:
			_cursor.count = min(_cursor.count + 64, _cursor.max_stack())
	elif is_right:
		if _cursor == null:
			_cursor = ItemStack.new(item_id, 1)
		elif _cursor.item_id == item_id and _cursor.count < _cursor.max_stack():
			_cursor.count += 1
				
				
func _update_anvil_result() -> void:
	if _anvil_result == null:
		return

	var input1 = _anvil_input1.get("item")
	var input2 = _anvil_input2.get("item")

	_anvil_result["item"] = null
	_anvil_result["icon"].texture = null
	_anvil_result["label"].text = ""

	if input1 == null:
		return

	var result_item = ItemStack.new(input1.item_id, input1.count)

	if input1.durability >= 0:
		result_item.durability = input1.durability

	result_item.enchantments = input1.enchantments.duplicate()

	if input1.custom_name.strip_edges() != "":
		result_item.custom_name = input1.custom_name

	if _anvil_text_edit and _anvil_text_edit.text.strip_edges() != "":
		result_item.custom_name = _anvil_text_edit.text.strip_edges()

	if input2 != null:
		for ench_id in input2.enchantments.keys():
			var lvl = input2.enchantments[ench_id]
			var existing = result_item.enchantments.get(ench_id, 0)
			result_item.enchantments[ench_id] = max(existing, lvl)

		if input1.item_id == input2.item_id and result_item.has_method("max_durability"):
			var max_dur = result_item.max_durability()
			result_item.durability = min(result_item.durability + int(max_dur * 0.4), max_dur)

	_anvil_result["item"] = result_item
	_anvil_result["icon"].texture = Textures.get_texture(result_item.item_id)
	_anvil_result["label"].text = result_item.custom_name if result_item.custom_name.strip_edges() != "" else ""

func _drop_hovered_item(drop_all: bool = false) -> void:
	if _hovered_slot.is_empty() or player == null:
		return

	var bag = _hovered_slot["bag"]
	var index = _hovered_slot["index"]
	var arr = _bag(bag)

	if index >= arr.size() or arr[index] == null:
		return

	var stack = arr[index]
	var drop_count = stack.count if drop_all else 1

	if interactor != null and interactor.game != null and player != null:
		var item_entity = preload("res://scenes/item_entity.tscn").instantiate()
		interactor.game.add_child(item_entity)
		item_entity.global_position = player.global_position + Vector3(0, 1.8, 0) + -player.global_transform.basis.z * 1.8
		if item_entity.has_method("setup"):
			item_entity.callv("setup", [stack.item_id, drop_count, player])

	stack.count -= drop_count
	if stack.count <= 0:
		arr[index] = null

	Audio.play("player_item_drop", -8.0)
	
func _register_bag_slot(widget: Dictionary, bag: String, index: int) -> void:
	_bag_widgets.append({"w": widget, "bag": bag, "index": index})
	widget["panel"].gui_input.connect(_on_bag_input.bind(bag, index))
	
	# Hover Tracking + Tooltip – nur bei Maus; Controller steuert Fokus separat
	widget["panel"].mouse_entered.connect(func():
		if _input_device == "controller":
			return
		_hovered_slot = {"bag": bag, "index": index}
		var arr = _bag(bag)
		if index < arr.size() and arr[index] != null:
			_show_item_tooltip(arr[index].item_id, get_viewport().get_mouse_position())
	)
	widget["panel"].mouse_exited.connect(func():
		if _input_device == "controller":
			return
		_hovered_slot = {}
		_hide_item_tooltip()
	)

func _create_tooltip() -> void:
	_tooltip_label = Label.new()
	_tooltip_label.visible = false
	_tooltip_label.z_index = 100
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_label.add_theme_font_size_override("font_size", 14)
	_tooltip_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_tooltip_label.add_theme_constant_override("shadow_offset_x", 1)
	_tooltip_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_tooltip_label)
	move_child(_tooltip_label, get_child_count() - 1)
	
	
func _get_focusable_slots() -> Array:
	# Controller-Fokus als echtes 2D-Layout. Jede Position kennt x/y, damit
	# D-Pad/Stick nicht einfach über ein flaches Array springt.
	var slots: Array = []

	match _mode:
		"inventory", "table":
			for i in range(4):
				slots.append({"bag": "armor", "index": i, "x": 0, "y": i})
			for i in range(_craft_cells.size()):
				var side = maxi(int(sqrt(float(_craft_cells.size()))), 1)
				slots.append({"bag": "craft", "index": i, "x": 2 + (i % side), "y": i / side})
			slots.append({"bag": "craft_result", "index": 0, "x": 5, "y": 0})
			for i in range(27):
				slots.append({"bag": "main", "index": i, "x": i % 9, "y": 4 + i / 9})
			for i in range(9):
				slots.append({"bag": "hotbar", "index": i, "x": i, "y": 7})
			if player != null and player.game_mode == GameSettings.GameMode.CREATIVE and _creative_grid != null:
				var creative_cols = maxi(_creative_grid.columns, 1)
				var visible_i = 0
				for ci in range(_creative_items.size()):
					var item_id: String = str(_creative_items[ci])
					var matches := _creative_filter == "" or item_id.to_lower().contains(_creative_filter)
					if not matches:
						continue
					# Sequential layout among matches only → search results fully navigable
					slots.append({
						"bag": "creative",
						"index": ci,
						"item_id": item_id,
						"x": 10 + (visible_i % creative_cols),
						"y": int(visible_i / creative_cols)
					})
					visible_i += 1

		"furnace":
			slots.append({"bag": "furnace", "index": 0, "x": 10, "y": 0})
			slots.append({"bag": "furnace", "index": 1, "x": 10, "y": 1})
			slots.append({"bag": "furnace", "index": 2, "x": 12, "y": 0})
			for i in range(27):
				slots.append({"bag": "main", "index": i, "x": i % 9, "y": 4 + i / 9})
			for i in range(9):
				slots.append({"bag": "hotbar", "index": i, "x": i, "y": 7})

		"anvil":
			slots.append({"bag": "anvil", "index": 0, "x": 10, "y": 0})
			slots.append({"bag": "anvil", "index": 1, "x": 11, "y": 0})
			slots.append({"bag": "anvil", "index": 2, "x": 12, "y": 0})
			var anvil_buttons = _get_anvil_buttons()
			for i in range(anvil_buttons.size()):
				slots.append({"kind": "button", "button": anvil_buttons[i], "x": 10 + i, "y": 2})
			for i in range(27):
				slots.append({"bag": "main", "index": i, "x": i % 9, "y": 4 + i / 9})
			for i in range(9):
				slots.append({"bag": "hotbar", "index": i, "x": i, "y": 7})

		"enchant":
			slots.append({"bag": "enchant", "index": 0, "x": 10, "y": 0})
			slots.append({"bag": "enchant", "index": 1, "x": 11, "y": 0})
			var ench_buttons = _get_enchant_buttons()
			for i in range(ench_buttons.size()):
				slots.append({"kind": "button", "button": ench_buttons[i], "x": 10 + i, "y": 2})
			for i in range(27):
				slots.append({"bag": "main", "index": i, "x": i % 9, "y": 4 + i / 9})
			for i in range(9):
				slots.append({"bag": "hotbar", "index": i, "x": i, "y": 7})

		"dispenser":
			for i in range(9):
				slots.append({"bag": "dispenser", "index": i, "x": 10 + (i % 3), "y": i / 3})
			var dispenser_buttons = _get_dispenser_buttons()
			for i in range(dispenser_buttons.size()):
				slots.append({"kind": "button", "button": dispenser_buttons[i], "x": 10 + i, "y": 4})
			for i in range(27):
				slots.append({"bag": "main", "index": i, "x": i % 9, "y": 4 + i / 9})
			for i in range(9):
				slots.append({"bag": "hotbar", "index": i, "x": i, "y": 7})

		"chest":
			for i in range(27):
				slots.append({"bag": "chest", "index": i, "x": 10 + (i % 9), "y": i / 9})
			for i in range(27):
				slots.append({"bag": "main", "index": i, "x": i % 9, "y": 4 + i / 9})
			for i in range(9):
				slots.append({"bag": "hotbar", "index": i, "x": i, "y": 7})

		"trade":
			var buttons = _get_trade_buttons()
			for i in range(buttons.size()):
				slots.append({"kind": "button", "button": buttons[i], "x": 0, "y": i})

		"command_block":
			if _command_block_panel != null and is_instance_valid(_command_block_panel):
				var cb_buttons: Array = []
				_collect_buttons(_command_block_panel, cb_buttons)
				for i in range(cb_buttons.size()):
					slots.append({"kind": "button", "button": cb_buttons[i], "x": i, "y": 0})

		_:
			for i in range(9):
				slots.append({"bag": "hotbar", "index": i, "x": i, "y": 0})

	return slots


func _get_trade_buttons() -> Array:
	var buttons: Array = []
	if _trade_panel == null or not is_instance_valid(_trade_panel):
		return buttons
	_collect_buttons(_trade_panel, buttons)
	return buttons


func _get_anvil_buttons() -> Array:
	var buttons: Array = []
	if _anvil_panel != null and is_instance_valid(_anvil_panel):
		_collect_buttons(_anvil_panel, buttons)
	return buttons


func _get_enchant_buttons() -> Array:
	var buttons: Array = []
	if _enchant_panel != null and is_instance_valid(_enchant_panel):
		_collect_buttons(_enchant_panel, buttons)
	return buttons


func _get_dispenser_buttons() -> Array:
	var buttons: Array = []
	if _dispenser_panel != null and is_instance_valid(_dispenser_panel):
		_collect_buttons(_dispenser_panel, buttons)
	return buttons


func _focus_target_matches(target: Dictionary) -> bool:
	if target.get("kind", "slot") == "button":
		return _controller_focus_kind == "button" and _controller_focus_button == target.get("button")
	return _controller_focus_kind == "slot" and target.get("bag", "") == _focus_bag and int(target.get("index", -1)) == _focus_index


func _move_focus(dx: int, dy: int) -> void:
	var targets = _get_focusable_slots()
	if targets.is_empty():
		return

	var current_index = 0
	for i in range(targets.size()):
		if _focus_target_matches(targets[i]):
			current_index = i
			break

	var current: Dictionary = targets[current_index]
	var cx = int(current.get("x", 0))
	var cy = int(current.get("y", 0))
	var candidates: Array = []

	for i in range(targets.size()):
		if i == current_index:
			continue
		var t: Dictionary = targets[i]
		var tx = int(t.get("x", 0))
		var ty = int(t.get("y", 0))
		var vx = tx - cx
		var vy = ty - cy

		if dx > 0 and vx <= 0:
			continue
		if dx < 0 and vx >= 0:
			continue
		if dy > 0 and vy <= 0:
			continue
		if dy < 0 and vy >= 0:
			continue

		var primary = abs(vx) if dx != 0 else abs(vy)
		var secondary = abs(vy) if dx != 0 else abs(vx)
		var same_axis = 0 if secondary == 0 else 1
		candidates.append([same_axis, primary, secondary, i])

	if candidates.is_empty():
		# Reaching the edge of one slot grid automatically moves to the next UI
		# zone. LB/RB remain optional shortcuts, never a requirement.
		_cycle_focus_zone(1 if dx > 0 or dy > 0 else -1)
		_position_focus_cursor()
		return
	else:
		candidates.sort_custom(func(a, b):
			if a[0] != b[0]:
				return a[0] < b[0]
			if a[1] != b[1]:
				return a[1] < b[1]
			if a[2] != b[2]:
				return a[2] < b[2]
			return a[3] < b[3]
		)
		current_index = candidates[0][3]

	var next: Dictionary = targets[current_index]
	if next.get("kind", "slot") == "button":
		_controller_focus_kind = "button"
		_controller_focus_button = next.get("button")
		if _controller_focus_button != null:
			_controller_focus_button.grab_focus()
		_update_focus_visual()
		return

	_controller_focus_kind = "slot"
	_controller_focus_button = null
	_focus_bag = next["bag"]
	_focus_index = int(next["index"])
	_hovered_slot = {"bag": _focus_bag, "index": _focus_index}
	_update_focus_visual()
	_position_focus_cursor()


func _ensure_focus_cursor() -> void:
	if _focus_cursor != null and is_instance_valid(_focus_cursor):
		return
	# Use a Panel with only a bright yellow border (no fill) so icons stay readable
	# – same visual language as the inventory slot self_modulate glow.
	_focus_cursor = Panel.new()
	_focus_cursor.size = Vector2(SLOT + 8, SLOT + 8)
	_focus_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_cursor.z_index = 250
	_focus_cursor.z_as_relative = false
	_focus_cursor.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(1.0, 0.92, 0.1, 1.0)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	_focus_cursor.add_theme_stylebox_override("panel", sb)
	add_child(_focus_cursor)
	move_child(_focus_cursor, get_child_count() - 1)


func _get_focused_panel() -> Control:
	if _controller_focus_kind == "button" and _controller_focus_button != null and is_instance_valid(_controller_focus_button):
		return _controller_focus_button
	match _focus_bag:
		"hotbar", "main", "armor":
			for entry in _bag_widgets:
				if entry["bag"] == _focus_bag and entry["index"] == _focus_index:
					return entry["w"]["panel"]
		"craft":
			if _focus_index >= 0 and _focus_index < _craft_widgets.size():
				return _craft_widgets[_focus_index]["panel"]
		"craft_result":
			if _result_widget.has("panel") and is_instance_valid(_result_widget["panel"]):
				return _result_widget["panel"]
		"furnace":
			var keys = ["input", "fuel", "output"]
			if _focus_index >= 0 and _focus_index < 3 and _furnace_widgets.has(keys[_focus_index]):
				return _furnace_widgets[keys[_focus_index]]["panel"]
		"anvil":
			if _focus_bag == "enchant":
				if _focus_index == 0 and _enchant_item is Dictionary and _enchant_item.has("panel"):
					return _enchant_item["panel"]
				if _focus_index == 1 and _enchant_lapis is Dictionary and _enchant_lapis.has("panel"):
					return _enchant_lapis["panel"]
			if _focus_index == 0 and _anvil_input1.has("panel"):
				return _anvil_input1["panel"]
			if _focus_index == 1 and _anvil_input2.has("panel"):
				return _anvil_input2["panel"]
			if _focus_index == 2 and _anvil_result.has("panel"):
				return _anvil_result["panel"]
		"dispenser":
			if _focus_index >= 0 and _focus_index < _dispenser_widgets.size():
				return _dispenser_widgets[_focus_index]["panel"]
		"chest":
			if _focus_index >= 0 and _focus_index < _chest_widgets.size():
				return _chest_widgets[_focus_index]["panel"]
		"creative":
			if _creative_grid != null and _focus_index >= 0 and _focus_index < _creative_grid.get_child_count():
				return _creative_grid.get_child(_focus_index)
	return null


func _position_focus_cursor() -> void:
	_ensure_focus_cursor()
	if _input_device != "controller" or _mode in ["closed", "pause", "chat"] or _controller_focus_kind == "button":
		_focus_cursor.visible = false
		return
	var panel = _get_focused_panel()
	if panel == null or not is_instance_valid(panel):
		_focus_cursor.visible = false
		return
	# Globale Position des Slot-Panels → CanvasLayer-Koordinaten
	var gp = panel.get_global_rect()
	_focus_cursor.global_position = gp.position - Vector2(3, 3)
	_focus_cursor.size = gp.size + Vector2(6, 6)
	_focus_cursor.visible = true
	_focus_cursor.z_index = 250
	_focus_cursor.move_to_front()
	# The separate border is the focus effect. Tinting the whole slot also tints
	# enchanted item glints and made them look as if they were behind the UI.


func _update_focus_visual() -> void:
	if _controller_focus_kind == "button" and _controller_focus_button != null and is_instance_valid(_controller_focus_button):
		_controller_focus_button.grab_focus()
	# Alle Slot-Panels zurücksetzen, dann fokussierten hervorheben
	# (auch im Chest-Modus: Inventar-Slots neben der Truhe)
	for entry in _bag_widgets:
		var w = entry["w"]
		var p = w["panel"]
		var focused = (entry["bag"] == _focus_bag and entry["index"] == _focus_index)
		p.self_modulate = Color(1.4, 1.4, 0.6) if focused else Color(1, 1, 1)
		if w.has("overlay") and w["overlay"] != null:
			w["overlay"].visible = focused
			w["overlay"].color = Color(1.0, 0.92, 0.15, 0.45) if focused else Color(1, 1, 1, 0.28)
		if focused:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.22, 0.22, 0.18, 0.95)
			sb.border_color = Color(1.0, 0.92, 0.12, 1.0)
			sb.set_border_width_all(3)
			p.add_theme_stylebox_override("panel", sb)
		else:
			p.remove_theme_stylebox_override("panel")

	# Craft-Slots
	for i in range(_craft_widgets.size()):
		var p = _craft_widgets[i]["panel"]
		if _focus_bag == "craft" and _focus_index == i:
			p.self_modulate = Color(1.4, 1.4, 0.6)
		else:
			p.self_modulate = Color(1, 1, 1)

	# Result
	if _result_widget.has("panel") and is_instance_valid(_result_widget["panel"]):
		if _focus_bag == "craft_result":
			_result_widget["panel"].self_modulate = Color(1.4, 1.4, 0.6)
		else:
			_result_widget["panel"].self_modulate = Color(1, 1, 1)

	# Furnace
	if not _furnace_widgets.is_empty():
		var keys = ["input", "fuel", "output"]
		for i in range(3):
			if _furnace_widgets.has(keys[i]):
				var p = _furnace_widgets[keys[i]]["panel"]
				if _focus_bag == "furnace" and _focus_index == i:
					p.self_modulate = Color(1.4, 1.4, 0.6)
				else:
					p.self_modulate = Color(1, 1, 1)

	# Anvil
	if _anvil_input1.has("panel"):
		_anvil_input1["panel"].self_modulate = Color(1.4, 1.4, 0.6) if (_focus_bag == "anvil" and _focus_index == 0) else Color(1, 1, 1)
	if _anvil_input2.has("panel"):
		_anvil_input2["panel"].self_modulate = Color(1.4, 1.4, 0.6) if (_focus_bag == "anvil" and _focus_index == 1) else Color(1, 1, 1)
	if _anvil_result.has("panel"):
		_anvil_result["panel"].self_modulate = Color(1.4, 1.4, 0.6) if (_focus_bag == "anvil" and _focus_index == 2) else Color(1, 1, 1)
	if _enchant_item is Dictionary and _enchant_item.has("panel"):
		_enchant_item["panel"].self_modulate = Color(1, 1, 1)
	if _enchant_lapis is Dictionary and _enchant_lapis.has("panel"):
		_enchant_lapis["panel"].self_modulate = Color(1, 1, 1)

	# Dispenser
	for i in range(_dispenser_widgets.size()):
		var p = _dispenser_widgets[i]["panel"]
		if _focus_bag == "dispenser" and _focus_index == i:
			p.self_modulate = Color(1.4, 1.4, 0.6)
		else:
			p.self_modulate = Color(1, 1, 1)

	# Chest – use slot overlay (same mechanism as selected hotbar) + yellow border
	for i in range(_chest_widgets.size()):
		var w = _chest_widgets[i]
		var p = w["panel"]
		var focused = (_focus_bag == "chest" and _focus_index == i)
		if w.has("overlay") and w["overlay"] != null:
			w["overlay"].visible = focused
			if focused:
				w["overlay"].color = Color(1.0, 0.92, 0.15, 0.45)
			else:
				w["overlay"].color = Color(1, 1, 1, 0.28)
		p.self_modulate = Color(1.4, 1.4, 0.6) if focused else Color(1, 1, 1)
		# Yellow border style on focused chest slot
		if focused:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.22, 0.22, 0.18, 0.95)
			sb.border_color = Color(1.0, 0.92, 0.12, 1.0)
			sb.set_border_width_all(3)
			p.add_theme_stylebox_override("panel", sb)
		else:
			p.remove_theme_stylebox_override("panel")

	# Creative
	if _creative_grid != null:
		for i in range(_creative_grid.get_child_count()):
			var child = _creative_grid.get_child(i)
			if child is CanvasItem:
				if _focus_bag == "creative" and _focus_index == i:
					child.self_modulate = Color(1.4, 1.4, 0.6)
				else:
					child.self_modulate = Color(1, 1, 1)
		if _focus_bag == "creative" and _creative_scroll != null and is_instance_valid(_creative_scroll):
			if _focus_index >= 0 and _focus_index < _creative_grid.get_child_count():
				var focused_child = _creative_grid.get_child(_focus_index)
				if focused_child is Control:
					_creative_scroll.ensure_control_visible(focused_child)

	_position_focus_cursor()
	_update_controller_tooltip()
# ---------------------------------------------------------------- open/close
func _unhandled_input(event: InputEvent) -> void:
	# Split-screen: ignore input that belongs to another player
	if not _event_for_this_player(event):
		return

	# ---------- Geräte-Erkennung ----------
	# Sobald echte Maus-/Tastatur-Eingabe kommt -> "mouse", sobald Controller-Eingabe kommt -> "controller".
	# Verhindert, dass Stick-Cursor und echte Maus sich gegenseitig ins Gehege kommen.
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		_input_device = "mouse"
	elif event is InputEventJoypadButton:
		_input_device = "controller"
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.35:
		_input_device = "controller"

	# ---------- Tastatur ----------
	if event is InputEventKey and event.pressed and not event.echo:
		var k = event.keycode

		if k == KEY_Q and _mode != "closed" and not _hovered_slot.is_empty():
			_drop_hovered_item(Input.is_key_pressed(KEY_CTRL))
			return

		if k == KEY_E:
			if _mode == "closed":
				open_inventory()
			elif _mode in ["inventory", "table", "furnace", "trade", "anvil", "dispenser", "chest", "enchant"]:
				_close()

		elif k == KEY_ESCAPE:
			if _mode == "closed":
				open_pause()
			elif _mode == "pause":
				_close_pause()
			elif _mode == "chat":
				_close_chat()
			elif _mode == "skin":
				_close_skin_selector(true)
			elif _mode == "avatar":
				pass
			elif _mode in ["inventory", "table", "furnace", "trade", "anvil", "dispenser", "chest", "enchant"]:
				_close()

		elif k == KEY_T:
			if _mode == "closed":
				open_chat()


		elif k == KEY_2 and event.ctrl_pressed:
			_toggle_coords()
		elif k == KEY_3 and event.ctrl_pressed:
			_copy_coords()

		return
		
		
		
	# ============================
	# CONTROLLER UI INPUT
	# ============================
	if not (event is InputEventJoypadMotion or event is InputEventJoypadButton):
		return
	if _input_device != "controller":
		return

	# --- On-screen keyboard owns controller input (handled in OnScreenKeyboard._input) ---
	if _osk_open:
		if get_viewport():
			get_viewport().set_input_as_handled()
		return

	# --- Stick-Navigation (Inventar-Slots + Pause + Skin) ---
	if event is InputEventJoypadMotion:
		if _controller_nav_cooldown <= 0.0:
			var ax: int = event.axis
			var val: float = event.axis_value
			if absf(val) > 0.5:
				if _mode == "pause":
					if HCPad.is_nav_axis_y(ax):
						_pause_focus_move(1 if val > 0.0 else -1)
						_controller_nav_cooldown = CONTROLLER_NAV_DELAY
						if get_viewport(): get_viewport().set_input_as_handled()
				elif _mode == "skin":
					if HCPad.is_nav_axis_y(ax):
						_skin_focus_move(1 if val > 0.0 else -1)
						_controller_nav_cooldown = CONTROLLER_NAV_DELAY
						if get_viewport(): get_viewport().set_input_as_handled()
				elif _mode == "avatar":
					# AvatarEditor handles its own input
					pass
				elif _mode in ["inventory", "table", "furnace", "anvil", "dispenser", "trade", "chest", "enchant"]:
					if HCPad.is_nav_axis_x(ax):
						_move_focus(1 if val > 0.0 else -1, 0)
						_controller_nav_cooldown = CONTROLLER_NAV_DELAY
						if get_viewport(): get_viewport().set_input_as_handled()
					elif HCPad.is_nav_axis_y(ax):
						_move_focus(0, 1 if val > 0.0 else -1)
						_controller_nav_cooldown = CONTROLLER_NAV_DELAY
						if get_viewport(): get_viewport().set_input_as_handled()
		return

	if not (event is InputEventJoypadButton and event.pressed):
		return

	var btn: int = event.button_index

	# --- Start / Options → Pause ---
	if HCPad.is_pause(btn):
		if _mode == "closed":
			open_pause()
		elif _mode == "pause":
			_close_pause()
		elif _mode == "chat":
			_close_chat()
		elif _mode == "skin":
			_close_skin_selector(true)
		elif _mode == "avatar":
			pass # editor handles B/close
		else:
			_close()
		if get_viewport(): get_viewport().set_input_as_handled()
		return

	# --- Select / Back → Chat, or Creative Search when inventory is open ---
	if HCPad.is_select(btn):
		if _mode == "closed":
			open_chat()
		elif _mode == "chat":
			if _osk_open:
				_close_osk(true)
			else:
				_close_chat()
		elif _mode in ["inventory", "table"] and _creative_search != null and _creative_container != null and _creative_container.visible:
			_show_virtual_keyboard_if_needed(_creative_search)
		elif _mode == "anvil" and _anvil_text_edit != null:
			_show_virtual_keyboard_if_needed(_anvil_text_edit)
		elif _mode == "command_block" and _command_block_edit != null:
			_show_virtual_keyboard_if_needed(_command_block_edit)
		if get_viewport(): get_viewport().set_input_as_handled()
		return

	# --- Y / Triangle → Inventar toggle / Craft-Result / text fields ---
	if HCPad.is_inventory(btn):
		if _mode == "closed":
			open_inventory()
		elif _mode in ["inventory", "table"] and _craft_result != null:
			var fake = InputEventMouseButton.new()
			fake.button_index = MOUSE_BUTTON_LEFT
			fake.pressed = true
			_on_result_input(fake)
		elif _mode == "anvil" and _anvil_text_edit != null:
			_show_virtual_keyboard_if_needed(_anvil_text_edit)
		elif _mode in ["inventory", "table", "furnace", "trade", "anvil", "dispenser", "chest"]:
			_close()
		if get_viewport(): get_viewport().set_input_as_handled()
		return

	# --- D-Pad (nur wenn UI offen) ---
	if _mode not in ["closed", "chat", "avatar"] and _controller_nav_cooldown <= 0.0:
		var dpad_dir = Vector2i.ZERO
		match btn:
			HCPad.BTN_DPAD_UP:
				dpad_dir = Vector2i(0, -1)
			HCPad.BTN_DPAD_DOWN:
				dpad_dir = Vector2i(0, 1)
			HCPad.BTN_DPAD_LEFT:
				dpad_dir = Vector2i(-1, 0)
			HCPad.BTN_DPAD_RIGHT:
				dpad_dir = Vector2i(1, 0)
		if dpad_dir != Vector2i.ZERO:
			if _mode == "pause":
				if dpad_dir.y != 0:
					_pause_focus_move(dpad_dir.y)
			elif _mode == "skin":
				if dpad_dir.y != 0:
					_skin_focus_move(dpad_dir.y)
			else:
				_move_focus(dpad_dir.x, dpad_dir.y)
			_controller_nav_cooldown = CONTROLLER_NAV_DELAY
			if get_viewport(): get_viewport().set_input_as_handled()
			return

	# --- A / Cross → bestätigen (nur UI) ---
	if HCPad.is_accept(btn):
		if _mode == "pause":
			_pause_activate_focused()
			if get_viewport(): get_viewport().set_input_as_handled()
			return
		if _mode == "skin":
			_skin_activate()
			if get_viewport(): get_viewport().set_input_as_handled()
			return
		if _mode == "chat":
			if _chat_edit != null:
				_on_chat_submit(_chat_edit.text)
			if get_viewport(): get_viewport().set_input_as_handled()
			return
		if _mode in ["inventory", "table", "furnace", "anvil", "dispenser", "trade", "command_block", "chest", "enchant"]:
			_controller_activate_slot(false)
			if get_viewport(): get_viewport().set_input_as_handled()
			return

	# --- B / Circle → schließen ---
	if HCPad.is_cancel(btn):
		if _mode == "pause":
			_close_pause()
			if get_viewport(): get_viewport().set_input_as_handled()
			return
		if _mode == "skin":
			_close_skin_selector(true)
			if get_viewport(): get_viewport().set_input_as_handled()
			return
		if _mode == "chat":
			_close_chat()
			if get_viewport(): get_viewport().set_input_as_handled()
			return
		if _mode == "avatar":
			return # editor handles B
		if _mode != "closed":
			_close()
			if get_viewport(): get_viewport().set_input_as_handled()
			return

	# --- X / Square → Rechtsklick auf Slot ---
	if HCPad.is_attack_button(btn):
		if _mode in ["inventory", "table", "furnace", "anvil", "dispenser", "chest", "enchant"]:
			_controller_activate_slot(true)
			get_viewport().set_input_as_handled()
			return

	# --- LB / L1 ---
	if HCPad.is_lb(btn):
		if _mode == "closed":
			# Hotbar prev — leave event free for interactor as well
			if player and player.inventory:
				player.inventory.selected = max(player.inventory.selected - 1, 0)
			return
		elif _mode != "pause" and _mode != "chat":
			_cycle_focus_zone(-1)
			if get_viewport():
				get_viewport().set_input_as_handled()
			return

	# --- RB / R1 ---
	# When closed: do NOT handle RB here — BlockInteractor uses RB/LT to place/open chest/trade
	if HCPad.is_rb(btn):
		if _mode == "closed":
			return # let interactor handle place / open station
		elif _mode != "pause" and _mode != "chat":
			_cycle_focus_zone(1)
			if get_viewport():
				get_viewport().set_input_as_handled()
			return


func _focus_zones_for_mode() -> Array:
	# Guaranteed zone order. Normal D-Pad/stick navigation changes zones at
	# grid edges; LB/RB merely provide an optional shortcut.
	match _mode:
		"inventory", "table":
			var z = ["main", "hotbar", "armor"]
			if player != null and player.game_mode == GameSettings.GameMode.CREATIVE and _creative_grid != null and _creative_grid.get_child_count() > 0:
				z.append("creative")
			return z
		"furnace":
			return ["furnace", "main", "hotbar"]
		"anvil":
			return ["anvil", "main", "hotbar"]
		"enchant":
			return ["enchant", "main", "hotbar"]
		"dispenser":
			return ["dispenser", "main", "hotbar"]
		"chest":
			return ["chest", "main", "hotbar"]
		"trade":
			return ["trade"]
	return []


func _cycle_focus_zone(direction: int) -> void:
	var zones = _focus_zones_for_mode()
	if zones.is_empty():
		return
	var current = "trade" if _controller_focus_kind == "button" and _mode == "trade" else _focus_bag
	var idx = zones.find(current)
	if idx < 0:
		idx = 0
	var next_idx = posmod(idx + direction, zones.size())
	var target_bag = zones[next_idx]
	if target_bag == "trade":
		var buttons = _get_trade_buttons()
		if not buttons.is_empty():
			_set_controller_button_focus(buttons[0])
		Audio.play("click", -14.0)
		return
	_set_controller_slot_focus(target_bag, 0)
	Audio.play("click", -14.0)


func _controller_activate_slot(is_right: bool) -> void:
	if _controller_focus_kind == "button" and _controller_focus_button != null and is_instance_valid(_controller_focus_button):
		_controller_focus_button.emit_signal("pressed")
		Audio.play("click", -10.0)
		return

	if _hovered_slot.is_empty():
		return

	var bag: String = _hovered_slot.get("bag", "")
	var index: int = _hovered_slot.get("index", -1)

	match bag:
		"hotbar", "main", "armor":
			var arr = _bag(bag)
			if index < 0 or index >= arr.size():
				return
			if is_right:
				_handle_right_click(arr, index)
			else:
				_handle_left_click(arr, index, false)

		"craft":
			if not is_right:
				_swap_with(_craft_cells, index, false, 0)
				_update_craft_result()

		"craft_result":
			if not is_right:
				var fake = InputEventMouseButton.new()
				fake.button_index = MOUSE_BUTTON_LEFT
				fake.pressed = true
				_on_result_input(fake)

		"furnace":
			if _active_furnace == null:
				return
			var which = ["input", "fuel", "output"][index]
			var fake = InputEventMouseButton.new()
			fake.button_index = MOUSE_BUTTON_LEFT
			fake.pressed = true
			_on_furnace_input(fake, which)

		"anvil":
			var which = ["input1", "input2", "result"][index]
			var fake = InputEventMouseButton.new()
			fake.button_index = MOUSE_BUTTON_LEFT
			fake.pressed = true
			_on_anvil_slot_input(fake, which)

		"enchant":
			var which_e = "item" if index == 0 else "lapis"
			var fake_e = InputEventMouseButton.new()
			fake_e.button_index = MOUSE_BUTTON_LEFT
			fake_e.pressed = true
			_on_enchant_slot_input(fake_e, which_e)

		"dispenser":
			if _active_dispenser == null:
				return
			var fake = InputEventMouseButton.new()
			fake.button_index = MOUSE_BUTTON_LEFT
			fake.pressed = true
			_on_dispenser_slot_input(fake, index)

		"chest":
			if _active_chest.is_empty():
				return
			var fake_chest = InputEventMouseButton.new()
			fake_chest.button_index = MOUSE_BUTTON_LEFT
			fake_chest.pressed = true
			_on_chest_slot_input(fake_chest, index)

		"creative":
			var item_id := ""
			if _creative_grid != null and index >= 0 and index < _creative_grid.get_child_count():
				var ch = _creative_grid.get_child(index)
				if ch is Control and ch.has_meta("item_id"):
					item_id = str(ch.get_meta("item_id"))
			if item_id == "" and index >= 0 and index < _creative_items.size():
				item_id = str(_creative_items[index])
			if item_id == "":
				return
			var fake_creative = InputEventMouseButton.new()
			fake_creative.button_index = MOUSE_BUTTON_RIGHT if is_right else MOUSE_BUTTON_LEFT
			fake_creative.pressed = true
			_on_creative_slot_input(fake_creative, item_id)

	_refresh_cursor()
	_update_focus_visual()



func _fake_click_at_cursor(button: int) -> void:
	var pos = get_viewport().get_mouse_position()

	var down = InputEventMouseButton.new()
	down.button_index = button
	down.pressed = true
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)

	var up = InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	up.position = pos
	up.global_position = pos
	Input.parse_input_event(up)


func open_pause() -> void:
	if player == null:
		return
	if _pause_panel == null:
		_build_pause()
	if _pause_panel == null:
		return

	_mode = "pause"
	player.set_meta("ui_input_locked", true)
	_pause_panel.visible = true
	_pause_panel.move_to_front()
	_set_ui_mouse_mode(true)
	get_viewport().gui_disable_input = false

	_refresh_pause()
	# Ersten Pause-Button fokussieren (Controller + Tastatur)
	_controller_focus_kind = "button"
	_controller_focus_button = _pause_resume_btn
	if _pause_resume_btn != null:
		_pause_resume_btn.grab_focus()
	if _focus_cursor != null and is_instance_valid(_focus_cursor):
		_focus_cursor.visible = false

func open_command_block(cell: Vector3i) -> void:
	_mode = "command_block"
	_command_block_cell = cell
	# Ensure game ref (needed to persist + run commands via redstone)
	if game == null and interactor != null and interactor.get("game") != null:
		game = interactor.game
	_set_ui_mouse_mode(true)
	get_viewport().gui_disable_input = false

	if _creative_container:
		_creative_container.visible = false
	if _panel:
		_panel.visible = false

	if _command_block_panel != null and is_instance_valid(_command_block_panel):
		_command_block_panel.queue_free()

	_command_block_panel = Panel.new()
	_command_block_panel.name = "CommandBlockPanel"
	_command_block_panel.set_anchors_preset(Control.PRESET_CENTER)
	_command_block_panel.custom_minimum_size = Vector2(480, 180)
	_command_block_panel.position = -_command_block_panel.custom_minimum_size / 2.0
	_command_block_panel.z_index = 30
	add_child(_command_block_panel)
	_register_split_child(_command_block_panel)

	var vb = VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 10)
	_command_block_panel.add_child(vb)

	var title = Label.new()
	title.text = "Command Block"
	title.add_theme_font_size_override("font_size", 18)
	vb.add_child(title)

	_command_block_edit = LineEdit.new()
	_command_block_edit.placeholder_text = "/say hello or /summon charlie_emily"
	var key = str(cell)
	_command_block_edit.text = _command_block_texts.get(key, "")
	if game != null and game.has_method("get_command_block_command"):
		var stored = str(game.get_command_block_command(cell))
		if stored != "":
			_command_block_edit.text = stored
	_command_block_edit.focus_entered.connect(func():
		if not _osk_ignore_focus:
			_show_virtual_keyboard_if_needed(_command_block_edit)
	)
	vb.add_child(_command_block_edit)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(btn_row)

	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(func():
		var text = _command_block_edit.text.strip_edges()
		_command_block_texts[key] = text
		if game == null and interactor != null and interactor.get("game") != null:
			game = interactor.game
		if game != null and game.has_method("set_command_block_command"):
			game.set_command_block_command(cell, text)
		elif game != null and game.has_method("set_command_block_cmd"):
			game.set_command_block_cmd(cell, text)
		Audio.play("click")
		_close()
	)
	btn_row.add_child(save_btn)

	var run_btn = Button.new()
	run_btn.text = "Run Once"
	run_btn.pressed.connect(func():
		var text = _command_block_edit.text.strip_edges()
		_command_block_texts[key] = text
		if game == null and interactor != null and interactor.get("game") != null:
			game = interactor.game
		if game != null:
			if game.has_method("set_command_block_command"):
				game.set_command_block_command(cell, text)
			if game.has_method("run_command_block"):
				game.run_command_block(cell)
		Audio.play("click")
	)
	btn_row.add_child(run_btn)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close)
	btn_row.add_child(close_btn)

	if _input_device == "controller":
		_set_controller_button_focus(save_btn)
		# Open on-screen keyboard so controller can type the command
		_show_virtual_keyboard_if_needed(_command_block_edit)
	else:
		_command_block_edit.grab_focus()


func _close_pause() -> void:
	if _pause_panel != null:
		_pause_panel.visible = false
	var fo = get_viewport().gui_get_focus_owner()
	if fo != null:
		fo.release_focus()
	_mode = "closed"
	if player != null:
		player.set_meta("ui_input_locked", false)
	_controller_focus_kind = "slot"
	_controller_focus_button = null
	_set_ui_mouse_mode(false)
	get_viewport().gui_disable_input = false


func _get_pause_buttons() -> Array:
	var buttons: Array = []
	if _pause_panel == null or not is_instance_valid(_pause_panel):
		return buttons
	for child in _pause_panel.get_children():
		_collect_buttons(child, buttons)
	return buttons


func _collect_buttons(node: Node, out: Array) -> void:
	if node is Button:
		out.append(node)
	for c in node.get_children():
		_collect_buttons(c, out)


func _strip_button_focus(node: Node) -> void:
	# Buttons haben standardmäßig FOCUS_ALL. Wenn Godots eigenes GUI-System
	# echten Fokus auf einen Button legt, fängt es JOY_BUTTON_A (= ui_accept)
	# ab, bevor unser eigenes Controller-Handling in _unhandled_input es
	# überhaupt sieht. Deshalb Fokus hart deaktivieren – unsere eigene
	# Highlight-/Input-Logik übernimmt die Bedienung komplett selbst.
	if node is Control:
		var c = node as Control
		if c is Button or c is CheckButton:
			c.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_strip_button_focus(child)


func _pause_focus_move(dir: int) -> void:
	var buttons = _get_pause_buttons()
	if buttons.is_empty():
		return
	var cur = 0
	var fo = get_viewport().gui_get_focus_owner()
	for i in range(buttons.size()):
		if buttons[i] == fo:
			cur = i
			break
	var next = (cur + dir) % buttons.size()
	if next < 0:
		next += buttons.size()
	buttons[next].grab_focus()


func _pause_activate_focused() -> void:
	var fo = get_viewport().gui_get_focus_owner()
	if fo is BaseButton:
		fo.emit_signal("pressed")
		Audio.play("click", -10.0)
		return
	# Fallback: Resume
	if _pause_resume_btn != null:
		_pause_resume_btn.emit_signal("pressed")
func _refresh_pause() -> void:
	if player == null:
		return
	if _pause_mode_btn == null or _pause_diff_btn == null:
		return

	if player == null:
		return
	_pause_mode_btn.text = "Mode: " + GameSettings.mode_name(player.game_mode)
	_pause_diff_btn.text = "Difficulty: " + GameSettings.difficulty_name(player.difficulty)
func _show_virtual_keyboard_if_needed(edit: LineEdit) -> void:
	if edit == null or not is_instance_valid(edit):
		return
	if _osk_ignore_focus:
		return
	# Already open for this field — do not reopen
	if _osk_open and _osk != null and is_instance_valid(_osk) and _osk.target == edit:
		return
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(edit.text, Rect2(), DisplayServer.KEYBOARD_TYPE_DEFAULT, -1, -1)
	_open_osk(edit)


func _open_osk(edit: LineEdit) -> void:
	if edit == null or not is_instance_valid(edit):
		return
	_close_osk(false)
	_osk = OnScreenKeyboard.new()
	add_child(_osk)
	# OSK is CanvasLayer — scale handled inside its own panel
	_osk_open = true
	var for_chat := (edit == _chat_edit)
	_osk.done.connect(func(t):
		_osk_open = false
		_osk = null
		if for_chat and _mode == "chat":
			_on_chat_submit(str(t))
	)
	_osk.cancelled.connect(func():
		_osk_open = false
		_osk = null
	)
	_osk_ignore_focus = true
	if _is_split:
		_osk.owner_device = maxi(_split_index, 0)
	else:
		_osk.owner_device = -1
	_osk.open(edit)
	_osk_ignore_focus = false


func _close_osk(submit: bool = false) -> void:
	_osk_ignore_focus = true
	if _osk != null and is_instance_valid(_osk):
		# close() frees itself
		_osk.close(submit)
	_osk = null
	_osk_open = false
	_osk_ignore_focus = false
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()


func _cycle_mode() -> void:
	player.configure((player.game_mode + 1) % 4, player.difficulty)
	_refresh_pause()
func _cycle_diff() -> void:
	player.configure(player.game_mode, (player.difficulty + 1) % 4)
	_refresh_pause()
func open_chat() -> void:
	
	if _chat_edit == null or _chat_history_box == null:
		_build_chat()
	if _chat_edit == null:
		push_error("Chat UI could not be created")
		return

	_mode = "chat"
	_chat_edit.visible = true
	_chat_edit.focus_mode = Control.FOCUS_ALL
	_chat_edit.grab_focus()
	_chat_edit.text = ""
	_chat_edit.grab_focus()
	_chat_edit.move_to_front()
	_chat_edit.z_index = 100

	if _chat_history_box != null:
		_chat_history_box.visible = true
		_chat_history_box.z_index = 50

	if _chat_msg != null:
		_chat_msg.z_index = 0

	_set_ui_mouse_mode(true)
	get_viewport().gui_disable_input = false
	_show_virtual_keyboard_if_needed(_chat_edit)
	if _focus_cursor != null and is_instance_valid(_focus_cursor):
		_focus_cursor.visible = false
func _close_chat() -> void:
	_close_osk(false)
	if _chat_edit != null:
		_chat_edit.visible = false
		_chat_edit.release_focus()
		_chat_edit.text = ""
	_mode = "closed"
	_set_ui_mouse_mode(false)
	if is_inside_tree() and get_viewport() != null:
		get_viewport().gui_disable_input = false
	DisplayServer.virtual_keyboard_hide()
	if _focus_cursor != null and is_instance_valid(_focus_cursor):
		_focus_cursor.visible = false
func _on_chat_submit(text: String) -> void:
	var line = text.strip_edges()
	if line == "":
		_close_chat()
		return

	# Nur "/" ganz am Anfang = Befehl
	if line.begins_with("/"):
		var p = player
		var g = null
		if interactor != null:
			g = interactor.game
			if p == null:
				p = interactor.get("player")
		var scene = get_tree().current_scene
		if scene != null:
			if g == null:
				g = scene
			if p == null and "player" in scene:
				p = scene.player
			if p == null:
				p = scene.find_child("Player", true, false)
		if p != null:
			player = p
		if g != null and interactor != null:
			interactor.game = g

		var result = ""
		if p != null and g != null:
			result = CommandParser.execute(line, g, p)
		else:
			result = "Chat fail p=%s g=%s" % [p, g]
		if result != "":
			_push_chat_history(result)
		print("[Chat] ", result)
		_close_chat()
		return

	# Normale Nachricht → an alle senden
	_broadcast_chat(line)
	_close_chat()
	print("[Chat] ", line)
func _set_controller_slot_focus(bag: String, index: int = 0) -> void:
	_controller_focus_kind = "slot"
	_controller_focus_button = null
	_focus_bag = bag
	# Creative + search: index 0 is almost always "stone" and hidden — snap to first match
	if bag == "creative":
		if not _creative_index_matches(index):
			index = _first_creative_match_index()
	_focus_index = index
	_hovered_slot = {"bag": _focus_bag, "index": _focus_index}
	_update_focus_visual()


func _set_controller_button_focus(button: BaseButton) -> void:
	_controller_focus_kind = "button"
	_controller_focus_button = button
	_hovered_slot = {}
	if button != null:
		button.grab_focus()
	_update_focus_visual()


func open_inventory() -> void:
	_close_enchant_panel()
	_open("inventory", 2, null)
	if _input_device == "controller":
		_set_controller_slot_focus("main", 0)
func open_table() -> void:
	_open("table", 3, null)
	if _input_device == "controller":
		_set_controller_slot_focus("main", 0)
func open_furnace(furn) -> void:
	if _input_device == "controller":
		_set_controller_slot_focus("main", 0)
	_active_furnace = furn
	_open("furnace", 0, furn)
func _open(mode: String, craft_size: int, furn) -> void:
	if _mode == "closed":
		Audio.play("player_inventory_open", -8.0)
	_mode = mode
	if _panel != null:
		_panel.visible = true
	_set_ui_mouse_mode(true)

	_rebuild_craft(craft_size)
	_rebuild_furnace(furn)

	if player != null and player.game_mode == GameSettings.GameMode.CREATIVE:
		if _creative_container != null:
			_creative_container.visible = true
			if _creative_grid != null and _creative_grid.get_child_count() == 0:
				_build_creative_inventory()
	else:
		if _creative_container != null:
			_creative_container.visible = false
			
	if _input_device == "controller":
		_set_controller_slot_focus("main", 0)
func _close() -> void:
	if _mode == "chest":
		Audio.play("chest_close")
	elif _mode != "closed":
		Audio.play("player_inventory_close", -8.0)
	if _mode == "enchant":
		_close_enchant_panel()

	_close_osk(false)
	_hide_item_tooltip()
	# Craft + Cursor Items zurück ins Inventar geben
	if player != null and player.inventory != null:
		for s in _craft_cells:
			if s != null:
				player.inventory.add(s.item_id, s.count)
		_craft_cells.clear()

		if _cursor != null:
			player.inventory.add(_cursor.item_id, _cursor.count)
			_cursor = null

		# Anvil Items zurückgeben
		if _anvil_input1.has("item") and _anvil_input1["item"] != null:
			player.inventory.add(_anvil_input1["item"].item_id, _anvil_input1["item"].count)
			_anvil_input1["item"] = null
		if _anvil_input2.has("item") and _anvil_input2["item"] != null:
			player.inventory.add(_anvil_input2["item"].item_id, _anvil_input2["item"].count)
			_anvil_input2["item"] = null

	_active_furnace = null

	if _trade_panel != null:
		_trade_panel.queue_free()
		_trade_panel = null
		_trade_villager = null

	# Anvil UI schließen
	var anvil = _anvil_panel
	if anvil == null:
		anvil = get_node_or_null("AnvilPanel")
	if anvil != null:
		anvil.visible = false

	# Inventar-Panel schließen + zentrieren
	if _panel != null:
		_panel.anchor_left = 0.5
		_panel.anchor_top = 0.5
		_panel.anchor_right = 0.5
		_panel.anchor_bottom = 0.5
		_panel.offset_left = -550
		_panel.offset_top = -310
		_panel.offset_right = 550
		_panel.offset_bottom = 310
		_panel.custom_minimum_size = Vector2(1100, 620)
		_panel.visible = false

	_mode = "closed"
	_active_dispenser = null
	_active_chest = []

	# Dispenser-Panel schließen
	if _dispenser_panel != null and is_instance_valid(_dispenser_panel):
		_dispenser_panel.visible = false
		_dispenser_panel.queue_free()
	_dispenser_panel = null
	_dispenser_widgets.clear()
	var leftover = get_node_or_null("DispenserPanel")
	if leftover != null:
		leftover.queue_free()

	# Chest-Panel schließen
	if _chest_panel != null and is_instance_valid(_chest_panel):
		_chest_panel.visible = false
		_chest_panel.queue_free()
	_chest_panel = null
	_chest_widgets.clear()
	var chest_leftover = get_node_or_null("ChestPanel")
	if chest_leftover != null:
		chest_leftover.queue_free()

	# Command-Block-Panel schließen
	if _command_block_panel != null and is_instance_valid(_command_block_panel):
		_command_block_panel.visible = false
		_command_block_panel.queue_free()
	_command_block_panel = null
	_command_block_edit = null

	# Creative-Container-Flag für nächstes Öffnen (Panel selbst ist unsichtbar)
	if player != null and player.game_mode == GameSettings.GameMode.CREATIVE:
		if _creative_container != null:
			_creative_container.visible = true

	# Controller-Fokus + virtueller Cursor zurücksetzen
	_focus_bag = "hotbar"
	_focus_index = 0
	_hovered_slot = {}
	if _focus_cursor != null and is_instance_valid(_focus_cursor):
		_focus_cursor.visible = false
	# Slot-Glows zurücksetzen
	for entry in _bag_widgets:
		if entry["w"]["panel"] != null and is_instance_valid(entry["w"]["panel"]):
			entry["w"]["panel"].self_modulate = Color(1, 1, 1)

	# GUI-Fokus freigeben, Maus wieder einfangen
	var fo = get_viewport().gui_get_focus_owner()
	if fo != null:
		fo.release_focus()
	_set_ui_mouse_mode(false)
	get_viewport().gui_disable_input = false

func _refresh_anvil_slots() -> void:
	for which in ["input1", "input2", "result"]:
		var d: Dictionary
		match which:
			"input1": d = _anvil_input1
			"input2": d = _anvil_input2
			"result": d = _anvil_result
			_: continue
		
		var it = d.get("item")
		
		if it == null:
			d["icon"].texture = null
			if which != "result":
				d["label"].text = ""
			continue
		
		d["icon"].texture = Textures.get_texture(it.item_id)
		
		# === WICHTIG: Result-Slot Label NICHT überschreiben ===
		if which == "result":
			continue
		
		# Nur bei normalen Slots Count anzeigen
		if it.count > 1:
			d["label"].text = str(it.count)
		else:
			d["label"].text = ""
		
func open_trades(villager) -> void:
	_trade_villager = villager
	if villager != null and villager.has_method("play_mob_sound"):
		villager.play_mob_sound("idle")
	_mode = "trade"
	if _is_split:
		_input_device = "controller"
	if _panel:
		_panel.visible = true
	_set_ui_mouse_mode(true)
	get_viewport().gui_disable_input = false

	if _trade_panel != null:
		_trade_panel.queue_free()
		_trade_panel = null

	_trade_panel = Panel.new()
	_trade_panel.set_anchors_preset(Control.PRESET_CENTER)
	_trade_panel.custom_minimum_size = Vector2(440, 360)
	_trade_panel.position = -_trade_panel.custom_minimum_size / 2.0
	add_child(_trade_panel)
	_register_split_child(_trade_panel)

	var vb = VBoxContainer.new()
	vb.position = Vector2(16, 12)
	vb.add_theme_constant_override("separation", 6)
	_trade_panel.add_child(vb)

	var title = Label.new()
	title.text = "Trade - " + villager.profession + " (E to close)"
	vb.add_child(title)

	if not villager.can_trade():
		if villager.has_method("play_mob_sound"):
			villager.play_mob_sound("no")
		var l = Label.new()
		l.text = "This villager is upset and won't trade."
		vb.add_child(l)
		return

	for tr in villager.trades:
		var row = HBoxContainer.new()
		var cost_txt = ""
		for c in tr["cost"]:
			cost_txt += "%dx %s " % [int(c[1]), c[0]]

		var lbl = Label.new()
		lbl.text = "%s-> %dx %s" % [cost_txt, int(tr["reward"][1]), tr["reward"][0]]
		lbl.custom_minimum_size = Vector2(330, 0)
		row.add_child(lbl)

		var btn = Button.new()
		btn.text = "Trade"
		btn.pressed.connect(_do_trade.bind(tr))
		row.add_child(btn)

		vb.add_child(row)
		
		
	if _input_device == "controller":
		var trade_buttons = _get_trade_buttons()
		if not trade_buttons.is_empty():
			_set_controller_button_focus(trade_buttons[0])
func _do_trade(tr: Dictionary) -> void:
	if _trade_villager == null or not _trade_villager.can_trade():
		return
	for c in tr["cost"]:
		if not player.inventory.has(c[0], int(c[1])):
			if _trade_villager.has_method("play_mob_sound"):
				_trade_villager.play_mob_sound("no")
			Audio.play("ui_error", -12.0)
			return
	for c in tr["cost"]:
		player.inventory.remove(c[0], int(c[1]))
	player.inventory.add(tr["reward"][0], int(tr["reward"][1]))
	if _trade_villager.has_method("play_mob_sound"):
		_trade_villager.play_mob_sound("yes")
	Audio.play("ui_click")
func _rebuild_craft(size: int) -> void:
	if _craft_container == null:
		return

	# Alte Kinder löschen
	for c in _craft_container.get_children():
		c.queue_free()

	_craft_widgets.clear()
	_craft_cells.clear()
	_craft_result = null
	_craft_size = size

	if size <= 0:
		_craft_container.visible = false
		return

	_craft_container.visible = true
	_craft_container.columns = size # sauberes 2x2 oder 3x3
	_craft_container.add_theme_constant_override("h_separation", 4)
	_craft_container.add_theme_constant_override("v_separation", 4)

	# Craft-Slots erstellen
	for i in range(size * size):
		_craft_cells.append(null)
		var s = _make_slot()
		_craft_container.add_child(s["panel"])
		_craft_widgets.append(s)
		s["panel"].gui_input.connect(_on_craft_input.bind(i))

	# Result-Slot separat und sicher erstellen
	if _result_widget.has("panel") and is_instance_valid(_result_widget.get("panel")):
		_result_widget["panel"].queue_free()

	_result_widget = _make_slot()
	# Result wird als nächstes Kind nach dem Grid hinzugefügt
	var parent = _craft_container.get_parent()
	if parent:
		parent.add_child(_result_widget["panel"])
	else:
		_craft_container.add_child(_result_widget["panel"])

	_result_widget["panel"].gui_input.connect(_on_result_input)

	_update_craft_result()
func _rebuild_furnace(furn) -> void:
	if _furnace_box == null:
		return

	for c in _furnace_box.get_children():
		c.queue_free()

	_furnace_widgets.clear()

	if furn == null:
		_furnace_box.visible = false
		return

	_furnace_box.visible = true

	var inp = _make_slot()
	var fuel = _make_slot()
	var outp = _make_slot()
	_furnace_widgets = {"input": inp, "fuel": fuel, "output": outp}

	var prog = Label.new()
	prog.name = "prog"

	_furnace_box.add_child(inp["panel"])
	var lbl = Label.new()
	lbl.text = "fuel"
	_furnace_box.add_child(fuel["panel"])
	_furnace_box.add_child(prog)
	_furnace_box.add_child(outp["panel"])

	inp["panel"].gui_input.connect(_on_furnace_input.bind("input"))
	fuel["panel"].gui_input.connect(_on_furnace_input.bind("fuel"))
	outp["panel"].gui_input.connect(_on_furnace_input.bind("output"))
		# ---------------------------------------------------------------- clicks
func _bag(name: String) -> Array:
	if player == null or player.inventory == null:
		return []
	match name:
		"hotbar":
			return player.inventory.hotbar
		"main":
			return player.inventory.main
		_:
			return player.inventory.armor
func _swap_with(arr: Array, index: int, allow_armor: bool, armor_index: int) -> void:
	if index < 0 or index >= arr.size():
		return

	var s = arr[index]

	if _cursor == null:
		# Nichts in der Hand → Slot aufnehmen
		if s != null:
			_cursor = s
			arr[index] = null
		return

	# Etwas in der Hand
	if s == null:
		# Leerer Slot → ablegen
		if allow_armor and not _can_equip(_cursor, armor_index):
			return
		arr[index] = _cursor
		_cursor = null
		return

	# Beide Seiten haben Items
	if s.stackable_with(_cursor):
		var move = mini(s.max_stack() - s.count, _cursor.count)
		s.count += move
		_cursor.count -= move
		if _cursor.count <= 0:
			_cursor = null
	else:
		# Tauschen
		arr[index] = _cursor
		_cursor = s
func _on_bag_input(event: InputEvent, bag: String, index: int) -> void:
	var arr = _bag(bag)
	var is_left = _is_click(event)
	var is_right = _is_right_click(event)
	var ctrl = Input.is_key_pressed(KEY_CTRL)

	if is_left:
		_handle_left_click(arr, index, ctrl)
	elif is_right:
		_handle_right_click(arr, index)
		
		
		
func _handle_left_click(arr: Array, index: int, ctrl_pressed: bool) -> void:
	var s = arr[index]

	if _cursor == null:
		if s != null:
			_cursor = s
			arr[index] = null
		return

	if s == null:
		arr[index] = _cursor
		_cursor = null
	elif s.stackable_with(_cursor):
		if ctrl_pressed:
			var move = mini(s.max_stack() - s.count, _cursor.count)
			s.count += move
			_cursor.count -= move
		else:
			var move = mini(s.max_stack() - s.count, _cursor.count)
			s.count += move
			_cursor.count -= move
		if _cursor.count <= 0:
			_cursor = null
	else:
		arr[index] = _cursor
		_cursor = s


func _on_craft_input(event: InputEvent, index: int) -> void:
	if not _is_click(event):
		return
	_swap_with(_craft_cells, index, false, 0)
	_update_craft_result()
func _on_result_input(event: InputEvent) -> void:
	if not _is_click(event):
		return
	if _craft_result == null or _craft_result.is_empty():
		return

	var rid = _craft_result.get("result", "")
	var rcount = int(_craft_result.get("count", 1))
	if rid == "":
		return

	if _cursor != null:
		if _cursor.item_id != rid or _cursor.durability != -1:
			return
		if _cursor.count + rcount > _cursor.max_stack():
			return
		_cursor.count += rcount
	else:
		_cursor = ItemStack.new(rid, rcount)

	# Items aus dem Grid abziehen
	for i in range(_craft_cells.size()):
		var s = _craft_cells[i]
		if s != null:
			s.count -= 1
			if s.count <= 0:
				_craft_cells[i] = null

	_update_craft_result()
func _on_furnace_input(event: InputEvent, which: String) -> void:
	if not _is_click(event) or _active_furnace == null:
		return
	if which == "output":
		if _active_furnace.output != null and _cursor == null:
			_cursor = _active_furnace.output
			_active_furnace.output = null
			return
	var cur = _active_furnace.input if which == "input" else _active_furnace.fuel
	if _cursor == null:
		if cur != null:
			_cursor = cur
			_set_furnace_slot(which, null)
	else:
		_set_furnace_slot(which, _cursor)
		_cursor = cur
func _set_furnace_slot(which: String, val) -> void:
	if which == "input":
		_active_furnace.input = val
	else:
		_active_furnace.fuel = val
func _can_equip(stack, index: int) -> bool:
	if stack == null:
		return false

	if stack.item_id == "elytra":
		return index == 1

	var it = Registry.get_item(stack.item_id)
	if it == null or it.get("type", "") != "armor":
		return false

	return it.get("slot", "") == ARMOR_SLOT_NAMES[index]
func _update_craft_result() -> void:
	if _craft_size <= 0:
		_craft_result = null
		return

	var expected = _craft_size * _craft_size
	var grid: Array = []

	for i in range(expected):
		if i < _craft_cells.size() and _craft_cells[i] != null:
			grid.append(_craft_cells[i].item_id)
		else:
			grid.append("")

	var res = Crafting.match_grid(grid, _craft_size)
	_craft_result = res if not res.is_empty() else null
# ---------------------------------------------------------------- refresh

var _boss_bar: ProgressBar
var _boss_label: Label

func open_skin_selector() -> void:
	# Alten Selector entfernen
	if has_node("SkinSelector"):
		get_node("SkinSelector").queue_free()
	_skin_buttons.clear()
	_skin_focus_idx = 0

	# Critical: leave game mode so controller no longer drives gameplay
	_mode = "skin"
	if player != null:
		player.set_meta("ui_input_locked", true)
	_set_ui_mouse_mode(true)
	if is_inside_tree() and get_viewport() != null:
		get_viewport().gui_disable_input = false

	var panel = Panel.new()
	panel.name = "SkinSelector"
	_skin_panel = panel
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 520)
	panel.position = -panel.custom_minimum_size / 2.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 120
	add_child(panel)
	panel.move_to_front()

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Select Skin"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var hint = Label.new()
	hint.text = "Controller: D-Pad navigate | A select | B close"
	vbox.add_child(hint)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 340)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(scroll)

	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	# Default Skin — FOCUS_NONE so A is not eaten by Godot GUI
	var default_btn = Button.new()
	default_btn.text = "Afro Steve (Default)"
	default_btn.custom_minimum_size = Vector2(0, 36)
	default_btn.focus_mode = Control.FOCUS_NONE
	default_btn.set_meta("skin_action", "select")
	default_btn.set_meta("skin_name", "afro_steve")
	default_btn.pressed.connect(_on_skin_selected.bind("afro_steve"))
	list.add_child(default_btn)
	_skin_buttons.append(default_btn)

	var dir = DirAccess.open("user://skins")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var skin_name = file_name.get_basename()
				var btn = Button.new()
				btn.text = skin_name.replace("_", " ").capitalize()
				btn.custom_minimum_size = Vector2(0, 36)
				btn.focus_mode = Control.FOCUS_NONE
				btn.set_meta("skin_action", "select")
				btn.set_meta("skin_name", skin_name)
				btn.pressed.connect(_on_skin_selected.bind(skin_name))
				list.add_child(btn)
				_skin_buttons.append(btn)
			file_name = dir.get_next()
		dir.list_dir_end()

	var create_btn = Button.new()
	create_btn.text = "Create New Skin..."
	create_btn.custom_minimum_size = Vector2(0, 40)
	create_btn.focus_mode = Control.FOCUS_NONE
	create_btn.set_meta("skin_action", "create")
	create_btn.pressed.connect(func():
		_close_skin_selector(false)
		_open_avatar_editor_from_ui()
	)
	vbox.add_child(create_btn)
	_skin_buttons.append(create_btn)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 36)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.set_meta("skin_action", "close")
	close_btn.pressed.connect(func():
		_close_skin_selector(true)
	)
	vbox.add_child(close_btn)
	_skin_buttons.append(close_btn)

	_skin_focus_idx = 0
	_skin_focus_apply()


func _skin_focus_apply() -> void:
	if _skin_buttons.is_empty():
		return
	_skin_focus_idx = clampi(_skin_focus_idx, 0, _skin_buttons.size() - 1)
	for i in range(_skin_buttons.size()):
		var b: Control = _skin_buttons[i]
		if not is_instance_valid(b):
			continue
		# Visual only — no grab_focus (would steal A / ui_accept from our handler)
		b.modulate = Color(1.4, 1.35, 0.55) if i == _skin_focus_idx else Color(1, 1, 1)


func _skin_focus_move(dir: int) -> void:
	if _skin_buttons.is_empty():
		return
	_skin_focus_idx = posmod(_skin_focus_idx + dir, _skin_buttons.size())
	_skin_focus_apply()


func _skin_activate() -> void:
	if _skin_buttons.is_empty():
		return
	var b = _skin_buttons[_skin_focus_idx]
	if not is_instance_valid(b):
		return
	Audio.play("click", -10.0)
	# Dispatch by meta so Create works even if signal timing is odd
	var action := str(b.get_meta("skin_action", ""))
	if action == "create":
		_close_skin_selector(false)
		_open_avatar_editor_from_ui()
		return
	if action == "close":
		_close_skin_selector(true)
		return
	if action == "select":
		_on_skin_selected(str(b.get_meta("skin_name", "afro_steve")))
		return
	# Fallback
	if b is BaseButton:
		(b as BaseButton).pressed.emit()


func _close_skin_selector(capture_mouse: bool = true) -> void:
	if has_node("SkinSelector"):
		get_node("SkinSelector").queue_free()
	_skin_panel = null
	_skin_buttons.clear()
	_skin_focus_idx = 0
	_mode = "closed"
	if player != null:
		player.set_meta("ui_input_locked", false)
	if capture_mouse:
		_set_ui_mouse_mode(false)


func _on_skin_selected(skin_name: String) -> void:
	if player == null:
		return
	player.set_skin(skin_name)
	if game != null and game.has_method("notify_local_skin_changed"):
		game.notify_local_skin_changed(player)
	_close_skin_selector(true)
	Audio.play("click")


func _open_avatar_editor_from_ui() -> void:
	# Leave game controls; avatar editor owns controller input
	_mode = "avatar"
	if player != null:
		player.set_meta("ui_input_locked", true)
	_set_ui_mouse_mode(true)
	if is_inside_tree() and get_viewport() != null:
		get_viewport().gui_disable_input = false

	var layer = CanvasLayer.new()
	layer.layer = 130
	layer.name = "AvatarEditorLayer"
	add_child(layer)

	var editor = preload("res://scripts/avatar_editor.gd").new()
	layer.add_child(editor)

	editor.closed.connect(func():
		if is_instance_valid(layer):
			layer.queue_free()
		_mode = "closed"
		if player != null:
			player.set_meta("ui_input_locked", false)
		_set_ui_mouse_mode(false)
	)

	editor.skin_saved.connect(func(data):
		print("Skin gespeichert: ", data["name"])
		if player:
			player.set_skin(data["name"].replace(" ", "_").to_lower(), data)
			if game != null and game.has_method("notify_local_skin_changed"):
				game.notify_local_skin_changed(player)
	)

func show_boss_bar(boss_name: String, max_health: float) -> void:
	if _boss_bar == null:
		_create_boss_bar()

	_boss_label.text = boss_name
	_boss_bar.max_value = max_health
	_boss_bar.value = max_health
	_boss_bar.visible = true
	_boss_label.visible = true

func update_boss_bar(current_health: float) -> void:
	if _boss_bar != null:
		_boss_bar.value = current_health

func hide_boss_bar() -> void:
	if _boss_bar != null:
		_boss_bar.visible = false
		_boss_label.visible = false

func _create_boss_bar() -> void:
	_boss_bar = ProgressBar.new()
	_boss_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_bar.offset_top = 40
	_boss_bar.offset_left = 200
	_boss_bar.offset_right = -200
	_boss_bar.custom_minimum_size = Vector2(0, 20)
	add_child(_boss_bar)

	_boss_label = Label.new()
	_boss_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_label.offset_top = 20
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_boss_label)
func _process(_delta: float) -> void:
	if player == null:
		return

	# Controller-Nav-Cooldown in _process ticken (nicht nur bei Motion-Events)
	if _controller_nav_cooldown > 0.0:
		_controller_nav_cooldown = maxf(0.0, _controller_nav_cooldown - _delta)

	# Kein DisplayServer.warp_mouse mehr – das hat Hover-Events ausgelöst
	# und den Fokus ständig überschrieben. Navigation läuft rein über _focus_*.

	# Slot texture/name/durability refreshes are UI work, not gameplay work.
	# At 60+ FPS doing all of them every frame is wasteful and multiplies with
	# every split-screen player. 20 Hz remains visually immediate.
	_hud_refresh_t -= _delta
	if _hud_refresh_t <= 0.0:
		var hud_step := 0.05
		_hud_refresh_t = hud_step
		_refresh_hotbar(hud_step)
		_refresh_stats()
		_refresh_info()
		_refresh_effect_hud()
	if _coords_visible:
		_update_coords()

	# Cursor icon follows mouse whenever we hold a stack (inventory, enchant, anvil, ...)
	if _cursor != null:
		_refresh_cursor()
	elif _cursor_icon != null:
		_cursor_icon.visible = false

	if _mode in ["inventory", "table", "furnace", "anvil", "dispenser", "chest", "trade", "enchant"]:
		_inventory_refresh_t -= _delta
		if _inventory_refresh_t <= 0.0:
			_inventory_refresh_t = 0.05
			_refresh_open()
			if _mode == "anvil":
				_refresh_anvil_slots()
			if _mode == "enchant":
				_refresh_enchant_slots()
			if _mode == "dispenser":
				_refresh_dispenser_slots()
			if _mode == "chest" and has_method("_refresh_chest_slots"):
				_refresh_chest_slots()
		if _input_device == "controller":
			_position_focus_cursor()
			_update_focus_visual()
	else:
		if _focus_cursor != null:
			_focus_cursor.visible = false

func open_anvil() -> void:
	_mode = "anvil"
	if _is_split:
		_input_device = "controller"
	if _panel:
		_panel.visible = true
	_set_ui_mouse_mode(true)
	get_viewport().gui_disable_input = false
	
	# Creative Inventory ausblenden
	if _creative_container:
		_creative_container.visible = false
	
	if _panel:
		_panel.visible = true
	
	# === WICHTIG: Altes Anvil-Panel immer löschen ===
	if has_node("AnvilPanel"):
		get_node("AnvilPanel").queue_free()
		_anvil_panel = null
		_anvil_input1 = {}
		_anvil_input2 = {}
		_anvil_result = {}
	
	# Neues Anvil UI erstellen
	_create_anvil_ui()
	# Anvil-Panel rechts neben das Inventar positionieren
	if _anvil_panel:
		_anvil_panel.visible = true
		_anvil_panel.set_anchors_preset(Control.PRESET_CENTER)
		_anvil_panel.offset_left = -240
		_anvil_panel.offset_right = 240
		_anvil_panel.offset_top = -300
		_anvil_panel.offset_bottom = -20
		_anvil_panel.custom_minimum_size = Vector2(480, 280)
		_anvil_panel.z_index = 40
		_anvil_panel.move_to_front()
		_refresh_anvil_slots()
		_update_anvil_result()
		
		
	if _input_device == "controller":
		_set_controller_slot_focus("anvil", 0)
		
func _on_anvil_slot_input(event: InputEvent, which: String) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	
	var slot_dict: Dictionary
	match which:
		"input1": slot_dict = _anvil_input1
		"input2": slot_dict = _anvil_input2
		"result": slot_dict = _anvil_result
		_: return
	
	var current = slot_dict.get("item")
	
	if which == "result":
		if current != null and _cursor == null:
			_cursor = current
			slot_dict["item"] = null
			_anvil_input1["item"] = null
			_anvil_input2["item"] = null
			_refresh_anvil_slots()
			_update_anvil_result()
		return
	
	# Normale Slots (input1 + input2)
	if _cursor == null:
		if current != null:
			_cursor = current
			slot_dict["item"] = null
	else:
		if current == null:
			slot_dict["item"] = _cursor
			_cursor = null
		elif current.stackable_with(_cursor):
			var move = min(current.max_stack() - current.count, _cursor.count)
			current.count += move
			_cursor.count -= move
			if _cursor.count <= 0:
				_cursor = null
		else:
			var temp = current
			slot_dict["item"] = _cursor
			_cursor = temp
	
	_refresh_anvil_slots()
	_refresh_open()
	_update_anvil_result()

func _on_anvil_name_changed(new_text: String) -> void:
	_update_anvil_result()
	_refresh_anvil_slots()



func _create_anvil_ui() -> void:
	# Falls schon ein altes Panel existiert → löschen
	if has_node("AnvilPanel"):
		get_node("AnvilPanel").queue_free()
	
	_anvil_panel = Panel.new()
	_anvil_panel.name = "AnvilPanel"

	# Hintergrund
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.45)
	_anvil_panel.add_theme_stylebox_override("panel", style)

	add_child(_anvil_panel)
	_register_split_child(_anvil_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	_anvil_panel.add_child(vbox)

	# Titel
	var title = Label.new()
	title.text = "Anvil"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	# Slots Zeile
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	vbox.add_child(hbox)
	# === Buttons ===
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(button_hbox)

	var apply_btn = Button.new()
	apply_btn.text = "Apply"
	apply_btn.pressed.connect(_on_anvil_apply_pressed)
	vbox.add_child(apply_btn)

	var repair_btn = Button.new()
	repair_btn.text = "Repair"
	repair_btn.pressed.connect(_on_anvil_repair_pressed)
	vbox.add_child(repair_btn)

	# Input 1
	_anvil_input1 = _make_anvil_slot()
	_anvil_input1["panel"].gui_input.connect(_on_anvil_slot_input.bind("input1"))
	hbox.add_child(_anvil_input1["panel"])

	# Input 2
	_anvil_input2 = _make_anvil_slot()
	_anvil_input2["panel"].gui_input.connect(_on_anvil_slot_input.bind("input2"))
	hbox.add_child(_anvil_input2["panel"])

	# Result
	_anvil_result = _make_anvil_slot(true)
	_anvil_result["panel"].gui_input.connect(_on_anvil_slot_input.bind("result"))
	hbox.add_child(_anvil_result["panel"])

	# Textfeld zum Umbenennen
	_anvil_text_edit = LineEdit.new()
	_anvil_text_edit.placeholder_text = "New name..."
	_anvil_text_edit.custom_minimum_size = Vector2(300, 30)
	_anvil_text_edit.text_changed.connect(_on_anvil_name_changed)
	_anvil_text_edit.focus_entered.connect(func():
		if not _osk_ignore_focus:
			_show_virtual_keyboard_if_needed(_anvil_text_edit)
	)
	_anvil_text_edit.focus_exited.connect(func():
		if not _osk_open and not _osk_ignore_focus:
			DisplayServer.virtual_keyboard_hide()
	)
	vbox.add_child(_anvil_text_edit)

	# Hinweis
	var hint = Label.new()
	hint.text = "Put item + Name Tag or same item to repair"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
	
func _on_anvil_apply_pressed() -> void:
	var input1 = _anvil_input1.get("item")
	if input1 == null:
		return

	var result = ItemStack.new(input1.item_id, input1.count)

	if input1.durability >= 0:
		result.durability = input1.durability

	# Enchantments von Input1 übernehmen (nicht verlieren!)
	result.enchantments = input1.enchantments.duplicate()

	# Custom Name übernehmen
	if input1.custom_name.strip_edges() != "":
		result.custom_name = input1.custom_name

	# Rename aus Textfeld überschreibt
	if _anvil_text_edit and _anvil_text_edit.text.strip_edges() != "":
		result.custom_name = _anvil_text_edit.text.strip_edges()

	var input2 = _anvil_input2.get("item")
	if input2 != null:
		# Enchantments von Slot 2 dazu-mergen
		for ench_id in input2.enchantments.keys():
			var lvl = input2.enchantments[ench_id]
			var existing = result.enchantments.get(ench_id, 0)
			result.enchantments[ench_id] = max(existing, lvl)

		# Reparatur falls gleiches Item
		if input2.item_id == input1.item_id and result.has_method("max_durability"):
			var max_dur = result.max_durability()
			result.durability = min(result.durability + int(max_dur * 0.4), max_dur)

	_cursor = result
	_anvil_input1["item"] = null
	_anvil_input2["item"] = null
	_anvil_result["item"] = null

	if _anvil_text_edit:
		_anvil_text_edit.text = ""

	_refresh_anvil_slots()
	_refresh_open()
	_update_anvil_result()


func _on_anvil_repair_pressed() -> void:
	var input1 = _anvil_input1.get("item")
	var input2 = _anvil_input2.get("item")

	if input1 == null or input2 == null:
		return
	if input1.item_id != input2.item_id:
		return

	var result = ItemStack.new(input1.item_id, input1.count)

	if input1.durability >= 0:
		result.durability = input1.durability

	result.enchantments = input1.enchantments.duplicate()

	if input1.custom_name.strip_edges() != "":
		result.custom_name = input1.custom_name

	if result.has_method("max_durability"):
		var max_dur = result.max_durability()
		result.durability = min(result.durability + int(max_dur * 0.5), max_dur)

	_cursor = result
	_anvil_input1["item"] = null
	_anvil_input2["item"] = null
	_anvil_result["item"] = null

	_refresh_anvil_slots()
	_refresh_open()
	_update_anvil_result()


func _make_anvil_slot(is_result: bool = false) -> Dictionary:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(64, 64)
	
	var icon = TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(icon)
	
	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(label)
	
	# Durability Bar (neu)
	var dura = ColorRect.new()
	dura.position = Vector2(3, 57)
	dura.size = Vector2(58, 4)
	dura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dura.visible = false
	panel.add_child(dura)
	
	return {
		"panel": panel,
		"icon": icon,
		"label": label,
		"dura": dura,
		"item": null
	}
		
func _build_anvil_ui() -> void:
	_focus_bag = "main"
	_focus_index = 0

	_hovered_slot = {
		"bag": _focus_bag,
		"index": _focus_index
	}

	_update_focus_visual()
	var anvil_panel = Panel.new()
	anvil_panel.name = "AnvilUI"
	anvil_panel.set_anchors_preset(Control.PRESET_CENTER)
	anvil_panel.custom_minimum_size = Vector2(400, 200)
	add_child(anvil_panel)
	
	var vbox = VBoxContainer.new()
	anvil_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Anvil"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Hier kannst du später die echten Anvil-Slots (Input1, Input2, Result) hinzufügen
	var info = Label.new()
	info.text = "Anvil UI (work in progress)"
	vbox.add_child(info)
func _refresh_info() -> void:
	if _info == null:
		return
	if player == null or player.inventory == null:
		_info.text = ""
		return

	var held = player.inventory.held()
	var txt = ""
	if held != null and held.item_id == "clock" and interactor != null and interactor.game != null:
		var g = interactor.game
		txt = "Time %.2f (%s)" % [g.time_of_day, "Night" if g.is_night() else "Day"]
	elif held != null and held.item_id == "compass":
		var d = player.spawn_point - player.global_position
		txt = "Spawn %.0fm away" % Vector2(d.x, d.z).length()
	_info.text = txt
func _refresh_slot(widget: Dictionary, stack) -> void:
	if stack == null:
		widget["icon"].texture = null
		widget["label"].text = ""
		widget["dura"].visible = false
		return

	widget["icon"].texture = Textures.get_texture(stack.item_id)

	# Purple glint on enchanted items / enchanted books
	var enchanted = not stack.enchantments.is_empty() or str(stack.item_id).begins_with("enchanted_book")
	if enchanted:
		widget["icon"].self_modulate = Color(0.72, 0.45, 1.0)
	else:
		widget["icon"].self_modulate = Color(1, 1, 1)

	if stack.count > 1:
		widget["label"].text = str(stack.count)
	else:
		widget["label"].text = ""

	# Durability Bar (unverändert)
	if stack.durability >= 0:
		var max_dur = 100
		var item_data = Registry.get_item(stack.item_id)
		if item_data != null:
			max_dur = int(item_data.get("durability", 100))
		var frac = clampf(float(stack.durability) / max_dur, 0.0, 1.0)
		widget["dura"].visible = stack.durability < max_dur
		widget["dura"].size = Vector2((SLOT - 6) * frac, 4)
		widget["dura"].color = Color(1.0 - frac, frac, 0.12)
	else:
		widget["dura"].visible = false
	
	# Durability...
func _refresh_hotbar(delta: float = 0.0) -> void:
	if player == null or player.inventory == null:
		return

	var inv = player.inventory
	for i in range(9):
		if i < _hotbar_slots.size():
			_refresh_slot(_hotbar_slots[i], inv.hotbar[i])
			var selected = i == inv.selected
			var b = 1.0 if selected else 0.6
			_hotbar_slots[i]["panel"].self_modulate = Color(b, b, b)
			_hotbar_slots[i]["overlay"].visible = selected

	# Item-Name über der Hotbar: zeigt Name + Anzahl des aktuell
	# ausgewählten Slots, aktualisiert live und blendet sich nach kurzer
	# Zeit wieder aus (wie in Vanilla Minecraft), bleibt aber sichtbar
	# solange sich Slot/Item/Anzahl ändern (z.B. Controller-Wechsel).
	var stack = inv.hotbar[inv.selected] if inv.selected < inv.hotbar.size() else null
	var key = ""
	if stack != null:
		var item_data = Registry.get_item(stack.item_id)
		var nm = stack.custom_name
		if nm == null or nm.strip_edges() == "":
			nm = item_data.get("name", stack.item_id) if item_data != null else stack.item_id
		key = str(inv.selected) + "|" + nm + "|" + str(stack.count)
		_hotbar_name_label.text = nm if stack.count <= 1 else "%s x%d" % [nm, stack.count]
	else:
		key = str(inv.selected) + "|empty"
		_hotbar_name_label.text = ""

	if key != _hotbar_name_last_key:
		_hotbar_name_last_key = key
		_hotbar_name_timer = 2.0

	if _hotbar_name_timer > 0.0:
		_hotbar_name_timer = maxf(0.0, _hotbar_name_timer - delta)
		var a = 1.0 if stack != null else 0.0
		if _hotbar_name_timer < 0.4:
			a *= _hotbar_name_timer / 0.4
		_hotbar_name_label.modulate = Color(1, 1, 1, a)
	else:
		_hotbar_name_label.modulate = Color(1, 1, 1, 0)
func _refresh_open() -> void:
	if player == null or _bag_widgets.is_empty():
		return
	
	# Nur refreshen, wenn wir wirklich im Inventar/Crafting/Furnace Modus sind
	if _mode != "inventory" and _mode != "table" and _mode != "furnace" and _mode != "anvil":
		return
	
	for entry in _bag_widgets:
		var bag_name = entry.get("bag", "")
		var index = entry.get("index", -1)
		var arr = _bag(bag_name)
		
		if index >= 0 and index < arr.size():
			_refresh_slot(entry["w"], arr[index])
	
	# Craft & Furnace nur wenn vorhanden
	if _craft_widgets.size() > 0 and _craft_cells.size() > 0:
		var min_size = min(_craft_widgets.size(), _craft_cells.size())
		for i in range(min_size):
			_refresh_slot(_craft_widgets[i], _craft_cells[i])
	
	if _active_furnace != null and not _furnace_widgets.is_empty():
		_refresh_slot(_furnace_widgets["input"], _active_furnace.input)
		_refresh_slot(_furnace_widgets["fuel"], _active_furnace.fuel)
		_refresh_slot(_furnace_widgets["output"], _active_furnace.output)
	# WICHTIG: Fokus NICHT hier zurücksetzen – das hat die D-Pad-Navigation zerstört
func _refresh_cursor() -> void:
	if _cursor_icon == null:
		_build_cursor()
	if _cursor_icon == null:
		return
	if _cursor == null:
		_cursor_icon.visible = false
		return
	_cursor_icon.visible = true
	_cursor_icon.z_index = 300
	_cursor_icon.z_as_relative = false
	_cursor_icon.move_to_front()
	_cursor_icon.texture = Textures.get_texture(str(_cursor.item_id))
	var mp = get_viewport().get_mouse_position()
	if _input_device == "controller":
		var panel = _get_focused_panel() if has_method("_get_focused_panel") else null
		if panel != null and is_instance_valid(panel):
			var gp = panel.get_global_rect()
			_cursor_icon.global_position = gp.position + Vector2(4, 4)
		else:
			_cursor_icon.global_position = mp - Vector2(SLOT, SLOT) / 2.0
	else:
		_cursor_icon.global_position = mp - Vector2(SLOT, SLOT) / 2.0
	_cursor_icon.move_to_front()
func _icon_state(value: float, idx: int) -> int:
	var threshold = (idx + 1) * 2

	if value >= threshold:
		return 2
	elif value >= threshold - 1:
		return 1
	else:
		return 0
func _refresh_stats() -> void:
	if player == null or _stats_box == null:
		return

	_stats_box.visible = player.game_mode != GameSettings.GameMode.CREATIVE
	if not _stats_box.visible:
		return

	var full_heart = Color(0.85, 0.1, 0.1)
	var half_heart = Color(0.5, 0.08, 0.08)
	var full_hunger = Color(0.8, 0.5, 0.15)
	var half_hunger = Color(0.5, 0.32, 0.1)
	var full_armor = Color(0.8, 0.85, 0.95)
	var empty = Color(0.18, 0.18, 0.2)

	var ap = player.armor_points()
	for i in range(10):
		_hearts[i].color = [empty, half_heart, full_heart][_icon_state(player.health, i)]
		_hunger[i].color = [empty, half_hunger, full_hunger][_icon_state(player.hunger, i)]
		_armor_bar[i].color = full_armor if _icon_state(ap, i) > 0 else empty
	if _air_row != null:
		var air := float(player.get("_air"))
		var max_air := maxf(float(player.get("_max_air")), 0.001)
		_air_row.visible = air < max_air - 0.01
		var bubbles := ceili(clampf(air / max_air, 0.0, 1.0) * 10.0)
		for i in range(_air_bar.size()):
			_air_bar[i].color = Color(0.25, 0.72, 1.0, 0.95) if i < bubbles else Color(0.08, 0.18, 0.24, 0.75)
		


func open_dispenser(disp, cell: Vector3i = Vector3i.ZERO) -> void:
	_mode = "dispenser"
	if _is_split:
		_input_device = "controller"
	if _panel:
		_panel.visible = true
	_active_dispenser = disp
	_dispenser_cell = cell
	_set_ui_mouse_mode(true)
	get_viewport().gui_disable_input = false

	if _creative_container:
		_creative_container.visible = false
	if _panel:
		_panel.visible = true

	_create_dispenser_ui()
	_refresh_dispenser_slots()
	
	
	
	if _input_device == "controller":
		_set_controller_slot_focus("dispenser", 0)



func open_hopper(inv, cell: Vector3i = Vector3i.ZERO) -> void:
	_mode = "dispenser"
	if _is_split:
		_input_device = "controller"
	_active_dispenser = inv
	_dispenser_cell = cell
	_set_ui_mouse_mode(true)
	get_viewport().gui_disable_input = false
	if _creative_container:
		_creative_container.visible = false
	if _panel:
		_panel.visible = true
	_create_dispenser_ui()
	# retitle
	if _dispenser_panel != null:
		for c in _dispenser_panel.get_children():
			if c is VBoxContainer:
				for ch in c.get_children():
					if ch is Label and ch.text == "Dispenser":
						ch.text = "Hopper"
						break
	_refresh_dispenser_slots()
	if _input_device == "controller":
		_set_controller_slot_focus("dispenser", 0)


func open_dropper(inv, cell: Vector3i = Vector3i.ZERO) -> void:
	_mode = "dispenser"
	if _is_split:
		_input_device = "controller"
	_active_dispenser = inv
	_dispenser_cell = cell
	_set_ui_mouse_mode(true)
	get_viewport().gui_disable_input = false
	if _creative_container:
		_creative_container.visible = false
	if _panel:
		_panel.visible = true
	_create_dispenser_ui()
	if _dispenser_panel != null:
		for c in _dispenser_panel.get_children():
			if c is VBoxContainer:
				for ch in c.get_children():
					if ch is Label and ch.text == "Dispenser":
						ch.text = "Dropper"
						break
	_refresh_dispenser_slots()
	if _input_device == "controller":
		_set_controller_slot_focus("dispenser", 0)


func _create_dispenser_ui() -> void:
	if has_node("DispenserPanel"):
		get_node("DispenserPanel").queue_free()
	_dispenser_panel = null
	_dispenser_widgets.clear()

	_dispenser_panel = Panel.new()
	_dispenser_panel.name = "DispenserPanel"

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.45)
	_dispenser_panel.add_theme_stylebox_override("panel", style)
	_dispenser_panel.custom_minimum_size = Vector2(280, 220)
	_dispenser_panel.position = Vector2(620, 140)
	_dispenser_panel.z_index = 30
	add_child(_dispenser_panel)
	_register_split_child(_dispenser_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	_dispenser_panel.add_child(vbox)

	var title = Label.new()
	title.text = "Dispenser"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	for i in range(9):
		var w = _make_slot()
		w["panel"].gui_input.connect(_on_dispenser_slot_input.bind(i))
		grid.add_child(w["panel"])
		_dispenser_widgets.append(w)

	var hint = Label.new()
	hint.text = "Items → dispensed on activate"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
	
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var dispense_btn = Button.new()
	dispense_btn.text = "Dispense"
	dispense_btn.pressed.connect(_on_dispense_pressed)
	btn_row.add_child(dispense_btn)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close)
	btn_row.add_child(close_btn)


func _on_dispense_pressed() -> void:
	var g = null
	if interactor != null:
		g = interactor.game
	if g == null:
		g = get_tree().current_scene
	if g != null and g.has_method("activate_dispenser"):
		g.activate_dispenser(_dispenser_cell)
	_refresh_dispenser_slots()


func _on_dispenser_slot_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _active_dispenser == null:
		return
	var arr = _active_dispenser.slots
	if index < 0 or index >= arr.size():
		return

	var current = arr[index]
	if _cursor == null:
		if current != null:
			_cursor = current
			arr[index] = null
	else:
		if current == null:
			arr[index] = _cursor
			_cursor = null
		elif current.stackable_with(_cursor):
			var move = mini(current.max_stack() - current.count, _cursor.count)
			current.count += move
			_cursor.count -= move
			if _cursor.count <= 0:
				_cursor = null
		else:
			var tmp = current
			arr[index] = _cursor
			_cursor = tmp

	_refresh_dispenser_slots()
	_refresh_cursor()


func _refresh_dispenser_slots() -> void:
	if _active_dispenser == null or _dispenser_widgets.is_empty():
		return
	for i in range(mini(9, _dispenser_widgets.size())):
		_refresh_slot(_dispenser_widgets[i], _active_dispenser.slots[i])


func open_chest(chest_slots: Array, cell: Vector3i = Vector3i.ZERO) -> void:
	if game == null and interactor != null and interactor.get("game") != null:
		game = interactor.game
	_mode = "chest"
	if _is_split:
		_input_device = "controller"
	_active_chest = chest_slots
	_chest_cell = cell
	_set_ui_mouse_mode(true)
	get_viewport().gui_disable_input = false

	if _creative_container:
		_creative_container.visible = false

	# Same approach as anvil: keep default centered inventory, overlay chest panel
	if _panel:
		_panel.visible = true
		_panel.set_anchors_preset(Control.PRESET_CENTER)
		_panel.offset_left = -550
		_panel.offset_right = 550
		_panel.offset_top = -310
		_panel.offset_bottom = 310
		_panel.custom_minimum_size = Vector2(1100, 620)
		_panel.z_index = 20

	_create_chest_ui()
	_refresh_chest_slots()
	if player != null and player.inventory != null:
		for entry in _bag_widgets:
			var arr = _bag(entry["bag"])
			var index = entry["index"]
			if index >= 0 and index < arr.size():
				_refresh_slot(entry["w"], arr[index])

	if _input_device == "controller":
		_set_controller_slot_focus("chest", 0)
		_update_focus_visual()


func _create_chest_ui() -> void:
	if _chest_panel != null and is_instance_valid(_chest_panel):
		_chest_panel.queue_free()
	elif has_node("ChestPanel"):
		get_node("ChestPanel").queue_free()
	_chest_panel = null
	_chest_widgets.clear()

	_chest_panel = Panel.new()
	_chest_panel.name = "ChestPanel"

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.12, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.45, 0.38, 0.22)
	_chest_panel.add_theme_stylebox_override("panel", style)
	# Overlay upper-center like anvil panel (inventory stays default centered under it)
	_chest_panel.set_anchors_preset(Control.PRESET_CENTER)
	_chest_panel.offset_left = -200
	_chest_panel.offset_right = 200
	_chest_panel.offset_top = -300
	_chest_panel.offset_bottom = -40
	_chest_panel.custom_minimum_size = Vector2(400, 260)
	_chest_panel.z_index = 40
	_chest_panel.visible = true
	_chest_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_chest_panel)
	_chest_panel.move_to_front()
	_register_split_child(_chest_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	_chest_panel.add_child(vbox)

	var title = Label.new()
	title.text = "Chest"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var grid = GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(grid)

	for i in range(27):
		var w = _make_slot()
		var idx = i
		w["panel"].gui_input.connect(_on_chest_slot_input.bind(idx))
		# Hover / tooltip / controller focus parity with inventory slots
		w["panel"].mouse_entered.connect(func():
			if _input_device == "controller":
				return
			_hovered_slot = {"bag": "chest", "index": idx}
			if idx < _active_chest.size() and _active_chest[idx] != null:
				_show_item_tooltip(_active_chest[idx].item_id, get_viewport().get_mouse_position())
		)
		w["panel"].mouse_exited.connect(func():
			if _input_device == "controller":
				return
			if _hovered_slot.get("bag", "") == "chest" and int(_hovered_slot.get("index", -1)) == idx:
				_hovered_slot = {}
				_hide_item_tooltip()
		)
		grid.add_child(w["panel"])
		_chest_widgets.append(w)

	var hint = Label.new()
	hint.text = "Click / A = move items | LB/RB = switch panels"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)


func _on_chest_slot_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _active_chest.is_empty():
		return
	if index < 0 or index >= _active_chest.size():
		return

	var current = _active_chest[index]
	if _cursor == null:
		if current != null:
			_cursor = current
			_active_chest[index] = null
	else:
		if current == null:
			_active_chest[index] = _cursor
			_cursor = null
		elif current.stackable_with(_cursor):
			var move = mini(current.max_stack() - current.count, _cursor.count)
			current.count += move
			_cursor.count -= move
			if _cursor.count <= 0:
				_cursor = null
		else:
			var tmp = current
			_active_chest[index] = _cursor
			_cursor = tmp

	_refresh_chest_slots()
	_refresh_cursor()


func _refresh_chest_slots() -> void:
	if _active_chest.is_empty() or _chest_widgets.is_empty():
		return
	for i in range(mini(27, _chest_widgets.size())):
		var stack = _active_chest[i] if i < _active_chest.size() else null
		_refresh_slot(_chest_widgets[i], stack)


func open_enchant() -> void:
	# Real inventory UI (same system as anvil/chest) — NOT a separate hotbar-only panel
	_mode = "enchant"
	if _is_split:
		_input_device = "controller"
	_set_ui_mouse_mode(true)
	get_viewport().gui_disable_input = false
	if _creative_container:
		_creative_container.visible = false
	# Show normal inventory so player can pick Lapis / tools with UI cursor
	if _panel:
		_panel.visible = true
	_close_enchant_panel()
	_create_enchant_ui()
	if _enchant_panel:
		_enchant_panel.visible = true
		_enchant_panel.set_anchors_preset(Control.PRESET_CENTER)
		_enchant_panel.offset_left = -220
		_enchant_panel.offset_right = 220
		_enchant_panel.offset_top = -340
		_enchant_panel.offset_bottom = -40
		_enchant_panel.custom_minimum_size = Vector2(440, 300)
		_enchant_panel.z_index = 40
		_enchant_panel.move_to_front()
	_refresh_open()
	_refresh_enchant_slots()
	_update_enchant_offers()
	_refresh_cursor()
	# Always prepare controller focus (works as soon as a pad is used)
	_set_controller_slot_focus("enchant", 0)
	_update_focus_visual()
	_position_focus_cursor()
	print("[GameUI] enchant open, controller focus on enchant slots")


func _close_enchant_panel() -> void:
	if _enchant_panel != null and is_instance_valid(_enchant_panel):
		# Return items from slots to inventory
		_return_enchant_slots()
		_enchant_panel.queue_free()
	_enchant_panel = null
	_enchant_item = {}
	_enchant_lapis = {}
	_enchant_offers.clear()
	_enchant_offer_btns.clear()
	_enchant_label = null


func _return_enchant_slots() -> void:
	for slot in [_enchant_item, _enchant_lapis]:
		if slot is Dictionary and slot.get("item") != null and player != null and player.inventory != null:
			var s = slot["item"]
			player.inventory.add(s.item_id, s.count)
			slot["item"] = null


func _create_enchant_ui() -> void:
	_enchant_panel = Panel.new()
	_enchant_panel.name = "EnchantPanel"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.16, 0.96)
	style.border_color = Color(0.5, 0.4, 0.75)
	style.set_border_width_all(2)
	_enchant_panel.add_theme_stylebox_override("panel", style)
	add_child(_enchant_panel)
	if has_method("_register_split_child"):
		_register_split_child(_enchant_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 10
	vbox.offset_right = -12
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 8)
	_enchant_panel.add_child(vbox)

	var title = Label.new()
	title.text = "Enchanting Table"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var hint = Label.new()
	hint.text = "Use inventory cursor: put tool in left, Lapis Lazuli in right"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 28)
	vbox.add_child(hbox)

	_enchant_item = _make_anvil_slot()
	_enchant_item["panel"].gui_input.connect(_on_enchant_slot_input.bind("item"))
	hbox.add_child(_enchant_item["panel"])

	_enchant_lapis = _make_anvil_slot()
	_enchant_lapis["panel"].gui_input.connect(_on_enchant_slot_input.bind("lapis"))
	hbox.add_child(_enchant_lapis["panel"])

	_enchant_label = Label.new()
	_enchant_label.text = "Place item + Lapis Lazuli"
	_enchant_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_enchant_label)

	_enchant_offer_btns.clear()
	for i in range(3):
		var b = Button.new()
		b.text = "—"
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(400, 36)
		b.pressed.connect(_on_enchant_offer.bind(i))
		vbox.add_child(b)
		_enchant_offer_btns.append(b)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.focus_mode = Control.FOCUS_ALL
	close_btn.pressed.connect(func():
		_close_enchant_panel()
		_mode = "closed"
		if _panel:
			_panel.visible = false
		_set_ui_mouse_mode(false)
	)
	vbox.add_child(close_btn)


func _is_lapis_id(id: String) -> bool:
	var s = id.to_lower()
	return s == "lapis_lazuli" or s == "lapis" or s.ends_with("lapis_lazuli")


func _on_enchant_slot_input(event: InputEvent, which: String) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var slot_dict: Dictionary = _enchant_item if which == "item" else _enchant_lapis
	var current = slot_dict.get("item")

	if _cursor == null:
		if current != null:
			_cursor = current
			slot_dict["item"] = null
	else:
		# Lapis slot only accepts lapis
		if which == "lapis" and not _is_lapis_id(str(_cursor.item_id)):
			return
		# Item slot: no pure lapis as the enchanted target
		if which == "item" and _is_lapis_id(str(_cursor.item_id)):
			return
		if current == null:
			slot_dict["item"] = _cursor
			_cursor = null
		elif current.stackable_with(_cursor):
			var move = mini(current.max_stack() - current.count, _cursor.count)
			current.count += move
			_cursor.count -= move
			if _cursor.count <= 0:
				_cursor = null
		else:
			var temp = current
			slot_dict["item"] = _cursor
			_cursor = temp

	_refresh_enchant_slots()
	_update_enchant_offers()
	_refresh_open()
	_refresh_cursor()


func _refresh_enchant_slots() -> void:
	if _enchant_item is Dictionary and _enchant_item.has("panel"):
		_refresh_slot(_enchant_item, _enchant_item.get("item"))
	if _enchant_lapis is Dictionary and _enchant_lapis.has("panel"):
		_refresh_slot(_enchant_lapis, _enchant_lapis.get("item"))


func _update_enchant_offers() -> void:
	_enchant_offers.clear()
	var item = _enchant_item.get("item") if _enchant_item is Dictionary else null
	var lapis = _enchant_lapis.get("item") if _enchant_lapis is Dictionary else null
	var lapis_n = 0
	if lapis != null and _is_lapis_id(str(lapis.item_id)):
		lapis_n = int(lapis.count)

	if item == null:
		if _enchant_label:
			_enchant_label.text = "Place item + Lapis Lazuli"
		for b in _enchant_offer_btns:
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
		_enchant_offers.append({"id": eid, "level": lvl, "cost": cost})

	for i in range(3):
		if i < _enchant_offers.size():
			var o = _enchant_offers[i]
			_enchant_offer_btns[i].text = "%s %d  (%d Lapis)" % [str(o.id).capitalize(), o.level, o.cost]
			_enchant_offer_btns[i].disabled = lapis_n < int(o.cost)
		else:
			_enchant_offer_btns[i].text = "—"
			_enchant_offer_btns[i].disabled = true
	if _enchant_label:
		_enchant_label.text = "Lapis available: %d" % lapis_n


func _on_enchant_offer(i: int) -> void:
	if i < 0 or i >= _enchant_offers.size():
		return
	var item = _enchant_item.get("item") if _enchant_item is Dictionary else null
	var lapis = _enchant_lapis.get("item") if _enchant_lapis is Dictionary else null
	if item == null or lapis == null:
		return
	var o = _enchant_offers[i]
	var cost = int(o.cost)
	if int(lapis.count) < cost:
		return
	lapis.count -= cost
	if lapis.count <= 0:
		_enchant_lapis["item"] = null
	if not ("enchantments" in item) or item.enchantments == null:
		item.enchantments = {}
	item.enchantments[str(o.id)] = int(o.level)
	if str(item.item_id) == "book":
		item.item_id = "enchanted_book"
	# Enchanted item stays in slot; player can pick it up with cursor
	_refresh_enchant_slots()
	_update_enchant_offers()
	_refresh_open()
	Audio.play("ui_click")



func _unhandled_key_recipe(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R and _mode in ["inventory", "closed", "pause"]:
		open_recipe_book()
		get_viewport().set_input_as_handled()

func open_recipe_book() -> void:
	_mode = "recipe_book"
	_set_ui_mouse_mode(true)
	get_viewport().gui_disable_input = false
	var book = RecipeBookUI.new()
	book.name = "RecipeBookUI"
	add_child(book)
	book.setup()
	book.closed.connect(func():
		if is_instance_valid(book):
			book.queue_free()
		if _mode == "recipe_book":
			_mode = "closed"
			_set_ui_mouse_mode(false)
	)



func _show_achievements() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var panel = Panel.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.12, 0.15, 0.96)
	st.set_border_width_all(2)
	st.border_color = Color(0.5, 0.45, 0.2)
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(400, 360)
	panel.position = Vector2(180, 100)
	layer.add_child(panel)
	var v = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(v)
	var title = Label.new()
	title.text = "Achievements"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	v.add_child(title)
	var defs = {
		"open_inventory": "Taking Inventory",
		"mine_stone": "Stone Age",
		"plant_wheat": "A Seedy Place",
		"ride_boat": "Whatever Floats",
		"ride_minecart": "On A Rail",
		"kill_boss": "Godslayer",
	}
	for k in defs.keys():
		var l = Label.new()
		l.text = "• " + defs[k]
		v.add_child(l)
	var close = Button.new()
	close.text = "Close"
	close.pressed.connect(func():
		layer.queue_free()
		_mode = "closed"
		_set_ui_mouse_mode(false)
	)
	v.add_child(close)
	_mode = "achievements"
	_set_ui_mouse_mode(true)


var _effect_hud: VBoxContainer = null
var _brew_stand = null
var _brew_cell: Vector3i = Vector3i.ZERO
var _brew_panel: Panel = null


func _build_effect_hud() -> void:
	_effect_hud = VBoxContainer.new()
	_effect_hud.name = "EffectHUD"
	_effect_hud.position = Vector2(12, 80)
	_effect_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_effect_hud)


func _refresh_effect_hud() -> void:
	if _effect_hud == null or player == null:
		return
	for c in _effect_hud.get_children():
		c.queue_free()
	if not ("active_effects" in player):
		return
	for eid in player.active_effects.keys():
		var data = player.active_effects[eid]
		var dur = int(ceil(float(data.get("duration", 0.0))))
		var amp = int(data.get("amplifier", 0))
		var l = Label.new()
		var roman = Registry.roman_level(amp + 1) if Registry.has_method("roman_level") else str(amp + 1)
		l.text = "%s %s  %ds" % [str(eid).replace("_", " ").capitalize(), roman, dur]
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		_effect_hud.add_child(l)


func set_boss_bar(title: String, frac: float) -> void:
	if title == "":
		hide_boss_bar()
		return
	if _boss_bar == null:
		show_boss_bar(title, 1.0)
	else:
		_boss_label.text = title
		_boss_bar.visible = true
		_boss_label.visible = true
	_boss_bar.max_value = 1.0
	_boss_bar.value = clampf(frac, 0.0, 1.0)


func open_brewing(stand, cell: Vector3i) -> void:
	_brew_stand = stand
	_brew_cell = cell
	_mode = "brewing"
	_set_ui_mouse_mode(true)
	if _brew_panel != null and is_instance_valid(_brew_panel):
		_brew_panel.queue_free()
	_brew_panel = Panel.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.1, 0.16, 0.96)
	st.border_color = Color(0.55, 0.35, 0.7)
	st.set_border_width_all(2)
	_brew_panel.add_theme_stylebox_override("panel", st)
	_brew_panel.custom_minimum_size = Vector2(360, 280)
	_brew_panel.position = Vector2(200, 80)
	add_child(_brew_panel)
	var v = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_top = 12
	v.offset_right = -12
	v.offset_bottom = -12
	_brew_panel.add_child(v)
	var title = Label.new()
	title.text = "Brewing Stand"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	v.add_child(title)
	var hint = Label.new()
	hint.text = "Bottles + ingredient + Blaze Powder. Water bottle + Nether Wart = Awkward."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for i in range(3):
		var b = Button.new()
		b.custom_minimum_size = Vector2(64, 64)
		b.text = _brew_slot_text(stand.bottles[i] if stand else null)
		var idx = i
		b.pressed.connect(func(): _brew_click_bottle(idx))
		row.add_child(b)
	var ing = Button.new()
	ing.text = "Ingredient: " + _brew_slot_text(stand.ingredient if stand else null)
	ing.pressed.connect(func(): _brew_click_ing())
	v.add_child(ing)
	var fuel = Button.new()
	fuel.text = "Blaze Powder: " + _brew_slot_text(stand.fuel if stand else null)
	fuel.pressed.connect(func(): _brew_click_fuel())
	v.add_child(fuel)
	var close = Button.new()
	close.text = "Close"
	close.pressed.connect(func():
		if _brew_panel:
			_brew_panel.queue_free()
		_brew_panel = null
		_mode = "closed"
		_set_ui_mouse_mode(false)
	)
	v.add_child(close)


func _brew_slot_text(stack) -> String:
	if stack == null:
		return "(empty)"
	return str(stack.item_id) + " x" + str(stack.count)


func _brew_take_or_put(current):
	if _cursor != null and current == null:
		var one = ItemStack.new(_cursor.item_id, 1)
		_cursor.count -= 1
		if _cursor.count <= 0:
			_cursor = null
		_refresh_cursor()
		return one
	if _cursor == null and current != null:
		_cursor = current
		_refresh_cursor()
		return null
	return current


func _brew_click_bottle(i: int) -> void:
	if _brew_stand == null:
		return
	_brew_stand.bottles[i] = _brew_take_or_put(_brew_stand.bottles[i])
	open_brewing(_brew_stand, _brew_cell)


func _brew_click_ing() -> void:
	if _brew_stand == null:
		return
	_brew_stand.ingredient = _brew_take_or_put(_brew_stand.ingredient)
	open_brewing(_brew_stand, _brew_cell)


func _brew_click_fuel() -> void:
	if _brew_stand == null:
		return
	_brew_stand.fuel = _brew_take_or_put(_brew_stand.fuel)
	open_brewing(_brew_stand, _brew_cell)
