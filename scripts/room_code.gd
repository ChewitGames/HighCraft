class_name RoomCode
extends RefCounted
# Short room codes encoding LAN IP + port (no Tailscale required on LAN).
# Internet play still needs reachability (port-forward or future relay).

const ALPH := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


static func encode(ip: String, port: int) -> String:
	var parts = ip.split(".")
	if parts.size() != 4:
		return "LOCAL-%04d" % (port % 10000)
	var n: int = 0
	for p in parts:
		n = (n << 8) | clampi(int(p), 0, 255)
	n = (n << 16) | (port & 0xFFFF)
	return _to_code(n)


static func decode(code: String) -> Dictionary:
	code = code.strip_edges().to_upper().replace(" ", "").replace("-", "")
	if code.begins_with("LOCAL"):
		return {"ok": false, "error": "LOCAL code – use host LAN IP manually"}
	var n := _from_code(code)
	if n < 0:
		return {"ok": false, "error": "Invalid room code"}
	var port = n & 0xFFFF
	n = n >> 16
	var a = [(n >> 24) & 255, (n >> 16) & 255, (n >> 8) & 255, n & 255]
	var ip = "%d.%d.%d.%d" % [a[0], a[1], a[2], a[3]]
	return {"ok": true, "ip": ip, "port": port}


static func _to_code(n: int) -> String:
	var s := ""
	var x: int = n
	for i in range(8):
		s = ALPH[x % ALPH.length()] + s
		x = int(x / ALPH.length())
	return s.substr(0, 4) + "-" + s.substr(4, 4)


static func _from_code(code: String) -> int:
	var n: int = 0
	for i in code.length():
		var idx = ALPH.find(code[i])
		if idx < 0:
			return -1
		n = n * ALPH.length() + idx
	return n


static func pick_lan_ip() -> String:
	var best := "127.0.0.1"
	for addr in IP.get_local_addresses():
		if addr.begins_with("127.") or ":" in addr:
			continue
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
		best = addr
	return best
