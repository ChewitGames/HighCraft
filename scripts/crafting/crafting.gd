class_name Crafting
extends RefCounted
# Recipe matching for a crafting grid. Works for any NxN grid (2x2 personal,
# 3x3 table/toolbench). Shaped recipes are matched by trimming both the grid
# and the recipe pattern to their bounding box so position does not matter.
# Smelting is a simple input -> output lookup. Data comes from the Registry.


static func match_grid(grid: Array, size: int) -> Dictionary:
	# grid: flat Array of item id strings, "" = empty cell, length = size*size
	var present: Array = []
	for c in grid:
		if c != "":
			present.append(c)
	if present.is_empty():
		return {}

	for r in Registry.recipes:
		if r["type"] == "shapeless":
			if _match_shapeless(r, present):
				return {"result": r["result"], "count": r["count"]}
		else:
			if _match_shaped(r, grid, size):
				return {"result": r["result"], "count": r["count"]}
	return {}


static func smelt(input_id: String) -> Dictionary:
	for r in Registry.smelting:
		if r["input"] == input_id:
			return {"result": r["result"], "count": r["count"]}
	return {}


static func _match_shapeless(recipe: Dictionary, present: Array) -> bool:
	var a = present.duplicate()
	var b = recipe["ingredients"].duplicate()
	if a.size() != b.size():
		return false
	a.sort()
	b.sort()
	return a == b


static func _match_shaped(recipe: Dictionary, grid: Array, size: int) -> bool:
	if grid.size() < size * size:
		return false

	var grid2d: Array = []
	for y in range(size):
		var row: Array = []
		for x in range(size):
			var idx = y * size + x
			if idx < grid.size():
				row.append(grid[idx])
			else:
				row.append("")
		grid2d.append(row)

	var trimmed_grid = _trim(grid2d)
	var trimmed_pattern = _trim(recipe["pattern"])
	return trimmed_grid == trimmed_pattern


static func _trim(grid2d: Array) -> Array:
	# drop fully-empty outer rows and columns
	var rows: Array = []
	for row in grid2d:
		var any = false
		for c in row:
			if c != "":
				any = true
				break
		if any:
			rows.append(row)
	if rows.is_empty():
		return [[]]
	var width = rows[0].size()
	var lo = width
	var hi = -1
	for row in rows:
		for x in range(row.size()):
			if row[x] != "":
				lo = mini(lo, x)
				hi = maxi(hi, x)
	var out: Array = []
	for row in rows:
		var nr: Array = []
		for x in range(lo, hi + 1):
			nr.append(row[x] if x < row.size() else "")
		out.append(nr)
	return out
