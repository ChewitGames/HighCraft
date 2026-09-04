extends Node
# HighCraft - Multiplayer Manager (autoload "Multiplayer")
# Supports LAN + automatic Tailscale IP detection

const DEFAULT_PORT = 4242
const MAX_PLAYERS = 8

var is_host: bool = false
var is_multiplayer: bool = false
var pvp_enabled: bool = true
var server_ip: String = ""
var public_ip: String = ""
var tailscale_ip: String = ""
var _pending_world_edits: Array = []
var _pending_world_peers: Array = []
var _peer_skins: Dictionary = {}

var upnp: UPNP


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	_detect_tailscale_ip()


func _detect_tailscale_ip() -> void:
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		if addr.begins_with("100."):
			tailscale_ip = addr
			print("[Multiplayer] Tailscale IP detected: ", tailscale_ip)
			return


func _on_peer_connected(id: int) -> void:
	print("[Multiplayer] Player connected: ", id)
	if is_host:
		rpc_id(id, "sync_pvp_setting", pvp_enabled)
		if has_node("/root/Config"):
			var cfg = get_node("/root/Config")
			rpc_id(id, "sync_world_config", {
				"seed": cfg.seed_val, "world_id": cfg.world_id,
				"world_type": cfg.world_type, "structures": cfg.generate_structures,
				"game_mode": cfg.game_mode, "difficulty": cfg.difficulty,
				"pvp": pvp_enabled
			})
		# Ask game to push edits to this peer. Hosting can begin in the main menu,
		# before Game has connected the signal, so retain early requests.
		if has_meta("game") and is_instance_valid(get_meta("game")):
			peer_ready_for_world.emit(id)
		else:
			_pending_world_peers.append(id)
		# A late joiner must receive every avatar already present, not only future
		# skin changes.
		for peer_id in _peer_skins.keys():
			var entry: Dictionary = _peer_skins[peer_id]
			rpc_id(id, "_rpc_player_skin_relay", int(peer_id), str(entry.get("name", "afro_steve")), entry.get("data", {}))

signal peer_ready_for_world(peer_id: int)
signal player_state_received(peer_id: int, position: Vector3, yaw: float, pitch: float, held_item_id: String, held_enchantments: Dictionary)
signal player_left(peer_id: int)
signal player_skin_received(peer_id: int, skin_name: String, skin_data: Dictionary)
signal world_config_received


func _on_peer_disconnected(id: int) -> void:
	print("[Multiplayer] Player disconnected: ", id)
	_peer_skins.erase(id)
	player_left.emit(id)


func _on_connected_to_server() -> void:
	print("[Multiplayer] Connected to server")
	is_multiplayer = true


func _on_connection_failed() -> void:
	print("[Multiplayer] Connection failed")
	is_multiplayer = false


func _on_server_disconnected() -> void:
	print("[Multiplayer] Server disconnected")
	is_multiplayer = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ==================== HOSTING ====================
func host_server(port: int = DEFAULT_PORT, enable_upnp: bool = true) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("Failed to create server on port " + str(port))
		return false

	multiplayer.multiplayer_peer = peer
	is_host = true
	is_multiplayer = true
	server_ip = IP.get_local_addresses()[0] + ":" + str(port)

	if enable_upnp:
		_try_upnp(port)

	_detect_tailscale_ip()
	print("[Multiplayer] Server started on port ", port)
	return true


func _try_upnp(port: int) -> void:
	upnp = UPNP.new()
	var result = upnp.discover(2000)
	if result != UPNP.UPNP_RESULT_SUCCESS:
		print("[UPnP] Discovery failed (common on mobile hotspots)")
		return

	var gateway = upnp.get_gateway()
	if gateway and gateway.is_valid_gateway():
		var map_result = upnp.add_port_mapping(port, port, "HighCraft", "UDP")
		if map_result == UPNP.UPNP_RESULT_SUCCESS:
			public_ip = upnp.query_external_address()
			print("[UPnP] Success! Public IP: ", public_ip)
		else:
			print("[UPnP] Port mapping failed")
	else:
		print("[UPnP] No valid gateway found")


# ==================== JOINING ====================
func join_server(ip: String, port: int = DEFAULT_PORT) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		push_error("Failed to connect to " + ip + ":" + str(port))
		return false

	multiplayer.multiplayer_peer = peer
	is_host = false
	is_multiplayer = true
	print("[Multiplayer] Joining ", ip, ":", port)
	return true


