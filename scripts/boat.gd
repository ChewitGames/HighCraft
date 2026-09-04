class_name Boat
extends AnimatableBody3D
# Minecraft-style boat: mount, steer, dismount with Shift / Space / B.

var rider: Node3D = null
var speed: float = 7.0
var _dismount_cd: float = 0.0


func _ready() -> void:
	collision_layer = 1 | 2
	collision_mask = 1
	_build_mesh()


func _build_mesh() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.28, 0.12)
	var hull := MeshInstance3D.new()
	var hbox := BoxMesh.new()
	hbox.size = Vector3(1.5, 0.35, 2.4)
	hull.mesh = hbox
	hull.material_override = mat
	hull.position = Vector3(0, 0.15, 0)
	add_child(hull)
	for sx in [-0.7, 0.7]:
		var side := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.12, 0.35, 2.3)
		side.mesh = sb
		side.material_override = mat
		side.position = Vector3(sx, 0.4, 0)
		add_child(side)
	var bow := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.9, 0.3, 0.4)
	bow.mesh = bb
	bow.material_override = mat
	bow.position = Vector3(0, 0.25, -1.3)
	add_child(bow)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.5, 0.5, 2.4)
	col.shape = sh
	col.position = Vector3(0, 0.2, 0)
	add_child(col)


func try_mount(p: Node3D) -> void:
	if rider != null or p == null:
		return
	rider = p
	p.set_meta("in_boat", self)
	if "velocity" in p:
		p.velocity = Vector3.ZERO
	_dismount_cd = 0.4
	print("[Boat] mounted — Shift / Space / B to exit")


func dismount() -> void:
	if rider == null:
		return
	var p = rider
	rider = null
	if is_instance_valid(p):
		p.set_meta("in_boat", null)
		p.global_position = global_position + Vector3(1.2, 0.8, 0)
		if "velocity" in p:
			p.velocity = Vector3.ZERO
	print("[Boat] dismounted")


func _physics_process(delta: float) -> void:
	if rider == null or not is_instance_valid(rider):
		rider = null
		return
	_dismount_cd = maxf(0.0, _dismount_cd - delta)

	# Exit: Shift, Space (after cooldown), controller B
	var exit = false
	if _dismount_cd <= 0.0:
		if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_SPACE):
			exit = true
		var pads = Input.get_connected_joypads()
		for d in pads:
			if Input.is_joy_button_pressed(d, JOY_BUTTON_B):
				exit = true
				break
	if exit:
		dismount()
		return

	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move -= global_transform.basis.z
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move += global_transform.basis.z
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		rotate_y(1.8 * delta)
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		rotate_y(-1.8 * delta)
	# Stick
	var pads2 = Input.get_connected_joypads()
	if pads2.size() > 0:
		var lx = Input.get_joy_axis(pads2[0], JOY_AXIS_LEFT_X)
		var ly = Input.get_joy_axis(pads2[0], JOY_AXIS_LEFT_Y)
		if absf(lx) > 0.25:
			rotate_y(-lx * 2.0 * delta)
		if absf(ly) > 0.25:
			move -= global_transform.basis.z * (-ly)

	move.y = 0.0
	if move.length() > 0.01:
		move = move.normalized()
		global_position += move * speed * delta

	rider.global_position = global_position + Vector3(0, 0.7, 0)
	rider.rotation.y = rotation.y
	if "velocity" in rider:
		rider.velocity = Vector3.ZERO
