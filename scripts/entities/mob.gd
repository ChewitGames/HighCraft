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
var _ambient_sound_t: float = 0.0
var _step_sound_t: float = 0.0
var _target_refresh_t: float = 0.0
var _hurt_flash_t: float = 0.0
var _knockback_t: float = 0.0

var _is_flying_boss: bool = false
var _flight_center: Vector3 = Vector3.ZERO
var _flight_angle: float = 0.0
var _flight_ready: bool = false
var _dive_t: float = 0.0
var _diving: bool = false
var _landing: bool = false
var _land_t: float = 0.0

# Universal limb animation (works for every mob type that names parts)
var _anim_t: float = 0.0
var _anim_legs: Array = []   # MeshInstance3D
var _anim_arms: Array = []
var _anim_wings: Array = []
var _anim_head: MeshInstance3D = null
var _anim_body: MeshInstance3D = null
var _anim_rest: Dictionary = {}  # node -> Vector3 rest rotation_degrees
var _anim_style: String = "walk_biped"


func _build_quadruped_model(mat: StandardMaterial3D, model_data: Dictionary) -> void:
	var hs = model_data.get("head_scale", 0.9)
	var bs = model_data.get("body_scale", 1.0)

	# Körper
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	var slim := str(model_data.get("type", "")) in ["ocelot", "wolf", "rabbit"]
	var bw = 1.05*bs if slim else 1.4*bs
	var bh = 0.55*bs if slim else 0.9*bs
	var bd = 0.5*bs if slim else 0.8*bs
	body.mesh.size = Vector3(bw, bh, bd)
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

	# 4 Beine (named for walk anim)
	for i in range(4):
		var leg = MeshInstance3D.new()
		leg.name = "anim_leg_%d" % i
		leg.mesh = BoxMesh.new()
		var ll = model_data.get("leg_length",0.6)
		leg.mesh.size = Vector3(0.22,ll,0.22)
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
	head.name = "anim_head"
	body.name = "anim_body"
	add_child(head)

	# Arme
	var ai = 0
	for side in [-1, 1]:
		var arm = MeshInstance3D.new()
		arm.name = "anim_arm_%d" % ai
		ai += 1
		arm.mesh = BoxMesh.new()
		arm.mesh.size = Vector3(0.25, 0.9, 0.25)
		arm.material_override = mat
		arm.position = Vector3(side * 0.5, 1.3, 0)
		add_child(arm)

	# Beine
	var li = 0
	for side in [-1, 1]:
		var leg = MeshInstance3D.new()
		leg.name = "anim_leg_%d" % li
		li += 1
		leg.mesh = BoxMesh.new()
		leg.mesh.size = Vector3(0.3, 0.9, 0.3)
		leg.material_override = mat
		leg.position = Vector3(side * 0.2, 0.45, 0)
		add_child(leg)

	head.name = "anim_head"
	body.name = "anim_body"


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

	var ci = 0
	for x in [-0.25, 0.25]:
		for z in [-0.25, 0.25]:
			var leg = MeshInstance3D.new()
			leg.name = "anim_leg_%d" % ci
			ci += 1
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
		leg.name = "anim_leg_%d" % i
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

	# Stäbe — orbit as anim_leg for spin/bob
	for i in range(6):
		var rod = MeshInstance3D.new()
		rod.name = "anim_leg_%d" % i
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
		tentacle.name = "anim_leg_%d" % i
		tentacle.mesh = BoxMesh.new()
		tentacle.mesh.size = Vector3(0.3, 1.5, 0.3)
		tentacle.material_override = mat
		tentacle.position = Vector3(randf_range(-1.2, 1.2), 0.3, randf_range(-1.2, 1.2))
		add_child(tentacle)



