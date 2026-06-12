class_name ParameterPanel
extends ScrollContainer

signal parameters_changed(parameters: Dictionary)

const UiText := preload("res://scripts/ui/UiText.gd")
const UiRows := preload("res://scripts/ui/UiRows.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
const CreatureModeScript := preload("res://scripts/creature/CreatureMode.gd")
const CreatureParameterSchemaScript := preload("res://scripts/creature/CreatureParameterSchema.gd")
const MarkingLayerEditorScript := preload("res://scripts/ui/MarkingLayerEditor.gd")

var parameters: Dictionary = {}
var creature_type := CreatureModeScript.FISH
var container: VBoxContainer
var section_bodies: Dictionary = {}
var collapsed_sections: Dictionary = {}
var sliders := {}
var color_pickers := {}
var option_buttons := {}
var labels := {}
var search_edit: LineEdit
var search_text := ""
var control_rows := {}
var control_name_labels := {}
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
	"mouth_open": true,
	"head_flattening": true,
	"eye_size": true,
	"eye_position_x": true,
	"eye_position_y": true,
	"eye_bulge": true,
	"eye_pupil_scale": true,
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

func set_creature_type(mode: String) -> void:
	var normalized_mode := CreatureModeScript.normalize(mode)
	if creature_type == normalized_mode:
		return
	creature_type = normalized_mode
	if not parameters.is_empty() and container != null:
		_build_controls()

func set_parameters(new_parameters: Dictionary) -> void:
	var keys_changed := false
	if new_parameters.size() != parameters.size():
		keys_changed = true
	else:
		for k in new_parameters.keys():
			if not parameters.has(k):
				keys_changed = true
				break
	var incoming_mode := CreatureModeScript.normalize(String(new_parameters.get("creature_type", creature_type)))
	if incoming_mode != creature_type:
		creature_type = incoming_mode
		keys_changed = true

	parameters = new_parameters.duplicate(true)
	if container == null:
		return
		
	if keys_changed or container.get_child_count() == 0:
		_build_controls()
	else:
		_update_control_values()

func set_search_text(text: String) -> void:
	search_text = text
	if search_edit != null and search_edit.text != search_text:
		search_edit.text = search_text
	_apply_row_filter()

func _build_controls() -> void:
	for child in container.get_children():
		child.queue_free()
	section_bodies.clear()
	sliders.clear()
	color_pickers.clear()
	option_buttons.clear()
	labels.clear()
	control_rows.clear()
	control_name_labels.clear()

	search_edit = UiRows.add_filter_row(container, UiText.slider_search_placeholder())
	search_edit.text = search_text
	search_edit.text_changed.connect(func(text: String) -> void:
		set_search_text(text)
	)
	
	for key in parameters.keys():
		if _should_hide_key(String(key)):
			continue
		var value: Variant = parameters[key]
		var category := _category_for_key(String(key))
		if not included_categories.is_empty() and not included_categories.has(category):
			continue
		if excluded_categories.has(category):
			continue
		if String(key) == "marking_layers" and value is Array:
			var section_body := _ensure_section("Pattern Settings")
			_add_marking_layer_editor(section_body, value)
			continue
		var section_body := _ensure_section(category)
		if typeof(value) == TYPE_BOOL:
			_add_boolean_row(section_body, String(key), bool(value))
		elif typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			if _is_boolean_parameter(String(key)):
				_add_boolean_row(section_body, String(key), float(value) > 0.5)
			else:
				_add_number_row(section_body, String(key), float(value))
		elif _is_color_value(value):
			_add_color_row(section_body, String(key), _color_from_value(value))
		elif typeof(value) == TYPE_STRING and _is_option_parameter(String(key)):
			_add_option_row(section_body, String(key), String(value))
	_apply_row_filter()

func _update_control_values() -> void:
	_updating_values = true
	for key in parameters.keys():
		var value: Variant = parameters[key]
		if sliders.has(key):
			var widget = sliders[key]
			if widget is HSlider:
				var slider := widget as HSlider
				slider.value = float(value)
				var label := labels[key] as Label
				if label:
					label.text = "%.2f" % float(value)
			elif widget is CheckBox:
				var check := widget as CheckBox
				check.button_pressed = bool(value) if typeof(value) == TYPE_BOOL else float(value) > 0.5
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
			header.button_pressed = not collapsed
			header.text = _header_text(section_name, not collapsed)
	_apply_row_filter()

func _ensure_section(section_name: String) -> VBoxContainer:
	if section_bodies.has(section_name):
		return section_bodies[section_name]
	var section := VBoxContainer.new()
	section.name = section_name.replace(" ", "") + "Section"
	section.add_theme_constant_override("separation", 6)
	
	var header := Button.new()
	header.name = "Header"
	header.toggle_mode = true
	# Default to collapsed (true) if not specified
	header.button_pressed = not bool(collapsed_sections.get(section_name, true))
	header.text = _header_text(section_name, header.button_pressed)
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Modern visual style for premium accordion look
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.14, 0.16, 0.19)
	style_normal.border_width_left = 4
	style_normal.border_color = Color(0.27, 0.77, 0.81) # Cyan border accent
	style_normal.content_margin_left = 12
	style_normal.content_margin_top = 8
	style_normal.content_margin_bottom = 8
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_right = 4

	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.2, 0.23, 0.27)

	var style_pressed := style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = Color(0.11, 0.13, 0.15)
	style_pressed.border_color = Color(0.27, 0.77, 0.81)

	header.add_theme_stylebox_override("normal", style_normal)
	header.add_theme_stylebox_override("hover", style_hover)
	header.add_theme_stylebox_override("pressed", style_pressed)
	header.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	header.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	header.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	header.add_theme_color_override("font_pressed_color", Color(0.27, 0.77, 0.81))
	header.add_theme_font_size_override("font_size", 12)
	
	section.add_child(header)
	
	var body := VBoxContainer.new()
	body.name = "Body"
	body.visible = header.button_pressed
	body.add_theme_constant_override("separation", 6)
	
	# Draw premium background container for active settings
	body.draw.connect(func() -> void:
		if not body.visible or body.get_child_count() == 0:
			return
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.09, 0.11, 0.6)
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		body.draw_style_box(style, Rect2(Vector2.ZERO, body.size))
	)
	
	section.add_child(body)
	
	header.toggled.connect(func(opened: bool) -> void:
		collapsed_sections[section_name] = not opened
		body.visible = opened
		header.text = _header_text(section_name, opened)
		_apply_row_filter()
	)
	container.add_child(section)
	section_bodies[section_name] = body
	return body

