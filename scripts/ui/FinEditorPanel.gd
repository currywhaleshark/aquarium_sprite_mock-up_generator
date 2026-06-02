class_name FinEditorPanel
extends VBoxContainer

signal parameters_changed(parameters: Dictionary)

const UiText := preload("res://scripts/ui/UiText.gd")
const UiRows := preload("res://scripts/ui/UiRows.gd")

const SLOT_LABELS := {
	"dorsal_1": "Dorsal 1",
	"dorsal_2": "Dorsal 2",
	"pectoral": "Pectoral",
	"pelvic": "Pelvic",
	"anal": "Anal",
	"caudal": "Caudal"
}

const SHAPES := {
	"dorsal_1": ["single", "spiny", "split", "trailing", "trigger", "bezier"],
	"dorsal_2": ["single", "spiny", "split", "trailing", "trigger", "bezier"],
	"pectoral": ["oval", "triangle", "long", "rounded", "bezier"],
	"pelvic": ["triangle", "oval", "long", "rounded", "bezier"],
	"anal": ["long", "single", "spiny", "rounded", "bezier"],
	"caudal": [
		"forked_shallow", "forked_deep", "truncate", "rounded", "pointed", "lunate",
		"fan", "double_fan", "halfmoon", "veil", "crowntail", "spade", "lyre",
		"top_sword", "bottom_sword", "double_sword", "butterfly",
		"shark_heterocercal", "thresher"
	]
}

const NUMERIC_KEYS := {
	"dorsal_1": {
		"dorsal_1_length": {"min": 0.08, "max": 1.2, "step": 0.005, "fallback": 0.42},
		"dorsal_1_height": {"min": 0.04, "max": 0.8, "step": 0.005, "fallback_key": "dorsal_fin_size", "fallback": 0.28},
		"dorsal_fin_offset_x": {"min": -0.55, "max": 0.55, "step": 0.005, "fallback": 0.0}
	},
	"dorsal_2": {
		"dorsal_2_length": {"min": 0.08, "max": 1.2, "step": 0.005, "fallback": 0.34},
		"dorsal_2_height": {"min": 0.04, "max": 0.8, "step": 0.005, "fallback": 0.18}
	},
	"pectoral": {
		"pectoral_fin_size": {"min": 0.04, "max": 0.6, "step": 0.005, "fallback": 0.16},
		"pectoral_fin_offset_x": {"min": -0.55, "max": 0.55, "step": 0.005, "fallback": 0.0}
	},
	"pelvic": {
		"pelvic_length": {"min": 0.04, "max": 0.7, "step": 0.005, "fallback": 0.22},
		"pelvic_height": {"min": 0.03, "max": 0.5, "step": 0.005, "fallback": 0.14}
	},
	"anal": {
		"anal_length": {"min": 0.04, "max": 1.0, "step": 0.005, "fallback": 0.36},
		"anal_height": {"min": 0.03, "max": 0.7, "step": 0.005, "fallback_key": "anal_fin_size", "fallback": 0.2},
		"anal_fin_offset_x": {"min": -0.55, "max": 0.55, "step": 0.005, "fallback": 0.0}
	},
	"caudal": {
		"tail_fin_size": {"min": 0.08, "max": 1.2, "step": 0.005, "fallback": 0.46},
		"caudal_height_scale": {"min": 0.2, "max": 1.8, "step": 0.005, "fallback": 0.72}
	}
}

var parameters: Dictionary = {}
var selected_slot := "dorsal_1"
var slot_option: OptionButton
var enabled_check: CheckBox
var attach_slider: HSlider
var shape_option: OptionButton
var numeric_container: VBoxContainer
var numeric_sliders := {}
var _updating := false