func _build_iron_golem_model(mat: StandardMaterial3D) -> void:
	mat.albedo_color = Color(0.72, 0.72, 0.75)
	mat.albedo_texture = null
	var body = MeshInstance3D.new()
	body.name = "anim_body"
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(1.4, 1.6, 0.7)
	body.material_override = mat
	body.position = Vector3(0, 1.4, 0)
	add_child(body)
	var head = MeshInstance3D.new()
	head.name = "anim_head"
	head.mesh = BoxMesh.new()
	head.mesh.size = Vector3(0.8, 0.8, 0.8)
	head.material_override = mat
	head.position = Vector3(0, 2.5, 0)
	add_child(head)
	for i in range(2):
		var arm = MeshInstance3D.new()
		arm.name = "anim_arm_%d" % i
		arm.mesh = BoxMesh.new()
		arm.mesh.size = Vector3(0.45, 1.4, 0.45)
		arm.material_override = mat
		arm.position = Vector3((-1 if i == 0 else 1) * 1.0, 1.5, 0)
		add_child(arm)
	for i in range(2):
		var leg = MeshInstance3D.new()
		leg.name = "anim_leg_%d" % i
		leg.mesh = BoxMesh.new()
		leg.mesh.size = Vector3(0.4, 1.0, 0.5)
		leg.material_override = mat
		leg.position = Vector3((-1 if i == 0 else 1) * 0.35, 0.5, 0)
		add_child(leg)
	# Nose
	var nose = MeshInstance3D.new()
	nose.mesh = BoxMesh.new()
	nose.mesh.size = Vector3(0.2, 0.25, 0.35)
	nose.material_override = mat
	nose.position = Vector3(0, 2.35, 0.5)
	add_child(nose)


func _build_snow_golem_model(mat: StandardMaterial3D) -> void:
	mat.albedo_color = Color(0.95, 0.97, 1.0)
	mat.albedo_texture = null
	for i in range(2):
		var ball = MeshInstance3D.new()
		ball.name = "anim_body" if i == 0 else "anim_leg_0"
		ball.mesh = BoxMesh.new()
		ball.mesh.size = Vector3(0.7 - i * 0.1, 0.7 - i * 0.1, 0.7 - i * 0.1)
		ball.material_override = mat
		ball.position = Vector3(0, 0.45 + i * 0.65, 0)
		add_child(ball)
	var head = MeshInstance3D.new()
	head.name = "anim_head"
	head.mesh = BoxMesh.new()
	head.mesh.size = Vector3(0.55, 0.55, 0.55)
	head.material_override = mat
	head.position = Vector3(0, 1.7, 0)
	add_child(head)
	# Pumpkin head tint
	var pump = StandardMaterial3D.new()
	pump.albedo_color = Color(1.0, 0.55, 0.1)
	var face = MeshInstance3D.new()
	face.mesh = BoxMesh.new()
	face.mesh.size = Vector3(0.58, 0.58, 0.58)
	face.material_override = pump
	face.position = Vector3(0, 1.7, 0)
	add_child(face)
	for i in range(2):
		var arm = MeshInstance3D.new()
		arm.name = "anim_arm_%d" % i
		arm.mesh = BoxMesh.new()
		arm.mesh.size = Vector3(0.12, 0.7, 0.12)
		var stick = StandardMaterial3D.new()
		stick.albedo_color = Color(0.4, 0.25, 0.1)
		arm.material_override = stick
		arm.position = Vector3((-1 if i == 0 else 1) * 0.5, 1.15, 0)
		add_child(arm)

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
	body.name = "anim_body"
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.6, 0.5, 0.8)
	body.material_override = mat
	body.position = Vector3(0, 0.7, 0)
	add_child(body)
	var head = MeshInstance3D.new()
	head.name = "anim_head"
	head.mesh = BoxMesh.new()
	head.mesh.size = Vector3(0.35, 0.35, 0.35)
	head.material_override = mat
	head.position = Vector3(0.35, 1.05, 0)
	add_child(head)
	for i in range(2):
		var leg = MeshInstance3D.new()
		leg.name = "anim_leg_%d" % i
		leg.mesh = BoxMesh.new()
		leg.mesh.size = Vector3(0.12, 0.45, 0.12)
		leg.material_override = mat
		leg.position = Vector3(0.1 if i == 0 else -0.1, 0.25, 0)
		add_child(leg)
	for i in range(2):
		var wing = MeshInstance3D.new()
		wing.name = "anim_wing_%d" % i
		wing.mesh = BoxMesh.new()
		wing.mesh.size = Vector3(0.15, 0.35, 0.5)
		wing.material_override = mat
		wing.position = Vector3(0, 0.75, 0.4 if i == 0 else -0.4)
		add_child(wing)



func _build_squid_model(mat: StandardMaterial3D) -> void:
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(1.0, 1.2, 1.0)
	body.material_override = mat
	body.position = Vector3(0, 0.9, 0)
	add_child(body)

	for i in range(8):
		var tent = MeshInstance3D.new()
		tent.name = "anim_leg_%d" % i
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
	wing_l.name = "anim_wing_0"
	wing_l.mesh = BoxMesh.new()
	wing_l.mesh.size = Vector3(1.2, 0.15, 0.8)
	wing_l.material_override = mat
	wing_l.position = Vector3(0, 0.6, -0.6)
	add_child(wing_l)

	var wing_r = MeshInstance3D.new()
	wing_r.name = "anim_wing_1"
	wing_r.mesh = BoxMesh.new()
	wing_r.mesh.size = Vector3(1.2, 0.15, 0.8)
	wing_r.material_override = mat
	wing_r.position = Vector3(0, 0.6, 0.6)
	add_child(wing_r)



