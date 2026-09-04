extends Node3D
var is_raining := false
var rain_strength := 0.0
var rain_timer := 0.0
var rain_particles: GPUParticles3D
var _rain_emitters: Array = []
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
const OVERWORLD_SKY_SHADER: Shader = preload("res://shaders/sky.gdshader")
var sky_material: ShaderMaterial
var sky_resource: Sky
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
var _portal_check_t: float = 0.0
var _return_points: Dictionary = {}
var _last_pos_for_footprints: Vector3 = Vector3.INF
var _footprint_dist: float = 0.0
var _footprint_side: float = 1.0
var _net_state_t: float = 0.0
var _remote_players: Dictionary = {}
var _remote_targets: Dictionary = {}
var _command_block_commands: Dictionary = {}
var brewing_stands: Dictionary = {}
var _starter_chest_created: bool = false
var _dimension_traveling: bool = false
var _portal_enter_time: float = 0.0
var _portal_overlay: ColorRect
var _dragon_dead: bool = false
var _fluid_tick: float = 0.0
var _crystal_tick: float = 0.0
var _boss_bar: ProgressBar = null
var _stronghold_cache: Vector3 = Vector3.INF
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
		var rain_quad := QuadMesh.new()
		rain_quad.size = Vector2(0.045, 1.1)
		var rain_mat := StandardMaterial3D.new()
		rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Always face the active camera. BILLBOARD_PARTICLES follows the particle
		# transform and can turn thin rain quads edge-on, which looks as if rain is
		# rendered from only one side. Regular billboarding plus disabled culling is
		# stable for solo and every split-screen SubViewport.
		rain_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		rain_mat.billboard_keep_scale = true
		rain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		rain_mat.vertex_color_use_as_albedo = true
		rain_mat.albedo_color = Color(0.78, 0.84, 0.95, 0.72)
		rain_quad.material = rain_mat
		rain_particles.draw_pass_1 = rain_quad
		
func _setup_lightning_light() -> void:
		lightning_light = OmniLight3D.new()
		lightning_light.light_color = Color(0.9, 0.95, 1.0)
		lightning_light.light_energy = 0.0
		lightning_light.omni_range = 120.0
		lightning_light.shadow_enabled = false
		add_child(lightning_light)
func _ready() -> void:
	add_to_group("game")
	# A new session always starts clear. Previously rain_timer started at zero,
	# so the first _process() frame immediately rolled weather and could cover the
	# sun before the player ever saw the normal sky.
	is_raining = false
	is_thunderstorm = false
	rain_strength = 0.0
	rain_timer = randf_range(90.0, 180.0)
	thunder_timer = 0.0
	thunder_flash = 0.0
	# Isolate world data: only start a brand-new world if we are NOT loading a save
	if has_node("/root/Config"):
		if Config.pending_save != null:
			print("[HighCraft] pending save present — will apply after player spawn")
		elif str(Config.world_id) == "":
			Config.begin_new_world()
	_is_loading = true
	_ensure_loading_ui()
	if _loading_label:
		_loading_label.text = "Loading world..."
	await get_tree().process_frame
	await get_tree().process_frame

	rain_particles = GPUParticles3D.new()
	add_child(rain_particles)
	_setup_rain_particles() # ← NEU
	_setup_lightning_light() # ← NEU
	rain_particles.emitting = false
	_setup_environment()
	dim_mgr = DimensionManager.new(Config.seed_val, Config.world_type, Config.generate_structures)
	if has_node("/root/Multiplayer"):
		Multiplayer.pvp_enabled = Config.pvp_enabled
	world = dim_mgr.get_world("overworld")
	renderer = ChunkRenderer.new()
	add_child(renderer)
	renderer.setup(world)
	var sy = world.surface_height(SPAWN_X, SPAWN_Z)
	if sy < 1:
		sy = VoxelWorld.SEA_LEVEL
	# Force-build spawn chunks WITH collision BEFORE the player exists (prevents fall-through)
	renderer.max_builds_per_call = 9999
	renderer._use_threads = false
	var scx = floori(float(SPAWN_X) / float(VoxelWorld.CHUNK_SIZE))
	var scz = floori(float(SPAWN_Z) / float(VoxelWorld.CHUNK_SIZE))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			renderer.build_chunk(scx + dx, scz + dz)
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
	mob_manager.get_is_night = func():
		return is_night() or is_raining
	mob_manager.game = self

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
		player.set_meta("spawn_frozen", true)
		if "velocity" in player:
			player.velocity = Vector3.ZERO

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
		# Directional shadow maps are corrupted in additional Mobile/Vulkan
		# SubViewports on Adreno (large black regions following the cameras).
		# Keep full lighting/native resolution, but disable this broken pass locally.
		if sun != null:
			sun.shadow_enabled = false

		player = split_screen_mgr.players[0]
		for i in range(split_screen_mgr.players.size()):
			var p = split_screen_mgr.players[i]
			p.configure(Config.game_mode, Config.difficulty)
			p.set_meta("spawn_frozen", true)
			if "velocity" in p:
				p.velocity = Vector3.ZERO
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
	_configure_rain_emitters()

	# Load World: restore edits, inventory, position (must run AFTER player exists)
	if has_node("/root/Config") and Config.pending_save != null:
		var save_data = Config.pending_save
		Config.pending_save = null
		_apply_save(save_data)
		print("[HighCraft] loaded world from save")
	else:
		print("[HighCraft] fresh world (no pending save)")
		_create_starter_chest()

	# Pre-render spawn chunks so the first seconds are not hitching
	call_deferred("_preload_chunks")


func _configure_rain_emitters() -> void:
	for emitter in _rain_emitters:
		if emitter != rain_particles and emitter != null and is_instance_valid(emitter):
			emitter.queue_free()
	_rain_emitters = [rain_particles]
	var count := 1
	if split_screen_mgr != null:
		count = maxi(1, split_screen_mgr.players.size())
	if count > 1:
		rain_particles.layers = 1 << 14 # render layer 15, private to P1 camera
	else:
		rain_particles.layers = 1
	for i in range(1, count):
		var emitter := rain_particles.duplicate() as GPUParticles3D
		emitter.name = "RainParticlesP%d" % (i + 1)
		emitter.emitting = false
		emitter.layers = 1 << (14 + i) # render layers 16–18
		add_child(emitter)
		_rain_emitters.append(emitter)


func _stream_players() -> Array:
	var out: Array = []
	for p in get_tree().get_nodes_in_group("players"):
		if p != null and is_instance_valid(p) and p is Node3D and not bool(p.get_meta("remote_proxy", false)):
			out.append(p)
	if out.is_empty() and player != null:
		out.append(player)
	return out


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

	var radius := 6  # Minecraft-like spawn radius (~13x13 chunks)
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
	# Preload: sync main-thread builds (mesh pool + warm mesher = fast, no thread races at spawn)
	renderer._use_threads = false
	renderer.max_builds_per_call = 9999
	const BATCH := 6
	for k in unique:
		renderer.build_chunk(k.x, k.y)
		done += 1
		if _loading_label:
			_loading_label.text = "Loading world...\nChunks %d / %d" % [done, total]
		if done % BATCH == 0:
			await get_tree().process_frame

	renderer._use_threads = true
	renderer.max_builds_per_call = 8
	print("[HighCraft] preload done, loaded_chunks=", renderer.loaded_count())
	await get_tree().process_frame
	_finish_loading()


