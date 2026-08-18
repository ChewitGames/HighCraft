class_name OnScreenKeyboard
extends CanvasLayer
# Reusable controller on-screen keyboard for LineEdit fields.
# Desktop often has no OS virtual keyboard — this fills the gap.

signal done(text: String)
signal cancelled()

var target: LineEdit = null
var owner_device: int = -1  # -1 = any (solo/P1 keyboard); >=0 = that joypad only
var _keys: Array = []
var _focus: int = 0
var _shift: bool = false
var _panel: Panel = null
var _preview: Label = null
var _ignore_focus: bool = false
var _nav_cd: float = 0.0
const NAV_DELAY := 0.16


func open(edit: LineEdit) -> void:
	if edit == null or not is_instance_valid(edit):
		return
	if is_instance_valid(_panel):
		close(false)
	target = edit
	_shift = false
	_focus = 0
	layer = 200
	_ignore_focus = true
	_build()
	_ignore_focus = false
	set_process(true)
	set_process_input(true)


func close(submit: bool = true) -> void:
	var text := ""
	if target != null and is_instance_valid(target):
		text = target.text
		_ignore_focus = true
		if target.has_focus():
			target.release_focus()
		_ignore_focus = false
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	_keys.clear()
	_preview = null
	target = null
	set_process(false)
	set_process_input(false)
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	if submit:
		done.emit(text)
	else:
		cancelled.emit()
	queue_free()


func is_open() -> bool:
	return _panel != null and is_instance_valid(_panel)


func _build() -> void:
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -290
	_panel.offset_bottom = 0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.07, 0.1, 0.97)
	bg.border_color = Color(0.45, 0.45, 0.5)
	bg.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", bg)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 10
	root.offset_top = 8
	root.offset_right = -10
	root.offset_bottom = -8
	root.add_theme_constant_override("separation", 5)
	_panel.add_child(root)

	_preview = Label.new()
	_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview.add_theme_font_size_override("font_size", 18)
	_update_preview()
	root.add_child(_preview)

	var hint := Label.new()
	hint.text = "D-Pad move | A type | X space | Y shift | B backspace | Start done"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)

	_keys.clear()
	var rows: Array = [
		["1","2","3","4","5","6","7","8","9","0"],
		["q","w","e","r","t","y","u","i","o","p"],
		["a","s","d","f","g","h","j","k","l","/"],
		["z","x","c","v","b","n","m",".","_","-"],
		["SPACE","SHIFT","BACK","CLEAR","DONE"]
	]
	for row in rows:
		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 4)
		root.add_child(hb)
		for key in row:
			var b := Button.new()
			b.text = str(key)
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(52 if str(key).length() <= 1 else 88, 34)
			b.set_meta("osk_key", str(key))
			b.pressed.connect(_press.bind(str(key)))
			hb.add_child(b)
			_keys.append(b)
	_apply_focus()


func _update_preview() -> void:
	if _preview == null:
		return
	if target != null and is_instance_valid(target) and target.text != "":
		_preview.text = target.text
	else:
		_preview.text = "…"


func _apply_focus() -> void:
	if _keys.is_empty():
		return
	_focus = clampi(_focus, 0, _keys.size() - 1)
	for i in range(_keys.size()):
		var b: Control = _keys[i]
		if is_instance_valid(b):
			b.modulate = Color(1.45, 1.35, 0.5) if i == _focus else Color(1, 1, 1)


func _move(dx: int, dy: int) -> void:
	if _keys.is_empty():
		return
	var idx := _focus
	if dy != 0:
		if idx < 40:
			var col := idx % 10
			var row := clampi(int(idx / 10) + dy, 0, 4)
			if row < 4:
				idx = row * 10 + col
			else:
				idx = 40 + clampi(int(col / 2), 0, 4)
		elif dy < 0:
			idx = 30 + clampi((_focus - 40) * 2, 0, 9)
	if dx != 0:
		if idx < 40:
			var row2 := int(idx / 10)
			idx = row2 * 10 + posmod(idx % 10 + dx, 10)
		else:
			idx = 40 + posmod((_focus - 40) + dx, 5)
	_focus = clampi(idx, 0, _keys.size() - 1)
	_apply_focus()


func _press(key: String) -> void:
	if target == null or not is_instance_valid(target):
		close(false)
		return
	match key:
		"SPACE":
			target.text += " "
		"SHIFT":
			_shift = not _shift
			for b in _keys:
				if not is_instance_valid(b):
					continue
				var k := str(b.get_meta("osk_key", ""))
				if k.length() == 1 and k >= "a" and k <= "z":
					b.text = k.to_upper() if _shift else k
			return
		"BACK":
			if target.text.length() > 0:
				target.text = target.text.substr(0, target.text.length() - 1)
		"CLEAR":
			target.text = ""
		"DONE":
			close(true)
			return
		_:
			var ch := key
			if _shift:
				ch = ch.to_upper()
			target.text += ch
	target.caret_column = target.text.length()
	target.text_changed.emit(target.text)
	_update_preview()


func _process(delta: float) -> void:
	if _nav_cd > 0.0:
		_nav_cd -= delta


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	# Split-screen: only the player who opened the keyboard may type
	if owner_device >= 0 and event is InputEventJoypadButton:
		if int(event.device) != owner_device:
			return
	if owner_device >= 0 and event is InputEventJoypadMotion:
		if int(event.device) != owner_device:
			return
	if event is InputEventJoypadMotion and _nav_cd <= 0.0:
		var ax: int = event.axis
		var val: float = event.axis_value
		if absf(val) > 0.5:
			if ax == 0:
				_move(1 if val > 0.0 else -1, 0)
			elif ax == 1:
				_move(0, 1 if val > 0.0 else -1)
			_nav_cd = NAV_DELAY
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventJoypadButton and event.pressed):
		return
	var btn: int = event.button_index
	if btn == JOY_BUTTON_DPAD_UP or btn == 11:
		_move(0, -1)
	elif btn == JOY_BUTTON_DPAD_DOWN or btn == 12:
		_move(0, 1)
	elif btn == JOY_BUTTON_DPAD_LEFT or btn == 13:
		_move(-1, 0)
	elif btn == JOY_BUTTON_DPAD_RIGHT or btn == 14:
		_move(1, 0)
	elif btn == JOY_BUTTON_A or btn == 0:
		if _focus >= 0 and _focus < _keys.size() and is_instance_valid(_keys[_focus]):
			_press(str(_keys[_focus].get_meta("osk_key", "")))
	elif btn == JOY_BUTTON_B or btn == 1:
		_press("BACK")
	elif btn == JOY_BUTTON_X or btn == 2:
		_press("SPACE")
	elif btn == JOY_BUTTON_Y or btn == 3:
		_press("SHIFT")
	elif btn == JOY_BUTTON_START or btn == 6:
		_press("DONE")
	else:
		return
	get_viewport().set_input_as_handled()
