extends Node3D
var is_raining := false
var rain_strength := 0.0
var rain_timer := 0.0
var rain_particles: GPUParticles3D
var _dragon_ref = null
var _loading_label: Label
var _is_loading := true
# === NEU: Gewitter ===
var is_thunderstorm := false
var thunder_timer := 0.0
var thunder_flash := 0.0
var lightning_light: OmniLight3D # ← NEU für sichtbaren Blitz
# HighCraft - main game scene (Part 13).
# Voxel world per dimension, chunk streaming, player, interactor, UI, mobs,
# day/night, and portal travel between Overworld / Hell / The End / Heaven.
const RADIUS = 4
const SPAWN_X = 8
const SPAWN_Z = 8
var sky_material = ShaderMaterial.new()
const PORTAL_LINK = {
"nether_portal": ["overworld", "hell"],
"end_portal": ["overworld", "the_end"],
"heaven_portal": ["overworld", "heaven"]
}
var dim_mgr: DimensionManager
var current_dim: String = "overworld"
var world
var renderer: ChunkRenderer
var player: Player
var split_screen_mgr: SplitScreenManager
var interactor: BlockInteractor
var ui: GameUI
var mob_manager: MobManager
var event_manager: EventManager
var furnaces: Dictionary = {}
var sun: DirectionalLight3D
var env: Environment
var time_of_day: float = 0.3
var day_length: float = 600.0
var moon: DirectionalLight3D # ← NEU
var _daynight: bool = true
var _portal_cd: float = 0.0
var _return_points: Dictionary = {}
func _setup_rain_particles() -> void:
		rain_particles.emitting = false
		rain_particles.amount = 1200
		rain_particles.lifetime = 1.2
		rain_particles.preprocess = 1.2
		rain_particles.explosiveness = 0.0
		rain_particles.randomness = 0.3
		rain_particles.visibility_aabb = AABB(Vector3(-80, -20, -80), Vector3(160, 100, 160))
		rain_particles.local_coords = false
		var process_material := ParticleProcessMaterial.new()
		process_material.direction = Vector3(0, -1, 0)
		process_material.spread = 8.0
		process_material.initial_velocity_min = 18.0
		process_material.initial_velocity_max = 26.0
		process_material.gravity = Vector3(0, -9.8, 0)
		process_material.scale_min = 0.04
		process_material.scale_max = 0.07
		process_material.color = Color(0.75, 0.78, 0.85, 0.6)
# Form: Große Box über dem Spieler
		process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process_material.emission_box_extents = Vector3(35, 8, 35)
		rain_particles.process_material = process_material
		rain_particles.draw_pass_1 = QuadMesh.new()
		
func _setup_lightning_light() -> void:
		lightning_light = OmniLight3D.new()
		lightning_light.light_color = Color(0.9, 0.95, 1.0)
		lightning_light.light_energy = 0.0
		lightning_light.omni_range = 120.0
		lightning_light.shadow_enabled = false
		add_child(lightning_light)
func _ready() -> void:
	add_to_group("game")
	# Show loading overlay FIRST so the player sees it before any hitch
	_is_loading = true
	_ensure_loading_ui()
	if _loading_label:
		_loading_label.text = "Loading world..."

	rain_particles = GPUParticles3D.new()
	add_child(rain_particles)
	_setup_rain_particles() # ← NEU
	_setup_lightning_light() # ← NEU
	rain_particles.emitting = false
	_setup_environment()
	dim_mgr = DimensionManager.new(Config.seed_val, Config.world_type, Config.generate_structures)
	world = dim_mgr.get_world("overworld")
	renderer = ChunkRenderer.new()
	add_child(renderer)
	renderer.setup(world)
	var sy = world.surface_height(SPAWN_X, SPAWN_Z)
	# Always mesh a small ring around spawn immediately (guarantees terrain exists)
	renderer.max_builds_per_call = 9999
	renderer.update_around(Vector3(SPAWN_X, sy, SPAWN_Z), 2)
	renderer.max_builds_per_call = 10
	print("[HighCraft] spawn chunks loaded=", renderer.loaded_count(), " surface_y=", sy)
	var spawn_pos = Vector3(SPAWN_X + 0.5, float(sy) + 2.0, SPAWN_Z + 0.5)

	if has_node("/root/Music"):
		get_node("/root/Music").play_for_dimension(_music_ctx(current_dim))

	var split_n := 1
	if has_node("/root/HCSettings"):
		split_n = clampi(get_node("/root/HCSettings").splitscreen_players, 1, 4)
	elif Config.has_meta("splitscreen"):
		split_n = clampi(int(Config.get_meta("splitscreen")), 1, 4)

	interactor = BlockInteractor.new()
	add_child(interactor)
	interactor.game = self

	mob_manager = MobManager.new()
	add_child(mob_manager)
	mob_manager.setup(world, null)
	mob_manager.set_dimension(world, current_dim)

	# Special events (Charlie Emily timer/rose, Hero No Brain)
	event_manager = EventManager.new()
	add_child(event_manager)

	if split_n <= 1:
		# ----- SOLO: 1 Player, 1 Fullscreen-UI -----
		player = preload("res://scenes/player.tscn").instantiate()
		add_child(player)
		player.global_position = spawn_pos
		player.spawn_point = spawn_pos
		player.configure(Config.game_mode, Config.difficulty)

		interactor.setup(world, renderer, player)
		player.interactor = interactor
		mob_manager.player = player
		event_manager.setup(player, mob_manager)

		ui = GameUI.new()
		add_child(ui)
		ui.setup(player, interactor)
		ui.game = self
		interactor.ui = ui
	else:
		# ----- SPLIT: 1 Manager, N Player, N UIs, N BlockInteractors -----
		split_screen_mgr = SplitScreenManager.new()
		add_child(split_screen_mgr)
		split_screen_mgr.start(split_n, self, spawn_pos)

		player = split_screen_mgr.players[0]
		for i in range(split_screen_mgr.players.size()):
			var p = split_screen_mgr.players[i]
			p.configure(Config.game_mode, Config.difficulty)
			if "split_index" in p:
				p.split_index = i
			p.set_meta("split_index", i)

			# One BlockInteractor per player (mine/place/attack on their own pad)
			var bi: BlockInteractor
			if i == 0:
				bi = interactor
			else:
				bi = BlockInteractor.new()
				add_child(bi)
				bi.game = self
			bi.setup(world, renderer, p)
			bi.player = p
			p.interactor = bi

			if i < split_screen_mgr.uis.size() and split_screen_mgr.uis[i] != null:
				var u = split_screen_mgr.uis[i]
				u.game = self
				u.player = p
				u.interactor = bi
				bi.ui = u

		mob_manager.player = player
		event_manager.setup(player, mob_manager)

		if split_screen_mgr.uis.size() > 0:
			ui = split_screen_mgr.uis[0]
		else:
			push_error("SplitScreenManager hat keine UIs erzeugt – setup_split in start() fehlt")

		# Re-bind after one frame so SubViewport cameras/UI exist for sure
		call_deferred("_rewire_split_players")

	# Pre-render spawn chunks so the first seconds are not hitching
	call_deferred("_preload_chunks")


