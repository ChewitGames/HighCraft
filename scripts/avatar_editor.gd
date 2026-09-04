class_name AvatarEditor
extends Control

const Catalog = preload("res://scripts/avatar_catalog.gd")
const PixelCanvas = preload("res://scripts/ui/avatar_pixel_canvas.gd")

signal skin_saved(skin_data: Dictionary)
signal closed()

const CTRL_DELAY := 0.16
const COLOR_KEYS := ["skin_color", "hair_color", "eye_color", "shirt_color", "pants_color", "cape_color", "hood_color", "cap_color", "pixel_color"]
var skin_data := Catalog.defaults()
var preview_model: Node3D
var name_edit: LineEdit
var status_label: Label
var controls: Array[Control] = []
var control_index := 0
var cooldown := 0.0
var option_panel: Panel
var option_scroll: ScrollContainer
var option_target: OptionButton
var option_buttons: Array[Button] = []
var option_index := 0
var color_panel: Panel
var color_target := ""
var color_sliders: Array[HSlider] = []
var color_index := 0
var pixel_panel: Panel
var pixel_canvas: Control
var osk: OnScreenKeyboard
var active_joy_device := 0
var main_scroll: ScrollContainer
var preview_dragging := false
var preview_last_mouse := Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process_input(true)
	set_process(true)
	_build_ui()
	_build_preview()
	_refresh_preview()
	_apply_focus()

func _build_ui() -> void:
	var bg := ColorRect.new(); bg.color = Color(0.055, 0.065, 0.09, 0.98); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var title := Label.new(); title.text = "HighCraft Character & Skin Creator"; title.add_theme_font_size_override("font_size", 28); title.position = Vector2(28, 14); add_child(title)
	main_scroll = ScrollContainer.new(); main_scroll.position = Vector2(24, 58); main_scroll.size = Vector2(450, 610); main_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; add_child(main_scroll)
	var box := VBoxContainer.new(); box.custom_minimum_size = Vector2(420, 0); box.add_theme_constant_override("separation", 7); main_scroll.add_child(box)
	controls.clear()
	_add_name(box)
	_add_option(box, "Gender / body", "gender", Catalog.GENDERS)
	_add_option(box, "Age", "age", Catalog.AGES)
	_add_option(box, "Body build", "build", Catalog.BUILDS)
	_add_option(box, "Female chest size", "chest_size", Catalog.CHEST_SIZES)
	_add_option(box, "Hair (shared by everyone)", "hair_style", Catalog.HAIRS)
	_add_option(box, "Clothes (shared by everyone)", "outfit_style", Catalog.OUTFITS)
	_add_option(box, "Cape", "cape_style", Catalog.CAPES)
	_add_option(box, "Hood", "hood_style", Catalog.HOODS)
	_add_option(box, "Cap / hat", "cap_style", Catalog.CAPS)
	_add_option(box, "Beard (male body)", "beard_style", Catalog.BEARDS)
	_add_option(box, "Glasses", "glasses_style", Catalog.GLASSES)
	_add_option(box, "Mouth line", "mouth_style", Catalog.MOUTHS)
	for pair in [["Skin", "skin_color"], ["Hair", "hair_color"], ["Eyes", "eye_color"], ["Clothes", "shirt_color"], ["Pants", "pants_color"], ["Cape", "cape_color"], ["Hood", "hood_color"], ["Cap", "cap_color"]]:
		_add_color(box, pair[0], pair[1])
	_add_button(box, "Pixel painting editor", _open_pixel_editor)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); box.add_child(row)
	var save_button := _add_button(row, "Save", _on_save)
	var load_button := _add_button(row, "Load", _on_load)
	var export_button := _add_button(row, "Export JSON", _on_export)
	for button in [save_button, load_button, export_button]: button.set_meta("horizontal_group", "file_actions")
	_add_button(box, "Close", _close_editor)
	status_label = Label.new(); status_label.text = "Navigate: left stick/D-Pad | A select | B close | Rotate: right stick or mouse drag"; status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(status_label)