func _build_god_model(mat: StandardMaterial3D, model_data: Dictionary) -> void:
	# Unique looks (NOT classical statues) — stylized box avatars
	var palette = {
		"chaos": Color(0.95, 0.95, 0.98),
		"eidorian_ushiha": Color(0.12, 0.12, 0.14),
		"mania_hedgehog": Color(1.0, 0.85, 0.15),
		"zeus": Color(0.85, 0.8, 0.2),
		"poseidon": Color(0.15, 0.45, 0.85),
		"hades": Color(0.25, 0.05, 0.3),
		"nyx": Color(0.08, 0.05, 0.18),
		"gaia": Color(0.2, 0.65, 0.25),
		"erebos_demon": Color(0.12, 0.0, 0.05),
		"angel_warden": Color(0.95, 0.95, 0.75),
		"chronos": Color(0.55, 0.45, 0.2),
		"hera": Color(0.75, 0.55, 0.85),
		"demeter": Color(0.45, 0.7, 0.25),
		"hestia": Color(0.9, 0.55, 0.3),
		"apollon": Color(1.0, 0.9, 0.4),
		"artemis": Color(0.55, 0.75, 0.55),
		"aphrodite": Color(0.95, 0.55, 0.7),
		"hephaistos": Color(0.55, 0.35, 0.25),
		"hermes": Color(0.35, 0.65, 0.45),
		"dionysos": Color(0.55, 0.2, 0.45),
		"athena": Color(0.75, 0.75, 0.8),
		"ares": Color(0.7, 0.1, 0.1),
		"aither": Color(0.7, 0.85, 1.0),
		"hemera": Color(1.0, 0.9, 0.4),
		"uranos": Color(0.4, 0.6, 0.95),
		"tartaros": Color(0.15, 0.05, 0.2),
		"ananke": Color(0.5, 0.2, 0.5),
		"erebus_foreigner": Color(0.15, 0.05, 0.25),
		"demon_reaver": Color(0.5, 0.05, 0.05),
	}
	var col = palette.get(mob_id, mat.albedo_color if mat.albedo_color else Color(0.6, 0.6, 0.7))
	mat.albedo_color = col
	mat.albedo_texture = null
	# Larger biped
	var body = MeshInstance3D.new()
	body.name = "anim_body"
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.75, 1.4, 0.55)
	body.material_override = mat
	body.position = Vector3(0, 1.15, 0)
	add_child(body)
	var head = MeshInstance3D.new()
	head.name = "anim_head"
	head.mesh = BoxMesh.new()
	head.mesh.size = Vector3(0.7, 0.7, 0.7)
	head.material_override = mat
	head.position = Vector3(0, 2.15, 0)
	add_child(head)
	# Eyes
	var eye_mat = StandardMaterial3D.new()
	if mob_id == "chaos" or mob_id == "erebos_demon":
		eye_mat.albedo_color = Color(1, 0.1, 0.1)
		eye_mat.emission_enabled = true
		eye_mat.emission = Color(1, 0.1, 0.1)
	elif mob_id == "mania_hedgehog":
		eye_mat.albedo_color = Color(0.4, 0.75, 1.0)
	else:
		eye_mat.albedo_color = Color(0.05, 0.05, 0.05)
	for z in [-0.15, 0.15]:
		var e = MeshInstance3D.new()
		e.mesh = BoxMesh.new()
		e.mesh.size = Vector3(0.08, 0.08, 0.08)
		e.material_override = eye_mat
		e.position = head.position + Vector3(0.32, 0.05, z)
		add_child(e)
	# Eidorian: mask + hoodie silhouette
	if mob_id == "eidorian_ushiha":
		var mask = MeshInstance3D.new()
		mask.mesh = BoxMesh.new()
		mask.mesh.size = Vector3(0.72, 0.35, 0.15)
		var mm = StandardMaterial3D.new()
		mm.albedo_color = Color(0.05, 0.05, 0.05)
		mask.material_override = mm
		mask.position = head.position + Vector3(0.05, -0.05, 0)
		add_child(mask)
		var hood = MeshInstance3D.new()
		hood.mesh = BoxMesh.new()
		hood.mesh.size = Vector3(0.85, 0.35, 0.85)
		hood.material_override = mm
		hood.position = head.position + Vector3(0, 0.25, -0.05)
		add_child(hood)
	# Mania: spikes (hedgehog)
	if mob_id == "mania_hedgehog":
		for i in range(6):
			var sp = MeshInstance3D.new()
			sp.mesh = BoxMesh.new()
			sp.mesh.size = Vector3(0.12, 0.35, 0.12)
			sp.material_override = mat
			sp.position = head.position + Vector3(randf_range(-0.25, 0.25), 0.35, randf_range(-0.25, 0.25))
			add_child(sp)
		# dress / white
		var dress = MeshInstance3D.new()
		dress.mesh = BoxMesh.new()
		dress.mesh.size = Vector3(0.85, 0.7, 0.5)
		var dm = StandardMaterial3D.new()
		dm.albedo_color = Color(0.95, 0.95, 0.98)
		dress.material_override = dm
		dress.position = Vector3(0, 0.85, 0)
		add_child(dress)
	# Angel wings
	if mob_id == "angel_warden" or mob_id == "aither":
		for i in range(2):
			var w = MeshInstance3D.new()
			w.name = "anim_wing_%d" % i
			w.mesh = BoxMesh.new()
			w.mesh.size = Vector3(0.15, 1.2, 0.9)
			var wm = StandardMaterial3D.new()
			wm.albedo_color = Color(0.95, 0.95, 0.9)
			w.material_override = wm
			w.position = Vector3(0, 1.4, 0.55 if i == 0 else -0.55)
			add_child(w)
	# Demon horns
	if mob_id in ["erebos_demon", "demon_reaver", "hades", "tartaros"]:
		for side in [-1, 1]:
			var horn = MeshInstance3D.new()
			horn.mesh = BoxMesh.new()
			horn.mesh.size = Vector3(0.12, 0.4, 0.12)
			var hm = StandardMaterial3D.new()
			hm.albedo_color = Color(0.15, 0.02, 0.02)
			horn.material_override = hm
			horn.position = head.position + Vector3(0.1, 0.4, side * 0.22)
			add_child(horn)
	# Arms / legs
	for i in range(2):
		var arm = MeshInstance3D.new()
		arm.name = "anim_arm_%d" % i
		arm.mesh = BoxMesh.new()
		arm.mesh.size = Vector3(0.28, 1.0, 0.28)
		arm.material_override = mat
		arm.position = Vector3((-1 if i == 0 else 1) * 0.55, 1.35, 0)
		add_child(arm)
	for i in range(2):
		var leg = MeshInstance3D.new()
		leg.name = "anim_leg_%d" % i
		leg.mesh = BoxMesh.new()
		leg.mesh.size = Vector3(0.32, 0.95, 0.32)
		leg.material_override = mat
		leg.position = Vector3((-1 if i == 0 else 1) * 0.22, 0.45, 0)
		add_child(leg)
	# Aura light
	var light = OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.position = Vector3(0, 1.5, 0)
	add_child(light)


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
	_ambient_sound_t = randf_range(2.0, 8.0)
	collision_layer = 2
	collision_mask = 1
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	_apply_collision_size(box, shape)
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

	_anim_style = MobModelFactory.build(self, mob_id, mat, model)
	_collect_anim_parts()


