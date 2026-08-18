extends Control
# HighCraft main menu: logo, rotating world preview, Singleplayer / Load /
# Host (room code) / Join / Split-Screen / Settings.

const GAME_SCENE := "res://scenes/game.tscn"


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
var _first_btn: Button

# Settings as in-scene Panel (NOT Window) so controller focus stays in same viewport
var _settings_panel: Panel = null
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
	if has_node("/root/Music"):
		get_node("/root/Music").play_for_dimension("menu")
	_build_ui()
	_build_preview()


func _process(delta: float) -> void:
	if _preview_cam == null or not _preview_cam.is_inside_tree():
		return
	_preview_angle += delta * 0.15
	var r = 24.0  # stays well inside the ~48-block generated preview radius
	var cam_pos = Vector3(cos(_preview_angle) * r, _preview_focus_y + 34.0, sin(_preview_angle) * r)
	_preview_cam.look_at_from_position(cam_pos, Vector3(0, _preview_focus_y, 0), Vector3.UP)


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
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.45, 0.7, 1.0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.85, 0.9)
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(sun)

	_spawn_real_terrain(world)

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


func _spawn_real_terrain(world: Node3D) -> void:
	# Use the exact same world generator + chunk renderer as the real game
	# (see game.gd _ready) so the preview shows genuine HighCraft terrain
	# instead of placeholder shapes.
	var seed_val: int = randi()
	var world_type = "normal"
	var gen_structures = false
	if has_node("/root/Config"):
		seed_val = Config.seed_val if Config.seed_val != null else seed_val
		if "world_type" in Config:
			world_type = Config.world_type
		if "generate_structures" in Config:
			gen_structures = Config.generate_structures

	var dim_mgr = DimensionManager.new(seed_val, world_type, gen_structures)
	var pworld = dim_mgr.get_world("overworld")
	var prenderer := ChunkRenderer.new()
	world.add_child(prenderer)
	prenderer.setup(pworld)
	prenderer.set_world(pworld)
	var sy = pworld.surface_height(0, 0)
	prenderer.max_builds_per_call = 9999
	prenderer.update_around(Vector3(0, sy, 0), 4)
	_preview_focus_y = float(sy)


func _build_ui() -> void:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = 40
	panel.offset_top = -280
	panel.offset_right = 420
	panel.offset_bottom = 280
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 16
	vb.offset_top = 16
	vb.offset_right = -16
	vb.offset_bottom = -16
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var logo := Label.new()
	logo.text = "HIGHCRAFT"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 36)
	vb.add_child(logo)

	var sub := Label.new()
	sub.text = "Desktop full version  ·  Linux / Windows / macOS"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	_add_btn(vb, "New World", _on_new_world)
	_add_btn(vb, "Load World…", _on_load_world)
	_add_btn(vb, "Host Server (Room Code)", _on_host)
	_add_btn(vb, "Join with Room Code", _on_join)
	_add_btn(vb, "Local Split-Screen", _on_split)
	_add_btn(vb, "Settings", _on_settings)
	_add_btn(vb, "Quit", func(): get_tree().quit())
	if _first_btn:
		_first_btn.grab_focus()

	vb.add_child(Label.new())
	var nl := Label.new()
	nl.text = "Server name (shown with room code):"
	vb.add_child(nl)
	_name_edit = LineEdit.new()
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
	if has_node("/root/HCSettings"):
		var hs = get_node("/root/HCSettings")
		hs.splitscreen_players = 1
		hs.save_settings()
	if has_node("/root/Config"):
		Config.reset_defaults()
		Config.pending_save = null
		if Config.has_meta("splitscreen"):
			Config.remove_meta("splitscreen")
	get_tree().change_scene_to_file(GAME_SCENE)
	
	
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
	title.text = "Split-Screen Players"
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
		str(data.get("current_dim", "overworld")),
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
			Config.pending_save = data
		_close_host_dialog()
		get_tree().change_scene_to_file(GAME_SCENE)
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
	if c is Button:
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
		get_tree().change_scene_to_file(GAME_SCENE)
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
	var res = Multiplayer.join_room_code(code)
	if res.get("ok", false):
		_status.text = "Connecting…"
		get_tree().change_scene_to_file(GAME_SCENE)
	else:
		_status.text = str(res.get("error", "Join failed"))


func _on_split() -> void:
	var n = _split_opt.get_selected_id()
	if n < 2:
		n = 2
	if has_node("/root/HCSettings"):
		var hs_split = get_node("/root/HCSettings")
		hs_split.splitscreen_players = n
		hs_split.save_settings()
	if has_node("/root/Config"):
		Config.set_meta("splitscreen", n)
	_status.text = "Starting %d-player local split-screen (controllers / extra keys)" % n
	get_tree().change_scene_to_file(GAME_SCENE)


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
