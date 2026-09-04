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
var sky_materials: Array = []
var _safe_sky_time: float = 0.3
var _safe_sky_rain: float = 0.0
var input_maps: Array = []    # per-player device binding


var uis: Array = []


func start(count: int, parent: Node, spawn_pos: Vector3 = Vector3(8, 80, 8)) -> void:
	player_count = clampi(count, 1, 4)
	_clear()
	uis.clear()

	var root_size := parent.get_viewport().get_visible_rect().size
	var layout: Array = _layout_rects(player_count, root_size)

	for i in range(player_count):
		var rect: Rect2 = layout[i]

		# 1) Viewport + Container (3D)
		var vp := SubViewport.new()
		vp.size = Vector2i(maxi(64, int(rect.size.x)), maxi(64, int(rect.size.y)))
		# Render every split at its native pane resolution. The former 66/56%
		# scale was visibly soft and made lighting/block edges look low quality.
		vp.scaling_3d_scale = 1.0
		# Use a history-free render path for every split. Temporal/upscaling state
		# in several SubViewports can leak stale black/grey tiles on some Windows
		# GPUs, especially while chunk geometry is added to the shared World3D.
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		# Multisampled SubViewport resolve can leave coloured tiles on some
		# Forward+ Windows drivers. Native resolution stays sharp without it.
		vp.msaa_3d = Viewport.MSAA_DISABLED
		# FXAA blurs the entire finished image, including voxel texture detail.
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		vp.use_hdr_2d = false
		vp.snap_2d_transforms_to_pixel = true
		vp.snap_2d_vertices_to_pixel = true
		vp.positional_shadow_atlas_size = 2048
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		vp.transparent_bg = false
		vp.handle_input_locally = true
		vp.gui_disable_input = false
		var cont := SubViewportContainer.new()
		cont.stretch = true
		cont.clip_contents = true
		# Anchor split panes to the root viewport. Fixed DisplayServer pixel
		# rectangles drift under DPI scaling/fullscreen resize and can overlap or
		# leave gray gaps between P1 and P2.
		cont.anchor_left = rect.position.x / root_size.x
		cont.anchor_top = rect.position.y / root_size.y
		cont.anchor_right = rect.end.x / root_size.x
		cont.anchor_bottom = rect.end.y / root_size.y
		cont.offset_left = 0.0
		cont.offset_top = 0.0
		cont.offset_right = 0.0
		cont.offset_bottom = 0.0
		cont.mouse_filter = Control.MOUSE_FILTER_STOP
		parent.add_child(cont)
		cont.add_child(vp)
		cont.resized.connect(_sync_viewport_size.bind(vp, cont))
		call_deferred("_sync_viewport_size", vp, cont)
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
		p.controller_device = i
		vp.add_child(p)
		p.global_position = spawn_pos + Vector3(float(i) * 2.0, 0, 0)
		var cam: Camera3D = p.find_child("Camera3D", true, false) as Camera3D
		if cam:
			cameras.append(cam)
			cam.current = true
			_isolate_camera_environment(cam, parent)
			var chunk_radius := 8
			if parent.has_node("/root/HCSettings"):
				chunk_radius = clampi(int(parent.get_node("/root/HCSettings").chunk_load_radius), 2, 24)
			# The shared world contains the union of every local player's chunks.
			# A huge default far plane made each camera submit terrain loaded only
			# for the other players. Cull it at this camera's own chunk horizon.
			cam.far = clampf(float(chunk_radius + 2) * 16.0, 64.0, 416.0)

		players.append(p)
		viewports.append(vp)

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

	# A WorldEnvironment on the root viewport is not reliably resolved by cameras
	# rendered through separate SubViewports. Give every split camera an explicit
	# environment after all cameras have entered the shared World3D.
	var source_env = parent.get("env")
	if source_env is Environment:
		refresh_camera_environments(source_env)

	print("[SplitScreen] players=", player_count, " uis=", uis.size())
	players_ready.emit()


func _isolate_camera_environment(cam: Camera3D, parent: Node) -> void:
	# The final override is installed once all split cameras exist. Clear any
	# scene-provided override until then.
	cam.environment = null
	cam.set_meta("split_safe_sky", false)
	cam.set_meta("highcraft_dimension", str(parent.get("current_dim")))


func set_sky_parameter(parameter: StringName, value: Variant) -> void:
	if parameter == &"time_of_day":
		_safe_sky_time = float(value)
	elif parameter == &"rain_amount":
		_safe_sky_rain = float(value)
	for material in sky_materials:
		if material != null and is_instance_valid(material):
			material.set_shader_parameter(parameter, value)
	_update_safe_sky_colors()