func is_ender_dragon() -> bool:
	return mob_id == "ender_dragon"


func _aggressive() -> bool:
	if category == "hostile" or category == "boss":
		return true
	if category == "neutral":
		return _provoked
	return false



func _collect_anim_parts() -> void:
	_anim_legs.clear()
	_anim_arms.clear()
	_anim_wings.clear()
	_anim_head = null
	_anim_body = null
	_anim_rest.clear()
	for c in get_children():
		if not (c is MeshInstance3D):
			continue
		var n = str(c.name)
		if n.begins_with("anim_leg_"):
			_anim_legs.append(c)
		elif n.begins_with("anim_arm_"):
			_anim_arms.append(c)
		elif n.begins_with("anim_wing_"):
			_anim_wings.append(c)
		elif n == "anim_head":
			_anim_head = c
		elif n == "anim_body":
			_anim_body = c
		_anim_rest[c] = c.rotation_degrees


func _apply_collision_size(box: BoxShape3D, shape: CollisionShape3D) -> void:
	match mob_id:
		"ender_dragon", "erebus_sovereign":
			box.size = Vector3(5.0, 2.2, 2.6); shape.position = Vector3(0, 1.2, 0)
		"iron_golem":
			box.size = Vector3(1.4, 2.7, 1.0); shape.position = Vector3(0, 1.35, 0)
		"wither":
			box.size = Vector3(1.5, 2.5, 1.0); shape.position = Vector3(0, 1.5, 0)
		"erebite", "erebus_foreigner":
			box.size = Vector3(0.5, 2.9, 0.5); shape.position = Vector3(0, 1.45, 0)
		"horse":
			box.size = Vector3(1.6, 1.7, 0.7); shape.position = Vector3(0, 0.85, 0)
		"cow", "mooshroom", "sheep":
			box.size = Vector3(1.3, 1.3, 0.9); shape.position = Vector3(0, 0.65, 0)
		"pig", "wolf":
			box.size = Vector3(1.1, 0.9, 0.6); shape.position = Vector3(0, 0.45, 0)
		"ocelot":
			box.size = Vector3(0.9, 0.55, 0.4); shape.position = Vector3(0, 0.28, 0)
		"rabbit", "chicken", "silverfish", "endermite":
			box.size = Vector3(0.5, 0.5, 0.4); shape.position = Vector3(0, 0.25, 0)
		"spider":
			box.size = Vector3(1.2, 0.7, 1.2); shape.position = Vector3(0, 0.35, 0)
		"cave_spider":
			box.size = Vector3(0.8, 0.5, 0.8); shape.position = Vector3(0, 0.25, 0)
		"slime", "magma_cube":
			box.size = Vector3(1.1, 1.1, 1.1); shape.position = Vector3(0, 0.55, 0)
		"soulwraith":
			box.size = Vector3(2.0, 2.2, 2.0); shape.position = Vector3(0, 1.2, 0)
		"bat":
			box.size = Vector3(0.5, 0.5, 0.5); shape.position = Vector3(0, 0.4, 0)
		"squid":
			box.size = Vector3(0.9, 1.4, 0.9); shape.position = Vector3(0, 0.7, 0)
		"shulker":
			box.size = Vector3(1.0, 1.0, 1.0); shape.position = Vector3(0, 0.5, 0)
		"creeper":
			box.size = Vector3(0.6, 1.7, 0.6); shape.position = Vector3(0, 0.85, 0)
		_:
			box.size = Vector3(0.7, 1.8, 0.7); shape.position = Vector3(0, 0.9, 0)


