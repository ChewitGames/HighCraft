extends Node
# Cross-platform external add-on support. Portable desktop builds use the folder
# beside the executable; sandboxed platforms use the platform-owned user:// area.

signal packs_changed
signal download_finished(ok: bool, message: String)

const MANIFEST := "pack.json"
const TYPE_FOLDERS := {
	"mod": "Mods",
	"shader": "Shaders",
	"texture_pack": "Texture Packs",
}

var root_dir: String
var packs: Array[Dictionary] = []
var texture_files: Dictionary = {}
var active_sky_shader: Shader = null
var _mod_nodes: Array[Node] = []
var _http: HTTPRequest
var _download_temp := ""


func _ready() -> void:
	root_dir = _resolve_root_dir()
	_create_folders()
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_download_completed)
	rescan()


func _resolve_root_dir() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://external_addons")
	# Windows/Linux portable builds support the familiar "beside the EXE" layout.
	# Consoles, mobile, Web and macOS app bundles must use writable app storage.
	if OS.has_feature("windows") or OS.has_feature("linuxbsd"):
		var portable := OS.get_executable_path().get_base_dir()
		if DirAccess.make_dir_recursive_absolute(portable.path_join("HighCraft Addons")) == OK:
			return portable.path_join("HighCraft Addons")
	return ProjectSettings.globalize_path("user://HighCraft Addons")


func supports_code_mods() -> bool:
	# Runtime GDScript compilation is intentionally restricted to desktop/editor.
	# Console certification sandboxes normally prohibit downloaded executable code.
	return OS.has_feature("editor") or OS.has_feature("windows") or OS.has_feature("linuxbsd") or OS.has_feature("macos")


func _create_folders() -> void:
	for folder in TYPE_FOLDERS.values():
		DirAccess.make_dir_recursive_absolute(root_dir.path_join(folder))


func get_folder(kind: String) -> String:
	return root_dir.path_join(str(TYPE_FOLDERS.get(kind, "")))


func rescan() -> void:
	packs.clear()
	texture_files.clear()
	active_sky_shader = null
	for kind in TYPE_FOLDERS.keys():
		_scan_type(kind, get_folder(kind))
	packs.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("name", "")) < str(b.get("name", "")))
	_build_texture_index()
	_load_shader_pack()
	var textures := get_node_or_null("/root/Textures")
	if textures != null and textures.has_method("clear_cache"):
		textures.clear_cache()
	call_deferred("_load_mods")
	packs_changed.emit()