func _finish_loading() -> void:
	_setup_multiplayer_hooks()

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
		renderer._use_threads = true

	# Snap every player onto solid ground so nobody falls through unloaded collision
	_snap_players_to_ground()
	_is_loading = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _snap_players_to_ground() -> void:
	var list: Array = []
	if split_screen_mgr != null and split_screen_mgr.players.size() > 0:
		for p in split_screen_mgr.players:
			if p != null and is_instance_valid(p):
				list.append(p)
	elif player != null:
		list.append(player)
	for p in list:
		if world == null:
			continue
		var px = floori(p.global_position.x)
		var pz = floori(p.global_position.z)
		var sy = world.surface_height(px, pz)
		if sy < 1:
			sy = VoxelWorld.SEA_LEVEL
		p.global_position = Vector3(px + 0.5, float(sy) + 2.0, pz + 0.5)
		p.spawn_point = p.global_position
		if "velocity" in p:
			p.velocity = Vector3.ZERO
		if p.has_meta("spawn_frozen"):
			p.remove_meta("spawn_frozen")
func gather_save() -> Dictionary:
	var edits = {}
	for dim in dim_mgr.worlds.keys():
		edits[dim] = dim_mgr.worlds[dim].export_edits()

	var pp = player.global_position
	return {
		"seed": Config.seed_val,
		"world_id": Config.world_id,
		"world_type": Config.world_type,
		"default_game_mode": Config.game_mode,
		"difficulty": Config.difficulty,
		"pvp_enabled": Config.pvp_enabled,
		"structures": Config.generate_structures,
		"time_of_day": time_of_day,
		"current_dim": current_dim,
		"player": {
			"pos": [pp.x, pp.y, pp.z],
			"health": player.health,
			"hunger": player.hunger,
			"mode": player.game_mode,
			"diff": player.difficulty,
			"xp": player.xp_level,
			"effects": player.active_effects.duplicate(true)
		},
		"inventory": player.inventory.to_data(),
		"chests": _serialize_chests(),
		"starter_chest_created": _starter_chest_created,
		"edits": edits
	}
	
func save_now() -> bool:
	if world != null and world.has_method("flush_regions"):
		world.flush_regions()
	return SaveManager.write(gather_save())
func _apply_save(data: Dictionary) -> void:
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return
	print("[HighCraft] applying save seed=", data.get("seed", "?"), " world_id=", data.get("world_id", "?"))
	# Restore block edits per dimension
	var edits = data.get("edits", {})
	if edits is Dictionary:
		for dim in edits.keys():
			var w = dim_mgr.get_world(str(dim))
			if w != null and edits[dim] is Array:
				w.import_edits(edits[dim])
	elif edits is Array and world != null:
		world.import_edits(edits)

	time_of_day = fposmod(float(data.get("time_of_day", 0.3)), 1.0)
	var pdata = data.get("player", {})
	if player != null:
		if player.inventory != null and player.inventory.has_method("from_data"):
			player.inventory.from_data(data.get("inventory", {}))
		player.configure(int(pdata.get("mode", Config.game_mode)), int(pdata.get("diff", Config.difficulty)))
		player.health = float(pdata.get("health", 20))
		player.hunger = float(pdata.get("hunger", 20))
		player.active_effects = pdata.get("effects", {}).duplicate(true)
		player._refresh_effect_visuals()
		if "xp_level" in player:
			player.xp_level = int(pdata.get("xp", 0))
	_starter_chest_created = bool(data.get("starter_chest_created", true))
	_load_chests(data.get("chests", []))

	var sdim = Registry.normalize_dimension_id(str(data.get("current_dim", "overworld")))
	var pos_arr = pdata.get("pos", [SPAWN_X + 0.5, 70, SPAWN_Z + 0.5])
	var pos = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))

	current_dim = sdim
	world = dim_mgr.get_world(sdim)
	if renderer != null:
		renderer.set_world(world)
	if interactor != null:
		interactor.world = world
		interactor.renderer = renderer
	if mob_manager != null:
		mob_manager.set_dimension(world, sdim)

	if player != null:
		player.global_position = pos
		player.spawn_point = pos
		player.set_meta("spawn_frozen", true)
		if "velocity" in player:
			player.velocity = Vector3.ZERO
	if renderer != null and world != null:
		renderer._use_threads = false
		var pcx = floori(pos.x / float(VoxelWorld.CHUNK_SIZE))
		var pcz = floori(pos.z / float(VoxelWorld.CHUNK_SIZE))
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				renderer.build_chunk(pcx + dx, pcz + dz)
	if has_method("_update_sky"):
		_update_sky(sdim)
	print("[HighCraft] save applied at ", pos, " dim=", sdim)
func get_furnace(cell: Vector3i) -> Furnace:
	if not furnaces.has(cell):
		furnaces[cell] = Furnace.new()
	return furnaces[cell]
	
var dispensers: Dictionary = {}   # Vector3i -> DispenserInventory
var piston_facing: Dictionary = {}  # Vector3i -> Vector3i push direction
var piston_extended: Dictionary = {}  # Vector3i -> bool
var redstone_power: Dictionary = {}  # Vector3i -> int strength 0-15


var hoppers: Dictionary = {}      # Vector3i -> Array (5 slots)
var droppers: Dictionary = {}     # Vector3i -> Array (9 slots)
var _hopper_tick: float = 0.0
var _region_flush_t: float = 5.0

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


func _create_starter_chest() -> void:
	if _starter_chest_created or world == null:
		return
	# One shared bonus chest per new world; players begin with empty inventories.
	var x := SPAWN_X + 3
	var z := SPAWN_Z + 2
	var y: int = int(world.surface_height(x, z)) + 1
	var cell := Vector3i(x, y, z)
	world.set_block(x, y, z, "chest")
	world.set_block(x, y + 1, z, "air")
	var slots := get_chest(cell)
	var loot := [["wood_pickaxe", 1], ["wood_axe", 1], ["oak_log", 6], ["oak_planks", 12], ["stick", 8], ["bread", 6], ["torch", 8], ["apple", 3]]
	for i in range(loot.size()):
		slots[i] = ItemStack.new(str(loot[i][0]), int(loot[i][1]))
	_starter_chest_created = true
	if renderer != null:
		renderer.build_chunk(floori(float(x) / 16.0), floori(float(z) / 16.0))


func _serialize_chests() -> Array:
	var result: Array = []
	for cell in chests.keys():
		var slots: Array = []
		for stack in chests[cell]:
			if stack == null:
				slots.append(null)
			else:
				slots.append({"id": stack.item_id, "count": stack.count, "dur": stack.durability, "enchantments": stack.enchantments.duplicate(true), "custom_name": stack.custom_name})
		result.append({"cell": [cell.x, cell.y, cell.z], "slots": slots})
	return result