func _update_footprints(delta: float) -> void:
	if player == null or not player.has_method("is_on_floor") or not player.is_on_floor():
		_last_pos_for_footprints = Vector3.INF
		return
	var pos = player.global_position
	if _last_pos_for_footprints == Vector3.INF:
		_last_pos_for_footprints = pos
		return
	var moved = pos.distance_to(_last_pos_for_footprints)
	_last_pos_for_footprints = pos
	if moved < 0.01:
		return
	_footprint_dist += moved
	if _footprint_dist >= 0.7:
		_footprint_dist = 0.0
		_spawn_footprint(pos)


func _spawn_footprint(pos: Vector3) -> void:
	var by = floori(pos.y) - 1
	var bx = floori(pos.x)
	var bz = floori(pos.z)
	var block_below = world.get_block_no_gen(bx, by, bz)
	if block_below == "air" or block_below == "water" or block_below == "lava":
		return
	var side_offset = player.global_transform.basis.x.normalized() * (0.15 * _footprint_side)
	_footprint_side *= -1
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.28)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.1, 0.08, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.rotation_degrees = Vector3(-90, randf() * 360.0, 0)
	mi.global_position = Vector3(bx + 0.5, floori(pos.y) + 0.02, bz + 0.5) + side_offset
	add_child(mi)
	var tw = create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(mat, "albedo_color:a", 0.0, 4.0)
	tw.tween_callback(mi.queue_free)


func _on_hc_settings_changed() -> void:
	if renderer == null:
		return
	# Rebuild every currently loaded chunk so material-affecting settings
	# (realistic water, swaying flowers/grass) take effect immediately
	# instead of only on the next chunk load.
	for key in renderer.loaded.keys():
		renderer.build_chunk(key.x, key.y)
		
		
		
func _rewire_split_players() -> void:
	if split_screen_mgr == null:
		return
	for i in range(split_screen_mgr.players.size()):
		var p = split_screen_mgr.players[i]
		if p == null or not is_instance_valid(p):
			continue
		p.split_index = i
		p.set_meta("split_index", i)
		var bi = p.interactor if "interactor" in p else null
		if bi == null:
			continue
		bi.game = self
		bi.world = world
		bi.renderer = renderer
		bi.player = p
		if p.has_node("Head/Camera3D"):
			bi.camera = p.get_node("Head/Camera3D")
		else:
			bi.camera = p.find_child("Camera3D", true, false)
		if i < split_screen_mgr.uis.size():
			var u = split_screen_mgr.uis[i]
			if u != null and is_instance_valid(u):
				u.game = self
				u.player = p
				u.interactor = bi
				bi.ui = u
				p.set_meta("ui", u)
				print("[SplitWire] P%d ui=%s cam=%s device=%d" % [i + 1, u, bi.camera != null, bi._joy_device()])


func _ensure_loading_ui() -> void:

	if _loading_label != null and is_instance_valid(_loading_label):
		return
	var layer = CanvasLayer.new()
	layer.name = "WorldLoadingLayer"
	layer.layer = 128
	add_child(layer)
	var panel = ColorRect.new()
	panel.name = "LoadingBG"
	panel.color = Color(0.04, 0.05, 0.08, 1.0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)
	_loading_label = Label.new()
	_loading_label.name = "LoadingLabel"
	_loading_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 32)
	_loading_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	_loading_label.text = "Loading world..."
	layer.add_child(_loading_label)
	_loading_label.set_meta("layer", layer)