func _scan_type(kind: String, folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	# Single-file mods need no manifest: dropping MyMod.gd directly into Mods is
	# enough. Folder-based packs still use pack.json for metadata and extra files.
	if kind == "mod":
		for file in dir.get_files():
			if file.get_extension().to_lower() == "gd":
				packs.append({
					"id": file.get_basename(),
					"name": file.get_basename().replace("_", " ").capitalize(),
					"type": "mod",
					"path": folder,
					"entry": file,
					"enabled": true,
					"single_file": true,
				})
	for entry in dir.get_directories():
		var pack_dir := folder.path_join(entry)
		var manifest_path := pack_dir.path_join(MANIFEST)
		if not FileAccess.file_exists(manifest_path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary:
			var info: Dictionary = parsed.duplicate(true)
			info["type"] = kind
			info["path"] = pack_dir
			info["enabled"] = bool(info.get("enabled", true))
			packs.append(info)


func _build_texture_index() -> void:
	for pack in packs:
		if pack.get("type") != "texture_pack" or not pack.get("enabled", true):
			continue
		var textures_dir := str(pack["path"]).path_join(str(pack.get("textures", "textures")))
		var dir := DirAccess.open(textures_dir)
		if dir == null:
			continue
		for file in dir.get_files():
			if file.get_extension().to_lower() == "png":
				texture_files[file.get_basename()] = textures_dir.path_join(file)


func find_texture(id: String) -> String:
	return str(texture_files.get(id, ""))


func _load_shader_pack() -> void:
	for pack in packs:
		if pack.get("type") != "shader" or not pack.get("enabled", true):
			continue
		var shader_path := str(pack["path"]).path_join(str(pack.get("sky_shader", "sky.gdshader")))
		if not FileAccess.file_exists(shader_path):
			continue
		var shader := Shader.new()
		shader.code = FileAccess.get_file_as_string(shader_path)
		active_sky_shader = shader
		return


func get_sky_shader(fallback: Shader) -> Shader:
	return active_sky_shader if active_sky_shader != null else fallback


func _load_mods() -> void:
	for node in _mod_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_mod_nodes.clear()
	if not supports_code_mods():
		return
	for pack in packs:
		if pack.get("type") != "mod" or not pack.get("enabled", true):
			continue
		var script_path := str(pack["path"]).path_join(str(pack.get("entry", "main.gd")))
		if not FileAccess.file_exists(script_path):
			push_warning("[Addons] Missing mod entry: " + script_path)
			continue
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string(script_path)
		var error := script.reload()
		if error != OK:
			push_error("[Addons] Could not compile mod: " + str(pack.get("name", script_path)))
			continue
		var instance = script.new()
		if not instance is Node:
			push_error("[Addons] Mod entry must extend Node: " + script_path)
			continue
		instance.name = "Mod_" + str(pack.get("id", pack.get("name", "unknown"))).validate_node_name()
		add_child(instance)
		_mod_nodes.append(instance)
		if instance.has_method("on_mod_loaded"):
			instance.call("on_mod_loaded", self)


func notify_game_ready(game: Node) -> void:
	for mod in _mod_nodes:
		if is_instance_valid(mod) and mod.has_method("on_game_ready"):
			mod.call("on_game_ready", game)


func download_zip(url: String) -> Error:
	url = url.strip_edges()
	if url == "" or not (url.begins_with("https://") or url.begins_with("http://")):
		download_finished.emit(false, "Enter a valid http(s) ZIP URL.")
		return ERR_INVALID_PARAMETER
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		download_finished.emit(false, "A download is already running.")
		return ERR_BUSY
	_download_temp = root_dir.path_join(".highcraft_download.zip")
	_http.download_file = _download_temp
	var error := _http.request(url)
	if error != OK:
		download_finished.emit(false, "Could not start download: " + error_string(error))
	return error


func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_http.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		download_finished.emit(false, "Download failed (HTTP %d)." % response_code)
		return
	var message := _install_zip(_download_temp)
	DirAccess.remove_absolute(_download_temp)
	if message.begins_with("ERROR:"):
		download_finished.emit(false, message.trim_prefix("ERROR:"))
	else:
		rescan()
		download_finished.emit(true, message)


func _install_zip(zip_path: String) -> String:
	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		return "ERROR:Downloaded file is not a readable ZIP."
	var files := reader.get_files()
	var manifest_file := ""
	for file in files:
		if file.get_file() == MANIFEST:
			manifest_file = file
			break
	if manifest_file == "":
		reader.close()
		return "ERROR:The ZIP contains no pack.json."
	var manifest_data = JSON.parse_string(reader.read_file(manifest_file).get_string_from_utf8())
	if not manifest_data is Dictionary:
		reader.close()
		return "ERROR:pack.json is invalid."
	var kind := str(manifest_data.get("type", ""))
	if not TYPE_FOLDERS.has(kind):
		reader.close()
		return "ERROR:Unknown pack type: " + kind
	var pack_id := str(manifest_data.get("id", manifest_data.get("name", "pack"))).validate_filename()
	if pack_id == "":
		pack_id = "pack"
	var destination := get_folder(kind).path_join(pack_id)
	DirAccess.make_dir_recursive_absolute(destination)
	var archive_root := manifest_file.get_base_dir()
	for file in files:
		if file.ends_with("/"):
			continue
		if archive_root != "" and not file.begins_with(archive_root + "/"):
			continue
		var relative := file.trim_prefix(archive_root + "/") if archive_root != "" else file
		relative = relative.replace("\\", "/")
		if relative == "" or relative.begins_with("/") or ".." in relative.split("/"):
			continue
		var output := destination.path_join(relative)
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var handle := FileAccess.open(output, FileAccess.WRITE)
		if handle != null:
			handle.store_buffer(reader.read_file(file))
	reader.close()
	return "Installed %s. Restart the world to apply all changes." % str(manifest_data.get("name", pack_id))
