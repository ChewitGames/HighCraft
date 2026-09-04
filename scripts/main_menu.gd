extends Control
# HighCraft main menu: logo, rotating world preview, Singleplayer / Load /
# Host (room code) / Join / Split-Screen / Settings.

const GAME_SCENE := "res://scenes/game.tscn"
const MAIN_MENU_LOGO := preload("res://assets/Logo/HighCraft Logo.png")
const MAIN_MENU_SIZE := Vector2(440.0, 716.0)


var _input_device: String = "mouse"   # "mouse" oder "controller"
var _controller_nav_cooldown: float = 0.0
const CONTROLLER_NAV_DELAY := 0.18

var _status: Label
var _room_label: Label
var _name_edit: LineEdit
var _code_edit: LineEdit
var _split_opt: OptionButton
var _preview_root: Node3D
var _preview_cam: Camera3D
var _preview_angle: float = 0.0
var _preview_focus_y: float = 70.0
var _preview_time_of_day: float = 0.30
var _preview_sky_material: ShaderMaterial
var _preview_sun: DirectionalLight3D
var _preview_moon: DirectionalLight3D
var _first_btn: Button
var _intro_layer: CanvasLayer = null
var _intro_tween: Tween = null
var _intro_active: bool = false

# Settings as in-scene Panel (NOT Window) so controller focus stays in same viewport
var _settings_panel: Panel = null
var _addons_panel: Panel = null
var _addons_scroll: ScrollContainer = null
var _addons_controls: Array[Control] = []
var _addons_focus_idx := 0
var _settings_scroll: ScrollContainer = null
var _settings_controls: Array = []   # HSlider / CheckButton / Button in order
var _settings_focus_idx: int = 0
# Host ready dialog (same pattern — no Window)
var _host_panel: Panel = null
var _host_controls: Array = []
var _host_focus_idx: int = 0
var _osk: OnScreenKeyboard = null
# OptionButton submenu (split-screen player count)
var _opt_panel: Panel = null
var _opt_buttons: Array = []
var _opt_focus: int = 0
var _opt_target: OptionButton = null
var _new_world_action: String = "singleplayer"
var _new_world_split_players: int = 1
var _skin_panel: Panel = null
var _skin_buttons: Array[Button] = []
var _skin_focus_idx := 0
var _skin_scroll: ScrollContainer = null
var _avatar_layer: CanvasLayer = null
var _scene_transition_active: bool = false


func _mark_handled() -> void:
	# Scene can already be unloading (game start) → viewport is null
	if not is_inside_tree():
		return
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _open_text_osk(edit: LineEdit) -> void:
	if edit == null or not is_instance_valid(edit):
		return
	if _osk != null and is_instance_valid(_osk):
		_osk.close(false)
		_osk = null
	_osk = OnScreenKeyboard.new()
	add_child(_osk)
	_osk.done.connect(func(_txt):
		_osk = null
	)
	_osk.cancelled.connect(func():
		_osk = null
	)
	_osk.open(edit)


func _focus_owner() -> Control:

	if not is_inside_tree():
		return null
	var vp := get_viewport()
	if vp == null:
		return null
	return vp.gui_get_focus_owner()


func _ready() -> void:
	# Gameplay captures the process-global mouse. Scene changes do not reset that
	# state automatically, so every path back to the menu must release it here.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if has_node("/root/Music"):
		get_node("/root/Music").play_for_dimension("menu")
	# Paint the intro immediately.  Building the rotating voxel preview used to
	# happen first, leaving a black/frozen-looking window during startup.
	_build_intro()
	_build_ui()
	_build_preview()


func _process(delta: float) -> void:
	if _controller_nav_cooldown > 0.0:
		_controller_nav_cooldown = maxf(0.0, _controller_nav_cooldown - delta)
	if _preview_cam == null or not _preview_cam.is_inside_tree():
		return
	_preview_angle += delta * 0.15
	var r = 24.0  # stays well inside the ~48-block generated preview radius
	var cam_pos = Vector3(cos(_preview_angle) * r, _preview_focus_y + 34.0, sin(_preview_angle) * r)
	_preview_cam.look_at_from_position(cam_pos, Vector3(0, _preview_focus_y, 0), Vector3.UP)
	# Slow real day/night preview using the same sky and light direction as game.
	_preview_time_of_day = fmod(_preview_time_of_day + delta / 360.0, 1.0)
	var sun_angle := _preview_time_of_day * TAU - PI / 2.0
	var elevation := sin(sun_angle)
	var daylight := smoothstep(-0.12, 0.18, elevation)
	var moonlight := 1.0 - smoothstep(-0.05, 0.22, elevation)
	if _preview_sky_material != null:
		_preview_sky_material.set_shader_parameter("time_of_day", _preview_time_of_day)
	if _preview_sun != null:
		_preview_sun.rotation = Vector3(-sun_angle, 0.0, 0.0)
		_preview_sun.light_energy = daylight * 1.2
		_preview_sun.visible = daylight > 0.01
	if _preview_moon != null:
		_preview_moon.rotation = Vector3(PI - sun_angle, 0.0, 0.0)
		_preview_moon.light_energy = moonlight * 0.22
		_preview_moon.visible = moonlight > 0.01


func _build_preview() -> void:
	# Lightweight visual only — no mobs, no day/night cycle
	var vp := SubViewport.new()
	vp.size = Vector2i(960, 540)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var world := Node3D.new()
	vp.add_child(world)
	_preview_root = world
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	_preview_sky_material = ShaderMaterial.new()
	_preview_sky_material.shader = load("res://shaders/sky.gdshader")
	_preview_sky_material.set_shader_parameter("time_of_day", _preview_time_of_day)
	var preview_sky := Sky.new()
	preview_sky.sky_material = _preview_sky_material
	preview_sky.process_mode = Sky.PROCESS_MODE_AUTOMATIC
	e.sky = preview_sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.85
	env.environment = e
	world.add_child(env)
	_preview_sun = DirectionalLight3D.new()
	# Adreno's Mobile renderer corrupts directional shadow maps in SubViewports,
	# producing a large black region beneath/behind the moving preview camera.
	_preview_sun.shadow_enabled = false
	world.add_child(_preview_sun)
	_preview_moon = DirectionalLight3D.new()
	_preview_moon.shadow_enabled = false
	_preview_moon.light_color = Color(0.9, 0.95, 1.0)
	world.add_child(_preview_moon)

	# Let the intro/menu paint before generating preview chunks.  The preview is
	# decorative, so it can safely appear a few chunks at a time behind the intro.
	call_deferred("_spawn_real_terrain_async", world)

	_preview_cam = Camera3D.new()
	world.add_child(_preview_cam)
	_preview_cam.current = true
	var cont := SubViewportContainer.new()
	cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	cont.stretch = true
	vp.gui_disable_input = true

	cont.z_index = -10
	add_child(cont)
	move_child(cont, 0)
	cont.add_child(vp)


