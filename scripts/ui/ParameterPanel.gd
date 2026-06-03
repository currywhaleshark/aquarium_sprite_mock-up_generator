class_name ParameterPanel
extends ScrollContainer

signal parameters_changed(parameters: Dictionary)

const UiText := preload("res://scripts/ui/UiText.gd")
const UiRows := preload("res://scripts/ui/UiRows.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")

var parameters: Dictionary = {}
var container: VBoxContainer
var section_bodies: Dictionary = {}
var collapsed_sections: Dictionary = {}
var sliders := {}
var color_pickers := {}
var option_buttons := {}
var labels := {}
var _updating_values := false
# Optional category filters so one parameter set can be split across several panels
# (e.g. separate tabs for colour and motion). Empty included_categories = show all.
var included_categories: Array = []
var excluded_categories: Array = []

const HIDDEN_BODY_PROFILE_KEYS := {
	"body_profile": true,
	"selected_body_ring_id": true,
	"body_profile_shape": true,
	"overall_scale": true,
	"body_height_scale": true,
	"facing_direction": true,
	"render_angle": true,
	"show_pivot_guides": true,
	"visual_thickness": true,
	"head_depth_scale": true,
	"shoulder_depth_scale": true,
	"midbody_depth_scale": true,
	"tail_base_depth_scale": true,
	"caudal_peduncle_depth_scale": true,
	"body_width_scale": true,
	"lateral_compression": true,
	"body_depth_bias": true,
	"head_vertical_offset": true,
	"tail_vertical_offset": true,
	"mouth_position": true
}

const SPECIALIZED_EDITOR_KEYS := {
	"head_shape": true,
	"mouth_type": true,
	"head_size": true,
	"head_offset": true,
	"snout_length": true,
	"forehead_slope": true,
	"jaw_offset": true,
	"mouth_size": true,
	"head_flattening": true,
	"eye_size": true,
	"eye_position_x": true,
	"eye_position_y": true,
	"eye_bulge": true,
	"dorsal_fin_size": true,
	"anal_fin_size": true,
	"pectoral_fin_size": true,
	"dorsal_fin_offset_x": true,
	"anal_fin_offset_x": true,
	"pectoral_fin_offset_x": true,
	"pectoral_offset_y": true,
	"pectoral_fin_yaw": true,
	"pectoral_fin_pitch": true,
	"pectoral_fin_roll": true,
	"dorsal_1_attach_t": true,
	"dorsal_1_shape": true,
	"dorsal_1_length": true,
	"dorsal_1_height": true,
	"dorsal_2_enabled": true,
	"dorsal_2_attach_t": true,
	"dorsal_2_shape": true,
	"dorsal_2_length": true,
	"dorsal_2_height": true,
	"pectoral_attach_t": true,
	"pectoral_shape": true,
	"pelvic_enabled": true,
	"pelvic_attach_t": true,
	"pelvic_shape": true,
	"pelvic_length": true,
	"pelvic_height": true,
	"anal_attach_t": true,
	"anal_shape": true,
	"anal_length": true,
	"anal_height": true,
	"caudal_shape": true,
	"tail_length": true,
	"tail_height": true,
	"tail_fin_size": true,
	"caudal_height_scale": true,
	"body_sway_amount": true,
	"tail_1_sway_amount": true,
	"tail_2_sway_amount": true,
	"tail_fin_sway_amount": true,
	"pectoral_flap_amount": true,
	"outline_width": true,
	"toon_steps": true,
	"rim_light_strength": true,
	"cephalic_horns": true,
	"ray_head_shape": true,
	"ray_disc_shape": true,
	"ray_tail_style": true,
	"ray_tail_spine_enabled": true,
	"ray_dorsal_tail_fins": true,
	"eye_spacing": true
}

func _ready() -> void:
	container = VBoxContainer.new()
	container.name = "ParameterRows"
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(container)

func set_parameters(new_parameters: Dictionary) -> void:
	var keys_changed := false
	if new_parameters.size() != parameters.size():
		keys_changed = true
	else:
		for k in new_parameters.keys():
			if not parameters.has(k):
				keys_changed = true
				break
				
	parameters = new_parameters.duplicate(true)
	if container == null:
		return
		
	if keys_changed or container.get_child_count() == 0:
		_build_controls()
	else:
		_update_control_values()

func _build_controls() -> void:
	for child in container.get_children():
		child.queue_free()
	section_bodies.clear()
	sliders.clear()
	color_pickers.clear()
	option_buttons.clear()
	labels.clear()
	
	for key in parameters.keys():
		if _should_hide_key(String(key)):
			continue
		var value: Variant = parameters[key]
		var category := _category_for_key(String(key))
		if not included_categories.is_empty() and not included_categories.has(category):
			continue
		if excluded_categories.has(category):
			continue
		var section_body := _ensure_section(category)
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			_add_number_row(section_body, String(key), float(value))
		elif _is_color_value(value):
			_add_color_row(section_body, String(key), _color_from_value(value))
		elif typeof(value) == TYPE_STRING and _is_option_parameter(String(key)):
			_add_option_row(section_body, String(key), String(value))