func _add_name(parent: Container) -> void:
	parent.add_child(_label("Name")); name_edit = LineEdit.new(); name_edit.text = skin_data.name; name_edit.focus_mode = Control.FOCUS_CLICK
	name_edit.text_changed.connect(func(value: String): skin_data.name = value); parent.add_child(name_edit); controls.append(name_edit)

func _add_option(parent: Container, caption: String, key: String, values: Array) -> void:
	parent.add_child(_label(caption)); var option := OptionButton.new(); option.focus_mode = Control.FOCUS_NONE; option.set_meta("data_key", key); option.set_meta("caption", caption)
	for value in values: option.add_item(str(value))
	option.selected = clampi(int(skin_data.get(key, 0)), 0, option.item_count - 1)
	option.item_selected.connect(func(index: int): skin_data[key] = index; _refresh_preview())
	parent.add_child(option); controls.append(option)

func _add_color(parent: Container, caption: String, key: String) -> void:
	var button := Button.new(); button.text = caption + " color"; button.focus_mode = Control.FOCUS_NONE; button.set_meta("color_key", key); button.set_meta("base_caption", button.text); button.modulate = skin_data[key]
	button.pressed.connect(_open_color_editor.bind(key, caption)); parent.add_child(button); controls.append(button)

func _add_button(parent: Container, caption: String, callback: Callable) -> Button:
	var button := Button.new(); button.text = caption; button.set_meta("base_caption", caption); button.focus_mode = Control.FOCUS_NONE; button.pressed.connect(callback); parent.add_child(button); controls.append(button); return button

func _label(value: String) -> Label:
	var result := Label.new(); result.text = value; return result

func _build_preview() -> void:
	var container := SubViewportContainer.new(); container.position = Vector2(500, 75); container.size = Vector2(740, 575); container.stretch = true; add_child(container)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_preview_mouse_input)
	var viewport := SubViewport.new(); viewport.size = Vector2i(740, 575); viewport.transparent_bg = true; container.add_child(viewport)
	var world := Node3D.new(); viewport.add_child(world)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-45, 35, 0); light.light_energy = 1.4; world.add_child(light)
	var camera := Camera3D.new(); camera.position = Vector3(0, 1.35, 3.4); camera.look_at(Vector3(0, 1.15, 0)); world.add_child(camera)
	preview_model = Node3D.new(); preview_model.name = "PreviewModel"; world.add_child(preview_model)
	# Runtime avatars face -Z. Rotate only the preview so its front faces the +Z camera.
	preview_model.rotation_degrees.y = 180.0

func _refresh_preview() -> void:
	if preview_model == null: return
	for child in preview_model.get_children(): child.free()
	AvatarLoader.populate_model(preview_model, skin_data, true)
	for control in controls:
		if control.has_meta("color_key"):
			control.modulate = Color.WHITE if control == controls[control_index] else skin_data[control.get_meta("color_key")]

func _apply_focus() -> void:
	if controls.is_empty(): return
	control_index = clampi(control_index, 0, controls.size() - 1)
	for i in range(controls.size()):
		var control := controls[i]
		var selected := i == control_index
		control.self_modulate = Color.WHITE
		if selected:
			var focus_style := StyleBoxFlat.new()
			focus_style.bg_color = Color(0.28, 0.22, 0.045, 1.0)
			focus_style.border_color = Color(1.0, 0.82, 0.12, 1.0)
			focus_style.set_border_width_all(4)
			focus_style.set_corner_radius_all(5)
			control.add_theme_stylebox_override("normal", focus_style)
		else:
			control.remove_theme_stylebox_override("normal")
		if control.has_meta("color_key"):
			# Never multiply the focus highlight by a dark chosen color.
			control.modulate = Color.WHITE if selected else skin_data[control.get_meta("color_key")]
		if control is Button and not control is OptionButton and control.has_meta("base_caption"):
			(control as Button).text = (">  " if selected else "") + str(control.get_meta("base_caption"))
	var current := controls[control_index]
	if main_scroll:
		# Works for nested controls too (Save/Load/Export live inside an HBox).
		main_scroll.call_deferred("ensure_control_visible", current)

