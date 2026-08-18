class_name BlockInteractor
extends Node3D
# Block breaking (hold LMB, time scales with hardness) and placing (RMB) via a
# voxel raycast from the camera. Mined blocks drop into the player inventory;
# placing consumes the held hotbar item. A wireframe box highlights the target.
# Interaction is disabled while the mouse is freed (inventory open).

var _dispenser_cell: Vector3i = Vector3i.ZERO
var _lt_was_down: bool = false
var _rb_was_down: bool = false
var _x_was_down: bool = false
var _rt_was_down: bool = false
var _lmb_was_down: bool = false
var _rmb_was_down: bool = false
var world
var renderer
var camera: Camera3D
var player: Node3D
var ui
var game
var reach: float = 6.0

var _highlight: MeshInstance3D
var _mining_cell: Vector3i = Vector3i.ZERO
var _has_target: bool = false
var _mining_progress: float = 0.0
var _dig_timer: float = 0.0



func setup(p_world, p_renderer, p_player: Node3D) -> void:
	world = p_world
	renderer = p_renderer
	player = p_player
	camera = null
	if p_player != null:
		if p_player.has_node("Head/Camera3D"):
			camera = p_player.get_node("Head/Camera3D")
		else:
			camera = p_player.find_child("Camera3D", true, false)
	set_process(true)
	set_process_unhandled_input(true)



func _split_index() -> int:
	# Nutzt den split_index vom Player (-1 = Solo, 0..3 = Split-Screen-Slot).
	if player != null and "split_index" in player:
		return player.split_index
	return -1


func _joy_device() -> int:
	if _is_split():
		return maxi(_split_index(), 0)
	var pads = Input.get_connected_joypads()
	if pads.size() > 0:
		return pads[0]
	return 0


func _is_split() -> bool:
	# Solo: split_index is -1. Split players are 0..3 AND their UI is marked split.
	if player == null or int(player.split_index) < 0:
		return false
	if ui != null and is_instance_valid(ui) and bool(ui.get("is_split")):
		return true
	# Player has a split slot index even if UI flag missing
	return int(player.split_index) >= 0


func _ready() -> void:
	if game == null:
		game = get_parent()
	_highlight = _make_highlight()
	add_child(_highlight)
	_highlight.visible = false
	set_process(true)
	set_process_unhandled_input(true)
				
				



func held_block_id() -> String:
	if player == null or player.inventory == null:
		return ""
	var s = player.inventory.held()
	if s != null and Registry.blocks.has(s.item_id):
		return s.item_id
	return ""


func _inv_ok() -> bool:
	return player != null and is_instance_valid(player) and player.inventory != null


func _active() -> bool:
	if ui != null and is_instance_valid(ui):
		var m := str(ui._mode)
		return m == "closed" or m.is_empty()
	# No UI: still allow combat/interact
	return true


var _plate_cell: Vector3i = Vector3i.ZERO
var _plate_on: bool = false

func _check_pressure_plate() -> void:
	if world == null or player == null:
		return
	# Pressure plates are thin; check both the cell under the feet and the
	# cell the player is standing in (in case the plate has no collision).
	var feet = player.global_position
	var candidates: Array[Vector3i] = [
		Vector3i(floori(feet.x), floori(feet.y - 0.05), floori(feet.z)),
		Vector3i(floori(feet.x), floori(feet.y) - 1, floori(feet.z)),
		Vector3i(floori(feet.x), floori(feet.y), floori(feet.z))
	]
	var standing_on_plate := false
	var cell := Vector3i.ZERO
	var id := ""
	for c in candidates:
		var bid = world.get_block(c.x, c.y, c.z)
		if bid == "pressure_plate" or bid == "pressure_plate_on":
			standing_on_plate = true
			cell = c
			id = bid
			break

	if standing_on_plate and not _plate_on:
		_plate_on = true
		_plate_cell = cell
		if id != "pressure_plate_on":
			world.set_block(cell.x, cell.y, cell.z, "pressure_plate_on")
			if renderer:
				renderer.edit_block(cell.x, cell.y, cell.z, "pressure_plate_on")
			Redstone.pulse(game, world, renderer, cell)
	elif not standing_on_plate and _plate_on:
		_plate_on = false
		var old_id = world.get_block(_plate_cell.x, _plate_cell.y, _plate_cell.z)
		if old_id == "pressure_plate_on":
			world.set_block(_plate_cell.x, _plate_cell.y, _plate_cell.z, "pressure_plate")
			if renderer:
				renderer.edit_block(_plate_cell.x, _plate_cell.y, _plate_cell.z, "pressure_plate")
			Redstone.pulse(game, world, renderer, _plate_cell)


