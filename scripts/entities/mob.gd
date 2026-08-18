class_name Mob
extends CharacterBody3D
# Data-driven mob. Reads stats from Registry.mobs[id]. Simple AI:
#   passive  -> wander, flee when hit
#   neutral  -> wander; chase + attack once provoked
#   hostile  -> chase + attack the player within detection range
#   creeper-like ("explode" in ai) -> chase then explode near the player
# Movement is direct steering with gravity (no pathfinding yet).
# Boss mobs (category == "boss") additionally: regenerate health slowly
# when not recently hit, and "flying_boss" mobs (Ender Dragon) circle a
# fixed point in the air instead of walking on the ground.

signal died

const GRAVITY = 24.0
const DETECTION = 16.0
const ATTACK_RANGE = 1.8
const ATTACK_COOLDOWN = 1.0
const DESPAWN_DIST = 80.0
const EXPLODE_RANGE = 3.0

# Boss-Regeneration: ohne aktive "End Crystal"-Mechanik heilt sich ein
# Boss stattdessen einfach selbst, solange er eine Weile nicht getroffen
# wurde - simpler Ersatz, der denselben Zweck erfüllt (Fight zieht sich,
# Spieler muss konstant Druck machen statt einmal hinzuhauen).
const BOSS_REGEN_DELAY = 8.0
const BOSS_REGEN_PER_SEC = 4.0

# Flugdrache: Kreisflug, dann ~10s landen/angreifen, dann wieder hoch.
const DRAGON_FLIGHT_HEIGHT = 14.0
const DRAGON_FLIGHT_RADIUS = 16.0
const DRAGON_FLIGHT_SPEED = 0.45   # rad/s um den Mittelpunkt
const DRAGON_DIVE_COOLDOWN = 8.0
const DRAGON_LAND_DURATION = 10.0
const DRAGON_DESPAWN_DIST = 200.0

var mob_id: String = ""
var data: Dictionary = {}
var health: float = 10.0
var max_health: float = 10.0
var category: String = "passive"
var attack_damage: float = 0.0
var ai_states: Array = []
var speed: float = 2.5

var player: Node3D
var _provoked: bool = false
var _attack_t: float = 0.0
var _wander_t: float = 0.0
var _wander_dir: Vector3 = Vector3.ZERO
var _regen_t: float = 0.0

var _is_flying_boss: bool = false
var _flight_center: Vector3 = Vector3.ZERO
var _flight_angle: float = 0.0
var _flight_ready: bool = false
var _dive_t: float = 0.0
var _diving: bool = false
var _landing: bool = false
var _land_t: float = 0.0


func _build_quadruped_model(mat: StandardMaterial3D, model_data: Dictionary) -> void:
	var hs = model_data.get("head_scale", 0.9)
	var bs = model_data.get("body_scale", 1.0)

	# Körper
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(
		1.4*bs,
		0.9*bs,
		0.8*bs
		)
	body.material_override = mat
	body.position = Vector3(0, 0.9, 0)
	add_child(body)

	# Kopf
	var head = MeshInstance3D.new()
	head.mesh = BoxMesh.new()
	head.mesh.size = Vector3(0.7 * hs, 0.7 * hs, 0.7 * hs)
	head.material_override = mat
	head.position = Vector3(
		0.9*bs,
		0.95+(hs*0.3),
		0
		)
	add_child(head)
	var eye = StandardMaterial3D.new()
	eye.albedo_color = Color.BLACK

	for z in [-0.12,0.12]:
		var e = MeshInstance3D.new()
		e.mesh = BoxMesh.new()
		e.mesh.size = Vector3(0.05,0.05,0.05)
		e.material_override = eye
		e.position = head.position + Vector3(0.28,0.02,z)
		add_child(e)
	if model_data.get("mushrooms",false):
		for p in [
			Vector3(-0.2,1.35,0),
			Vector3(0.3,1.45,0.15)
		]:
			var mush = MeshInstance3D.new()
			mush.mesh = BoxMesh.new()
			mush.mesh.size = Vector3(0.3,0.3,0.3)
			mush.material_override = mat
			mush.position = p
			add_child(mush)
	if model_data.get("horns",false):
		for side in [-1,1]:
			var horn = MeshInstance3D.new()
			horn.mesh = BoxMesh.new()
			horn.mesh.size = Vector3(0.08,0.25,0.08)
			horn.material_override = mat
			horn.position = head.position + Vector3(0.18,0.25,side*0.18)
			add_child(horn)
			
	if model_data.get("tail",false):
		var tail = MeshInstance3D.new()
		tail.mesh = BoxMesh.new()
		tail.mesh.size = Vector3(0.45,0.12,0.12)
		tail.material_override = mat
		tail.position = Vector3(-0.9*bs,0.9,0)
		tail.rotation_degrees.z = 25
		add_child(tail)

	# 4 Beine
	for i in range(4):
		var leg = MeshInstance3D.new()
		leg.mesh = BoxMesh.new()
		var ll = model_data.get("leg_length",0.6)
		leg.mesh.size = Vector3(0.22,ll,0.22)
		leg.position.y = ll*0.5
		leg.material_override = mat
		var x = 0.5 if i < 2 else -0.5
		var z = 0.35 if i % 2 == 0 else -0.35
		leg.position = Vector3(x, 0.4, z)
		add_child(leg)


