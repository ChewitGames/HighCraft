class_name ChunkMesher
extends RefCounted
# Builds chunk meshes with face culling: only faces touching a non-opaque
# neighbour are emitted (typically ~99% of faces are skipped). Faces are
# grouped by block type into surfaces so each gets its own texture material.
# Returns two meshes: "collide" (solid blocks) and "liquid" (water/lava, no
# collision). This is the perf-critical step, swappable for a native module.

const CHUNK_SIZE = 16
const LIQUIDS = {"water": true, "lava": true}
const TRANSPARENT_MATS = {"water": true, "lava": true, "glass": true, "ice": true}

# Each face: neighbour offset, outward normal, 4 corner offsets (quad order).
const FACES = [
	{"off": Vector3i(0, 1, 0), "n": Vector3(0, 1, 0),
		"v": [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]},
	{"off": Vector3i(0, -1, 0), "n": Vector3(0, -1, 0),
		"v": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]},
	{"off": Vector3i(1, 0, 0), "n": Vector3(1, 0, 0),
		"v": [Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]},
	{"off": Vector3i(-1, 0, 0), "n": Vector3(-1, 0, 0),
		"v": [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)]},
	{"off": Vector3i(0, 0, 1), "n": Vector3(0, 0, 1),
		"v": [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)]},
	{"off": Vector3i(0, 0, -1), "n": Vector3(0, 0, -1),
		"v": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)]}
]
const UVS = [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]

var _mat_cache: Dictionary = {}
var _fx_water: bool = false
var _fx_wind: bool = false
var _cache_ready: bool = false
var _plant_ids: Dictionary = {}
var _water_shader: Shader
var _plant_wind_shader: Shader


func build(world, chunk) -> Dictionary:
	_plant_ids = {}
	var solid_groups: Dictionary = {}
	var liquid_groups: Dictionary = {}
	var collider_cells: Dictionary = {}
	var base_x = chunk.cx * CHUNK_SIZE
	var base_z = chunk.cz * CHUNK_SIZE

	for key in chunk.blocks.keys():
		var id = chunk.blocks[key]
		var lx = key.x
		var ly = key.y
		var lz = key.z
		var wx = base_x + lx
		var wz = base_z + lz

		var model = Registry.get_block_model(id)
		var is_liquid = LIQUIDS.has(id)

		if model.has("type"):
			match model["type"]:
				"stairs":
					_add_stairs(solid_groups, lx, ly, lz, id)
				"torch":
					_add_torch(solid_groups, lx, ly, lz, id)
				"door", "trapdoor":
					_add_door_or_trapdoor(solid_groups, lx, ly, lz, id, model)
				"cross":
					_add_plant_cross(solid_groups, lx, ly, lz, id)
				"anvil":
					_add_anvil(solid_groups, lx, ly, lz, id)
				"bed":
					_add_bed(solid_groups, lx, ly, lz, id)
				"pressure_plate":
					_add_pressure_plate(solid_groups, lx, ly, lz, id)
				"button":
					_add_button(solid_groups, lx, ly, lz, id)
				"redstone_wire":
					_add_redstone_wire(solid_groups, lx, ly, lz, id)
				"daylight_sensor":
					_add_daylight_sensor(solid_groups, lx, ly, lz, id)
				"chest":
					_add_chest(solid_groups, lx, ly, lz, id)
				"piston", "piston_head":
					_add_piston(solid_groups, lx, ly, lz, id)
				"fence":
					_add_fence(solid_groups, lx, ly, lz, id)
				"fence_gate":
					_add_fence_gate(solid_groups, lx, ly, lz, id, model)
				"lever":
					_add_lever(solid_groups, lx, ly, lz, id)
				"hopper":
					_add_hopper(solid_groups, lx, ly, lz, id)
				"dropper", "dispenser":
					_add_dropper_like(solid_groups, lx, ly, lz, id)
				"rail":
					_add_rail(solid_groups, lx, ly, lz, id)
				"repeater", "comparator":
					_add_repeater_like(solid_groups, lx, ly, lz, id)
				_:
					pass

			# Wichtig: Unique-Blöcke sollen trotzdem Collider bekommen
			if not is_liquid and Registry.is_solid(id):
				collider_cells[Vector3i(lx, ly, lz)] = true
			continue

		# === Normaler Cube-Code (nur wenn kein spezielles Model) ===
		for f in FACES:
			var off = f["off"]
			var nx = lx + off.x
			var ny = ly + off.y
			var nz = lz + off.z

			if ny < 0:
				continue

			var nb: String
			if nx >= 0 and nx < CHUNK_SIZE and nz >= 0 and nz < CHUNK_SIZE:
				nb = chunk.get_local(nx, ny, nz)
			else:
				nb = world.get_block_no_gen(wx + off.x, ny, wz + off.z)

			var show = false
			if is_liquid:
				show = (nb == "air")
			elif not Registry.is_opaque(nb):
				show = true

			if not show:
				continue

			var groups = liquid_groups if is_liquid else solid_groups
			if not groups.has(id):
				groups[id] = {
					"v": PackedVector3Array(),
					"n": PackedVector3Array(),
					"uv": PackedVector2Array(),
					"idx": PackedInt32Array()
				}
			var buf = groups[id]
			var start = buf["v"].size()

			for i in range(4):
				var vv = f["v"][i]
				buf["v"].append(Vector3(lx + vv.x, ly + vv.y, lz + vv.z))
				buf["n"].append(f["n"])
				buf["uv"].append(UVS[i])

			buf["idx"].append(start)
			buf["idx"].append(start + 1)
			buf["idx"].append(start + 2)
			buf["idx"].append(start)
			buf["idx"].append(start + 2)
			buf["idx"].append(start + 3)

			if not is_liquid and Registry.is_solid(id):
				collider_cells[Vector3i(lx, ly, lz)] = true

	return {
		"collide": _to_mesh(solid_groups),
		"liquid": _to_mesh(liquid_groups),
		"collider_cells": collider_cells.keys()
	}
	
	
