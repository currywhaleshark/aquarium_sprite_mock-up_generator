class_name UiRows
extends RefCounted

## Shared builders for the parameter editor panels.
##
## All panels render numeric controls as a horizontal row shaped exactly as
## [Label, HSlider, value Label]. Several tests locate widgets by this child
## order (row.get_child(0) is the label, row.get_child(1) is the slider), so the
## ordering here must stay stable.
static func add_labeled_slider(parent: Node, label_text: String, config: Dictionary) -> Dictionary:
	var row := HBoxContainer.new()
	var row_height := float(config.get("row_height", 28.0))
	if row_height > 0.0:
		row.custom_minimum_size = Vector2(0, row_height)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(float(config.get("label_width", 112.0)), 0)
	label.clip_text = true
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = float(config.get("min", 0.0))
	slider.max_value = float(config.get("max", 1.0))
	slider.step = float(config.get("step", 0.005))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if config.has("value"):
		slider.value = float(config["value"])
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(float(config.get("value_width", 44.0)), 0)
	if config.has("value"):
		value_label.text = "%.2f" % float(config["value"])
	row.add_child(value_label)

	parent.add_child(row)
	return {"row": row, "slider": slider, "value_label": value_label}
