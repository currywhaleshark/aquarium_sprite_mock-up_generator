class_name HeadEditorPanel
extends VBoxContainer

signal parameters_changed(parameters: Dictionary)

const UiText := preload("res://scripts/ui/UiText.gd")
const UiRows := preload("res://scripts/ui/UiRows.gd")

const HEAD_SHAPES := ["rounded", "tapered", "pointed", "blunt", "broad", "flattened", "hump", "steep_forehead", "cephalofoil"]
const MOUTH_TYPES := ["terminal", "superior", "inferior", "subterminal", "protrusible"]
const HEAD_ORNAMENTS := ["none", "wen", "nuchal_hump", "cheek_pad", "forehead_bump"]
const GILL_MARKS := ["none", "line", "crescent", "plate"]
const BARBEL_STYLES := ["none", "cory", "loach", "koi"]
const EYE_STYLES := ["bead", "large", "telescope", "celestial", "tiny_puffer"]
const MOUTH_DETAILS := ["dot", "lip", "beak", "sucker", "downturned"]
const NUMERIC_KEYS := {
	"head_size": {"min": 0.12, "max": 1.2, "step": 0.005},
	"head_offset": {"min": -1.5, "max": 0.4, "step": 0.005},
	"snout_length": {"min": 0.0, "max": 0.6, "step": 0.005},
	"snout_base": {"min": 0.12, "max": 0.5, "step": 0.005},
	"snout_thickness": {"min": 0.15, "max": 1.0, "step": 0.01},
	"snout_taper": {"min": 0.0, "max": 1.0, "step": 0.01},
	"snout_curve": {"min": -1.0, "max": 1.0, "step": 0.01},
	"head_top_curve": {"min": -1.0, "max": 1.0, "step": 0.01},
	"head_top_peak": {"min": -0.5, "max": 1.0, "step": 0.01},
	"head_belly_curve": {"min": -1.0, "max": 1.0, "step": 0.01},
	"head_bump_height": {"min": 0.0, "max": 0.8, "step": 0.005},
	"head_bump_pos": {"min": -0.5, "max": 0.5, "step": 0.01},
	"head_bump_width": {"min": 0.06, "max": 0.5, "step": 0.01},
	"head_bump_angle": {"min": -45.0, "max": 120.0, "step": 1.0},
	"head_bump_round": {"min": 0.0, "max": 1.0, "step": 0.01},
	"forehead_slope": {"min": 0.0, "max": 1.0, "step": 0.005},
	"jaw_offset": {"min": -0.3, "max": 0.3, "step": 0.005},
	"mouth_size": {"min": 0.02, "max": 0.24, "step": 0.005},
	"mouth_open": {"min": 0.0, "max": 1.0, "step": 0.01},
	"jaw_hinge_x": {"min": -0.3, "max": 0.4, "step": 0.01},
	"jaw_hinge_y": {"min": -0.15, "max": 0.15, "step": 0.01},
	"jaw_protrusion": {"min": 0.0, "max": 0.3, "step": 0.01},
	"lower_upper_ratio": {"min": 0.6, "max": 1.5, "step": 0.01},
	"head_flattening": {"min": 0.0, "max": 0.65, "step": 0.005},
	"snout_appendage_length": {"min": 0.05, "max": 0.8, "step": 0.005},
	"eye_size": {"min": 0.01, "max": 0.16, "step": 0.005},
	"eye_position_x": {"min": -1.5, "max": 0.2, "step": 0.005},
	"eye_position_y": {"min": -0.5, "max": 0.6, "step": 0.005},
	"eye_bulge": {"min": 0.0, "max": 1.0, "step": 0.01}
}

const RAY_HEAD_KEYS := {
	"eye_size": {"min": 0.01, "max": 0.12, "step": 0.005},
	"eye_spacing": {"min": 0.1, "max": 0.8, "step": 0.005},
	"snout_length": {"min": 0.0, "max": 0.6, "step": 0.005}
}

var parameters: Dictionary = {}
var options_container: VBoxContainer
var slider_container: VBoxContainer
var current_editor_mode := ""

var head_option: OptionButton
var mouth_option: OptionButton
var snout_appendage_option: OptionButton
var head_ornament_option: OptionButton
var gill_mark_option: OptionButton
var barbel_style_option: OptionButton
var eye_style_option: OptionButton
var mouth_detail_option: OptionButton
var ray_head_shape_option: OptionButton

var numeric_sliders := {}
var current_numeric_keys: Array[String] = []
var _updating := false

# Collapsible groupings for the (many) fish head sliders. Keys not listed in any
# section fall through to a trailing "기타" group so nothing is ever dropped.
const FISH_SECTIONS := [
	{"title": "머리 본체", "keys": ["head_size", "head_offset", "head_flattening"]},
	{"title": "주둥이", "keys": ["snout_length", "snout_base", "snout_thickness", "snout_taper", "snout_curve", "snout_appendage_length"]},
	{"title": "등선·배선", "keys": ["head_top_curve", "head_top_peak", "head_belly_curve", "forehead_slope"]},
	{"title": "혹", "keys": ["head_bump_height", "head_bump_pos", "head_bump_width", "head_bump_angle", "head_bump_round"]},
	{"title": "입", "keys": ["jaw_offset", "mouth_size", "mouth_open", "jaw_hinge_x", "jaw_hinge_y", "jaw_protrusion", "lower_upper_ratio"]},
	{"title": "눈", "keys": ["eye_size", "eye_position_x", "eye_position_y", "eye_bulge"]},
]
const RAY_SECTIONS := [
	{"title": "머리", "keys": ["snout_length", "eye_size", "eye_spacing"]},
]

