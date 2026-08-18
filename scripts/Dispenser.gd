extends Node3D
# Dünner Wrapper, falls Dispenser-Blöcke irgendwo als eigene Node3D-Instanz
# in der Szene existieren. Die eigentliche Logik (Inventar, Auswerfen,
# Redstone-Trigger) lebt zentral in game.gd::activate_dispenser() +
# DispenserInventory, damit es nur EINE Quelle der Wahrheit gibt statt
# zwei parallele, potenziell widersprüchliche Implementierungen.

var game = null
var cell: Vector3i = Vector3i.ZERO


func setup(p_game, p_cell: Vector3i) -> void:
	game = p_game
	cell = p_cell


func activate() -> void:
	if game != null and game.has_method("activate_dispenser"):
		game.activate_dispenser(cell)
	else:
		push_warning("Dispenser.activate(): kein game-Bezug gesetzt (setup() nicht aufgerufen?)")