func _spawn_real_terrain_async(world: Node3D) -> void:
	await get_tree().process_frame
	if world == null or not is_instance_valid(world):
		return
	# Fully isolated deterministic preview. Never inherit Config, a saved world,
	# DimensionManager state, structures, or another dimension's region cache.
	const PREVIEW_SEED := 927451
	var generator := TerrainGenerator.new(PREVIEW_SEED, "normal", "overworld")
	generator.structures_enabled = false
	var pworld := VoxelWorld.new(generator)
	if pworld.regions != null:
		pworld.regions.setup(PREVIEW_SEED, "main_menu_preview", false)
	var prenderer := ChunkRenderer.new()
	world.add_child(prenderer)
	prenderer.setup(pworld)
	var sy = pworld.surface_height(0, 0)
	# Build the complete camera area synchronously. The former threaded startup
	# displayed two isolated chunks first, making normal hills/water look like
	# floating Heaven islands while the remaining Overworld chunks trickled in.
	prenderer._use_threads = false
	prenderer.max_builds_per_call = 9999
	var built := 0
	for cx in range(-3, 4):
		for cz in range(-3, 4):
			prenderer.build_chunk(cx, cz)
			built += 1
			if built % 3 == 0:
				await get_tree().process_frame
	_preview_focus_y = float(sy)


func _dimension_display_name(raw_id: String) -> String:
	var dim_id := str(raw_id)
	if has_node("/root/Registry"):
		dim_id = Registry.normalize_dimension_id(dim_id)
		var profile = Registry.get_dimension(dim_id)
		if profile is Dictionary and not profile.is_empty():
			return str(profile.get("name", dim_id.capitalize()))
	return "The Hell" if dim_id in ["hell", "nether", "the_hell"] else dim_id.replace("_", " ").capitalize()


func _change_to_game(message: String = "Loading world...") -> void:
	if _scene_transition_active:
		return
	_scene_transition_active = true
	set_process_input(false)
	set_process_unhandled_input(false)
	var layer := CanvasLayer.new()
	layer.name = "SceneTransition"
	layer.layer = 1000
	add_child(layer)
	var background := ColorRect.new()
	background.color = Color(0.025, 0.03, 0.055, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(background)
	var title := Label.new()
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	title.text = message
	background.add_child(title)
	# Two frames guarantee that the transition is submitted before scene loading.
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(GAME_SCENE)


func _build_ui() -> void:
	var panel := Panel.new()
	panel.name = "CenteredMenuPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -MAIN_MENU_SIZE.x * 0.5
	panel.offset_top = -MAIN_MENU_SIZE.y * 0.5
	panel.offset_right = MAIN_MENU_SIZE.x * 0.5
	panel.offset_bottom = MAIN_MENU_SIZE.y * 0.5
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 12
	vb.offset_top = 8
	vb.offset_right = -12
	vb.offset_bottom = -8
	vb.add_theme_constant_override("separation", 0)
	panel.add_child(vb)

	var logo := TextureRect.new()
	logo.name = "HighCraftLogo"
	logo.texture = MAIN_MENU_LOGO
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 230)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(logo)

	_add_btn(vb, "New World", _on_new_world)
	_add_btn(vb, "Load World…", _on_load_world)
	_add_btn(vb, "Host Server (Room Code)", _on_host)
	_add_btn(vb, "Join with Room Code", _on_join)
	_add_btn(vb, "Local Split-Screen", _on_split)
	_add_btn(vb, "Select Skin", _open_skin_selector)
	_add_btn(vb, "Create Skin", _open_avatar_editor)
	_add_btn(vb, "Mods & Packs", _on_addons)
	_add_btn(vb, "Settings", _on_settings)
	_add_btn(vb, "Quit", func(): get_tree().quit())
	if _first_btn:
		_first_btn.grab_focus()

	var nl := Label.new()
	nl.text = "Server name (shown with room code):"
	vb.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.text = "HighCraft Server"
	if has_node("/root/HCSettings"):
		_name_edit.text = get_node("/root/HCSettings").server_display_name
	_name_edit.focus_mode = Control.FOCUS_ALL
	vb.add_child(_name_edit)

	var cl := Label.new()
	cl.text = "Room code / join:"
	vb.add_child(cl)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "ABCD-EFGH"
	_code_edit.focus_mode = Control.FOCUS_ALL
	vb.add_child(_code_edit)

	var sl := Label.new()
	sl.text = "Split-screen players (2–4, pads/extra keys):"
	vb.add_child(sl)
	_split_opt = OptionButton.new()
	for n in [2, 3, 4]:
		_split_opt.add_item("%d players" % n, n)
	_split_opt.selected = 0
	_split_opt.focus_mode = Control.FOCUS_ALL
	vb.add_child(_split_opt)

	_room_label = Label.new()
	_room_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_room_label)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_status)


func _build_intro() -> void:
	_intro_active = true
	_intro_layer = CanvasLayer.new()
	_intro_layer.name = "MainMenuIntro"
	_intro_layer.layer = 500
	add_child(_intro_layer)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro_layer.add_child(background)

	var credits := VBoxContainer.new()
	credits.set_anchors_preset(Control.PRESET_CENTER)
	credits.offset_left = -360.0
	credits.offset_top = -90.0
	credits.offset_right = 360.0
	credits.offset_bottom = 90.0
	credits.alignment = BoxContainer.ALIGNMENT_CENTER
	credits.add_theme_constant_override("separation", 10)
	background.add_child(credits)

	var studio_credit := Label.new()
	studio_credit.text = "By Chewit!Games TM and Adrian Ruf"
	studio_credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	studio_credit.add_theme_font_size_override("font_size", 34)
	studio_credit.modulate.a = 0.0
	credits.add_child(studio_credit)

	var music_credit := Label.new()
	music_credit.text = "Music by X120 - HighCraft"
	music_credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	music_credit.add_theme_font_size_override("font_size", 25)
	music_credit.modulate.a = 0.0
	credits.add_child(music_credit)

	_intro_tween = create_tween()
	_intro_tween.tween_property(studio_credit, "modulate:a", 1.0, 0.8)
	_intro_tween.tween_interval(1.2)
	_intro_tween.tween_property(studio_credit, "modulate:a", 0.0, 0.6)
	_intro_tween.tween_property(music_credit, "modulate:a", 1.0, 0.8)
	_intro_tween.tween_interval(1.2)
	_intro_tween.tween_property(music_credit, "modulate:a", 0.0, 0.6)
	_intro_tween.tween_property(background, "modulate:a", 0.0, 0.8)
	_intro_tween.tween_callback(_finish_intro)


func _finish_intro() -> void:
	if not _intro_active:
		return
	_intro_active = false
	_intro_tween = null
	if _intro_layer != null and is_instance_valid(_intro_layer):
		_intro_layer.queue_free()
	_intro_layer = null
	if _first_btn != null and is_instance_valid(_first_btn):
		_first_btn.grab_focus()


func _skip_intro() -> void:
	if not _intro_active:
		return
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_finish_intro()


