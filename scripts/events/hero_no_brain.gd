class_name HeroNoBrain
extends Mob

func _ready() -> void:
	super()
	speed = 7.5
	health = 1.0

func _aggressive() -> bool:
	return true

func take_hit(dmg: float) -> void:
	# Stirbt in einem Hit und gibt 64 Diamanten
	player.inventory.add("diamond", 64)
	Audio.play("explode", 0.0)
	queue_free()

func _physics_process(delta: float) -> void:
	if player == null:
		return
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0

	var to_player = player.global_position - global_position
	var dist = Vector2(to_player.x, to_player.z).length()

	if dist < 2.2:
		# Explodiert
		player.take_damage(12.0, global_position)
		Audio.play("explode", 0.0)
		queue_free()
		return

	_steer(to_player, speed)
	move_and_slide()
