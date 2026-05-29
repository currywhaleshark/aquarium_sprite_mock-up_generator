class_name BodyEditorPanel
extends VBoxContainer

signal parameters_changed(parameters: Dictionary)

const BODY_PROFILE_SHAPES := ["fusiform", "deep_compressed", "elongated", "eel_like", "depressed", "broad_head", "narrow_peduncle", "custom"]
const PROFILE_DEFAULTS := {
	"fusiform": {
		"head_depth_scale": 0.9,
		"shoulder_depth_scale": 1.0,
		"midbody_depth_scale": 1.0,
		"tail_base_depth_scale": 0.8,
		"caudal_peduncle_depth_scale": 0.65,
		"body_width_scale": 1.0,
		"lateral_compression": 0.1,
		"body_depth_bias": 0.0
	},
	"deep_compressed": {
		"head_depth_scale": 0.78,
		"shoulder_depth_scale": 1.36,
		"midbody_depth_scale": 1.55,
		"tail_base_depth_scale": 0.82,
		"caudal_peduncle_depth_scale": 0.42,
		"body_width_scale": 0.82,
		"lateral_compression": 0.48,
		"body_depth_bias": -0.35
	},
	"elongated": {
		"head_depth_scale": 0.74,
		"shoulder_depth_scale": 0.82,
		"midbody_depth_scale": 0.82,
		"tail_base_depth_scale": 0.64,
		"caudal_peduncle_depth_scale": 0.5,
		"body_width_scale": 0.9,
		"lateral_compression": 0.16,
		"body_depth_bias": 0.0
	},
	"eel_like": {
		"head_depth_scale": 0.56,
		"shoulder_depth_scale": 0.58,
		"midbody_depth_scale": 0.6,
		"tail_base_depth_scale": 0.5,
		"caudal_peduncle_depth_scale": 0.42,
		"body_width_scale": 0.75,
		"lateral_compression": 0.08,
		"body_depth_bias": 0.0
	},
	"depressed": {
		"head_depth_scale": 0.5,
		"shoulder_depth_scale": 0.56,
		"midbody_depth_scale": 0.58,
		"tail_base_depth_scale": 0.48,
		"caudal_peduncle_depth_scale": 0.36,
		"body_width_scale": 1.35,
		"lateral_compression": 0.0,
		"body_depth_bias": -0.2
	},
	"broad_head": {
		"head_depth_scale": 1.35,
		"shoulder_depth_scale": 1.18,
		"midbody_depth_scale": 0.88,
		"tail_base_depth_scale": 0.72,
		"caudal_peduncle_depth_scale": 0.5,
		"body_width_scale": 1.28,
		"lateral_compression": 0.08,
		"body_depth_bias": -0.15
	},
	"narrow_peduncle": {
		"head_depth_scale": 0.9,
		"shoulder_depth_scale": 1.0,
		"midbody_depth_scale": 1.0,
		"tail_base_depth_scale": 0.58,
		"caudal_peduncle_depth_scale": 0.28,
		"body_width_scale": 0.95,
		"lateral_compression": 0.18,
		"body_depth_bias": 0.0
	}
}
const NUMERIC_KEYS := {
	"head_depth_scale": {"min": 0.35, "max": 1.8, "step": 0.005},
	"shoulder_depth_scale": {"min": 0.35, "max": 1.9, "step": 0.005},
	"midbody_depth_scale": {"min": 0.35, "max": 2.0, "step": 0.005},
	"tail_base_depth_scale": {"min": 0.2, "max": 1.5, "step": 0.005},
	"caudal_peduncle_depth_scale": {"min": 0.12, "max": 1.2, "step": 0.005},
	"body_width_scale": {"min": 0.4, "max": 1.8, "step": 0.005},
	"lateral_compression": {"min": 0.0, "max": 0.8, "step": 0.005},
	"body_depth_bias": {"min": -1.0, "max": 1.0, "step": 0.005},
	"head_vertical_offset": {"min": -0.45, "max": 0.45, "step": 0.005},
	"tail_vertical_offset": {"min": -0.45, "max": 0.45, "step": 0.005}
}

var parameters: Dictionary = {}
var profile_option: OptionButton
var numeric_sliders := {}
var _updating := false

func _ready() -> void:
	var title := Label.new()
	title.text = "Body Editor"
	title.add_theme_font_size_override("font_size", 15)
	add_child(title)

	profile_option = _add_option_row("Profile", BODY_PROFILE_SHAPES)
	profile_option.item_selected.connect(func(index: int) -> void:
		if not _updating:
			set_body_profile_shape(profile_option.get_item_text(index))
	)

	for key in NUMERIC_KEYS.keys():
		_add_numeric_row(key)
	_refresh_controls()

func set_parameters(new_parameters: Dictionary) -> void:
	parameters = new_parameters.duplicate(true)
	_refresh_controls()

func set_body_profile_shape(shape: String) -> void:
	parameters["body_profile_shape"] = shape
	if PROFILE_DEFAULTS.has(shape):
		var defaults: Dictionary = PROFILE_DEFAULTS[shape]
		for key in defaults.keys():
			parameters[key] = defaults[key]
	_emit_and_refresh()

func set_numeric_parameter(key: String, value: float) -> void:
	if not NUMERIC_KEYS.has(key):
		return
	var config: Dictionary = NUMERIC_KEYS[key]
	parameters[key] = clampf(value, float(config["min"]), float(config["max"]))
	parameters["body_profile_shape"] = "custom"
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
		option.add_item(String(value))
	row.add_child(option)
	add_child(row)
	return option

func _add_numeric_row(key: String) -> void:
	var config: Dictionary = NUMERIC_KEYS[key]
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = key
	label.custom_minimum_size = Vector2(164, 0)
	label.clip_text = true
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = float(config["min"])
	slider.max_value = float(config["max"])
	slider.step = float(config["step"])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(44, 0)
	row.add_child(value_label)
	numeric_sliders[key] = {"slider": slider, "label": value_label}
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%.2f" % value
		if not _updating:
			set_numeric_parameter(key, value)
	)
	add_child(row)

func _refresh_controls() -> void:
	if profile_option == null:
		return
	_updating = true
	_select_option(profile_option, String(parameters.get("body_profile_shape", "fusiform")))
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
		if option.get_item_text(i) == value:
			option.select(i)
			return
	option.select(0)

func _default_numeric(key: String) -> float:
	var defaults: Dictionary = PROFILE_DEFAULTS["fusiform"]
	return float(defaults.get(key, 1.0))

func _emit_and_refresh() -> void:
	parameters_changed.emit(parameters.duplicate(true))
	_refresh_controls()
