extends Node
# HighCraft Audio — real files + synth fallback.
# RULE: the same SFX name never overlaps itself — it restarts from the beginning.
# Different SFX can play together (separate players).

const RATE = 22050
const MAX_VOICES = 12
const MOB_SFX_NAMES := [
	"bat_chirp", "blaze_fire", "blaze_hurt", "blaze_shoot", "cat_meow",
	"chicken_cluck", "cow_hurt", "cow_moo", "creeper_death", "creeper_fuse",
	"creeper_hurt", "dragon_flap", "dragon_growl", "dragon_roar",
	"enderman_hurt", "enderman_idle", "enderman_scream", "enderman_teleport",
	"ghast_cry", "ghast_scream", "ghast_shoot", "magma_squish", "pig_oink",
	"player_attack", "player_death", "player_hurt", "player_jump",
	"player_step_grass", "player_step_stone", "player_step_wood", "sheep_baa",
	"skeleton_bones", "skeleton_bow", "skeleton_hurt", "skeleton_step",
	"slime_jump", "slime_squish", "spider_attack", "spider_hurt", "spider_step",
	"villager_hrmm", "villager_hurt", "villager_no", "villager_yes",
	"wither_death", "wither_hurt", "wither_spawn", "wolf_bark",
	"zombie_attack", "zombie_groan", "zombie_hurt", "zombie_step"
]
const WORLD_SFX_NAMES := [
	"break_dirt", "break_glass", "break_grass_block", "break_leaves",
	"break_metal", "break_sand", "break_stone", "break_wood", "chest_close",
	"chest_open", "door_close_wood", "door_open_wood", "fire_ignite",
	"lava_ambient", "lava_flow", "lava_pop", "player_armor_on",
	"player_arrow_shoot", "player_drink", "player_eat", "player_inventory_close",
	"player_inventory_open", "player_item_drop", "player_item_pickup",
	"ui_achievement", "ui_click", "ui_error", "water_splash", "weather_rain"
]

var _sfx: Dictionary = {}
# One dedicated player per active sound name → no self-overlap
var _named_players: Dictionary = {}  # name -> AudioStreamPlayer
var _pool: Array = []
var _pool_i: int = 0


func _ready() -> void:
	for i in range(MAX_VOICES):
		var p = AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_sfx["dig_grass"] = _noise(0.16, 0.35, 1)
	_sfx["dig_stone"] = _noise(0.16, 0.4, 2)
	_sfx["dig_wood"] = _noise(0.17, 0.38, 3)
	_sfx["dig_sand"] = _noise(0.2, 0.3, 4)
	_sfx["place"] = _noise(0.12, 0.45, 5)
	_sfx["break"] = _noise(0.25, 0.5, 6)
	_sfx["click"] = _tone(900.0, 0.05, 0.3)
	_sfx["step"] = _noise(0.08, 0.25, 7)
	_sfx["hit"] = _noise(0.12, 0.6, 8)
	_sfx["hurt"] = _noise(0.18, 0.7, 9)
	_sfx["explode"] = _noise(0.35, 0.9, 10)
	_load_real_sfx()


func _load_real_sfx() -> void:
	var folders = [
		"res://assets/highcraft_sounds_effects/",
		"res://assets/highcraft_mobs_sounds/",
	]
	var aliases = {
		"ui_click": "click",
		"break_stone": "dig_stone",
		"break_wood": "dig_wood",
		"break_dirt": "dig_grass",
		"break_grass_block": "dig_grass",
		"break_sand": "dig_sand",
		"break_metal": "dig_stone",
		"break_glass": "break",
		"break_leaves": "dig_grass",
		"player_hurt": "hurt",
		"player_attack": "hit",
		"chest_open": "click",
		"chest_close": "click",
		"door_open_wood": "click",
		"door_close_wood": "click",
		"player_inventory_open": "click",
		"player_inventory_close": "click",
		"player_item_pickup": "place",
		"player_item_drop": "place",
		"water_splash": "step",
		"fire_ignite": "place",
		"lightning_strike": "explode",
	}
	# Export-safe manifest. Imported resources inside a PCK are not guaranteed to
	# appear in DirAccess with their original extension, so exact res:// loads are
	# required instead of relying only on directory enumeration.
	_load_sfx_manifest("res://assets/highcraft_mobs_sounds/", MOB_SFX_NAMES, ".wav", aliases)
	_load_sfx_manifest("res://assets/highcraft_sounds_effects/", WORLD_SFX_NAMES, ".wav", aliases)
	_load_one_sfx("res://assets/highcraft_sounds_effects/lightning_strike.mp3", aliases)
	for folder in folders:
		var dir = DirAccess.open(folder)
		if dir == null:
			continue
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".wav") or fname.ends_with(".mp3") or fname.ends_with(".ogg"):
				var key = fname.get_basename()
				var stream = load(folder + fname)
				if stream != null:
					_sfx[key] = stream
					if aliases.has(key):
						_sfx[aliases[key]] = stream
			fname = dir.get_next()
	print("[Audio] loaded ", _sfx.size(), " sfx (no self-overlap pipeline)")


