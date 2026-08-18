class_name AvatarLoader
extends RefCounted
# Helper to load a saved skin and apply it to a Player model.

static func load_skin(name: String = "afro_steve") -> Dictionary:
	var path = "user://skins/" + name.replace(" ", "_").to_lower() + ".json"
	if not FileAccess.file_exists(path):
		# Default Afro Steve
		return {
			"name": "Afro Steve",
			"skin_color": Color(0.55, 0.35, 0.2),
			"hair_color": Color(0.08, 0.04, 0.0),
			"eye_color": Color(0.2, 0.5, 0.9),
			"shirt_color": Color(0.1, 0.55, 0.9),
			"pants_color": Color(0.15, 0.15, 0.25),
			"hair_style": 0
		}
		# Default Afro Steve
		return {
			"name": "Afro Steve",
			"skin_color": Color(0.55, 0.35, 0.2),
			"hair_color": Color(0.08, 0.04, 0.0),
			"eye_color": Color(0.2, 0.5, 0.9),
			"shirt_color": Color(0.1, 0.55, 0.9),
			"pants_color": Color(0.15, 0.15, 0.25),
			"hair_style": 0
		}
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var json = JSON.new()
	if json.parse(f.get_as_text()) != OK:
		f.close()
		return {}
	var d = json.data
	f.close()
	return {
		"name": d.get("name", "Afro Steve"),
		"skin_color": Color(d["skin_color"][0], d["skin_color"][1], d["skin_color"][2]),
		"hair_color": Color(d["hair_color"][0], d["hair_color"][1], d["hair_color"][2]),
		"eye_color": Color(d["eye_color"][0], d["eye_color"][1], d["eye_color"][2]),
		"shirt_color": Color(d["shirt_color"][0], d["shirt_color"][1], d["shirt_color"][2]),
		"pants_color": Color(d["pants_color"][0], d["pants_color"][1], d["pants_color"][2]),
		"hair_style": int(d.get("hair_style", 0))
	}


static func apply_to_player(player: Node3D, skin: Dictionary) -> void:
	# === ALLES Alte komplett entfernen ===
	var old = player.get_node_or_null("PlayerModel")
	if old:
		old.queue_free()
		# Warten bis es wirklich weg ist
		await player.get_tree().process_frame

	# Nochmal sicherstellen (falls mehrere vorhanden)
	for child in player.get_children():
		if child.name == "PlayerModel" or child.name.begins_with("PlayerModel"):
			child.queue_free()

	var model = Node3D.new()
	model.name = "PlayerModel"
	player.add_child(model)

	var skin_c = skin.get("skin_color", Color(0.55, 0.35, 0.2))
	var hair_c = skin.get("hair_color", Color(0.08, 0.04, 0.0))
	var eye_c  = skin.get("eye_color", Color(0.2, 0.5, 0.9))
	var shirt_c = skin.get("shirt_color", Color(0.1, 0.55, 0.9))
	var pants_c = skin.get("pants_color", Color(0.15, 0.15, 0.25))
	var style = int(skin.get("hair_style", 0))

	# Head
	_box(model, Vector3(0.55, 0.55, 0.55), Vector3(0, 1.75, 0), skin_c)

	# Eyes (vorne)
	_box(model, Vector3(0.12, 0.08, 0.05), Vector3(-0.12, 1.8, -0.28), eye_c)
	_box(model, Vector3(0.12, 0.08, 0.05), Vector3(0.12, 1.8, -0.28), eye_c)

	# Hair
	match style:
		0: # Afro
			_sphere(model, 0.42, Vector3(0, 2.05, 0), hair_c)
		1: # Short
			_box(model, Vector3(0.58, 0.18, 0.58), Vector3(0, 2.05, 0), hair_c)
		2: # Long
			_box(model, Vector3(0.58, 0.35, 0.58), Vector3(0, 2.1, 0), hair_c)
			_box(model, Vector3(0.5, 0.6, 0.25), Vector3(0, 1.6, -0.35), hair_c)
		3: # Bald
			pass

	# Body
	_box(model, Vector3(0.55, 0.85, 0.3), Vector3(0, 1.1, 0), shirt_c)

	# Arms
	_box(model, Vector3(0.22, 0.75, 0.22), Vector3(-0.42, 1.1, 0), skin_c)
	_box(model, Vector3(0.22, 0.75, 0.22), Vector3(0.42, 1.1, 0), skin_c)

	# Legs
	_box(model, Vector3(0.26, 0.85, 0.26), Vector3(-0.18, 0.45, 0), pants_c)
	_box(model, Vector3(0.26, 0.85, 0.26), Vector3(0.18, 0.45, 0), pants_c)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> void:
	var mi = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


static func _sphere(parent: Node3D, radius: float, pos: Vector3, col: Color) -> void:
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