func _preload_chunks() -> void:
	# Async entry — yields so the loading screen can actually paint
	await _preload_chunks_async()


func _preload_chunks_async() -> void:
	_is_loading = true
	_ensure_loading_ui()
	if _loading_label:
		_loading_label.visible = true
		_loading_label.text = "Loading world...\nPreparing chunks"

	# Let Godot draw the overlay for at least 2 frames before heavy work
	await get_tree().process_frame
	await get_tree().process_frame

	if renderer == null:
		push_error("[HighCraft] preload: renderer is null")
		_finish_loading()
		return

	var centers: Array = []
	if split_screen_mgr != null and split_screen_mgr.players.size() > 0:
		for sp in split_screen_mgr.players:
			if sp != null and is_instance_valid(sp):
				centers.append(sp.global_position)
	elif player != null:
		centers.append(player.global_position)
	else:
		centers.append(Vector3(SPAWN_X, 64, SPAWN_Z))

	var radius := 4
	var jobs: Array = []
	for pos in centers:
		var sx = floori(pos.x / VoxelWorld.CHUNK_SIZE)
		var sz = floori(pos.z / VoxelWorld.CHUNK_SIZE)
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				jobs.append(Vector2i(sx + dx, sz + dz))
	var seen: Dictionary = {}
	var unique: Array = []
	for k in jobs:
		if not seen.has(k):
			seen[k] = true
			unique.append(k)

	var total: int = unique.size()
	var done: int = 0
	# Sync builds during preload, but yield every few chunks so UI updates
	renderer.max_builds_per_call = 9999
	const BATCH := 8
	for k in unique:
		renderer.build_chunk(k.x, k.y)
		done += 1
		if _loading_label:
			_loading_label.text = "Loading world...\nChunks %d / %d" % [done, total]
		if done % BATCH == 0:
			await get_tree().process_frame

	renderer.max_builds_per_call = 4
	print("[HighCraft] preload done, loaded_chunks=", renderer.loaded_count())
	await get_tree().process_frame
	_finish_loading()


func _finish_loading() -> void:
	if _loading_label != null and is_instance_valid(_loading_label):
		if _loading_label.has_meta("layer"):
			var layer = _loading_label.get_meta("layer")
			if is_instance_valid(layer):
				layer.queue_free()
		elif is_instance_valid(_loading_label):
			_loading_label.queue_free()
	_loading_label = null
	if renderer != null:
		renderer.max_builds_per_call = 10
	_is_loading = false
	# Ensure look/interact work after loading overlay
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func gather_save() -> Dictionary:
	var edits = {}
	for dim in dim_mgr.worlds.keys():
		edits[dim] = dim_mgr.worlds[dim].export_edits()

	var pp = player.global_position
	return {
		"seed": Config.seed_val,
		"world_type": Config.world_type,
		"structures": Config.generate_structures,
		"time_of_day": time_of_day,
		"current_dim": current_dim,
		"player": {
			"pos": [pp.x, pp.y, pp.z],
			"health": player.health,
			"hunger": player.hunger,
			"mode": player.game_mode,
			"diff": player.difficulty,
			"xp": player.xp_level
		},
		"inventory": player.inventory.to_data(),
		"edits": edits
	}
	
func save_now() -> bool:
		return SaveManager.write(gather_save())
func _apply_save(data: Dictionary) -> void:
		var edits = data.get("edits", {})
		for dim in edits.keys():
			dim_mgr.get_world(dim).import_edits(edits[dim])
			time_of_day = float(data.get("time_of_day", 0.3))
			var pdata = data.get("player", {})
			player.inventory.from_data(data.get("inventory", {}))
			player.configure(int(pdata.get("mode", 1)), int(pdata.get("diff", 2)))
			player.health = float(pdata.get("health", 20))
			player.hunger = float(pdata.get("hunger", 20))
			var sdim = data.get("current_dim", "overworld")
			var pos_arr = pdata.get("pos", [8.5, 70, 8.5])
			var pos = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
			current_dim = sdim
			world = dim_mgr.get_world(sdim)
			renderer.set_world(world)
			interactor.world = world
			mob_manager.set_dimension(world, sdim)
			renderer.max_builds_per_call = 9999
			renderer.update_around(pos, 1)
			renderer.max_builds_per_call = 3
			player.global_position = pos
			player.spawn_point = pos
			_update_sky(sdim)
func get_furnace(cell: Vector3i) -> Furnace:
	if not furnaces.has(cell):
		furnaces[cell] = Furnace.new()
	return furnaces[cell]
	
var dispensers: Dictionary = {}   # Vector3i -> DispenserInventory
var piston_facing: Dictionary = {}  # Vector3i -> Vector3i push direction

var hoppers: Dictionary = {}      # Vector3i -> Array (5 slots)
var droppers: Dictionary = {}     # Vector3i -> Array (9 slots)
var _hopper_tick: float = 0.0

var chests: Dictionary = {}       # Vector3i -> Array of 27 ItemStack-or-null

func get_dispenser(cell: Vector3i) -> DispenserInventory:
	if not dispensers.has(cell):
		dispensers[cell] = DispenserInventory.new()
	return dispensers[cell]