func _load_chests(entries: Array) -> void:
	chests.clear()
	for entry in entries:
		var xyz = entry.get("cell", [])
		if xyz.size() != 3:
			continue
		var slots := get_chest(Vector3i(int(xyz[0]), int(xyz[1]), int(xyz[2])))
		var saved = entry.get("slots", [])
		for i in range(mini(slots.size(), saved.size())):
			if saved[i] == null:
				continue
			var data: Dictionary = saved[i]
			var stack := ItemStack.new(str(data.get("id", "")), int(data.get("count", 1)))
			stack.durability = int(data.get("dur", -1))
			stack.enchantments = data.get("enchantments", {}).duplicate(true)
			stack.custom_name = str(data.get("custom_name", ""))
			slots[i] = stack


func get_brewing_stand(cell: Vector3i):
	var key := current_dim + ":" + str(cell)
	if not brewing_stands.has(key):
		brewing_stands[key] = load("res://scripts/crafting/brewing_stand.gd").new()
	return brewing_stands[key]

func set_weather(mode: String) -> void:
	mode = mode.to_lower()
	is_raining = mode in ["rain", "rainy", "thunder", "thunderstorm"]
	is_thunderstorm = mode in ["thunder", "thunderstorm"]
	rain_strength = 1.0 if is_raining else 0.0
	rain_timer = 180.0 if is_raining else 300.0
	thunder_timer = 0.25 if is_thunderstorm else 0.0
	thunder_flash = 0.0
	for emitter in _rain_emitters:
		if emitter != null and is_instance_valid(emitter): emitter.emitting = is_raining
	if not is_thunderstorm and lightning_light != null: lightning_light.light_energy = 0.0
	if sky_material != null and sky_material.shader != null:
		sky_material.set_shader_parameter("rain_amount", rain_strength)
		sky_material.set_shader_parameter("thunder_flash", 0.0)
	if split_screen_mgr != null:
		split_screen_mgr.set_sky_parameter("rain_amount", rain_strength)
		split_screen_mgr.set_sky_parameter("thunder_flash", 0.0)


func set_command_block_command(cell: Vector3i, command: String) -> void:
	var cleaned := command.strip_edges()
	if cleaned.is_empty(): _command_block_commands.erase(cell)
	else: _command_block_commands[cell] = cleaned


func set_command_block_cmd(cell: Vector3i, command: String) -> void:
	set_command_block_command(cell, command)


func get_command_block_command(cell: Vector3i) -> String:
	return str(_command_block_commands.get(cell, ""))


func run_command_block(cell: Vector3i) -> String:
	var command := get_command_block_command(cell)
	if command.is_empty(): return "No command stored."
	var executor = player
	var best_distance := INF
	for candidate in _stream_players():
		var distance = candidate.global_position.distance_squared_to(Vector3(cell) + Vector3(0.5, 0.5, 0.5))
		if distance < best_distance: executor = candidate; best_distance = distance
	var result := CommandParser.execute(command, self, executor)
	if ui != null:
		if ui.has_method("_push_chat_history"): ui._push_chat_history(result)
		elif ui.get("_chat_msg") != null: ui._chat_msg.text = result
	print("[CommandBlock] ", cell, " ", command, " -> ", result)
	return result


func sleep() -> void:
	if not is_night():
		if ui != null:
			ui._chat_msg.text = "You can only sleep at night."
		return
	time_of_day = 0.27
	is_raining = false
	is_thunderstorm = false
	rain_strength = 0.0
	rain_timer = randf_range(120.0, 240.0)
	thunder_flash = 0.0
	if ui != null:
		ui._chat_msg.text = "Slept through the night."
func _music_ctx(dim: String) -> String:
	if dim == "the_end":
		return "end"
	return dim
func travel_to(dim: String, _portal_block: String) -> void:
	dim = Registry.normalize_dimension_id(dim)
	if current_dim == dim:
		return
	if player == null or dim_mgr == null:
		return
	if _dimension_traveling:
		return
	_dimension_traveling = true
	_show_dimension_loading(dim)
	await get_tree().process_frame
	await get_tree().process_frame

	print("[HighCraft] travel ", current_dim, " -> ", dim)
	# Save exit point OFFSET from the portal so return is never inside the frame
	_return_points[current_dim] = _offset_from_portals(player.global_position)

	is_raining = false
	is_thunderstorm = false
	rain_strength = 0.0
	rain_timer = randf_range(90.0, 180.0)
	thunder_flash = 0.0
	if rain_particles != null:
		rain_particles.emitting = false
	if lightning_light != null:
		lightning_light.light_energy = 0.0

	current_dim = dim
	world = dim_mgr.get_world(dim)

	if renderer != null:
		renderer.set_world(world)

	if interactor != null:
		interactor.world = world
		interactor.renderer = renderer
	if split_screen_mgr != null and split_screen_mgr.players.size() > 0:
		for p in split_screen_mgr.players:
			if p != null and p.get("interactor") != null:
				p.interactor.world = world
				p.interactor.renderer = renderer

	if mob_manager != null:
		mob_manager.set_dimension(world, dim)

	for m in get_tree().get_nodes_in_group("mobs"):
		if is_instance_valid(m):
			m.queue_free()
	_dragon_ref = null
	for m in get_tree().get_nodes_in_group("item_entities"):
		if is_instance_valid(m):
			m.queue_free()

	var pos: Vector3
	if _return_points.has(dim):
		pos = _return_points[dim]
	elif dim == "the_end":
		var sy = world.surface_height(0, 0)
		if sy < 1:
			sy = 55
		pos = Vector3(0.5, float(sy) + 2.0, 0.5)
	elif dim == "hell":
		var sx = int(player.global_position.x)
		var sz = int(player.global_position.z)
		var sy = world.surface_height(sx, sz)
		if sy < 1:
			sy = 64
		pos = Vector3(sx + 0.5, float(sy) + 2.0, sz + 0.5)
	else:
		var sx = int(player.global_position.x)
		var sz = int(player.global_position.z)
		var sy = world.surface_height(sx, sz)
		pos = Vector3(sx + 0.5, float(sy) + 2.0, sz + 0.5)

	# NEVER land inside / on a portal — breaks infinite nether↔overworld loops
	if dim in ["the_end", "heaven"]:
		pos = _ensure_obsidian_spawn_platform(pos, dim)
	pos = _safe_portal_exit(pos)

	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.spawn_point = pos

	if renderer != null:
		renderer.max_builds_per_call = 9999
		var pcx = floori(pos.x / float(VoxelWorld.CHUNK_SIZE))
		var pcz = floori(pos.z / float(VoxelWorld.CHUNK_SIZE))
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				renderer.build_chunk(pcx + dx, pcz + dz)
		renderer.max_builds_per_call = 8

	if dim == "the_end":
		_spawn_ender_dragon()

	# Long cooldown so the player can walk away before portals re-trigger
	_portal_cd = 6.0
	_update_sky(dim)
	if has_node("/root/Music"):
		Music.play_for_dimension(_music_ctx(dim))
	Audio.play("water_splash" if dim == "heaven" else "fire_ignite" if dim == "hell" else "ui_achievement", -8.0)
	_snap_players_to_ground()
	# Let the new meshes and sky land on screen before dropping the overlay.
	await get_tree().process_frame
	await get_tree().process_frame
	_hide_dimension_loading()
	_dimension_traveling = false