func _update_control_values() -> void:
	_updating_values = true
	for key in parameters.keys():
		var value: Variant = parameters[key]
		if sliders.has(key):
			var slider := sliders[key] as HSlider
			slider.value = float(value)
			var label := labels[key] as Label
			if label:
				label.text = "%.2f" % float(value)
		elif color_pickers.has(key):
			var picker := color_pickers[key] as ColorPickerButton
			picker.color = _color_from_value(value)
		elif option_buttons.has(key):
			var option := option_buttons[key] as OptionButton
			var options := _options_for_key(key)
			var selected_index := options.find(String(value))
			option.select(maxi(selected_index, 0))
	_updating_values = false

func get_section_body(section_name: String) -> VBoxContainer:
	return section_bodies.get(section_name, null)

func set_section_collapsed(section_name: String, collapsed: bool) -> void:
	collapsed_sections[section_name] = collapsed
	var body := get_section_body(section_name)
	if body:
		body.visible = not collapsed
	var section := body.get_parent() if body else null
	if section:
		var header := section.get_node_or_null("Header") as Button
		if header:
			header.text = _header_text(section_name, not collapsed)

func _ensure_section(section_name: String) -> VBoxContainer:
	if section_bodies.has(section_name):
		return section_bodies[section_name]
	var section := VBoxContainer.new()
	section.name = section_name.replace(" ", "") + "Section"
	section.add_theme_constant_override("separation", 2)
	var header := Button.new()
	header.name = "Header"
	header.toggle_mode = true
	header.button_pressed = not bool(collapsed_sections.get(section_name, false))
	header.text = _header_text(section_name, header.button_pressed)
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	section.add_child(header)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.visible = header.button_pressed
	body.add_theme_constant_override("separation", 1)
	section.add_child(body)
	header.toggled.connect(func(opened: bool) -> void:
		collapsed_sections[section_name] = not opened
		body.visible = opened
		header.text = _header_text(section_name, opened)
	)
	container.add_child(section)
	section_bodies[section_name] = body
	return body

func _header_text(section_name: String, opened: bool) -> String:
	return ("%s %s" % ["v" if opened else ">", UiText.section(section_name)])

func _add_number_row(parent: VBoxContainer, key: String, value: float) -> void:
	var max_value := _max_for_key(key, value)
	var widgets := UiRows.add_labeled_slider(parent, UiText.parameter(key), {
		"label_width": 150,
		"value_width": 46,
		"min": _min_for_key(key, value),
		"max": max_value,
		"step": 0.005 if max_value <= 3.0 else 0.1,
		"value": value,
	})
	var slider := widgets["slider"] as HSlider
	var value_label := widgets["value_label"] as Label
	sliders[key] = slider
	labels[key] = value_label
	
	slider.value_changed.connect(func(new_value: float) -> void:
		if _updating_values:
			return
		parameters[key] = new_value
		value_label.text = "%.2f" % new_value
		parameters_changed.emit(parameters.duplicate(true))
	)

func _add_color_row(parent: VBoxContainer, key: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)
	var label := Label.new()
	label.text = UiText.parameter(key)
	label.custom_minimum_size = Vector2(150, 0)
	label.clip_text = true
	row.add_child(label)
	var picker := ColorPickerButton.new()
	picker.color = color
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(picker)
	color_pickers[key] = picker
	
	picker.color_changed.connect(func(new_color: Color) -> void:
		if _updating_values:
			return
		parameters[key] = "#%s" % new_color.to_html(false)
		parameters_changed.emit(parameters.duplicate(true))
	)
	parent.add_child(row)

func _add_option_row(parent: VBoxContainer, key: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)
	var label := Label.new()
	label.text = UiText.parameter(key)
	label.custom_minimum_size = Vector2(150, 0)
	label.clip_text = true
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var options := _options_for_key(key)
	for option_value in options:
		option.add_item(UiText.option(option_value))
		option.set_item_metadata(option.item_count - 1, option_value)
	var selected_index := options.find(value)
	option.select(maxi(selected_index, 0))
	row.add_child(option)
	option_buttons[key] = option
	
	option.item_selected.connect(func(index: int) -> void:
		if _updating_values:
			return
		var selected := String(option.get_item_metadata(index))
		parameters[key] = selected
		if key == "swim_mode":
			BodyProfileScript.apply_swim_mode(parameters, selected)
		parameters_changed.emit(parameters.duplicate(true))
	)
	parent.add_child(row)

func _min_for_key(key: String, value: float) -> float:
	if key == "wave_ripples":
		return 0.5
	if key.begins_with("pattern_") or key == "belly_height" or key == "belly_slope":
		return 0.0
	if _is_signed_parameter(key):
		return minf(-2.0, value * 2.0)
	return 0.0

