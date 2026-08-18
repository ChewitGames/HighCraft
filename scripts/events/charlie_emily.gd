class_name CharlieEmily
extends Mob

var name_label: Label3D

func take_hit(_dmg: float) -> void:
	# Unkillable
	pass

func _ready() -> void:
	# Skip default box model; build a recognizable girl figure
	add_to_group("mobs")
	collision_layer = 2
	collision_mask = 1
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(0.55, 1.7, 0.4)
	shape.shape = box
	shape.position = Vector3(0, 0.85, 0)
	add_child(shape)

	_build_charlie_model()

	name_label = Label3D.new()
	name_label.text = "CHARLIE EMILY"
	name_label.font_size = 48
	name_label.modulate = Color(1.0, 0.8, 0.9)
	name_label.outline_modulate = Color(0, 0, 0)
	name_label.outline_size = 8
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.position = Vector3(0, 2.35, 0)
	add_child(name_label)

	mob_id = "charlie_emily"
	health = 9999.0
	max_health = 9999.0
	category = "special"
	attack_damage = 0.0


func _mat(col: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


func _build_charlie_model() -> void:
	# Skin, long brown hair, blue eyes, dress – no more sky-colored blob
	var skin = _mat(Color(0.96, 0.80, 0.70))
	var hair = _mat(Color(0.35, 0.18, 0.08))
	var dress = _mat(Color(0.55, 0.25, 0.55))
	var eyes = _mat(Color(0.25, 0.45, 0.95))
	var shoes = _mat(Color(0.2, 0.15, 0.12))

	# Body / dress
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.55, 0.85, 0.32)
	body.material_override = dress
	body.position = Vector3(0, 0.95, 0)
	add_child(body)

	# Skirt flare
	var skirt = MeshInstance3D.new()
	skirt.mesh = BoxMesh.new()
	skirt.mesh.size = Vector3(0.7, 0.35, 0.4)
	skirt.material_override = dress
	skirt.position = Vector3(0, 0.45, 0)
	add_child(skirt)

	# Head
	var head = MeshInstance3D.new()
	head.mesh = BoxMesh.new()
	head.mesh.size = Vector3(0.42, 0.45, 0.38)
	head.material_override = skin
	head.position = Vector3(0, 1.55, 0)
	add_child(head)

	# Long brown hair (back + sides)
	var hair_back = MeshInstance3D.new()
	hair_back.mesh = BoxMesh.new()
	hair_back.mesh.size = Vector3(0.48, 0.9, 0.2)
	hair_back.material_override = hair
	hair_back.position = Vector3(0, 1.25, -0.22)
	add_child(hair_back)
	for side in [-1, 1]:
		var hs = MeshInstance3D.new()
		hs.mesh = BoxMesh.new()
		hs.mesh.size = Vector3(0.12, 0.85, 0.35)
		hs.material_override = hair
		hs.position = Vector3(side * 0.28, 1.2, -0.05)
		add_child(hs)
	# Bangs
	var bangs = MeshInstance3D.new()
	bangs.mesh = BoxMesh.new()
	bangs.mesh.size = Vector3(0.44, 0.12, 0.15)
	bangs.material_override = hair
	bangs.position = Vector3(0, 1.72, 0.18)
	add_child(bangs)

	# Blue eyes
	for z in [-0.08, 0.08]:
		var e = MeshInstance3D.new()
		e.mesh = BoxMesh.new()
		e.mesh.size = Vector3(0.06, 0.06, 0.04)
		e.material_override = eyes
		e.position = Vector3(0.2, 1.58, z)
		add_child(e)

	# Arms
	for side in [-1, 1]:
		var arm = MeshInstance3D.new()
		arm.mesh = BoxMesh.new()
		arm.mesh.size = Vector3(0.14, 0.55, 0.14)
		arm.material_override = skin
		arm.position = Vector3(side * 0.38, 1.0, 0)
		add_child(arm)

	# Legs / shoes
	for side in [-1, 1]:
		var leg = MeshInstance3D.new()
		leg.mesh = BoxMesh.new()
		leg.mesh.size = Vector3(0.16, 0.4, 0.16)
		leg.material_override = skin
		leg.position = Vector3(side * 0.14, 0.2, 0)
		add_child(leg)
		var shoe = MeshInstance3D.new()
		shoe.mesh = BoxMesh.new()
		shoe.mesh.size = Vector3(0.18, 0.1, 0.22)
		shoe.material_override = shoes
		shoe.position = Vector3(side * 0.14, 0.05, 0.02)
		add_child(shoe)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