func _animate_model(delta: float) -> void:
	var hvel = Vector3(velocity.x, 0.0, velocity.z).length()
	var moving = hvel > 0.12
	var style := _anim_style
	var speed := 8.0
	match style:
		"hop":
			speed = 7.0
		"crawl":
			speed = 10.0
		"flap", "float", "fly_dragon":
			speed = 6.0
		"gallop":
			speed = 9.0
		"sneak":
			speed = 11.0
		_:
			speed = clampf(hvel * 2.4, 4.0, 12.0) if moving else 3.0
	if moving or style in ["flap", "float", "fly_dragon", "idle"]:
		_anim_t += delta * speed
	else:
		_anim_t = move_toward(_anim_t, 0.0, delta * 6.0)

	var amp := 32.0 if moving else 0.0
	if style == "walk_zombie":
		amp = 18.0 if moving else 0.0
	elif style == "hop":
		amp = 40.0
	elif style == "crawl":
		amp = 22.0
	elif style == "sneak":
		amp = 20.0 if moving else 4.0
	elif style == "gallop":
		amp = 38.0 if moving else 0.0

	for i in range(_anim_legs.size()):
		var leg: MeshInstance3D = _anim_legs[i]
		if not is_instance_valid(leg):
			continue
		var rest: Vector3 = _anim_rest.get(leg, Vector3.ZERO)
		var sign = 1.0 if (i % 2 == 0) else -1.0
		match style:
			"hop":
				leg.rotation_degrees = rest + Vector3(sin(_anim_t) * amp, 0, 0)
				leg.position.y = rest.y if false else leg.position.y
			"crawl":
				leg.rotation_degrees = rest + Vector3(0, sin(_anim_t + float(i)) * amp, sign * 8.0)
			"float":
				leg.rotation_degrees = rest + Vector3(0, _anim_t * 25.0 + float(i) * 40.0, 0)
			_:
				leg.rotation_degrees = rest + Vector3(sin(_anim_t) * amp * sign, 0, 0)
	for i in range(_anim_arms.size()):
		var arm: MeshInstance3D = _anim_arms[i]
		if not is_instance_valid(arm):
			continue
		var rest2: Vector3 = _anim_rest.get(arm, Vector3.ZERO)
		var sign2 = -1.0 if (i % 2 == 0) else 1.0
		if style == "walk_zombie" or style == "walk_enderman":
			arm.rotation_degrees = rest2 + Vector3(sin(_anim_t) * 8.0 * sign2, 0, 0)
		else:
			arm.rotation_degrees = rest2 + Vector3(sin(_anim_t) * amp * sign2, 0, 0)
	var flap = sin(_anim_t * (2.2 if style == "flap" else 1.4)) * (38.0 if style in ["flap", "fly_dragon"] else 16.0)
	for i in range(_anim_wings.size()):
		var wing: MeshInstance3D = _anim_wings[i]
		if not is_instance_valid(wing):
			continue
		var rest3: Vector3 = _anim_rest.get(wing, Vector3.ZERO)
		var s = 1.0 if i % 2 == 0 else -1.0
		wing.rotation_degrees = rest3 + Vector3(0, 0, flap * s)
	if _anim_head != null and is_instance_valid(_anim_head):
		var hr: Vector3 = _anim_rest.get(_anim_head, Vector3.ZERO)
		_anim_head.rotation_degrees = hr + Vector3(sin(_anim_t * 0.6) * (5.0 if moving else 2.0), sin(_anim_t * 0.3) * 3.0, 0)
	if _anim_body != null and is_instance_valid(_anim_body) and style == "hop":
		_anim_body.position.y = _anim_rest.get(_anim_body, Vector3.ZERO).y + abs(sin(_anim_t)) * 0.18
	if _attack_t > ATTACK_COOLDOWN - 0.25:
		for i in range(_anim_arms.size()):
			var arm2: MeshInstance3D = _anim_arms[i]
			if is_instance_valid(arm2):
				arm2.rotation_degrees.x = -70.0