func host_with_room(port: int = -1, display_name: String = "") -> Dictionary:
	var use_port: int = DEFAULT_PORT if port <= 0 else port
	var ok = host_server(use_port, true)
	if not ok:
		return {"ok": false, "error": "Failed to start server on port %d" % use_port}
	var ip = RoomCode.pick_lan_ip()
	var code = RoomCode.encode(ip, use_port)
	server_ip = "%s:%d" % [ip, use_port]
	return {"ok": true, "name": display_name, "code": code, "ip": ip, "port": use_port}


func join_room_code(code: String) -> Dictionary:
	var decoded = RoomCode.decode(code)
	if not decoded.get("ok", false):
		return decoded
	var ip: String = decoded["ip"]
	var port: int = decoded["port"]
	var ok = join_server(ip, port)
	if not ok:
		return {"ok": false, "error": "Failed to connect to %s:%d" % [ip, port]}
	return {"ok": true, "ip": ip, "port": port}


func disconnect_from_server() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false
	is_multiplayer = false
	_peer_skins.clear()


func set_local_player_skin(skin_name: String, skin_data: Dictionary) -> void:
	if not is_multiplayer or multiplayer.multiplayer_peer == null:
		return
	var own_id := multiplayer.get_unique_id()
	_peer_skins[own_id] = {"name": skin_name, "data": skin_data.duplicate(true)}
	if is_host:
		for peer_id in multiplayer.get_peers():
			rpc_id(peer_id, "_rpc_player_skin_relay", own_id, skin_name, skin_data)
	else:
		rpc_id(1, "_rpc_player_skin", skin_name, skin_data)


func get_peer_skins() -> Dictionary:
	return _peer_skins.duplicate(true)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_player_skin(skin_name: String, skin_data: Dictionary) -> void:
	if not is_host:
		return
	var origin_peer := multiplayer.get_remote_sender_id()
	_peer_skins[origin_peer] = {"name": skin_name, "data": skin_data.duplicate(true)}
	player_skin_received.emit(origin_peer, skin_name, skin_data)
	for peer_id in multiplayer.get_peers():
		if peer_id != origin_peer:
			rpc_id(peer_id, "_rpc_player_skin_relay", origin_peer, skin_name, skin_data)


@rpc("authority", "call_remote", "reliable")
func _rpc_player_skin_relay(peer_id: int, skin_name: String, skin_data: Dictionary) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	_peer_skins[peer_id] = {"name": skin_name, "data": skin_data.duplicate(true)}
	player_skin_received.emit(peer_id, skin_name, skin_data)


# ==================== PvP ====================
@rpc("authority", "call_local", "reliable")
func sync_pvp_setting(enabled: bool) -> void:
	pvp_enabled = enabled


@rpc("authority", "call_remote", "reliable")
func sync_world_config(data: Dictionary) -> void:
	if has_node("/root/Config"):
		var cfg = get_node("/root/Config")
		cfg.seed_val = int(data.get("seed", cfg.seed_val))
		cfg.world_id = str(data.get("world_id", cfg.world_id))
		cfg.world_type = str(data.get("world_type", "normal"))
		cfg.generate_structures = bool(data.get("structures", true))
		cfg.game_mode = int(data.get("game_mode", 1))
		cfg.difficulty = int(data.get("difficulty", 2))
		cfg.pvp_enabled = bool(data.get("pvp", true))
		cfg.pending_save = null
		cfg.load_regions_from_disk = false
	pvp_enabled = bool(data.get("pvp", true))
	world_config_received.emit()


func set_pvp(enabled: bool) -> void:
	if is_host:
		pvp_enabled = enabled
		rpc("sync_pvp_setting", enabled)


func is_server() -> bool:
	return is_host and multiplayer.is_server()
	
	
signal chat_received(player_num: int, msg: String)

func send_chat(player_num: int, msg: String) -> void:
	chat_received.emit(player_num, msg)
	if multiplayer.multiplayer_peer != null:
		rpc("_rpc_chat_msg", player_num, msg)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_chat_msg(player_num: int, msg: String) -> void:
	chat_received.emit(player_num, msg)


# ==================== CONNECTION INFO ====================
func get_connection_info() -> String:
	var info = ""
	
	if tailscale_ip != "":
		info += "Tailscale IP: " + tailscale_ip + ":" + str(DEFAULT_PORT) + "\n"
	
	if server_ip != "":
		info += "Local IP: " + server_ip + "\n"
	
	if public_ip != "":
		info += "Public IP (UPnP): " + public_ip + ":" + str(DEFAULT_PORT) + "\n"
	
	if info == "":
		info = "No connection info available.\n"
	
	info += "\nFor internet play use Tailscale or set up port forwarding."
	return info


