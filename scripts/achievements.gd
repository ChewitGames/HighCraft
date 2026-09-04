class_name Achievements
extends Node
# Simple achievement tracker + toast UI hook.

signal unlocked(id: String, title: String)

var done: Dictionary = {}
const DEFS := {
	"open_inventory": {"title": "Taking Inventory", "desc": "Open your inventory"},
	"mine_stone": {"title": "Stone Age", "desc": "Mine stone with a pickaxe"},
	"plant_wheat": {"title": "A Seedy Place", "desc": "Plant wheat seeds"},
	"ride_boat": {"title": "Whatever Floats", "desc": "Ride a boat"},
	"ride_minecart": {"title": "On A Rail", "desc": "Ride a minecart"},
	"kill_boss": {"title": "Godslayer", "desc": "Defeat a boss or god"},
}


func unlock(id: String) -> void:
	if done.get(id, false):
		return
	if not DEFS.has(id):
		return
	done[id] = true
	var title = DEFS[id]["title"]
	unlocked.emit(id, title)
	if Audio:
		Audio.play("ui_achievement", -4.0)
	print("[Achievement] ", title)