func _move_focus(delta: int) -> void:
	control_index = posmod(control_index + delta, controls.size()); _apply_focus()

func _move_horizontal_focus(delta: int) -> bool:
	if controls.is_empty() or not controls[control_index].has_meta("horizontal_group"): return false
	var group = controls[control_index].get_meta("horizontal_group")
	var group_indices: Array[int] = []
	for i in range(controls.size()):
		if controls[i].get_meta("horizontal_group", null) == group: group_indices.append(i)
	if group_indices.is_empty(): return false
	var position := group_indices.find(control_index)
	if position < 0: return false
	control_index = group_indices[posmod(position + delta, group_indices.size())]
	_apply_focus()
	return true

func _activate() -> void:
	var current := controls[control_index]
	if current is OptionButton: _open_option(current)
	elif current is LineEdit: _open_osk(current)
	elif current is Button: (current as Button).pressed.emit()

func _open_option(target: OptionButton) -> void:
	_close_option()
	option_target = target; option_index = target.selected; option_buttons.clear()
	var overlay := _create_modal_overlay(1000)
	option_panel = Panel.new(); option_panel.size = Vector2(400, minf(600.0, 105.0 + target.item_count * 38.0)); option_panel.position = (get_viewport_rect().size - option_panel.size) * 0.5; option_panel.set_meta("overlay", overlay); overlay.add_child(option_panel)
	option_scroll = ScrollContainer.new(); option_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); option_panel.add_child(option_scroll)
	var box := VBoxContainer.new(); box.custom_minimum_size.x = 370; option_scroll.add_child(box)
	var title := _label("Select " + str(target.get_meta("caption", "option"))); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(title)
	for i in range(target.item_count):
		var button := Button.new(); button.text = target.get_item_text(i); button.focus_mode = Control.FOCUS_NONE; button.pressed.connect(_pick_option.bind(i)); box.add_child(button); option_buttons.append(button)
	_apply_option_focus()

func _apply_option_focus() -> void:
	option_index = clampi(option_index, 0, option_buttons.size() - 1)
	for i in range(option_buttons.size()): option_buttons[i].modulate = Color(1.45, 1.3, 0.45) if i == option_index else Color.WHITE
	if option_scroll: option_scroll.scroll_vertical = maxi(0, option_index * 38 - 220)

func _pick_option(index: int) -> void:
	option_target.selected = index; option_target.item_selected.emit(index); _close_option()

func _close_option() -> void:
	if option_panel and is_instance_valid(option_panel):
		var overlay = option_panel.get_meta("overlay", null)
		if overlay and is_instance_valid(overlay): overlay.queue_free()
	option_panel = null; option_scroll = null; option_target = null; option_buttons.clear()

func _open_color_editor(key: String, caption: String) -> void:
	_close_color()
	color_target = key; color_index = 0; color_sliders.clear()
	var overlay := _create_modal_overlay(1200)
	color_panel = Panel.new(); color_panel.size = Vector2(480, 300); color_panel.position = (get_viewport_rect().size - color_panel.size) * 0.5; color_panel.set_meta("overlay", overlay); overlay.add_child(color_panel)
	var box := VBoxContainer.new(); box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); box.offset_left = 24; box.offset_right = -24; box.offset_top = 18; box.offset_bottom = -18; color_panel.add_child(box)
	box.add_child(_label(caption + " color — left/right changes the selected slider"))
	var color: Color = skin_data[key]
	for entry in [["Hue", color.h], ["Saturation", color.s], ["Brightness", color.v]]:
		box.add_child(_label(entry[0])); var slider := HSlider.new(); slider.min_value = 0; slider.max_value = 1; slider.step = 0.01; slider.value = entry[1]; slider.focus_mode = Control.FOCUS_NONE; slider.value_changed.connect(_color_changed); box.add_child(slider); color_sliders.append(slider)
	box.add_child(_label("Controller: up/down slider | left/right value | A/B finish")); _apply_color_focus()

