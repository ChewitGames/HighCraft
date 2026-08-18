class_name Boat
extends AnimatableBody3D
# Einfaches Boot: Spieler sitzt, steuert mit WASD, rutscht auf Wasser.

var rider: Node3D = null
var speed: float = 6.0


func _ready() -> void:
	collision_layer = 1 | 2
	collision_mask = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.28, 0.12)
	# Hull
	var hull := MeshInstance3D.new()
	var hbox := BoxMesh.new()
	hbox.size = Vector3(1.5, 0.35, 2.4)
	hull.mesh = hbox
	hull.material_override = mat
	hull.position = Vector3(0, 0.15, 0)
	add_child(hull)
	# Sides (raised gunwales)
	for sx in [-0.7, 0.7]:
		var side := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.12, 0.35, 2.3)
		side.mesh = sb
		side.material_override = mat
		side.position = Vector3(sx, 0.4, 0)
		add_child(side)
	# Bow tip
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
	if rider != null:
		return
	rider = p
	p.set_meta("in_boat", self)
	p.velocity = Vector3.ZERO
	# Spieler-Physik pausieren optional über Meta
	print("[Boat] mounted")


func dismount() -> void:
	if rider == null:
		return
	rider.set_meta("in_boat", null)
	rider.global_position = global_position + Vector3(1.2, 0.5, 0)
	rider = null


func _physics_process(delta: float) -> void:
	if rider == null:
		return
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir -= global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		dir += global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		rotate_y(1.5 * delta)
	if Input.is_key_pressed(KEY_D):
		rotate_y(-1.5 * delta)
	dir.y = 0
	if dir.length() > 0.01:
		dir = dir.normalized()
		global_position += dir * speed * delta
	rider.global_position = global_position + Vector3(0, 0.6, 0)
	rider.rotation.y = rotation.y