func get_hopper(cell: Vector3i) -> DispenserInventory:
	if not hoppers.has(cell):
		var inv = DispenserInventory.new()
		inv.slots.resize(5)
		hoppers[cell] = inv
	return hoppers[cell]


func get_dropper(cell: Vector3i) -> DispenserInventory:
	if not droppers.has(cell):
		droppers[cell] = DispenserInventory.new()
	return droppers[cell]


func activate_dropper(cell: Vector3i) -> void:
	var inv = get_dropper(cell)
	var stack = inv.take_one()
	if stack == null:
		return
	var pos = Vector3(cell.x + 0.5, cell.y + 0.4, cell.z + 1.4)
	_eject_item_entity(stack.item_id, pos)
	Audio.play("click")


func is_hopper_locked(cell: Vector3i) -> bool:
	if world == null:
		return false
	return Redstone.powered_neighbors(world, cell)


func _eject_item_entity(item_id: String, pos: Vector3) -> void:
	# Prefer ItemEntity if available
	if ClassDB.class_exists("ItemEntity") or true:
		var path = "res://scripts/entities/item_entity.gd"
		if ResourceLoader.exists(path):
			var scr = load(path)
			if scr != null:
				var ent = scr.new()
				if ent.has_method("setup"):
					ent.setup(item_id, 1)
				elif "item_id" in ent:
					ent.item_id = item_id
				add_child(ent)
				ent.global_position = pos
				return
	# Fallback: give to nearest player
	if player != null and player.inventory != null:
		player.inventory.add(item_id, 1)


func get_chest(cell: Vector3i) -> Array:
	if not chests.has(cell):
		var slots: Array = []
		slots.resize(27)
		chests[cell] = slots
	return chests[cell]

func sleep() -> void:
	if not is_night():
		if ui != null:
			ui._chat_msg.text = "You can only sleep at night."
		return
	time_of_day = 0.27
	is_raining = false
	is_thunderstorm = false
	if ui != null:
		ui._chat_msg.text = "Slept through the night."
func _music_ctx(dim: String) -> String:
	if dim == "the_end":
		return "end"
	return dim
func travel_to(dim: String, _portal_block: String) -> void:
	if current_dim == dim:
		return

	_return_points[current_dim] = player.global_position

	current_dim = dim
	world = dim_mgr.get_world(dim)
	renderer.set_world(world)
	interactor.world = world
	mob_manager.set_dimension(world, dim)

	# Alte Mobs löschen
	for m in get_tree().get_nodes_in_group("mobs"):
		m.queue_free()

	# Neue Position finden
	var pos
	if _return_points.has(dim):
		pos = _return_points[dim]
	else:
		if dim == "the_end":
			# Immer auf die zentrale End-Insel (Radius ~58), damit Dragon und Spieler sich finden
			var sy = world.surface_height(0, 0)
			if sy < 1:
				sy = 55
			pos = Vector3(0.5, sy + 2.0, 0.5)
		else:
			var sx = int(player.global_position.x)
			var sz = int(player.global_position.z)
			var sy = world.surface_height(sx, sz)
			pos = Vector3(sx + 0.5, sy + 2, sz + 0.5)

	# Spieler teleportieren
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.spawn_point = pos
	
	# === ENDER DRAGON SPAWNEN ===
	if dim == "the_end":
		_spawn_ender_dragon()

	_portal_cd = 3.0
	_update_sky(dim)
	Music.play_for_dimension(_music_ctx(dim))
	
	
func _spawn_ender_dragon() -> void:
	if mob_manager == null:
		return
	# Ensure mob_manager knows the player (needed after dimension travel)
	if mob_manager.player == null and player != null:
		mob_manager.player = player

	# Hard-remove any leftover / queued-free dragons so the group check cannot block respawn
	for mob in get_tree().get_nodes_in_group("mobs"):
		var is_dragon := false
		if mob.has_method("is_ender_dragon") and mob.is_ender_dragon():
			is_dragon = true
		elif "mob_id" in mob and str(mob.mob_id).to_lower() in ["ender_dragon", "erebus_sovereign"]:
			is_dragon = true
		elif "ender_dragon" in mob.name.to_lower() or "erebus" in mob.name.to_lower():
			is_dragon = true
		if is_dragon:
			if is_instance_valid(mob) and not mob.is_queued_for_deletion():
				# Live dragon already present – keep it
				_dragon_ref = mob
				return
			# Queued for free or invalid – force remove from group so it cannot block
			mob.remove_from_group("mobs")
			mob.remove_from_group("ender_dragon")

	if _dragon_ref != null and is_instance_valid(_dragon_ref) and not _dragon_ref.is_queued_for_deletion():
		return

	# Spawn near the player on the central island at a visible flight height
	var base = player.global_position if player else Vector3(0, 55, 0)
	var spawn_pos = Vector3(base.x + 12.0, base.y + 12.0, base.z + 8.0)
	var dragon = mob_manager.spawn("ender_dragon", spawn_pos)
	if dragon == null:
		# Fallback id from older data
		dragon = mob_manager.spawn("erebus_sovereign", spawn_pos)
		if dragon != null and dragon.has_method("setup"):
			# Force flying-boss behavior if the rename entry lacks it
			dragon._is_flying_boss = true
			dragon.speed = 12.0
	if dragon != null:
		dragon.add_to_group("ender_dragon")
		_dragon_ref = dragon
		if dragon.has_signal("died"):
			dragon.died.connect(_on_ender_dragon_died)
		print("Ender Dragon gespawnt bei ", spawn_pos, " id=", dragon.mob_id if "mob_id" in dragon else "?")
	else:
		print("Ender Dragon spawn fehlgeschlagen – weder ender_dragon noch erebus_sovereign in Registry?")


