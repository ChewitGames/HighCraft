class_name AvatarEditor
extends Control
# HighCraft - Avatar / Skin Creator
# Allows the player to customize Afro Steve style character:
# Skin color, hair style, eye color, shirt, pants.
# Skins are saved as JSON in user://skins/

signal skin_saved(skin_data: Dictionary)
signal closed()

var skin_data: Dictionary = {
	"skin_color": Color(0.55, 0.35, 0.2),
	"hair_color": Color(0.08, 0.04, 0.0),
	"eye_color": Color(0.2, 0.5, 0.9),
	"shirt_color": Color(0.1, 0.55, 0.9),
	"pants_color": Color(0.15, 0.15, 0.25),
	"hair_style": 0,          # 0 = Afro, 1 = Short, 2 = Long, 3 = Bald
	"name": "Afro Steve"
}

var preview_model: Node3D
var camera: Camera3D

# UI elements
var name_edit: LineEdit
var skin_picker: ColorPickerButton
var hair_picker: ColorPickerButton
var eye_picker: ColorPickerButton
var shirt_picker: ColorPickerButton
var pants_picker: ColorPickerButton
var hair_option: OptionButton
var status_label: Label

# Controller navigation
var _ctrl_list: Array = []
var _ctrl_idx: int = 0
var _ctrl_cooldown: float = 0.0
const _CTRL_DELAY := 0.18
var _osk: OnScreenKeyboard = null
# Hair-style / option submenu (controller)
var _opt_panel: Panel = null
var _opt_buttons: Array = []
var _opt_focus: int = 0
var _opt_target: OptionButton = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process_input(true)
	_build_ui()
	_build_preview()
	_apply_to_preview()
	# Start controller focus on first control
	if not _ctrl_list.is_empty():
		_ctrl_idx = 0
		_ctrl_apply()


func _build_ui() -> void:
	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title = Label.new()
	title.text = "HighCraft Avatar Creator"
	title.add_theme_font_size_override("font_size", 32)
	title.position = Vector2(40, 20)
	add_child(title)

	# === LEFT SIDE – CONTROLS ===
	var left = VBoxContainer.new()
	left.position = Vector2(40, 80)
	left.custom_minimum_size = Vector2(320, 500)
	left.add_theme_constant_override("separation", 12)
	add_child(left)

	_ctrl_list.clear()

	# Name
	left.add_child(_make_label("Name:"))
	name_edit = LineEdit.new()
	name_edit.text = skin_data["name"]
	name_edit.focus_mode = Control.FOCUS_NONE
	name_edit.text_changed.connect(func(t): skin_data["name"] = t)
	left.add_child(name_edit)
	_ctrl_list.append(name_edit)

	# Skin Color
	left.add_child(_make_label("Skin Color:"))
	skin_picker = ColorPickerButton.new()
	skin_picker.color = skin_data["skin_color"]
	skin_picker.focus_mode = Control.FOCUS_NONE
	skin_picker.color_changed.connect(func(c):
		skin_data["skin_color"] = c
		_apply_to_preview()
	)
	left.add_child(skin_picker)
	_ctrl_list.append(skin_picker)

	# Hair Color
	left.add_child(_make_label("Hair Color:"))
	hair_picker = ColorPickerButton.new()
	hair_picker.color = skin_data["hair_color"]
	hair_picker.focus_mode = Control.FOCUS_NONE
	hair_picker.color_changed.connect(func(c):
		skin_data["hair_color"] = c
		_apply_to_preview()
	)
	left.add_child(hair_picker)
	_ctrl_list.append(hair_picker)

	# Eye Color
	left.add_child(_make_label("Eye Color:"))
	eye_picker = ColorPickerButton.new()
	eye_picker.color = skin_data["eye_color"]
	eye_picker.focus_mode = Control.FOCUS_NONE
	eye_picker.color_changed.connect(func(c):
		skin_data["eye_color"] = c
		_apply_to_preview()
	)
	left.add_child(eye_picker)
	_ctrl_list.append(eye_picker)

	# Shirt
	left.add_child(_make_label("Shirt Color:"))
	shirt_picker = ColorPickerButton.new()
	shirt_picker.color = skin_data["shirt_color"]
	shirt_picker.focus_mode = Control.FOCUS_NONE
	shirt_picker.color_changed.connect(func(c):
		skin_data["shirt_color"] = c
		_apply_to_preview()
	)
	left.add_child(shirt_picker)
	_ctrl_list.append(shirt_picker)

	# Pants
	left.add_child(_make_label("Pants Color:"))
	pants_picker = ColorPickerButton.new()
	pants_picker.color = skin_data["pants_color"]
	pants_picker.focus_mode = Control.FOCUS_NONE
	pants_picker.color_changed.connect(func(c):
		skin_data["pants_color"] = c
		_apply_to_preview()
	)
	left.add_child(pants_picker)
	_ctrl_list.append(pants_picker)

	# Hair Style
	left.add_child(_make_label("Hair Style:"))
	hair_option = OptionButton.new()
	hair_option.add_item("Afro")
	hair_option.add_item("Short")
	hair_option.add_item("Long")
	hair_option.add_item("Bald")
	hair_option.selected = skin_data["hair_style"]
	hair_option.focus_mode = Control.FOCUS_NONE  # our submenu handles controller
	hair_option.item_selected.connect(func(i):
		skin_data["hair_style"] = i
		_apply_to_preview()
	)
	left.add_child(hair_option)
	_ctrl_list.append(hair_option)

	# Buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	left.add_child(btn_row)

	var save_btn = Button.new()
	save_btn.text = "Save Skin"
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.pressed.connect(_on_save)
	btn_row.add_child(save_btn)
	_ctrl_list.append(save_btn)

	var load_btn = Button.new()
	load_btn.text = "Load Skin"
	load_btn.focus_mode = Control.FOCUS_NONE
	load_btn.pressed.connect(_on_load)
	btn_row.add_child(load_btn)
	_ctrl_list.append(load_btn)

	var export_btn = Button.new()
	export_btn.text = "Export JSON"
	export_btn.focus_mode = Control.FOCUS_NONE
	export_btn.pressed.connect(_on_export)
	btn_row.add_child(export_btn)
	_ctrl_list.append(export_btn)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func():
		closed.emit()
		queue_free()
	)
	left.add_child(close_btn)
	_ctrl_list.append(close_btn)

	status_label = Label.new()
	status_label.text = "Controller: D-Pad navigate  |  A open / confirm  |  B close"
	left.add_child(status_label)


