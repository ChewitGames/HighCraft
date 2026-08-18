extends Node
class_name Explosion

@export var radius: float = 4.0
@export var damage: float = 20.0

func explode(origin: Vector3, world = null, renderer = null) -> void:
	print("Explosion at: ", origin)
	Audio.play("explode", 0.0)

	var scene = get_tree().current_scene
	if scene != null and scene.get_world_3d() != null:
		var space_state = scene.get_world_3d().direct_space_state
		var shape := SphereShape3D.new()
		shape.radius = radius
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis(), origin)
		query.collide_with_bodies = true
		query.collide_with_areas = true
		for result in space_state.intersect_shape(query, 32):
			var col = result.get("collider")
			if col == null: continue
			if col.has_method("take_damage"):
				col.take_damage(damage)
			elif col.has_method("take_hit"):
				col.take_hit(damage)
			elif col.has_method("mob_hit"):
				col.mob_hit(damage)

	if world != null and renderer != null:
		var r = int(ceil(radius))
		var ox = floori(origin.x)
		var oy = floori(origin.y)
		var oz = floori(origin.z)
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				for dz in range(-r, r + 1):
					if sqrt(float(dx*dx + dy*dy + dz*dz)) > radius:
						continue
					var bx = ox + dx
					var by = oy + dy
					var bz = oz + dz
					var bid = world.get_block(bx, by, bz)
					if bid == "air" or bid == "bedrock" or bid == "obsidian":
						continue
					var bdata = Registry.get_block(bid)
					if bdata != null and float(bdata.get("hardness", 1.0)) < 0.0:
						continue
					renderer.edit_block(bx, by, bz, "air")

	queue_free()
