class_name AvatarLoader
extends RefCounted

const Catalog = preload("res://scripts/avatar_catalog.gd")

static func load_skin(name: String = "afro_steve") -> Dictionary:
	var result := Catalog.defaults()
	var path := "user://skins/" + name.replace(" ", "_").to_lower() + ".json"
	if not FileAccess.file_exists(path): return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return result
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary: return result
	for key in parsed:
		if key.ends_with("_color") and parsed[key] is Array and parsed[key].size() >= 3:
			var color: Array = parsed[key]
			result[key] = Color(float(color[0]), float(color[1]), float(color[2]), float(color[3]) if color.size() > 3 else 1.0)
		else: result[key] = parsed[key]
	return result

static func apply_to_player(player: Node3D, skin: Dictionary) -> void:
	var old := player.get_node_or_null("PlayerModel")
	if old: old.free()
	for child in player.get_children():
		if child.name == "PlayerModel" or child.name.begins_with("PlayerModel"): child.free()
	var model := Node3D.new()
	model.name = "PlayerModel"
	player.add_child(model)
	populate_model(model, skin, false)

static func populate_model(model: Node3D, skin: Dictionary, preview := false) -> void:
	var dims := Catalog.body_dimensions(skin)
	var height: float = dims.height
	var torso: Vector3 = dims.torso
	var shoulder: float = dims.shoulder
	var hip: float = dims.hip
	var head_scale: float = dims.head_scale
	var limb_scale: float = dims.limb_scale
	var gender := int(skin.get("gender", 0))
	var age := int(skin.get("age", 2))
	var build := clampi(int(skin.get("build", 1)), 0, 2)
	var skin_c: Color = skin.get("skin_color", Color(0.55, 0.35, 0.2))
	var hair_c: Color = skin.get("hair_color", Color(0.08, 0.04, 0.0))
	var eye_c: Color = skin.get("eye_color", Color(0.2, 0.5, 0.9))
	var shirt_c: Color = skin.get("shirt_color", Color(0.1, 0.55, 0.9))
	var pants_c: Color = skin.get("pants_color", Color(0.15, 0.15, 0.25))
	# One coordinate system everywhere: face/front is -Z, back is +Z.
	# The preview model itself is rotated to face its camera.
	var front := -0.29
	var head_y := 1.25 + 0.5 * height
	var torso_y := 0.7 + 0.42 * height
	var head_size := Vector3(0.55, 0.55, 0.55) * head_scale
	_box(model, head_size, Vector3(0, head_y, 0), skin_c)
	_add_face_details(model, head_y, head_scale, front, skin_c, eye_c, age, gender, int(skin.get("mouth_style", 1)))
	_add_hair(model, int(skin.get("hair_style", 0)), Vector3(0, head_y, 0), hair_c, -front)
	if age == 3: _add_old_hair_detail(model, head_y, -front, hair_c)
	_add_glasses(model, int(skin.get("glasses_style", 0)), head_y, front)
	if gender == 0: _add_beard(model, int(skin.get("beard_style", 0)), head_y, front, hair_c)
	_add_detailed_torso(model, skin, torso_y, torso, shirt_c, gender, age)
	var arm_thickness = (0.16 if gender == 1 else 0.19) * (0.88 if age == 0 else 1.0) * [0.86, 1.0, 1.16][build]
	var arm_size := Vector3(arm_thickness, 0.7 * height * limb_scale, arm_thickness + 0.01)
	var sleeve_ratio := 0.28 + 0.08 * float(int(skin.get("outfit_style", 0)) % 4)
	_arm_limb(model, "LeftArm", arm_size, Vector3(-shoulder, torso_y + arm_size.y * 0.45, 0), skin_c, shirt_c, sleeve_ratio)
	_arm_limb(model, "RightArm", arm_size, Vector3(shoulder, torso_y + arm_size.y * 0.45, 0), skin_c, shirt_c, sleeve_ratio)
	# Legs and feet are separate so age/build affect the complete silhouette.
	# The old single limb was scaled twice for Liddle and visibly floated above ground.
	var build_width: float = [0.82, 1.0, 1.18][build]
	var age_foot_scale: float = [0.78, 0.92, 1.0, 0.96][age]
	var leg_top := 0.78 * height
	var foot_height = 0.105 * age_foot_scale * [0.9, 1.0, 1.08][build]
	var leg_width := hip * (0.58 if gender == 1 else 0.64) * build_width
	var leg_depth = (0.205 if gender == 1 else 0.22) * age_foot_scale * [0.88, 1.0, 1.14][build]
	var leg_size := Vector3(leg_width, maxf(0.2, leg_top - foot_height), leg_depth)
	var foot_size := Vector3(leg_width * [0.94, 1.02, 1.1][build], foot_height, leg_depth * [1.18, 1.28, 1.38][build])
	_leg_with_foot(model, "LeftLeg", leg_size, foot_size, Vector3(-hip * 0.48, leg_top, 0), pants_c)
	_leg_with_foot(model, "RightLeg", leg_size, foot_size, Vector3(hip * 0.48, leg_top, 0), pants_c)
	_add_outfit_details(model, int(skin.get("outfit_style", 0)), torso_y, torso, shirt_c)
	_add_back_cosmetics(model, skin, torso_y, torso, head_y, -front)