func _add_btn(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(cb)
	b.add_to_group("menu_buttons")
	parent.add_child(b)
	if _first_btn == null:
		_first_btn = b



func _on_new_world() -> void:
	_show_new_world_dialog("singleplayer")


func _show_new_world_dialog(action: String, split_players: int = 1) -> void:
	_new_world_action = action
	_new_world_split_players = split_players
	_close_host_dialog()
	_host_panel = Panel.new()
	_host_panel.name = "NewWorldPanel"
	_host_panel.z_index = 100
	_host_panel.set_anchors_preset(Control.PRESET_CENTER)
	_host_panel.custom_minimum_size = Vector2(480, 580)
	_host_panel.size = Vector2(480, 580)
	_host_panel.position = -_host_panel.size / 2.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.12, 0.98)
	bg.border_color = Color(0.7, 0.65, 0.3)
	bg.set_border_width_all(3)
	_host_panel.add_theme_stylebox_override("panel", bg)
	add_child(_host_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 20
	vb.offset_top = 18
	vb.offset_right = -20
	vb.offset_bottom = -18
	vb.add_theme_constant_override("separation", 10)
	_host_panel.add_child(vb)

	var title := Label.new()
	title.text = "Create New World"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)

	_host_controls.clear()
	_host_focus_idx = 0
	var seed_label := Label.new()
	seed_label.text = "Seed (leave empty for random)"
	vb.add_child(seed_label)
	var seed_edit := LineEdit.new()
	seed_edit.placeholder_text = "Random seed"
	seed_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	seed_edit.focus_mode = Control.FOCUS_ALL
	vb.add_child(seed_edit)
	_host_controls.append(seed_edit)
	var mode := _new_world_option(vb, "Default game mode", ["Creative", "Survival", "Adventure", "Hardcore"], 1)
	var difficulty := _new_world_option(vb, "Difficulty", ["Peaceful", "Easy", "Normal", "Hard"], 2)
	var world_type := _new_world_option(vb, "World type", ["Normal", "Flat"], 0)
	var pvp := CheckButton.new()
	pvp.text = "Player versus Player (PvP)"
	pvp.button_pressed = true
	pvp.focus_mode = Control.FOCUS_ALL
	vb.add_child(pvp)
	_host_controls.append(pvp)

	var hint := Label.new()
	hint.text = "Controller: D-Pad navigate  |  A select  |  B cancel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(hint)

	var create_btn := Button.new()
	create_btn.text = "Create World"
	create_btn.pressed.connect(func():
		_start_new_world(seed_edit.text, mode.selected, difficulty.selected, world_type.selected, pvp.button_pressed)
	)
	vb.add_child(create_btn)
	_host_controls.append(create_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_close_host_dialog)
	vb.add_child(cancel_btn)
	_host_controls.append(cancel_btn)
	_host_focus_apply()


func _new_world_option(parent: Control, label_text: String, choices: Array, selected: int) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var option := OptionButton.new()
	for choice in choices:
		option.add_item(str(choice))
	option.selected = selected
	option.focus_mode = Control.FOCUS_ALL
	option.set_meta("option_title", label_text)
	parent.add_child(option)
	_host_controls.append(option)
	return option


func _start_new_world(seed_text: String, mode: int, difficulty: int, world_type: int, pvp: bool) -> void:
	if has_node("/root/HCSettings"):
		var hs = get_node("/root/HCSettings")
		hs.splitscreen_players = _new_world_split_players if _new_world_action == "split" else 1
		hs.save_settings()
	if has_node("/root/Config"):
		Config.game_mode = mode
		Config.difficulty = difficulty
		Config.world_type = "flat" if world_type == 1 else "normal"
		Config.pvp_enabled = pvp
		# Fresh seed + world_id — NEVER reuse previous world builds/regions
		var clean_seed := seed_text.strip_edges()
		var selected_seed = null
		if clean_seed != "":
			selected_seed = int(clean_seed) if clean_seed.is_valid_int() else clean_seed.hash()
		Config.begin_new_world(selected_seed)
	if has_node("/root/Multiplayer"):
		Multiplayer.pvp_enabled = pvp
	_close_host_dialog()
	match _new_world_action:
		"host":
			_start_host_after_world_options()
		"split":
			if has_node("/root/Config"):
				Config.set_meta("splitscreen", _new_world_split_players)
			_status.text = "Starting %d-player local split-screen (controllers / extra keys)" % _new_world_split_players
			_change_to_game("Creating world...\nPreparing local split-screen")
		_:
			_change_to_game("Creating world...\nGenerating terrain")
	
	
func _settings_open() -> bool:
	return _settings_panel != null and is_instance_valid(_settings_panel) and _settings_panel.visible


func _close_settings() -> void:
	if _settings_panel != null and is_instance_valid(_settings_panel):
		_settings_panel.queue_free()
	_settings_panel = null
	_settings_scroll = null
	_settings_controls.clear()
	_settings_focus_idx = 0
	if is_inside_tree() and _first_btn != null and is_instance_valid(_first_btn):
		_first_btn.grab_focus()


func _settings_focus_apply() -> void:
	if _settings_controls.is_empty():
		return
	_settings_focus_idx = clampi(_settings_focus_idx, 0, _settings_controls.size() - 1)
	for i in range(_settings_controls.size()):
		var c: Control = _settings_controls[i]
		if not is_instance_valid(c):
			continue
		if i == _settings_focus_idx:
			c.modulate = Color(1.4, 1.35, 0.6)
			c.grab_focus()
			# Auto-scroll so the focused row is always on screen
			if _settings_scroll != null and is_instance_valid(_settings_scroll):
				_settings_scroll.ensure_control_visible(c)
		else:
			c.modulate = Color(1, 1, 1)


func _settings_move(delta: int) -> void:
	if _settings_controls.is_empty():
		return
	_settings_focus_idx = posmod(_settings_focus_idx + delta, _settings_controls.size())
	_settings_focus_apply()


func _settings_adjust_slider(dir: float) -> void:
	if _settings_controls.is_empty():
		return
	var c = _settings_controls[_settings_focus_idx]
	if c is HSlider:
		var s: HSlider = c
		var step = s.step if s.step > 0.0 else 1.0
		s.value = clampf(s.value + dir * step, s.min_value, s.max_value)


func _settings_activate() -> void:
	if _settings_controls.is_empty():
		return
	var c = _settings_controls[_settings_focus_idx]
	if c is CheckButton:
		var cb: CheckButton = c
		cb.button_pressed = not cb.button_pressed
		cb.toggled.emit(cb.button_pressed)
	elif c is Button:
		(c as Button).pressed.emit()
	elif c is HSlider:
		# A on slider = no-op; use left/right
		pass