func _update_safe_sky_colors() -> void:
	var elevation := sin(_safe_sky_time * TAU - PI * 0.5)
	var daylight := smoothstep(-0.12, 0.18, elevation)
	var night_color := Color(0.008, 0.015, 0.055)
	var day_color := Color(0.48, 0.68, 0.94)
	var color := night_color.lerp(day_color, daylight)
	color = color.lerp(color * 0.55, clampf(_safe_sky_rain, 0.0, 1.0))
	for cam in cameras:
		if cam != null and is_instance_valid(cam) and cam.environment != null:
			var target: Environment = cam.environment
			if bool(cam.get_meta("split_safe_sky", false)):
				var dim := str(cam.get_meta("highcraft_dimension", "overworld"))
				if dim == "hell":
					target.background_color = Color(0.16, 0.018, 0.01)
					target.ambient_light_color = Color(0.55, 0.22, 0.16)
					target.ambient_light_energy = 0.6
				elif dim == "the_end":
					target.background_color = Color(0.045, 0.02, 0.075)
					target.ambient_light_color = Color(0.42, 0.46, 0.62)
					target.ambient_light_energy = 0.55
				elif dim == "heaven":
					target.background_color = Color(0.48, 0.76, 1.0)
					target.ambient_light_color = Color(0.86, 0.93, 1.0)
					target.ambient_light_energy = 0.95
				else:
					target.background_color = color
					target.ambient_light_color = color.lerp(Color.WHITE, 0.38)
					target.ambient_light_energy = lerpf(0.62, 0.88, daylight)


func refresh_camera_environments(source_env: Environment) -> void:
	if source_env == null:
		return
	sky_materials.clear()
	for cam in cameras:
		if cam == null or not is_instance_valid(cam):
			continue
		var camera_env := source_env.duplicate(true) as Environment
		if camera_env == null:
			continue
		var dim := str(source_env.get_meta("highcraft_dimension", "overworld"))
		# Never share a Sky RID between SubViewports. On the Mobile renderer that can
		# leave the viewport clear colour (plain blue) in front of the actual sky.
		if source_env.background_mode == Environment.BG_SKY and source_env.sky != null:
			var camera_sky := Sky.new()
			var source_material := source_env.sky.sky_material
			if source_material is ShaderMaterial:
				var camera_material := ShaderMaterial.new()
				camera_material.shader = (source_material as ShaderMaterial).shader
				camera_material.set_shader_parameter("time_of_day", _safe_sky_time)
				camera_material.set_shader_parameter("rain_amount", _safe_sky_rain)
				camera_material.set_shader_parameter("thunder_flash", 0.0)
				camera_sky.sky_material = camera_material
				sky_materials.append(camera_material)
			else:
				camera_sky.sky_material = source_material.duplicate(true) if source_material != null else null
			camera_sky.process_mode = Sky.PROCESS_MODE_AUTOMATIC
			camera_env.sky = camera_sky
		cam.environment = camera_env
		cam.set_meta("split_safe_sky", false)
		cam.set_meta("highcraft_dimension", dim)


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


func _sync_viewport_size(vp: SubViewport, cont: SubViewportContainer) -> void:
	if vp == null or cont == null or not is_instance_valid(vp) or not is_instance_valid(cont):
		return
	var new_size := Vector2i(maxi(64, roundi(cont.size.x)), maxi(64, roundi(cont.size.y)))
	# Avoid reallocating render targets on duplicate resize notifications.
	# Reallocations while chunks upload were another source of grey/black frames.
	if vp.size != new_size:
		vp.size = new_size


func _layout_rects(n: int, viewport_size: Vector2 = Vector2.ZERO) -> Array:
	var w = viewport_size.x if viewport_size.x > 0.0 else float(DisplayServer.window_get_size().x)
	var h = viewport_size.y if viewport_size.y > 0.0 else float(DisplayServer.window_get_size().y)
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
	sky_materials.clear()
	input_maps.clear()
	uis.clear()


func remove_player(target: Node) -> bool:
	var index := players.find(target)
	if index < 0:
		return false
	var vp = viewports[index] if index < viewports.size() else null
	var cont = vp.get_parent() if vp != null and is_instance_valid(vp) else null
	players.remove_at(index)
	if index < viewports.size():
		viewports.remove_at(index)
	if index < cameras.size():
		cameras.remove_at(index)
	if index < uis.size():
		uis.remove_at(index)
	player_count = players.size()
	if cont != null and is_instance_valid(cont):
		cont.queue_free() # Frees this viewport, its player and its private UI.
	elif target != null and is_instance_valid(target):
		target.queue_free()
	_relayout_remaining_players()
	return true


func _relayout_remaining_players() -> void:
	if player_count <= 0:
		return
	var root_size := get_viewport().get_visible_rect().size
	var layout := _layout_rects(player_count, root_size)
	for i in range(player_count):
		var p = players[i]
		p.split_index = i
		p.set_meta("split_index", i)
		p.name = "Player%d" % (i + 1)
		p._apply_perspective()
		var vp = viewports[i]
		var cont = vp.get_parent() as SubViewportContainer
		var rect: Rect2 = layout[i]
		cont.anchor_left = rect.position.x / root_size.x
		cont.anchor_top = rect.position.y / root_size.y
		cont.anchor_right = rect.end.x / root_size.x
		cont.anchor_bottom = rect.end.y / root_size.y
		cont.offset_left = 0.0
		cont.offset_top = 0.0
		cont.offset_right = 0.0
		cont.offset_bottom = 0.0
		if i < uis.size():
			var local_ui = uis[i]
			local_ui._split_index = i
			local_ui._split_rect = rect
			var ref := Vector2(1920.0, 1080.0)
			local_ui._ui_scale = clampf(minf(rect.size.x / ref.x, rect.size.y / ref.y) * 1.2, 0.42, 0.92)
			local_ui.call_deferred("_apply_split_ui_scale")


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