func _make_label(txt: String) -> Label:
	var l = Label.new()
	l.text = txt
	return l


func _ctrl_apply() -> void:
	if _ctrl_list.is_empty():
		return
	_ctrl_idx = clampi(_ctrl_idx, 0, _ctrl_list.size() - 1)
	for i in range(_ctrl_list.size()):
		var c: Control = _ctrl_list[i]
		if not is_instance_valid(c):
			continue
		# Visual only — never grab_focus (would steal A / ui_accept from our handler)
		c.modulate = Color(1.4, 1.35, 0.55) if i == _ctrl_idx else Color(1, 1, 1)


func _ctrl_move(delta: int) -> void:
	if _ctrl_list.is_empty():
		return
	_ctrl_idx = posmod(_ctrl_idx + delta, _ctrl_list.size())
	_ctrl_apply()


func _ctrl_activate() -> void:
	if _ctrl_list.is_empty():
		return
	var c = _ctrl_list[_ctrl_idx]
	# Order matters: OptionButton + ColorPickerButton both extend Button in Godot 4
	if c is OptionButton:
		_open_option_menu(c as OptionButton)
	elif c is ColorPickerButton:
		var cp: ColorPickerButton = c
		var col = cp.color
		col.h = fmod(col.h + 0.08, 1.0)
		cp.color = col
		cp.color_changed.emit(col)
	elif c is Button:
		(c as Button).pressed.emit()
	elif c is LineEdit:
		_open_text_osk(c as LineEdit)


func _open_option_menu(ob: OptionButton) -> void:
	if ob == null or not is_instance_valid(ob):
		return
	_close_option_menu(false)
	_opt_target = ob
	_opt_focus = clampi(ob.selected, 0, maxi(ob.item_count - 1, 0))
	_opt_buttons.clear()

	# CanvasLayer so the menu is always visible above preview / other UI
	var layer := CanvasLayer.new()
	layer.layer = 250
	layer.name = "OptionSubmenuLayer"
	add_child(layer)

	_opt_panel = Panel.new()
	_opt_panel.name = "OptionSubmenu"
	var h := float(50 + ob.item_count * 48)
	_opt_panel.size = Vector2(300, h)
	# Center on screen
	var vp_size := get_viewport().get_visible_rect().size
	_opt_panel.position = (vp_size - _opt_panel.size) * 0.5
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.12, 0.98)
	bg.border_color = Color(0.7, 0.65, 0.3)
	bg.set_border_width_all(3)
	_opt_panel.add_theme_stylebox_override("panel", bg)
	layer.add_child(_opt_panel)
	# Keep a back-ref so close can free the layer
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
	title.text = "Select Hair Style"
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
	if has_node("/root/Audio") or Engine.has_singleton("Audio"):
		pass
	# Soft click if Audio autoload exists
	if is_instance_valid(get_tree().root.get_node_or_null("Audio")):
		get_tree().root.get_node("Audio").play("click", -12.0)


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
		_opt_target.selected = idx
		_opt_target.item_selected.emit(idx)
	_close_option_menu(true)


