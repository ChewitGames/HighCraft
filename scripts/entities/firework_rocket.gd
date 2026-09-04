class_name FireworkRocket
extends Node3D
## Purely visual firework: no collision, damage, or block edits.

var velocity: Vector3 = Vector3.UP * 9.0
var lifetime: float = 5.0
var _launch_y: float = 0.0
var _target_y: float = 0.0
var _age: float = 0.0
var _exploded: bool = false
var _rocket_mesh: MeshInstance3D
var _trail: GPUParticles3D
var _sparks: Array = []
var _explosion_age: float = 0.0
const EXPLOSION_DURATION := 2.4

func setup(p_direction: Vector3 = Vector3.UP, p_speed: float = 9.0) -> void:
	var direction := p_direction.normalized()
	if direction == Vector3.ZERO:
		direction = Vector3.UP
	# Dispenser rockets may start horizontally, but every firework must climb to
	# its visible burst height instead of flying endlessly along the horizon.
	if direction.y < 0.65:
		direction = (direction + Vector3.UP * 1.35).normalized()
	velocity = direction * p_speed
	_launch_y = global_position.y
	_target_y = _launch_y + randf_range(20.0, 25.0)

func _ready() -> void:
	add_to_group("fireworks")
	_build_rocket()
	_build_trail()
	Audio.play("place")

func _physics_process(delta: float) -> void:
	if _exploded:
		_update_manual_explosion(delta)
		return
	_age += delta
	global_position += velocity * delta
	velocity.y += 1.15 * delta
	if global_position.y >= _target_y:
		global_position.y = _target_y
		_explode_visual_only()
	elif _age >= lifetime:
		# Safety fallback for unusual externally spawned/downward rockets.
		_explode_visual_only()

func _build_rocket() -> void:
	_rocket_mesh = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.035
	mesh.bottom_radius = 0.055
	mesh.height = 0.35
	_rocket_mesh.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.18, 0.12)
	material.emission_enabled = true
	material.emission = Color(0.45, 0.06, 0.02)
	_rocket_mesh.material_override = material
	add_child(_rocket_mesh)

func _build_trail() -> void:
	_trail = GPUParticles3D.new()
	_trail.amount = 24
	_trail.lifetime = 0.45
	_trail.local_coords = false
	_trail.visibility_aabb = AABB(Vector3(-16, -16, -16), Vector3(32, 32, 32))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, -1, 0)
	process.spread = 25.0
	process.gravity = Vector3(0, -1.5, 0)
	process.initial_velocity_min = 0.4
	process.initial_velocity_max = 1.5
	process.scale_min = 0.025
	process.scale_max = 0.07
	process.color = Color(1.0, 0.72, 0.25, 0.85)
	_trail.process_material = process
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.035
	particle_mesh.height = 0.07
	_trail.draw_pass_1 = particle_mesh
	add_child(_trail)
	_trail.emitting = true

func _explode_visual_only() -> void:
	_exploded = true
	_rocket_mesh.visible = false
	_trail.emitting = false
	var palette := [Color(1.0, 0.12, 0.18), Color(0.15, 0.55, 1.0), Color(0.25, 1.0, 0.35), Color(1.0, 0.75, 0.12), Color(0.85, 0.2, 1.0), Color(0.15, 1.0, 0.9)]
	palette.shuffle()
	# Manual MeshInstance sparks are used instead of a one-frame GPU burst. This
	# renders reliably on Compatibility/Mobile renderers and remains clearly
	# visible when the rocket explodes more than twenty blocks above the player.
	for i in range(90):
		_create_spark(palette[i % 3], i)
	_create_center_flash()
	Audio.play("place")

func _create_spark(color: Color, index: int) -> void:
	var spark := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.18
	spark.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 2.5
	material.emission_energy_multiplier = 2.5
	spark.material_override = material
	add_child(spark)
	var direction := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if direction.length_squared() < 0.01:
		direction = Vector3.UP
	direction = direction.normalized()
	_sparks.append({
		"node": spark,
		"direction": direction,
		"speed": randf_range(4.5, 8.0),
		"delay": float(index % 6) * 0.012
	})

func _create_center_flash() -> void:
	var flash := MeshInstance3D.new()
	flash.name = "FireworkFlash"
	var mesh := SphereMesh.new()
	mesh.radius = 0.7
	mesh.height = 1.4
	flash.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.95, 0.75)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.8, 0.45)
	material.emission_energy_multiplier = 4.0
	flash.material_override = material
	add_child(flash)
	_sparks.append({"node": flash, "direction": Vector3.ZERO, "speed": 0.0, "delay": 0.0, "flash": true})

func _update_manual_explosion(delta: float) -> void:
	_explosion_age += delta
	for data in _sparks:
		var spark = data["node"] as MeshInstance3D
		if spark == null or not is_instance_valid(spark):
			continue
		var local_age: float = maxf(0.0, _explosion_age - float(data["delay"]))
		if bool(data.get("flash", false)):
			var flash_fade := clampf(1.0 - local_age / 0.28, 0.0, 1.0)
			spark.scale = Vector3.ONE * flash_fade
			continue
		var direction: Vector3 = data["direction"]
		var speed: float = data["speed"]
		# Expanding sphere followed by a gentle downward firework fall.
		spark.position = direction * speed * local_age + Vector3.DOWN * 1.65 * local_age * local_age
		var fade := clampf(1.0 - local_age / EXPLOSION_DURATION, 0.0, 1.0)
		spark.scale = Vector3.ONE * maxf(0.08, fade)
	if _explosion_age >= EXPLOSION_DURATION:
		queue_free()