func _on_ender_dragon_died() -> void:
	_spawn_end_portal_ring()
	_dragon_ref = null

func _spawn_end_portal_ring() -> void:
	if world == null or player == null:
		return

	# Portal an der Spielerposition erzeugen, damit er nicht eingesperrt ist,
	# egal wo der Dragon gestorben ist.
	var px = floori(player.global_position.x)
	var py = floori(player.global_position.y)
	var pz = floori(player.global_position.z)

	# Kleine Plattform freiräumen, damit der Ring nicht in Fels eingebettet ist
	for x in range(-3, 4):
		for z in range(-3, 4):
			for y in range(0, 2):
				world.set_block(px + x, py + y, pz + z, "air")

	for x in range(-3, 4):
		for z in range(-3, 4):
			var dist = Vector2(x, z).length()
			if dist <= 3.0 and dist >= 2.0:
				world.set_block(px + x, py, pz + z, "end_portal")

	_spawn_portal_smoke(Vector3(px + 0.5, py + 1.0, pz + 0.5))

	if renderer != null:
		renderer.max_builds_per_call = 9999
		renderer.update_around(player.global_position, 2)
		renderer.max_builds_per_call = 3


func _spawn_portal_smoke(pos: Vector3) -> void:
	# Kleiner, dauerhaft laufender Rauch/Partikel-Wirbel über dem
	# Portal-Ring, damit man ihn auch aus der Ferne findet - ohne
	# echtes Portal-Objekt/Sound wäre der Ring sonst kaum sichtbar.
	var smoke := GPUParticles3D.new()
	smoke.name = "PortalSmoke"
	smoke.amount = 80
	smoke.lifetime = 3.0
	smoke.preprocess = 3.0
	smoke.explosiveness = 0.0
	smoke.randomness = 0.4
	smoke.local_coords = false
	smoke.visibility_aabb = AABB(Vector3(-6, -2, -6), Vector3(12, 14, 12))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 1, 0)
	pm.emission_ring_radius = 2.5
	pm.emission_ring_inner_radius = 1.8
	pm.emission_ring_height = 0.1
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 15.0
	pm.gravity = Vector3(0, 0.35, 0)
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.color = Color(0.55, 0.15, 0.75, 0.55)
	smoke.process_material = pm

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.6, 0.6)
	smoke.draw_pass_1 = mesh

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.6, 0.2, 0.8, 0.5)
	smoke.material_override = mat

	add_child(smoke)
	smoke.global_position = pos
	smoke.emitting = true

func _setup_environment() -> void:
		var hs = get_node("/root/HCSettings") if has_node("/root/HCSettings") else null
		sun = DirectionalLight3D.new()
		sun.shadow_enabled = true
		if hs != null:
			# 0 = shadows off, 1 = low-res shadows, 2 = high-res shadows
			sun.shadow_enabled = hs.shadow_quality > 0
			sun.directional_shadow_max_distance = 80.0 if hs.shadow_quality <= 1 else 200.0
		add_child(sun)
		moon = DirectionalLight3D.new()
		moon.shadow_enabled = false
		moon.light_color = Color(0.9, 0.95, 1.0)
		add_child(moon)
		env = Environment.new()
		env.background_mode = Environment.BG_SKY
		var shader := load("res://shaders/sky.gdshader")
		sky_material = ShaderMaterial.new()
		sky_material.shader = shader
		var sky := Sky.new()
		sky.sky_material = sky_material
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		if hs != null:
			# render_distance (in chunks) drives fade-out distance fog so far
			# terrain doesn't just hard-pop/disappear at the chunk load edge.
			var fog_dist = float(clampi(hs.render_distance, 2, 32)) * VoxelWorld.CHUNK_SIZE
			env.fog_enabled = true
			env.fog_light_color = Color(0.7, 0.8, 0.9)
			env.fog_density = 0.0
			env.fog_depth_begin = fog_dist * 0.6
			env.fog_depth_end = fog_dist
		var we = WorldEnvironment.new()
		we.environment = env
		add_child(we)
func _update_sky(dim: String) -> void:
		if dim == "overworld":
			env.background_mode = Environment.BG_SKY
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			sun.visible = true
			_daynight = true
		elif dim == "hell":
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.16, 0.03, 0.03)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.55, 0.22, 0.16)
			env.ambient_light_energy = 0.6
			sun.visible = false
			_daynight = false
		elif dim == "the_end":
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.04, 0.05, 0.10)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.42, 0.46, 0.62)
			env.ambient_light_energy = 0.55
			sun.visible = false
			_daynight = false
		elif dim == "heaven":
			env.background_mode = Environment.BG_SKY
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_energy = 0.95
			sun.visible = true
			sun.light_energy = 1.3
			_daynight = false