var section_bodies := {}
var section_expanded := {}

func _ready() -> void:
	var title := Label.new()
	title.text = "머리 편집"
	title.add_theme_font_size_override("font_size", 15)
	add_child(title)

	options_container = VBoxContainer.new()
	add_child(options_container)

	slider_container = VBoxContainer.new()
	add_child(slider_container)

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

func set_option_parameter(key: String, value: String) -> void:
	parameters[key] = value
	_emit_and_refresh()

func set_numeric_parameter(key: String, value: float) -> void:
	var is_ray := String(parameters.get("creature_type", "fish")) == "ray"
	var keys: Dictionary = RAY_HEAD_KEYS if is_ray else NUMERIC_KEYS
	if not keys.has(key):
		return
	var config: Dictionary = keys[key]
	parameters[key] = clampf(value, float(config.get("min", 0.0)), float(config.get("max", 1.0)))
	_emit_and_refresh()

func _rebuild_controls_for_mode(is_ray: bool) -> void:
	for child in options_container.get_children():
		child.queue_free()
	for child in slider_container.get_children():
		child.queue_free()
	numeric_sliders.clear()
	current_numeric_keys.clear()

	if is_ray:
		ray_head_shape_option = _add_option_row(options_container, UiText.parameter("ray_head_shape"), ["manta", "eagle", "cownose"])
		ray_head_shape_option.item_selected.connect(func(index: int) -> void:
			if not _updating:
				set_option_parameter("ray_head_shape", String(ray_head_shape_option.get_item_metadata(index)))
		)
	else:
		head_option = _add_option_row(options_container, "형태", HEAD_SHAPES)
		head_option.item_selected.connect(func(index: int) -> void:
			if not _updating:
				set_head_shape(String(head_option.get_item_metadata(index)))
		)

		mouth_option = _add_option_row(options_container, "입", MOUTH_TYPES)
		mouth_option.item_selected.connect(func(index: int) -> void:
			if not _updating:
				set_mouth_type(String(mouth_option.get_item_metadata(index)))
		)

		head_ornament_option = _add_option_row(options_container, UiText.parameter("head_ornament"), HEAD_ORNAMENTS)
		head_ornament_option.item_selected.connect(func(index: int) -> void:
			if not _updating:
				set_option_parameter("head_ornament", String(head_ornament_option.get_item_metadata(index)))
		)

		gill_mark_option = _add_option_row(options_container, UiText.parameter("gill_mark"), GILL_MARKS)
		gill_mark_option.item_selected.connect(func(index: int) -> void:
			if not _updating:
				set_option_parameter("gill_mark", String(gill_mark_option.get_item_metadata(index)))
		)

		barbel_style_option = _add_option_row(options_container, UiText.parameter("barbel_style"), BARBEL_STYLES)
		barbel_style_option.item_selected.connect(func(index: int) -> void:
			if not _updating:
				set_option_parameter("barbel_style", String(barbel_style_option.get_item_metadata(index)))
		)

		eye_style_option = _add_option_row(options_container, UiText.parameter("eye_style"), EYE_STYLES)
		eye_style_option.item_selected.connect(func(index: int) -> void:
			if not _updating:
				set_option_parameter("eye_style", String(eye_style_option.get_item_metadata(index)))
		)

		mouth_detail_option = _add_option_row(options_container, UiText.parameter("mouth_detail"), MOUTH_DETAILS)
		mouth_detail_option.item_selected.connect(func(index: int) -> void:
			if not _updating:
				set_option_parameter("mouth_detail", String(mouth_detail_option.get_item_metadata(index)))
		)

		snout_appendage_option = _add_option_row(options_container, UiText.parameter("snout_appendage"), ["none", "swordfish_bill", "sawfish_saw", "barbels"])
		snout_appendage_option.item_selected.connect(func(index: int) -> void:
			if not _updating:
				set_snout_appendage(String(snout_appendage_option.get_item_metadata(index)))
		)

func _add_option_row(parent: VBoxContainer, label_text: String, values: Array) -> OptionButton:
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
	parent.add_child(row)
	return option

