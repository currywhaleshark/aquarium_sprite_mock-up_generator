class_name HeadEditorPanel
extends VBoxContainer

signal parameters_changed(parameters: Dictionary)

const UiText := preload("res://scripts/ui/UiText.gd")
const UiRows := preload("res://scripts/ui/UiRows.gd")

const HEAD_SHAPES := ["rounded", "tapered", "pointed", "blunt", "broad", "flattened", "hump", "steep_forehead", "cephalofoil"]
const MOUTH_TYPES := ["terminal", "superior", "inferior", "subterminal", "protrusible"]
const NUMERIC_KEYS := {
	"head_size": {"min": 0.12, "max": 1.2, "step": 0.005},
	"head_offset": {"min": -1.5, "max": 0.4, "step": 0.005},
	"snout_length": {"min": 0.0, "max": 0.6, "step": 0.005},
	"forehead_slope": {"min": 0.0, "max": 1.0, "step": 0.005},
	"jaw_offset": {"min": -0.3, "max": 0.3, "step": 0.005},
	"mouth_size": {"min": 0.02, "max": 0.24, "step": 0.005},
	"head_flattening": {"min": 0.0, "max": 0.65, "step": 0.005},
	"snout_appendage_length": {"min": 0.05, "max": 0.8, "step": 0.005},
	"eye_size": {"min": 0.01, "max": 0.16, "step": 0.005},
	"eye_position_x": {"min": -1.5, "max": 0.2, "step": 0.005},
	"eye_position_y": {"min": -0.5, "max": 0.6, "step": 0.005},
	"eye_bulge": {"min": 0.0, "max": 1.0, "step": 0.01}
}

var parameters: Dictionary = {}
var head_option: OptionButton
var mouth_option: OptionButton
var snout_appendage_option: OptionButton
var numeric_sliders := {}
var _updating := false

func _ready() -> void:
	var title := Label.new()
	title.text = "머리 편집"
	title.add_theme_font_size_override("font_size", 15)
	add_child(title)

	head_option = _add_option_row("형태", HEAD_SHAPES)
	head_option.item_selected.connect(func(index: int) -> void:
		if not _updating:
			set_head_shape(String(head_option.get_item_metadata(index)))
	)

	mouth_option = _add_option_row("입", MOUTH_TYPES)
	mouth_option.item_selected.connect(func(index: int) -> void:
		if not _updating:
			set_mouth_type(String(mouth_option.get_item_metadata(index)))
	)

	snout_appendage_option = _add_option_row(UiText.parameter("snout_appendage"), ["none", "swordfish_bill", "sawfish_saw", "barbels"])
	snout_appendage_option.item_selected.connect(func(index: int) -> void:
		if not _updating:
			set_snout_appendage(String(snout_appendage_option.get_item_metadata(index)))
	)

	for key in NUMERIC_KEYS.keys():
		_add_numeric_row(key)
	_refresh_controls()

func set_parameters(new_parameters: Dictionary) -> void:
	parameters = new_parameters.duplicate(true)
	_refresh_controls()

func set_head_shape(shape: String) -> void:
	parameters["head_shape"] = shape
	_emit_and_refresh()

func set_mouth_type(mouth_type: String) -> void:
	parameters["mouth_type"] = mouth_type
	_emit_and_refresh()

func set_snout_appendage(type: String) -> void:
	parameters["snout_appendage"] = type
	_emit_and_refresh()

func set_numeric_parameter(key: String, value: float) -> void:
	if not NUMERIC_KEYS.has(key):
		return
	var config: Dictionary = NUMERIC_KEYS[key]
	parameters[key] = clampf(value, float(config.get("min", 0.0)), float(config.get("max", 1.0)))
	_emit_and_refresh()

func _add_option_row(label_text: String, values: Array) -> OptionButton:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(96, 0)
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for value in values:
		option.add_item(UiText.option(String(value)))
		option.set_item_metadata(option.item_count - 1, String(value))
	row.add_child(option)
	add_child(row)
	return option

func _add_numeric_row(key: String) -> void:
	var config: Dictionary = NUMERIC_KEYS[key]
	var widgets := UiRows.add_labeled_slider(self, UiText.parameter(key), {
		"row_height": 0.0,
		"label_width": 112,
		"min": float(config["min"]),
		"max": float(config["max"]),
		"step": float(config["step"]),
	})
	var slider := widgets["slider"] as HSlider
	var value_label := widgets["value_label"] as Label
	numeric_sliders[key] = {"slider": slider, "label": value_label}
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%.2f" % value
		if not _updating:
			set_numeric_parameter(key, value)
	)

func _refresh_controls() -> void:
	if head_option == null:
		return
	_updating = true
	_select_option(head_option, String(parameters.get("head_shape", "rounded")))
	_select_option(mouth_option, String(parameters.get("mouth_type", "terminal")))
	_select_option(snout_appendage_option, String(parameters.get("snout_appendage", "none")))
	for key in numeric_sliders.keys():
		var widgets: Dictionary = numeric_sliders[key]
		var slider := widgets["slider"] as HSlider
		var label := widgets["label"] as Label
		var value := float(parameters.get(key, _default_numeric(key)))
		slider.value = value
		label.text = "%.2f" % value
	_updating = false

func _select_option(option: OptionButton, value: String) -> void:
	for i in option.item_count:
		if String(option.get_item_metadata(i)) == value:
			option.select(i)
			return
	option.select(0)

func _default_numeric(key: String) -> float:
	match key:
		"head_size":
			return 0.44
		"head_offset":
			return -0.58
		"mouth_size":
			return 0.08
		"eye_size":
			return 0.055
		"eye_position_x":
			return -0.78
		"eye_position_y":
			return 0.12
		"snout_appendage_length":
			return 0.4
	return 0.0

func _emit_and_refresh() -> void:
	parameters_changed.emit(parameters.duplicate(true))
	_refresh_controls()
