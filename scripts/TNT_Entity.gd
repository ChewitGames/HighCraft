extends Node3D
class_name TNT_Entity

@export var fuse_time: float = 1.5
var _world = null
var _renderer = null
var velocity: Vector3 = Vector3.ZERO
var _launched: bool = false

func setup(p_world = null, p_renderer = null) -> void:
	_world = p_world
	_renderer = p_renderer

func ignite() -> void:
	print("TNT Entity ignited!")
	await get_tree().create_timer(fuse_time).timeout
	explode()

func launch(p_velocity: Vector3) -> void:
	velocity = p_velocity
	_launched = true
	ignite()

func _physics_process(delta: float) -> void:
	if not _launched:
		return
	velocity.y -= 9.8 * delta
	global_position += velocity * delta

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