func _process(delta: float) -> void:
	_check_pressure_plate()

	# Rebind camera if lost
	if (camera == null or not is_instance_valid(camera)) and player != null:
		if player.has_node("Head/Camera3D"):
			camera = player.get_node("Head/Camera3D")
		else:
			camera = player.find_child("Camera3D", true, false)

	if camera == null or not _active():
		if _highlight != null:
			_highlight.visible = false
		_has_target = false
		_lmb_was_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		_rmb_was_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		return

	# ===== MOUSE (polling) =====
	# LMB = attack (edge) + mine while held  |  RMB = use/place
	if not _is_split() or _split_index() <= 0:
		var lmb = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if lmb and not _lmb_was_down:
			_attack()
		_lmb_was_down = lmb
		var rmb = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if rmb and not _rmb_was_down:
			_do_use_action()
		_rmb_was_down = rmb

	# ===== CONTROLLER via HCPad (Xbox / PlayStation / Switch / generic SDL map) =====
	var dev2 = _joy_device()

	# LT = use / place / talk (chest, villager, anvil, …)
	var lt_down = HCPad.lt_held(dev2)
	if lt_down and not _lt_was_down:
		_do_use_action()
	_lt_was_down = lt_down

	# RT = attack on press + mine while held (Minecraft left-click)
	var rt_down = HCPad.rt_held(dev2)
	if rt_down and not _rt_was_down:
		_attack()
	_rt_was_down = rt_down

	# X / Square / left-face = attack
	var x_down = HCPad.pressed(dev2, HCPad.BTN_ATTACK_ALT)
	if x_down and not _x_was_down:
		_attack()
	_x_was_down = x_down

	# RB = use / place
	var rb_down = HCPad.pressed(dev2, HCPad.BTN_RB)
	if rb_down and not _rb_was_down:
		_do_use_action()
	_rb_was_down = rb_down

	var origin = camera.global_position
	var dir = -camera.global_transform.basis.z
	var hit = VoxelRaycast.cast(world, origin, dir, reach)

	if hit.get("ok", false):
		_highlight.visible = true
		_highlight.global_position = Vector3(hit["hit"])
	else:
		_highlight.visible = false

	var mine_held = false
	# Maus: Solo oder Split-Spieler 0
	if not _is_split() or _split_index() <= 0:
		mine_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	# Controller: Solo UND Split (RT oder LB halten)
	if not mine_held:
		var dev = _joy_device()
		if HCPad.rt_held(dev):
			mine_held = true
		elif HCPad.pressed(dev, HCPad.BTN_LB):
			mine_held = true

	if mine_held and hit.get("ok", false) \
			and GameSettings.can_break_place(player.game_mode):
		_mine(hit["hit"], delta)
	else:
		_has_target = false
		_mining_progress = 0.0


