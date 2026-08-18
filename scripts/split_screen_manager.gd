class_name SplitScreenManager
extends Node
# Local split-screen for 1–4 players.
# P1: keyboard+mouse OR controller 0
# P2–P4: extra keyboards (device index) and/or controllers only — no shared mouse.

signal players_ready

const PLAYER_SCENE := "res://scenes/player.tscn"

var player_count: int = 1
var players: Array = []       # CharacterBody3D
var viewports: Array = []     # SubViewport
var cameras: Array = []
var input_maps: Array = []    # per-player device binding


var uis: Array = []


func start(count: int, parent: Node, spawn_pos: Vector3 = Vector3(8, 80, 8)) -> void:
	player_count = clampi(count, 1, 4)
	_clear()
	uis.clear()

	var layout: Array = _layout_rects(player_count)

	for i in range(player_count):
		var rect: Rect2 = layout[i]

		# 1) Viewport + Container (3D)
		var vp := SubViewport.new()
		vp.size = Vector2i(maxi(64, int(rect.size.x)), maxi(64, int(rect.size.y)))
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.handle_input_locally = true
		vp.gui_disable_input = false
		var cont := SubViewportContainer.new()
		cont.stretch = true
		cont.position = rect.position
		cont.size = rect.size
		cont.mouse_filter = Control.MOUSE_FILTER_STOP
		parent.add_child(cont)
		cont.add_child(vp)
		# Assign shared world AFTER viewport is in the tree
		if parent is Node3D:
			var w3d = parent.get_world_3d()
			if w3d != null:
				vp.world_3d = w3d
			else:
				push_error("[SplitScreen] parent world_3d is null — terrain will not show")

		# 2) Player in den Viewport
		var p = load(PLAYER_SCENE).instantiate()
		p.name = "Player%d" % (i + 1)
		p.set_meta("split_index", i)
		vp.add_child(p)
		p.global_position = spawn_pos + Vector3(float(i) * 2.0, 0, 0)
		var cam: Camera3D = p.find_child("Camera3D", true, false) as Camera3D
		if cam:
			cam.current = true

		players.append(p)
		viewports.append(vp)
		cameras.append(cam)

		# 3) HIER — UI nur für diesen Spieler ----------
		# WICHTIG: GameUI ist ein CanvasLayer und rendert daher immer den
		# GESAMTEN Viewport, dem es angehört. Als Kind eines Control im
		# Hauptbaum (parent) würde es also den ganzen Bildschirm
		# überdecken statt nur diesen Split. Deshalb muss die UI direkt
		# in den SubViewport dieses Spielers (vp) gehängt werden.
		var ui := GameUI.new()
		vp.add_child(ui)
		ui.setup_split(p, null, rect, i)
		p.set_meta("ui", ui)
		uis.append(ui)
		# ------------------------------------------------

	print("[SplitScreen] players=", player_count, " uis=", uis.size())
	players_ready.emit()


func _layout_ui_local(ui: Node, size: Vector2) -> void:
	# Alles relativ zum UIRoot (0,0 = Ecke DIESES Splits)
	for c in ui.get_children():
		if c is Control:
			pass  # setup_split setzt Positionen auf lokales Rect
		
func _fit_ui_to_rect(ui: Node, rect: Rect2) -> void:
	# CanvasLayer deckt immer den Root-Viewport ab → auf Control umbiegen
	if ui is CanvasLayer:
		ui.offset = Vector2.ZERO
		# Child-Controls in die Split-Ecke schieben
		for c in ui.get_children():
			if c is Control:
				c.set_anchors_preset(Control.PRESET_TOP_LEFT)
				c.position = rect.position
				# Hotbar o.Ä. relativ unten im Split halten:
				# bleibt über setup_split sauberer
	elif ui is Control:
		ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
		ui.position = rect.position
		ui.size = rect.size
		ui.clip_contents = true


func _vp_size(r: Rect2) -> Vector2i:
	return Vector2i(maxi(32, int(r.size.x)), maxi(32, int(r.size.y)))


func _layout_rects(n: int) -> Array:
	var w = float(DisplayServer.window_get_size().x)
	var h = float(DisplayServer.window_get_size().y)
	match n:
		1:
			return [Rect2(0, 0, w, h)]
		2:
			return [Rect2(0, 0, w * 0.5, h), Rect2(w * 0.5, 0, w * 0.5, h)]
		3:
			return [
				Rect2(0, 0, w * 0.5, h * 0.5),
				Rect2(w * 0.5, 0, w * 0.5, h * 0.5),
				Rect2(0, h * 0.5, w, h * 0.5)
			]
		_:
			return [
				Rect2(0, 0, w * 0.5, h * 0.5),
				Rect2(w * 0.5, 0, w * 0.5, h * 0.5),
				Rect2(0, h * 0.5, w * 0.5, h * 0.5),
				Rect2(w * 0.5, h * 0.5, w * 0.5, h * 0.5)
			]


func _clear() -> void:
	for u in uis:
		if is_instance_valid(u):
			u.queue_free()
	for p in players:
		if is_instance_valid(p):
			p.queue_free()
	for vp in viewports:
		if is_instance_valid(vp):
			var cont = vp.get_parent()
			vp.queue_free()
			if cont != null and is_instance_valid(cont) and cont is SubViewportContainer:
				cont.queue_free()
	players.clear()
	viewports.clear()
	cameras.clear()
	input_maps.clear()
	uis.clear()


static func read_move_axis(split_index: int, deadzone: float = 0.18) -> Vector2:
	# P1 keyboard WASD + joy0; P2+ joy device index only (or secondary keys if you expand)
	var v := Vector2.ZERO
	if split_index == 0:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			v.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			v.y += 1
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			v.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			v.x += 1
	var joy = split_index
	var lx = Input.get_joy_axis(joy, JOY_AXIS_LEFT_X)
	var ly = Input.get_joy_axis(joy, JOY_AXIS_LEFT_Y)
	if absf(lx) > deadzone:
		v.x += lx
	if absf(ly) > deadzone:
		v.y += ly
	if v.length() > 1.0:
		v = v.normalized()
	return v


static func read_look_axis(split_index: int, sens: float = 1.2, deadzone: float = 0.18) -> Vector2:
	var rx = Input.get_joy_axis(split_index, JOY_AXIS_RIGHT_X)
	var ry = Input.get_joy_axis(split_index, JOY_AXIS_RIGHT_Y)
	var look := Vector2.ZERO
	if absf(rx) > deadzone:
		look.x = rx * sens
	if absf(ry) > deadzone:
		look.y = ry * sens
	return look


static func is_action_just_pressed(split_index: int, action: String) -> bool:
	# Map generic actions to joy buttons per device
	match action:
		"jump":
			if split_index == 0 and Input.is_key_pressed(KEY_SPACE):
				return Input.is_physical_key_pressed(KEY_SPACE)
			return Input.is_joy_button_pressed(split_index, JOY_BUTTON_A)
		"interact":
			if split_index == 0 and Input.is_key_pressed(KEY_E):
				return true
			return Input.is_joy_button_pressed(split_index, JOY_BUTTON_X)
		"inventory":
			if split_index == 0 and Input.is_key_pressed(KEY_E):
				return true
			return Input.is_joy_button_pressed(split_index, JOY_BUTTON_Y)
		"pause":
			if split_index == 0 and Input.is_key_pressed(KEY_ESCAPE):
				return true
			return Input.is_joy_button_pressed(split_index, JOY_BUTTON_START)
	return false