func is_night() -> bool:
	if not _daynight:
		return false
	return sin(time_of_day * TAU - PI / 2.0) < 0.0
func _process(delta: float) -> void:
# ============================================
# REGEN + GEWITTER TIMER
# ============================================
		rain_timer -= delta
		if rain_timer <= 0.0:
			rain_timer = randf_range(80.0, 260.0)
			is_raining = randf() < 0.40
			# Gewitter mit 50% Chance starten, wenn es regnet - EINMALIG
			# beim Timer-Reset entschieden, nicht jeden Frame neu würfeln.
			is_thunderstorm = is_raining and randf() < 0.50
			if is_thunderstorm:
				thunder_timer = randf_range(6.0, 18.0)

# Rain Strength JEDEN Frame glätten (nicht nur beim Timer-Reset, sonst
# bleibt der Shader-Parameter fast immer auf einem veralteten Wert hängen)
		var target_rain := 1.0 if is_raining else 0.0
		rain_strength = move_toward(rain_strength, target_rain, delta * 0.28)
# ============================================
# REGEN PARTIKEL STEUERN
# ============================================
		if rain_particles:
			rain_particles.emitting = is_raining
			rain_particles.amount = 1850 if is_thunderstorm else 1150
			# Follow average of all split players so every viewport sees rain nearby
			var rain_pos = player.global_position if player != null else Vector3.ZERO
			if split_screen_mgr != null and split_screen_mgr.players.size() > 1:
				var acc = Vector3.ZERO
				var n = 0
				for sp in split_screen_mgr.players:
					if sp != null and is_instance_valid(sp):
						acc += sp.global_position
						n += 1
				if n > 0:
					rain_pos = acc / float(n)
			rain_particles.global_position = rain_pos + Vector3(0, 28, 0)
# ============================================
# GEWITTER + BLITZ LOGIK
# ============================================
		if is_thunderstorm:
			thunder_timer -= delta
			if thunder_timer <= 0.0:
# === BLITZ AUSLÖSEN ===
				thunder_flash = 1.0
				if lightning_light:
					lightning_light.light_energy = 5.0
				thunder_timer = randf_range(5.5, 14.0)

# Blitz + Licht JEDEN Frame ausblenden (vorher nur sporadisch erreicht)
		thunder_flash = move_toward(thunder_flash, 0.0, delta * 3.8)
		if lightning_light:
			lightning_light.light_energy = move_toward(lightning_light.light_energy, 0.0, delta * 9.0)
# ============================================
# SHADER PARAMETER AKTUALISIEREN
# ============================================
		if sky_material:
			sky_material.set_shader_parameter("time_of_day", time_of_day)
			sky_material.set_shader_parameter("rain_amount", rain_strength)
			sky_material.set_shader_parameter("thunder_flash", thunder_flash)
# ============================================
# DAY/NIGHT CYCLE
# ============================================
		if not _daynight:
			return
		time_of_day = fmod(time_of_day + delta / day_length, 1.0)
		var angle = time_of_day * TAU
		var elevation = sin(angle - PI / 2.0)
		var day_factor = clampf(elevation, 0.0, 1.0)
		var night_factor = clampf(-elevation, 0.0, 1.0)
# === SONNE ===
		if sun:
			sun.rotation_degrees.x = -time_of_day * 360.0 + 90.0
		if elevation > 0.05:
			sun.light_energy = lerp(0.12, 1.4, day_factor)
			sun.visible = true
		else:
			sun.light_energy = 0.0
			sun.visible = false
# === MOND ===
		if moon:
			moon.rotation_degrees.x = sun.rotation_degrees.x + 180.0
		if elevation < -0.1:
			moon.light_energy = lerp(0.0, 0.85, night_factor)
			moon.visible = true
		else:
			moon.light_energy = 0.0
			moon.visible = false
var _footprint_dist: float = 0.0
var _last_pos_for_footprints: Vector3 = Vector3.INF
var _footprint_side: int = 1


var _plate_cells: Dictionary = {}  # Vector3i -> bool pressed

func _update_redstone_world(_delta: float) -> void:
	if world == null or renderer == null or player == null:
		return
	var pc = Vector3i(
		floori(player.global_position.x),
		floori(player.global_position.y - 0.1),
		floori(player.global_position.z)
	)
	# Pressure plates near player (Interactor also handles; this is backup)
	for d in [Vector3i(0, 0, 0), Vector3i(0, -1, 0), Vector3i(0, 1, 0)]:
		var c = pc + d
		var id = world.get_block(c.x, c.y, c.z)
		if id == "pressure_plate" and _player_near_plate(c):
			renderer.edit_block(c.x, c.y, c.z, "pressure_plate_on")
			_plate_cells[c] = true
			Redstone.pulse(self, world, renderer, c)
		elif id == "pressure_plate_on" and not _player_near_plate(c):
			renderer.edit_block(c.x, c.y, c.z, "pressure_plate")
			_plate_cells.erase(c)
			Redstone.pulse(self, world, renderer, c)

	# Daylight sensor: on by day, off by night (scan near player)
	var day = not is_night()
	for dx in range(-6, 7):
		for dz in range(-6, 7):
			for dy in range(-2, 3):
				var c3 = Vector3i(pc.x + dx, pc.y + dy, pc.z + dz)
				var bid = world.get_block(c3.x, c3.y, c3.z)
				if bid == "daylight_sensor" and day:
					renderer.edit_block(c3.x, c3.y, c3.z, "daylight_sensor_on")
					Redstone.pulse(self, world, renderer, c3)
				elif bid == "daylight_sensor_on" and not day:
					renderer.edit_block(c3.x, c3.y, c3.z, "daylight_sensor")
					Redstone.pulse(self, world, renderer, c3)
					
					
