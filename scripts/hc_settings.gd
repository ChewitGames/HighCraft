extends Node
# Autoload name: HCSettings
signal settings_changed
const PATH = "user://hc_settings.cfg"
var render_distance: int = 8
var max_fps: int = 0
var vsync: bool = true
var fullscreen: bool = false
var shadow_quality: int = 1
var fov: float = 75.0
var chunk_load_radius: int = 8
var chunk_unload_radius: int = 12
var chunk_reload_threshold: float = 16.0
var realistic_water: bool = true
var footprints: bool = true
var swaying_flowers: bool = true
var tall_grass_mesh: bool = true
var crossplay_enabled: bool = true
var preferred_port: int = 4242
var max_players: int = 8
var server_display_name: String = "HighCraft Server"
var splitscreen_players: int = 1
var splitscreen_layout: String = "auto"
var controller_aim_sensitivity: float = 1.2
var controller_deadzone: float = 0.18

# Gemeinsame Controller-Navigation für Settings-UIs. Die eigentliche Settings-Szene
# kann diese Helfer verwenden, ohne eigene D-Pad/Stick-Logik zu duplizieren.
const CONTROLLER_NAV_DELAY = 0.18
var _controller_nav_cooldown: float = 0.0
var _settings_focus: Control = null

func _process(delta: float) -> void:
	if _controller_nav_cooldown > 0.0:
		_controller_nav_cooldown = maxf(0.0, _controller_nav_cooldown - delta)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventJoypadMotion or event is InputEventJoypadButton):
		return
	if _controller_nav_cooldown > 0.0:
		return

	# WICHTIG: NICHT get_viewport().gui_get_focus_owner() verwenden – das
	# Settings-Fenster ist ein eigenes Window (= eigener Viewport), das
	# Autoload sitzt aber im Haupt-Viewport. Wir tracken den Fokus deshalb
	# selbst statt ihn viewport-übergreifend abzufragen.
	var focus = _settings_focus
	if focus == null or not is_instance_valid(focus) or not _is_settings_control(focus):
		focus = _find_settings_focus()
		if focus != null:
			focus.grab_focus()
			_settings_focus = focus
	if focus == null or not is_instance_valid(focus) or not _is_settings_control(focus):
		return

	if event is InputEventJoypadMotion:
		if absf(event.axis_value) <= controller_deadzone:
			return
		var direction = 1 if event.axis_value > 0.0 else -1
		if event.axis == JOY_AXIS_LEFT_Y:
			_move_settings_focus(focus, direction)
		elif event.axis == JOY_AXIS_LEFT_X:
			if _change_settings_value(focus, direction):
				get_viewport().set_input_as_handled()
			else:
				_move_settings_focus(focus, direction)
		else:
			return
		get_viewport().set_input_as_handled()
		_controller_nav_cooldown = CONTROLLER_NAV_DELAY
		return

	if not event.pressed:
		return

	match event.button_index:
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN:
			var direction = -1 if event.button_index == JOY_BUTTON_DPAD_UP else 1
			_move_settings_focus(focus, direction)
			get_viewport().set_input_as_handled()
			_controller_nav_cooldown = CONTROLLER_NAV_DELAY
		JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
			var direction = -1 if event.button_index == JOY_BUTTON_DPAD_LEFT else 1
			if _change_settings_value(focus, direction):
				get_viewport().set_input_as_handled()
			else:
				_move_settings_focus(focus, direction)
			_controller_nav_cooldown = CONTROLLER_NAV_DELAY
		JOY_BUTTON_A:
			if focus is BaseButton:
				focus.emit_signal("pressed")
				get_viewport().set_input_as_handled()
				_controller_nav_cooldown = CONTROLLER_NAV_DELAY

func _find_settings_focus() -> Control:
	var scene = get_tree().current_scene
	if scene == null:
		return null
	var controls: Array[Control] = []
	_collect_focusable_controls(scene, controls)
	for c in controls:
		if _is_settings_control(c):
			return c
	return null

func _change_settings_value(control: Control, direction: int) -> bool:
	if control is Range:
		var r = control as Range
		r.value = clampf(r.value + r.step * direction, r.min_value, r.max_value)
		return true
	if control is OptionButton:
		var option = control as OptionButton
		var count = option.item_count
		if count <= 0:
			return false
		option.select(posmod(option.selected + direction, count))
		option.item_selected.emit(option.selected)
		return true
	return false

func _is_settings_control(control: Control) -> bool:
	var node: Node = control
	while node != null:
		var n = node.name.to_lower()
		if "settings" in n or "hcsettings" in n:
			return true
		if node.has_meta("settings_ui") and bool(node.get_meta("settings_ui")):
			return true
		node = node.get_parent()
	return false

func _move_settings_focus(current: Control, direction: int) -> void:
	var root: Node = current
	while root.get_parent() != null:
		var parent = root.get_parent()
		if parent is Control and _is_settings_control(parent):
			root = parent
		else:
			break
	if not (root is Control):
		return

	var controls: Array[Control] = []
	_collect_focusable_controls(root, controls)
	if controls.is_empty():
		return

	var index = controls.find(current)
	if index < 0:
		index = 0
	var next = (index + direction) % controls.size()
	if next < 0:
		next += controls.size()
	controls[next].grab_focus()
	_settings_focus = controls[next]

