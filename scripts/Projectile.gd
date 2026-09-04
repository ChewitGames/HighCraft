extends Node3D
class_name Projectile

@export var speed: float = 25.0
@export var gravity: float = 9.8
@export var damage: float = 6.0
@export var lifetime: float = 5.0

var velocity: Vector3 = Vector3.ZERO
var shooter = null
var time_alive: float = 0.0

func _ready() -> void:
	set_as_top_level(true)

func setup(direction: Vector3, shooter_node = null) -> void:
	velocity = direction.normalized() * speed
	shooter = shooter_node
	look_at(global_position + velocity, Vector3.UP)

func _physics_process(delta: float) -> void:
	time_alive += delta
	if time_alive > lifetime:
		queue_free()
		return

	# Simple gravity
	velocity.y -= gravity * delta

	# Move
	global_position += velocity * delta

	# Simple ground check (can be improved)
	if global_position.y < 0:
		queue_free()
		return

	# TODO: Add raycast or Area3D for proper collision & damage
	
	# Einfacher Schaden-Check
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + velocity.normalized() * 2)
	var hit = space.intersect_ray(query)

	if not hit.is_empty():
		var collider = hit.get("collider")
		if collider and collider.has_method("take_hit"):
			collider.take_hit(damage)
			if collider.has_method("apply_knockback"):
				collider.apply_knockback(global_position, 3.2)
			queue_free()
