class_name AvatarPixelCanvas
extends Control

signal changed(pixels: Array)

const GRID := 16
var pixels: Array = []
var paint_color := Color.WHITE
var cursor := Vector2i(0, 0)
var controller_active := false

func _ready() -> void:
	custom_minimum_size = Vector2(448, 448)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if pixels.is_empty():
		reset_pixels(false)
	queue_redraw()

func set_pixels(value: Array) -> void:
	pixels = value.duplicate(true)
	while pixels.size() < GRID * GRID:
		pixels.append([0.0, 0.0, 0.0, 0.0])
	queue_redraw()

func reset_pixels(emit_change: bool = true) -> void:
	pixels.clear()
	for _i in range(GRID * GRID):
		pixels.append([0.0, 0.0, 0.0, 0.0])
	queue_redraw()
	if emit_change: changed.emit(pixels)

func move_cursor(delta: Vector2i) -> void:
	cursor.x = clampi(cursor.x + delta.x, 0, GRID - 1)
	cursor.y = clampi(cursor.y + delta.y, 0, GRID - 1)
	controller_active = true
	queue_redraw()

func paint_cursor() -> void:
	_set_pixel(cursor.x, cursor.y, paint_color)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var cell := size / float(GRID)
		var p := Vector2i(clampi(int(event.position.x / cell.x), 0, GRID - 1), clampi(int(event.position.y / cell.y), 0, GRID - 1))
		cursor = p
		controller_active = false
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_set_pixel(p.x, p.y, paint_color)
		queue_redraw()

func _set_pixel(x: int, y: int, color: Color) -> void:
	pixels[y * GRID + x] = [color.r, color.g, color.b, color.a]
	changed.emit(pixels)
	queue_redraw()

func _draw() -> void:
	var cell := size / float(GRID)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.13, 0.16))
	for y in range(GRID):
		for x in range(GRID):
			var raw: Array = pixels[y * GRID + x]
			var col := Color(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
			var rect := Rect2(Vector2(x * cell.x, y * cell.y), cell)
			if col.a > 0.0: draw_rect(rect, col)
			draw_rect(rect, Color(0.28, 0.3, 0.34), false, 1.0)
	if controller_active:
		draw_rect(Rect2(Vector2(cursor.x * cell.x, cursor.y * cell.y), cell), Color(1.0, 0.85, 0.2), false, 3.0)