func _apply_color_focus() -> void:
	for i in range(color_sliders.size()): color_sliders[i].modulate = Color(1.45, 1.3, 0.45) if i == color_index else Color.WHITE

func _color_changed(_value: float) -> void:
	if color_sliders.size() != 3: return
	skin_data[color_target] = Color.from_hsv(color_sliders[0].value, color_sliders[1].value, color_sliders[2].value); _refresh_preview()

func _close_color() -> void:
	if color_panel and is_instance_valid(color_panel):
		var overlay = color_panel.get_meta("overlay", null)
		if overlay and is_instance_valid(overlay): overlay.queue_free()
	color_panel = null; color_sliders.clear(); color_target = ""

func _open_pixel_editor() -> void:
	_close_pixel_editor()
	var overlay := _create_modal_overlay(1100)
	pixel_panel = Panel.new(); pixel_panel.position = Vector2(24, 70); pixel_panel.size = Vector2(460, 580); pixel_panel.set_meta("overlay", overlay); overlay.add_child(pixel_panel)
	var box := VBoxContainer.new(); box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); box.offset_left = 6; box.offset_right = -6; box.offset_top = 6; box.offset_bottom = -6; pixel_panel.add_child(box)
	box.add_child(_label("Pixel painting — right stick rotates the 3D skin"))
	pixel_canvas = PixelCanvas.new(); pixel_canvas.set_pixels(skin_data.pixels); pixel_canvas.paint_color = skin_data.pixel_color; pixel_canvas.changed.connect(func(value: Array): skin_data.pixels = value.duplicate(true); _refresh_preview()); box.add_child(pixel_canvas)
	var color_button := Button.new(); color_button.text = "Paint color (controller sliders)"; color_button.focus_mode = Control.FOCUS_NONE; color_button.pressed.connect(_open_color_editor.bind("pixel_color", "Paint")); box.add_child(color_button)
	box.add_child(_label("Left stick: cursor | A: paint | X: reset | B: finish | Right stick: rotate"))

func _close_pixel_editor() -> void:
	if pixel_panel and is_instance_valid(pixel_panel):
		var overlay = pixel_panel.get_meta("overlay", null)
		if overlay and is_instance_valid(overlay): overlay.queue_free()
	pixel_panel = null; pixel_canvas = null

func _create_modal_overlay(order: int) -> Control:
	var overlay := Control.new()
	overlay.name = "AvatarModalOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = order
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.025, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	add_child(overlay)
	return overlay