var command_blocks: Dictionary = {}  # Vector3i -> String command

func get_command_block_cmd(cell: Vector3i) -> String:
	return str(command_blocks.get(cell, ""))

func get_command_block_command(cell: Vector3i) -> String:
	return get_command_block_cmd(cell)

func set_command_block_cmd(cell: Vector3i, cmd: String) -> void:
	command_blocks[cell] = cmd

func set_command_block_command(cell: Vector3i, cmd: String) -> void:
	set_command_block_cmd(cell, cmd)

func run_command_block(cell: Vector3i) -> void:
	var cmd = get_command_block_cmd(cell).strip_edges()
	# Fallback: command only stored in UI local dict (if game wasn't wired yet)
	if cmd == "" and ui != null and ui.get("_command_block_texts") != null:
		var key = str(cell)
		cmd = str(ui._command_block_texts.get(key, "")).strip_edges()
		if cmd != "":
			command_blocks[cell] = cmd
	if cmd == "":
		print("[CommandBlock] ", cell, " → (empty command)")
		return
	if not cmd.begins_with("/"):
		cmd = "/" + cmd
	if player != null:
		var r = CommandParser.execute(cmd, self, player)
		print("[CommandBlock] ", cell, " → ", r)
		if ui != null:
			if ui.has_method("show_chat_message"):
				ui.show_chat_message(str(r))
			elif ui.get("_chat_msg") != null:
				ui._chat_msg.text = str(r)
			if ui.has_method("_show_chat_line"):
				ui._show_chat_line(1, str(r))


func _player_near_plate(c: Vector3i) -> bool:
	var p = player.global_position
	return absf(p.x - (c.x + 0.5)) < 0.7 and absf(p.z - (c.z + 0.5)) < 0.7 and absf(p.y - c.y) < 1.5

func _physics_process(delta: float) -> void:
	_tick_hoppers(delta)

	if player == null or renderer == null:
		return
	if _is_loading:
		return

	var load_radius: int = RADIUS
	if has_node("/root/HCSettings"):
		var hs = get_node("/root/HCSettings")
		load_radius = hs.effective_load_radius()
		if hs.footprints:
			_update_footprints(delta)
	if split_screen_mgr != null and split_screen_mgr.players.size() > 1:
		# Keep chunks loaded around every local player
		for sp in split_screen_mgr.players:
			if sp != null and is_instance_valid(sp):
				renderer.update_around(sp.global_position, load_radius)
	else:
		renderer.update_around(player.global_position, load_radius)
	for f in furnaces.values():
		f.tick(delta)
	if _portal_cd > 0.0:
		_portal_cd -= delta
	else:
		_check_portal()
		_handle_portal_walking()

	# Fallback: falls kein "died"-Signal existiert, Health direkt prüfen
	if _dragon_ref != null:
		if not is_instance_valid(_dragon_ref):
			_on_ender_dragon_died()
		elif _dragon_ref.has_method("get") and "health" in _dragon_ref and _dragon_ref.health <= 0:
			_on_ender_dragon_died()

	_update_redstone_world(delta)

func _check_portal() -> void:
	if player == null or world == null:
		return

	var px = floori(player.global_position.x)
	var py = floori(player.global_position.y)
	var pz = floori(player.global_position.z)

	# Prüfe mehrere Positionen um den Spieler herum (Füße + etwas höher)
	var positions_to_check = [
		Vector3i(px, py, pz),
		Vector3i(px, py + 1, pz),
		Vector3i(px, py, pz + 1),
		Vector3i(px, py, pz - 1),
		Vector3i(px + 1, py, pz),
		Vector3i(px - 1, py, pz)
	]

	for pos in positions_to_check:
		var b = world.get_block(pos.x, pos.y, pos.z)
		if PORTAL_LINK.has(b):
			var link = PORTAL_LINK[b]
			var target_dim = link[1] if current_dim == link[0] else link[0]
			travel_to(target_dim, b)
			return
func _handle_portal_walking() -> void:
	if player == null or world == null:
		return

	var px = floori(player.global_position.x)
	var py = floori(player.global_position.y)
	var pz = floori(player.global_position.z)

	var b = world.get_block(px, py, pz)

	if _is_portal_block(b):
		# Spieler leicht in Blickrichtung nach vorne schieben
		var forward = -player.global_transform.basis.z.normalized() * 1.2
		player.global_position += forward
			
