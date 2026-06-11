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

	if config.has("default"):
		row.set_meta("default_value", float(config["default"]))
		row.set_meta("slider_step", slider.step)
		slider.draw.connect(func() -> void:
			var span := slider.max_value - slider.min_value
			if span <= 0.0:
				return
			var t := clampf((float(row.get_meta("default_value")) - slider.min_value) / span, 0.0, 1.0)
			var x := slider.size.x * t
			var center_y := slider.size.y * 0.5
			slider.draw_line(
				Vector2(x, center_y - 4.0),
				Vector2(x, center_y + 4.0),
				Color(1.0, 1.0, 1.0, 0.55),
				2.0
			)
		)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(float(config.get("value_width", 44.0)), 0)
	if config.has("value"):
		value_label.text = "%.2f" % float(config["value"])
	row.add_child(value_label)

	if config.has("default"):
		slider.gui_input.connect(func(event: InputEvent) -> void:
			var mouse := event as InputEventMouseButton
			if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT and mouse.double_click:
				UiRows.reset_row_to_default({"row": row, "slider": slider, "value_label": value_label, "name_label": label})
		)

	parent.add_child(row)
	return {"row": row, "slider": slider, "value_label": value_label, "name_label": label}

static func reset_row_to_default(widgets: Dictionary) -> void:
	if not widgets.has("row") or not widgets.has("slider"):
		return
	var row := widgets["row"] as Control
	var slider := widgets["slider"] as HSlider
	if row == null or slider == null or not row.has_meta("default_value"):
		return
	slider.value = float(row.get_meta("default_value"))
	if widgets.has("value_label") and widgets["value_label"] is Label:
		(widgets["value_label"] as Label).text = "%.2f" % slider.value
	update_changed_marker(widgets)

static func is_changed_from_default(widgets: Dictionary) -> bool:
	if not widgets.has("row") or not widgets.has("slider"):
		return false
	var row := widgets["row"] as Control
	var slider := widgets["slider"] as HSlider
	if row == null or slider == null or not row.has_meta("default_value"):
		return false
	var step := maxf(float(row.get_meta("slider_step", slider.step)), 0.000001)
	return absf(slider.value - float(row.get_meta("default_value"))) > step * 0.5

static func update_changed_marker(widgets: Dictionary) -> void:
	if not widgets.has("name_label") or not widgets["name_label"] is Label:
		return
	var name_label := widgets["name_label"] as Label
	if is_changed_from_default(widgets):
		name_label.add_theme_color_override("font_color", Color(1.0, 0.74, 0.28))
	else:
		name_label.remove_theme_color_override("font_color")
