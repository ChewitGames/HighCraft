class_name MobModelFactory
extends RefCounted
## Unique box-model silhouettes for every HighCraft mob.

static func build(host: Node3D, mob_id: String, mat: StandardMaterial3D, model: Dictionary) -> String:
	var mtype := str(model.get("type", "biped"))
	match mob_id:
		"cow":
			_cow(host, mat, false); return "walk_quad"
		"mooshroom":
			_cow(host, mat, true); return "walk_quad"
		"pig":
			_pig(host, mat); return "walk_quad"
		"sheep":
			_sheep(host, mat); return "walk_quad"
		"wolf":
			_wolf(host, mat); return "walk_quad"
		"horse":
			_horse(host, mat); return "gallop"
		"ocelot":
			_ocelot(host, mat); return "sneak"
		"rabbit":
			_rabbit(host, mat); return "hop"
		"chicken":
			_chicken(host, mat); return "flap"
		"squid":
			_squid(host, mat); return "float"
		"bat":
			_bat(host, mat); return "flap"
		"villager":
			_villager(host, mat, false); return "walk_biped"
		"zombie_villager":
			_villager(host, mat, true); return "walk_zombie"
		"witch":
			_witch(host, mat); return "walk_biped"
		"zombie", "husk":
			_zombie(host, mat, mob_id == "husk"); return "walk_zombie"
		"skeleton", "stray":
			_skeleton(host, mat, mob_id == "stray", false); return "walk_biped"
		"wither_skeleton":
			_skeleton(host, mat, false, true); return "walk_biped"
		"zombie_pigman":
			_pigman(host, mat); return "walk_zombie"
		"erebite", "erebus_foreigner":
			_enderman(host, mat); return "walk_enderman"
		"creeper":
			_creeper(host, mat, false); return "walk_creeper"
		"hero_no_brain":
			_creeper(host, mat, true); return "walk_creeper"
		"spider":
			_spider(host, mat, 1.0, Color(0.7, 0.08, 0.08)); return "crawl"
		"cave_spider":
			_spider(host, mat, 0.72, Color(0.15, 0.7, 0.2)); return "crawl"
		"slime":
			_slime(host, mat, false); return "hop"
		"magma_cube":
			_slime(host, mat, true); return "hop"
		"silverfish":
			_bug(host, mat, Color(0.55, 0.55, 0.6), 1.0); return "crawl"
		"endermite":
			_bug(host, mat, Color(0.45, 0.15, 0.55), 0.7); return "crawl"
		"blaze":
			_blaze(host, mat); return "float"
		"soulwraith":
			_ghast(host, mat, true); return "float"
		"shulker":
			_shulker(host, mat); return "idle"
		"snow_golem":
			_snow_golem(host, mat); return "walk_biped"
		"iron_golem":
			_iron_golem(host, mat); return "walk_biped"
		"wither":
			_wither(host, mat); return "float"
		"ender_dragon", "erebus_sovereign":
			_dragon(host, mat); return "fly_dragon"
		"charlie_emily":
			_charlie(host, mat); return "walk_biped"
	if mob_id in ["chaos", "gaia", "tartaros", "nyx", "erebos", "aither", "hemera", "uranos", "chronos", "ananke",
			"zeus", "poseidon", "hades", "athena", "ares", "hera", "demeter", "hestia", "apollon", "artemis",
			"aphrodite", "hephaistos", "hermes", "dionysos", "eidorian_ushiha", "mania_hedgehog",
			"erebos_demon", "angel_warden", "demon_reaver"]:
		_god(host, mat, mob_id)
		return "walk_biped"
	if mtype == "quadruped":
		_cow(host, mat, false)
		return "walk_quad"
	_zombie(host, mat, false)
	return "walk_biped"