func _show_dimension_loading(dim: String) -> void:
	_ensure_loading_ui()
	if _loading_label:
		_loading_label.visible = true
		if _loading_label.has_meta("layer"):
			var layer = _loading_label.get_meta("layer")
			if is_instance_valid(layer):
				layer.visible = true
				var bg = layer.get_node_or_null("LoadingBG")
				if bg:
					bg.visible = true
		var nice = dim.replace("_", " ").capitalize()
		if dim == "hell":
			nice = "The Hell"
		elif dim == "the_end":
			nice = "The End"
		_loading_label.text = "Entering " + nice + "..."
	_spawn_portal_enter_flash()


func _hide_dimension_loading() -> void:
	# Must free the whole CanvasLayer. Hiding only the label left the black
	# LoadingBG ColorRect covering the new dimension (overworld was fine
	# because first-load uses _finish_loading which already frees the layer).
	if _loading_label != null and is_instance_valid(_loading_label):
		if _loading_label.has_meta("layer"):
			var layer = _loading_label.get_meta("layer")
			if is_instance_valid(layer):
				layer.queue_free()
		else:
			var parent = _loading_label.get_parent()
			if parent != null and is_instance_valid(parent):
				parent.queue_free()
			elif is_instance_valid(_loading_label):
				_loading_label.queue_free()
	_loading_label = null


func _spawn_portal_enter_flash() -> void:
	if _portal_overlay != null and is_instance_valid(_portal_overlay):
		_portal_overlay.queue_free()
	_portal_overlay = ColorRect.new()
	_portal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portal_overlay.color = Color(0.45, 0.15, 0.7, 0.55)
	_portal_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	layer.add_child(_portal_overlay)
	var tw = create_tween()
	tw.tween_property(_portal_overlay, "color:a", 0.0, 0.6)
	tw.finished.connect(func():
		if is_instance_valid(layer):
			layer.queue_free()
		_portal_overlay = null
	)


func _ensure_obsidian_spawn_platform(near: Vector3, dim: String) -> Vector3:
	# A deterministic 5x5 safety platform is created before chunk meshing. Heaven
	# islands are sparse and End spawn terrain may be absent/edited away.
	var cx := floori(near.x)
	var cz := floori(near.z)
	var platform_y := 72 if dim == "heaven" else maxi(56, world.surface_height(cx, cz) + 1)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			world.set_block(cx + dx, platform_y, cz + dz, "obsidian")
			for dy in range(1, 4):
				world.set_block(cx + dx, platform_y + dy, cz + dz, "air")
	return Vector3(cx + 0.5, float(platform_y) + 2.0, cz + 0.5)


func _is_portal_at(wx: int, wy: int, wz: int) -> bool:
	if world == null:
		return false
	var id = str(world.get_block(wx, wy, wz))
	return id in ["nether_portal", "end_portal", "heaven_portal"]


func _offset_from_portals(from: Vector3) -> Vector3:
	# Prefer a few blocks sideways from current portal
	var base = from
	for dist in [3, 4, 5, 6, 8]:
		for d in [Vector3(dist, 0, 0), Vector3(-dist, 0, 0), Vector3(0, 0, dist), Vector3(0, 0, -dist),
				Vector3(dist, 0, dist), Vector3(-dist, 0, -dist)]:
			var p = base + d
			var sy = world.surface_height(floori(p.x), floori(p.z)) if world else int(p.y)
			p.y = float(sy) + 2.0
			if not _is_portal_at(floori(p.x), floori(p.y), floori(p.z)) and not _is_portal_at(floori(p.x), floori(p.y) - 1, floori(p.z)):
				return p
	return base + Vector3(4, 0, 0)


func _safe_portal_exit(pos: Vector3) -> Vector3:
	# Search for a landing spot with no portal blocks in a 2-block body volume
	var candidates: Array = [pos]
	for dist in [3, 4, 5, 6, 8, 10]:
		for d in [
			Vector3(dist, 0, 0), Vector3(-dist, 0, 0), Vector3(0, 0, dist), Vector3(0, 0, -dist),
			Vector3(dist, 0, dist), Vector3(-dist, 0, dist), Vector3(dist, 0, -dist), Vector3(-dist, 0, -dist)
		]:
			candidates.append(pos + d)
	for c in candidates:
		var x = floori(c.x)
		var z = floori(c.z)
		var sy = world.surface_height(x, z) if world else int(c.y)
		if sy < 1:
			sy = int(c.y)
		var y = sy + 1
		var ok = true
		for dy in range(0, 3):
			if _is_portal_at(x, y + dy, z):
				ok = false
				break
		if ok:
			return Vector3(x + 0.5, float(sy) + 2.0, z + 0.5)
	return pos + Vector3(5, 2, 0)
	
	
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
	_spawn_end_portal_frames()
	_spawn_victory_burst()
	_dragon_ref = null
	_dragon_dead = true

func _spawn_end_portal_frames() -> void:
	if world == null:
		return
	# Frames appear on the central podium after the dragon is defeated
	var cx := 8
	var cz := 8
	var y := 55
	for i in range(1, 4):
		world.set_block(cx - 2 + i, y, cz - 2, "end_portal_frame_filled")
		world.set_block(cx - 2 + i, y, cz + 2, "end_portal_frame_filled")
		world.set_block(cx - 2, y, cz - 2 + i, "end_portal_frame_filled")
		world.set_block(cx + 2, y, cz - 2 + i, "end_portal_frame_filled")
	for x in range(cx - 1, cx + 2):
		for z in range(cz - 1, cz + 2):
			world.set_block(x, y, z, "end_portal")
	if renderer != null:
		var pcx = floori(float(cx) / float(VoxelWorld.CHUNK_SIZE))
		var pcz = floori(float(cz) / float(VoxelWorld.CHUNK_SIZE))
		renderer.remesh_chunk_now(pcx, pcz)
		renderer.remesh_chunk_now(pcx - 1, pcz)
		renderer.remesh_chunk_now(pcx + 1, pcz)
		renderer.remesh_chunk_now(pcx, pcz - 1)
		renderer.remesh_chunk_now(pcx, pcz + 1)