func _header_text(section_name: String, opened: bool) -> String:
	return ("  %s  %s" % ["▼" if opened else "▶", UiText.section(section_name)])

func _is_boolean_parameter(key: String) -> bool:
	return key.ends_with("_enabled") or key == "ray_dorsal_tail_fins" or key.begins_with("show_")

func _add_boolean_row(parent: VBoxContainer, key: String, checked: bool) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)
	var label := Label.new()
	label.text = UiText.parameter(key)
	label.custom_minimum_size = Vector2(150, 0)
	label.clip_text = true
	row.add_child(label)
	
	var check := CheckBox.new()
	check.button_pressed = checked
	check.text = ""
	row.add_child(check)
	
	sliders[key] = check
	
	check.toggled.connect(func(new_value: bool) -> void:
		if _updating_values:
			return
		parameters[key] = 1.0 if new_value else 0.0
		parameters_changed.emit(parameters.duplicate(true))
	)
	parent.add_child(row)
	control_rows[key] = row
	control_name_labels[key] = label

func _add_number_row(parent: VBoxContainer, key: String, value: float) -> void:
	var max_value := _max_for_key(key, value)
	var widgets := UiRows.add_labeled_slider(parent, UiText.parameter(key), {
		"label_width": 150,
		"value_width": 46,
		"min": _min_for_key(key, value),
		"max": max_value,
		"step": _step_for_key(key, max_value),
		"value": value,
	})
	var slider := widgets["slider"] as HSlider
	var value_label := widgets["value_label"] as Label
	sliders[key] = slider
	labels[key] = value_label
	control_rows[key] = widgets["row"]
	control_name_labels[key] = widgets["name_label"]
	slider.value_changed.connect(func(new_value: float) -> void:
		if _updating_values:
			return
		value_label.text = "%.2f" % new_value
		_apply_number_value(key, new_value, value_label)
	)