func _input(event: InputEvent) -> void:
	if _intro_active:
		var skip_requested := (
			(event is InputEventKey and (event as InputEventKey).pressed)
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
			or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed)
		)
		if skip_requested:
			_skip_intro()
			_mark_handled()
		return

	# AvatarEditor owns all controller/keyboard input while it is visible.
	if _avatar_layer != null and is_instance_valid(_avatar_layer):
		return
	if _skin_selector_open() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_skin_selector()
		_mark_handled()
		return

	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		_input_device = "mouse"
	elif event is InputEventJoypadButton:
		_input_device = "controller"
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.35:
		_input_device = "controller"

	if _input_device != "controller":
		return

	# OSK owns input while open
	if _osk != null and is_instance_valid(_osk) and _osk.is_open():
		_mark_handled()
		return

	if _skin_selector_open():
		_handle_skin_selector_input(event)
		return

	# Option submenu (split-screen players etc.)
	if _option_menu_open():
		if event is InputEventJoypadMotion and _controller_nav_cooldown <= 0.0:
			if event.axis == 1 and absf(event.axis_value) > 0.5:
				_opt_move(1 if event.axis_value > 0.0 else -1)
				_controller_nav_cooldown = CONTROLLER_NAV_DELAY
				_mark_handled()
			return
		if event is InputEventJoypadButton and event.pressed:
			var obtn: int = event.button_index
			if obtn == HCPad.BTN_DPAD_UP or obtn == 11:
				_opt_move(-1)
				_mark_handled()
				return
			if obtn == HCPad.BTN_DPAD_DOWN or obtn == 12:
				_opt_move(1)
				_mark_handled()
				return
			if obtn == HCPad.BTN_ACCEPT or obtn == 0:
				_pick_option(_opt_focus)
				_mark_handled()
				return
			if obtn == HCPad.BTN_CANCEL or obtn == 1:
				_close_option_menu()
				_mark_handled()
				return
		return

	if _controller_nav_cooldown > 0.0:
		_controller_nav_cooldown -= get_process_delta_time()

	# ===== MODS & PACKS =====
	if _addons_open():
		if event is InputEventJoypadMotion and _controller_nav_cooldown <= 0.0:
			if event.axis == 1 and absf(event.axis_value) > 0.5:
				_addons_move(1 if event.axis_value > 0.0 else -1)
				_controller_nav_cooldown = CONTROLLER_NAV_DELAY
				_mark_handled()
			return
		if event is InputEventJoypadButton and event.pressed:
			var addon_btn: int = event.button_index
			if addon_btn == HCPad.BTN_DPAD_UP or addon_btn == 11:
				_addons_move(-1)
				_mark_handled()
				return
			if addon_btn == HCPad.BTN_DPAD_DOWN or addon_btn == 12:
				_addons_move(1)
				_mark_handled()
				return
			if addon_btn == HCPad.BTN_ACCEPT or addon_btn == 0:
				_addons_activate()
				_mark_handled()
				return
			if addon_btn == HCPad.BTN_CANCEL or addon_btn == 1:
				_close_addons()
				_mark_handled()
				return
		return

	# ===== HOST DIALOG =====
	if _host_open():
		if event is InputEventJoypadMotion and _controller_nav_cooldown <= 0.0:
			var hax: int = event.axis
			var hval: float = event.axis_value
			if absf(hval) > 0.5 and hax == 1:
				_host_move(1 if hval > 0.0 else -1)
				_controller_nav_cooldown = CONTROLLER_NAV_DELAY
				_mark_handled()
			return
		if event is InputEventJoypadButton and event.pressed:
			var hbtn: int = event.button_index
			if hbtn == HCPad.BTN_DPAD_UP or hbtn == 11:
				_host_move(-1)
				_mark_handled()
				return
			if hbtn == HCPad.BTN_DPAD_DOWN or hbtn == 12:
				_host_move(1)
				_mark_handled()
				return
			if hbtn == HCPad.BTN_ACCEPT or hbtn == 0:
				_host_activate()
				_mark_handled()
				return
			if hbtn == HCPad.BTN_CANCEL or hbtn == 1:
				_close_host_dialog()
				_mark_handled()
				return
		return

	# ===== SETTINGS PANEL: own focus list, never relies on Window viewport =====
	if _settings_open():
		if event is InputEventJoypadMotion and _controller_nav_cooldown <= 0.0:
			var ax: int = event.axis
			var val: float = event.axis_value
			if absf(val) > 0.5:
				if ax == 1:  # Y stick
					_settings_move(1 if val > 0.0 else -1)
					_controller_nav_cooldown = CONTROLLER_NAV_DELAY
					_mark_handled()
				elif ax == 0:  # X stick → slider
					_settings_adjust_slider(1.0 if val > 0.0 else -1.0)
					_controller_nav_cooldown = CONTROLLER_NAV_DELAY * 0.4
					_mark_handled()
			return
		if event is InputEventJoypadButton and event.pressed:
			var btn: int = event.button_index
			if btn == HCPad.BTN_DPAD_UP or btn == 11:
				_settings_move(-1)
				_mark_handled()
				return
			if btn == HCPad.BTN_DPAD_DOWN or btn == 12:
				_settings_move(1)
				_mark_handled()
				return
			if btn == HCPad.BTN_DPAD_LEFT or btn == 13:
				_settings_adjust_slider(-1.0)
				_mark_handled()
				return
			if btn == HCPad.BTN_DPAD_RIGHT or btn == 14:
				_settings_adjust_slider(1.0)
				_mark_handled()
				return
			if btn == HCPad.BTN_ACCEPT or btn == 0:
				_settings_activate()
				_mark_handled()
				return
			if btn == HCPad.BTN_CANCEL or btn == 1:
				_close_settings()
				_mark_handled()
				return
		return

	# ===== MAIN MENU =====
	if event is InputEventJoypadMotion:
		if _controller_nav_cooldown <= 0.0:
			var ax2: int = event.axis
			var val2: float = event.axis_value
			if absf(val2) > 0.5 and ax2 == 1:
				if val2 > 0.0:
					_focus_next()
				else:
					_focus_prev()
				_controller_nav_cooldown = CONTROLLER_NAV_DELAY
				_mark_handled()
		return

	if not (event is InputEventJoypadButton and event.pressed):
		return

	var btn2: int = event.button_index
	if btn2 == HCPad.BTN_DPAD_UP or btn2 == 11:
		_focus_prev()
		_mark_handled()
		return
	if btn2 == HCPad.BTN_DPAD_DOWN or btn2 == 12:
		_focus_next()
		_mark_handled()
		return
	if btn2 == HCPad.BTN_ACCEPT or btn2 == 0:
		var focus := _focus_owner()
		if focus is LineEdit:
			_open_text_osk(focus as LineEdit)
		elif focus is OptionButton:
			_open_option_menu(focus as OptionButton)
		elif focus is Button:
			(focus as Button).pressed.emit()
		_mark_handled()
		return
	if btn2 == JOY_BUTTON_Y or btn2 == 3 or btn2 == HCPad.BTN_PAUSE or btn2 == 6:
		_on_settings()
		_mark_handled()
		return


func _option_menu_open() -> bool:
	return _opt_panel != null and is_instance_valid(_opt_panel)