func _build_biped_model(mat: StandardMaterial3D, model_data: Dictionary) -> void:
	var hs = model_data.get("head_scale", 0.9)

	# Körper
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.6, 1.2, 0.5)
	body.material_override = mat
	body.position = Vector3(0, 1.0, 0)
	add_child(body)

	# Kopf
	var head = MeshInstance3D.new()
	head.mesh = BoxMesh.new()
	head.mesh.size = Vector3(0.6 * hs, 0.6 * hs, 0.6 * hs)
	head.material_override = mat
	head.position = Vector3(0, 1.9, 0)
	add_child(head)

	# Arme
	for side in [-1, 1]:
		var arm = MeshInstance3D.new()
		arm.mesh = BoxMesh.new()
		arm.mesh.size = Vector3(0.25, 0.9, 0.25)
		arm.material_override = mat
		arm.position = Vector3(side * 0.5, 1.3, 0)
		add_child(arm)

	# Beine
	for side in [-1, 1]:
		var leg = MeshInstance3D.new()
		leg.mesh = BoxMesh.new()
		leg.mesh.size = Vector3(0.3, 0.9, 0.3)
		leg.material_override = mat
		leg.position = Vector3(side * 0.2, 0.45, 0)
		add_child(leg)


func _build_creeper_model(mat: StandardMaterial3D) -> void:
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.6, 1.6, 0.6)
	body.material_override = mat
	body.position = Vector3(0, 0.9, 0)
	add_child(body)

	var head = MeshInstance3D.new()
	head.mesh = BoxMesh.new()
	head.mesh.size = Vector3(0.55, 0.55, 0.55)
	head.material_override = mat
	head.position = Vector3(0, 1.85, 0)
	add_child(head)

	for x in [-0.25, 0.25]:
		for z in [-0.25, 0.25]:
			var leg = MeshInstance3D.new()
			leg.mesh = BoxMesh.new()
			leg.mesh.size = Vector3(0.2, 0.6, 0.2)
			leg.material_override = mat
			leg.position = Vector3(x, 0.35, z)
			add_child(leg)


func _build_spider_model(mat: StandardMaterial3D) -> void:
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(1.1, 0.6, 1.1)
	body.material_override = mat
	body.position = Vector3(0, 0.6, 0)
	add_child(body)

	var head = MeshInstance3D.new()
	head.mesh = BoxMesh.new()
	head.mesh.size = Vector3(0.7, 0.5, 0.7)
	head.material_override = mat
	head.position = Vector3(0.7, 0.7, 0)
	add_child(head)

	# 8 Beine
	for i in range(8):
		var leg = MeshInstance3D.new()
		leg.mesh = BoxMesh.new()
		leg.mesh.size = Vector3(0.9, 0.15, 0.15)
		leg.material_override = mat
		var angle = (i - 3.5) * 18
		leg.rotation_degrees.y = angle
		leg.position = Vector3(0, 0.4, 0)
		add_child(leg)