# ==================== PLAYER STATE ====================
## Movement is transient state: unreliable delivery avoids old packets piling
## up and 10 Hz from Game is enough because remote avatars interpolate.
func broadcast_player_state(position: Vector3, yaw: float, pitch: float, held_item_id: String = "", held_enchantments: Dictionary = {}) -> void:
	if not is_multiplayer or multiplayer.multiplayer_peer == null:
		return
	var own_id := multiplayer.get_unique_id()
	if is_host:
		for peer_id in multiplayer.get_peers():
			rpc_id(peer_id, "_rpc_player_state_relay", own_id, position, yaw, pitch, held_item_id, held_enchantments)
	else:
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			rpc_id(1, "_rpc_player_state", position, yaw, pitch, held_item_id, held_enchantments)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_player_state(position: Vector3, yaw: float, pitch: float, held_item_id: String = "", held_enchantments: Dictionary = {}) -> void:
	if not is_host:
		return
	var origin_peer := multiplayer.get_remote_sender_id()
	player_state_received.emit(origin_peer, position, yaw, pitch, held_item_id, held_enchantments)
	for peer_id in multiplayer.get_peers():
		if peer_id != origin_peer:
			rpc_id(peer_id, "_rpc_player_state_relay", origin_peer, position, yaw, pitch, held_item_id, held_enchantments)


@rpc("authority", "call_remote", "unreliable")
func _rpc_player_state_relay(peer_id: int, position: Vector3, yaw: float, pitch: float, held_item_id: String = "", held_enchantments: Dictionary = {}) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	player_state_received.emit(peer_id, position, yaw, pitch, held_item_id, held_enchantments)



# ==================== WORLD BLOCK SYNC ====================
signal block_received(x: int, y: int, z: int, id: String)

## Call when local player places/breaks a block
func broadcast_block(x: int, y: int, z: int, id: String) -> void:
	if not is_multiplayer or multiplayer.multiplayer_peer == null:
		return
	var own_id := multiplayer.get_unique_id()
	if is_host:
		for peer_id in multiplayer.get_peers():
			rpc_id(peer_id, "_rpc_block_edit_relay", own_id, x, y, z, id)
	else:
		rpc_id(1, "_rpc_block_edit", x, y, z, id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_block_edit(x: int, y: int, z: int, id: String) -> void:
	if not is_host:
		return
	var origin_peer := multiplayer.get_remote_sender_id()
	block_received.emit(x, y, z, id)
	# Relay only to the other peers. The sender already applied its local edit;
	# echoing it back caused a second expensive chunk rebuild.
	for peer_id in multiplayer.get_peers():
		if peer_id != origin_peer:
			rpc_id(peer_id, "_rpc_block_edit_relay", origin_peer, x, y, z, id)


@rpc("authority", "call_remote", "reliable")
func _rpc_block_edit_relay(_origin_peer: int, x: int, y: int, z: int, id: String) -> void:
	block_received.emit(x, y, z, id)


## Host sends full edit list to a joining peer
func send_edits_to_peer(peer_id: int, edits: Array) -> void:
	if not is_host:
		return
	# Large worlds can contain thousands of edits. One giant reliable RPC causes
	# a serialization hitch and may exceed a practical ENet packet size.
	const EDIT_BATCH_SIZE := 256
	var offset := 0
	while offset < edits.size():
		var batch := edits.slice(offset, mini(offset + EDIT_BATCH_SIZE, edits.size()))
		rpc_id(peer_id, "_rpc_receive_edits", batch)
		offset += EDIT_BATCH_SIZE


@rpc("authority", "call_remote", "reliable")
func _rpc_receive_edits(edits: Array) -> void:
	# Game listens via signal or applies if registered
	if has_meta("game") and get_meta("game") != null:
		var g = get_meta("game")
		if g.has_method("apply_remote_edits"):
			g.apply_remote_edits(edits)
	else:
		_pending_world_edits.append_array(edits)


func take_pending_world_edits() -> Array:
	var out := _pending_world_edits
	_pending_world_edits = []
	return out


func take_pending_world_peers() -> Array:
	var out := _pending_world_peers
	_pending_world_peers = []
	return out