func _physics_process(delta: float) -> void:
	_target_refresh_t -= delta
	if _target_refresh_t <= 0.0:
		_target_refresh_t = 0.5
		_refresh_nearest_player()
	if _hurt_flash_t > 0.0:
		_hurt_flash_t -= delta
		if _hurt_flash_t <= 0.0:
			_set_hurt_overlay(false)
	if has_meta("frozen_t"):
		var ft = float(get_meta("frozen_t"))
		if ft > 0.0:
			set_meta("frozen_t", ft - delta)
			velocity = Vector3.ZERO
			_animate_model(delta)
			return

	if player == null:
		return
	_tick_daylight_burn(delta)
	_ambient_sound_t -= delta
	if _ambient_sound_t <= 0.0:
		_ambient_sound_t = randf_range(7.0, 18.0)
		if global_position.distance_to(player.global_position) <= 24.0:
			play_mob_sound("idle")
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
	if _knockback_t > 0.0:
		_knockback_t -= delta
		velocity.x = move_toward(velocity.x, 0.0, 9.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 9.0 * delta)
		_animate_model(delta)
		move_and_slide()
		return

	var to_player = player.global_position - global_position
	var dist = Vector2(to_player.x, to_player.z).length()

	if ai_states.has("explode") and _aggressive() and dist < EXPLODE_RANGE:
		_explode()
		return

	# Erebos Demon: staring curse — look at it → slowness-like slow for 3s, then it sprints
	if mob_id == "erebos_demon" and dist < 12.0 and player != null:
		var to_p = (player.global_position - global_position).normalized()
		var facing = -global_transform.basis.z.normalized().dot(to_p) if true else 1.0
		# Approximate: if player looks roughly toward us
		if player.get("camera") != null:
			var cam = player.camera
			if cam != null:
				var look = -cam.global_transform.basis.z.normalized()
				var to_m = (global_position - cam.global_position).normalized()
				if look.dot(to_m) > 0.85:
					if "walk_speed" in player:
						player.set_meta("gaze_slow_t", 3.0)
		speed = 7.0  # sprint toward player when near

	if _aggressive() and dist < DETECTION and dist > ATTACK_RANGE:
		_steer(to_player, speed)
	elif _aggressive() and dist <= ATTACK_RANGE:
		velocity.x = 0.0
		velocity.z = 0.0
		_attack_t -= delta
		if _attack_t <= 0.0 and attack_damage > 0.0:
			_attack_t = ATTACK_COOLDOWN
			play_mob_sound("attack")
			player.mob_hit(attack_damage, global_position)
	else:
		_wander(delta)
	_step_sound_t -= delta
	if is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.4 and _step_sound_t <= 0.0:
		_step_sound_t = randf_range(0.45, 0.7)
		play_mob_sound("step")

	_animate_model(delta)
	move_and_slide()


