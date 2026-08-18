extends Node
# HighCraft - music manager (autoload singleton "Music").
# Picks X120 tracks per context (menu / overworld / hell / end / heaven) from
# the data pools, applies the dimension volume profile, and schedules the next
# track after a random gap. Music files are user-provided under
# res://assets/music/<folder>/; if a file is missing it is skipped gracefully.
# (Reverb/reverse/lowpass profiles are described in data and can be applied via
# audio buses later; for now volume is applied.)

const MUSIC_DIR = "res://assets/music/"

var current_context: String = "overworld"
var _player: AudioStreamPlayer
var _gap_timer: float = 0.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_on_finished)
	_gap_timer = randf_range(4.0, 12.0)


func pool_for(ctx: String) -> Array:
	if ctx == "menu":
		return Registry.music.get("menu_tracks", [])
	var pool = []
	pool.append_array(Registry.music.get("overworld_tracks", []))
	pool.append_array(Registry.music.get("beta_tracks", []))
	return pool


func subfolder_for(ctx: String) -> String:
	var folders = Registry.music.get("folders", {})
	if ctx == "menu":
		return folders.get("menu", "Main Menu")
	return folders.get("game", "Game Music")


func profile_for(ctx: String) -> Dictionary:
	return Registry.music.get("profiles", {}).get(ctx, {})


func _resolve(track: String, subfolder: String) -> String:
	var base = track.get_basename()
	for cand in [track, base + ".ogg", base + ".wav"]:
		var p = MUSIC_DIR + subfolder + "/" + cand
		if ResourceLoader.exists(p):
			return p
	return ""


func play_for_dimension(ctx: String) -> String:
	current_context = ctx
	var pool = pool_for(ctx)
	if pool.is_empty():
		return ""
	var track = pool[randi() % pool.size()]
	var path = _resolve(track, subfolder_for(ctx))
	var prof = profile_for(ctx)
	if path != "":
		var stream = load(path)
		if stream != null:
			_player.stream = stream
			_player.volume_db = linear_to_db(clampf(prof.get("volume", 1.0), 0.05, 1.0))
			_player.play()
	return track


func _on_finished() -> void:
	var gap = Registry.music.get("overworld_gap_seconds", [600, 1200])
	_gap_timer = randf_range(float(gap[0]), float(gap[1]))


func play_event(track: String, subfolder: String) -> void:
	# one-shot event track (e.g. Charlie Emily). Resumes normal scheduling after.
	if track == "":
		return
	var path = _resolve(track, subfolder)
	if path == "":
		return
	var stream = load(path)
	if stream != null:
		_player.stream = stream
		_player.volume_db = 0.0
		_player.play()


func _process(delta: float) -> void:
	if _gap_timer > 0.0:
		_gap_timer -= delta
		if _gap_timer <= 0.0 and not _player.playing:
			play_for_dimension(current_context)