func _apply_number_value(key: String, new_value: float, value_label: Label) -> void:
	parameters[key] = new_value
	value_label.text = "%.2f" % new_value
	parameters_changed.emit(parameters.duplicate(true))

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
	control_rows[key] = row
	control_name_labels[key] = label

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
	control_rows[key] = row
	control_name_labels[key] = label

func _apply_row_filter() -> void:
	var search_active := search_text.strip_edges() != ""
	for key in control_rows.keys():
		var row := control_rows[key] as Control
		if row == null:
			continue
		row.visible = _row_matches_search(String(key))
	for section_name in section_bodies.keys():
		var body := section_bodies[section_name] as Control
		if body == null:
			continue
		var section := body.get_parent() as Control
		var any_visible := false
		for key in control_rows.keys():
			var row := control_rows[key] as Control
			if row != null and row.get_parent() == body and row.visible:
				any_visible = true
				break
		if section != null:
			section.visible = (not search_active) or any_visible
		if search_active:
			body.visible = any_visible
		else:
			body.visible = not bool(collapsed_sections.get(String(section_name), true))

func _row_matches_search(key: String) -> bool:
	var query := search_text.strip_edges()
	if query == "":
		return true
	var label := control_name_labels.get(key) as Label
	return label != null and label.text.contains(query)

func _add_marking_layer_editor(parent: VBoxContainer, layers_value: Array) -> void:
	var editor := MarkingLayerEditorScript.new()
	editor.name = "RegionalMarkingLayerEditor"
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.set_layers(layers_value)
	editor.layers_changed.connect(func(new_layers: Array) -> void:
		if _updating_values:
			return
		parameters["marking_layers"] = new_layers.duplicate(true)
		parameters_changed.emit(parameters.duplicate(true))
	)
	parent.add_child(editor)

func _min_for_key(key: String, value: float) -> float:
	if key == "shark_gill_slit_count":
		return 1.0
	if key == "shark_gill_slit_angle":
		return -45.0
	if key == "shark_gill_slit_depth":
		return 0.0
	if key == "scale_size":
		return 4.0
	if key == "wave_ripples":
		return 0.5
	if key == "adipose_fin_position":
		return 0.0
	if key == "fin_ray_root_bias" or key == "finlet_pitch":
		return -1.0
	if key.begins_with("pattern_") or key == "belly_height" or key == "belly_slope":
		return 0.0
	if _is_signed_parameter(key):
		return minf(-2.0, value * 2.0)
	return 0.0

func _max_for_key(key: String, value: float) -> float:
	if key == "shark_gill_slit_count":
		return 7.0
	if key == "shark_gill_slit_angle":
		return 45.0
	if key == "shark_gill_slit_depth":
		return 1.0
	if key == "scale_size":
		return 64.0
	if key == "disc_thickness":
		return 0.3
	if key == "tail_thickness":
		return 0.2
	if key == "wave_ripples":
		return 3.0
	if key == "fin_ray_count":
		return 48.0
	if key == "fin_spine_count" or key == "finlet_dorsal_count" or key == "finlet_ventral_count":
		return 12.0
	if key == "fin_ray_root_bias" or key == "finlet_pitch":
		return 1.0
	if key == "adipose_fin_position":
		return 1.0
	if key.begins_with("fin_ray_") or key.begins_with("adipose_fin_") or key.begins_with("finlet_") or key == "fin_spine_strength":
		return 1.0
	if key == "pattern_intensity" or key == "pattern_invert" or key == "pattern_size_lock" or key == "belly_height" or key == "belly_slope" or key == "wetness" or key == "shell_roundness":
		return 1.0
	if key == "pattern_seed":
		return maxf(999.0, value * 2.0)
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