func _build_slime_model(mat: StandardMaterial3D) -> void:
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(1.2, 1.2, 1.2)
	body.material_override = mat
	body.position = Vector3(0, 0.7, 0)
	add_child(body)


func _build_blaze_model(mat: StandardMaterial3D) -> void:
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.7, 1.4, 0.7)
	body.material_override = mat
	body.position = Vector3(0, 1.0, 0)
	add_child(body)

	# Stäbe (vereinfacht als kleine Boxen)
	for i in range(6):
		var rod = MeshInstance3D.new()
		rod.mesh = BoxMesh.new()
		rod.mesh.size = Vector3(0.15, 1.8, 0.15)
		rod.material_override = mat
		rod.position = Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.6, 0.6))
		add_child(rod)


func _build_ghast_model(mat: StandardMaterial3D) -> void:
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(2.5, 2.0, 2.5)
	body.material_override = mat
	body.position = Vector3(0, 1.5, 0)
	add_child(body)

	for i in range(9):
		var tentacle = MeshInstance3D.new()
		tentacle.mesh = BoxMesh.new()
		tentacle.mesh.size = Vector3(0.3, 1.5, 0.3)
		tentacle.material_override = mat
		tentacle.position = Vector3(randf_range(-1.2, 1.2), 0.3, randf_range(-1.2, 1.2))
		add_child(tentacle)


func _build_wither_model(mat: StandardMaterial3D) -> void:
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(1.2, 1.0, 1.2)
	body.material_override = mat
	body.position = Vector3(0, 1.2, 0)
	add_child(body)

	for i in range(3):
		var skull = MeshInstance3D.new()
		skull.mesh = BoxMesh.new()
		skull.mesh.size = Vector3(0.7, 0.7, 0.7)
		skull.material_override = mat
		skull.position = Vector3(-1.2 + i * 1.2, 2.0, 0)
		add_child(skull)


func _build_shulker_model(mat: StandardMaterial3D) -> void:
	var shell = MeshInstance3D.new()
	shell.mesh = BoxMesh.new()
	shell.mesh.size = Vector3(1.0, 1.0, 1.0)
	shell.material_override = mat
	shell.position = Vector3(0, 0.6, 0)
	add_child(shell)


func _build_chicken_model(mat: StandardMaterial3D) -> void:
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.6, 0.7, 0.8)
	body.material_override = mat
	body.position = Vector3(0, 0.7, 0)
	add_child(body)

	var head = MeshInstance3D.new()
	head.mesh = BoxMesh.new()
	head.mesh.size = Vector3(0.4, 0.4, 0.4)
	head.material_override = mat
	head.position = Vector3(0.5, 1.0, 0)
	add_child(head)


func _build_squid_model(mat: StandardMaterial3D) -> void:
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(1.0, 1.2, 1.0)
	body.material_override = mat
	body.position = Vector3(0, 0.9, 0)
	add_child(body)

	for i in range(8):
		var tent = MeshInstance3D.new()
		tent.mesh = BoxMesh.new()
		tent.mesh.size = Vector3(0.2, 1.8, 0.2)
		tent.material_override = mat
		tent.position = Vector3(randf_range(-0.6, 0.6), 0.3, randf_range(-0.6, 0.6))
		add_child(tent)


func _build_bat_model(mat: StandardMaterial3D) -> void:
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.5, 0.4, 0.8)
	body.material_override = mat
	body.position = Vector3(0, 0.5, 0)
	add_child(body)

	var wing_l = MeshInstance3D.new()
	wing_l.mesh = BoxMesh.new()
	wing_l.mesh.size = Vector3(1.2, 0.15, 0.8)
	wing_l.material_override = mat
	wing_l.position = Vector3(0, 0.6, -0.6)
	add_child(wing_l)

	var wing_r = MeshInstance3D.new()
	wing_r.mesh = BoxMesh.new()
	wing_r.mesh.size = Vector3(1.2, 0.15, 0.8)
	wing_r.material_override = mat
	wing_r.position = Vector3(0, 0.6, 0.6)
	add_child(wing_r)


func _build_dragon_model(mat: StandardMaterial3D) -> void:
	# Dein bereits guter Enderdrachen-Code von vorher hier einfügen
	pass