func _open_osk(edit: LineEdit) -> void:
	osk = OnScreenKeyboard.new(); add_child(osk); osk.done.connect(func(_value): osk = null); osk.cancelled.connect(func(): osk = null); osk.open(edit)

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	var rotate := Vector2(Input.get_joy_axis(active_joy_device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(active_joy_device, JOY_AXIS_RIGHT_Y))
	if rotate.length() > 0.2 and preview_model: preview_model.rotation_degrees += Vector3(rotate.y * 85.0 * delta, rotate.x * 110.0 * delta, 0)

func _on_preview_mouse_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		preview_dragging = event.pressed
		preview_last_mouse = event.position
		mouse_default_cursor_shape = Control.CURSOR_DRAG if preview_dragging else Control.CURSOR_ARROW
	elif event is InputEventMouseMotion and preview_dragging and preview_model:
		var movement = event.position - preview_last_mouse
		preview_last_mouse = event.position
		preview_model.rotation_degrees += Vector3(movement.y * 0.35, movement.x * 0.45, 0)

func _input(event: InputEvent) -> void:
	if osk and is_instance_valid(osk) and osk.is_open(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if color_panel and is_instance_valid(color_panel):
			_handle_color_keyboard(event)
			return
		if pixel_panel and is_instance_valid(pixel_panel):
			_handle_pixel_keyboard(event)
			return
		if option_panel and is_instance_valid(option_panel) and event.keycode == KEY_ESCAPE:
			_close_option(); get_viewport().set_input_as_handled(); return
		if event.keycode == KEY_ESCAPE:
			if name_edit and name_edit.has_focus(): name_edit.release_focus()
			_close_editor()
			get_viewport().set_input_as_handled()
			return
	if not _is_controller_event(event): return
	active_joy_device = maxi(event.device, 0)
	if color_panel and is_instance_valid(color_panel): _handle_color_input(event); return
	if pixel_panel and is_instance_valid(pixel_panel): _handle_pixel_input(event); return
	if option_panel and is_instance_valid(option_panel): _handle_option_input(event); return
	_handle_main_input(event)

func _is_controller_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion

func _axis_step(event: InputEvent, axis: int) -> int:
	if event is InputEventJoypadMotion and event.axis == axis and absf(event.axis_value) > 0.55 and cooldown <= 0.0:
		cooldown = CTRL_DELAY; return 1 if event.axis_value > 0 else -1
	return 0

func _button(event: InputEvent, index: int) -> bool:
	return event is InputEventJoypadButton and event.pressed and event.button_index == index

func _handle_main_input(event: InputEvent) -> void:
	var step := _axis_step(event, JOY_AXIS_LEFT_Y)
	var horizontal := _axis_step(event, JOY_AXIS_LEFT_X)
	if step != 0: _move_focus(step)
	elif horizontal != 0 and _move_horizontal_focus(horizontal): pass
	elif _button(event, JOY_BUTTON_DPAD_UP): _move_focus(-1)
	elif _button(event, JOY_BUTTON_DPAD_DOWN): _move_focus(1)
	elif _button(event, JOY_BUTTON_DPAD_LEFT) and _move_horizontal_focus(-1): pass
	elif _button(event, JOY_BUTTON_DPAD_RIGHT) and _move_horizontal_focus(1): pass
	elif _button(event, JOY_BUTTON_A): _activate()
	elif _button(event, JOY_BUTTON_B): _close_editor()
	else: return
	get_viewport().set_input_as_handled()

func _handle_option_input(event: InputEvent) -> void:
	var step := _axis_step(event, JOY_AXIS_LEFT_Y)
	if step != 0: option_index = posmod(option_index + step, option_buttons.size()); _apply_option_focus()
	elif _button(event, JOY_BUTTON_DPAD_UP): option_index = posmod(option_index - 1, option_buttons.size()); _apply_option_focus()
	elif _button(event, JOY_BUTTON_DPAD_DOWN): option_index = posmod(option_index + 1, option_buttons.size()); _apply_option_focus()
	elif _button(event, JOY_BUTTON_A): _pick_option(option_index)
	elif _button(event, JOY_BUTTON_B): _close_option()
	else: return
	get_viewport().set_input_as_handled()

func _handle_color_input(event: InputEvent) -> void:
	var vertical := _axis_step(event, JOY_AXIS_LEFT_Y); var horizontal := _axis_step(event, JOY_AXIS_LEFT_X)
	if vertical != 0: color_index = posmod(color_index + vertical, 3); _apply_color_focus()
	elif horizontal != 0: color_sliders[color_index].value = clampf(color_sliders[color_index].value + horizontal * 0.025, 0, 1)
	elif _button(event, JOY_BUTTON_DPAD_UP): color_index = posmod(color_index - 1, 3); _apply_color_focus()
	elif _button(event, JOY_BUTTON_DPAD_DOWN): color_index = posmod(color_index + 1, 3); _apply_color_focus()
	elif _button(event, JOY_BUTTON_DPAD_LEFT): color_sliders[color_index].value = maxf(0, color_sliders[color_index].value - 0.025)
	elif _button(event, JOY_BUTTON_DPAD_RIGHT): color_sliders[color_index].value = minf(1, color_sliders[color_index].value + 0.025)
	elif _button(event, JOY_BUTTON_A) or _button(event, JOY_BUTTON_B):
		_close_color()
		if pixel_canvas: pixel_canvas.paint_color = skin_data.pixel_color
	else: return
	get_viewport().set_input_as_handled()

func _handle_pixel_input(event: InputEvent) -> void:
	var x := _axis_step(event, JOY_AXIS_LEFT_X); var y := _axis_step(event, JOY_AXIS_LEFT_Y)
	if x != 0: pixel_canvas.move_cursor(Vector2i(x, 0))
	elif y != 0: pixel_canvas.move_cursor(Vector2i(0, y))
	elif _button(event, JOY_BUTTON_DPAD_LEFT): pixel_canvas.move_cursor(Vector2i.LEFT)
	elif _button(event, JOY_BUTTON_DPAD_RIGHT): pixel_canvas.move_cursor(Vector2i.RIGHT)
	elif _button(event, JOY_BUTTON_DPAD_UP): pixel_canvas.move_cursor(Vector2i.UP)
	elif _button(event, JOY_BUTTON_DPAD_DOWN): pixel_canvas.move_cursor(Vector2i.DOWN)
	elif _button(event, JOY_BUTTON_A): pixel_canvas.paint_cursor()
	elif _button(event, JOY_BUTTON_X): pixel_canvas.reset_pixels()
	elif _button(event, JOY_BUTTON_Y): _open_color_editor("pixel_color", "Paint")
	elif _button(event, JOY_BUTTON_B): _close_pixel_editor()
	else: return
	get_viewport().set_input_as_handled()

func _handle_pixel_keyboard(event: InputEventKey) -> void:
	match event.keycode:
		KEY_ESCAPE, KEY_B:
			_close_pixel_editor()
		KEY_X:
			pixel_canvas.reset_pixels()
		KEY_LEFT:
			pixel_canvas.move_cursor(Vector2i.LEFT)
		KEY_RIGHT:
			pixel_canvas.move_cursor(Vector2i.RIGHT)
		KEY_UP:
			pixel_canvas.move_cursor(Vector2i.UP)
		KEY_DOWN:
			pixel_canvas.move_cursor(Vector2i.DOWN)
		KEY_SPACE, KEY_ENTER:
			pixel_canvas.paint_cursor()
		KEY_Y, KEY_C:
			_open_color_editor("pixel_color", "Paint")
		_:
			return
	get_viewport().set_input_as_handled()

func _handle_color_keyboard(event: InputEventKey) -> void:
	match event.keycode:
		KEY_ESCAPE, KEY_B, KEY_ENTER:
			_close_color()
			if pixel_canvas: pixel_canvas.paint_color = skin_data.pixel_color
		KEY_UP:
			color_index = posmod(color_index - 1, 3); _apply_color_focus()
		KEY_DOWN:
			color_index = posmod(color_index + 1, 3); _apply_color_focus()
		KEY_LEFT:
			color_sliders[color_index].value = maxf(0, color_sliders[color_index].value - 0.025)
		KEY_RIGHT:
			color_sliders[color_index].value = minf(1, color_sliders[color_index].value + 0.025)
		_:
			return
	get_viewport().set_input_as_handled()

func _serialize() -> Dictionary:
	var data := skin_data.duplicate(true)
	for key in COLOR_KEYS:
		var color: Color = data[key]; data[key] = [color.r, color.g, color.b, color.a]
	return data

func _on_save() -> void:
	DirAccess.make_dir_recursive_absolute("user://skins")
	var path := "user://skins/" + str(skin_data.name).replace(" ", "_").to_lower() + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(_serialize(), "\t")); file.close(); status_label.text = "Saved: " + path; skin_saved.emit(skin_data)
	else: status_label.text = "Save failed"

func _on_load() -> void:
	skin_data = AvatarLoader.load_skin(str(skin_data.name)); name_edit.text = skin_data.name; _sync_options(); _refresh_preview(); status_label.text = "Loaded"

func _sync_options() -> void:
	for control in controls:
		if control is OptionButton: control.selected = int(skin_data.get(control.get_meta("data_key"), 0))

func _on_export() -> void:
	_on_save(); status_label.text = "Exported to user://skins/"

func _close_editor() -> void:
	closed.emit(); queue_free()