func _spawn_victory_burst() -> void:
	var pos = Vector3(8, 58, 8)
	var light := OmniLight3D.new()
	light.light_color = Color(0.85, 0.55, 1.0)
	light.light_energy = 18.0
	light.omni_range = 40.0
	light.global_position = pos
	add_child(light)
	var parts := GPUParticles3D.new()
	parts.amount = 120
	parts.lifetime = 1.4
	parts.one_shot = true
	parts.emitting = true
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 8.0
	pm.color = Color(0.75, 0.4, 1.0, 0.8)
	parts.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.3)
	parts.draw_pass_1 = q
	parts.global_position = pos
	add_child(parts)
	get_tree().create_timer(2.5).timeout.connect(func():
		if is_instance_valid(light):
			light.queue_free()
		if is_instance_valid(parts):
			parts.queue_free()
	)


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
		renderer.remesh_chunk_now(floori(float(px) / float(VoxelWorld.CHUNK_SIZE)), floori(float(pz) / float(VoxelWorld.CHUNK_SIZE)))


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
		var mobile_r := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) == "mobile"
		if hs != null:
			# 0 = shadows off, 1 = low-res shadows, 2 = high-res shadows
			sun.shadow_enabled = hs.shadow_quality > 0
			sun.directional_shadow_max_distance = 48.0 if mobile_r else (80.0 if hs.shadow_quality <= 1 else 200.0)
		if mobile_r:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			if hs == null or hs.shadow_quality <= 1:
				sun.shadow_enabled = false
		add_child(sun)
		moon = DirectionalLight3D.new()
		moon.shadow_enabled = false
		moon.light_color = Color(0.9, 0.95, 1.0)
		add_child(moon)
		env = Environment.new()
		env.background_mode = Environment.BG_SKY
		sky_material = ShaderMaterial.new()
		sky_material.shader = Addons.get_sky_shader(OVERWORLD_SKY_SHADER) if has_node("/root/Addons") else OVERWORLD_SKY_SHADER
		sky_material.set_shader_parameter("time_of_day", time_of_day)
		sky_material.set_shader_parameter("rain_amount", 0.0)
		sky_material.set_shader_parameter("thunder_flash", 0.0)
		sky_resource = Sky.new()
		sky_resource.sky_material = sky_material
		# Keep Godot's automatic update mode used by the original working sky.
		# Shader parameter changes invalidate the sky without forcing a separate
		# realtime radiance path.
		sky_resource.process_mode = Sky.PROCESS_MODE_AUTOMATIC
		env.sky = sky_resource
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		if hs != null:
			# render_distance (in chunks) drives fade-out distance fog so far
			# terrain doesn't just hard-pop/disappear at the chunk load edge.
			var fog_dist = float(clampi(hs.render_distance, 2, 32)) * VoxelWorld.CHUNK_SIZE
			env.fog_enabled = true
			env.fog_light_color = Color(0.72, 0.82, 0.95)
			env.fog_density = 0.0008
			env.fog_depth_begin = fog_dist * 0.55
			env.fog_depth_end = fog_dist * 1.05
			# The sky is infinitely far away, so Godot's default sky fog influence
			# covers the complete shader with fog_light_color (a flat blue screen).
			# Keep distance fog on terrain, but never apply it to the sky shader.
			env.fog_sky_affect = 0.0
			# Glow is a full-screen pass; skip it on Forward Mobile / Adreno.
			var mobile_r2 := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) == "mobile"
			env.glow_enabled = not mobile_r2
			env.glow_intensity = 0.35
			env.glow_strength = 0.8
			env.ssao_enabled = false
			env.ssil_enabled = false
			env.ssr_enabled = false
			env.volumetric_fog_enabled = false
		var we = WorldEnvironment.new()
		we.environment = env
		add_child(we)
		_update_sky(current_dim)
		if has_node("/root/Addons"):
			Addons.notify_game_ready(self)
func _update_sky(dim: String) -> void:
	if env == null:
		return
	dim = Registry.normalize_dimension_id(dim)
	if dim == "overworld":
		sky_resource.sky_material = sky_material
		env.background_mode = Environment.BG_SKY
		env.background_color = Color(0.48, 0.68, 0.94)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.85
		env.fog_light_color = Color(0.72, 0.82, 0.95)
		if sun:
			sun.visible = true
		if moon:
			moon.visible = true
		_daynight = true
	elif dim == "hell":
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.16, 0.03, 0.03)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.55, 0.22, 0.16)
		env.ambient_light_energy = 0.6
		env.fog_light_color = Color(0.22, 0.045, 0.035)
		if sun:
			sun.visible = false
		if moon:
			moon.visible = false
		_daynight = false
	elif dim == "the_end":
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.04, 0.05, 0.10)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.42, 0.46, 0.62)
		env.ambient_light_energy = 0.55
		env.fog_light_color = Color(0.055, 0.045, 0.09)
		if sun:
			sun.visible = false
		if moon:
			moon.visible = false
		_daynight = false
	elif dim == "heaven":
		sky_resource.sky_material = sky_material
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.95
		env.fog_light_color = Color(0.82, 0.90, 1.0)
		if sun:
			sun.visible = true
			sun.light_energy = 1.3
			sun.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
		if moon:
			moon.visible = false
		_daynight = false
	env.set_meta("highcraft_dimension", dim)
	if dim == "overworld":
		_update_celestial_lights()
		if sky_material != null and sky_material.shader != null:
			sky_material.set_shader_parameter("time_of_day", time_of_day)
	if split_screen_mgr != null:
		split_screen_mgr.refresh_camera_environments(env)


func _update_celestial_lights() -> void:
	# Keep shader disk and real DirectionalLight3D on exactly the same orbit.
	# A DirectionalLight3D emits along local -Z, therefore its ray direction is
	# the inverse of the shader's direction towards the sun/moon.
	var angle := time_of_day * TAU - PI / 2.0
	var elevation := sin(angle)
	var daylight := smoothstep(-0.12, 0.18, elevation)
	var moonlight := 1.0 - smoothstep(-0.05, 0.22, elevation)
	if sun != null:
		sun.rotation = Vector3(-angle, 0.0, 0.0)
		sun.light_energy = daylight * 1.2
		sun.visible = daylight > 0.01
	if moon != null:
		moon.rotation = Vector3(PI - angle, 0.0, 0.0)
		moon.light_energy = moonlight * 0.22
		moon.visible = moonlight > 0.01
	if sky_material != null:
		sky_material.set_shader_parameter("time_of_day", time_of_day)
func is_night() -> bool:
	if not _daynight:
		return false
	return sin(time_of_day * TAU - PI / 2.0) < 0.0
