extends Node
# HighCraft - audio (autoload singleton "Audio").
# You have no SFX yet, so HighCraft synthesizes simple placeholder sounds at
# runtime as AudioStreamWAV (noise/tone bursts). A small voice pool lets a few
# play at once. Drop real .wav/.ogg later and load them instead.

const RATE = 22050
const VOICES = 6

var _sfx: Dictionary = {}
var _players: Array = []
var _next: int = 0


func _ready() -> void:
	for i in range(VOICES):
		var p = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_sfx["dig_grass"] = _noise(0.16, 0.35, 1)
	_sfx["dig_stone"] = _noise(0.16, 0.4, 2)
	_sfx["dig_wood"] = _noise(0.17, 0.38, 3)
	_sfx["dig_sand"] = _noise(0.2, 0.3, 4)
	_sfx["place"] = _noise(0.12, 0.45, 5)
	_sfx["break"] = _noise(0.25, 0.5, 6)
	_sfx["click"] = _tone(900.0, 0.05, 0.3)

	# === NEW GENERIC SOUNDS (for footsteps, combat, explosions) ===
	_sfx["step"]   = _noise(0.08, 0.25, 7)      # light footstep
	_sfx["hit"]    = _noise(0.12, 0.6, 8)       # generic hit/punch sound
	_sfx["hurt"]   = _noise(0.18, 0.7, 9)       # player/mob hurt
	_sfx["explode"] = _noise(0.35, 0.9, 10)     # explosion (creeper, tnt, etc.)


func play(name: String, volume_db: float = -6.0) -> void:
	if not _sfx.has(name):
		return
	var p = _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _sfx[name]
	p.volume_db = volume_db
	p.play()


func dig_group(block_id: String) -> String:
	if block_id.find("log") >= 0 or block_id.find("plank") >= 0:
		return "dig_wood"
	if block_id.find("sand") >= 0:
		return "dig_sand"
	if block_id == "grass_block" or block_id == "dirt":
		return "dig_grass"
	return "dig_stone"


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
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	var samples = PackedFloat32Array()
	samples.resize(n)
	for i in range(n):
		samples[i] = vol * _env(i, n, 0.005, 0.3) * (rng.randf() * 2.0 - 1.0)
	return _make_stream(samples)


func _tone(freq: float, dur: float, vol: float) -> AudioStreamWAV:
	var n = int(RATE * dur)
	var samples = PackedFloat32Array()
	samples.resize(n)
	for i in range(n):
		samples[i] = vol * _env(i, n, 0.005, 0.5) * sin(TAU * freq * i / RATE)
	return _make_stream(samples)