func _ready() -> void:
	var title := Label.new()
	title.text = "지느러미 편집"
	title.add_theme_font_size_override("font_size", 15)
	add_child(title)

	slot_option = OptionButton.new()
	for slot_id in SLOT_LABELS.keys():
		slot_option.add_item(UiText.fin_slot(slot_id))
		slot_option.set_item_metadata(slot_option.item_count - 1, slot_id)
	slot_option.item_selected.connect(func(index: int) -> void:
		selected_slot = String(slot_option.get_item_metadata(index))
		_refresh_controls()
	)
	add_child(slot_option)

	enabled_check = CheckBox.new()
	enabled_check.text = "사용"
	enabled_check.toggled.connect(func(value: bool) -> void:
		if _updating:
			return
		set_slot_enabled(selected_slot, value)
	)
	add_child(enabled_check)

	var attach_row := HBoxContainer.new()
	var attach_label := Label.new()
	attach_label.text = "부착 위치"
	attach_label.custom_minimum_size = Vector2(72, 0)
	attach_row.add_child(attach_label)
	attach_slider = HSlider.new()
	attach_slider.min_value = 0.02
	attach_slider.max_value = 0.98
	attach_slider.step = 0.005
	attach_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attach_slider.value_changed.connect(func(value: float) -> void:
		if _updating:
			return
		set_slot_attach(selected_slot, value)
	)
	attach_row.add_child(attach_slider)
	add_child(attach_row)

	shape_option = OptionButton.new()
	shape_option.item_selected.connect(func(index: int) -> void:
		if _updating:
			return
		set_slot_shape(selected_slot, String(shape_option.get_item_metadata(index)))
	)
	add_child(shape_option)

	numeric_container = VBoxContainer.new()
	numeric_container.add_theme_constant_override("separation", 1)
	add_child(numeric_container)
	_refresh_controls()

func set_parameters(new_parameters: Dictionary) -> void:
	parameters = new_parameters.duplicate(true)
	_refresh_controls()

func set_slot_enabled(slot_id: String, enabled: bool) -> void:
	parameters[_enabled_key(slot_id)] = 1.0 if enabled else 0.0
	parameters_changed.emit(parameters.duplicate(true))
	_refresh_controls()

func set_slot_attach(slot_id: String, attach_t: float) -> void:
	var key := _attach_key(slot_id)
	if key != "":
		parameters[key] = clampf(attach_t, 0.02, 0.98)
		parameters_changed.emit(parameters.duplicate(true))
	_refresh_controls()

func set_slot_shape(slot_id: String, shape: String) -> void:
	parameters[_shape_key(slot_id)] = shape
	parameters_changed.emit(parameters.duplicate(true))
	_refresh_controls()

func set_numeric_parameter(key: String, value: float) -> void:
	var config := _numeric_config_for_key(key)
	if config.is_empty():
		return
	parameters[key] = clampf(value, float(config.get("min", 0.0)), float(config.get("max", 1.0)))
	parameters_changed.emit(parameters.duplicate(true))
	_refresh_controls()

func _refresh_controls() -> void:
	if slot_option == null:
		return
	_updating = true
	enabled_check.button_pressed = float(parameters.get(_enabled_key(selected_slot), _default_enabled(selected_slot))) > 0.5
	var attach_key := _attach_key(selected_slot)
	attach_slider.editable = attach_key != ""
	attach_slider.value = float(parameters.get(attach_key, _default_attach(selected_slot))) if attach_key != "" else 0.5
	
	var shapes: Array = SHAPES.get(selected_slot, ["single"])
	var shape_items_match := true
	if shape_option.item_count != shapes.size():
		shape_items_match = false
	else:
		for i in range(shapes.size()):
			if String(shape_option.get_item_metadata(i)) != String(shapes[i]):
				shape_items_match = false
				break
				
	if not shape_items_match:
		shape_option.clear()
		for shape in shapes:
			shape_option.add_item(UiText.option(String(shape)))
			shape_option.set_item_metadata(shape_option.item_count - 1, String(shape))
			
	var current_shape := String(parameters.get(_shape_key(selected_slot), shapes[0]))
	for i in shape_option.item_count:
		if String(shape_option.get_item_metadata(i)) == current_shape:
			shape_option.select(i)
			break
	_rebuild_numeric_controls()
	_updating = false

