class_name RecipeBookUI
extends CanvasLayer
## Lists all Registry recipes; click to show ingredients.

signal closed

var _list: ItemList
var _detail: RichTextLabel
var _filter: LineEdit
var _recipes: Array = []


func setup() -> void:
	layer = 80
	var panel = Panel.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.12, 0.14, 0.96)
	st.border_color = Color(0.4, 0.45, 0.5)
	st.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(520, 420)
	panel.position = Vector2(160, 80)
	add_child(panel)
	var v = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(v)
	var title = Label.new()
	title.text = "Recipe Book"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	v.add_child(title)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Search..."
	_filter.text_changed.connect(_rebuild)
	v.add_child(_filter)
	var split = HSplitContainer.new()
	split.custom_minimum_size = Vector2(0, 300)
	v.add_child(split)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(220, 280)
	_list.item_selected.connect(_on_select)
	split.add_child(_list)
	_detail = RichTextLabel.new()
	_detail.fit_content = true
	_detail.custom_minimum_size = Vector2(240, 280)
	split.add_child(_detail)
	var close = Button.new()
	close.text = "Close"
	close.pressed.connect(func():
		closed.emit()
		queue_free()
	)
	v.add_child(close)
	_recipes = Registry.recipes.duplicate()
	_rebuild("")


func _rebuild(text: String = "") -> void:
	_list.clear()
	var q = text.strip_edges().to_lower()
	for i in range(_recipes.size()):
		var r = _recipes[i]
		var res = str(r.get("result", r.get("output", "?")))
		if q != "" and not res.to_lower().contains(q):
			continue
		_list.add_item(res)
		_list.set_item_metadata(_list.item_count - 1, i)


func _on_select(idx: int) -> void:
	var ri = _list.get_item_metadata(idx)
	if ri == null or ri < 0 or ri >= _recipes.size():
		return
	var r = _recipes[ri]
	var res = str(r.get("result", "?"))
	var lines = "[b]%s[/b]\nType: %s\n\nIngredients:\n" % [res, str(r.get("type", "?"))]
	if r.has("ingredients"):
		for ing in r["ingredients"]:
			lines += " • %s\n" % str(ing)
	elif r.has("pattern"):
		for row in r["pattern"]:
			lines += " %s\n" % str(row)
		if r.has("key"):
			lines += "\nKey:\n"
			for k in r["key"].keys():
				lines += " %s = %s\n" % [k, str(r["key"][k])]
	_detail.text = lines
