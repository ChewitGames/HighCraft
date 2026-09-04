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
var _last_use_msec: int = -1000
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
	if player != null and player.has_method("_joy_device"):
		return int(player._joy_device())
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
var _plate_check_t: float = 0.0

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
			if renderer:
				_net_edit_block(cell.x, cell.y, cell.z, "pressure_plate_on")
			else:
				world.set_block(cell.x, cell.y, cell.z, "pressure_plate_on")
			Redstone.pulse(game, world, renderer, cell)
	elif not standing_on_plate and _plate_on:
		_plate_on = false
		var old_id = world.get_block(_plate_cell.x, _plate_cell.y, _plate_cell.z)
		if old_id == "pressure_plate_on":
			if renderer:
				_net_edit_block(_plate_cell.x, _plate_cell.y, _plate_cell.z, "pressure_plate")
			else:
				world.set_block(_plate_cell.x, _plate_cell.y, _plate_cell.z, "pressure_plate")
			Redstone.pulse(game, world, renderer, _plate_cell)


func _process(delta: float) -> void:
	_plate_check_t -= delta
	if _plate_check_t <= 0.0:
		_plate_check_t = 0.1
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

	# RT = firework use when holding a rocket; otherwise attack/mine.
	var rt_down = HCPad.rt_held(dev2)
	if rt_down and not _rt_was_down:
		var held = player.inventory.held() if _inv_ok() else null
		if held != null and held.item_id == "firework_rocket":
			_do_use_action()
		else:
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
		if player.has_method("play_arm_swing"):
			player.play_arm_swing()

	var bid = world.get_block(cell.x, cell.y, cell.z)
	var bt = _break_time(bid)
	if bt < 0.0:
		return

	_mining_progress += delta
	_dig_timer += delta

	if _dig_timer >= 0.25:
		_dig_timer = 0.0
		Audio.play(Audio.dig_group(bid))
		if player.has_method("play_arm_swing"):
			player.play_arm_swing()

	if _mining_progress >= bt:
		if _can_harvest(bid):
			_collect_drops(bid)
			_wear_tool()
		_net_edit_block(cell.x, cell.y, cell.z, "air")
		Audio.play(Audio.dig_group(bid))
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
			_rmb_was_down = true
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
				_rb_was_down = true
				_do_use_action()
			HCPad.BTN_DPAD_LEFT:
				if player != null and player.inventory != null:
					player.inventory.scroll(-1)
			HCPad.BTN_DPAD_RIGHT:
				if player != null and player.inventory != null:
					player.inventory.scroll(1)


func _do_use_action() -> void:
	# Events and polling can both observe one physical press in adjacent frames.
	var now := Time.get_ticks_msec()
	if now - _last_use_msec < 80:
		return
	_last_use_msec = now
	if player != null and player.has_method("play_arm_swing"):
		player.play_arm_swing()
	if _try_firework():
		return
	if _try_use_realm_stone():
		return
	if _try_tame_animal():
		return
	if _try_drink_potion():
		return
	if _try_place_ender_eye():
		return
	if _try_throw_ender_item():
		return
	if _try_flint_and_steel():
		return
	if _try_heaven_portal_water():
		return
	if _try_use_spawn_egg():
		return
	if _try_farm_action():
		return
	if _try_use_fishing_rod():
		return
	if _try_talk():
		return
	_try_place()
	if _try_eat():
		return


func _try_farm_action() -> bool:
	if not _inv_ok() or camera == null or world == null:
		return false
	var held = player.inventory.held()
	if held == null:
		return false
	var dir = -camera.global_transform.basis.z
	var hit = VoxelRaycast.cast(world, camera.global_position, dir, reach)
	if not hit.get("ok", false):
		return false
	var cell: Vector3i = hit["hit"]
	var target = str(world.get_block(cell.x, cell.y, cell.z))
	# Hoe → till dirt/grass
	if Farming.is_hoe(held.item_id):
		if Farming.try_till(world, renderer, cell):
			Audio.play("dig_grass")
			return true
		return false
	# Seeds / carrot / potato on farmland
	var crop = Farming.seed_crop(held.item_id)
	if crop != "":
		if Farming.try_plant(world, renderer, cell, crop):
			if not GameSettings.unlimited_blocks(player.game_mode):
				player.inventory.consume_held(1)
			Audio.play("place")
			return true
	return false



