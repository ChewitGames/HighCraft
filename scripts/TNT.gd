extends Node3D

@export var fuse_time: float = 1.5
var is_lit := false

func ignite() -> void:
	if is_lit: return
	is_lit = true
	print("TNT ignited!")
	await get_tree().create_timer(fuse_time).timeout
	explode()

func explode() -> void:
	var explosion = Explosion.new()
	get_parent().add_child(explosion)
	explosion.explode(global_position)
	queue_free()
