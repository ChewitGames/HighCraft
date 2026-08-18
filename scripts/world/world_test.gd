extends Node3D
# HighCraft - Part 2 visual test.
# Builds a VoxelWorld, streams chunk meshes around a free-fly camera, and adds
# a sky + sun so you can actually SEE the generated terrain (hills, water,
# ores, trees). Part 4 replaces this with the real player controller.

const RADIUS = 3

var world
var renderer: ChunkRenderer
var cam: Camera3D
var hud: Label
var yaw: float = 0.0
var pitch: float = 0.0
var fly_speed: float = 16.0


func _ready() -> void:
	_setup_environment()

	var gen = TerrainGenerator.new(1337, "normal")
	world = VoxelWorld.new(gen)
	renderer = ChunkRenderer.new()
	add_child(renderer)
	renderer.setup(world)

	_print_part2_stats()

	var sy = world.surface_height(8, 8)
	cam = Camera3D.new()
	cam.position = Vector3(8, sy + 6, 8)
	cam.far = 1000.0
	add_child(cam)
	cam.current = true

	renderer.max_builds_per_call = 9999
	renderer.update_around(cam.position, RADIUS)
	renderer.max_builds_per_call = 4

	_setup_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _setup_environment() -> void:
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -40, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6

	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _setup_hud() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(16, 12)
	layer.add_child(hud)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.003
		pitch -= event.relative.y * 0.003
		pitch = clamp(pitch, -1.5, 1.5)
		cam.rotation = Vector3(pitch, yaw, 0.0)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var dir = Vector3.ZERO
	var b = cam.global_transform.basis
	if Input.is_key_pressed(KEY_W):
		dir -= b.z
	if Input.is_key_pressed(KEY_S):
		dir += b.z
	if Input.is_key_pressed(KEY_A):
		dir -= b.x
	if Input.is_key_pressed(KEY_D):
		dir += b.x
	if Input.is_key_pressed(KEY_SPACE):
		dir += Vector3.UP
	if Input.is_key_pressed(KEY_SHIFT):
		dir += Vector3.DOWN
	if dir.length() > 0.0:
		cam.global_position += dir.normalized() * fly_speed * delta

	renderer.update_around(cam.global_position, RADIUS)
	_update_hud()


func _update_hud() -> void:
	if hud == null:
		return
	var p = cam.global_position
	var lines: Array = []
	lines.append("HighCraft - Part 2 (voxel world)")
	lines.append("WASD + mouse to fly | Space/Shift = up/down | Esc = release mouse")
	lines.append("Chunks loaded: %d" % renderer.loaded_count())
	lines.append("Pos: (%.0f, %.0f, %.0f)" % [p.x, p.y, p.z])
	hud.text = "\n".join(lines)


func _print_part2_stats() -> void:
	var chunk = world.get_chunk(0, 0)
	var bc = chunk.blocks.size()
	var meshes = renderer.mesher.build(world, chunk)
	var verts = 0
	var surfaces = 0
	if meshes["collide"] != null:
		surfaces = meshes["collide"].get_surface_count()
		for i in range(surfaces):
			verts += meshes["collide"].surface_get_array_len(i)
	var faces = verts / 4
	var naive = bc * 6
	var msg = "[Part2] chunk(0,0) blocks=%d surfaces=%d visible_faces=%d naive=%d"
	print(msg % [bc, surfaces, faces, naive])
	if naive > 0:
		print("[Part2] culled=%.1f%%" % (100.0 * (1.0 - float(faces) / naive)))
