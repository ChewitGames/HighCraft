class_name Minecart
extends CharacterBody3D
## Visible minecart on rails. Mount with interact, move with W/S or stick.

var rider: Node3D = null
var speed: float = 0.0
var max_speed: float = 8.0
var dir: Vector3 = Vector3(1, 0, 0)
var world = null
var game = null
var _ready_done: bool = false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_build_mesh()
	_ready_done = true
	if world == null:
		_find_world()


func _find_world() -> void:
	var n = get_parent()
	var hops = 0
	while n != null and hops < 10:
		if n.get("world") != null:
			game = n
			world = n.world
			break
		n = n.get_parent()
		hops += 1


func setup(p_world, p_game, pos: Vector3) -> void:
	world = p_world
	game = p_game
	global_position = pos


func _build_mesh() -> void:
	# Clear old
	for c in get_children():
		if c is MeshInstance3D or c is CollisionShape3D:
			c.queue_free()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.4, 0.45)
	mat.metallic = 0.6
	mat.roughness = 0.4
	# Body
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.95, 0.4, 1.15)
	body.mesh = bm
	body.material_override = mat
	body.position = Vector3(0, 0.35, 0)
	add_child(body)
	# Sides higher
	for sx in [-0.42, 0.42]:
		var side := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.08, 0.45, 1.1)
		side.mesh = sm
		side.material_override = mat
		side.position = Vector3(sx, 0.55, 0)
		add_child(side)
	# Wheels
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.12, 0.12, 0.12)
	for xz in [Vector3(-0.38, 0.12, -0.4), Vector3(0.38, 0.12, -0.4),
			Vector3(-0.38, 0.12, 0.4), Vector3(0.38, 0.12, 0.4)]:
		var w := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.14, 0.14, 0.14)
		w.mesh = wm
		w.material_override = wmat
		w.position = xz
		add_child(w)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.9, 0.55, 1.1)
	col.shape = sh
	col.position = Vector3(0, 0.3, 0)
	add_child(col)


func try_mount(p: Node3D) -> void:
	if rider != null or p == null:
		return
	rider = p
	p.set_meta("in_minecart", self)
	if "velocity" in p:
		p.velocity = Vector3.ZERO
	speed = 0.0


func dismount() -> void:
	if rider == null:
		return
	rider.set_meta("in_minecart", null)
	rider.global_position = global_position + Vector3(1.2, 0.8, 0)
	rider = null
	speed = 0.0


func _physics_process(delta: float) -> void:
	if world == null:
		_find_world()
		if world == null:
			return
	var cell = Vector3i(floori(global_position.x), floori(global_position.y + 0.1), floori(global_position.z))
	var rail_y = _find_rail_y(cell)
	if rail_y < 0:
		# Try slightly above/below
		velocity.y -= 12.0 * delta
		move_and_slide()
		if rider:
			rider.global_position = global_position + Vector3(0, 0.75, 0)
		return
	# Snap onto rail
	global_position.y = float(rail_y) + 0.4
	velocity = Vector3.ZERO

	if rider != null:
		var forward = _rail_forward(cell, rail_y)
		if forward.length() > 0.1:
			dir = forward
		var want = 0.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			want = max_speed
		elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			want = -max_speed * 0.6
		var pads = Input.get_connected_joypads()
		if pads.size() > 0:
			var sy = Input.get_joy_axis(pads[0], JOY_AXIS_LEFT_Y)
			if absf(sy) > 0.3:
				want = -sy * max_speed
		speed = move_toward(speed, want, delta * 14.0)
		if Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_B):
			dismount()
			return
	else:
		speed = move_toward(speed, 0.0, delta * 4.0)

	var bid = str(world.get_block(cell.x, rail_y, cell.z))
	if bid == "powered_rail" and absf(speed) > 0.05:
		speed = clampf(speed * 1.08, -max_speed * 1.4, max_speed * 1.4)

	if absf(speed) < 0.04:
		if rider:
			rider.global_position = global_position + Vector3(0, 0.75, 0)
		return

	var move = dir.normalized() * speed * delta
	var next = global_position + move
	var ncell = Vector3i(floori(next.x), rail_y, floori(next.z))
	if _is_rail(str(world.get_block(ncell.x, rail_y, ncell.z))):
		global_position = Vector3(next.x, float(rail_y) + 0.4, next.z)
		if move.length() > 0.001:
			look_at(global_position + Vector3(dir.x, 0, dir.z), Vector3.UP)
	else:
		var turned = false
		for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			if d.dot(dir) < -0.4:
				continue
			var tcell = Vector3i(cell.x + int(d.x), rail_y, cell.z + int(d.z))
			if _is_rail(str(world.get_block(tcell.x, rail_y, tcell.z))):
				dir = d
				turned = true
				break
		if not turned:
			speed *= -0.4

	if rider:
		rider.global_position = global_position + Vector3(0, 0.75, 0)
		rider.rotation.y = rotation.y


func _is_rail(id: String) -> bool:
	return id == "rail" or id == "powered_rail" or id == "detector_rail"


func _find_rail_y(cell: Vector3i) -> int:
	if world == null:
		return -1
	for dy in [0, -1, 1, -2, 2]:
		var y = cell.y + dy
		if y < 0 or y >= 128:
			continue
		if _is_rail(str(world.get_block(cell.x, y, cell.z))):
			return y
	return -1


func _rail_forward(cell: Vector3i, y: int) -> Vector3:
	for d in [dir, Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		if d.length() < 0.1:
			continue
		var n = Vector3i(cell.x + int(sign(d.x)), y, cell.z + int(sign(d.z)))
		if _is_rail(str(world.get_block(n.x, y, n.z))):
			return Vector3(sign(d.x), 0, sign(d.z))
	return dir