func _try_use_realm_stone() -> bool:
	if not _inv_ok():
		return false
	var held = player.inventory.held()
	if held == null:
		return false
	var id = str(held.item_id)
	if not id.begins_with("realm_stone_"):
		return false
	var key = id.replace("realm_stone_", "")
	var g = game if game != null else get_parent()
	match key:
		"chronos":
			# Slow time-ish: freeze nearby mobs briefly
			for m in get_tree().get_nodes_in_group("mobs"):
				if m.global_position.distance_to(player.global_position) < 20.0:
					m.set_meta("frozen_t", 5.0)
			Audio.play("ui_achievement")
		"zeus":
			if g and g.has_method("strike_lightning"):
				var dir = -camera.global_transform.basis.z
				var hit = VoxelRaycast.cast(world, camera.global_position, dir, 30.0)
				var pos = hit["hit"] if hit.get("ok", false) else (player.global_position + dir * 8.0)
				if pos is Vector3i:
					pos = Vector3(pos.x, pos.y, pos.z)
				g.strike_lightning(pos)
			Audio.play("lightning_strike")
		"hemera", "aither":
			if g:
				g.time_of_day = 0.25  # day
			Audio.play("ui_click")
		"nyx", "erebos":
			if g:
				g.time_of_day = 0.75  # night
			Audio.play("ui_click")
		"gaia":
			player.health = player.max_health
			Audio.play("player_eat" if true else "place")
		"poseidon":
			player.set_meta("water_breath_t", 30.0)
			Audio.play("water_splash")
		"creation", "chaos":
			player.health = player.max_health
			player.hunger = player.max_hunger if "max_hunger" in player else 20
			Audio.play("ui_achievement")
		"mania":
			player.set_meta("speed_boost_t", 15.0)
			player.set_meta("speed_boost_multiplier", 3.0)
			Audio.play("ui_click")
		"apollon":
			# Light burst
			if g and g.get("lightning_light"):
				g.lightning_light.global_position = player.global_position + Vector3(0, 3, 0)
				g.lightning_light.light_energy = 10.0
				g.thunder_flash = 0.5
			Audio.play("ui_click")
		"artemis":
			player.set_meta("speed_boost_t", 10.0)
			player.set_meta("speed_boost_multiplier", 1.55)
			Audio.play("ui_click")
		"ares":
			player.set_meta("damage_boost_t", 20.0)
			Audio.play("player_attack")
		"athena":
			player.set_meta("armor_boost_t", 30.0)
			Audio.play("player_armor_on")
		"hermes":
			player.set_meta("speed_boost_t", 25.0)
			player.set_meta("speed_boost_multiplier", 1.55)
			Audio.play("ui_click")
		"hephaistos":
			# free fire at feet
			if world and renderer:
				var c = Vector3i(floori(player.global_position.x), floori(player.global_position.y), floori(player.global_position.z))
				_net_edit_block(c.x, c.y, c.z, "fire")
			Audio.play("fire_ignite")
		"demeter":
			player.hunger = player.max_hunger if "max_hunger" in player else 20
			Audio.play("player_eat")
		"hera", "hestia", "aphrodite", "dionysos", "hermes":
			player.health = minf(player.max_health, player.health + 8.0)
			Audio.play("ui_click")
		_:
			Audio.play("ui_click")
	if not GameSettings.unlimited_blocks(player.game_mode):
		player.inventory.consume_held(1)
	return true


