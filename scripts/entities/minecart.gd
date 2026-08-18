class_name Minecart
extends AnimatableBody3D
# Simple Minecraft-style minecart: sits on rails, moves along rail network,
# player can mount (like boat). Powered rails boost speed.

var rider: Node3D = null
var speed: float = 0.0
var max_speed: float = 8.0
var dir: Vector3 = Vector3(1, 0, 0)
var world = null
var game = null


func _ready() -> void:
	collision_layer = 1 | 2
	collision_mask = 1
	_build_mesh()
	# Find world
	var n = get_parent()
	var hops = 0
	while n != null and hops < 8:
		if n.get("world") != null:
			game = n
			world = n.world
			break
		n = n.get_parent()
		hops += 1


func _build_mesh() -> void:
	var mesh := MeshInstance3D.new()
	# Body
	var body := BoxMesh.new()
	body.size = Vector3(0.9, 0.35, 1.1)
	mesh.mesh = body
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.4)
	mesh.material_override = mat
	mesh.position = Vector3(0, 0.25, 0)
	add_child(mesh)
	# Wheels (visual)
	for xz in [Vector3(-0.35, 0.1, -0.4), Vector3(0.35, 0.1, -0.4), Vector3(-0.35, 0.1, 0.4), Vector3(0.35, 0.1, 0.4)]:
		var w := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.12, 0.12, 0.12)
		w.mesh = wm
		var wm_mat := StandardMaterial3D.new()
		wm_mat.albedo_color = Color(0.15, 0.15, 0.15)
		w.material_override = wm_mat
		w.position = xz
		add_child(w)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.9, 0.5, 1.1)
	col.shape = sh
	col.position = Vector3(0, 0.25, 0)
	add_child(col)


func try_mount(p: Node3D) -> void:
	if rider != null:
		return
	rider = p
	p.set_meta("in_minecart", self)
	p.velocity = Vector3.ZERO
	speed = 0.0


func dismount() -> void:
	if rider == null:
		return
	rider.set_meta("in_minecart", null)
	rider.global_position = global_position + Vector3(1.0, 0.6, 0)
	rider = null
	speed = 0.0


func _physics_process(delta: float) -> void:
	if world == null:
		return
	var cell = Vector3i(floori(global_position.x), floori(global_position.y), floori(global_position.z))
	# Snap to rail Y
	var rail_y = _find_rail_y(cell)
	if rail_y >= 0:
		global_position.y = float(rail_y) + 0.35
	else:
		# Fall if no rail
		global_position.y -= 9.8 * delta * 0.3
		if rider:
			rider.global_position = global_position + Vector3(0, 0.7, 0)
		return

	# Input boost when ridden
	if rider != null:
		var forward = _rail_forward(cell)
		if forward.length() > 0.1:
			dir = forward
		var want = 0.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			want = max_speed
		elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			want = -max_speed * 0.5
		# Controller: left stick Y
		var pads = Input.get_connected_joypads()
		if pads.size() > 0:
			var sy = Input.get_joy_axis(pads[0], JOY_AXIS_LEFT_Y)
			if absf(sy) > 0.3:
				want = -sy * max_speed
		speed = move_toward(speed, want, delta * 12.0)
		if Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_B):
			dismount()
			return
	else:
		speed = move_toward(speed, 0.0, delta * 3.0)

	# Powered rail boost
	var bid = world.get_block(cell.x, rail_y, cell.z)
	if bid == "powered_rail" and absf(speed) > 0.1:
		speed = clamp(speed * 1.05, -max_speed * 1.3, max_speed * 1.3)

	if absf(speed) < 0.05:
		if rider:
			rider.global_position = global_position + Vector3(0, 0.7, 0)
		return

	var move = dir.normalized() * speed * delta
	var next = global_position + move
	var ncell = Vector3i(floori(next.x), rail_y, floori(next.z))
	var nrail = world.get_block(ncell.x, rail_y, ncell.z)
	if _is_rail(nrail):
		global_position = next
		global_position.y = float(rail_y) + 0.35
		# Align rotation to movement
		if move.length() > 0.001:
			look_at(global_position + dir, Vector3.UP)
	else:
		# Try turn to adjacent rail
		var turned = false
		for d in [Vector3(1,0,0), Vector3(-1,0,0), Vector3(0,0,1), Vector3(0,0,-1)]:
			if d.dot(dir) < -0.5:
				continue
			var tcell = Vector3i(cell.x + int(d.x), rail_y, cell.z + int(d.z))
			if _is_rail(world.get_block(tcell.x, rail_y, tcell.z)):
				dir = d
				turned = true
				break
		if not turned:
			speed *= -0.5  # bounce

	if rider:
		rider.global_position = global_position + Vector3(0, 0.7, 0)
		rider.rotation.y = rotation.y


func _is_rail(id: String) -> bool:
	return id == "rail" or id == "powered_rail" or id == "detector_rail"


func _find_rail_y(cell: Vector3i) -> int:
	if world == null:
		return -1
	for dy in [0, -1, 1]:
		var y = cell.y + dy
		if y < 0:
			continue
		if _is_rail(world.get_block(cell.x, y, cell.z)):
			return y
	return -1


func _rail_forward(cell: Vector3i) -> Vector3:
	var y = _find_rail_y(cell)
	if y < 0:
		return dir
	# Prefer continuing current dir if rail ahead
	for d in [dir, Vector3(1,0,0), Vector3(-1,0,0), Vector3(0,0,1), Vector3(0,0,-1)]:
		if d.length() < 0.1:
			continue
		var n = Vector3i(cell.x + int(sign(d.x)), y, cell.z + int(sign(d.z)))
		if _is_rail(world.get_block(n.x, y, n.z)):
			return Vector3(sign(d.x), 0, sign(d.z))
	return dir
