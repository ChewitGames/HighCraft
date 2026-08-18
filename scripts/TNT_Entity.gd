extends Node3D
class_name TNT_Entity

@export var fuse_time: float = 1.5
var _world = null
var _renderer = null

func setup(p_world = null, p_renderer = null) -> void:
	_world = p_world
	_renderer = p_renderer

func ignite() -> void:
	print("TNT Entity ignited!")
	await get_tree().create_timer(fuse_time).timeout
	explode()

func explode() -> void:
	var explosion = Explosion.new()
	get_parent().add_child(explosion)
	var w = _world
	var r = _renderer
	if w == null or r == null:
		var scene = get_tree().current_scene
		if scene != null:
			if scene.get("world") != null: w = scene.world
			if scene.get("renderer") != null: r = scene.renderer
	explosion.explode(global_position, w, r)
	queue_free()