static func _add_face_details(parent: Node3D, y: float, scale: float, front: float, skin: Color, eyes: Color, age: int, gender: int, mouth_style: int) -> void:
	var face_z := front * scale - 0.012
	var eye_y := y + (0.045 if gender == 0 else 0.055)
	var pixel := 0.055 * scale
	for x in [-0.13 * scale, 0.13 * scale]:
		if gender == 0:
			# Cool classic one-row Minecraft eyes.
			_box(parent, Vector3(pixel * 1.55, pixel, 0.014), Vector3(x, eye_y, face_z), eyes)
			_box(parent, Vector3(pixel * 0.55, pixel, 0.01), Vector3(x + pixel * 0.35, eye_y, face_z - 0.01), Color(0.035, 0.03, 0.025))
		else:
			# Common girl-skin eye: two pixels high, dark upper lash and tiny shine.
			_box(parent, Vector3(pixel * 1.45, pixel * 1.55, 0.014), Vector3(x, eye_y, face_z), eyes)
			_box(parent, Vector3(pixel * 1.55, pixel * 0.38, 0.01), Vector3(x, eye_y + pixel * 0.78, face_z - 0.01), skin.darkened(0.5))
			_box(parent, Vector3(pixel * 0.35, pixel * 0.4, 0.008), Vector3(x - pixel * 0.35, eye_y + pixel * 0.25, face_z - 0.013), Color(0.95, 0.95, 0.92))
			_box(parent, Vector3(pixel * 0.28, pixel * 0.55, 0.009), Vector3(x + signf(x) * pixel * 0.9, eye_y + pixel * 0.45, face_z), skin.darkened(0.5))
	if gender == 1:
		for x in [-0.2, 0.2]: _box(parent, Vector3(pixel * 0.55, pixel * 0.3, 0.009), Vector3(x, y - 0.07, face_z), Color(0.72, 0.32, 0.34).lerp(skin, 0.35))
	if age == 3:
		for x in [-0.18, 0.18]: _box(parent, Vector3(pixel, 0.012, 0.008), Vector3(x, eye_y - 0.075, face_z), skin.darkened(0.1))
	_add_mouth_line(parent, mouth_style, y - 0.14 * scale, face_z - 0.004, scale, skin, gender)

static func _add_mouth_line(parent: Node3D, style: int, y: float, z: float, scale: float, skin: Color, gender: int) -> void:
	if style <= 0: return
	var color := Color(0.3, 0.09, 0.1).lerp(skin, 0.22) if gender == 1 else skin.darkened(0.48)
	var thin := 0.014 * scale
	var short := 0.08 * scale
	var normal := 0.125 * scale
	var wide := 0.18 * scale
	match style:
		1: _mouth_segment(parent, normal, thin, Vector3(0, y, z), 0, color)
		2: _mouth_segment(parent, short, thin, Vector3(0, y, z), 0, color)
		3: _mouth_segment(parent, wide, thin, Vector3(0, y, z), 0, color)
		4: _mouth_smile(parent, normal, thin, y, z, color, 10)
		5: _mouth_smile(parent, wide, thin, y, z, color, 12)
		6: _mouth_smile(parent, short, thin, y, z, color, 9)
		7: _mouth_segment(parent, normal, thin, Vector3(0, y, z), -7, color)
		8: _mouth_segment(parent, normal, thin, Vector3(0, y, z), 7, color)
		9: _mouth_segment(parent, wide, thin * 1.15, Vector3(0, y, z), -4, color)
		10: _mouth_smile(parent, normal * 1.1, thin, y, z, color, 6)
		11: _mouth_smile(parent, short * 0.8, thin, y, z, color, 7)
		12: _mouth_segment(parent, normal, thin * 1.2, Vector3(0, y, z), 0, color.darkened(0.08))
		13: _mouth_smile(parent, normal, thin, y, z, color, -10)
		14: _mouth_smile(parent, short, thin, y, z, color, -9)
		15:
			_mouth_segment(parent, short, thin, Vector3(-0.035, y, z), -7, color)
			_mouth_segment(parent, short * 0.65, thin, Vector3(0.04, y + 0.008, z), 5, color)
		16:
			_mouth_segment(parent, normal, thin, Vector3(-0.018, y, z), 0, color)
			_mouth_segment(parent, thin, short * 0.45, Vector3(0.055, y - 0.012, z), 0, color)
		17: _mouth_smile(parent, short, thin * 1.15, y, z, color.lightened(0.08), 12)
		18:
			_mouth_smile(parent, normal, thin, y, z, color, 7)
			_mouth_segment(parent, short * 0.45, thin, Vector3(0.0, y + 0.025, z), 0, color.lightened(0.1))
		19:
			_mouth_segment(parent, normal, thin, Vector3(0, y, z), 0, color)
			_mouth_segment(parent, short * 0.5, thin, Vector3(0.04, y - 0.025, z), 0, color)
		20:
			_mouth_segment(parent, wide, thin * 1.2, Vector3(0, y, z), -3, color.darkened(0.12))
			_mouth_segment(parent, short * 0.4, thin, Vector3(-0.055, y + 0.02, z), 12, color)
		21:
			_mouth_smile(parent, wide, thin, y, z, color, 8)
			_mouth_segment(parent, normal * 0.7, thin, Vector3(0, y - 0.022, z), 0, color.lightened(0.12))