func _close_option_menu(_selected: bool = false) -> void:
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


func _option_menu_open() -> bool:
	return _opt_panel != null and is_instance_valid(_opt_panel)


func _open_text_osk(edit: LineEdit) -> void:
	if edit == null or not is_instance_valid(edit):
		return
	if _osk != null and is_instance_valid(_osk):
		_osk.close(false)
		_osk = null
	_osk = OnScreenKeyboard.new()
	add_child(_osk)
	_osk.done.connect(func(_t): _osk = null)
	_osk.cancelled.connect(func(): _osk = null)
	_osk.open(edit)


func _input(event: InputEvent) -> void:
	# While OSK is open it handles controller itself
	if _osk != null and is_instance_valid(_osk) and _osk.is_open():
		return

	if _ctrl_cooldown > 0.0:
		_ctrl_cooldown -= get_process_delta_time()

	# --- Hair style / option submenu ---
	if _option_menu_open():
		if event is InputEventJoypadMotion and _ctrl_cooldown <= 0.0:
			if event.axis == 1 and absf(event.axis_value) > 0.5:
				_opt_move(1 if event.axis_value > 0.0 else -1)
				_ctrl_cooldown = _CTRL_DELAY
				if get_viewport(): get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadButton and event.pressed:
			var obtn: int = event.button_index
			if obtn == JOY_BUTTON_DPAD_UP or obtn == 11:
				_opt_move(-1)
			elif obtn == JOY_BUTTON_DPAD_DOWN or obtn == 12:
				_opt_move(1)
			elif obtn == JOY_BUTTON_A or obtn == 0:
				_pick_option(_opt_focus)
			elif obtn == JOY_BUTTON_B or obtn == 1:
				_close_option_menu(false)
			else:
				return
			if get_viewport(): get_viewport().set_input_as_handled()
		return

	if event is InputEventJoypadMotion:
		if _ctrl_cooldown <= 0.0 and absf(event.axis_value) > 0.5 and event.axis == 1:
			_ctrl_move(1 if event.axis_value > 0.0 else -1)
			_ctrl_cooldown = _CTRL_DELAY
			if is_inside_tree() and get_viewport() != null:
				get_viewport().set_input_as_handled()
		return

	if not (event is InputEventJoypadButton and event.pressed):
		return

	var btn: int = event.button_index
	if btn == JOY_BUTTON_DPAD_UP or btn == 11:
		_ctrl_move(-1)
	elif btn == JOY_BUTTON_DPAD_DOWN or btn == 12:
		_ctrl_move(1)
	elif btn == JOY_BUTTON_A or btn == 0:
		_ctrl_activate()
	elif btn == JOY_BUTTON_B or btn == 1:
		closed.emit()
		queue_free()
	else:
		return
	if is_inside_tree() and get_viewport() != null:
		get_viewport().set_input_as_handled()


func _build_preview() -> void:
	# Simple 3D preview viewport
	var vp_container = SubViewportContainer.new()
	vp_container.position = Vector2(420, 80)
	vp_container.custom_minimum_size = Vector2(500, 500)
	vp_container.stretch = true
	add_child(vp_container)

	var vp = SubViewport.new()
	vp.size = Vector2i(500, 500)
	vp.transparent_bg = true
	vp_container.add_child(vp)

	var world = Node3D.new()
	vp.add_child(world)

	# Light
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	world.add_child(light)

	# Camera
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.4, 3.5)
	camera.look_at(Vector3(0, 1.2, 0))
	world.add_child(camera)

	# Preview model root
	preview_model = Node3D.new()
	preview_model.name = "PreviewModel"
	world.add_child(preview_model)