func _collect_focusable_controls(node: Node, out: Array[Control]) -> void:
	if node is Control and node != self:
		var c = node as Control
		if c.visible and c.focus_mode != Control.FOCUS_NONE and c is not Label:
			out.append(c)
	for child in node.get_children():
		_collect_focusable_controls(child, out)

func _ready() -> void:
	load_settings()
	apply_graphics()
	_disable_ui_joypad_intercept()

func _disable_ui_joypad_intercept() -> void:
	# Godot fängt JOY_BUTTON_A/B standardmäßig als ui_accept/ui_cancel ab,
	# sobald irgendein Control echten Engine-Fokus hält (z.B. via
	# grab_focus()). Das passiert VOR _unhandled_input – unsere eigene
	# Controller-Logik (hier und in game_ui.gd) sah die Events dadurch nie.
	# Wir entfernen die Joypad-Bindungen aus diesen Actions global, damit
	# Buttons/Slider/CheckButtons trotzdem normal Engine-Fokus (=sichtbaren
	# Fokus-Rahmen) bekommen können, ohne A/B selbst zu verarbeiten.
	for action in ["ui_accept", "ui_cancel", "ui_select"]:
		if not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton:
				InputMap.action_erase_event(action, ev)

func load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	render_distance = int(cfg.get_value("gfx", "render_distance", render_distance))
	chunk_load_radius = int(cfg.get_value("chunk", "load_radius", chunk_load_radius))
	chunk_unload_radius = int(cfg.get_value("chunk", "unload_radius", chunk_unload_radius))
	chunk_reload_threshold = float(cfg.get_value("chunk", "reload_threshold", chunk_reload_threshold))
	max_fps = int(cfg.get_value("gfx", "max_fps", max_fps))
	vsync = bool(cfg.get_value("gfx", "vsync", vsync))
	fullscreen = bool(cfg.get_value("gfx", "fullscreen", fullscreen))
	shadow_quality = int(cfg.get_value("gfx", "shadow_quality", shadow_quality))
	fov = float(cfg.get_value("gfx", "fov", fov))
	realistic_water = bool(cfg.get_value("fx", "water", realistic_water))
	footprints = bool(cfg.get_value("fx", "footprints", footprints))
	swaying_flowers = bool(cfg.get_value("fx", "flowers", swaying_flowers))
	tall_grass_mesh = bool(cfg.get_value("fx", "grass", tall_grass_mesh))
	crossplay_enabled = bool(cfg.get_value("net", "crossplay", crossplay_enabled))
	preferred_port = int(cfg.get_value("net", "port", preferred_port))
	max_players = int(cfg.get_value("net", "max_players", max_players))
	server_display_name = str(cfg.get_value("net", "server_name", server_display_name))
	splitscreen_players = clampi(int(cfg.get_value("split", "players", splitscreen_players)), 1, 4)
	splitscreen_layout = str(cfg.get_value("split", "layout", splitscreen_layout))
	controller_aim_sensitivity = float(cfg.get_value("pad", "aim", controller_aim_sensitivity))
	controller_deadzone = float(cfg.get_value("pad", "deadzone", controller_deadzone))

func save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("gfx", "render_distance", render_distance)
	cfg.set_value("gfx", "max_fps", max_fps)
	cfg.set_value("gfx", "vsync", vsync)
	cfg.set_value("gfx", "fullscreen", fullscreen)
	cfg.set_value("gfx", "shadow_quality", shadow_quality)
	cfg.set_value("gfx", "fov", fov)
	cfg.set_value("chunk", "load_radius", chunk_load_radius)
	cfg.set_value("chunk", "unload_radius", chunk_unload_radius)
	cfg.set_value("chunk", "reload_threshold", chunk_reload_threshold)
	cfg.set_value("fx", "water", realistic_water)
	cfg.set_value("fx", "footprints", footprints)
	cfg.set_value("fx", "flowers", swaying_flowers)
	cfg.set_value("fx", "grass", tall_grass_mesh)
	cfg.set_value("net", "crossplay", crossplay_enabled)
	cfg.set_value("net", "port", preferred_port)
	cfg.set_value("net", "max_players", max_players)
	cfg.set_value("net", "server_name", server_display_name)
	cfg.set_value("split", "players", splitscreen_players)
	cfg.set_value("split", "layout", splitscreen_layout)
	cfg.set_value("pad", "aim", controller_aim_sensitivity)
	cfg.set_value("pad", "deadzone", controller_deadzone)
	cfg.save(PATH)
	apply_graphics()
	settings_changed.emit()

func apply_graphics() -> void:
	Engine.max_fps = max_fps
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func effective_load_radius() -> int:
	return clampi(chunk_load_radius, 2, 32)

func effective_unload_radius() -> int:
	return maxi(chunk_unload_radius, chunk_load_radius + 2)