func _mine(cell: Vector3i, delta: float) -> void:
	if not _inv_ok():
		return
	if not _has_target or cell != _mining_cell:
		_mining_cell = cell
		_mining_progress = 0.0
		_dig_timer = 0.0
		_has_target = true

	var bid = world.get_block(cell.x, cell.y, cell.z)
	var bt = _break_time(bid)
	if bt < 0.0:
		return

	_mining_progress += delta
	_dig_timer += delta

	if _dig_timer >= 0.25:
		_dig_timer = 0.0
		Audio.play(Audio.dig_group(bid))

	if _mining_progress >= bt:
		if _can_harvest(bid):
			_collect_drops(bid)
			_wear_tool()
		renderer.edit_block(cell.x, cell.y, cell.z, "air")
		Audio.play("break")
		_has_target = false
		_mining_progress = 0.0


func _collect_drops(bid: String) -> void:
	var b = Registry.get_block(bid)
	if b == null:
		return
	var drops = b.get("drops", [])
	if drops.is_empty():
		player.inventory.add(bid, 1)
	else:
		for d in drops:
			player.inventory.add(d[0], int(d[1]))


func _held_tool() -> Dictionary:
	var s = player.inventory.held()
	if s == null:
		return {}
	var it = Registry.get_item(s.item_id)
	if it == null or it.get("type", "") != "tool":
		return {}
	return it


func _can_harvest(bid: String) -> bool:
	var b = Registry.get_block(bid)
	if b == null:
		return true
	var req = int(b.get("tier", 0))
	if req <= 0:
		return true
	var tool = _held_tool()
	if tool.is_empty():
		return false
	if tool.get("tool_type", "") != b.get("tool", ""):
		return false
	return int(tool.get("tier", 0)) >= req


func _wear_tool() -> void:
	if not GameSettings.uses_durability(player.game_mode):
		return
	var s = player.inventory.held()
	if s == null or s.durability < 0:
		return
	s.durability -= 1
	if s.durability <= 0:
		player.inventory.hotbar[player.inventory.selected] = null
		Audio.play("break")


func _break_time(bid: String) -> float:
	var b = Registry.get_block(bid)
	if b == null:
		return 0.2
	var h = float(b.get("hardness", 1.0))
	if h < 0.0:
		return -1.0
	var speed = 1.0
	var tool = _held_tool()
	if not tool.is_empty() and tool.get("tool_type", "") == b.get("tool", ""):
		speed = 1.0 + int(tool.get("tier", 0)) * 1.5
	return maxf(0.05, h * 1.5 / speed)