func _try_tame_animal() -> bool:
	if not _inv_ok() or camera == null:
		return false
	var held = player.inventory.held()
	if held == null:
		return false
	# Food used for taming
	var food = held.item_id
	var tame_foods = ["wheat", "carrot", "potato", "wheat_seeds", "apple"]
	if food not in tame_foods:
		return false
	var space = camera.get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from + (-camera.global_transform.basis.z) * reach
	var q = PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 2
	var hit = space.intersect_ray(q)
	if hit.is_empty():
		return false
	var col = hit["collider"]
	var mob = col if col is Mob else col.get_parent()
	if not (mob is Mob):
		return false
	var mid = str(mob.mob_id)
	if mid not in ["pig", "horse", "wolf", "ocelot"]:
		return false
	var progress = int(mob.get_meta("tame_progress", 0)) + 1
	mob.set_meta("tame_progress", progress)
	if not GameSettings.unlimited_blocks(player.game_mode):
		player.inventory.consume_held(1)
	Audio.play("player_eat" if true else "click")
	if progress >= 3:
		mob.set_meta("tamed", true)
		mob.set_meta("owner", player)
		mob.category = "passive"
		# Saddle required for ride
		if mid in ["pig", "horse"] and held.item_id == "saddle":
			mob.set_meta("saddled", true)
		print("[Tame] ", mid, " tamed after ", progress, " feeds")
		Audio.play("ui_achievement")
	else:
		print("[Tame] ", mid, " progress ", progress, "/3")
	return true


func _try_tame_saddle() -> bool:
	return false


func _try_flint_and_steel() -> bool:
	if not _inv_ok() or world == null:
		return false
	var held = player.inventory.held()
	if held == null or held.item_id != "flint_and_steel":
		return false
	var dir = -camera.global_transform.basis.z
	var hit = VoxelRaycast.cast(world, camera.global_position, dir, reach)
	if not hit.get("ok", false):
		return false
	var target: Vector3i = hit["hit"]
	if world.get_block(target.x, target.y, target.z) == "tnt":
		return false
	var place: Vector3i = hit.get("place", hit["hit"])
	# Light a hell portal if an obsidian frame is complete
	if PortalBuilder.try_light_hell(world, renderer, target) or PortalBuilder.try_light_hell(world, renderer, place):
		Audio.play("fire_ignite")
		return true
	if world.get_block(place.x, place.y, place.z) != "air":
		return false
	if renderer:
		_net_edit_block(place.x, place.y, place.z, "fire")
	else:
		world.set_block(place.x, place.y, place.z, "fire")
	Audio.play("fire_ignite")
	return true


func _try_heaven_portal_water() -> bool:
	if not _inv_ok() or world == null or camera == null:
		return false
	var held = player.inventory.held()
	if held == null or held.item_id != "water_bucket":
		return false
	var dir = -camera.global_transform.basis.z
	var hit = VoxelRaycast.cast(world, camera.global_position, dir, reach)
	if not hit.get("ok", false):
		return false
	var target: Vector3i = hit["hit"]
	var place: Vector3i = hit.get("place", target)
	if PortalBuilder.try_light_heaven(world, renderer, target) or PortalBuilder.try_light_heaven(world, renderer, place):
		if not GameSettings.unlimited_blocks(player.game_mode):
			player.inventory.consume_held(1)
			player.inventory.add("bucket", 1)
		Audio.play("water_splash")
		return true
	return false