func activate_dispenser(cell: Vector3i) -> void:
	var inv = get_dispenser(cell)
	if inv.is_empty():
		print("Dispenser at ", cell, " is empty – nothing dispensed")
		return

	var stack = inv.take_one()
	if stack == null:
		return

	var spawn_pos = Vector3(cell) + Vector3(0.5, 0.5, 0.5)
	# Default direction: north (-Z). Later: store facing on the block.
	var direction = Vector3(0, 0, -1)
	spawn_pos += direction * 0.8

	# Spawn eggs → spawn the mob in front of the dispenser (1.6.4-style)
	if str(stack.item_id).begins_with("spawn_egg_"):
		var mob_id = str(stack.item_id).substr("spawn_egg_".length())
		if mob_manager != null and not mob_id.is_empty():
			mob_manager.spawn(mob_id, spawn_pos + direction * 0.5)
			Audio.play("place")
			print("Dispenser spawned mob: ", mob_id)
		return

	# Shoot arrows / projectiles
	if stack.item_id == "arrow":
		var arrow = preload("res://scenes/arrow.tscn").instantiate()
		arrow.global_position = spawn_pos
		add_child(arrow)
		if arrow.has_method("setup"):
			arrow.setup(direction, null)
		Audio.play("place")
		return

	# Everything else: drop as item entity
	var item_entity = preload("res://scenes/item_entity.tscn").instantiate()
	add_child(item_entity)
	item_entity.global_position = spawn_pos
	if item_entity.has_method("setup"):
		item_entity.setup(stack.item_id, 1, player)
	# Give it a little push
	if item_entity is RigidBody3D:
		item_entity.linear_velocity = direction * 6.0
	Audio.play("place")
	print("Dispenser dispensed: ", stack.item_id)
		
		
func _is_portal_block(block_id: String) -> bool:
	return block_id == "nether_portal" or block_id == "end_portal" or block_id == "heaven_portal"


func _tick_hoppers(delta: float) -> void:
	# 1.6.4 hopper: ~1 item / 4 ticks ≈ 0.2s
	_hopper_tick -= delta
	if _hopper_tick > 0.0:
		return
	_hopper_tick = 0.2
	if world == null:
		return
	for cell in hoppers.keys():
		if is_hopper_locked(cell):
			continue
		var inv = hoppers[cell]
		if inv == null or inv.is_empty():
			# try pull from chest/dispenser above
			var above = cell + Vector3i(0, 1, 0)
			_hopper_try_pull(cell, above)
			continue
		# push down into container below
		var below = cell + Vector3i(0, -1, 0)
		_hopper_try_push(cell, below)


func _hopper_try_pull(hopper_cell: Vector3i, from_cell: Vector3i) -> void:
	var bid = world.get_block(from_cell.x, from_cell.y, from_cell.z)
	var src = null
	if bid == "chest":
		src = get_chest(from_cell)
	elif bid == "dispenser":
		src = get_dispenser(from_cell)
	elif bid == "dropper":
		src = get_dropper(from_cell)
	elif bid == "hopper":
		src = get_hopper(from_cell)
	if src == null:
		return
	var inv = get_hopper(hopper_cell)
	# src is Array (chest) or DispenserInventory
	if src is Array:
		for i in range(src.size()):
			if src[i] != null and src[i].count > 0:
				var s = src[i]
				var moved = ItemStack.new(s.item_id, 1)
				# find empty/same in hopper
				for j in range(inv.slots.size()):
					if inv.slots[j] == null:
						inv.slots[j] = moved
						s.count -= 1
						if s.count <= 0:
							src[i] = null
						return
					elif inv.slots[j].item_id == s.item_id and inv.slots[j].count < 64:
						inv.slots[j].count += 1
						s.count -= 1
						if s.count <= 0:
							src[i] = null
						return
	elif src is DispenserInventory:
		var one = src.take_one()
		if one == null:
			return
		for j in range(inv.slots.size()):
			if inv.slots[j] == null:
				inv.slots[j] = one
				return
			elif inv.slots[j].item_id == one.item_id and inv.slots[j].count < 64:
				inv.slots[j].count += 1
				return
		# no space — put back
		for j in range(src.slots.size()):
			if src.slots[j] == null:
				src.slots[j] = one
				return


func _hopper_try_push(hopper_cell: Vector3i, to_cell: Vector3i) -> void:
	var bid = world.get_block(to_cell.x, to_cell.y, to_cell.z)
	var inv = get_hopper(hopper_cell)
	var one = inv.take_one()
	if one == null:
		return
	var dst = null
	if bid == "chest":
		dst = get_chest(to_cell)
	elif bid == "dispenser":
		dst = get_dispenser(to_cell)
	elif bid == "dropper":
		dst = get_dropper(to_cell)
	elif bid == "hopper":
		dst = get_hopper(to_cell)
	if dst == null:
		# put back
		for j in range(inv.slots.size()):
			if inv.slots[j] == null:
				inv.slots[j] = one
				return
		return
	if dst is Array:
		for i in range(dst.size()):
			if dst[i] == null:
				dst[i] = one
				return
			elif dst[i].item_id == one.item_id and dst[i].count < 64:
				dst[i].count += 1
				return
		# full — return
		for j in range(inv.slots.size()):
			if inv.slots[j] == null:
				inv.slots[j] = one
				return
	elif dst is DispenserInventory:
		for j in range(dst.slots.size()):
			if dst.slots[j] == null:
				dst.slots[j] = one
				return
			elif dst.slots[j].item_id == one.item_id and dst.slots[j].count < 64:
				dst.slots[j].count += 1
				return
		for j in range(inv.slots.size()):
			if inv.slots[j] == null:
				inv.slots[j] = one
				return