static func _mouth_smile(parent: Node3D, width: float, thickness: float, y: float, z: float, color: Color, angle: float) -> void:
	_mouth_segment(parent, width * 0.52, thickness, Vector3(-width * 0.23, y, z), -angle, color)
	_mouth_segment(parent, width * 0.52, thickness, Vector3(width * 0.23, y, z), angle, color)

static func _mouth_segment(parent: Node3D, width: float, height: float, pos: Vector3, angle: float, color: Color) -> void:
	_box_rotated(parent, Vector3(width, height, 0.01), pos, color, Vector3(0, 0, angle))

static func _add_old_hair_detail(parent: Node3D, head_y: float, back: float, hair: Color) -> void:
	var gray := hair.lerp(Color(0.76, 0.76, 0.72), 0.7)
	for x in [-0.22, 0.22]: _box(parent, Vector3(0.075, 0.18, 0.12), Vector3(x, head_y + 0.2, back), gray)

static func _add_detailed_torso(parent: Node3D, skin: Dictionary, y: float, torso: Vector3, shirt: Color, gender: int, age: int) -> void:
	var texture := _pixels_to_texture(skin.get("pixels", []), shirt)
	var base_color := Color.WHITE if texture != null else shirt
	# Exactly one classic Minecraft torso block.
	_box(parent, torso, Vector3(0, y, 0), base_color, texture)
	# Female clothing silhouette: connected shallow voxel forms on the classic torso.
	if gender == 1 and age > 0:
		var torso_front := -torso.z * 0.5
		# Compact, anatomy-inspired proportions expressed with flat voxel facets.
		# Young stays subtle; Adult is defined; Old is slightly softer/smaller.
		var chest_size := clampi(int(skin.get("chest_size", 1)), 0, 2)
		# Standard preserves the previous proportions exactly.
		var size_depth: float = [0.72, 1.0, 1.28][chest_size]
		var size_width: float = [0.9, 1.0, 1.08][chest_size]
		var size_height: float = [0.88, 1.0, 1.1][chest_size]
		var total_depth := (0.075 if age == 1 else (0.115 if age == 3 else 0.135)) * size_depth
		var panel_w := torso.x * 0.47 * size_width
		var panel_h := torso.y * (0.34 if age == 1 else 0.43) * size_height
		# Two joined compact halves form one coherent clothing silhouette.
		var half_spacing := minf(torso.x * 0.245 * size_width, torso.x * 0.27)
		for x in [-half_spacing, half_spacing]:
			_add_minecraft_chest_half(parent, Vector3(x, y + torso.y * 0.17, torso_front), panel_w, panel_h, total_depth, shirt)

static func _add_minecraft_chest_half(parent: Node3D, anchor: Vector3, width: float, height: float, depth: float, color: Color) -> void:
	var side := signf(anchor.x)
	var inner_x := anchor.x - side * width * 0.5
	var full_outer_x := anchor.x + side * width * 0.5
	# Five straight rings reproduce the drawn / profile. The lower outer edge
	# is cut inward, matching the black front outline without any () bulge.
	var profile_y := PackedFloat32Array([height * 0.5, height * 0.18, -height * 0.02, -height * 0.23, -height * 0.5])
	var profile_z := PackedFloat32Array([0.0, -depth * 0.46, -depth, -depth * 0.86, 0.0])
	# Very subtle outward side curve: only the middle rings exceed the regular
	# width, and only by a few percent. Top/bottom remain controlled and blocky.
	var outer_taper := PackedFloat32Array([0.94, 1.02, 1.05, 1.0, 0.88])
	var vertices := PackedVector3Array()
	for i in range(5):
		var outer_x := lerpf(inner_x, full_outer_x, outer_taper[i])
		vertices.append(Vector3(inner_x, anchor.y + profile_y[i], anchor.z + profile_z[i]))
		vertices.append(Vector3(outer_x, anchor.y + profile_y[i], anchor.z + profile_z[i]))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Every strip is two triangles on one plane: flat facets, never rounded.
	for i in range(5):
		var next := (i + 1) % 5
		var inner_i := i * 2
		var outer_i := inner_i + 1
		var inner_next := next * 2
		var outer_next := inner_next + 1
		_add_surface_triangle(surface, vertices[inner_i], vertices[outer_i], vertices[outer_next])
		_add_surface_triangle(surface, vertices[inner_i], vertices[outer_next], vertices[inner_next])
	# Flat caps close the inner seam and outer cut edge.
	_add_surface_triangle(surface, vertices[0], vertices[4], vertices[2])
	_add_surface_triangle(surface, vertices[0], vertices[6], vertices[4])
	_add_surface_triangle(surface, vertices[0], vertices[8], vertices[6])
	_add_surface_triangle(surface, vertices[1], vertices[3], vertices[5])
	_add_surface_triangle(surface, vertices[1], vertices[5], vertices[7])
	_add_surface_triangle(surface, vertices[1], vertices[7], vertices[9])
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	parent.add_child(instance)

