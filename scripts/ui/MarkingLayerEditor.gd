class_name MarkingLayerEditor
extends VBoxContainer

signal layers_changed(layers: Array)

const LAYER_TYPES := ["lateral_line", "horizontal_band", "vertical_bar", "caudal_spot", "head_mask", "saddle", "ocellus", "calico_patch", "fin_edge", "fin_spots", "scale_grid", "reticulated_zone", "region_color", "scale_region", "iridescence_region"]
const REGIONS := ["body", "dorsal", "flank", "ventral", "dorsal_flank", "ventral_flank", "head", "cheek", "operculum", "caudal_peduncle", "median_fin", "paired_fin", "caudal_fin", "special_fin", "fin"]
const BLEND_MODES := ["normal", "multiply", "screen", "add"]

var layers: Array = []
var _updating := false

func set_layers(new_layers: Array) -> void:
	layers = new_layers.duplicate(true)
	_rebuild()

func _rebuild() -> void:
	_updating = true
	for child in get_children():
		child.queue_free()
	for i in layers.size():
		_add_layer_row(i, layers[i] as Dictionary)
	var add_button := Button.new()
	add_button.text = "+"
	add_button.tooltip_text = "Add regional layer"
	add_button.pressed.connect(func() -> void:
		layers.append({"type": "horizontal_band", "region": "flank", "blend_mode": "normal", "color": "#ffffff", "intensity": 0.0, "x_start": 0.0, "x_end": 1.0, "y": 0.0, "thickness": 0.08})
		_emit_and_rebuild()
	)
	add_child(add_button)
	_updating = false

func _add_layer_row(index: int, layer: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = "Layer_%d" % index
	_add_option(row, index, "type", LAYER_TYPES, String(layer.get("type", "region_color")))
	_add_option(row, index, "region", REGIONS, _region_value_for_layer(layer))
	_add_option(row, index, "blend_mode", BLEND_MODES, String(layer.get("blend_mode", "normal")))
	_add_color_picker(row, index, String(layer.get("color", "#ffffff")))
	_add_number(row, index, "x_start", float(layer.get("x_start", 0.0)), 0.0, 1.0, 0.01)
	_add_number(row, index, "x_end", float(layer.get("x_end", 1.0)), 0.0, 1.0, 0.01)
	_add_number(row, index, "thickness", float(layer.get("thickness", 0.08)), 0.001, 1.0, 0.005)
	var intensity := SpinBox.new()
	intensity.min_value = 0.0
	intensity.max_value = 1.0
	intensity.step = 0.01
	intensity.value = float(layer.get("intensity", 1.0))
	intensity.value_changed.connect(func(value: float) -> void:
		_set_layer_field(index, "intensity", value)
	)
	row.add_child(intensity)
	add_child(row)

func _region_value_for_layer(layer: Dictionary) -> String:
	if layer.has("region"):
		return String(layer.get("region", "body"))
	if String(layer.get("zone", "")) == "fin":
		return "fin"
	return "body"

func _add_option(row: HBoxContainer, index: int, field: String, options: Array, value: String) -> void:
	var option := OptionButton.new()
	for item in options:
		option.add_item(String(item))
	var selected := options.find(value)
	option.select(maxi(selected, 0))
	option.item_selected.connect(func(item_index: int) -> void:
		_set_layer_field(index, field, option.get_item_text(item_index))
	)
	row.add_child(option)

func _add_color_picker(row: HBoxContainer, index: int, value: String) -> void:
	var picker := ColorPickerButton.new()
	picker.tooltip_text = "Color"
	picker.color = _color_from_html(value)
	picker.custom_minimum_size = Vector2(36, 0)
	picker.color_changed.connect(func(new_color: Color) -> void:
		_set_layer_field(index, "color", "#%s" % new_color.to_html(false))
	)
	row.add_child(picker)

func _add_number(row: HBoxContainer, index: int, field: String, value: float, min_value: float, max_value: float, step: float) -> void:
	var spin := SpinBox.new()
	spin.tooltip_text = field
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.custom_minimum_size = Vector2(72, 0)
	spin.value_changed.connect(func(new_value: float) -> void:
		_set_layer_field(index, field, new_value)
	)
	row.add_child(spin)

func _set_layer_field(index: int, field: String, value: Variant) -> void:
	if _updating or index < 0 or index >= layers.size():
		return
	var layer := (layers[index] as Dictionary).duplicate(true)
	if field != "region" and not layer.has("region"):
		layer["region"] = _region_value_for_layer(layer)
	layer[field] = value
	layers[index] = layer
	layers_changed.emit(layers.duplicate(true))

func _emit_and_rebuild() -> void:
	layers_changed.emit(layers.duplicate(true))
	_rebuild()

func _color_from_html(value: String) -> Color:
	if Color.html_is_valid(value):
		return Color.html(value)
	return Color.WHITE
