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


func _on_peer_disconnected(id: int) -> void:
	print("[Multiplayer] Player disconnected: ", id)


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


# ==================== PvP ====================
@rpc("authority", "call_local", "reliable")
func sync_pvp_setting(enabled: bool) -> void:
	pvp_enabled = enabled


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