func _unhandled_input(event: InputEvent) -> void:
	if not _active():
		return

	# ---------- Maus: nur Solo oder Split-Spieler 1 (geteilte Maus) ----------
	if event is InputEventMouseButton and event.pressed:
		if _is_split() and _split_index() > 0:
			return  # Maus gehört P1, andere Split-Spieler ignorieren sie
		if event.button_index == MOUSE_BUTTON_LEFT:
			_attack()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_do_use_action()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if player != null and player.inventory != null:
				player.inventory.scroll(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if player != null and player.inventory != null:
				player.inventory.scroll(1)
		return

	# ---------- Tastatur: nur Solo oder Split-Spieler 1 ----------
	if event is InputEventKey and event.pressed and not event.echo:
		if _is_split() and _split_index() > 0:
			return  # Tastatur gehört P1
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			if player != null and player.inventory != null:
				player.inventory.select(event.keycode - KEY_1)
		return

	# ---------- Gamepad: jeder Split-Spieler über sein eigenes Gerät ----------
	if event is InputEventJoypadButton and event.pressed:
		if _is_split() and event.device != _joy_device():
			return

		match event.button_index:
			HCPad.BTN_ATTACK_ALT:
				_attack()
			HCPad.BTN_RB:
				_do_use_action()
			HCPad.BTN_DPAD_LEFT:
				if player != null and player.inventory != null:
					player.inventory.scroll(-1)
			HCPad.BTN_DPAD_RIGHT:
				if player != null and player.inventory != null:
					player.inventory.scroll(1)


func _do_use_action() -> void:
	if _try_use_spawn_egg():
		return
	if _try_use_fishing_rod():
		return
	if _try_talk():
		return
	_try_place()
	if _try_eat():
		return
	_try_firework()


func _try_use_spawn_egg() -> bool:
	if not _inv_ok() or player == null or camera == null:
		return false
	var held = player.inventory.held()
	if held == null:
		return false
	var iid = str(held.item_id)
	if not iid.begins_with("spawn_egg_"):
		return false
	var mob_id = iid.substr("spawn_egg_".length())
	if mob_id.is_empty():
		return false
	# Ray to place position
	var dir = -camera.global_transform.basis.z
	var hit = VoxelRaycast.cast(world, camera.global_position, dir, reach)
	var pos: Vector3
	if hit.get("ok", false):
		var cell = hit.get("place", hit["hit"])
		pos = Vector3(cell.x + 0.5, cell.y + 1.0, cell.z + 0.5)
	else:
		pos = camera.global_position + dir * 3.0
	var g = game
	if g == null:
		g = get_parent()
	if g != null and g.get("mob_manager") != null:
		g.mob_manager.spawn(mob_id, pos)
	elif g != null and g.has_method("spawn_mob"):
		g.spawn_mob(mob_id, pos)
	else:
		return false
	if not GameSettings.unlimited_blocks(player.game_mode):
		player.inventory.consume_held(1)
	Audio.play("place")
	return true


func _try_place() -> void:
	if player == null or camera == null or world == null:
		return

	# Name Tag auf Mobs
	if _inv_ok() and _try_name_tag_on_mob():
		return

	var dir = -camera.global_transform.basis.z
	var hit = VoxelRaycast.cast(world, camera.global_position, dir, reach)
	if not hit.get("ok", false):
		return

	var cell = hit["hit"]
	var target = str(world.get_block(cell.x, cell.y, cell.z))

	# Chests, doors, anvils, etc. — always interactable
	if _try_open_station(target, cell):
		return
	if _try_ignite_tnt(hit):
		return
	if _try_ignite(hit, target):
		return
	if _inv_ok() and _try_place_boat(hit, target):
		return
	if _inv_ok() and _try_place_minecart(hit, target):
		return

	# Only block placement needs break/place permission + inventory
	if not GameSettings.can_break_place(player.game_mode):
		return
	if not _inv_ok():
		return
	_try_place_block(hit)


func _try_place_minecart(hit: Dictionary, target: String) -> bool:
	var held = player.inventory.held()
	if held == null or held.item_id != "minecart":
		return false
	var cell: Vector3i = hit["hit"]
	# Prefer placing on a rail
	var rail_cell = cell
	if target != "rail" and target != "powered_rail" and target != "detector_rail":
		if hit.has("place"):
			rail_cell = hit["place"]
			var bid = world.get_block(rail_cell.x, rail_cell.y, rail_cell.z)
			# place on top of solid, need rail at that cell — require looking at rail
			if bid != "rail" and bid != "powered_rail" and bid != "detector_rail":
				return false
		else:
			return false
	var cart = Minecart.new()
	var root = get_tree().current_scene
	if root == null:
		root = game if game != null else get_parent()
	root.add_child(cart)
	cart.global_position = Vector3(rail_cell.x + 0.5, rail_cell.y + 0.35, rail_cell.z + 0.5)
	cart.world = world
	cart.game = game
	if not GameSettings.unlimited_blocks(player.game_mode):
		player.inventory.consume_held(1)
	Audio.play("place")
	return true


func _try_place_boat(hit: Dictionary, target: String) -> bool:
	var held = player.inventory.held()
	if held == null or held.item_id != "boat":
		return false
	# Place on water surface or on top of solid block
	var cell: Vector3i = hit["hit"]
	var place_pos: Vector3
	if target == "water":
		place_pos = Vector3(cell.x + 0.5, cell.y + 0.55, cell.z + 0.5)
	else:
		# place on adjacent "place" face if available
		if hit.has("place"):
			var pc: Vector3i = hit["place"]
			place_pos = Vector3(pc.x + 0.5, pc.y + 0.2, pc.z + 0.5)
		else:
			place_pos = Vector3(cell.x + 0.5, cell.y + 1.2, cell.z + 0.5)
	var boat = Boat.new()
	var root = get_tree().current_scene
	if root == null:
		root = game if game != null else get_parent()
	root.add_child(boat)
	boat.global_position = place_pos
	if not GameSettings.unlimited_blocks(player.game_mode):
		player.inventory.consume_held(1)
	Audio.play("place")
	return true



func _try_ignite(hit: Dictionary, target: String) -> bool:
	var held = player.inventory.held()
	if held == null or held.item_id != "flint_and_steel":
		return false

	if target != "obsidian":
		return false

	var base = hit["place"]

	# Erzeuge ein einfaches 2 breit × 3 hoch Portal
	for y in range(3):
		for x in range(-1, 2):
			var px = base.x + x
			var py = base.y + y
			var pz = base.z

			var current = world.get_block(px, py, pz)
			if current == "obsidian" or current == "air":
				renderer.edit_block(px, py, pz, "nether_portal")

	Audio.play("place")
	print("DEBUG: Portal wurde erzeugt!")
	return true


func _try_talk() -> bool:
	if player == null or camera == null:
		return false

	var space = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from + (-camera.global_transform.basis.z) * reach
	var q = PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 2
	var hit = space.intersect_ray(q)

	if hit.is_empty():
		return false

	var col = hit.get("collider")
	if col != null and col.has_method("can_trade"):
		if ui != null:
			ui.open_trades(col)
		return true
		
	if col is Boat or (col.get_parent() is Boat):
		var boat = col if col is Boat else col.get_parent()
		boat.try_mount(player)
		return true

	if col is Minecart or (col.get_parent() is Minecart):
		var cart = col if col is Minecart else col.get_parent()
		cart.try_mount(player)
		return true

	return false


func _try_eat() -> bool:
	if not _inv_ok():
		return false
	var held = player.inventory.held()
	if held == null:
		return false
	var it = Registry.get_item(held.item_id)
	if it == null or it.get("type", "") != "food":
		return false
	if player.eat(held.item_id):
		player.inventory.consume_held(1)
		Audio.play("click")
		return true
	return false
	
func _toggle_door(cell: Vector3i) -> void:
	if world == null or renderer == null:
		return
	var current = world.get_block(cell.x, cell.y, cell.z)
	var new_id = "door_oak_open" if current == "door_oak" else "door_oak"
	if not Registry.blocks.has(new_id):
		print("DEBUG: Registry hat '", new_id, "' nicht!")
		Audio.play("click")
		return
	renderer.edit_block(cell.x, cell.y, cell.z, new_id)
	Audio.play("place")

func _toggle_trapdoor(cell: Vector3i) -> void:
	if world == null or renderer == null:
		return
	var current = world.get_block(cell.x, cell.y, cell.z)
	var new_id = "trapdoor_oak_open" if current == "trapdoor_oak" else "trapdoor_oak"
	if not Registry.blocks.has(new_id):
		print("DEBUG: Registry hat '", new_id, "' nicht!")
		Audio.play("click")
		return
	renderer.edit_block(cell.x, cell.y, cell.z, new_id)
	Audio.play("place")


func _toggle_fence_gate(cell: Vector3i) -> void:
	if world == null or renderer == null:
		return
	var current = world.get_block(cell.x, cell.y, cell.z)
	var new_id = "fence_gate_oak_open" if current == "fence_gate_oak" else "fence_gate_oak"
	if not Registry.blocks.has(new_id):
		# Fallback: still toggle if only one exists
		if current == "fence_gate_oak":
			new_id = "fence_gate_oak_open"
		else:
			new_id = "fence_gate_oak"
	renderer.edit_block(cell.x, cell.y, cell.z, new_id)
	Audio.play("click")


func _try_open_station(target: String, cell: Vector3i) -> bool:
	if ui == null and player != null and player.has_meta("ui"):
		ui = player.get_meta("ui")
	if ui == null:
		return false
		
	if target == "door_oak" or target == "door_oak_open":
		_toggle_door(cell)
		return true

	if target == "trapdoor_oak" or target == "trapdoor_oak_open":
		_toggle_trapdoor(cell)
		return true

	if target == "fence_gate_oak" or target == "fence_gate_oak_open":
		_toggle_fence_gate(cell)
		return true

	if ui == null:
		return false

	match target:
		"anvil":
			if ui.has_method("open_anvil"):
				ui.open_anvil()
				return true
			return false
		"crafting_table", "toolbench":
			ui.open_table()
			return true
		"furnace":
			if game != null:
				ui.open_furnace(game.get_furnace(cell))
			return true
		"bed":
			if game != null:
				game.sleep()
			return true
		"jukebox":
			var held = player.inventory.held()

			if held != null:
				var it = Registry.get_item(held.item_id)
				if it != null and it.get("type", "") == "record":
			# Schallplatte abspielen
					Music.play_event(it.get("track", ""), "Game Music")
					player.inventory.consume_held(1)   # Platte wird verbraucht (oder später auswerfen)
					return true
				else:
					print("Das ist keine Schallplatte")
			else:
				print("Jukebox angeklickt (keine Platte in der Hand)")
				return true
		

		"dispenser":
			if game != null and ui.has_method("open_dispenser"):
				var disp = game.get_dispenser(cell)
				if disp != null:
					ui.open_dispenser(disp, cell)
					return true
			return false
		"chest":
			if game != null and ui.has_method("open_chest"):
				ui.open_chest(game.get_chest(cell), cell)
				return true
			return false
		"hopper":
			if game != null and ui.has_method("open_hopper"):
				ui.open_hopper(game.get_hopper(cell), cell)
				return true
			return false
		"dropper":
			if game != null and ui.has_method("open_dropper"):
				ui.open_dropper(game.get_dropper(cell), cell)
				return true
			return false
		"dispenser":
			if game != null and ui.has_method("open_dispenser"):
				ui.open_dispenser(game.get_dispenser(cell), cell)
				return true
			return false

			# --- Redstone-Inputs ---
	if target == "lever" or target == "lever_on":
		var on = target == "lever"
		var new_id = "lever_on" if on else "lever"
		world.set_block(cell.x, cell.y, cell.z, new_id)
		renderer.edit_block(cell.x, cell.y, cell.z, new_id)
		Audio.play("click")
		Redstone.pulse(game, world, renderer, cell)
		return true

	if target == "stone_button":
		world.set_block(cell.x, cell.y, cell.z, "stone_button_on")
		renderer.edit_block(cell.x, cell.y, cell.z, "stone_button_on")
		Audio.play("click")
		Redstone.pulse(game, world, renderer, cell)
		# Auto-off nach 1s
		get_tree().create_timer(1.0).timeout.connect(func():
			if world.get_block(cell.x, cell.y, cell.z) == "stone_button_on":
				world.set_block(cell.x, cell.y, cell.z, "stone_button")
				renderer.edit_block(cell.x, cell.y, cell.z, "stone_button")
				Redstone.pulse(game, world, renderer, cell)
		)
		return true

	if target == "command_block":
		if ui != null and ui.has_method("open_command_block"):
			ui.open_command_block(cell)
		return true

	return false
	
	
var _fishing_line: Node3D = null
var _fishing_active: bool = false

func _try_use_fishing_rod() -> bool:
	if not _inv_ok():
		return false
	var held = player.inventory.held()
	if held == null or held.item_id != "fishing_rod":
		return false

	if _fishing_active:
		_reel_in()
	else:
		_cast_line()
	return true

func _cast_line() -> void:
	_fishing_active = true
	Audio.play("place")

	var origin = camera.global_position
	var dir = -camera.global_transform.basis.z
	var hit = VoxelRaycast.cast(world, origin, dir, reach)

	if hit.get("ok", false):
		var cell = hit["hit"]
		var block_id = world.get_block(cell.x, cell.y, cell.z)
		if block_id == "water":
			await get_tree().create_timer(randf_range(1.5, 4.0)).timeout
			if _fishing_active:
				Audio.play("pop")
				var fish_drops = ["fish", "cooked_fish", "salmon"]
				var caught = fish_drops[randi() % fish_drops.size()]
				if Registry.items.has(caught):
					player.inventory.add(caught, 1)
				_fishing_active = false
			return

	await get_tree().create_timer(0.3).timeout
	_fishing_active = false

func _reel_in() -> void:
	_fishing_active = false
	Audio.play("click")


func _try_firework() -> bool:
	if not _inv_ok():
		return false
	var held = player.inventory.held()
	if held == null or held.item_id != "firework_rocket":
		return false
	# Only "use" the rocket when actually gliding — otherwise fall through to place/interact
	if player.has_method("elytra_boost") and bool(player.gliding):
		player.elytra_boost()
		player.inventory.consume_held(1)
		Audio.play("place")
		return true
	return false


func _try_place_block(hit: Dictionary) -> void:
	var bid = held_block_id()
	print("DEBUG: held_block_id() = ", bid)

	if bid == "":
		print("DEBUG: Kein Block in der Hand")
		return

	var place = hit["place"]

	# Portal-Blöcke dürfen auch überlappen (damit man sie betreten kann)
	if not _is_portal_block(bid) and _overlaps_player(place):
		print("DEBUG: Block überschneidet sich mit Spieler")
		return

	renderer.edit_block(place.x, place.y, place.z, bid)
	# Store piston push direction from camera look
	if bid == "piston" or bid == "sticky_piston":
		var look = -camera.global_transform.basis.z
		var dir = Vector3i(0, 0, 0)
		if absf(look.y) > absf(look.x) and absf(look.y) > absf(look.z):
			dir = Vector3i(0, 1 if look.y > 0 else -1, 0)
		elif absf(look.x) > absf(look.z):
			dir = Vector3i(1 if look.x > 0 else -1, 0, 0)
		else:
			dir = Vector3i(0, 0, 1 if look.z > 0 else -1)
		if game != null:
			if game.get("piston_facing") == null:
				game.piston_facing = {}
			game.piston_facing[place] = dir

	if not GameSettings.unlimited_blocks(player.game_mode):
		player.inventory.consume_held(1)

	Audio.play("place")
	print("DEBUG: Block erfolgreich platziert!")


func _overlaps_player(cell: Vector3i) -> bool:
	var fx = floori(player.global_position.x)
	var fy = floori(player.global_position.y)
	var fz = floori(player.global_position.z)
	return cell == Vector3i(fx, fy, fz) or cell == Vector3i(fx, fy + 1, fz)


func _attack() -> void:
	if player == null or not _active():
		return
	if camera == null or not is_instance_valid(camera):
		if player.has_node("Head/Camera3D"):
			camera = player.get_node("Head/Camera3D")
		else:
			camera = player.find_child("Camera3D", true, false)
	if camera == null:
		return

	var dmg = _attack_damage()
	var origin = camera.global_position
	var forward = -camera.global_transform.basis.z.normalized()
	var attack_reach = maxf(reach, 4.5)

	# PRIMARY: nearest mob in front of the camera (reliable in all viewports)
	var best = null
	var best_score = -9999.0
	var tree = player.get_tree()
	if tree != null:
		for m in tree.get_nodes_in_group("mobs"):
			if m == null or not is_instance_valid(m) or not m.has_method("take_hit"):
				continue
			var to_m: Vector3 = (m.global_position + Vector3(0, 0.9, 0)) - origin
			var dist = to_m.length()
			if dist > attack_reach or dist < 0.05:
				continue
			var dir = to_m / dist
			var facing = dir.dot(forward)
			if facing < -0.15:
				continue  # mostly behind the player
			# Prefer closer + more centered in crosshair
			var score = facing * 2.0 - dist * 0.15
			if score > best_score:
				best_score = score
				best = m

	if best != null:
		best.take_hit(dmg)
		if has_node("/root/Audio"):
			get_node("/root/Audio").play("hit")
		elif Audio:
			Audio.play("hit")
		return

	# SECONDARY: physics ray on entity layer
	var w3d = player.get_world_3d()
	if w3d == null:
		w3d = get_world_3d()
	if w3d == null:
		return
	var space = w3d.direct_space_state
	var q = PhysicsRayQueryParameters3D.create(origin, origin + forward * attack_reach)
	q.collision_mask = 2
	q.collide_with_areas = true
	q.collide_with_bodies = true
	if player is CollisionObject3D:
		q.exclude = [player.get_rid()]
	var hit = space.intersect_ray(q)
	if hit.is_empty():
		return
	var node = hit.get("collider")
	while node != null:
		if node != player and node.has_method("take_hit"):
			node.take_hit(dmg)
			if has_node("/root/Audio"):
				get_node("/root/Audio").play("hit")
			elif Audio:
				Audio.play("hit")
			return
		node = node.get_parent()



func _attack_damage() -> float:
	var s = player.inventory.held()
	if s == null:
		return 1.0
	var it = Registry.get_item(s.item_id)
	if it != null and it.get("type", "") == "tool":
		return float(it.get("damage", 1))
	return 1.0


func _make_highlight() -> MeshInstance3D:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0, 0, 0, 0.9)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var lo = -0.002
	var hi = 1.002
	var c = [
		Vector3(lo, lo, lo), Vector3(hi, lo, lo), Vector3(hi, lo, hi), Vector3(lo, lo, hi),
		Vector3(lo, hi, lo), Vector3(hi, hi, lo), Vector3(hi, hi, hi), Vector3(lo, hi, hi)]
	var edges = [
		[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6],
		[6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]]
	for e in edges:
		im.surface_add_vertex(c[e[0]])
		im.surface_add_vertex(c[e[1]])
	im.surface_end()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	return mi
	
	
	
	