func setup(p_id: String, p_player: Node3D) -> void:
	mob_id = p_id
	player = p_player
	data = Registry.get_mob(p_id)
	if data == null:
		data = {}
	# Defensiv: manche Einträge könnten "health" statt "hp" nutzen.
	health = float(data.get("hp", data.get("health", 10)))
	max_health = health
	category = data.get("category", "passive")
	attack_damage = float(data.get("damage", 0))
	ai_states = data.get("ai", [])
	if category == "hostile" or category == "boss":
		speed = 3.0
	elif category == "neutral":
		speed = 2.6
	else:
		speed = 2.0

	_is_flying_boss = data.get("behavior", "") == "flying_boss"
	if _is_flying_boss:
		speed = clampf(float(data.get("speed", 12.0)), 6.0, 16.0)


func _ready() -> void:
	add_to_group("mobs")
	collision_layer = 2
	collision_mask = 1
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	if mob_id == "ender_dragon":
		box.size = Vector3(5.0, 2.2, 2.6)
		shape.position = Vector3(0, 1.2, 0)
	else:
		box.size = Vector3(0.7, 1.7, 0.7)
		shape.position = Vector3(0, 0.85, 0)
	shape.shape = box
	add_child(shape)

	# === Einzigartige Modelle ===
	var model = Registry.get_mob_model(mob_id)
	var mtype = model.get("type", "biped")

	var mat = StandardMaterial3D.new()
	mat.albedo_texture = Textures.get_texture(mob_id)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	var bm = BoxMesh.new()
	bm.size = Vector3(0.7, 1.7, 0.7)

	if mtype == "creeper":
		_build_creeper_model(mat)
		return

	elif mtype == "spider":
		_build_spider_model(mat)
		return

	elif mtype == "slime":
		_build_slime_model(mat)
		return

	elif mtype == "blaze":
		_build_blaze_model(mat)
		return

	elif mtype == "ghast":
		_build_ghast_model(mat)
		return

	elif mtype == "wither":
		_build_wither_model(mat)
		return

	elif mtype == "shulker":
		_build_shulker_model(mat)
		return

	elif mtype == "chicken":
		_build_chicken_model(mat)
		return

	elif mtype == "squid":
		_build_squid_model(mat)
		return

	elif mtype == "bat":
		_build_bat_model(mat)
		return

	elif mtype in ["quadruped", "sheep", "cow", "pig", "wolf", "horse", "rabbit", "ocelot"]:
		_build_quadruped_model(mat, model)
		return

	elif mtype in ["biped", "zombie", "skeleton", "villager", "witch", "zombie_pigman", "erebite"]:
		_build_biped_model(mat, model)
		return
	# === ENDER DRACHE (einfaches aber erkennbares Modell) ===
	if mtype == "dragon":
		mat.albedo_texture = Textures.get_texture(mob_id)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

		# === KÖRPER (lang) ===
		var body = MeshInstance3D.new()
		var body_mesh = BoxMesh.new()
		body_mesh.size = Vector3(4.5, 1.8, 2.2)
		body.mesh = body_mesh
		body.material_override = mat
		body.position = Vector3(0, 1.2, 0)
		add_child(body)

		# === KOPF ===
		var head = MeshInstance3D.new()
		var head_mesh = BoxMesh.new()
		head_mesh.size = Vector3(1.8, 1.6, 1.8)
		head.mesh = head_mesh
		head.material_override = mat
		head.position = Vector3(3.0, 1.8, 0)
		add_child(head)

		# === LINKER FLÜGEL ===
		var wing_l = MeshInstance3D.new()
		var wing_l_mesh = BoxMesh.new()
		wing_l_mesh.size = Vector3(5.5, 0.3, 3.5)
		wing_l.mesh = wing_l_mesh
		wing_l.material_override = mat
		wing_l.position = Vector3(0, 2.2, -2.8)
		wing_l.rotation_degrees = Vector3(15, 25, -35)
		add_child(wing_l)

		# === RECHTER FLÜGEL ===
		var wing_r = MeshInstance3D.new()
		var wing_r_mesh = BoxMesh.new()
		wing_r_mesh.size = Vector3(5.5, 0.3, 3.5)
		wing_r.mesh = wing_r_mesh
		wing_r.material_override = mat
		wing_r.position = Vector3(0, 2.2, 2.8)
		wing_r.rotation_degrees = Vector3(-15, -25, 35)
		add_child(wing_r)

		# === SCHWANZ ===
		var tail = MeshInstance3D.new()
		var tail_mesh = BoxMesh.new()
		tail_mesh.size = Vector3(3.5, 1.0, 1.2)
		tail.mesh = tail_mesh
		tail.material_override = mat
		tail.position = Vector3(-3.5, 1.0, 0)
		add_child(tail)

		return   # wichtig, damit kein normaler Würfel mehr hinzugefügt wird
	elif mtype == "slime":
		bm.size = Vector3(1.1, 1.1, 1.1)
		return
	elif mtype == "chicken":
		bm.size = Vector3(0.55, 0.9, 0.7)
		return

