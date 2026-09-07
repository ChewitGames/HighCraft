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
				col.take_damage(damage, origin)
			elif col.has_method("take_hit"):
				col.take_hit(damage)
				if col.has_method("apply_knockback"):
					col.apply_knockback(origin, 7.0)
			elif col.has_method("mob_hit"):
				col.mob_hit(damage)

	if world != null and renderer != null:
		if has_node("/root/Config") and not Config.tnt_explosions_enabled:
			queue_free()
			return
		var r = int(ceil(radius))
		var ox = floori(origin.x)
		var oy = floori(origin.y)
		var oz = floori(origin.z)
		var changed_cells: Array = []
		var chained_tnt: Array[Vector3i] = []
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
					var cell := Vector3i(bx, by, bz)
					if bid == "tnt" and (not has_node("/root/Config") or Config.tnt_chain_reaction_enabled):
						chained_tnt.append(cell)
					world.set_block(bx, by, bz, "air")
					changed_cells.append(cell)
		if renderer.has_method("remesh_cells_now"):
			renderer.remesh_cells_now(changed_cells)
		elif renderer.has_method("remesh_cells"):
			renderer.remesh_cells(changed_cells)
		for cell in chained_tnt:
			var entity = preload("res://scenes/tnt_entity.tscn").instantiate()
			entity.global_position = Vector3(cell) + Vector3(0.5, 0.5, 0.5)
			get_tree().current_scene.add_child(entity)
			entity.setup(world, renderer)
			entity.fuse_time = randf_range(0.25, 0.75)
			entity.ignite()

	queue_free()