func _step_for_key(key: String, max_value: float) -> float:
	if key == "shark_gill_slit_count":
		return 1.0
	if key == "shark_gill_slit_angle":
		return 1.0
	return 0.005 if max_value <= 3.0 else 0.1

func _is_signed_parameter(key: String) -> bool:
	return key.contains("offset") or key.contains("position") or key.ends_with("_x") or key.ends_with("_y") or key.ends_with("_z")

func _category_for_key(key: String) -> String:
	if key == "marking_layers":
		return "Pattern Settings"
	if key.contains("scale") or key == "lateral_line_strength":
		return "Scale Settings"
	if key.begins_with("pattern"):
		return "Pattern Settings"
	if key == "palette_scheme":
		return "Color Settings"
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
	if HIDDEN_BODY_PROFILE_KEYS.has(key):
		return true
	if not CreatureParameterSchemaScript.is_parameter_visible(creature_type, key):
		return true
	return SPECIALIZED_EDITOR_KEYS.has(key) and not _should_show_specialized_key(key)

func _should_show_specialized_key(key: String) -> bool:
	if creature_type == CreatureModeScript.RAY and key == "ray_disc_shape":
		return true
	if creature_type == CreatureModeScript.SHARK and key == "caudal_shape":
		return true
	return false

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
	return key == "gill_mark" or key == "caudal_shape" or key == "swim_mode" or key == "pattern_type" or key == "palette_scheme" or key == "scale_type" or key == "pectoral_flap_sync" or key == "cephalic_horns" or key == "ray_locomotion_mode" or key == "ray_head_shape" or key == "ray_disc_shape" or key == "ray_tail_style" or key == "fin_ray_style"

func _options_for_key(key: String) -> Array[String]:
	if key == "gill_mark":
		return _filter_options_for_mode(key, ["none", "line", "crescent", "plate", "operculum"] as Array[String])
	if key == "caudal_shape":
		return _filter_options_for_mode(key, [
			"forked_shallow", "forked_deep", "truncate", "rounded", "pointed", "lunate",
			"fan", "double_fan", "halfmoon", "veil", "crowntail", "spade", "lyre",
			"top_sword", "bottom_sword", "double_sword", "butterfly",
			"shark_heterocercal", "thresher", "custom"
		] as Array[String])
	if key == "swim_mode":
		return _filter_options_for_mode(key, BodyProfileScript.swim_mode_names())
	if key == "pattern_type":
		return _filter_options_for_mode(key, BodyProfileScript.pattern_type_names())
	if key == "palette_scheme":
		return _filter_options_for_mode(key, BodyProfileScript.palette_scheme_names())
	if key == "scale_type":
		return _filter_options_for_mode(key, BodyProfileScript.scale_type_names())
	if key == "pectoral_flap_sync":
		return _filter_options_for_mode(key, ["alternating", "synchronous"] as Array[String])
	if key == "cephalic_horns":
		return _filter_options_for_mode(key, ["none", "rolled", "unfolded"] as Array[String])
	if key == "ray_locomotion_mode":
		return _filter_options_for_mode(key, ["rajiform", "mobuliform", "punting"] as Array[String])
	if key == "ray_head_shape":
		return _filter_options_for_mode(key, ["manta", "eagle", "cownose"] as Array[String])
	if key == "ray_disc_shape":
		return _filter_options_for_mode(key, ["diamond", "round", "manta", "skate", "electric"] as Array[String])
	if key == "ray_tail_style":
		return _filter_options_for_mode(key, ["whip", "manta_thread", "stout_skate", "short_round"] as Array[String])
	if key == "fin_ray_style":
		return _filter_options_for_mode(key, BodyProfileScript.fin_ray_style_names())
	return []

func _filter_options_for_mode(key: String, options: Array[String]) -> Array[String]:
	var filtered: Array[String] = []
	for option in options:
		if CreatureParameterSchemaScript.is_option_value_visible(creature_type, key, option):
			filtered.append(option)
	return filtered