static func _add_surface_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)

static func _add_hair(parent: Node3D, style: int, head: Vector3, color: Color, back_z: float) -> void:
	if style == Catalog.HAIRS.size() - 1: return
	if style == 0:
		for x in [-0.24, 0.0, 0.24]:
			for z in [-0.2, 0.0, 0.2]: _box(parent, Vector3(0.25, 0.24 + (0.06 if x == 0 and z == 0 else 0.0), 0.25), head + Vector3(x, 0.3 + (0.04 if x == 0 and z == 0 else 0.0), z), color)
		return
	# All non-bald hair wraps over the whole skull instead of being a front plate.
	var top_h := 0.1 + 0.025 * float(style % 4)
	_box(parent, Vector3(0.59, top_h, 0.59), head + Vector3(0, 0.31, 0), color)
	if style not in [1, 2, 4]:
		var front_z := -absf(back_z)
		var fringe_side := -1.0 if style % 2 == 0 else 1.0
		_box(parent, Vector3(0.24, 0.13 + 0.025 * float(style % 3), 0.075), head + Vector3(-0.14 * fringe_side, 0.2, front_z), color.darkened(0.035))
		_box(parent, Vector3(0.16, 0.09 + 0.02 * float((style + 1) % 3), 0.075), head + Vector3(0.15 * fringe_side, 0.23, front_z), color.lightened(0.045))
	_box(parent, Vector3(0.2, 0.025, 0.22), head + Vector3(-0.14 if style % 2 == 0 else 0.14, 0.39 + top_h * 0.25, -0.08), color.lightened(0.09))
	if style in [2, 3, 4, 5, 8, 9, 10, 11, 12, 13, 14, 22]:
		_box(parent, Vector3(0.58, 0.18 + 0.035 * float(style % 3), 0.12), head + Vector3(0, 0.18, back_z), color)
	if style in [3, 4, 5, 7, 8, 10, 11, 12, 22]:
		var side_x := -0.30 if style % 2 == 0 else 0.30
		_box(parent, Vector3(0.09, 0.25 + 0.03 * float(style % 4), 0.52), head + Vector3(side_x, 0.12, 0), color)
	if style in [7, 9]:
		_box(parent, Vector3(0.12, 0.2 + 0.05 * float(style - 7), 0.16), head + Vector3(0, 0.47, 0), color)
	if style in [10, 11]:
		for x in [-0.2, 0.0, 0.2]: _box(parent, Vector3(0.19, 0.19, 0.2), head + Vector3(x, 0.34 + (0.035 if x == 0 else 0.0), 0), color.lightened(0.04 if x == 0 else 0.0))
	if style in [12, 13, 14]:
		_box(parent, Vector3(0.1, 0.35 + 0.08 * float(style - 12), 0.48), head + Vector3(-0.29, -0.02, 0.04), color)
		_box(parent, Vector3(0.1, 0.35 + 0.08 * float(style - 12), 0.48), head + Vector3(0.29, -0.02, 0.04), color)
		_box(parent, Vector3(0.48, 0.4 + 0.08 * float(style - 12), 0.12), head + Vector3(0, -0.06, back_z), color)
		for x in [-0.19, -0.06, 0.07, 0.2]: _box(parent, Vector3(0.075, 0.26 + 0.045 * float(style - 12), 0.035), head + Vector3(x, -0.12, back_z * 1.23), color.lightened(0.04 if x > 0 else 0.0))
	if style in [15, 16]:
		_box(parent, Vector3(0.18, 0.18, 0.18), head + Vector3(0, 0.05, back_z * 1.2), color)
		_box(parent, Vector3(0.12, 0.42 + 0.12 * float(style - 15), 0.12), head + Vector3(0, -0.22, back_z * 1.25), color)
	if style in [17, 18, 19]:
		for x in [-0.28, 0.28]:
			_box(parent, Vector3(0.14, 0.4 + 0.08 * float(style - 17), 0.14), head + Vector3(x, -0.13, back_z * 1.12), color)
	if style == 20:
		_box(parent, Vector3(0.3, 0.22, 0.28), head + Vector3(0, 0.5, back_z * 0.35), color)
		_box(parent, Vector3(0.2, 0.1, 0.2), head + Vector3(0, 0.65, back_z * 0.35), color.lightened(0.05))
	if style == 21:
		for x in [-0.22, 0.22]:
			_box(parent, Vector3(0.23, 0.2, 0.23), head + Vector3(x, 0.49, 0), color)
			_box(parent, Vector3(0.15, 0.08, 0.15), head + Vector3(x, 0.63, 0), color.lightened(0.05))