func _try_ignite_tnt(hit: Dictionary) -> bool:
	var held = player.inventory.held()
	if held == null or held.item_id != "flint_and_steel":
		return false

	var target_pos = hit["hit"]   # ← der TNT-Block selbst, nicht "place"
	var target_block = world.get_block(target_pos.x, target_pos.y, target_pos.z)

	if target_block == "tnt":
		renderer.edit_block(target_pos.x, target_pos.y, target_pos.z, "air")
		var tnt_entity = preload("res://scenes/tnt_entity.tscn").instantiate()
		tnt_entity.global_position = Vector3(target_pos) + Vector3(0.5, 0.5, 0.5)
		get_tree().current_scene.add_child(tnt_entity)
		if tnt_entity.has_method("setup"):
			tnt_entity.setup(world, renderer)
		if tnt_entity.has_method("ignite"):
			tnt_entity.ignite()
		return true
	return false
	
	
func _is_portal_block(block_id: String) -> bool:
	return block_id == "nether_portal" or block_id == "end_portal" or block_id == "heaven_portal"



func _try_name_tag_on_mob() -> bool:
	if player == null or camera == null:
		return false
	var held = player.inventory.held()
	if held == null or held.item_id != "name_tag":
		return false
	var space = get_world_3d().direct_space_state
	if space == null:
		return false
	var from = camera.global_position
	var to = from + (-camera.global_transform.basis.z) * reach
	var q = PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 2
	var hit = space.intersect_ray(q)
	if hit.is_empty():
		return false
	var col = hit.get("collider")
	if col == null:
		return false
	if player.has_method("try_apply_name_tag_to_mob"):
		if player.try_apply_name_tag_to_mob(col):
			Audio.play("click")
			return true
	return false