func _refresh_nearest_player() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var nearest: Node3D = null
	var nearest_sq := INF
	for candidate in tree.get_nodes_in_group("players"):
		if candidate == null or not is_instance_valid(candidate) or not (candidate is Node3D):
			continue
		var d := global_position.distance_squared_to(candidate.global_position)
		if d < nearest_sq:
			nearest_sq = d
			nearest = candidate
	if nearest != null:
		player = nearest


func _physics_process_dragon(delta: float) -> void:
	# Kreisflug, dann landen (~10s) damit Spieler angreifen kann, dann wieder hoch.
	if not _flight_ready:
		_flight_center = Vector3(player.global_position.x, player.global_position.y + 2.0, player.global_position.z)
		_flight_angle = 0.0
		_flight_ready = true
		_dive_t = 4.0

	_dive_t -= delta
	_step_sound_t -= delta
	if _step_sound_t <= 0.0:
		_step_sound_t = randf_range(1.2, 2.0)
		play_mob_sound("step")
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
				play_mob_sound("attack")
				player.mob_hit(attack_damage, global_position)
		if _land_t <= 0.0:
			_landing = false
			_diving = false
			_dive_t = DRAGON_DIVE_COOLDOWN
			_flight_center = Vector3(player.global_position.x, player.global_position.y + 2.0, player.global_position.z)
	elif _diving:
		target_pos = player.global_position + Vector3(0, 2.5, 0)
		if dist < ATTACK_RANGE * 2.2:
			if attack_damage > 0.0:
				play_mob_sound("attack")
				player.mob_hit(attack_damage, global_position)
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


	_animate_model(delta)

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


func play_mob_sound(kind: String) -> void:
	# kind: idle, hurt, death, attack, step
	var map = {
		"cow": {"idle": "cow_moo", "hurt": "cow_hurt"},
		"mooshroom": {"idle": "cow_moo", "hurt": "cow_hurt"},
		"pig": {"idle": "pig_oink", "hurt": "pig_oink"},
		"chicken": {"idle": "chicken_cluck", "hurt": "chicken_cluck"},
		"sheep": {"idle": "sheep_baa", "hurt": "sheep_baa"},
		"zombie": {"idle": "zombie_groan", "hurt": "zombie_hurt", "attack": "zombie_attack", "step": "zombie_step"},
		"husk": {"idle": "zombie_groan", "hurt": "zombie_hurt", "attack": "zombie_attack", "step": "zombie_step"},
		"zombie_villager": {"idle": "zombie_groan", "hurt": "zombie_hurt", "attack": "zombie_attack", "step": "zombie_step"},
		"zombie_pigman": {"idle": "zombie_groan", "hurt": "zombie_hurt", "attack": "zombie_attack", "step": "zombie_step"},
		"skeleton": {"idle": "skeleton_bones", "hurt": "skeleton_hurt", "attack": "skeleton_bow", "step": "skeleton_step"},
		"stray": {"idle": "skeleton_bones", "hurt": "skeleton_hurt", "attack": "skeleton_bow", "step": "skeleton_step"},
		"wither_skeleton": {"idle": "skeleton_bones", "hurt": "skeleton_hurt", "attack": "skeleton_bones", "step": "skeleton_step"},
		"creeper": {"hurt": "creeper_hurt", "death": "creeper_death"},
		"spider": {"hurt": "spider_hurt", "attack": "spider_attack", "step": "spider_step"},
		"enderman": {"idle": "enderman_idle", "hurt": "enderman_hurt", "attack": "enderman_scream"},
		"erebus_foreigner": {"idle": "enderman_idle", "hurt": "enderman_hurt", "attack": "enderman_scream"},
		"blaze": {"idle": "blaze_fire", "hurt": "blaze_hurt", "attack": "blaze_shoot"},
		"ghast": {"idle": "ghast_cry", "hurt": "ghast_scream", "attack": "ghast_shoot"},
		"villager": {"idle": "villager_hrmm", "hurt": "villager_hurt", "yes": "villager_yes", "no": "villager_no"},
		"wolf": {"idle": "wolf_bark", "hurt": "wolf_bark"},
		"ender_dragon": {"idle": "dragon_growl", "hurt": "dragon_roar", "attack": "dragon_roar", "step": "dragon_flap"},
		"bat": {"idle": "bat_chirp"},
		"slime": {"hurt": "slime_squish", "step": "slime_jump"},
		"magma_cube": {"hurt": "magma_squish", "step": "magma_squish"},
		"wither": {"hurt": "wither_hurt", "death": "wither_death"},
		"cave_spider": {"hurt": "spider_hurt", "attack": "spider_attack", "step": "spider_step"},
		"ocelot": {"idle": "cat_meow", "hurt": "cat_hiss"},
		"horse": {"idle": "horse_idle", "hurt": "horse_hurt"},
		"rabbit": {"idle": "rabbit_idle", "hurt": "rabbit_hurt"},
		"squid": {"hurt": "squid_hurt"},
		"witch": {"idle": "witch_idle", "hurt": "witch_hurt", "attack": "witch_idle"},
		"silverfish": {"hurt": "silverfish_hurt", "step": "silverfish_step"},
		"endermite": {"hurt": "endermite_hurt"},
		"shulker": {"hurt": "shulker_hurt", "attack": "shulker_shoot"},
		"soulwraith": {"idle": "ghast_cry", "hurt": "ghast_scream"},
		"erebite": {"idle": "enderman_idle", "hurt": "enderman_hurt"},
		"iron_golem": {"hurt": "golem_hit", "attack": "golem_hit"},
		"snow_golem": {"hurt": "snow_crunch"},
	}
	var entry = map.get(mob_id, {})
	var key = entry.get(kind, "")
	if key != "" and Audio:
		Audio.play(key, -8.0)