# Nur verwenden wenn kein spezielles Modell existiert
	if get_child_count() <= 2:
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = bm
		mesh_inst.material_override = mat
		mesh_inst.position = Vector3(0, 0.85, 0)
		add_child(mesh_inst)

	# Schaf-Wolle
	if model.get("wool", false) or mtype == "sheep":
		var wool = MeshInstance3D.new()
		var wool_mesh = BoxMesh.new()
		wool_mesh.size = Vector3(1.55,1.15,1.0)
		wool.mesh = wool_mesh
		wool.position = Vector3(0, 1.05, 0)
		var wool_mat = StandardMaterial3D.new()
		wool_mat.albedo_texture = Textures.get_texture("white_wool")
		wool_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		wool.material_override = wool_mat
		add_child(wool)

	# Kopf
	if mtype in ["biped", "quadruped", "villager", "zombie", "skeleton", "creeper", "sheep", "cow", "pig"]:
		var head = MeshInstance3D.new()
		var head_mesh = BoxMesh.new()
		var hs = model.get("head_scale", 0.9)
		head_mesh.size = Vector3(0.55 * hs, 0.55 * hs, 0.55 * hs)
		head.mesh = head_mesh
		head.position = Vector3(0, 1.65, 0)
		head.material_override = mat
		add_child(head)


func is_ender_dragon() -> bool:
	return mob_id == "ender_dragon"


func _aggressive() -> bool:
	if category == "hostile" or category == "boss":
		return true
	if category == "neutral":
		return _provoked
	return false


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var max_dist = DRAGON_DESPAWN_DIST if _is_flying_boss or category == "boss" else DESPAWN_DIST
	if global_position.distance_to(player.global_position) > max_dist:
		queue_free()
		return

	# Boss-Regeneration: heilt langsam, solange er eine Weile nicht
	# getroffen wurde. Ersetzt eine echte End-Crystal-Mechanik simpel,
	# ohne neue Blöcke/Entities zu brauchen.
	if category == "boss" and health > 0.0 and health < max_health:
		_regen_t += delta
		if _regen_t >= BOSS_REGEN_DELAY:
			health = minf(max_health, health + BOSS_REGEN_PER_SEC * delta)

	if _is_flying_boss:
		_physics_process_dragon(delta)
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	var to_player = player.global_position - global_position
	var dist = Vector2(to_player.x, to_player.z).length()

	if ai_states.has("explode") and _aggressive() and dist < EXPLODE_RANGE:
		_explode()
		return

	if _aggressive() and dist < DETECTION and dist > ATTACK_RANGE:
		_steer(to_player, speed)
	elif _aggressive() and dist <= ATTACK_RANGE:
		velocity.x = 0.0
		velocity.z = 0.0
		_attack_t -= delta
		if _attack_t <= 0.0 and attack_damage > 0.0:
			_attack_t = ATTACK_COOLDOWN
			player.mob_hit(attack_damage)
			Audio.play("hit", -8.0)
	else:
		_wander(delta)

	move_and_slide()