func _rebuild_numeric_controls() -> void:
	if numeric_container == null:
		return
		
	var slot_keys: Dictionary = NUMERIC_KEYS.get(selected_slot, {}).duplicate()
	var current_shape := String(parameters.get(_shape_key(selected_slot), ""))
	if current_shape == "bezier":
		var prefix := selected_slot + "_bezier_"
		slot_keys[prefix + "p1_x"] = {"min": -1.0, "max": 1.0, "step": 0.01, "fallback": -0.25}
		slot_keys[prefix + "p1_y"] = {"min": 0.0, "max": 2.0, "step": 0.01, "fallback": 1.0}
		slot_keys[prefix + "p2_x"] = {"min": -1.0, "max": 1.0, "step": 0.01, "fallback": 0.25}
		slot_keys[prefix + "p2_y"] = {"min": 0.0, "max": 2.0, "step": 0.01, "fallback": 1.0}
		
	var match_exact := true
	if numeric_sliders.size() != slot_keys.size():
		match_exact = false
	else:
		for key in slot_keys.keys():
			if not numeric_sliders.has(key):
				match_exact = false
				break
				
	if match_exact:
		for key in slot_keys.keys():
			var widgets: Dictionary = numeric_sliders[key]
			var slider := widgets["slider"] as HSlider
			var label := widgets["label"] as Label
			var value := _numeric_value(String(key), slot_keys[key])
			slider.value = value
			label.text = "%.2f" % value
	else:
		for child in numeric_container.get_children():
			child.queue_free()
		numeric_sliders.clear()
		for key in slot_keys.keys():
			_add_numeric_row(String(key), slot_keys[key])

func _add_numeric_row(key: String, config: Dictionary) -> void:
	var widgets := UiRows.add_labeled_slider(numeric_container, UiText.parameter(key), {
		"label_width": 112,
		"min": float(config.get("min", 0.0)),
		"max": float(config.get("max", 1.0)),
		"step": float(config.get("step", 0.005)),
		"value": _numeric_value(key, config),
	})
	var slider := widgets["slider"] as HSlider
	var value_label := widgets["value_label"] as Label
	numeric_sliders[key] = {"slider": slider, "label": value_label}
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%.2f" % value
		if not _updating:
			set_numeric_parameter(key, value)
	)

func _numeric_value(key: String, config: Dictionary) -> float:
	if parameters.has(key):
		return float(parameters[key])
	var fallback_key := String(config.get("fallback_key", ""))
	if fallback_key != "" and parameters.has(fallback_key):
		return float(parameters[fallback_key])
	return float(config.get("fallback", 0.0))

func _numeric_config_for_key(key: String) -> Dictionary:
	var slot_keys: Dictionary = NUMERIC_KEYS.get(selected_slot, {})
	if slot_keys.has(key):
		return slot_keys[key]
	if key.contains("_bezier_"):
		if key.ends_with("p1_x"):
			return {"min": -1.0, "max": 1.0, "step": 0.01, "fallback": -0.25}
		elif key.ends_with("p2_x"):
			return {"min": -1.0, "max": 1.0, "step": 0.01, "fallback": 0.25}
		elif key.ends_with("p1_y") or key.ends_with("p2_y"):
			return {"min": 0.0, "max": 2.0, "step": 0.01, "fallback": 1.0}
	return {}

func _enabled_key(slot_id: String) -> String:
	match slot_id:
		"dorsal_2":
			return "dorsal_2_enabled"
		"pelvic":
			return "pelvic_enabled"
	return "%s_enabled" % slot_id

func _attach_key(slot_id: String) -> String:
	match slot_id:
		"dorsal_1":
			return "dorsal_1_attach_t"
		"dorsal_2":
			return "dorsal_2_attach_t"
		"pectoral":
			return "pectoral_attach_t"
		"pelvic":
			return "pelvic_attach_t"
		"anal":
			return "anal_attach_t"
	return ""

func _shape_key(slot_id: String) -> String:
	match slot_id:
		"dorsal_1":
			return "dorsal_1_shape"
		"dorsal_2":
			return "dorsal_2_shape"
		"pectoral":
			return "pectoral_shape"
		"pelvic":
			return "pelvic_shape"
		"anal":
			return "anal_shape"
		"caudal":
			return "caudal_shape"
	return "%s_shape" % slot_id

func _default_enabled(slot_id: String) -> float:
	if slot_id == "dorsal_2" or slot_id == "pelvic":
		return 0.0
	return 1.0

func _default_attach(slot_id: String) -> float:
	match slot_id:
		"dorsal_1":
			return 0.45
		"dorsal_2":
			return 0.68
		"pectoral":
			return 0.32
		"pelvic":
			return 0.36
		"anal":
			return 0.64
	return 0.5