func take_hit(dmg: float) -> void:
	play_mob_sound("hurt")
	_show_hurt_flash()

	health -= dmg
	_provoked = true
	_regen_t = 0.0
	Audio.play("hit", -6.0)
	# passive mobs flee away from the player
	if category == "passive" and player != null and is_instance_valid(player):
		var away = (global_position - player.global_position)
		_steer(away, speed)
	if health <= 0.0:
		_die()


func apply_knockback(source_position: Vector3, strength: float = 4.2) -> void:
	var away := global_position - source_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3(0, 0, 1)
	away = away.normalized()
	velocity.x = away.x * strength
	velocity.z = away.z * strength
	velocity.y = maxf(velocity.y, 2.6)
	_knockback_t = 0.22


func _show_hurt_flash() -> void:
	_hurt_flash_t = 0.14
	_set_hurt_overlay(true)


func _set_hurt_overlay(enabled: bool) -> void:
	var overlay: StandardMaterial3D = null
	if enabled:
		overlay = StandardMaterial3D.new()
		overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		overlay.albedo_color = Color(1.0, 0.18, 0.12, 0.62)
		overlay.emission_enabled = true
		overlay.emission = Color(1.0, 0.08, 0.04)
		overlay.emission_energy_multiplier = 1.35
	for node in find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = overlay


func _die() -> void:
	play_mob_sound("death")
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

			if randf() <= chance and player != null and player.inventory != null:
				player.inventory.add(item_id, count)
		elif drop is String:
			# Fallback für alte/simple Drops
			if player != null and player.inventory != null:
				player.inventory.add(drop, 1)


func set_charged(on: bool) -> void:
	set_meta("charged", on)
	if on:
		scale = Vector3(1.3, 1.3, 1.3)


func _tick_daylight_burn(delta: float) -> void:
	if category != "hostile":
		return
	if mob_id in ["creeper", "spider", "cave_spider", "witch", "slime", "silverfish"]:
		return
	var g = get_tree().get_first_node_in_group("game")
	if g == null or not g.has_method("is_night"):
		return
	if g.is_night() or bool(g.get("is_raining")):
		return
	if str(g.get("current_dim")) != "overworld":
		return
	# Burn undead / pigmen in sunlight
	if mob_id in ["zombie", "husk", "skeleton", "stray", "zombie_villager", "zombie_pigman", "erebite", "erebus_foreigner"]:
		health -= 2.0 * delta
		if health <= 0.0:
			_die()


func _explode() -> void:
	play_mob_sound("death")
	var radius := 4.0
	if bool(get_meta("charged", false)):
		radius = 6.0
	var boom := Explosion.new()
	boom.radius = radius
	boom.damage = 18.0 if bool(get_meta("charged", false)) else 12.0
	var root = get_tree().current_scene
	if root:
		root.add_child(boom)
	var g = get_tree().get_first_node_in_group("game")
	var world = g.world if g != null else null
	var renderer = g.renderer if g != null else null
	boom.explode(global_position, world, renderer)
	_drop_loot()
	queue_free()