static func _add_outfit_details(parent: Node3D, style: int, y: float, torso: Vector3, color: Color) -> void:
	if style <= 0: return
	var front_surface := -torso.z * 0.5 - 0.022
	var light := color.lightened(0.18)
	var dark := color.darkened(0.24)
	match style:
		1: # T-shirt: simple neck and sleeve seam
			_outfit_wrap(parent, torso, y + torso.y * 0.43, 0.055, light)
		2: # Tank top
			for x in [-torso.x * 0.31, torso.x * 0.31]: _box(parent, Vector3(torso.x * 0.16, torso.y * 0.42, 0.035), Vector3(x, y + torso.y * 0.27, front_surface), dark)
			_box(parent, Vector3(torso.x * 0.42, 0.045, 0.035), Vector3(0, y + torso.y * 0.29, front_surface), dark)
		3: # Polo
			for x in [-torso.x * 0.13, torso.x * 0.13]: _box_rotated(parent, Vector3(torso.x * 0.3, 0.055, 0.035), Vector3(x, y + torso.y * 0.35, front_surface), light, Vector3(0, 0, 18.0 * signf(x)))
			_outfit_buttons(parent, y + torso.y * 0.2, front_surface, 2, dark)
		4: # Hoodie
			_box(parent, Vector3(torso.x * 0.68, torso.y * 0.2, 0.04), Vector3(0, y - torso.y * 0.22, front_surface), dark)
			for x in [-0.08, 0.08]: _box(parent, Vector3(0.025, torso.y * 0.28, 0.025), Vector3(x, y + torso.y * 0.25, front_surface), light)
		5: # Sweater
			_outfit_wrap(parent, torso, y + torso.y * 0.43, 0.075, light)
			_outfit_wrap(parent, torso, y - torso.y * 0.43, 0.075, dark)
		6: # Cardigan
			for x in [-0.055, 0.055]: _box(parent, Vector3(0.045, torso.y * 0.88, 0.035), Vector3(x, y, front_surface), light)
			_outfit_buttons(parent, y + torso.y * 0.18, front_surface, 4, dark)
		7: # Jacket
			_box(parent, Vector3(0.045, torso.y * 0.88, 0.04), Vector3(0, y, front_surface), light)
			for x in [-torso.x * 0.28, torso.x * 0.28]: _box(parent, Vector3(torso.x * 0.24, 0.06, 0.04), Vector3(x, y - torso.y * 0.18, front_surface), dark)
		8: # Leather jacket
			for x in [-torso.x * 0.16, torso.x * 0.16]: _box_rotated(parent, Vector3(torso.x * 0.48, 0.07, 0.04), Vector3(x, y + torso.y * 0.16, front_surface), dark, Vector3(0, 0, 48.0 * signf(x)))
			_outfit_wrap(parent, torso, y - torso.y * 0.43, 0.07, dark)
		9: # Denim jacket
			for x in [-torso.x * 0.25, torso.x * 0.25]: _box(parent, Vector3(torso.x * 0.28, torso.y * 0.18, 0.04), Vector3(x, y + torso.y * 0.02, front_surface), light)
			_box(parent, Vector3(0.035, torso.y * 0.86, 0.035), Vector3(0, y, front_surface), dark)
		10: # Vest
			for x in [-torso.x * 0.34, torso.x * 0.34]: _box(parent, Vector3(torso.x * 0.23, torso.y * 0.82, 0.04), Vector3(x, y - torso.y * 0.04, front_surface), dark)
		11: # Suit
			for x in [-torso.x * 0.17, torso.x * 0.17]: _box_rotated(parent, Vector3(torso.x * 0.48, 0.065, 0.04), Vector3(x, y + torso.y * 0.18, front_surface), light, Vector3(0, 0, 42.0 * signf(x)))
			_box(parent, Vector3(0.06, torso.y * 0.35, 0.04), Vector3(0, y + torso.y * 0.03, front_surface), dark)
		12: # Dress
			_box(parent, Vector3(torso.x * 1.18, torso.y * 0.42, torso.z * 1.08), Vector3(0, y - torso.y * 0.43, 0), light)
			_outfit_wrap(parent, torso, y - torso.y * 0.14, 0.055, dark)
		13: # Tunic
			_box(parent, Vector3(torso.x * 1.08, torso.y * 0.24, torso.z * 1.04), Vector3(0, y - torso.y * 0.46, 0), color)
			_outfit_wrap(parent, torso, y - torso.y * 0.16, 0.07, dark)
		14: # Overalls
			_box(parent, Vector3(torso.x * 0.66, torso.y * 0.48, 0.045), Vector3(0, y - torso.y * 0.13, front_surface), dark)
			for x in [-torso.x * 0.23, torso.x * 0.23]: _box(parent, Vector3(0.06, torso.y * 0.5, 0.04), Vector3(x, y + torso.y * 0.27, front_surface), dark)
		15: # Tracksuit
			for x in [-torso.x * 0.43, torso.x * 0.43]: _box(parent, Vector3(0.045, torso.y * 0.92, 0.04), Vector3(x, y, front_surface), light)
			_box(parent, Vector3(0.035, torso.y * 0.88, 0.035), Vector3(0, y, front_surface), dark)
		16: # Explorer
			for x in [-torso.x * 0.27, torso.x * 0.27]: _box(parent, Vector3(torso.x * 0.28, torso.y * 0.2, 0.045), Vector3(x, y + torso.y * 0.05, front_surface), light)
			_outfit_wrap(parent, torso, y - torso.y * 0.2, 0.075, dark)
		17: # Farmer
			_box(parent, Vector3(torso.x * 0.68, torso.y * 0.5, 0.045), Vector3(0, y - torso.y * 0.12, front_surface), dark)
			for x in [-torso.x * 0.24, torso.x * 0.24]: _box(parent, Vector3(0.055, torso.y * 0.5, 0.04), Vector3(x, y + torso.y * 0.28, front_surface), dark)
		18: # Knight
			_outfit_wrap(parent, torso, y + torso.y * 0.08, 0.11, light)
			_box(parent, Vector3(0.08, torso.y * 0.7, 0.05), Vector3(0, y, front_surface), dark)
			_box(parent, Vector3(torso.x * 0.72, 0.08, 0.05), Vector3(0, y + torso.y * 0.06, front_surface), dark)
		19: # Wizard
			_box_rotated(parent, Vector3(torso.x * 1.05, 0.1, 0.045), Vector3(0, y, front_surface), light, Vector3(0, 0, -24))
			for x in [-0.16, 0.1]: _box(parent, Vector3(0.045, 0.045, 0.04), Vector3(x, y + torso.y * 0.2, front_surface), Color(0.95, 0.8, 0.25))
		20: # Pirate
			_box_rotated(parent, Vector3(torso.x * 1.08, 0.11, 0.045), Vector3(0, y + torso.y * 0.05, front_surface), dark, Vector3(0, 0, 24))
			_outfit_wrap(parent, torso, y - torso.y * 0.28, 0.09, Color(0.45, 0.18, 0.08))
		21: # Ninja
			for angle in [-30.0, 30.0]: _box_rotated(parent, Vector3(torso.x * 0.95, 0.075, 0.04), Vector3(0, y + torso.y * 0.08, front_surface), dark, Vector3(0, 0, angle))
		22: # Royal
			_box(parent, Vector3(torso.x * 0.18, torso.y * 0.9, 0.05), Vector3(0, y, front_surface), Color(0.9, 0.7, 0.18))
			_outfit_wrap(parent, torso, y + torso.y * 0.3, 0.085, light)
			_outfit_buttons(parent, y + torso.y * 0.12, front_surface, 3, Color(0.95, 0.78, 0.2))
		23: # Winter coat
			_outfit_wrap(parent, torso, y + torso.y * 0.4, 0.13, Color(0.9, 0.9, 0.86))
			_outfit_wrap(parent, torso, y - torso.y * 0.42, 0.09, dark)
			_outfit_buttons(parent, y + torso.y * 0.15, front_surface, 4, light)

