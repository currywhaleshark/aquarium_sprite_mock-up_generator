class_name ParameterPanel
extends ScrollContainer

signal parameters_changed(parameters: Dictionary)

const UiText := preload("res://scripts/ui/UiText.gd")

var parameters: Dictionary = {}
var container: VBoxContainer
var section_bodies: Dictionary = {}
var collapsed_sections: Dictionary = {}

const HIDDEN_BODY_PROFILE_KEYS := {
	"body_profile": true,
	"selected_body_ring_id": true,
	"body_profile_shape": true,
	"head_depth_scale": true,
	"shoulder_depth_scale": true,
	"midbody_depth_scale": true,
	"tail_base_depth_scale": true,
	"caudal_peduncle_depth_scale": true,
	"body_width_scale": true,
	"lateral_compression": true,
	"body_depth_bias": true,
	"head_vertical_offset": true,
	"tail_vertical_offset": true
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
	"dorsal_fin_size": true,
	"anal_fin_size": true,
	"pectoral_fin_size": true,
	"dorsal_fin_offset_x": true,
	"anal_fin_offset_x": true,
	"pectoral_fin_offset_x": true,
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
	"tail_fin_sway_amount": true
}

func _ready() -> void:
	container = VBoxContainer.new()
	container.name = "ParameterRows"
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(container)

func set_parameters(new_parameters: Dictionary) -> void:
	parameters = new_parameters.duplicate(true)
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	section_bodies.clear()
	for key in parameters.keys():
		if _should_hide_key(String(key)):
			continue
		var value: Variant = parameters[key]
		var section_body := _ensure_section(_category_for_key(String(key)))
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			_add_number_row(section_body, String(key), float(value))
		elif typeof(value) == TYPE_STRING and String(value).begins_with("#"):
			_add_color_row(section_body, String(key), Color.html(String(value)))

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
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 28)
	var label := Label.new()
	label.text = UiText.parameter(key)
	label.custom_minimum_size = Vector2(150, 0)
	label.clip_text = true
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = _min_for_key(key, value)
	slider.max_value = _max_for_key(key, value)
	slider.step = 0.005 if slider.max_value <= 3.0 else 0.1
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.text = "%.2f" % value
	value_label.custom_minimum_size = Vector2(46, 0)
	row.add_child(value_label)
	slider.value_changed.connect(func(new_value: float) -> void:
		parameters[key] = new_value
		value_label.text = "%.2f" % new_value
		parameters_changed.emit(parameters.duplicate(true))
	)
	parent.add_child(row)

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
	picker.color_changed.connect(func(new_color: Color) -> void:
		parameters[key] = new_color.to_html(false)
		parameters_changed.emit(parameters.duplicate(true))
	)
	parent.add_child(row)

func _min_for_key(key: String, value: float) -> float:
	if _is_signed_parameter(key):
		return minf(-2.0, value * 2.0)
	return 0.0

func _max_for_key(key: String, value: float) -> float:
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
	if key.begins_with("head") or key.begins_with("mouth") or key.contains("snout") or key.contains("forehead") or key.contains("jaw"):
		return "Head"
	if key.contains("fin") or key.contains("dorsal") or key.contains("pectoral") or key.contains("pelvic") or key.contains("anal") or key.contains("caudal"):
		return "Fins"
	if key.contains("speed") or key.contains("sway") or key.contains("flap") or key.contains("phase") or key.contains("bob") or key.contains("follow") or key.contains("glide"):
		return "Motion Settings"
	if key.contains("color") or key.contains("outline") or key.contains("highlight") or key.contains("shadow") or key.contains("toon") or key.contains("rim") or key.contains("opacity"):
		return "Visual Settings"
	if key.contains("camera") or key.contains("orthographic") or key.contains("resolution") or key.contains("frame") or key.contains("padding") or key.contains("target_display"):
		return "Export"
	if key.contains("disc") or key.contains("wing") or key.contains("tail") or key.contains("eye") or key.contains("body") or key.contains("shell") or key.contains("visual") or key.contains("length") or key.contains("height") or key.contains("width") or key.contains("size") or key.contains("thickness"):
		return "Global Settings"
	return "Other"

func _should_hide_key(key: String) -> bool:
	return HIDDEN_BODY_PROFILE_KEYS.has(key) or SPECIALIZED_EDITOR_KEYS.has(key)