func _physics_process_dragon(delta: float) -> void:
	# Kreisflug, dann landen (~10s) damit Spieler angreifen kann, dann wieder hoch.
	if not _flight_ready:
		_flight_center = Vector3(player.global_position.x, player.global_position.y + 2.0, player.global_position.z)
		_flight_angle = 0.0
		_flight_ready = true
		_dive_t = 4.0

	_dive_t -= delta
	var to_player = player.global_position - global_position
	var dist = to_player.length()

	# Phase: Landen starten
	if not _diving and not _landing and _dive_t <= 0.0:
		_landing = true
		_land_t = DRAGON_LAND_DURATION
		_diving = true

	var target_pos: Vector3
	var move_speed = speed

	if _landing:
		_land_t -= delta
		# Ziel: knapp über dem Spieler / Boden, damit man den Drachen treffen kann
		target_pos = player.global_position + Vector3(0, 1.8, 0)
		move_speed = speed * 0.7
		if dist < ATTACK_RANGE * 2.5:
			_attack_t -= delta
			if _attack_t <= 0.0 and attack_damage > 0.0:
				_attack_t = ATTACK_COOLDOWN
				player.mob_hit(attack_damage)
				Audio.play("hit", -6.0)
		if _land_t <= 0.0:
			_landing = false
			_diving = false
			_dive_t = DRAGON_DIVE_COOLDOWN
			_flight_center = Vector3(player.global_position.x, player.global_position.y + 2.0, player.global_position.z)
	elif _diving:
		target_pos = player.global_position + Vector3(0, 2.5, 0)
		if dist < ATTACK_RANGE * 2.2:
			if attack_damage > 0.0:
				player.mob_hit(attack_damage)
				Audio.play("hit", -6.0)
			_diving = false
			_dive_t = DRAGON_DIVE_COOLDOWN * 0.5
	else:
		_flight_angle += DRAGON_FLIGHT_SPEED * delta
		var fly_y = _flight_center.y + DRAGON_FLIGHT_HEIGHT + sin(_flight_angle * 1.7) * 2.5
		target_pos = _flight_center + Vector3(
			cos(_flight_angle) * DRAGON_FLIGHT_RADIUS,
			fly_y - _flight_center.y,
			sin(_flight_angle) * DRAGON_FLIGHT_RADIUS
		)

	var to_target = target_pos - global_position
	if to_target.length() > 0.08:
		velocity = to_target.normalized() * move_speed
		if absf(velocity.x) + absf(velocity.z) > 0.01:
			look_at(global_position + Vector3(velocity.x, 0, velocity.z), Vector3.UP)
	else:
		velocity = Vector3.ZERO

	global_position += velocity * delta


func _steer(dir: Vector3, spd: float) -> void:
	var flat = Vector3(dir.x, 0, dir.z).normalized()
	velocity.x = flat.x * spd
	velocity.z = flat.z * spd
	if flat.length() > 0.01:
		look_at(global_position + flat, Vector3.UP)


func _wander(delta: float) -> void:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.5, 4.0)
		if randf() < 0.5:
			var ang = randf() * TAU
			_wander_dir = Vector3(cos(ang), 0, sin(ang))
		else:
			_wander_dir = Vector3.ZERO
	velocity.x = _wander_dir.x * speed * 0.5
	velocity.z = _wander_dir.z * speed * 0.5


func take_hit(dmg: float) -> void:
	health -= dmg
	_provoked = true
	_regen_t = 0.0
	Audio.play("hit", -6.0)
	# passive mobs flee away from the player
	if category == "passive":
		var away = (global_position - player.global_position)
		_steer(away, speed)
	if health <= 0.0:
		_die()


func _die() -> void:
	_drop_loot()
	died.emit()
	queue_free()


func _drop_loot() -> void:
	var drops = Registry.get_mob(mob_id).get("drops", [])
	if drops.is_empty():
		return

	for drop in drops:
		if drop is Array and drop.size() >= 2:
			var item_id = drop[0]
			var count = drop[1]
			var chance = drop[2] if drop.size() > 2 else 1.0

			if randf() <= chance:
				player.inventory.add(item_id, count)
		elif drop is String:
			# Fallback für alte/simple Drops
			player.inventory.add(drop, 1)


func _explode() -> void:
	if global_position.distance_to(player.global_position) < EXPLODE_RANGE:
		player.take_damage(14.0)
	Audio.play("explode", 0.0)
	_drop_loot()
	queue_free()