func _max_for_key(key: String, value: float) -> float:
	if key == "disc_thickness":
		return 0.3
	if key == "tail_thickness":
		return 0.2
	if key == "wave_ripples":
		return 3.0
	if key == "pattern_intensity" or key == "belly_height" or key == "belly_slope" or key == "wetness" or key == "shell_roundness":
		return 1.0
	if key == "iridescence_frequency":
		return 10.0
	if key == "pattern_scale_x" or key == "pattern_scale_y":
		return maxf(20.0, value * 2.0)
	if _is_signed_parameter(key):
		return maxf(2.0, absf(value) * 2.0)
	if key.contains("color") or key.contains("strength"):
		return 1.0
	if key.contains("sway") or key.contains("flap") or key.contains("amount") or key.contains("amplitude"):
		return maxf(45.0, value * 2.0)
	if key.contains("speed"):
		return maxf(4.0, value * 2.0)
	if key.contains("size") or key.contains("length") or key.contains("width") or key.contains("height") or key.contains("thickness"):
		return maxf(3.5, value * 2.0)
	return maxf(2.0, value * 2.0)

func _is_signed_parameter(key: String) -> bool:
	return key.contains("offset") or key.contains("position") or key.ends_with("_x") or key.ends_with("_y") or key.ends_with("_z")

func _category_for_key(key: String) -> String:
	if key.begins_with("pattern"):
		return "Pattern Settings"
	if key == "belly_height" or key == "belly_slope" or key == "wetness" or key.begins_with("iridescence"):
		return "Color Settings"
	if key.contains("color"):
		return "Color Settings"
	if key.begins_with("head") or key.begins_with("mouth") or key.contains("snout") or key.contains("forehead") or key.contains("jaw"):
		return "Head"
	if key == "swim_mode" or key == "ray_locomotion_mode" or key == "wave_ripples" or key == "pectoral_flap_sync" or key.begins_with("body_wave_") or key.contains("speed") or key.contains("sway") or key.contains("swing") or key.contains("flap") or key.contains("phase") or key.contains("bob") or key.contains("follow") or key.contains("glide") or key.contains("turn") or key.contains("fold") or key.contains("brace"):
		return "Motion Settings"
	if key.contains("fin") or key.contains("dorsal") or key.contains("pectoral") or key.contains("pelvic") or key.contains("anal") or key.contains("caudal"):
		return "Fins"
	if key.contains("outline") or key.contains("highlight") or key.contains("shadow") or key.contains("toon") or key.contains("rim") or key.contains("opacity"):
		return "Visual Settings"
	if key.contains("camera") or key.contains("orthographic") or key.contains("resolution") or key.contains("frame") or key.contains("padding") or key.contains("target_display"):
		return "Export"
	if key.contains("disc") or key.contains("wing") or key.contains("tail") or key.contains("eye") or key.contains("body") or key.contains("shell") or key.contains("visual") or key.contains("length") or key.contains("height") or key.contains("width") or key.contains("size") or key.contains("thickness"):
		return "Global Settings"
	return "Other"

func _should_hide_key(key: String) -> bool:
	return HIDDEN_BODY_PROFILE_KEYS.has(key) or SPECIALIZED_EDITOR_KEYS.has(key)

func _is_color_value(value: Variant) -> bool:
	if value is Color:
		return true
	return typeof(value) == TYPE_STRING and (String(value).begins_with("#") or _looks_like_hex_color(String(value)))

func _color_from_value(value: Variant) -> Color:
	if value is Color:
		return value
	var text := String(value)
	if not text.begins_with("#"):
		text = "#%s" % text
	return Color.html(text)

func _looks_like_hex_color(text: String) -> bool:
	if text.length() != 6 and text.length() != 8:
		return false
	for i in text.length():
		var code := text.unicode_at(i)
		var is_digit := code >= 48 and code <= 57
		var is_upper_hex := code >= 65 and code <= 70
		var is_lower_hex := code >= 97 and code <= 102
		if not (is_digit or is_upper_hex or is_lower_hex):
			return false
	return true

func _is_option_parameter(key: String) -> bool:
	return key == "swim_mode" or key == "pattern_type" or key == "pectoral_flap_sync" or key == "cephalic_horns" or key == "ray_locomotion_mode" or key == "ray_head_shape" or key == "ray_disc_shape" or key == "ray_tail_style"

func _options_for_key(key: String) -> Array[String]:
	if key == "swim_mode":
		return BodyProfileScript.swim_mode_names()
	if key == "pattern_type":
		return BodyProfileScript.pattern_type_names()
	if key == "pectoral_flap_sync":
		return ["alternating", "synchronous"] as Array[String]
	if key == "cephalic_horns":
		return ["none", "rolled", "unfolded"] as Array[String]
	if key == "ray_locomotion_mode":
		return ["rajiform", "mobuliform", "punting"] as Array[String]
	if key == "ray_head_shape":
		return ["manta", "eagle", "cownose"] as Array[String]
	if key == "ray_disc_shape":
		return ["diamond", "round", "manta", "skate", "electric"] as Array[String]
	if key == "ray_tail_style":
		return ["whip", "manta_thread", "stout_skate", "short_round"] as Array[String]
	return []