func _process(delta: float) -> void:
	if _is_loading:
		return
	for stand in brewing_stands.values():
		stand.tick(delta)
	_tick_fluids(delta)
	_tick_end_crystals(delta)
	_update_boss_bar()
	_update_network_players(delta)
	_region_flush_t -= delta
	if _region_flush_t <= 0.0:
		_region_flush_t = 5.0
		if world != null and world.has_method("flush_next_region"):
			world.flush_next_region()
	# Weather ONLY in overworld — never rain/lightning in hell / end / heaven
	if current_dim != "overworld":
		is_raining = false
		is_thunderstorm = false
		for emitter in _rain_emitters:
			if emitter != null and is_instance_valid(emitter):
				emitter.emitting = false
		if lightning_light != null:
			lightning_light.light_energy = 0.0
	else:
		rain_timer -= delta
		if rain_timer <= 0.0:
			if is_raining:
				# Rain has a defined end instead of being randomly extended again.
				is_raining = false
				is_thunderstorm = false
				thunder_flash = 0.0
				rain_timer = randf_range(120.0, 300.0)
			else:
				is_raining = randf() < 0.28
				is_thunderstorm = is_raining and randf() < 0.30
				if is_raining:
					rain_timer = randf_range(45.0, 110.0)
					thunder_timer = randf_range(8.0, 18.0)
				else:
					rain_timer = randf_range(90.0, 240.0)
		rain_strength = move_toward(rain_strength, 1.0 if is_raining else 0.0, delta / 4.0)
		var target_rain := rain_strength
		if sky_material != null and sky_material is ShaderMaterial:
			if sky_material.shader != null:
				sky_material.set_shader_parameter("rain_amount", target_rain)
				sky_material.set_shader_parameter("thunder_flash", maxf(thunder_flash, 0.0))
				if split_screen_mgr != null:
					split_screen_mgr.set_sky_parameter("rain_amount", target_rain)
					split_screen_mgr.set_sky_parameter("thunder_flash", maxf(thunder_flash, 0.0))
		var active_players := _stream_players()
		for i in range(_rain_emitters.size()):
			var emitter = _rain_emitters[i]
			if emitter == null or not is_instance_valid(emitter):
				continue
			if emitter.emitting != is_raining:
				emitter.emitting = is_raining
			var desired_amount := (1800 if is_thunderstorm else 1200) if _rain_emitters.size() > 1 else (4000 if is_thunderstorm else 2800)
			if emitter.amount != desired_amount:
				emitter.amount = desired_amount
			if i < active_players.size():
				emitter.global_position = active_players[i].global_position + Vector3(0, 20, 0)
		if is_thunderstorm:
			thunder_timer -= delta
			if thunder_timer <= 0.0:
				thunder_timer = randf_range(8.0, 22.0)
				_do_lightning_strike()
			if thunder_flash > 0.0:
				thunder_flash -= delta
				if lightning_light != null:
					lightning_light.light_energy = maxf(0.0, thunder_flash * 8.0)
			elif lightning_light != null:
				lightning_light.light_energy = 0.0

	# Day/night only in overworld
	if _daynight and current_dim == "overworld":
		time_of_day = fmod(time_of_day + delta / day_length, 1.0)
		_update_celestial_lights()
		if split_screen_mgr != null:
			split_screen_mgr.set_sky_parameter("time_of_day", time_of_day)

	if player != null and renderer != null and not _is_loading:
		var load_radius = 6
		if has_node("/root/HCSettings"):
			load_radius = clampi(int(get_node("/root/HCSettings").chunk_load_radius), 2, 24)
		var stream_positions: Array = []
		for p in _stream_players():
			stream_positions.append(p.global_position)
		if stream_positions.is_empty():
			stream_positions.append(player.global_position)
		renderer.update_around_many(stream_positions, load_radius)

	if _portal_cd > 0.0:
		_portal_cd -= delta
	else:
		_portal_check_t -= delta
		if _portal_check_t <= 0.0:
			_portal_check_t = 0.1
			_check_portal()
			_handle_portal_walking()

	if _dragon_ref != null:
		if not is_instance_valid(_dragon_ref):
			_on_ender_dragon_died()
		elif "health" in _dragon_ref and float(_dragon_ref.health) <= 0.0:
			_on_ender_dragon_died()

	_update_redstone_world(delta)


func _check_portal() -> void:
	if player == null or world == null:
		return
	var px = floori(player.global_position.x)
	var py = floori(player.global_position.y)
	var pz = floori(player.global_position.z)
	var positions_to_check = [
		Vector3i(px, py, pz),
		Vector3i(px, py + 1, pz),
		Vector3i(px, py, pz + 1),
		Vector3i(px, py, pz - 1),
		Vector3i(px + 1, py, pz),
		Vector3i(px - 1, py, pz),
	]
	for pos in positions_to_check:
		var b = str(world.get_block(pos.x, pos.y, pos.z))
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
		# Push farther out so cooldown can expire without re-trigger
		var forward = -player.global_transform.basis.z.normalized() * 2.5
		if forward.length() < 0.1:
			forward = Vector3(2.5, 0, 0)
		player.global_position += forward
		player.velocity = Vector3.ZERO
			

func _update_redstone_world(_delta: float) -> void:
	if world == null or renderer == null or player == null:
		return
	# lightweight tick — full pulse is from lever/button interactions
	pass


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

	if stack.item_id == "firework_rocket":
		spawn_firework(spawn_pos, direction)
		return

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


func spawn_firework(spawn_position: Vector3, direction: Vector3 = Vector3.UP) -> FireworkRocket:
	var rocket := FireworkRocket.new()
	add_child(rocket)
	rocket.global_position = spawn_position
	rocket.setup(direction, 9.0)
	return rocket
		
		
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
	# Also discover hoppers placed in world near player (lazy register)
	if player != null:
		var pc = Vector3i(floori(player.global_position.x), floori(player.global_position.y), floori(player.global_position.z))
		for dx in range(-3, 4):
			for dy in range(-2, 3):
				for dz in range(-3, 4):
					var c = pc + Vector3i(dx, dy, dz)
					if world.get_block(c.x, c.y, c.z) == "hopper" and not hoppers.has(c):
						get_hopper(c)
	for cell in hoppers.keys():
		if world.get_block(cell.x, cell.y, cell.z) != "hopper":
			continue
		if is_hopper_locked(cell):
			continue
		var inv = get_hopper(cell)
		if inv == null:
			continue
		# 1) Pull from above
		_hopper_try_pull(cell, cell + Vector3i(0, 1, 0))
		# 2) Vacuum nearby item entities
		_hopper_try_pickup_entities(cell)
		# 3) Push into below container (or dropper/chest)
		if not inv.is_empty():
			_hopper_try_push(cell, cell + Vector3i(0, -1, 0))


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


func _do_lightning_strike() -> void:
	if current_dim != "overworld" or player == null:
		return
	var pos = player.global_position + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40))
	strike_lightning(pos)


func strike_lightning(pos: Vector3) -> void:

	# Visible bolt + damage + fire + sound (chunk-local impact)
	Audio.play("lightning_strike", -2.0)
	if lightning_light:
		lightning_light.global_position = pos + Vector3(0, 8, 0)
		lightning_light.light_energy = 16.0
		thunder_flash = 0.35
	# Temporary bolt mesh
	var bolt = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.35, 18.0, 0.35)
	bolt.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.9, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.85, 1.0)
	mat.emission_energy_multiplier = 4.0
	bolt.material_override = mat
	bolt.global_position = pos + Vector3(0, 9, 0)
	add_child(bolt)
	# Ignite ground
	if world and renderer:
		var cx = floori(pos.x)
		var cy = floori(pos.y)
		var cz = floori(pos.z)
		for y in range(cy, cy + 4):
			if world.get_block(cx, y, cz) == "air":
				renderer.edit_block(cx, y, cz, "fire")
				break
	# Damage nearby mobs/players + lightning transformations
	for m in get_tree().get_nodes_in_group("mobs"):
		if m.global_position.distance_to(pos) >= 4.0:
			continue
		var mid := ""
		if "mob_id" in m:
			mid = str(m.mob_id)
		if mid == "pig" and mob_manager != null:
			var p = m.global_position
			m.queue_free()
			mob_manager.spawn("zombie_pigman", p)
			continue
		if mid == "creeper":
			m.set_meta("charged", true)
			m.scale = Vector3(1.25, 1.25, 1.25)
			if m.has_method("set_charged"):
				m.set_charged(true)
			continue
		if m.has_method("take_hit"):
			m.take_hit(12.0)
	if player and player.global_position.distance_to(pos) < 4.0 and player.has_method("take_damage"):
		player.take_damage(6.0)
	# Remove bolt after flash
	get_tree().create_timer(0.4).timeout.connect(func():
		if is_instance_valid(bolt):
			bolt.queue_free()
	)


var _farm_tick: float = 0.0
func _tick_farming(delta: float) -> void:
	_farm_tick -= delta
	if _farm_tick > 0.0 or world == null or renderer == null:
		return
	_farm_tick = 1.0
	if player == null:
		return
	var pcx = int(floor(player.global_position.x / 16.0))
	var pcz = int(floor(player.global_position.z / 16.0))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var ch = world.get_chunk(pcx + dx, pcz + dz)
			if ch != null:
				Farming.tick_chunk(world, renderer, ch, is_raining)