func _try_drink_potion() -> bool:
	if not _inv_ok():
		return false
	var held = player.inventory.held()
	if held == null:
		return false
	var iid = str(held.item_id)
	if iid == "milk_bucket":
		if player.has_method("clear_status_effects"):
			player.clear_status_effects()
		player.inventory.consume_held(1)
		player.inventory.add("bucket", 1)
		Audio.play("player_eat")
		return true
	if iid == "water_bucket":
		return false
	var is_potion = iid.begins_with("potion_") or iid.begins_with("splash_") or iid in ["water_bottle", "awkward_potion", "mundane_potion", "thick_potion"]
	if not is_potion and Registry.potions.has(iid):
		is_potion = true
	if not is_potion:
		return false
	if iid.begins_with("splash_"):
		return false
	if player.has_method("drink_potion"):
		if not player.drink_potion(iid):
			# Still consume empty-effect bottles
			pass
	if not GameSettings.unlimited_blocks(player.game_mode):
		player.inventory.consume_held(1)
		player.inventory.add("glass_bottle", 1)
	Audio.play("player_eat")
	return true


func _try_throw_ender_item() -> bool:
	if not _inv_ok() or player == null or camera == null:
		return false
	var held = player.inventory.held()
	if held == null:
		return false
	var iid = str(held.item_id)
	if iid != "ender_pearl" and iid != "eye_of_ender":
		return false
	var root = game if game != null else get_tree().current_scene
	if root == null:
		return false
	var proj = preload("res://scripts/Projectile.gd").new() if ResourceLoader.exists("res://scripts/Projectile.gd") else Node3D.new()
	# Dedicated visible pearl/eye projectile
	var body := RigidBody3D.new()
	body.gravity_scale = 1.1
	body.continuous_cd = true
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.7, 0.45) if iid == "ender_pearl" else Color(0.35, 0.85, 0.4)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 1.6
	mesh.material_override = mat
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.12
	col.shape = sph
	body.add_child(col)
	root.add_child(body)
	body.global_position = camera.global_position + (-camera.global_transform.basis.z) * 0.6
	body.linear_velocity = -camera.global_transform.basis.z * (18.0 if iid == "ender_pearl" else 10.0) + Vector3(0, 2.0, 0)
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.set_meta("kind", iid)
	body.set_meta("owner_player", player)
	body.body_entered.connect(func(_n): _on_ender_proj_hit(body))
	# Timeout fallback
	root.get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(body):
			_on_ender_proj_hit(body)
	)
	if not GameSettings.unlimited_blocks(player.game_mode):
		player.inventory.consume_held(1)
	Audio.play("place")
	return true