func _add_numeric_row(parent: VBoxContainer, key: String, config: Dictionary) -> void:
	var widgets := UiRows.add_labeled_slider(parent, UiText.parameter(key), {
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
	if options_container == null:
		return
	_updating = true
	var is_ray := String(parameters.get("creature_type", "fish")) == "ray"
	var mode := "ray" if is_ray else "fish"
	if mode != current_editor_mode:
		current_editor_mode = mode
		_rebuild_controls_for_mode(is_ray)

	if is_ray:
		_select_option(ray_head_shape_option, String(parameters.get("ray_head_shape", "manta")))
	else:
		_select_option(head_option, String(parameters.get("head_shape", "rounded")))
		_select_option(mouth_option, String(parameters.get("mouth_type", "terminal")))
		_select_option(head_ornament_option, String(parameters.get("head_ornament", "none")))
		_select_option(gill_mark_option, String(parameters.get("gill_mark", "none")))
		_select_option(barbel_style_option, String(parameters.get("barbel_style", "none")))
		_select_option(eye_style_option, String(parameters.get("eye_style", "bead")))
		_select_option(mouth_detail_option, String(parameters.get("mouth_detail", "dot")))
		_select_option(snout_appendage_option, String(parameters.get("snout_appendage", "none")))
	_sync_numeric_controls(is_ray)
	for key in numeric_sliders.keys():
		var widgets: Dictionary = numeric_sliders[key]
		var slider := widgets["slider"] as HSlider
		var label := widgets["label"] as Label
		var value := float(parameters.get(key, _default_numeric(key)))
		slider.value = value
		label.text = "%.2f" % value
	_updating = false

func _sync_numeric_controls(is_ray: bool) -> void:
	var visible_keys := _visible_numeric_keys(is_ray)
	if _same_key_list(current_numeric_keys, visible_keys):
		return
	for child in slider_container.get_children():
		child.queue_free()
	numeric_sliders.clear()
	section_bodies.clear()
	current_numeric_keys = visible_keys.duplicate()
	var source: Dictionary = RAY_HEAD_KEYS if is_ray else NUMERIC_KEYS
	var sections: Array = RAY_SECTIONS if is_ray else FISH_SECTIONS
	var visible_set := {}
	for key in visible_keys:
		visible_set[key] = true

	var placed := {}
	for section in sections:
		var keys_in: Array[String] = []
		for key in section["keys"]:
			if visible_set.has(key):
				keys_in.append(String(key))
				placed[key] = true
		if not keys_in.is_empty():
			_add_section(String(section["title"]), keys_in, source)

	# Safety net: any visible key not assigned to a section still gets shown.
	var leftover: Array[String] = []
	for key in visible_keys:
		if not placed.has(key):
			leftover.append(key)
	if not leftover.is_empty():
		_add_section("기타", leftover, source)

func _add_section(title: String, keys: Array[String], source: Dictionary) -> void:
	var header := Button.new()
	header.toggle_mode = true
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_theme_font_size_override("font_size", 13)
	header.button_pressed = bool(section_expanded.get(title, true))
	slider_container.add_child(header)

	var body := VBoxContainer.new()
	slider_container.add_child(body)
	for key in keys:
		_add_numeric_row(body, key, source[key])
	section_bodies[title] = body

	var apply := func(expanded: bool) -> void:
		section_expanded[title] = expanded
		body.visible = expanded
		header.text = ("▾ " if expanded else "▸ ") + title
	apply.call(header.button_pressed)
	header.toggled.connect(func(pressed: bool) -> void: apply.call(pressed))

func _visible_numeric_keys(is_ray: bool) -> Array[String]:
	var result: Array[String] = []
	var source: Dictionary = RAY_HEAD_KEYS if is_ray else NUMERIC_KEYS
	for key in source.keys():
		var key_text := String(key)
		if not is_ray and not _should_show_fish_numeric_key(key_text):
			continue
		result.append(key_text)
	return result

func _should_show_fish_numeric_key(key: String) -> bool:
	if key == "forehead_slope":
		var shape := String(parameters.get("head_shape", "rounded"))
		return shape == "hump" or shape == "steep_forehead"
	if key == "snout_appendage_length":
		var appendage := String(parameters.get("snout_appendage", "none"))
		return appendage != "" and appendage != "none"
	if key == "snout_base" or key == "snout_thickness" or key == "snout_taper" or key == "snout_curve":
		return float(parameters.get("snout_length", 0.0)) > 0.001
	if key == "head_top_peak":
		return absf(float(parameters.get("head_top_curve", 0.0))) > 0.001
	if key == "head_bump_pos" or key == "head_bump_width" or key == "head_bump_angle" or key == "head_bump_round":
		return float(parameters.get("head_bump_height", 0.0)) > 0.001
	return true

func _same_key_list(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	for i in left.size():
		if left[i] != right[i]:
			return false
	return true

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
		"mouth_open":
			return 0.25
		"eye_size":
			return 0.055
		"eye_position_x":
			return -0.78
		"eye_position_y":
			return 0.12
		"snout_appendage_length":
			return 0.4
		"eye_spacing":
			return 0.34
		"snout_length":
			return 0.3
		"snout_base":
			return 0.5
		"snout_thickness":
			return 1.0
		"snout_taper":
			return 0.0
		"head_top_peak":
			return 0.35
		"head_bump_pos":
			return -0.2
		"head_bump_width":
			return 0.18
		"head_bump_angle":
			return 35.0
		"head_bump_round":
			return 0.6
		"lower_upper_ratio":
			return 1.0
	return 0.0

func _emit_and_refresh() -> void:
	parameters_changed.emit(parameters.duplicate(true))
	_refresh_controls()