func _hopper_try_pickup_entities(hopper_cell: Vector3i) -> void:
	var inv = get_hopper(hopper_cell)
	if inv == null:
		return
	var center = Vector3(float(hopper_cell.x) + 0.5, float(hopper_cell.y) + 1.0, float(hopper_cell.z) + 0.5)
	for node in get_tree().get_nodes_in_group("item_entities"):
		if not is_instance_valid(node):
			continue
		if node.global_position.distance_to(center) > 1.25:
			continue
		var iid = ""
		if "item_id" in node:
			iid = str(node.item_id)
		elif node.has_method("get_item_id"):
			iid = str(node.get_item_id())
		if iid.is_empty():
			continue
		var placed = false
		for j in range(inv.slots.size()):
			if inv.slots[j] == null:
				inv.slots[j] = ItemStack.new(iid, 1)
				placed = true
				break
			elif inv.slots[j].item_id == iid and inv.slots[j].count < 64:
				inv.slots[j].count += 1
				placed = true
				break
		if placed:
			node.queue_free()
			return


func _setup_multiplayer_hooks() -> void:
	if not has_node("/root/Multiplayer"):
		return
	var mp = get_node("/root/Multiplayer")
	mp.set_meta("game", self)
	if not mp.block_received.is_connected(_on_remote_block):
		mp.block_received.connect(_on_remote_block)
	if mp.has_signal("peer_ready_for_world") and not mp.peer_ready_for_world.is_connected(_on_peer_needs_world):
		mp.peer_ready_for_world.connect(_on_peer_needs_world)
	if mp.has_signal("player_state_received") and not mp.player_state_received.is_connected(_on_remote_player_state):
		mp.player_state_received.connect(_on_remote_player_state)
	if mp.has_signal("player_left") and not mp.player_left.is_connected(_on_remote_player_left):
		mp.player_left.connect(_on_remote_player_left)
	if mp.has_signal("player_skin_received") and not mp.player_skin_received.is_connected(_on_remote_player_skin):
		mp.player_skin_received.connect(_on_remote_player_skin)
	if player != null and mp.has_method("set_local_player_skin"):
		mp.set_local_player_skin(player.current_skin_name, AvatarLoader.load_skin(player.current_skin_name))
	if mp.has_method("get_peer_skins"):
		for peer_id in mp.get_peer_skins().keys():
			if multiplayer != null and int(peer_id) == multiplayer.get_unique_id():
				continue
			var skin_entry: Dictionary = mp.get_peer_skins()[peer_id]
			_on_remote_player_skin(int(peer_id), str(skin_entry.get("name", "afro_steve")), skin_entry.get("data", {}))
	if mp.has_method("take_pending_world_edits"):
		var pending_edits: Array = mp.take_pending_world_edits()
		if not pending_edits.is_empty():
			apply_remote_edits(pending_edits)
	if mp.has_method("take_pending_world_peers"):
		for pending_peer in mp.take_pending_world_peers():
			_on_peer_needs_world(int(pending_peer))


func _update_network_players(delta: float) -> void:
	if not has_node("/root/Multiplayer"):
		return
	var mp = get_node("/root/Multiplayer")
	if not mp.is_multiplayer:
		return
	_net_state_t -= delta
	if _net_state_t <= 0.0 and player != null:
		_net_state_t = 0.1
		mp.broadcast_player_state(player.global_position, player.rotation.y, player.head.rotation.x, player.current_held_item_id(), player.current_held_enchantments())
	for peer_id in _remote_players.keys():
		var proxy = _remote_players.get(peer_id)
		if proxy == null or not is_instance_valid(proxy):
			_remote_players.erase(peer_id)
			_remote_targets.erase(peer_id)
			continue
		var target: Dictionary = _remote_targets.get(peer_id, {})
		if target.is_empty():
			continue
		var old_pos: Vector3 = proxy.global_position
		var target_pos: Vector3 = target.get("position", old_pos)
		proxy.global_position = old_pos.lerp(target_pos, minf(1.0, delta * 12.0))
		proxy.rotation.y = lerp_angle(proxy.rotation.y, float(target.get("yaw", proxy.rotation.y)), minf(1.0, delta * 12.0))
		proxy.head.rotation.x = lerpf(proxy.head.rotation.x, float(target.get("pitch", proxy.head.rotation.x)), minf(1.0, delta * 12.0))
		proxy.velocity = (proxy.global_position - old_pos) / maxf(delta, 0.001)
		proxy._update_player_animation(delta)


func _on_remote_player_state(peer_id: int, position: Vector3, yaw: float, pitch: float, held_item_id: String = "", held_enchantments: Dictionary = {}) -> void:
	if multiplayer != null and peer_id == multiplayer.get_unique_id():
		return
	var proxy = _remote_players.get(peer_id, null)
	if proxy == null or not is_instance_valid(proxy):
		proxy = preload("res://scenes/player.tscn").instantiate()
		proxy.name = "RemotePlayer%d" % peer_id
		proxy.set_meta("remote_proxy", true)
		proxy.set_multiplayer_authority(peer_id)
		add_child(proxy)
		proxy.global_position = position
		_remote_players[peer_id] = proxy
		var pending: Dictionary = _remote_targets.get(peer_id, {})
		if pending.has("skin_name"):
			proxy.set_skin(str(pending["skin_name"]), pending.get("skin_data", {}))
			proxy.set_meta("network_skin_pending", false)
	var target: Dictionary = _remote_targets.get(peer_id, {})
	target["position"] = position
	target["yaw"] = yaw
	target["pitch"] = pitch
	_remote_targets[peer_id] = target
	proxy.set_remote_held_item(held_item_id, held_enchantments)


func _on_remote_player_left(peer_id: int) -> void:
	var proxy = _remote_players.get(peer_id, null)
	if proxy != null and is_instance_valid(proxy):
		proxy.queue_free()
	_remote_players.erase(peer_id)
	_remote_targets.erase(peer_id)


func _on_remote_player_skin(peer_id: int, skin_name: String, skin_data: Dictionary) -> void:
	var proxy = _remote_players.get(peer_id, null)
	if proxy == null or not is_instance_valid(proxy):
		# Preserve the skin until the first movement packet creates the proxy.
		_remote_targets[peer_id] = _remote_targets.get(peer_id, {})
		_remote_targets[peer_id]["skin_name"] = skin_name
		_remote_targets[peer_id]["skin_data"] = skin_data.duplicate(true)
		return
	proxy.set_skin(skin_name, skin_data)
	proxy.set_meta("network_skin_pending", false)


func notify_local_skin_changed(changed_player: Player) -> void:
	if changed_player == null:
		return
	if has_node("/root/HCSettings"):
		var slot := changed_player._joy_device()
		HCSettings.set_local_player_skin(slot, changed_player.current_skin_name)
	# Current online architecture has one network-owned local avatar. Split skins
	# stay local and independent; the primary avatar is the one peers receive.
	if changed_player == player and has_node("/root/Multiplayer"):
		var mp = get_node("/root/Multiplayer")
		if mp.has_method("set_local_player_skin"):
			mp.set_local_player_skin(changed_player.current_skin_name, AvatarLoader.load_skin(changed_player.current_skin_name))