static func _outfit_wrap(parent: Node3D, torso: Vector3, y: float, height: float, color: Color) -> void:
	_box(parent, Vector3(torso.x + 0.035, height, torso.z + 0.035), Vector3(0, y, 0), color)

static func _outfit_buttons(parent: Node3D, start_y: float, z: float, count: int, color: Color) -> void:
	for i in range(count): _box(parent, Vector3(0.035, 0.035, 0.025), Vector3(0, start_y - i * 0.085, z), color)

static func _add_back_cosmetics(parent: Node3D, skin: Dictionary, y: float, torso: Vector3, head_y: float, back_z: float) -> void:
	var cape := int(skin.get("cape_style", 0))
	var cape_color: Color = skin.get("cape_color", Color.RED)
	if cape > 0:
		var cape_w := torso.x * (0.76 + 0.035 * float(cape % 6)); var cape_h := torso.y * (0.62 + 0.055 * float(cape % 7))
		if cape in [4, 8, 10, 15, 18]:
			for x in [-cape_w * 0.27, cape_w * 0.27]: _box(parent, Vector3(cape_w * 0.46, cape_h, 0.055), Vector3(x, y - 0.08, back_z * 0.82), cape_color)
		else: _box(parent, Vector3(cape_w, cape_h, 0.055), Vector3(0, y - 0.08, back_z * 0.82), cape_color)
		_box(parent, Vector3(torso.x + 0.08, 0.09, torso.z + 0.08), Vector3(0, y + torso.y * 0.44, 0), cape_color.darkened(0.18))
	_add_hood(parent, int(skin.get("hood_style", 0)), head_y, back_z, skin.get("hood_color", Color.DARK_GRAY))
	_add_hat(parent, int(skin.get("cap_style", 0)), head_y, skin.get("cap_color", Color.BLUE))