static func _box(host: Node3D, name: String, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = name
	var m := BoxMesh.new()
	m.size = size
	n.mesh = m
	n.material_override = mat
	n.position = pos
	n.rotation_degrees = rot
	host.add_child(n)
	return n


static func _col(rgb: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = rgb
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = rgb
		m.emission_energy_multiplier = emit
	return m


static func _eyes(host: Node3D, origin: Vector3, spread: float, col: Color, size := 0.08) -> void:
	var em := _col(col, 1.4)
	for z in [-spread, spread]:
		_box(host, "eye", Vector3(size, size, size), origin + Vector3(0, 0, z), em)


# ---------- animals ----------
static func _cow(host: Node3D, mat: Material, mushroom: bool) -> void:
	_box(host, "anim_body", Vector3(1.7, 0.85, 0.95), Vector3(0, 0.95, 0), mat)
	_box(host, "anim_head", Vector3(0.55, 0.5, 0.5), Vector3(0.95, 1.25, 0), mat)
	_box(host, "snout", Vector3(0.22, 0.2, 0.32), Vector3(1.28, 1.12, 0), mat)
	for s in [-1, 1]:
		_box(host, "horn", Vector3(0.08, 0.22, 0.08), Vector3(0.85, 1.55, s * 0.18), mat)
	_box(host, "udder", Vector3(0.35, 0.22, 0.28), Vector3(-0.15, 0.48, 0), _col(Color(0.95, 0.75, 0.8)))
	for i in range(4):
		var x := 0.55 if i < 2 else -0.55
		var z := 0.28 if i % 2 == 0 else -0.28
		_box(host, "anim_leg_%d" % i, Vector3(0.22, 0.7, 0.22), Vector3(x, 0.35, z), mat)
	if mushroom:
		var red := _col(Color(0.75, 0.12, 0.1))
		_box(host, "mush0", Vector3(0.28, 0.22, 0.28), Vector3(0.2, 1.48, 0.15), red)
		_box(host, "mush1", Vector3(0.22, 0.18, 0.22), Vector3(-0.35, 1.45, -0.1), red)


static func _pig(host: Node3D, mat: Material) -> void:
	_box(host, "anim_body", Vector3(1.15, 0.7, 0.75), Vector3(0, 0.7, 0), mat)
	_box(host, "anim_head", Vector3(0.5, 0.45, 0.5), Vector3(0.7, 0.85, 0), mat)
	_box(host, "snout", Vector3(0.16, 0.16, 0.28), Vector3(1.0, 0.78, 0), _col(Color(1.0, 0.7, 0.7)))
	_box(host, "anim_tail", Vector3(0.12, 0.12, 0.22), Vector3(-0.62, 0.85, 0), mat)
	for i in range(4):
		var x := 0.35 if i < 2 else -0.35
		var z := 0.22 if i % 2 == 0 else -0.22
		_box(host, "anim_leg_%d" % i, Vector3(0.18, 0.4, 0.18), Vector3(x, 0.22, z), mat)


static func _sheep(host: Node3D, mat: Material) -> void:
	var wool := _col(Color(0.95, 0.95, 0.97))
	_box(host, "anim_body", Vector3(1.25, 0.95, 0.85), Vector3(0, 0.95, 0), wool)
	_box(host, "anim_head", Vector3(0.42, 0.38, 0.38), Vector3(0.78, 1.05, 0), mat)
	for i in range(4):
		var x := 0.38 if i < 2 else -0.38
		var z := 0.24 if i % 2 == 0 else -0.24
		_box(host, "anim_leg_%d" % i, Vector3(0.18, 0.5, 0.18), Vector3(x, 0.28, z), mat)


static func _wolf(host: Node3D, mat: Material) -> void:
	_box(host, "anim_body", Vector3(1.05, 0.48, 0.42), Vector3(0, 0.62, 0), mat)
	_box(host, "anim_head", Vector3(0.38, 0.34, 0.34), Vector3(0.62, 0.78, 0), mat)
	_box(host, "snout", Vector3(0.28, 0.16, 0.18), Vector3(0.9, 0.7, 0), mat)
	for s in [-1, 1]:
		_box(host, "ear", Vector3(0.1, 0.16, 0.08), Vector3(0.55, 1.02, s * 0.12), mat)
	_box(host, "anim_tail", Vector3(0.45, 0.12, 0.12), Vector3(-0.7, 0.75, 0), mat, Vector3(0, 0, 25))
	for i in range(4):
		var x := 0.32 if i < 2 else -0.32
		var z := 0.14 if i % 2 == 0 else -0.14
		_box(host, "anim_leg_%d" % i, Vector3(0.14, 0.5, 0.14), Vector3(x, 0.28, z), mat)


static func _horse(host: Node3D, mat: Material) -> void:
	_box(host, "anim_body", Vector3(1.7, 0.7, 0.6), Vector3(0, 1.15, 0), mat)
	_box(host, "neck", Vector3(0.32, 0.7, 0.32), Vector3(0.75, 1.55, 0), mat, Vector3(0, 0, -20))
	_box(host, "anim_head", Vector3(0.38, 0.28, 0.28), Vector3(1.05, 1.95, 0), mat)
	_box(host, "snout", Vector3(0.32, 0.18, 0.2), Vector3(1.32, 1.88, 0), mat)
	_box(host, "anim_tail", Vector3(0.55, 0.14, 0.14), Vector3(-0.95, 1.15, 0), mat, Vector3(0, 0, 30))
	for i in range(4):
		var x := 0.55 if i < 2 else -0.55
		var z := 0.18 if i % 2 == 0 else -0.18
		_box(host, "anim_leg_%d" % i, Vector3(0.16, 1.0, 0.16), Vector3(x, 0.5, z), mat)


static func _ocelot(host: Node3D, mat: Material) -> void:
	_box(host, "anim_body", Vector3(1.05, 0.32, 0.34), Vector3(0, 0.42, 0), mat)
	_box(host, "anim_head", Vector3(0.3, 0.26, 0.28), Vector3(0.58, 0.52, 0), mat)
	for s in [-1, 1]:
		_box(host, "ear", Vector3(0.08, 0.12, 0.06), Vector3(0.52, 0.7, s * 0.1), mat)
	_box(host, "anim_tail", Vector3(0.7, 0.08, 0.08), Vector3(-0.75, 0.48, 0), mat)
	var spot := _col(Color(0.35, 0.2, 0.08))
	_box(host, "spot0", Vector3(0.1, 0.08, 0.1), Vector3(0.15, 0.58, 0.12), spot)
	_box(host, "spot1", Vector3(0.1, 0.08, 0.1), Vector3(-0.2, 0.58, -0.1), spot)
	for i in range(4):
		var x := 0.32 if i < 2 else -0.32
		var z := 0.1 if i % 2 == 0 else -0.1
		_box(host, "anim_leg_%d" % i, Vector3(0.1, 0.36, 0.1), Vector3(x, 0.2, z), mat)


static func _rabbit(host: Node3D, mat: Material) -> void:
	_box(host, "anim_body", Vector3(0.5, 0.32, 0.32), Vector3(0, 0.32, 0), mat)
	_box(host, "anim_head", Vector3(0.24, 0.22, 0.22), Vector3(0.28, 0.48, 0), mat)
	for s in [-1, 1]:
		_box(host, "ear", Vector3(0.07, 0.32, 0.06), Vector3(0.22, 0.72, s * 0.07), mat)
	_box(host, "anim_leg_0", Vector3(0.16, 0.28, 0.14), Vector3(-0.12, 0.16, 0.1), mat)
	_box(host, "anim_leg_1", Vector3(0.16, 0.28, 0.14), Vector3(-0.12, 0.16, -0.1), mat)
	_box(host, "anim_leg_2", Vector3(0.1, 0.2, 0.1), Vector3(0.18, 0.12, 0.08), mat)
	_box(host, "anim_leg_3", Vector3(0.1, 0.2, 0.1), Vector3(0.18, 0.12, -0.08), mat)


static func _chicken(host: Node3D, mat: Material) -> void:
	_box(host, "anim_body", Vector3(0.5, 0.4, 0.42), Vector3(0, 0.55, 0), mat)
	_box(host, "anim_head", Vector3(0.26, 0.26, 0.26), Vector3(0.28, 0.85, 0), mat)
	_box(host, "beak", Vector3(0.14, 0.08, 0.1), Vector3(0.46, 0.82, 0), _col(Color(1.0, 0.7, 0.1)))
	_box(host, "comb", Vector3(0.08, 0.12, 0.08), Vector3(0.28, 1.02, 0), _col(Color(0.85, 0.1, 0.1)))
	_box(host, "anim_wing_0", Vector3(0.12, 0.28, 0.36), Vector3(0, 0.58, 0.28), mat)
	_box(host, "anim_wing_1", Vector3(0.12, 0.28, 0.36), Vector3(0, 0.58, -0.28), mat)
	_box(host, "anim_leg_0", Vector3(0.08, 0.32, 0.08), Vector3(0.06, 0.18, 0.08), _col(Color(0.95, 0.7, 0.15)))
	_box(host, "anim_leg_1", Vector3(0.08, 0.32, 0.08), Vector3(0.06, 0.18, -0.08), _col(Color(0.95, 0.7, 0.15)))


static func _squid(host: Node3D, mat: Material) -> void:
	_box(host, "anim_body", Vector3(0.85, 1.0, 0.85), Vector3(0, 0.9, 0), mat)
	_eyes(host, Vector3(0.4, 1.05, 0), 0.18, Color(0.1, 0.9, 0.7))
	for i in range(8):
		var a := float(i) * TAU / 8.0
		_box(host, "anim_leg_%d" % i, Vector3(0.12, 1.2, 0.12), Vector3(cos(a) * 0.28, 0.15, sin(a) * 0.28), mat)


static func _bat(host: Node3D, mat: Material) -> void:
	_box(host, "anim_body", Vector3(0.28, 0.28, 0.22), Vector3(0, 0.4, 0), mat)
	_box(host, "anim_head", Vector3(0.22, 0.2, 0.2), Vector3(0.18, 0.52, 0), mat)
	_box(host, "anim_wing_0", Vector3(0.08, 0.55, 0.7), Vector3(0, 0.45, 0.45), mat)
	_box(host, "anim_wing_1", Vector3(0.08, 0.55, 0.7), Vector3(0, 0.45, -0.45), mat)


# ---------- humanoids ----------
static func _zombie(host: Node3D, mat: Material, husk: bool) -> void:
	var body_h := 1.15 if husk else 1.05
	_box(host, "anim_body", Vector3(0.55, body_h, 0.32), Vector3(0, 1.05, 0), mat)
	_box(host, "anim_head", Vector3(0.5, 0.5, 0.5), Vector3(0, 1.82 if husk else 1.72, 0), mat)
	_eyes(host, Vector3(0.26, 1.85 if husk else 1.75, 0), 0.12, Color(0.2, 0.55, 0.15))
	# Arms stretched forward
	_box(host, "anim_arm_0", Vector3(0.22, 0.85, 0.22), Vector3(-0.4, 1.25, 0.28), mat, Vector3(-80, 0, 0))
	_box(host, "anim_arm_1", Vector3(0.22, 0.85, 0.22), Vector3(0.4, 1.25, 0.28), mat, Vector3(-80, 0, 0))
	_box(host, "anim_leg_0", Vector3(0.24, 0.8, 0.24), Vector3(-0.14, 0.4, 0), mat)
	_box(host, "anim_leg_1", Vector3(0.24, 0.8, 0.24), Vector3(0.14, 0.4, 0), mat)


static func _skeleton(host: Node3D, mat: Material, stray: bool, wither: bool) -> void:
	var scale_y := 1.2 if wither else 1.0
	_box(host, "anim_body", Vector3(0.38, 0.95 * scale_y, 0.24), Vector3(0, 1.15 * scale_y, 0), mat)
	_box(host, "anim_head", Vector3(0.48, 0.48, 0.48), Vector3(0, 1.85 * scale_y, 0), mat)
	_eyes(host, Vector3(0.25, 1.88 * scale_y, 0), 0.12, Color(0.1, 0.9, 1.0) if not wither else Color(1.0, 0.85, 0.2))
	_box(host, "anim_arm_0", Vector3(0.14, 0.85, 0.14), Vector3(-0.32, 1.25 * scale_y, 0), mat)
	_box(host, "anim_arm_1", Vector3(0.14, 0.85, 0.14), Vector3(0.32, 1.25 * scale_y, 0), mat)
	_box(host, "anim_leg_0", Vector3(0.14, 0.85, 0.14), Vector3(-0.1, 0.42, 0), mat)
	_box(host, "anim_leg_1", Vector3(0.14, 0.85, 0.14), Vector3(0.1, 0.42, 0), mat)
	if stray:
		_box(host, "cloak", Vector3(0.5, 0.7, 0.18), Vector3(0, 1.35, -0.2), _col(Color(0.55, 0.7, 0.8)))
	# bow / sword
	var tool := _col(Color(0.45, 0.28, 0.12) if not wither else Color(0.25, 0.25, 0.28))
	_box(host, "weapon", Vector3(0.08, 0.7, 0.08) if wither else Vector3(0.08, 0.55, 0.22), Vector3(0.42, 1.15 * scale_y, 0.25), tool)


static func _villager(host: Node3D, mat: Material, zombie: bool) -> void:
	var robe := _col(Color(0.45, 0.32, 0.18) if not zombie else Color(0.28, 0.4, 0.22))
	_box(host, "anim_body", Vector3(0.55, 1.15, 0.4), Vector3(0, 0.95, 0), robe)
	_box(host, "anim_head", Vector3(0.5, 0.5, 0.5), Vector3(0, 1.72, 0), mat)
	_box(host, "nose", Vector3(0.12, 0.18, 0.22), Vector3(0.28, 1.62, 0), mat)
	_box(host, "brow", Vector3(0.5, 0.12, 0.12), Vector3(0, 1.88, 0.18), mat)
	_box(host, "anim_leg_0", Vector3(0.2, 0.45, 0.2), Vector3(-0.12, 0.22, 0), robe)
	_box(host, "anim_leg_1", Vector3(0.2, 0.45, 0.2), Vector3(0.12, 0.22, 0), robe)
	if zombie:
		_box(host, "anim_arm_0", Vector3(0.2, 0.7, 0.2), Vector3(-0.4, 1.15, 0.2), mat, Vector3(-70, 0, 0))
		_box(host, "anim_arm_1", Vector3(0.2, 0.7, 0.2), Vector3(0.4, 1.15, 0.2), mat, Vector3(-70, 0, 0))


static func _witch(host: Node3D, mat: Material) -> void:
	_villager(host, mat, false)
	var hat := _col(Color(0.18, 0.12, 0.22))
	_box(host, "hat_brim", Vector3(0.85, 0.08, 0.85), Vector3(0, 2.0, 0), hat)
	_box(host, "hat_cone", Vector3(0.32, 0.55, 0.32), Vector3(0, 2.3, 0), hat)
	_box(host, "wart", Vector3(0.1, 0.1, 0.1), Vector3(0.3, 1.55, 0.12), _col(Color(0.35, 0.55, 0.2)))


static func _pigman(host: Node3D, mat: Material) -> void:
	_box(host, "anim_body", Vector3(0.55, 1.05, 0.32), Vector3(0, 1.05, 0), mat)
	_box(host, "anim_head", Vector3(0.5, 0.45, 0.5), Vector3(0, 1.72, 0), mat)
	_box(host, "snout", Vector3(0.18, 0.16, 0.28), Vector3(0.32, 1.62, 0), mat)
	for s in [-1, 1]:
		_box(host, "ear", Vector3(0.08, 0.16, 0.14), Vector3(0.05, 1.95, s * 0.28), mat)
	_box(host, "anim_arm_0", Vector3(0.22, 0.8, 0.22), Vector3(-0.4, 1.2, 0.22), mat, Vector3(-70, 0, 0))
	_box(host, "anim_arm_1", Vector3(0.22, 0.8, 0.22), Vector3(0.4, 1.2, 0.22), mat, Vector3(-70, 0, 0))
	_box(host, "sword", Vector3(0.08, 0.7, 0.08), Vector3(0.5, 1.05, 0.4), _col(Color(0.95, 0.8, 0.2)))
	_box(host, "anim_leg_0", Vector3(0.24, 0.75, 0.24), Vector3(-0.14, 0.38, 0), mat)
	_box(host, "anim_leg_1", Vector3(0.24, 0.75, 0.24), Vector3(0.14, 0.38, 0), mat)


static func _enderman(host: Node3D, mat: Material) -> void:
	_box(host, "anim_body", Vector3(0.38, 1.4, 0.28), Vector3(0, 1.4, 0), mat)
	_box(host, "anim_head", Vector3(0.42, 0.42, 0.42), Vector3(0, 2.25, 0), mat)
	_eyes(host, Vector3(0.22, 2.25, 0), 0.1, Color(0.85, 0.2, 0.95), 0.07)
	_box(host, "anim_arm_0", Vector3(0.14, 1.35, 0.14), Vector3(-0.32, 1.25, 0), mat)
	_box(host, "anim_arm_1", Vector3(0.14, 1.35, 0.14), Vector3(0.32, 1.25, 0), mat)
	_box(host, "anim_leg_0", Vector3(0.14, 1.1, 0.14), Vector3(-0.1, 0.55, 0), mat)
	_box(host, "anim_leg_1", Vector3(0.14, 1.1, 0.14), Vector3(0.1, 0.55, 0), mat)


static func _charlie(host: Node3D, mat: Material) -> void:
	_box(host, "anim_body", Vector3(0.48, 0.95, 0.3), Vector3(0, 0.95, 0), mat)
	_box(host, "anim_head", Vector3(0.42, 0.42, 0.42), Vector3(0, 1.6, 0), mat)
	_box(host, "anim_arm_0", Vector3(0.18, 0.7, 0.18), Vector3(-0.36, 1.15, 0), mat)
	_box(host, "anim_arm_1", Vector3(0.18, 0.7, 0.18), Vector3(0.36, 1.15, 0), mat)
	_box(host, "anim_leg_0", Vector3(0.2, 0.7, 0.2), Vector3(-0.12, 0.35, 0), mat)
	_box(host, "anim_leg_1", Vector3(0.2, 0.7, 0.2), Vector3(0.12, 0.35, 0), mat)
	var rose := _col(Color(0.85, 0.1, 0.18), 0.4)
	_box(host, "rose", Vector3(0.12, 0.12, 0.12), Vector3(0.4, 0.85, 0.18), rose)
	_box(host, "stem", Vector3(0.05, 0.2, 0.05), Vector3(0.4, 0.7, 0.18), _col(Color(0.15, 0.45, 0.12)))


static func _creeper(host: Node3D, mat: Material, hero: bool) -> void:
	var head_s := 0.85 if hero else 0.52
	_box(host, "anim_body", Vector3(0.5, 1.15 if not hero else 0.7, 0.4), Vector3(0, 0.85, 0), mat)
	_box(host, "anim_head", Vector3(head_s, head_s, head_s), Vector3(0, 1.7 if not hero else 1.45, 0), mat)
	for i in range(4):
		var x := -0.18 if i < 2 else 0.18
		var z := -0.14 if i % 2 == 0 else 0.14
		_box(host, "anim_leg_%d" % i, Vector3(0.18, 0.45, 0.18), Vector3(x, 0.22, z), mat)


static func _spider(host: Node3D, mat: Material, sc: float, eye_col: Color) -> void:
	_box(host, "anim_body", Vector3(0.85 * sc, 0.45 * sc, 0.7 * sc), Vector3(-0.15 * sc, 0.45 * sc, 0), mat)
	_box(host, "anim_head", Vector3(0.5 * sc, 0.4 * sc, 0.5 * sc), Vector3(0.45 * sc, 0.48 * sc, 0), mat)
	_eyes(host, Vector3(0.7 * sc, 0.52 * sc, 0), 0.12 * sc, eye_col, 0.07 * sc)
	for i in range(8):
		var side := -1.0 if i < 4 else 1.0
		var t := float(i % 4) - 1.5
		_box(host, "anim_leg_%d" % i, Vector3(0.12 * sc, 0.12 * sc, 0.7 * sc), Vector3(t * 0.12 * sc, 0.38 * sc, side * 0.55 * sc), mat, Vector3(0, side * 25.0, 20.0 * t))


static func _slime(host: Node3D, mat: Material, magma: bool) -> void:
	_box(host, "anim_body", Vector3(1.05, 1.05, 1.05), Vector3(0, 0.55, 0), mat)
	var inner := _col(Color(0.35, 0.7, 0.25, 0.7) if not magma else Color(1.0, 0.45, 0.1), 1.2 if magma else 0.4)
	_box(host, "core", Vector3(0.55, 0.55, 0.55), Vector3(0, 0.55, 0), inner)
	_eyes(host, Vector3(0.5, 0.7, 0), 0.18, Color(0.05, 0.05, 0.05) if not magma else Color(1.0, 0.9, 0.3), 0.12)


static func _bug(host: Node3D, mat: Material, col: Color, sc: float) -> void:
	var m := _col(col)
	_box(host, "anim_head", Vector3(0.22 * sc, 0.16 * sc, 0.18 * sc), Vector3(0.28 * sc, 0.16 * sc, 0), m)
	_box(host, "anim_body", Vector3(0.32 * sc, 0.16 * sc, 0.2 * sc), Vector3(0, 0.16 * sc, 0), m)
	_box(host, "tail", Vector3(0.28 * sc, 0.14 * sc, 0.16 * sc), Vector3(-0.26 * sc, 0.14 * sc, 0), m)
	for i in range(6):
		var x := 0.12 - float(i % 3) * 0.12
		var z := 0.16 if i < 3 else -0.16
		_box(host, "anim_leg_%d" % i, Vector3(0.05 * sc, 0.12 * sc, 0.16 * sc), Vector3(x * sc, 0.08 * sc, z * sc), m)


static func _blaze(host: Node3D, mat: Material) -> void:
	var head := _col(Color(1.0, 0.75, 0.15), 1.6)
	_box(host, "anim_head", Vector3(0.5, 0.5, 0.5), Vector3(0, 1.35, 0), head)
	_eyes(host, Vector3(0.26, 1.38, 0), 0.12, Color(0.1, 0.05, 0.0))
	for i in range(8):
		var a := float(i) * TAU / 8.0
		var r := 0.55 if i % 2 == 0 else 0.75
		_box(host, "anim_leg_%d" % i, Vector3(0.1, 1.1, 0.1), Vector3(cos(a) * r, 0.85, sin(a) * r), mat)


static func _ghast(host: Node3D, mat: Material, wraith: bool) -> void:
	_box(host, "anim_body", Vector3(2.0, 1.7, 2.0), Vector3(0, 1.4, 0), mat)
	_eyes(host, Vector3(1.0, 1.6, 0), 0.35, Color(0.15, 0.05, 0.05) if not wraith else Color(0.7, 0.9, 1.0), 0.18)
	_box(host, "mouth", Vector3(0.35, 0.22, 0.5), Vector3(1.0, 1.15, 0), _col(Color(0.08, 0.04, 0.04)))
	for i in range(9):
		var x := float(i % 3) - 1.0
		var z := float(i / 3) - 1.0
		_box(host, "anim_leg_%d" % i, Vector3(0.18, 1.3, 0.18), Vector3(x * 0.5, 0.2, z * 0.5), mat)


static func _shulker(host: Node3D, mat: Material) -> void:
	_box(host, "anim_body", Vector3(1.0, 0.55, 1.0), Vector3(0, 0.28, 0), mat)
	_box(host, "lid", Vector3(1.02, 0.35, 1.02), Vector3(0, 0.7, 0), mat)
	_box(host, "anim_head", Vector3(0.45, 0.35, 0.45), Vector3(0, 0.7, 0), _col(Color(0.85, 0.55, 0.95), 0.5))


static func _snow_golem(host: Node3D, _mat: Material) -> void:
	var snow := _col(Color(0.95, 0.97, 1.0))
	_box(host, "anim_leg_0", Vector3(0.7, 0.7, 0.7), Vector3(0, 0.35, 0), snow)
	_box(host, "anim_body", Vector3(0.58, 0.58, 0.58), Vector3(0, 0.95, 0), snow)
	_box(host, "anim_head", Vector3(0.5, 0.5, 0.5), Vector3(0, 1.5, 0), _col(Color(1.0, 0.55, 0.12)))
	_box(host, "anim_arm_0", Vector3(0.1, 0.55, 0.1), Vector3(-0.45, 1.0, 0), _col(Color(0.4, 0.25, 0.1)))
	_box(host, "anim_arm_1", Vector3(0.1, 0.55, 0.1), Vector3(0.45, 1.0, 0), _col(Color(0.4, 0.25, 0.1)))


static func _iron_golem(host: Node3D, _mat: Material) -> void:
	var iron := _col(Color(0.72, 0.72, 0.75))
	_box(host, "anim_body", Vector3(1.35, 1.5, 0.7), Vector3(0, 1.45, 0), iron)
	_box(host, "anim_head", Vector3(0.7, 0.7, 0.7), Vector3(0, 2.4, 0), iron)
	_box(host, "nose", Vector3(0.18, 0.22, 0.32), Vector3(0, 2.25, 0.45), iron)
	_box(host, "anim_arm_0", Vector3(0.42, 1.5, 0.42), Vector3(-0.95, 1.35, 0), iron)
	_box(host, "anim_arm_1", Vector3(0.42, 1.5, 0.42), Vector3(0.95, 1.35, 0), iron)
	_box(host, "anim_leg_0", Vector3(0.38, 0.95, 0.45), Vector3(-0.32, 0.48, 0), iron)
	_box(host, "anim_leg_1", Vector3(0.38, 0.95, 0.45), Vector3(0.32, 0.48, 0), iron)


static func _wither(host: Node3D, mat: Material) -> void:
	_box(host, "anim_body", Vector3(0.45, 1.3, 0.45), Vector3(0, 1.0, 0), mat)
	_box(host, "anim_head", Vector3(0.7, 0.7, 0.7), Vector3(0, 2.05, 0), mat)
	_box(host, "head_l", Vector3(0.55, 0.55, 0.55), Vector3(-0.85, 1.95, 0), mat)
	_box(host, "head_r", Vector3(0.55, 0.55, 0.55), Vector3(0.85, 1.95, 0), mat)
	_eyes(host, Vector3(0.32, 2.1, 0), 0.14, Color(1.0, 0.3, 0.1), 0.1)


static func _dragon(host: Node3D, mat: Material) -> void:
	_box(host, "anim_body", Vector3(4.4, 1.6, 2.0), Vector3(0, 1.2, 0), mat)
	_box(host, "anim_head", Vector3(1.6, 1.4, 1.6), Vector3(2.8, 1.8, 0), mat)
	_eyes(host, Vector3(3.5, 1.95, 0), 0.35, Color(0.7, 0.2, 1.0), 0.16)
	_box(host, "anim_wing_0", Vector3(5.2, 0.22, 3.2), Vector3(0, 2.1, -2.6), mat, Vector3(12, 20, -30))
	_box(host, "anim_wing_1", Vector3(5.2, 0.22, 3.2), Vector3(0, 2.1, 2.6), mat, Vector3(-12, -20, 30))
	_box(host, "anim_tail", Vector3(3.2, 0.8, 1.0), Vector3(-3.4, 1.0, 0), mat)


static func _god(host: Node3D, mat: Material, mob_id: String) -> void:
	var palette := {
		"chaos": Color(0.95, 0.95, 0.98), "eidorian_ushiha": Color(0.12, 0.12, 0.14),
		"mania_hedgehog": Color(1.0, 0.85, 0.15), "zeus": Color(0.85, 0.8, 0.2),
		"poseidon": Color(0.15, 0.45, 0.85), "hades": Color(0.25, 0.05, 0.3),
		"nyx": Color(0.08, 0.05, 0.18), "gaia": Color(0.2, 0.65, 0.25),
		"erebos_demon": Color(0.12, 0.0, 0.05), "angel_warden": Color(0.95, 0.95, 0.75),
		"chronos": Color(0.55, 0.45, 0.2), "hera": Color(0.75, 0.55, 0.85),
		"demeter": Color(0.45, 0.7, 0.25), "hestia": Color(0.9, 0.55, 0.3),
		"apollon": Color(1.0, 0.9, 0.4), "artemis": Color(0.55, 0.75, 0.55),
		"aphrodite": Color(0.95, 0.55, 0.7), "hephaistos": Color(0.55, 0.35, 0.25),
		"hermes": Color(0.35, 0.65, 0.45), "dionysos": Color(0.55, 0.2, 0.45),
		"athena": Color(0.75, 0.75, 0.8), "ares": Color(0.7, 0.1, 0.1),
		"aither": Color(0.7, 0.85, 1.0), "hemera": Color(1.0, 0.9, 0.4),
		"uranos": Color(0.4, 0.6, 0.95), "tartaros": Color(0.15, 0.05, 0.2),
		"ananke": Color(0.5, 0.2, 0.5), "demon_reaver": Color(0.5, 0.05, 0.05),
		"erebos": Color(0.1, 0.05, 0.15),
	}
	var col: Color = palette.get(mob_id, Color(0.6, 0.6, 0.7))
	var m := _col(col, 0.35)
	_box(host, "anim_body", Vector3(0.7, 1.35, 0.5), Vector3(0, 1.15, 0), m)
	_box(host, "anim_head", Vector3(0.62, 0.62, 0.62), Vector3(0, 2.1, 0), m)
	_box(host, "anim_arm_0", Vector3(0.26, 1.05, 0.26), Vector3(-0.52, 1.3, 0), m)
	_box(host, "anim_arm_1", Vector3(0.26, 1.05, 0.26), Vector3(0.52, 1.3, 0), m)
	_box(host, "anim_leg_0", Vector3(0.28, 0.9, 0.28), Vector3(-0.2, 0.45, 0), m)
	_box(host, "anim_leg_1", Vector3(0.28, 0.9, 0.28), Vector3(0.2, 0.45, 0), m)
	if mob_id in ["angel_warden", "aither"]:
		_box(host, "anim_wing_0", Vector3(0.12, 1.3, 0.9), Vector3(0, 1.5, 0.6), _col(Color(0.95, 0.95, 0.88)))
		_box(host, "anim_wing_1", Vector3(0.12, 1.3, 0.9), Vector3(0, 1.5, -0.6), _col(Color(0.95, 0.95, 0.88)))
	if mob_id in ["erebos_demon", "demon_reaver", "hades", "tartaros"]:
		for s in [-1, 1]:
			_box(host, "horn", Vector3(0.1, 0.4, 0.1), Vector3(0.08, 2.5, s * 0.2), _col(Color(0.12, 0.02, 0.02)))
	if mob_id == "mania_hedgehog":
		for i in range(5):
			_box(host, "spike%d" % i, Vector3(0.1, 0.32, 0.1), Vector3(randf_range(-0.2, 0.2), 2.45, randf_range(-0.2, 0.2)), m)
	if mob_id == "eidorian_ushiha":
		_box(host, "mask", Vector3(0.66, 0.28, 0.12), Vector3(0.08, 2.08, 0.28), _col(Color(0.05, 0.05, 0.05)))
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.1
	light.omni_range = 4.0
	light.position = Vector3(0, 1.5, 0)
	host.add_child(light)