func _open_option_menu(ob: OptionButton) -> void:
	if ob == null or not is_instance_valid(ob):
		return
	_close_option_menu()
	_opt_target = ob
	_opt_focus = clampi(ob.selected, 0, maxi(ob.item_count - 1, 0))
	_opt_buttons.clear()

	var layer := CanvasLayer.new()
	layer.layer = 250
	layer.name = "OptionSubmenuLayer"
	add_child(layer)

	_opt_panel = Panel.new()
	_opt_panel.name = "OptionSubmenu"
	var h := float(56 + ob.item_count * 48)
	_opt_panel.size = Vector2(320, h)
	var vp_size := get_viewport().get_visible_rect().size
	_opt_panel.position = (vp_size - _opt_panel.size) * 0.5
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.12, 0.98)
	bg.border_color = Color(0.7, 0.65, 0.3)
	bg.set_border_width_all(3)
	_opt_panel.add_theme_stylebox_override("panel", bg)
	layer.add_child(_opt_panel)
	_opt_panel.set_meta("layer", layer)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 14
	vb.offset_top = 12
	vb.offset_right = -14
	vb.offset_bottom = -12
	vb.add_theme_constant_override("separation", 8)
	_opt_panel.add_child(vb)

	var title := Label.new()
	title.text = str(ob.get_meta("option_title", "Select Option"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vb.add_child(title)

	var hint := Label.new()
	hint.text = "D-Pad / A select  |  B cancel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)

	for i in range(ob.item_count):
		var b := Button.new()
		b.text = ob.get_item_text(i)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 40)
		var idx := i
		b.pressed.connect(func():
			_pick_option(idx)
		)
		vb.add_child(b)
		_opt_buttons.append(b)
	_opt_focus_apply()


func _opt_focus_apply() -> void:
	if _opt_buttons.is_empty():
		return
	_opt_focus = clampi(_opt_focus, 0, _opt_buttons.size() - 1)
	for i in range(_opt_buttons.size()):
		var b: Control = _opt_buttons[i]
		if is_instance_valid(b):
			b.modulate = Color(1.45, 1.35, 0.5) if i == _opt_focus else Color(1, 1, 1)


func _opt_move(delta: int) -> void:
	if _opt_buttons.is_empty():
		return
	_opt_focus = posmod(_opt_focus + delta, _opt_buttons.size())
	_opt_focus_apply()


func _pick_option(idx: int) -> void:
	if _opt_target != null and is_instance_valid(_opt_target):
		_opt_target.select(idx)
		_opt_target.item_selected.emit(idx)
	_close_option_menu()


func _close_option_menu() -> void:
	if _opt_panel != null and is_instance_valid(_opt_panel):
		if _opt_panel.has_meta("layer"):
			var layer = _opt_panel.get_meta("layer")
			if is_instance_valid(layer):
				layer.queue_free()
		else:
			_opt_panel.queue_free()
	_opt_panel = null
	_opt_buttons.clear()
	_opt_focus = 0
	_opt_target = null


func _get_focusable_menu_items() -> Array:

	var list: Array = []
	for n in get_tree().get_nodes_in_group("menu_buttons"):
		if is_instance_valid(n) and n is Control and n.visible:
			list.append(n)
	if _name_edit != null and is_instance_valid(_name_edit):
		list.append(_name_edit)
	if _code_edit != null and is_instance_valid(_code_edit):
		list.append(_code_edit)
	if _split_opt != null and is_instance_valid(_split_opt):
		list.append(_split_opt)
	return list


func _focus_next() -> void:
	var list := _get_focusable_menu_items()
	if list.is_empty():
		return
	var focus := _focus_owner()
	var idx := list.find(focus)
	if idx == -1:
		idx = 0
	else:
		idx = (idx + 1) % list.size()
	(list[idx] as Control).grab_focus()


func _focus_prev() -> void:
	var list := _get_focusable_menu_items()
	if list.is_empty():
		return
	var focus := _focus_owner()
	var idx := list.find(focus)
	if idx == -1:
		idx = 0
	else:
		idx = (idx - 1 + list.size()) % list.size()
	(list[idx] as Control).grab_focus()




func _on_load_world() -> void:
	if not SaveManager.has_save():
		_status.text = "No saved world found yet — use New World first."
		return
	var data = SaveManager.read()
	if data == null or typeof(data) != TYPE_DICTIONARY:
		_status.text = "Save file is corrupted or unreadable."
		return
	_show_load_confirm(data)


func _show_load_confirm(data: Dictionary) -> void:
	# Same Panel pattern as host/settings (controller works)
	_close_host_dialog()
	_host_panel = Panel.new()
	_host_panel.name = "LoadConfirmPanel"
	_host_panel.z_index = 100
	_host_panel.set_anchors_preset(Control.PRESET_CENTER)
	_host_panel.custom_minimum_size = Vector2(440, 260)
	_host_panel.size = Vector2(440, 260)
	_host_panel.position = -_host_panel.size / 2.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.12, 0.97)
	bg.border_color = Color(0.5, 0.5, 0.55)
	bg.set_border_width_all(2)
	_host_panel.add_theme_stylebox_override("panel", bg)
	add_child(_host_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 16
	vb.offset_top = 16
	vb.offset_right = -16
	vb.offset_bottom = -16
	vb.add_theme_constant_override("separation", 12)
	_host_panel.add_child(vb)

	var title := Label.new()
	title.text = "Load World"
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)

	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var pdata = data.get("player", {})
	info.text = "Saved world found.\nDimension: %s\nSeed: %s\nPlayer health: %s" % [
		_dimension_display_name(str(data.get("current_dim", "overworld"))),
		str(data.get("seed", "?")),
		str(pdata.get("health", "?"))
	]
	vb.add_child(info)

	_host_controls.clear()
	_host_focus_idx = 0

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.focus_mode = Control.FOCUS_NONE
	load_btn.pressed.connect(func():
		if has_node("/root/Config"):
			Config.begin_load_world(data)
		if has_node("/root/HCSettings"):
			HCSettings.splitscreen_players = 1
			HCSettings.save_settings()
		_close_host_dialog()
		_change_to_game("Loading saved world...\nRestoring terrain and inventory")
	)
	vb.add_child(load_btn)
	_host_controls.append(load_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.focus_mode = Control.FOCUS_NONE
	cancel_btn.pressed.connect(_close_host_dialog)
	vb.add_child(cancel_btn)
	_host_controls.append(cancel_btn)

	_host_focus_idx = 0
	_host_focus_apply()


func _on_host() -> void:
	_show_new_world_dialog("host")


func _start_host_after_world_options() -> void:
	if not has_node("/root/Multiplayer"):
		_status.text = "Multiplayer autoload missing"
		return
	if has_node("/root/HCSettings"):
		var hs_host = get_node("/root/HCSettings")
		hs_host.server_display_name = _name_edit.text.strip_edges()
		hs_host.save_settings()
	var res = Multiplayer.host_with_room(-1, _name_edit.text)
	if res.get("ok", false):
		_room_label.text = "Server: %s\nRoom code: %s\nLAN: %s:%d" % [
			res.get("name", ""), res.get("code", ""), res.get("ip", ""), res.get("port", 0)
		]
		_status.text = "Hosting – share the room code shown below"
		_show_host_ready_dialog(res)
	else:
		_status.text = str(res.get("error", "Host failed"))


func _host_open() -> bool:
	return _host_panel != null and is_instance_valid(_host_panel) and _host_panel.visible


func _close_host_dialog() -> void:
	if _host_panel != null and is_instance_valid(_host_panel):
		_host_panel.queue_free()
	_host_panel = null
	_host_controls.clear()
	_host_focus_idx = 0


func _host_focus_apply() -> void:
	if _host_controls.is_empty():
		return
	_host_focus_idx = clampi(_host_focus_idx, 0, _host_controls.size() - 1)
	for i in range(_host_controls.size()):
		var c: Control = _host_controls[i]
		if not is_instance_valid(c):
			continue
		c.modulate = Color(1.4, 1.35, 0.6) if i == _host_focus_idx else Color(1, 1, 1)


func _host_move(delta: int) -> void:
	if _host_controls.is_empty():
		return
	_host_focus_idx = posmod(_host_focus_idx + delta, _host_controls.size())
	_host_focus_apply()


func _host_activate() -> void:
	if _host_controls.is_empty():
		return
	var c = _host_controls[_host_focus_idx]
	# Check the specialised Button subclasses first. OptionButton and
	# CheckButton both inherit Button and must not use the generic branch.
	if c is OptionButton:
		_open_option_menu(c as OptionButton)
	elif c is CheckButton:
		(c as CheckButton).button_pressed = not (c as CheckButton).button_pressed
	elif c is LineEdit:
		_open_text_osk(c as LineEdit)
	elif c is Button:
		(c as Button).pressed.emit()


func _show_host_ready_dialog(res: Dictionary) -> void:
	_close_host_dialog()
	_host_panel = Panel.new()
	_host_panel.name = "HostReadyPanel"
	_host_panel.z_index = 100
	_host_panel.set_anchors_preset(Control.PRESET_CENTER)
	_host_panel.custom_minimum_size = Vector2(440, 280)
	_host_panel.size = Vector2(440, 280)
	_host_panel.position = -_host_panel.size / 2.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.12, 0.97)
	bg.border_color = Color(0.5, 0.5, 0.55)
	bg.set_border_width_all(2)
	_host_panel.add_theme_stylebox_override("panel", bg)
	add_child(_host_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 16
	vb.offset_top = 16
	vb.offset_right = -16
	vb.offset_bottom = -16
	vb.add_theme_constant_override("separation", 12)
	_host_panel.add_child(vb)

	var title := Label.new()
	title.text = "Hosting"
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)

	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "Server: %s\nRoom code:  %s\nLAN address: %s:%d" % [
		res.get("name", ""), res.get("code", ""), res.get("ip", ""), res.get("port", 0)
	]
	info.add_theme_font_size_override("font_size", 16)
	vb.add_child(info)

	var hint := Label.new()
	hint.text = "Controller: D-Pad navigate  |  A confirm"
	vb.add_child(hint)

	_host_controls.clear()
	_host_focus_idx = 0

	var copy_btn := Button.new()
	copy_btn.text = "Copy room code"
	copy_btn.focus_mode = Control.FOCUS_NONE
	copy_btn.pressed.connect(func():
		DisplayServer.clipboard_set(str(res.get("code", "")))
		_status.text = "Room code copied"
	)
	vb.add_child(copy_btn)
	_host_controls.append(copy_btn)

	var start_btn := Button.new()
	start_btn.text = "Start Hosting"
	start_btn.focus_mode = Control.FOCUS_NONE
	start_btn.pressed.connect(func():
		_close_host_dialog()
		_change_to_game("Starting server...\nPreparing world")
	)
	vb.add_child(start_btn)
	_host_controls.append(start_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(_close_host_dialog)
	vb.add_child(close_btn)
	_host_controls.append(close_btn)

	_host_focus_idx = 1  # Start Hosting
	_host_focus_apply()


func _on_join() -> void:
	if not has_node("/root/Multiplayer"):
		_status.text = "Multiplayer autoload missing"
		return
	var code = _code_edit.text.strip_edges()
	if code == "":
		_status.text = "Enter a room code"
		return
	if not Multiplayer.world_config_received.is_connected(_on_join_world_ready):
		Multiplayer.world_config_received.connect(_on_join_world_ready, CONNECT_ONE_SHOT)
	var res = Multiplayer.join_room_code(code)
	if res.get("ok", false):
		_status.text = "Connecting and receiving world…"
	else:
		if Multiplayer.world_config_received.is_connected(_on_join_world_ready):
			Multiplayer.world_config_received.disconnect(_on_join_world_ready)
		_status.text = str(res.get("error", "Join failed"))


func _on_join_world_ready() -> void:
	_status.text = "World received — joining…"
	_change_to_game("Joining world...\nSynchronizing terrain")


func _on_split() -> void:
	var n = _split_opt.get_selected_id()
	if n < 2:
		n = 2
	_show_new_world_dialog("split", n)


func _skin_selector_open() -> bool:
	return _skin_panel != null and is_instance_valid(_skin_panel)


func _open_skin_selector() -> void:
	_close_skin_selector()
	var selector_layer := CanvasLayer.new()
	selector_layer.name = "MainMenuSkinSelectorLayer"
	selector_layer.layer = 290
	add_child(selector_layer)
	var blocker := ColorRect.new()
	blocker.color = Color(0.01, 0.015, 0.025, 0.72)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	selector_layer.add_child(blocker)
	_skin_panel = Panel.new()
	_skin_panel.name = "MainMenuSkinSelector"
	_skin_panel.set_meta("selector_layer", selector_layer)
	_skin_panel.set_anchors_preset(Control.PRESET_CENTER)
	_skin_panel.size = Vector2(480, 560)
	_skin_panel.position = -_skin_panel.size * 0.5
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.06, 0.07, 0.1, 0.99)
	background.border_color = Color(0.7, 0.65, 0.3)
	background.set_border_width_all(3)
	_skin_panel.add_theme_stylebox_override("panel", background)
	selector_layer.add_child(_skin_panel)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 18; layout.offset_right = -18; layout.offset_top = 16; layout.offset_bottom = -16
	_skin_panel.add_child(layout)
	var title := Label.new(); title.text = "Select Skin"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 25); layout.add_child(title)
	var current := "afro_steve"
	if has_node("/root/HCSettings"): current = str(HCSettings.selected_skin_name)
	var selected := Label.new(); selected.text = "Current: " + current.replace("_", " ").capitalize(); selected.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; layout.add_child(selected)
	var hint := Label.new(); hint.text = "Controller: D-Pad/left stick | A select | B close"; hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; layout.add_child(hint)
	_skin_scroll = ScrollContainer.new(); _skin_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; layout.add_child(_skin_scroll)
	var list := VBoxContainer.new(); list.custom_minimum_size.x = 420; _skin_scroll.add_child(list)
	_add_skin_choice(list, "Afro Steve (default)", "afro_steve")
	var files: Array[String] = []
	var directory := DirAccess.open("user://skins")
	if directory:
		directory.list_dir_begin()
		var file_name := directory.get_next()
		while file_name != "":
			if not directory.current_is_dir() and file_name.get_extension().to_lower() == "json": files.append(file_name.get_basename())
			file_name = directory.get_next()
		directory.list_dir_end()
	files.sort()
	for skin_name in files:
		if skin_name != "afro_steve": _add_skin_choice(list, skin_name.replace("_", " ").capitalize(), skin_name)
	var create := Button.new(); create.text = "Create another skin…"; create.focus_mode = Control.FOCUS_NONE; create.pressed.connect(func(): _close_skin_selector(); _open_avatar_editor()); list.add_child(create); _skin_buttons.append(create)
	var close := Button.new(); close.text = "Close"; close.focus_mode = Control.FOCUS_NONE; close.pressed.connect(_close_skin_selector); layout.add_child(close); _skin_buttons.append(close)
	_apply_skin_focus()