static func _add_hood(parent: Node3D, style: int, head_y: float, back_z: float, color: Color) -> void:
	if style <= 0: return
	var shell_h := 0.16 + 0.018 * float(style % 5)
	_box(parent, Vector3(0.63 + 0.012 * float(style % 3), shell_h, 0.63), Vector3(0, head_y + 0.27, 0), color)
	_box(parent, Vector3(0.62, 0.34 + 0.025 * float(style % 4), 0.12), Vector3(0, head_y + 0.06, back_z), color)
	if style in [2, 5, 8, 9, 12, 14, 18, 19]:
		for x in [-0.305, 0.305]: _box(parent, Vector3(0.08, 0.34, 0.5), Vector3(x, head_y + 0.05, 0.04), color)
	if style in [4, 9, 10, 17, 19, 20]: _box(parent, Vector3(0.18, 0.18 + 0.035 * float(style % 4), 0.18), Vector3(0, head_y + 0.48, back_z * 0.25), color)

static func _add_hat(parent: Node3D, style: int, head_y: float, color: Color) -> void:
	if style <= 0: return
	var crown_h := 0.11 + 0.035 * float(style % 5)
	var crown_w := 0.46 + 0.025 * float(style % 4)
	match style:
		1, 2, 3, 4, 18, 19, 20:
			_box(parent, Vector3(crown_w, crown_h, 0.54), Vector3(0, head_y + 0.36 + crown_h * 0.5, 0), color)
			_box(parent, Vector3(0.68 if style != 2 else 0.58, 0.045, 0.7 if style in [4, 18] else 0.62), Vector3(0, head_y + 0.35, -0.04), color.darkened(0.1))
		5, 6, 7, 8, 9, 17:
			_box(parent, Vector3(0.48, 0.18 + 0.045 * float(style % 4), 0.48), Vector3(0, head_y + 0.46, 0), color)
			_box(parent, Vector3(0.74, 0.05, 0.74), Vector3(0, head_y + 0.35, 0), color.darkened(0.12))
		10, 11, 12, 13, 14, 15, 16:
			_box(parent, Vector3(0.56, 0.12, 0.56), Vector3(0, head_y + 0.4, 0), color)
			for x in range(-2, 3): _box(parent, Vector3(0.075, 0.1 + 0.055 * float((style + x + 8) % 4), 0.075), Vector3(x * 0.1, head_y + 0.51, 0), color.lightened(0.12))

static func _add_beard(parent: Node3D, style: int, y: float, front: float, color: Color) -> void:
	if style <= 0: return
	var z := front - 0.018
	var dark := color.darkened(0.14)
	match style:
		1: # Stubble: separate pixel marks instead of a solid beard block.
			for x in [-0.19, -0.1, 0.1, 0.19]:
				_box(parent, Vector3(0.045, 0.035, 0.022), Vector3(x, y - 0.135, z), dark)
			for x in [-0.14, -0.045, 0.045, 0.14]:
				_box(parent, Vector3(0.04, 0.035, 0.022), Vector3(x, y - 0.205, z), dark)
		2: # Goatee: narrow moustache and a distinct central chin strip.
			for x in [-0.07, 0.07]:
				_box_rotated(parent, Vector3(0.13, 0.035, 0.024), Vector3(x, y - 0.105, z), color, Vector3(0, 0, 8.0 * signf(x)))
			_box(parent, Vector3(0.13, 0.16, 0.026), Vector3(0, y - 0.225, z - 0.002), color)
		3: # Full beard: cheeks connect cleanly to a wide Minecraft chin band.
			for x in [-0.205, 0.205]:
				_box(parent, Vector3(0.1, 0.2, 0.027), Vector3(x, y - 0.18, z), color)
			_box(parent, Vector3(0.49, 0.115, 0.028), Vector3(0, y - 0.285, z), color)
			_box(parent, Vector3(0.22, 0.055, 0.029), Vector3(0, y - 0.12, z), dark)
		4: # Long beard: stepped/tapered layers keep the block-art silhouette.
			for x in [-0.205, 0.205]:
				_box(parent, Vector3(0.1, 0.19, 0.027), Vector3(x, y - 0.18, z), color)
			_box(parent, Vector3(0.48, 0.13, 0.03), Vector3(0, y - 0.285, z), color)
			_box(parent, Vector3(0.34, 0.11, 0.032), Vector3(0, y - 0.395, z), color)
			_box(parent, Vector3(0.2, 0.09, 0.034), Vector3(0, y - 0.485, z), dark)
		5: # Moustache: two clean angled pixel strips, no beard underneath.
			for x in [-0.085, 0.085]:
				_box_rotated(parent, Vector3(0.18, 0.045, 0.027), Vector3(x, y - 0.11, z), color, Vector3(0, 0, 10.0 * signf(x)))