func request_player_leave(leaving_player: Player) -> void:
	if leaving_player == null:
		return
	if split_screen_mgr != null and split_screen_mgr.players.size() > 1:
		var leaving_interactor = leaving_player.interactor
		if leaving_interactor != null and is_instance_valid(leaving_interactor):
			leaving_interactor.set_process(false)
			leaving_interactor.set_process_unhandled_input(false)
			leaving_interactor.queue_free()
		split_screen_mgr.remove_player(leaving_player)
		player = split_screen_mgr.players[0]
		ui = split_screen_mgr.uis[0] if not split_screen_mgr.uis.is_empty() else null
		interactor = player.interactor
		mob_manager.player = player
		event_manager.setup(player, mob_manager)
		_configure_rain_emitters()
		return
	# A client leaving does not affect the host or any other connected peer.
	if has_node("/root/Multiplayer") and Multiplayer.is_multiplayer:
		Multiplayer.disconnect_from_server()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_remote_block(x: int, y: int, z: int, id: String) -> void:
	if renderer != null:
		renderer.edit_block(x, y, z, id)
	elif world != null:
		world.set_block(x, y, z, id)


func _on_peer_needs_world(peer_id: int) -> void:
	if world == null or not has_node("/root/Multiplayer"):
		return
	var mp = get_node("/root/Multiplayer")
	if mp.has_method("send_edits_to_peer"):
		mp.send_edits_to_peer(peer_id, world.export_edits())


func apply_remote_edits(edits: Array) -> void:
	if world == null:
		return
	world.import_edits(edits)
	if renderer != null:
		var rebuild_chunks: Dictionary = {}
		for e in edits:
			if not (e is Array) or e.size() < 3:
				continue
			var cx = floori(float(e[0]) / VoxelWorld.CHUNK_SIZE)
			var cz = floori(float(e[2]) / VoxelWorld.CHUNK_SIZE)
			var key := Vector2i(cx, cz)
			if renderer.loaded.has(key):
				rebuild_chunks[key] = true
		for key in rebuild_chunks.keys():
			if renderer.has_method("rebuild"):
				renderer.rebuild(key.x, key.y)


func broadcast_block_edit(x: int, y: int, z: int, id: String) -> void:
	if has_node("/root/Multiplayer"):
		var mp = get_node("/root/Multiplayer")
		if mp.has_method("broadcast_block"):
			mp.broadcast_block(x, y, z, id)


func _tick_fluids(delta: float) -> void:
	_fluid_tick -= delta
	if _fluid_tick > 0.0 or world == null or renderer == null or player == null:
		return
	_fluid_tick = 0.35
	var pc := Vector3i(floori(player.global_position.x), floori(player.global_position.y), floori(player.global_position.z))
	for dx in range(-4, 5):
		for dy in range(-3, 2):
			for dz in range(-4, 5):
				var c = pc + Vector3i(dx, dy, dz)
				var id = str(world.get_block(c.x, c.y, c.z))
				if id != "water" and id != "lava":
					continue
				var below = str(world.get_block(c.x, c.y - 1, c.z))
				if below == "air":
					renderer.edit_block(c.x, c.y - 1, c.z, id)
					continue
				for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
					var n = c + d
					if str(world.get_block(n.x, n.y, n.z)) == "air":
						var under = str(world.get_block(n.x, n.y - 1, n.z))
						if under != "air" or id == "lava":
							renderer.edit_block(n.x, n.y, n.z, id)
							break


func _tick_end_crystals(delta: float) -> void:
	if current_dim != "the_end" or world == null:
		return
	_crystal_tick -= delta
	if _crystal_tick > 0.0:
		return
	_crystal_tick = 0.4
	var crystals: Array = []
	if player != null:
		var pc := Vector3i(floori(player.global_position.x), floori(player.global_position.y), floori(player.global_position.z))
		for dx in range(-16, 17):
			for dz in range(-16, 17):
				for dy in range(-4, 12):
					var c = pc + Vector3i(dx, dy, dz)
					if str(world.get_block(c.x, c.y, c.z)) == "end_crystal":
						crystals.append(c)
	# Heal dragon if any crystal exists
	if _dragon_ref != null and is_instance_valid(_dragon_ref) and crystals.size() > 0:
		if "health" in _dragon_ref and "max_health" in _dragon_ref:
			_dragon_ref.health = minf(float(_dragon_ref.max_health), float(_dragon_ref.health) + 2.0)
	# 4 crystals around the central podium revive the dragon
	var podium := [Vector3i(8, 56, 5), Vector3i(8, 56, 11), Vector3i(5, 56, 8), Vector3i(11, 56, 8)]
	var around := 0
	for p in podium:
		if str(world.get_block(p.x, p.y, p.z)) == "end_crystal":
			around += 1
	if around >= 4 and (_dragon_ref == null or not is_instance_valid(_dragon_ref)):
		_spawn_ender_dragon()


func _update_boss_bar() -> void:
	if ui == null:
		return
	var show := current_dim == "the_end" and _dragon_ref != null and is_instance_valid(_dragon_ref)
	if ui.has_method("set_boss_bar"):
		if show:
			var hp = float(_dragon_ref.health)
			var mx = float(_dragon_ref.max_health) if "max_health" in _dragon_ref else 200.0
			ui.set_boss_bar("Ender Dragon", hp / maxf(1.0, mx))
		else:
			ui.set_boss_bar("", 0.0)


func locate_structure(kind: String) -> Vector3:
	kind = kind.to_lower()
	if kind in ["stronghold", "fortress", "village", "mineshaft"]:
		# Deterministic search from spawn using the same RNG family as generation
		var best := Vector3(float(SPAWN_X), 40, float(SPAWN_Z))
		if kind == "stronghold":
			if _stronghold_cache != Vector3.INF:
				return _stronghold_cache
			best = Vector3(float(SPAWN_X + 96), 18, float(SPAWN_Z + 64))
			_stronghold_cache = best
		elif kind == "village":
			best = Vector3(float(SPAWN_X + 48), 70, float(SPAWN_Z + 16))
		elif kind == "mineshaft":
			best = Vector3(float(SPAWN_X - 40), 18, float(SPAWN_Z + 32))
		elif kind == "fortress":
			best = Vector3(float(SPAWN_X + 32), 64, float(SPAWN_Z - 32))
		return best
	return player.global_position if player else Vector3.ZERO


func guide_eye_of_ender(from: Vector3) -> void:
	var target = locate_structure("stronghold")
	if ui != null and "_chat_msg" in ui and ui._chat_msg != null:
		ui._chat_msg.text = "The Eye of Ender flies toward %d, %d" % [int(target.x), int(target.z)]
	if player != null:
		var dir = (Vector3(target.x, player.global_position.y, target.z) - player.global_position).normalized()
		# Nudge a visible marker ahead of the player
		var marker := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.15
		sph.height = 0.3
		marker.mesh = sph
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.9, 0.4)
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.9, 0.4)
		marker.material_override = mat
		add_child(marker)
		marker.global_position = from + dir * 2.0 + Vector3(0, 1.5, 0)
		var tw = create_tween()
		tw.tween_property(marker, "global_position", from + dir * 10.0 + Vector3(0, 6, 0), 1.6)
		tw.tween_callback(func():
			if is_instance_valid(marker):
				marker.queue_free()
		)
