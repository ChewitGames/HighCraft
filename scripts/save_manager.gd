class_name SaveManager
extends RefCounted
# Reads/writes the HighCraft save file (JSON) in the user data directory.

const LEGACY_PATH = "user://highcraft_save.json"
const WORLDS_DIR = "user://worlds"


static func has_save() -> bool:
	return not list_worlds().is_empty()


static func write(data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORLDS_DIR))
	var world_id := str(data.get("world_id", "world_%d" % Time.get_unix_time_from_system()))
	var f = FileAccess.open(_path_for(world_id), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


static func read():
	var worlds := list_worlds()
	if worlds.is_empty():
		return null
	return read_world(str(worlds[0].get("world_id", "")))


static func read_world(world_id: String):
	var path := _path_for(world_id)
	if not FileAccess.file_exists(path):
		return null
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text = f.get_as_text()
	f.close()
	return JSON.parse_string(text)


static func list_worlds() -> Array:
	_migrate_legacy_save()
	var result: Array = []
	var dir := DirAccess.open(WORLDS_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var f := FileAccess.open(WORLDS_DIR + "/" + file_name, FileAccess.READ)
			if f != null:
				var data = JSON.parse_string(f.get_as_text())
				f.close()
				if data is Dictionary:
					result.append({
						"world_id": str(data.get("world_id", file_name.trim_suffix(".json"))),
						"world_name": str(data.get("world_name", "World")),
						"seed": data.get("seed", "?"),
						"modified": FileAccess.get_modified_time(WORLDS_DIR + "/" + file_name)
					})
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a, b): return int(a.get("modified", 0)) > int(b.get("modified", 0)))
	return result


static func rename_world(world_id: String, new_name: String) -> bool:
	var clean := new_name.strip_edges()
	if clean == "":
		return false
	var data = read_world(world_id)
	if not (data is Dictionary):
		return false
	data["world_name"] = clean
	return write(data)


static func _path_for(world_id: String) -> String:
	var safe := ""
	for ch in world_id:
		if ch.is_valid_identifier() or ch.is_valid_int() or ch in ["-", "_"]:
			safe += ch
	if safe == "":
		safe = "world"
	return WORLDS_DIR + "/" + safe + ".json"


static func _migrate_legacy_save() -> void:
	if not FileAccess.file_exists(LEGACY_PATH):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORLDS_DIR))
	var f := FileAccess.open(LEGACY_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		if str(data.get("world_id", "")) == "":
			data["world_id"] = "legacy_world"
		if str(data.get("world_name", "")) == "":
			data["world_name"] = "Imported World"
		var target := _path_for(str(data["world_id"]))
		if not FileAccess.file_exists(target):
			var out := FileAccess.open(target, FileAccess.WRITE)
			if out != null:
				out.store_string(JSON.stringify(data))
				out.close()