static func _add_glasses(parent: Node3D, style: int, y: float, front: float) -> void:
	if style <= 0: return
	var frame := Color(0.06, 0.06, 0.07); var lens_w := 0.15 + 0.012 * float(style % 3); var lens_h := 0.09 + 0.018 * float((style + 1) % 3)
	for x in [-0.14, 0.14]:
		_box(parent, Vector3(lens_w, 0.025, 0.035), Vector3(x, y + 0.07 + lens_h * 0.5, front * 1.03), frame)
		_box(parent, Vector3(lens_w, 0.025, 0.035), Vector3(x, y + 0.07 - lens_h * 0.5, front * 1.03), frame)
		_box(parent, Vector3(0.025, lens_h, 0.035), Vector3(x - lens_w * 0.5, y + 0.07, front * 1.03), frame)
		_box(parent, Vector3(0.025, lens_h, 0.035), Vector3(x + lens_w * 0.5, y + 0.07, front * 1.03), frame)
	_box(parent, Vector3(0.1, 0.025, 0.035), Vector3(0, y + 0.07, front * 1.03), frame)
	for x in [-0.29, 0.29]: _box(parent, Vector3(0.035, 0.035, 0.48), Vector3(x, y + 0.08, 0), frame)

static func _pixels_to_texture(raw: Array, base_color: Color) -> ImageTexture:
	if raw.size() < 256: return null
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var value: Array = raw[y * 16 + x]
			var painted := Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
			image.set_pixel(x, y, painted if painted.a > 0.0 else base_color)
	return ImageTexture.create_from_image(image)

static func _limb(parent: Node3D, limb_name: String, size: Vector3, pivot_pos: Vector3, offset: Vector3, color: Color) -> void:
	var pivot := Node3D.new(); pivot.name = limb_name; pivot.position = pivot_pos; parent.add_child(pivot); _box(pivot, size, offset, color)

static func _leg_with_foot(parent: Node3D, limb_name: String, leg_size: Vector3, foot_size: Vector3, pivot_pos: Vector3, color: Color) -> void:
	var pivot := Node3D.new()
	pivot.name = limb_name
	pivot.position = pivot_pos
	parent.add_child(pivot)
	_box(pivot, leg_size, Vector3(0, -leg_size.y * 0.5, 0), color)
	# Front is -Z. Keep the heel aligned with the leg and extend only the toe.
	var foot_y := -pivot_pos.y + foot_size.y * 0.5
	var foot_z := -(foot_size.z - leg_size.z) * 0.5
	_box(pivot, foot_size, Vector3(0, foot_y, foot_z), color.darkened(0.08))

static func _arm_limb(parent: Node3D, limb_name: String, size: Vector3, pivot_pos: Vector3, skin: Color, shirt: Color, sleeve_ratio: float) -> void:
	var pivot := Node3D.new(); pivot.name = limb_name; pivot.position = pivot_pos; parent.add_child(pivot)
	var sleeve_h := size.y * clampf(sleeve_ratio, 0.2, 0.65)
	var bare_h := size.y - sleeve_h
	_box(pivot, Vector3(size.x * 1.08, sleeve_h, size.z * 1.08), Vector3(0, -sleeve_h * 0.5, 0), shirt)
	_box(pivot, Vector3(size.x, bare_h, size.z), Vector3(0, -sleeve_h - bare_h * 0.5, 0), skin)

static func _box_rotated(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rotation_deg: Vector3, texture: Texture2D = null) -> void:
	var instance := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size; instance.mesh = mesh
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if texture: material.albedo_texture = texture
	instance.material_override = material; instance.position = pos; instance.rotation_degrees = rotation_deg; parent.add_child(instance)

static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, texture: Texture2D = null) -> void:
	var instance := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size; instance.mesh = mesh
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if texture: material.albedo_texture = texture
	instance.material_override = material; instance.position = pos; parent.add_child(instance)

static func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new(); var mesh := SphereMesh.new(); mesh.radius = radius; mesh.height = radius * 1.3; instance.mesh = mesh
	var material := StandardMaterial3D.new(); material.albedo_color = color; instance.material_override = material; instance.position = pos; parent.add_child(instance)
