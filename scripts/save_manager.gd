class_name SaveManager
extends RefCounted
# Reads/writes the HighCraft save file (JSON) in the user data directory.

const PATH = "user://highcraft_save.json"


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


static func write(data: Dictionary) -> bool:
	var f = FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


static func read():
	if not has_save():
		return null
	var f = FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return null
	var text = f.get_as_text()
	f.close()
	return JSON.parse_string(text)