func _add_skin_choice(parent: Control, caption: String, skin_name: String) -> void:
	var button := Button.new(); button.text = caption; button.focus_mode = Control.FOCUS_NONE; button.pressed.connect(_select_main_menu_skin.bind(skin_name)); parent.add_child(button); _skin_buttons.append(button)


func _select_main_menu_skin(skin_name: String) -> void:
	if has_node("/root/HCSettings"):
		HCSettings.selected_skin_name = skin_name
		HCSettings.save_settings()
	_status.text = "Selected skin: " + skin_name.replace("_", " ").capitalize()
	_close_skin_selector()


func _apply_skin_focus() -> void:
	if _skin_buttons.is_empty(): return
	_skin_focus_idx = clampi(_skin_focus_idx, 0, _skin_buttons.size() - 1)
	for i in range(_skin_buttons.size()): _skin_buttons[i].modulate = Color(1.45, 1.35, 0.5) if i == _skin_focus_idx else Color.WHITE
	if _skin_scroll != null: _skin_scroll.scroll_vertical = maxi(0, _skin_focus_idx * 32 - 190)


func _handle_skin_selector_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and absf(event.axis_value) > 0.5 and _controller_nav_cooldown <= 0.0:
		_skin_focus_idx = posmod(_skin_focus_idx + (1 if event.axis_value > 0 else -1), _skin_buttons.size()); _apply_skin_focus(); _controller_nav_cooldown = CONTROLLER_NAV_DELAY; _mark_handled(); return
	if not (event is InputEventJoypadButton and event.pressed): return
	match event.button_index:
		JOY_BUTTON_DPAD_UP: _skin_focus_idx = posmod(_skin_focus_idx - 1, _skin_buttons.size()); _apply_skin_focus()
		JOY_BUTTON_DPAD_DOWN: _skin_focus_idx = posmod(_skin_focus_idx + 1, _skin_buttons.size()); _apply_skin_focus()
		JOY_BUTTON_A: _skin_buttons[_skin_focus_idx].pressed.emit()
		JOY_BUTTON_B: _close_skin_selector()
		_: return
	_mark_handled()