func _load_sfx_manifest(folder: String, names: Array, extension: String, aliases: Dictionary) -> void:
	for sound_name in names:
		_load_one_sfx(folder + str(sound_name) + extension, aliases)


func _load_one_sfx(path: String, aliases: Dictionary) -> void:
	if not ResourceLoader.exists(path):
		push_warning("[Audio] exported SFX missing: " + path)
		return
	var stream = load(path)
	if stream == null:
		push_warning("[Audio] failed to load SFX: " + path)
		return
	var key := path.get_file().get_basename()
	_sfx[key] = stream
	if aliases.has(key):
		_sfx[aliases[key]] = stream


## Play SFX. Same name restarts instead of stacking. Different names mix.
func play(name: String, volume_db: float = -6.0) -> void:
	if not _sfx.has(name):
		if name.begins_with("player_"):
			var alt = name.replace("player_", "")
			if _sfx.has(alt):
				name = alt
			else:
				return
		else:
			return
	var stream = _sfx[name]
	var player: AudioStreamPlayer
	if _named_players.has(name) and is_instance_valid(_named_players[name]):
		player = _named_players[name]
	else:
		player = AudioStreamPlayer.new()
		add_child(player)
		_named_players[name] = player
	player.stream = stream
	player.volume_db = volume_db
	if player.playing:
		player.stop()
	player.play()


func dig_group(block_id: String) -> String:
	if block_id.find("log") >= 0 or block_id.find("plank") >= 0 or block_id.find("wood") >= 0:
		return "break_wood" if _sfx.has("break_wood") else "dig_wood"
	if block_id.find("sand") >= 0:
		return "break_sand" if _sfx.has("break_sand") else "dig_sand"
	if block_id.find("glass") >= 0:
		return "break_glass" if _sfx.has("break_glass") else "break"
	if block_id.find("copper") >= 0 or block_id.find("iron") >= 0:
		return "break_metal" if _sfx.has("break_metal") else "dig_stone"
	if block_id == "grass_block" or block_id == "dirt" or block_id.find("farmland") >= 0 or block_id.find("wheat") >= 0:
		return "break_grass_block" if _sfx.has("break_grass_block") else "dig_grass"
	return "break_stone" if _sfx.has("break_stone") else "dig_stone"


func play_dig(block_id: String) -> void:
	play(dig_group(block_id))


func play_step(block_id: String = "grass") -> void:
	if block_id.find("wood") >= 0 or block_id.find("plank") >= 0:
		play("player_step_wood" if _sfx.has("player_step_wood") else "step", -12.0)
	elif block_id.find("stone") >= 0:
		play("player_step_stone" if _sfx.has("player_step_stone") else "step", -12.0)
	else:
		play("player_step_grass" if _sfx.has("player_step_grass") else "step", -12.0)


func _env(i: int, n: int, attack: float, release: float) -> float:
	var ti = float(i) / n
	var a = 1.0
	if attack > 0.0:
		a = minf(1.0, ti / attack)
	var r = 1.0
	if release > 0.0:
		r = minf(1.0, (1.0 - ti) / release)
	return a * r


func _make_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var s = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s


func _noise(dur: float, vol: float, seed_val: int) -> AudioStreamWAV:
	var n = int(RATE * dur)
	var samples = PackedFloat32Array()
	samples.resize(n)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	for i in range(n):
		samples[i] = rng.randf_range(-1.0, 1.0) * vol * _env(i, n, 0.02, 0.3)
	return _make_stream(samples)


func _tone(freq: float, dur: float, vol: float) -> AudioStreamWAV:
	var n = int(RATE * dur)
	var samples = PackedFloat32Array()
	samples.resize(n)
	for i in range(n):
		var t = float(i) / RATE
		samples[i] = sin(t * freq * TAU) * vol * _env(i, n, 0.01, 0.4)
	return _make_stream(samples)
