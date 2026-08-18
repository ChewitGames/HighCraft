class_name Villager
extends Mob
# A villager: a passive mob with a profession and balanced trades. Hitting a
# villager offends it (no more trading) and lowers the village reputation,
# matching the social system from the design.

var profession: String = "farmer"
var reputation: int = 0
var offended: bool = false
var trades: Array = []


func _ready() -> void:
	super()
	var profs = Registry.trades.keys()
	if not profs.is_empty():
		profession = profs[randi() % profs.size()]
		trades = Registry.trades[profession]


func can_trade() -> bool:
	return not offended


func take_hit(dmg: float) -> void:
	offended = true
	reputation = maxi(-30, reputation - 5)
	super(dmg)