func _on_ender_proj_hit(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	var kind = str(body.get_meta("kind", ""))
	var pos = body.global_position
	var owner_p = body.get_meta("owner_player", player)
	if kind == "ender_pearl" and owner_p != null and is_instance_valid(owner_p):
		owner_p.global_position = pos + Vector3(0, 0.6, 0)
		owner_p.velocity = Vector3.ZERO
		if owner_p.has_method("take_damage") and GameSettings.can_take_damage(owner_p.game_mode):
			owner_p.take_damage(5.0, pos)
	elif kind == "eye_of_ender" and game != null and game.has_method("guide_eye_of_ender"):
		game.guide_eye_of_ender(pos)
	body.queue_free()


func _try_place_ender_eye() -> bool:
	if not _inv_ok() or world == null or camera == null:
		return false
	var held = player.inventory.held()
	if held == null or held.item_id != "eye_of_ender":
		return false
	var dir = -camera.global_transform.basis.z
	var hit = VoxelRaycast.cast(world, camera.global_position, dir, reach)
	if not hit.get("ok", false):
		return false
	var cell: Vector3i = hit["hit"]
	if PortalBuilder.place_eye(world, renderer, cell):
		if not GameSettings.unlimited_blocks(player.game_mode):
			player.inventory.consume_held(1)
		Audio.play("place")
		return true
	return false


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
	var rail_cell: Vector3i = hit["hit"]
	var ok = target in ["rail", "powered_rail", "detector_rail"]
	if not ok and hit.has("place"):
		# check block under place position for rail
		var pc: Vector3i = hit["place"]
		var under = Vector3i(pc.x, pc.y - 1, pc.z)
		var u = world.get_block(under.x, under.y, under.z)
		if u in ["rail", "powered_rail", "detector_rail"]:
			rail_cell = under
			ok = true
		elif world.get_block(pc.x, pc.y, pc.z) in ["rail", "powered_rail", "detector_rail"]:
			rail_cell = pc
			ok = true
	if not ok:
		return false
	var cart = Minecart.new()
	var root = game if game != null else get_tree().current_scene
	if root == null:
		root = get_parent()
	root.add_child(cart)
	var pos = Vector3(rail_cell.x + 0.5, float(rail_cell.y) + 0.4, rail_cell.z + 0.5)
	if cart.has_method("setup"):
		cart.setup(world, game, pos)
	else:
		cart.world = world
		cart.game = game
		cart.global_position = pos
	cart.visible = true
	if not GameSettings.unlimited_blocks(player.game_mode):
		player.inventory.consume_held(1)
	Audio.play("place")
	print("[Minecart] placed at ", rail_cell, " pos=", pos, " parent=", root.name if root else "?")
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
	if held == null:
		return false
	if held.item_id == "flint_and_steel" and target == "obsidian":
		var base: Vector3i = hit.get("place", hit["hit"])
		if PortalBuilder.try_light_hell(world, renderer, hit["hit"]) or PortalBuilder.try_light_hell(world, renderer, base):
			Audio.play("fire_ignite")
			return true
	if held.item_id == "water_bucket" and target == "glowstone":
		var base2: Vector3i = hit.get("place", hit["hit"])
		if PortalBuilder.try_light_heaven(world, renderer, hit["hit"]) or PortalBuilder.try_light_heaven(world, renderer, base2):
			if not GameSettings.unlimited_blocks(player.game_mode):
				player.inventory.consume_held(1)
				player.inventory.add("bucket", 1)
			Audio.play("water_splash")
			return true
	return false


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

	# Tamed pig/horse: saddle then ride
	var mob = col if col is Mob else (col.get_parent() if col.get_parent() is Mob else null)
	if mob != null and bool(mob.get_meta("tamed", false)):
		var held = player.inventory.held() if _inv_ok() else null
		if held != null and held.item_id == "saddle" and not bool(mob.get_meta("saddled", false)):
			mob.set_meta("saddled", true)
			player.inventory.consume_held(1)
			Audio.play("player_armor_on" if true else "click")
			return true
		if bool(mob.get_meta("saddled", false)):
			mob.set_meta("rider", player)
			player.set_meta("riding_mob", mob)
			Audio.play("click")
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
		Audio.play("player_eat")
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
	_net_edit_block(cell.x, cell.y, cell.z, new_id)
	Audio.play("door_open_wood" if new_id.ends_with("_open") else "door_close_wood")

func _toggle_trapdoor(cell: Vector3i) -> void:
	if world == null or renderer == null:
		return
	var current = world.get_block(cell.x, cell.y, cell.z)
	var new_id = "trapdoor_oak_open" if current == "trapdoor_oak" else "trapdoor_oak"
	if not Registry.blocks.has(new_id):
		print("DEBUG: Registry hat '", new_id, "' nicht!")
		Audio.play("ui_error")
		return
	_net_edit_block(cell.x, cell.y, cell.z, new_id)
	Audio.play("door_open_wood" if new_id.ends_with("_open") else "door_close_wood")


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
	_net_edit_block(cell.x, cell.y, cell.z, new_id)
	Audio.play("door_open_wood" if new_id.ends_with("_open") else "door_close_wood")


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
		"brewing_stand":
			if game != null and ui.has_method("open_brewing"):
				ui.open_brewing(game.get_brewing_stand(cell), cell)
				return true
			return false
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
				Audio.play("chest_open")
				ui.open_chest(game.get_chest(cell), cell)
				return true
			return false
		"enchanting_table":
			if ui != null and ui.has_method("open_enchant"):
				ui.open_enchant()
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
		_net_edit_block(cell.x, cell.y, cell.z, new_id)
		Audio.play("click")
		Redstone.pulse(game, world, renderer, cell)
		return true

	if target == "stone_button":
		_net_edit_block(cell.x, cell.y, cell.z, "stone_button_on")
		Audio.play("click")
		Redstone.pulse(game, world, renderer, cell)
		# Auto-off nach 1s
		get_tree().create_timer(1.0).timeout.connect(func():
			if world.get_block(cell.x, cell.y, cell.z) == "stone_button_on":
				_net_edit_block(cell.x, cell.y, cell.z, "stone_button")
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
	var used := false
	if player.has_method("elytra_boost") and bool(player.gliding):
		player.elytra_boost()
		used = true
	else:
		var root = game if game != null else get_tree().current_scene
		if root != null and root.has_method("spawn_firework"):
			root.spawn_firework(player.global_position + Vector3(0, 0.35, 0), Vector3.UP)
			used = true
	if used:
		if not GameSettings.unlimited_blocks(player.game_mode):
			player.inventory.consume_held(1)
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

	_net_edit_block(place.x, place.y, place.z, bid)
	# Store piston push direction from camera look
	if bid == "piston" or bid == "sticky_piston":
		var look = -camera.global_transform.basis.z
		var dir = Vector3i(0, 0, 0)
		# The piston face points back toward the player. `look` is the ray direction
		# from the player into the placed block, so every dominant-axis sign must be
		# inverted; using it directly makes the piston extend into its support wall.
		if absf(look.y) > absf(look.x) and absf(look.y) > absf(look.z):
			dir = Vector3i(0, -1 if look.y > 0 else 1, 0)
		elif absf(look.x) > absf(look.z):
			dir = Vector3i(-1 if look.x > 0 else 1, 0, 0)
		else:
			dir = Vector3i(0, 0, -1 if look.z > 0 else 1)
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
	if player.has_method("play_arm_swing"):
		player.play_arm_swing()
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

	# PRIMARY: nearest attackable entity in front of the camera.
	var best = null
	var best_score = -9999.0
	var allow_pvp := true
	if has_node("/root/Multiplayer"):
		allow_pvp = bool(get_node("/root/Multiplayer").pvp_enabled)
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
		if allow_pvp:
			for other in tree.get_nodes_in_group("players"):
				if other == player or other == null or not is_instance_valid(other) or not other.has_method("take_damage"):
					continue
				var to_other: Vector3 = (other.global_position + Vector3(0, 0.9, 0)) - origin
				var other_dist := to_other.length()
				if other_dist > attack_reach or other_dist < 0.05:
					continue
				var other_facing := (to_other / other_dist).dot(forward)
				if other_facing < -0.15:
					continue
				var other_score := other_facing * 2.0 - other_dist * 0.15
				if other_score > best_score:
					best_score = other_score
					best = other

	if best != null:
		if best.has_method("take_hit"):
			best.take_hit(dmg)
			if best.has_method("apply_knockback"):
				best.apply_knockback(player.global_position)
		else:
			best.take_damage(dmg, player.global_position)
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
		if node != player and node.is_in_group("players") and not allow_pvp:
			return
		if node != player and node.is_in_group("players") and node.has_method("take_damage"):
			node.take_damage(dmg, player.global_position)
			Audio.play("hit")
			return
		if node != player and node.has_method("take_hit"):
			node.take_hit(dmg)
			if node.has_method("apply_knockback"):
				node.apply_knockback(player.global_position)
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
		_net_edit_block(target_pos.x, target_pos.y, target_pos.z, "air")
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


func _net_edit_block(x: int, y: int, z: int, id: String) -> void:
	if renderer != null:
		renderer.edit_block(x, y, z, id)
	elif world != null:
		world.set_block(x, y, z, id)
	if game != null and game.has_method("broadcast_block_edit"):
		game.broadcast_block_edit(x, y, z, id)
	# Construct mobs when placing pumpkin / skull
	if id in ["pumpkin", "carved_pumpkin", "wither_skeleton_skull"]:
		_try_construct_spawn(Vector3i(x, y, z), id)


func _try_construct_spawn(cell: Vector3i, placed_id: String) -> void:
	if world == null:
		return
	# Snow golem: pumpkin on 2 snow blocks
	if placed_id in ["pumpkin", "carved_pumpkin"]:
		var b1 = str(world.get_block(cell.x, cell.y - 1, cell.z))
		var b2 = str(world.get_block(cell.x, cell.y - 2, cell.z))
		if b1 == "snow_block" and b2 == "snow_block":
			_spawn_construct("snow_golem", cell, [
				cell, Vector3i(cell.x, cell.y - 1, cell.z), Vector3i(cell.x, cell.y - 2, cell.z)
			])
			return
		# Iron golem: pumpkin on iron T (center + arms + body)
		if b1 == "iron_block":
			for dir in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				var arm_l = cell + Vector3i(dir.x, -1, dir.z)  # wrong
			# Body is below pumpkin; arms horizontal at body level; legs optional
			var body = Vector3i(cell.x, cell.y - 1, cell.z)
			for arms in [
				[Vector3i(1, 0, 0), Vector3i(-1, 0, 0)],
				[Vector3i(0, 0, 1), Vector3i(0, 0, -1)],
			]:
				var a0 = body + arms[0]
				var a1 = body + arms[1]
				var legs = Vector3i(cell.x, cell.y - 2, cell.z)
				if str(world.get_block(a0.x, a0.y, a0.z)) == "iron_block" 						and str(world.get_block(a1.x, a1.y, a1.z)) == "iron_block" 						and str(world.get_block(legs.x, legs.y, legs.z)) == "iron_block":
					_spawn_construct("iron_golem", cell, [cell, body, a0, a1, legs])
					return
	# Wither: 3 wither skulls on soul sand T
	if placed_id == "wither_skeleton_skull":
		# Check horizontal row of 3 skulls with soul sand T below
		for axis in ["x", "z"]:
			var cells_skull: Array = []
			var ok = true
			for i in range(-1, 2):
				var c = cell
				if axis == "x":
					c = Vector3i(cell.x + i, cell.y, cell.z)
				else:
					c = Vector3i(cell.x, cell.y, cell.z + i)
				if str(world.get_block(c.x, c.y, c.z)) != "wither_skeleton_skull":
					ok = false
					break
				cells_skull.append(c)
			if not ok:
				continue
			# Soul sand: row below skulls + one down center
			var sand_cells: Array = []
			for sc in cells_skull:
				var below = Vector3i(sc.x, sc.y - 1, sc.z)
				if str(world.get_block(below.x, below.y, below.z)) != "soul_sand":
					ok = false
					break
				sand_cells.append(below)
			if not ok:
				continue
			var stem = Vector3i(cell.x, cell.y - 2, cell.z)
			if str(world.get_block(stem.x, stem.y, stem.z)) != "soul_sand":
				continue
			sand_cells.append(stem)
			var allc = cells_skull + sand_cells
			_spawn_construct("wither", cell, allc)
			return


func _spawn_construct(mob_id: String, at: Vector3i, clear_cells: Array) -> void:
	for c in clear_cells:
		_net_edit_block(c.x, c.y, c.z, "air")
	var pos = Vector3(at.x + 0.5, float(at.y) - 0.5, at.z + 0.5)
	if game != null and game.get("mob_manager") != null and game.mob_manager.has_method("spawn"):
		game.mob_manager.spawn(mob_id, pos)
	elif game != null:
		# Fallback: spawn via Mob directly
		var mob = Mob.new()
		mob.setup(mob_id, player)
		var root = game
		root.add_child(mob)
		mob.global_position = pos
	Audio.play("wither_spawn" if mob_id == "wither" else "ui_achievement")
	print("[Construct] spawned ", mob_id, " at ", at)