func _add_anvil(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	if not groups.has(id):
		groups[id] = {
			"v": PackedVector3Array(),
			"n": PackedVector3Array(),
			"uv": PackedVector2Array(),
			"idx": PackedInt32Array()
		}
	var b = groups[id]

	# === UNTERE BASIS (breit) ===
	_add_box(b, lx, ly, lz, 0.0, 0.25, 0.15, 0.85, 0.0, 1.0)   # y = 0.0 - 0.25

	# === MITTLERER TEIL (schmaler) ===
	_add_box(b, lx, ly, lz, 0.2, 0.8, 0.35, 0.65, 0.25, 0.75)  # y = 0.25 - 0.75

	# === OBERE PLATTE (wieder breit) ===
	_add_box(b, lx, ly, lz, 0.1, 0.9, 0.2, 0.8, 0.75, 1.0)     # y = 0.75 - 1.0

	# === HORN (Spitze rechts) ===
	_add_box(b, lx, ly, lz, 0.85, 1.0, 0.35, 0.65, 0.8, 0.95)  # Horn


# Hilfsfunktion für einfache Boxen (spart viel Code)
func _add_box(b: Dictionary, lx: int, ly: int, lz: int, 
			  x_min: float, x_max: float, 
			  z_min: float, z_max: float, 
			  y_min: float, y_max: float) -> void:

	# Bottom
	_add_quad(b, lx, ly, lz, Vector3(x_min, y_min, z_min), Vector3(x_max, y_min, z_min),
			  Vector3(x_max, y_min, z_max), Vector3(x_min, y_min, z_max), Vector3(0, -1, 0))
	# Top
	_add_quad(b, lx, ly, lz, Vector3(x_min, y_max, z_min), Vector3(x_min, y_max, z_max),
			  Vector3(x_max, y_max, z_max), Vector3(x_max, y_max, z_min), Vector3(0, 1, 0))
	# Front (-Z)
	_add_quad(b, lx, ly, lz, Vector3(x_min, y_min, z_min), Vector3(x_max, y_min, z_min),
			  Vector3(x_max, y_max, z_min), Vector3(x_min, y_max, z_min), Vector3(0, 0, -1))
	# Back (+Z)
	_add_quad(b, lx, ly, lz, Vector3(x_min, y_min, z_max), Vector3(x_min, y_max, z_max),
			  Vector3(x_max, y_max, z_max), Vector3(x_max, y_min, z_max), Vector3(0, 0, 1))
	# Left (-X)
	_add_quad(b, lx, ly, lz, Vector3(x_min, y_min, z_min), Vector3(x_min, y_min, z_max),
			  Vector3(x_min, y_max, z_max), Vector3(x_min, y_max, z_min), Vector3(-1, 0, 0))
	# Right (+X)
	_add_quad(b, lx, ly, lz, Vector3(x_max, y_min, z_min), Vector3(x_max, y_max, z_min),
			  Vector3(x_max, y_max, z_max), Vector3(x_max, y_min, z_max), Vector3(1, 0, 0))


func _add_plant_cross(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	_plant_ids[id] = true
	if not groups.has(id):
		groups[id] = {
			"v": PackedVector3Array(),
			"n": PackedVector3Array(),
			"uv": PackedVector2Array(),
			"idx": PackedInt32Array()
		}
	var b = groups[id]

	# Erstes Quad (eine Diagonale)
	_add_quad(b, lx, ly, lz,
		Vector3(0.1, 0, 0.1), Vector3(0.1, 1, 0.1),
		Vector3(0.9, 1, 0.9), Vector3(0.9, 0, 0.9),
		Vector3(0, 0, 1))

	# Zweites Quad (die andere Diagonale)
	_add_quad(b, lx, ly, lz,
		Vector3(0.9, 0, 0.1), Vector3(0.9, 1, 0.1),
		Vector3(0.1, 1, 0.9), Vector3(0.1, 0, 0.9),
		Vector3(0, 0, -1))

# ==================== NEUE FUNKTIONEN (komplett) ====================

func _add_stairs(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	if not groups.has(id):
		groups[id] = {
			"v": PackedVector3Array(),
			"n": PackedVector3Array(),
			"uv": PackedVector2Array(),
			"idx": PackedInt32Array()
		}
	var b = groups[id]

	# === UNTERE STUFE (y = 0.0 bis 0.5) - voller Block ===
	# Bottom
	_add_quad(b, lx, ly, lz, Vector3(0,0,0), Vector3(1,0,0), Vector3(1,0,1), Vector3(0,0,1), Vector3(0,-1,0))
	# Top der unteren Stufe
	_add_quad(b, lx, ly, lz, Vector3(0,0.5,0), Vector3(0,0.5,1), Vector3(1,0.5,1), Vector3(1,0.5,0), Vector3(0,1,0))
	# Front
	_add_quad(b, lx, ly, lz, Vector3(0,0,0), Vector3(1,0,0), Vector3(1,0.5,0), Vector3(0,0.5,0), Vector3(0,0,-1))
	# Back
	_add_quad(b, lx, ly, lz, Vector3(0,0,1), Vector3(0,0.5,1), Vector3(1,0.5,1), Vector3(1,0,1), Vector3(0,0,1))
	# Left
	_add_quad(b, lx, ly, lz, Vector3(0,0,0), Vector3(0,0,1), Vector3(0,0.5,1), Vector3(0,0.5,0), Vector3(-1,0,0))
	# Right
	_add_quad(b, lx, ly, lz, Vector3(1,0,0), Vector3(1,0.5,0), Vector3(1,0.5,1), Vector3(1,0,1), Vector3(1,0,0))

	# === OBERE STUFE (y = 0.5 bis 1.0) - nur hintere Hälfte (z = 0.5 bis 1.0) ===
	# Top der oberen Stufe  ←←← DAS FEHLTE!
	_add_quad(b, lx, ly, lz, Vector3(0,1,0.5), Vector3(0,1,1), Vector3(1,1,1), Vector3(1,1,0.5), Vector3(0,1,0))
	
	# Front der oberen Stufe (Riser)
	_add_quad(b, lx, ly, lz, Vector3(0,0.5,0.5), Vector3(1,0.5,0.5), Vector3(1,1,0.5), Vector3(0,1,0.5), Vector3(0,0,-1))
	# Back
	_add_quad(b, lx, ly, lz, Vector3(0,0.5,1), Vector3(0,1,1), Vector3(1,1,1), Vector3(1,0.5,1), Vector3(0,0,1))
	# Left
	_add_quad(b, lx, ly, lz, Vector3(0,0.5,0.5), Vector3(0,0.5,1), Vector3(0,1,1), Vector3(0,1,0.5), Vector3(-1,0,0))
	# Right
	_add_quad(b, lx, ly, lz, Vector3(1,0.5,0.5), Vector3(1,1,0.5), Vector3(1,1,1), Vector3(1,0.5,1), Vector3(1,0,0))

func _add_torch(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	if not groups.has(id):
		groups[id] = {
			"v": PackedVector3Array(),
			"n": PackedVector3Array(),
			"uv": PackedVector2Array(),
			"idx": PackedInt32Array()
		}
	var b = groups[id]

	var pole_w = 0.12
	var pole_h = 0.6

	# Pfahl
	_add_quad(b, lx, ly, lz, Vector3(0.44,0,0.44), Vector3(0.56,0,0.44), Vector3(0.56,0,0.56), Vector3(0.44,0,0.56), Vector3(0,-1,0))
	_add_quad(b, lx, ly, lz, Vector3(0.44,pole_h,0.44), Vector3(0.44,pole_h,0.56), Vector3(0.56,pole_h,0.56), Vector3(0.56,pole_h,0.44), Vector3(0,1,0))
	_add_quad(b, lx, ly, lz, Vector3(0.44,0,0.44), Vector3(0.56,0,0.44), Vector3(0.56,pole_h,0.44), Vector3(0.44,pole_h,0.44), Vector3(0,0,-1))
	_add_quad(b, lx, ly, lz, Vector3(0.44,0,0.56), Vector3(0.44,pole_h,0.56), Vector3(0.56,pole_h,0.56), Vector3(0.56,0,0.56), Vector3(0,0,1))
	_add_quad(b, lx, ly, lz, Vector3(0.44,0,0.44), Vector3(0.44,0,0.56), Vector3(0.44,pole_h,0.56), Vector3(0.44,pole_h,0.44), Vector3(-1,0,0))
	_add_quad(b, lx, ly, lz, Vector3(0.56,0,0.44), Vector3(0.56,pole_h,0.44), Vector3(0.56,pole_h,0.56), Vector3(0.56,0,0.56), Vector3(1,0,0))

	# Flamme (Kreuz)
	var fy = pole_h
	_add_quad(b, lx, ly, lz, Vector3(0.5,fy,0.3), Vector3(0.5,fy+0.35,0.3), Vector3(0.5,fy+0.35,0.7), Vector3(0.5,fy,0.7), Vector3(1,0,0))
	_add_quad(b, lx, ly, lz, Vector3(0.3,fy,0.5), Vector3(0.3,fy+0.35,0.5), Vector3(0.7,fy+0.35,0.5), Vector3(0.7,fy,0.5), Vector3(0,0,1))
func _add_door_or_trapdoor(groups: Dictionary, lx: int, ly: int, lz: int, id: String, model: Dictionary) -> void:
	if not groups.has(id):
		groups[id] = {
			"v": PackedVector3Array(),
			"n": PackedVector3Array(),
			"uv": PackedVector2Array(),
			"idx": PackedInt32Array()
		}
	var b = groups[id]

	var is_open = model.get("open", false)
	var is_trapdoor = id.begins_with("trapdoor")

	if is_trapdoor:
		# === TRAPDOOR ===
		if is_open:
			# Offen = vertikal
			_add_quad(b, lx, ly, lz, Vector3(0,0,0.45), Vector3(1,0,0.45), Vector3(1,1,0.45), Vector3(0,1,0.45), Vector3(0,0,-1))
			_add_quad(b, lx, ly, lz, Vector3(0,0,0.55), Vector3(0,1,0.55), Vector3(1,1,0.55), Vector3(1,0,0.55), Vector3(0,0,1))
			_add_quad(b, lx, ly, lz, Vector3(0,0,0.45), Vector3(0,0,0.55), Vector3(0,1,0.55), Vector3(0,1,0.45), Vector3(-1,0,0))
			_add_quad(b, lx, ly, lz, Vector3(1,0,0.45), Vector3(1,1,0.45), Vector3(1,1,0.55), Vector3(1,0,0.55), Vector3(1,0,0))
		else:
			# Geschlossen = flach oben (hier war die obere Fläche kaputt)
			# Oben (Top)
			_add_quad(b, lx, ly, lz, Vector3(0,0.8125,0), Vector3(0,0.8125,1), Vector3(1,0.8125,1), Vector3(1,0.8125,0), Vector3(0,1,0))
			# Unten
			_add_quad(b, lx, ly, lz, Vector3(0,0.8125,0), Vector3(1,0.8125,0), Vector3(1,1,0), Vector3(0,1,0), Vector3(0,0,-1))
			_add_quad(b, lx, ly, lz, Vector3(0,0.8125,1), Vector3(0,1,1), Vector3(1,1,1), Vector3(1,0.8125,1), Vector3(0,0,1))
			_add_quad(b, lx, ly, lz, Vector3(0,0.8125,0), Vector3(0,1,0), Vector3(0,1,1), Vector3(0,0.8125,1), Vector3(-1,0,0))
			_add_quad(b, lx, ly, lz, Vector3(1,0.8125,0), Vector3(1,0.8125,1), Vector3(1,1,1), Vector3(1,1,0), Vector3(1,0,0))
		# === TÜR ===
	else:
		var thickness = 0.1
		if is_open:
			# Offene Tür → gedreht (entlang der X-Achse)
			_add_quad(b, lx, ly, lz, Vector3(0.45,0,0), Vector3(0.45,2,0), Vector3(0.45,2,1), Vector3(0.45,0,1), Vector3(-1,0,0))
			_add_quad(b, lx, ly, lz, Vector3(0.55,0,0), Vector3(0.55,0,1), Vector3(0.55,2,1), Vector3(0.55,2,0), Vector3(1,0,0))
			_add_quad(b, lx, ly, lz, Vector3(0.45,0,0), Vector3(0.55,0,0), Vector3(0.55,2,0), Vector3(0.45,2,0), Vector3(0,0,-1))
			_add_quad(b, lx, ly, lz, Vector3(0.45,0,1), Vector3(0.45,2,1), Vector3(0.55,2,1), Vector3(0.55,0,1), Vector3(0,0,1))
			_add_quad(b, lx, ly, lz, Vector3(0.45,2,0), Vector3(0.55,2,0), Vector3(0.55,2,1), Vector3(0.45,2,1), Vector3(0,1,0))
		else:
			# Geschlossene Tür → dünne Wand
			_add_quad(b, lx, ly, lz, Vector3(0,0,0.45), Vector3(0,2,0.45), Vector3(1,2,0.45), Vector3(1,0,0.45), Vector3(0,0,-1))
			_add_quad(b, lx, ly, lz, Vector3(0,0,0.55), Vector3(1,0,0.55), Vector3(1,2,0.55), Vector3(0,2,0.55), Vector3(0,0,1))
			_add_quad(b, lx, ly, lz, Vector3(0,0,0.45), Vector3(0,0,0.55), Vector3(0,2,0.55), Vector3(0,2,0.45), Vector3(-1,0,0))
			_add_quad(b, lx, ly, lz, Vector3(1,0,0.45), Vector3(1,2,0.45), Vector3(1,2,0.55), Vector3(1,0,0.55), Vector3(1,0,0))
			_add_quad(b, lx, ly, lz, Vector3(0,2,0.45), Vector3(0,2,0.55), Vector3(1,2,0.55), Vector3(1,2,0.45), Vector3(0,1,0))


func _add_bed(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	if not groups.has(id):
		groups[id] = {
			"v": PackedVector3Array(),
			"n": PackedVector3Array(),
			"uv": PackedVector2Array(),
			"idx": PackedInt32Array()
		}
	var b = groups[id]

	# === Bett ist jetzt 2 Blöcke lang (x = 0 bis 2) ===

	# Matratze (flach, lang)
	_add_quad(b, lx, ly, lz, Vector3(0,0.3,0), Vector3(2,0.3,0), Vector3(2,0.3,1), Vector3(0,0.3,1), Vector3(0,1,0))   # oben
	_add_quad(b, lx, ly, lz, Vector3(0,0.1,0), Vector3(0,0.1,1), Vector3(2,0.1,1), Vector3(2,0.1,0), Vector3(0,-1,0)) # unten

	# Seitenwände
	_add_quad(b, lx, ly, lz, Vector3(0,0.1,0), Vector3(2,0.1,0), Vector3(2,0.3,0), Vector3(0,0.3,0), Vector3(0,0,-1))
	_add_quad(b, lx, ly, lz, Vector3(0,0.1,1), Vector3(0,0.3,1), Vector3(2,0.3,1), Vector3(2,0.1,1), Vector3(0,0,1))

	# Kopfteil (höher, am Ende x=1.6 bis 2)
	_add_quad(b, lx, ly, lz, Vector3(1.6,0.3,0), Vector3(2,0.3,0), Vector3(2,0.9,0), Vector3(1.6,0.9,0), Vector3(0,0,-1))
	_add_quad(b, lx, ly, lz, Vector3(1.6,0.9,0), Vector3(1.6,0.9,1), Vector3(2,0.9,1), Vector3(2,0.9,0), Vector3(0,1,0))

	# Kissen (oben auf dem Kopfteil)
	_add_quad(b, lx, ly, lz, Vector3(1.65,0.85,0.2), Vector3(1.95,0.85,0.2), Vector3(1.95,0.95,0.8), Vector3(1.65,0.95,0.8), Vector3(0,1,0))

	# Fußende (leichte Erhöhung am anderen Ende)
	_add_quad(b, lx, ly, lz, Vector3(0,0.3,0), Vector3(0.4,0.3,0), Vector3(0.4,0.45,0), Vector3(0,0.45,0), Vector3(0,0,-1))


func _add_pressure_plate(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	if not groups.has(id):
		groups[id] = {
			"v": PackedVector3Array(),
			"n": PackedVector3Array(),
			"uv": PackedVector2Array(),
			"idx": PackedInt32Array()
		}
	var b = groups[id]

	# Dünne, eingerückte Platte knapp über dem Boden. "_on" (gedrückt)
	# liegt sichtbar tiefer, damit man den Zustand ohne Textur-Wechsel
	# erkennt.
	var pressed = id.ends_with("_on")
	var y_top = 0.03 if pressed else 0.0625
	_add_box(b, lx, ly, lz, 0.0625, 0.9375, 0.0625, 0.9375, 0.0, y_top)


func _add_button(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	if not groups.has(id):
		groups[id] = {
			"v": PackedVector3Array(),
			"n": PackedVector3Array(),
			"uv": PackedVector2Array(),
			"idx": PackedInt32Array()
		}
	var b = groups[id]

	# Kleiner Quader, bodenmontiert (mittig auf dem Feld liegend). "_on"
	# (gedrückt) ist sichtbar flacher.
	var pressed = id.ends_with("_on")
	var depth = 0.09 if pressed else 0.125
	_add_box(b, lx, ly, lz, 0.3125, 0.6875, 0.4375, 0.5625, 0.0, depth)


func _ensure_group(groups: Dictionary, id: String) -> Dictionary:
	if not groups.has(id):
		groups[id] = {
			"v": PackedVector3Array(),
			"n": PackedVector3Array(),
			"uv": PackedVector2Array(),
			"idx": PackedInt32Array()
		}
	return groups[id]


func _add_redstone_wire(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	var b = _ensure_group(groups, id)
	# Flat cross on the ground — thicker so it's visible
	_add_box(b, lx, ly, lz, 0.15, 0.85, 0.4, 0.6, 0.0, 0.08)
	_add_box(b, lx, ly, lz, 0.4, 0.6, 0.15, 0.85, 0.0, 0.08)


func _add_daylight_sensor(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	var b = _ensure_group(groups, id)
	_add_box(b, lx, ly, lz, 0.0, 1.0, 0.0, 1.0, 0.0, 0.375)


func _add_chest(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	var b = _ensure_group(groups, id)
	# Slightly inset body + raised lid band so it reads as a chest
	_add_box(b, lx, ly, lz, 0.0625, 0.9375, 0.0625, 0.9375, 0.0, 0.875)
	_add_box(b, lx, ly, lz, 0.0, 1.0, 0.35, 0.65, 0.875, 1.0)


func _add_piston(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	var b = _ensure_group(groups, id)
	if id == "piston_head":
		_add_box(b, lx, ly, lz, 0.0, 1.0, 0.0, 1.0, 0.75, 1.0)
		_add_box(b, lx, ly, lz, 0.35, 0.65, 0.35, 0.65, 0.0, 0.75)
	else:
		# Base body + face plate
		_add_box(b, lx, ly, lz, 0.0, 1.0, 0.0, 1.0, 0.0, 0.75)
		_add_box(b, lx, ly, lz, 0.0, 1.0, 0.0, 1.0, 0.75, 1.0)


func _add_fence(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	var b = _ensure_group(groups, id)
	# Center post
	_add_box(b, lx, ly, lz, 0.375, 0.625, 0.375, 0.625, 0.0, 1.0)
	# Simple cross bars (connections would need neighbor checks; visual default)
	_add_box(b, lx, ly, lz, 0.0, 1.0, 0.4375, 0.5625, 0.4, 0.55)
	_add_box(b, lx, ly, lz, 0.0, 1.0, 0.4375, 0.5625, 0.7, 0.85)
	_add_box(b, lx, ly, lz, 0.4375, 0.5625, 0.0, 1.0, 0.4, 0.55)
	_add_box(b, lx, ly, lz, 0.4375, 0.5625, 0.0, 1.0, 0.7, 0.85)


func _add_fence_gate(groups: Dictionary, lx: int, ly: int, lz: int, id: String, model: Dictionary) -> void:
	var b = _ensure_group(groups, id)
	var open = model.get("open", false) or id.ends_with("_open")
	# Side posts always
	_add_box(b, lx, ly, lz, 0.0, 0.125, 0.375, 0.625, 0.0, 1.0)
	_add_box(b, lx, ly, lz, 0.875, 1.0, 0.375, 0.625, 0.0, 1.0)
	if open:
		# Gate swung open (thin panels along Z)
		_add_box(b, lx, ly, lz, 0.0, 0.125, 0.0, 0.4, 0.3, 0.9)
		_add_box(b, lx, ly, lz, 0.875, 1.0, 0.6, 1.0, 0.3, 0.9)
	else:
		# Closed gate across X
		_add_box(b, lx, ly, lz, 0.125, 0.875, 0.4375, 0.5625, 0.35, 0.5)
		_add_box(b, lx, ly, lz, 0.125, 0.875, 0.4375, 0.5625, 0.65, 0.8)
		_add_box(b, lx, ly, lz, 0.45, 0.55, 0.375, 0.625, 0.3, 0.9)


func _add_lever(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	var b = _ensure_group(groups, id)
	_add_box(b, lx, ly, lz, 0.3, 0.7, 0.3, 0.7, 0.0, 0.2)
	var on = id.ends_with("_on")
	if on:
		_add_box(b, lx, ly, lz, 0.45, 0.55, 0.45, 0.7, 0.2, 0.7)
	else:
		_add_box(b, lx, ly, lz, 0.45, 0.55, 0.3, 0.55, 0.2, 0.7)


func _add_quad(b: Dictionary, lx: int, ly: int, lz: int, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3) -> void:
	var start = b["v"].size()
	b["v"].append(Vector3(lx + v0.x, ly + v0.y, lz + v0.z))
	b["v"].append(Vector3(lx + v1.x, ly + v1.y, lz + v1.z))
	b["v"].append(Vector3(lx + v2.x, ly + v2.y, lz + v2.z))
	b["v"].append(Vector3(lx + v3.x, ly + v3.y, lz + v3.z))

	for i in 4:
		b["n"].append(normal)
		b["uv"].append(UVS[i])

	b["idx"].append(start)
	b["idx"].append(start + 1)
	b["idx"].append(start + 2)
	b["idx"].append(start)
	b["idx"].append(start + 2)
	b["idx"].append(start + 3)

func _to_mesh(groups: Dictionary):
	if groups.is_empty():
		return null
	var mesh = ArrayMesh.new()
	for id in groups.keys():
		var buf = groups[id]
		if buf["v"].size() == 0:
			continue
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = buf["v"]
		arrays[Mesh.ARRAY_NORMAL] = buf["n"]
		arrays[Mesh.ARRAY_TEX_UV] = buf["uv"]
		arrays[Mesh.ARRAY_INDEX] = buf["idx"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material_for(id))
	return mesh


func warm_cache() -> void:
	# Call once on the MAIN thread before any meshing.
	# Snapshots settings and pre-builds common materials so build() never
	# touches the scene tree (fast + safe).
	_fx_water = false
	_fx_wind = false
	var loop = Engine.get_main_loop()
	if loop != null and loop.root != null:
		var hs = loop.root.get_node_or_null("HCSettings")
		if hs != null:
			_fx_water = bool(hs.realistic_water)
			_fx_wind = bool(hs.swaying_flowers) or bool(hs.tall_grass_mesh)
	# Preload shaders once
	if _water_shader == null:
		_water_shader = load("res://shaders/water_realistic.gdshader")
	if _plant_wind_shader == null:
		_plant_wind_shader = load("res://shaders/plant_wind.gdshader")
	# Pre-warm frequent block materials
	for id in ["stone", "dirt", "grass_block", "sand", "gravel", "oak_log", "oak_leaves",
			"water", "lava", "bedrock", "coal_ore", "iron_ore", "glass", "snow",
			"oak_planks", "cobblestone", "clay", "ice"]:
		_material_for(id)
	_cache_ready = true


func _get_water_shader() -> Shader:
	if _water_shader == null:
		_water_shader = load("res://shaders/water_realistic.gdshader")
	return _water_shader


func _get_plant_wind_shader() -> Shader:
	if _plant_wind_shader == null:
		_plant_wind_shader = load("res://shaders/plant_wind.gdshader")
	return _plant_wind_shader


func _material_for(id: String) -> Material:
	# Uses ONLY snapshot flags — never queries the scene tree during build.
	var wants_realistic_water = (id == "water") and _fx_water
	var wants_wind = _plant_ids.has(id) and _fx_wind

	var cache_key = id
	if wants_realistic_water:
		cache_key = id + "#water_fx"
	elif wants_wind:
		cache_key = id + "#wind_fx"

	if _mat_cache.has(cache_key):
		return _mat_cache[cache_key]

	var m: Material

	if wants_realistic_water:
		var sm := ShaderMaterial.new()
		sm.shader = _get_water_shader()
		sm.set_shader_parameter("albedo_texture", Textures.get_texture(id))
		m = sm
	elif wants_wind:
		var wm := ShaderMaterial.new()
		wm.shader = _get_plant_wind_shader()
		wm.set_shader_parameter("albedo_texture", Textures.get_texture(id))
		m = wm
	else:
		var sd := StandardMaterial3D.new()
		sd.albedo_texture = Textures.get_texture(id)
		sd.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sd.cull_mode = BaseMaterial3D.CULL_DISABLED
		if TRANSPARENT_MATS.has(id):
			sd.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			if id == "water" or id == "lava":
				sd.albedo_color = Color(1, 1, 1, 0.7)
		m = sd

	_mat_cache[cache_key] = m
	return m


func _add_hopper(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	var b = _ensure_group(groups, id)
	# Top basin
	_add_box(b, lx, ly, lz, 0.0, 1.0, 0.0, 1.0, 0.625, 1.0)
	# Funnel body
	_add_box(b, lx, ly, lz, 0.25, 0.75, 0.25, 0.75, 0.25, 0.625)
	# Bottom spout
	_add_box(b, lx, ly, lz, 0.375, 0.625, 0.375, 0.625, 0.0, 0.25)


func _add_dropper_like(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	var b = _ensure_group(groups, id)
	# Full cube body
	_add_box(b, lx, ly, lz, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0)
	# Front mouth (dark inset on +Z face via thinner plate)
	_add_box(b, lx, ly, lz, 0.25, 0.75, 0.85, 1.0, 0.25, 0.75)


func _add_rail(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	var b = _ensure_group(groups, id)
	# Two rails + ties
	_add_box(b, lx, ly, lz, 0.15, 0.25, 0.0, 1.0, 0.0, 0.08)
	_add_box(b, lx, ly, lz, 0.75, 0.85, 0.0, 1.0, 0.0, 0.08)
	_add_box(b, lx, ly, lz, 0.1, 0.9, 0.2, 0.35, 0.0, 0.05)
	_add_box(b, lx, ly, lz, 0.1, 0.9, 0.65, 0.8, 0.0, 0.05)


func _add_repeater_like(groups: Dictionary, lx: int, ly: int, lz: int, id: String) -> void:
	var b = _ensure_group(groups, id)
	# Flat base
	_add_box(b, lx, ly, lz, 0.0, 1.0, 0.0, 1.0, 0.0, 0.125)
	# Two torch stubs
	_add_box(b, lx, ly, lz, 0.2, 0.35, 0.4, 0.6, 0.125, 0.45)
	_add_box(b, lx, ly, lz, 0.65, 0.8, 0.4, 0.6, 0.125, 0.45)