func _close_skin_selector() -> void:
	if _skin_panel != null and is_instance_valid(_skin_panel):
		var selector_layer = _skin_panel.get_meta("selector_layer", null)
		if selector_layer and is_instance_valid(selector_layer): selector_layer.queue_free()
		else: _skin_panel.queue_free()
	_skin_panel = null; _skin_scroll = null; _skin_buttons.clear(); _skin_focus_idx = 0
	if _first_btn != null and is_instance_valid(_first_btn): _first_btn.grab_focus()


func _open_avatar_editor() -> void:
	if _avatar_layer != null and is_instance_valid(_avatar_layer): return
	_close_skin_selector()
	_avatar_layer = CanvasLayer.new(); _avatar_layer.name = "MainMenuAvatarEditor"; _avatar_layer.layer = 300; add_child(_avatar_layer)
	var editor := preload("res://scripts/avatar_editor.gd").new()
	_avatar_layer.add_child(editor)
	editor.skin_saved.connect(func(data: Dictionary):
		var skin_name := str(data.get("name", "Afro Steve")).replace(" ", "_").to_lower()
		if has_node("/root/HCSettings"): HCSettings.selected_skin_name = skin_name; HCSettings.save_settings()
		_status.text = "Created and selected skin: " + skin_name.replace("_", " ").capitalize()
	)
	editor.closed.connect(func():
		if _avatar_layer != null and is_instance_valid(_avatar_layer): _avatar_layer.queue_free()
		_avatar_layer = null
		if _first_btn != null and is_instance_valid(_first_btn): _first_btn.grab_focus()
	)


func _on_addons() -> void:
	_close_addons()
	_addons_panel = Panel.new()
	_addons_panel.name = "AddonsPanel"
	_addons_panel.z_index = 120
	_addons_panel.set_anchors_preset(Control.PRESET_CENTER)
	_addons_panel.size = Vector2(720, 650)
	_addons_panel.position = -_addons_panel.size / 2.0
	add_child(_addons_panel)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 18
	scroll.offset_top = 14
	scroll.offset_right = -18
	scroll.offset_bottom = -14
	_addons_panel.add_child(scroll)
	_addons_scroll = scroll
	_addons_controls.clear()
	_addons_focus_idx = 0
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	scroll.add_child(vb)
	var title := Label.new()
	title.text = "HighCraft Mods, Shaders & Texture Packs"
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)
	var tutorial := Label.new()
	tutorial.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial.text = ("PACK INSTALLATION\n"
		+ "1. Download a HighCraft pack ZIP, or extract a pack folder manually.\n"
		+ "2. Put it in the Mods, Shaders, or Texture Packs location shown below.\n"
		+ "3. Every pack folder needs pack.json. Restart the world after changes.\n\n"
		+ "CREATING PACKS\n"
		+ "Texture pack: textures/<block_or_item_id>.png.\n"
		+ "Shader pack: sky.gdshader using shader_type sky.\n"
		+ "Mod: main.gd must extend Node; optional hooks are on_mod_loaded(api) and on_game_ready(game).\n\n"
		+ "Controller: D-Pad/stick navigates, A selects, B closes.\n\n"
		+ "WARNING: GDScript mods execute code with the same permissions as the game. Console builds may only allow texture/shader content. Only install packs you trust.")
	vb.add_child(tutorial)
	var folder_label := Label.new()
	folder_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	folder_label.text = "Pack storage: " + (Addons.root_dir if has_node("/root/Addons") else "Addons manager unavailable")
	vb.add_child(folder_label)
	var list_label := Label.new()
	list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if has_node("/root/Addons"):
		var names: Array[String] = []
		for pack in Addons.packs:
			names.append("• %s [%s]" % [str(pack.get("name", "Unnamed")), str(pack.get("type", "unknown"))])
		list_label.text = "Installed packs:\n" + ("None" if names.is_empty() else "\n".join(names))
	else:
		list_label.text = "Addons manager unavailable."
	vb.add_child(list_label)
	var url_edit := LineEdit.new()
	url_edit.placeholder_text = "https://example.com/highcraft-pack.zip"
	url_edit.focus_mode = Control.FOCUS_ALL
	vb.add_child(url_edit)
	_addons_controls.append(url_edit)
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(status)
	var download := Button.new()
	download.text = "Download and install ZIP"
	download.pressed.connect(func():
		status.text = "Downloading…"
		if has_node("/root/Addons"):
			Addons.download_zip(url_edit.text)
	)
	vb.add_child(download)
	_addons_controls.append(download)
	if has_node("/root/Addons"):
		var callback := func(ok: bool, message: String): status.text = ("Installed: " if ok else "Error: ") + message
		Addons.download_finished.connect(callback, CONNECT_ONE_SHOT)
	var open_folder := Button.new()
	open_folder.text = "Open pack folder"
	open_folder.pressed.connect(func():
		if has_node("/root/Addons"):
			OS.shell_open(Addons.root_dir)
	)
	vb.add_child(open_folder)
	# Opening a system folder is unavailable on most consoles. Keep the pack UI
	# portable and only expose this convenience where a desktop shell exists.
	open_folder.visible = OS.has_feature("editor") or OS.has_feature("windows") or OS.has_feature("linuxbsd") or OS.has_feature("macos")
	if open_folder.visible:
		_addons_controls.append(open_folder)
	var rescan := Button.new()
	rescan.text = "Rescan packs"
	rescan.pressed.connect(func():
		if has_node("/root/Addons"):
			Addons.rescan()
			Textures.clear_cache()
		status.text = "Packs rescanned. Restart the world to rebuild block materials."
	)
	vb.add_child(rescan)
	_addons_controls.append(rescan)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(_close_addons)
	vb.add_child(close)
	_addons_controls.append(close)
	_addons_focus_apply()