func _apply_to_preview() -> void:
	if preview_model == null:
		return

	# Clear old meshes
	for c in preview_model.get_children():
		c.queue_free()

	var skin = skin_data["skin_color"]
	var hair = skin_data["hair_color"]
	var eyes = skin_data["eye_color"]
	var shirt = skin_data["shirt_color"]
	var pants = skin_data["pants_color"]
	var style = int(skin_data["hair_style"])

	# Head
	_add_box(preview_model, Vector3(0.55, 0.55, 0.55), Vector3(0, 1.75, 0), skin)

	# Eyes
	_add_box(preview_model, Vector3(0.12, 0.08, 0.05), Vector3(-0.12, 1.8, 0.28), eyes)
	_add_box(preview_model, Vector3(0.12, 0.08, 0.05), Vector3(0.12, 1.8, 0.28), eyes)

	# Hair
	match style:
		0: # Afro
			_add_sphere(preview_model, 0.42, Vector3(0, 2.05, 0), hair)
		1: # Short
			_add_box(preview_model, Vector3(0.58, 0.18, 0.58), Vector3(0, 2.05, 0), hair)
		2: # Long
			_add_box(preview_model, Vector3(0.58, 0.35, 0.58), Vector3(0, 2.1, 0), hair)
			_add_box(preview_model, Vector3(0.5, 0.6, 0.25), Vector3(0, 1.6, -0.35), hair)
		3: # Bald
			pass

	# Body (shirt)
	_add_box(preview_model, Vector3(0.55, 0.85, 0.3), Vector3(0, 1.1, 0), shirt)

	# Arms
	_add_box(preview_model, Vector3(0.22, 0.75, 0.22), Vector3(-0.42, 1.1, 0), skin)
	_add_box(preview_model, Vector3(0.22, 0.75, 0.22), Vector3(0.42, 1.1, 0), skin)

	# Legs (pants)
	_add_box(preview_model, Vector3(0.26, 0.85, 0.26), Vector3(-0.18, 0.45, 0), pants)
	_add_box(preview_model, Vector3(0.26, 0.85, 0.26), Vector3(0.18, 0.45, 0), pants)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> void:
	var mi = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _add_sphere(parent: Node3D, radius: float, pos: Vector3, col: Color) -> void:
	var mi = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.3
	mi.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _on_save() -> void:
	var path = "user://skins/" + skin_data["name"].replace(" ", "_").to_lower() + ".json"
	DirAccess.make_dir_recursive_absolute("user://skins")
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		# Convert Colors to arrays for JSON
		var data = {
			"name": skin_data["name"],
			"skin_color": [skin_data["skin_color"].r, skin_data["skin_color"].g, skin_data["skin_color"].b],
			"hair_color": [skin_data["hair_color"].r, skin_data["hair_color"].g, skin_data["hair_color"].b],
			"eye_color": [skin_data["eye_color"].r, skin_data["eye_color"].g, skin_data["eye_color"].b],
			"shirt_color": [skin_data["shirt_color"].r, skin_data["shirt_color"].g, skin_data["shirt_color"].b],
			"pants_color": [skin_data["pants_color"].r, skin_data["pants_color"].g, skin_data["pants_color"].b],
			"hair_style": skin_data["hair_style"]
		}
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
		status_label.text = "Saved: " + path
		skin_saved.emit(skin_data)
	else:
		status_label.text = "Save failed!"


func _on_load() -> void:
	# Simple load of last saved or default
	var path = "user://skins/" + skin_data["name"].replace(" ", "_").to_lower() + ".json"
	if not FileAccess.file_exists(path):
		status_label.text = "No skin found with that name"
		return
	var f = FileAccess.open(path, FileAccess.READ)
	if f:
		var json = JSON.new()
		if json.parse(f.get_as_text()) == OK:
			var d = json.data
			skin_data["name"] = d.get("name", "Afro Steve")
			skin_data["skin_color"] = Color(d["skin_color"][0], d["skin_color"][1], d["skin_color"][2])
			skin_data["hair_color"] = Color(d["hair_color"][0], d["hair_color"][1], d["hair_color"][2])
			skin_data["eye_color"] = Color(d["eye_color"][0], d["eye_color"][1], d["eye_color"][2])
			skin_data["shirt_color"] = Color(d["shirt_color"][0], d["shirt_color"][1], d["shirt_color"][2])
			skin_data["pants_color"] = Color(d["pants_color"][0], d["pants_color"][1], d["pants_color"][2])
			skin_data["hair_style"] = int(d.get("hair_style", 0))
			name_edit.text = skin_data["name"]
			skin_picker.color = skin_data["skin_color"]
			hair_picker.color = skin_data["hair_color"]
			eye_picker.color = skin_data["eye_color"]
			shirt_picker.color = skin_data["shirt_color"]
			pants_picker.color = skin_data["pants_color"]
			hair_option.selected = skin_data["hair_style"]
			_apply_to_preview()
			status_label.text = "Loaded!"
		f.close()


func _on_export() -> void:
	_on_save()
	status_label.text = "Exported to user://skins/"
