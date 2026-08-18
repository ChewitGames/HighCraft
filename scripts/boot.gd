extends Control
# HighCraft - Part 1 boot screen.
# Confirms the data registry + texture pipeline are working. Later parts
# replace this with the real main menu and world.

@onready var label: Label = $Panel/Label
@onready var preview: HBoxContainer = $Panel/Preview


func _ready() -> void:
	var lines: Array = []
	lines.append("HighCraft - Godot edition")
	lines.append("")
	lines.append("Registry: " + Registry.summary())
	lines.append("")
	lines.append("Dimensions: " + str(Registry.dimensions.keys()))
	lines.append("Music records (Schallplatten): " + str(Registry.records.size()))
	lines.append("Renamed mobs present: erebite=" + str(Registry.mobs.has("erebite"))
		+ ", erebus_sovereign=" + str(Registry.mobs.has("erebus_sovereign"))
		+ ", soulwraith=" + str(Registry.mobs.has("soulwraith")))
	lines.append("Excluded water mobs absent: guardian=" + str(not Registry.mobs.has("guardian"))
		+ ", drowned=" + str(not Registry.mobs.has("drowned")))
	lines.append("")
	lines.append("Textures generate on demand (swappable).")
	lines.append("Part 1 complete: project + data + registry + textures.")
	label.text = "\n".join(lines)

	# show a few generated textures so you can SEE the pipeline works
	var sample = ["grass_block", "stone", "diamond_ore", "oak_log",
		"diamond_sword", "iron_chestplate", "water", "glowstone"]
	for id in sample:
		var rect = TextureRect.new()
		rect.texture = Textures.get_texture(id)
		rect.custom_minimum_size = Vector2(48, 48)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview.add_child(rect)

	print(label.text)