func _addons_open() -> bool:
	return _addons_panel != null and is_instance_valid(_addons_panel) and _addons_panel.visible


func _addons_focus_apply() -> void:
	if _addons_controls.is_empty():
		return
	_addons_focus_idx = clampi(_addons_focus_idx, 0, _addons_controls.size() - 1)
	for i in range(_addons_controls.size()):
		var control := _addons_controls[i]
		if is_instance_valid(control):
			control.modulate = Color(1.4, 1.35, 0.6) if i == _addons_focus_idx else Color.WHITE
	var focused := _addons_controls[_addons_focus_idx]
	if is_instance_valid(focused):
		focused.grab_focus()
		if _addons_scroll != null:
			_addons_scroll.ensure_control_visible(focused)


func _addons_move(delta: int) -> void:
	if _addons_controls.is_empty():
		return
	_addons_focus_idx = posmod(_addons_focus_idx + delta, _addons_controls.size())
	_addons_focus_apply()


func _addons_activate() -> void:
	if _addons_controls.is_empty():
		return
	var control := _addons_controls[_addons_focus_idx]
	if control is LineEdit:
		_open_text_osk(control as LineEdit)
	elif control is Button:
		(control as Button).pressed.emit()


func _close_addons() -> void:
	if _addons_panel != null and is_instance_valid(_addons_panel):
		_addons_panel.queue_free()
	_addons_panel = null
	_addons_scroll = null
	_addons_controls.clear()
	_addons_focus_idx = 0
	if _first_btn != null and is_instance_valid(_first_btn):
		_first_btn.grab_focus()


func _on_settings() -> void:
	# Rebuild settings as in-scene Panel (same viewport → controller works)
	_close_settings()

	_settings_panel = Panel.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.z_index = 100
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.custom_minimum_size = Vector2(440, 580)
	_settings_panel.size = Vector2(440, 580)
	_settings_panel.position = -_settings_panel.size / 2.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.12, 0.97)
	bg.border_color = Color(0.5, 0.5, 0.55)
	bg.set_border_width_all(2)
	_settings_panel.add_theme_stylebox_override("panel", bg)
	add_child(_settings_panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 12
	scroll.offset_top = 12
	scroll.offset_right = -12
	scroll.offset_bottom = -12
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settings_panel.add_child(scroll)
	_settings_scroll = scroll

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)

	_settings_controls.clear()
	_settings_focus_idx = 0

	if not has_node("/root/HCSettings"):
		var warn := Label.new()
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.text = "HCSettings autoload missing."
		vb.add_child(warn)
		var close_warn := Button.new()
		close_warn.text = "Close"
		close_warn.pressed.connect(_close_settings)
		vb.add_child(close_warn)
		_settings_controls.append(close_warn)
		_settings_focus_apply()
		return

	var hs = get_node("/root/HCSettings")
	_add_slider(vb, "Chunk load radius", 2, 24, hs.chunk_load_radius, func(v): hs.chunk_load_radius = int(v))
	_add_slider(vb, "Chunk unload radius", 4, 32, hs.chunk_unload_radius, func(v): hs.chunk_unload_radius = int(v))
	_add_slider(vb, "Reload threshold (blocks)", 4, 64, hs.chunk_reload_threshold, func(v): hs.chunk_reload_threshold = v)
	_add_slider(vb, "FOV", 50, 110, hs.fov, func(v): hs.fov = v)
	_add_check(vb, "VSync", hs.vsync, func(on): hs.vsync = on)
	_add_check(vb, "Fullscreen", hs.fullscreen, func(on): hs.fullscreen = on)
	_add_slider(vb, "Render distance (chunks)", 2, 24, hs.render_distance, func(v): hs.render_distance = int(v))
	_add_slider(vb, "Shadow quality (0=off,1=low,2=high)", 0, 2, hs.shadow_quality, func(v): hs.shadow_quality = int(v))
	_add_check(vb, "Realistic water", hs.realistic_water, func(on): hs.realistic_water = on)
	_add_check(vb, "Footprints", hs.footprints, func(on): hs.footprints = on)
	_add_check(vb, "Swaying flowers", hs.swaying_flowers, func(on): hs.swaying_flowers = on)
	_add_check(vb, "Tall grass meshes", hs.tall_grass_mesh, func(on): hs.tall_grass_mesh = on)
	_add_check(vb, "Crossplay", hs.crossplay_enabled, func(on): hs.crossplay_enabled = on)

	var saveb := Button.new()
	saveb.text = "Save settings"
	saveb.focus_mode = Control.FOCUS_ALL
	saveb.pressed.connect(func():
		hs.save_settings()
		_close_settings()
	)
	vb.add_child(saveb)
	_settings_controls.append(saveb)

	var closeb := Button.new()
	closeb.text = "Close without saving"
	closeb.focus_mode = Control.FOCUS_ALL
	closeb.pressed.connect(_close_settings)
	vb.add_child(closeb)
	_settings_controls.append(closeb)

	_settings_focus_idx = 0
	_settings_focus_apply()


func _add_slider(parent, title: String, mn: float, mx: float, val: float, cb: Callable) -> void:
	var l := Label.new()
	l.text = title + ": " + str(int(val))
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 1
	s.value = val
	s.focus_mode = Control.FOCUS_ALL
	s.custom_minimum_size = Vector2(360, 24)
	s.value_changed.connect(func(v):
		l.text = title + ": " + str(int(v))
		cb.call(v)
	)
	parent.add_child(s)
	_settings_controls.append(s)


func _add_check(parent, title: String, val: bool, cb: Callable) -> void:
	var c := CheckButton.new()
	c.text = title
	c.button_pressed = val
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(cb)
	parent.add_child(c)
	_settings_controls.append(c)
