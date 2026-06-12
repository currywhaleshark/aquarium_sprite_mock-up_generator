class_name HeadEditorPanel
extends VBoxContainer

signal parameters_changed(parameters: Dictionary)
# Emitted when the user drags a numeric slider (not on programmatic sync), with the key.
# Lets the preview show context indicators (e.g. the jaw-hinge marker) for the active key.
signal numeric_slider_changed(key: String)
signal numeric_slider_hovered(key: String)
signal vector_edit_target_changed(slot: String)
signal vector_edit_preview_changed(slot: String, active: bool, norm_position: Vector2, ghost: bool)

const UiText := preload("res://scripts/ui/UiText.gd")
const UiRows := preload("res://scripts/ui/UiRows.gd")
const FinVectorEditorScript := preload("res://scripts/ui/FinVectorEditor.gd")
const ThumbnailOptionGridScript := preload("res://scripts/ui/ThumbnailOptionGrid.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
const CreatureModeScript := preload("res://scripts/creature/CreatureMode.gd")

const HEAD_SHAPES := ["rounded", "tapered", "pointed", "blunt", "broad", "flattened", "hump", "steep_forehead", "cephalofoil"]
const MOUTH_TYPES := ["terminal", "superior", "inferior", "subterminal", "protrusible"]
const HEAD_ORNAMENTS := ["none", "wen", "nuchal_hump", "cheek_pad", "forehead_bump"]
const GILL_MARKS := ["none", "line", "crescent", "plate", "operculum"]
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
	"head_top_flatness": {"min": 0.0, "max": 1.0, "step": 0.005},
	"head_bottom_flatness": {"min": 0.0, "max": 1.0, "step": 0.005},
	"head_left_flatness": {"min": 0.0, "max": 1.0, "step": 0.005},
	"head_right_flatness": {"min": 0.0, "max": 1.0, "step": 0.005},
	"forehead_slope": {"min": 0.0, "max": 1.0, "step": 0.005},
	"jaw_offset": {"min": -0.3, "max": 0.3, "step": 0.005},
	"mouth_size": {"min": 0.02, "max": 0.24, "step": 0.005},
	"mouth_open": {"min": 0.0, "max": 1.0, "step": 0.01},
	"lower_jaw_length": {"min": 0.6, "max": 1.6, "step": 0.01},
	"lower_jaw_angle": {"min": -60.0, "max": 60.0, "step": 1.0},
	"lower_jaw_thickness": {"min": 0.5, "max": 1.8, "step": 0.01},
	"lower_jaw_tip": {"min": -1.0, "max": 1.0, "step": 0.01},
	"jaw_hinge_x": {"min": -0.8, "max": 1.0, "step": 0.01},
	"jaw_hinge_y": {"min": -0.4, "max": 0.4, "step": 0.01},
	"jaw_protrusion": {"min": 0.0, "max": 0.3, "step": 0.01},
	"lower_upper_ratio": {"min": 0.6, "max": 1.5, "step": 0.01},
	"operculum_size": {"min": 0.5, "max": 1.5, "step": 0.01},
	"operculum_height": {"min": 0.5, "max": 1.5, "step": 0.01},
	"operculum_open": {"min": 0.0, "max": 1.0, "step": 0.01},
	"operculum_ridge": {"min": 0.0, "max": 1.0, "step": 0.01},
	"operculum_position_x": {"min": -0.12, "max": 0.12, "step": 0.005},
	"operculum_position_y": {"min": -0.35, "max": 0.35, "step": 0.005},
	"head_flattening": {"min": 0.0, "max": 0.65, "step": 0.005},
	"snout_appendage_length": {"min": 0.05, "max": 0.8, "step": 0.005},
	"eye_size": {"min": 0.01, "max": 0.16, "step": 0.005},
	"eye_position_x": {"min": -1.5, "max": 0.2, "step": 0.005},
	"eye_position_y": {"min": -0.5, "max": 0.6, "step": 0.005},
	"eye_bulge": {"min": 0.0, "max": 1.0, "step": 0.01},
	"eye_pupil_scale": {"min": 0.2, "max": 0.95, "step": 0.01}
}

const RAY_HEAD_KEYS := {
	"eye_size": {"min": 0.01, "max": 0.12, "step": 0.005},
	"eye_spacing": {"min": 0.1, "max": 0.8, "step": 0.005},
	"snout_length": {"min": 0.0, "max": 0.6, "step": 0.005}
}

var parameters: Dictionary = {}
var creature_type := CreatureModeScript.FISH
var options_container: VBoxContainer
var slider_container: VBoxContainer
var current_editor_mode := ""

var snout_appendage_option: OptionButton
var head_ornament_option: OptionButton
var gill_mark_option: OptionButton
var barbel_style_option: OptionButton
var mouth_detail_option: OptionButton
var ray_head_shape_option: OptionButton
var head_shape_grid
var mouth_type_grid
var eye_style_grid

var numeric_sliders := {}
var current_numeric_keys: Array[String] = []
var operculum_editor: Control
var search_edit: LineEdit
var search_text := ""
var changed_only_check: CheckBox
var show_changed_only := false
var _updating := false

# Collapsible groupings for the (many) fish head sliders. Keys not listed in any
# section fall through to a trailing "기타" group so nothing is ever dropped.
const FISH_SECTIONS := [
	{"title": "머리 본체", "keys": ["head_size", "head_offset", "head_flattening"]},
	{"title": "평면화", "keys": ["head_top_flatness", "head_bottom_flatness", "head_left_flatness", "head_right_flatness"]},
	{"title": "주둥이", "keys": ["snout_length", "snout_base", "snout_thickness", "snout_taper", "snout_curve", "snout_appendage_length"]},
	{"title": "등선·배선", "keys": ["head_top_curve", "head_top_peak", "head_belly_curve", "forehead_slope"]},
	{"title": "혹", "keys": ["head_bump_height", "head_bump_pos", "head_bump_width", "head_bump_angle", "head_bump_round"]},
	{"title": "입", "keys": ["jaw_offset", "mouth_size", "mouth_open", "lower_jaw_length", "lower_jaw_angle", "lower_jaw_thickness", "lower_jaw_tip", "jaw_hinge_x", "jaw_hinge_y", "jaw_protrusion", "lower_upper_ratio"]},
	{"title": "아가미", "keys": ["operculum_position_x", "operculum_position_y", "operculum_size", "operculum_height", "operculum_open", "operculum_ridge"]},
	{"title": "눈", "keys": ["eye_size", "eye_position_x", "eye_position_y", "eye_bulge", "eye_pupil_scale"]},
]
const RAY_SECTIONS := [
	{"title": "머리", "keys": ["snout_length", "eye_size", "eye_spacing"]},
]

var section_bodies := {}
var section_headers := {}
var section_expanded := {}

func _ready() -> void:
	var title := Label.new()
	title.text = "머리 편집"
	title.add_theme_font_size_override("font_size", 15)
	add_child(title)

	options_container = VBoxContainer.new()
	add_child(options_container)

	search_edit = UiRows.add_filter_row(self, UiText.slider_search_placeholder())
	search_edit.text_changed.connect(func(text: String) -> void:
		set_search_text(text)
	)

	changed_only_check = CheckBox.new()
	changed_only_check.text = UiText.changed_only_filter()
	changed_only_check.toggled.connect(func(enabled: bool) -> void:
		show_changed_only = enabled
		_apply_row_filter()
	)
	add_child(changed_only_check)

	slider_container = VBoxContainer.new()
	add_child(slider_container)

	# Operculum silhouette editor (shown only when gill_mark == "operculum").
	# Mirrors the fin vector editor: drag/add/delete points -> custom outline.
	operculum_editor = FinVectorEditorScript.new()
	operculum_editor.visible = false
	operculum_editor.points_changed.connect(func(pts: Array) -> void:
		if _updating:
			return
		parameters["operculum_custom_points"] = pts
		parameters_changed.emit(parameters.duplicate(true))
	)
	operculum_editor.preview_marker_changed.connect(func(active: bool, norm_position: Vector2, ghost: bool) -> void:
		vector_edit_preview_changed.emit("operculum", active and operculum_editor.visible, norm_position, ghost)
	)
	add_child(operculum_editor)

	_refresh_controls()

func set_parameters(new_parameters: Dictionary) -> void:
	parameters = new_parameters.duplicate(true)
	creature_type = CreatureModeScript.normalize(String(parameters.get("creature_type", creature_type)))
	_refresh_controls()

func set_creature_type(mode: String) -> void:
	var normalized_mode := CreatureModeScript.normalize(mode)
	if creature_type == normalized_mode:
		return
	creature_type = normalized_mode
	parameters["creature_type"] = creature_type
	_refresh_controls()

func focus_key(key: String) -> Control:
	if creature_type == CreatureModeScript.RAY:
		return null
	if not numeric_sliders.has(key) or not _should_show_fish_numeric_key(key):
		return null
	var title := _section_title_for_key(key)
	if title != "":
		var header := section_headers.get(title) as Button
		var body := section_bodies.get(title) as Control
		section_expanded[title] = true
		if header != null:
			header.button_pressed = true
			header.text = "  ▼  " + title
		if body != null:
			body.visible = true
	var widgets: Dictionary = numeric_sliders[key]
	var row := widgets.get("row") as Control
	if row != null:
		row.visible = true
	return row

func set_search_text(text: String) -> void:
	search_text = text
	if search_edit != null and search_edit.text != search_text:
		search_edit.text = search_text
	_apply_row_filter()

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
	var is_ray := creature_type == CreatureModeScript.RAY
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
	snout_appendage_option = null
	head_ornament_option = null
	gill_mark_option = null
	barbel_style_option = null
	mouth_detail_option = null
	ray_head_shape_option = null

	if is_ray:
		ray_head_shape_option = _add_option_row(options_container, UiText.parameter("ray_head_shape"), ["manta", "eagle", "cownose"])
		ray_head_shape_option.item_selected.connect(func(index: int) -> void:
			if not _updating:
				set_option_parameter("ray_head_shape", String(ray_head_shape_option.get_item_metadata(index)))
		)
	else:
		head_shape_grid = _add_thumbnail_option_grid(options_container, "형태", "head_shape", HEAD_SHAPES)
		head_shape_grid.value_selected.connect(func(value: String) -> void:
			if not _updating:
				set_head_shape(value)
		)

		mouth_type_grid = _add_thumbnail_option_grid(options_container, "입", "mouth_type", MOUTH_TYPES)
		mouth_type_grid.value_selected.connect(func(value: String) -> void:
			if not _updating:
				set_mouth_type(value)
		)

		if creature_type == CreatureModeScript.FISH:
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

		eye_style_grid = _add_thumbnail_option_grid(options_container, UiText.parameter("eye_style"), "eye_style", EYE_STYLES)
		eye_style_grid.value_selected.connect(func(value: String) -> void:
			if not _updating:
				set_option_parameter("eye_style", value)
		)

		mouth_detail_option = _add_option_row(options_container, UiText.parameter("mouth_detail"), MOUTH_DETAILS)
		mouth_detail_option.item_selected.connect(func(index: int) -> void:
			if not _updating:
				set_option_parameter("mouth_detail", String(mouth_detail_option.get_item_metadata(index)))
		)

		if creature_type == CreatureModeScript.FISH:
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

func _add_thumbnail_option_grid(parent: VBoxContainer, label_text: String, key: String, values: Array) -> Control:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	var grid = ThumbnailOptionGridScript.new()
	grid.setup(key, values, "res://assets/option_thumbs/%s" % key)
	row.add_child(grid)
	parent.add_child(row)
	return grid

func _add_numeric_row(parent: VBoxContainer, key: String, config: Dictionary) -> void:
	var slider_config := {
		"row_height": 0.0,
		"label_width": 112,
		"min": float(config["min"]),
		"max": float(config["max"]),
		"step": float(config["step"]),
	}
	var default_value := _default_numeric(key)
	if default_value >= float(config["min"]) and default_value <= float(config["max"]):
		slider_config["default"] = default_value
	var widgets := UiRows.add_labeled_slider(parent, UiText.parameter(key), slider_config)
	var slider := widgets["slider"] as HSlider
	var value_label := widgets["value_label"] as Label
	var row := widgets["row"] as Control
	widgets["label"] = value_label
	numeric_sliders[key] = widgets
	row.mouse_entered.connect(func() -> void:
		numeric_slider_hovered.emit(key)
	)
	row.mouse_exited.connect(func() -> void:
		numeric_slider_hovered.emit("")
	)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%.2f" % value
		UiRows.update_changed_marker(widgets)
		_apply_row_filter()
		if not _updating:
			numeric_slider_changed.emit(key)
			set_numeric_parameter(key, value)
	)

func _refresh_controls() -> void:
	if options_container == null:
		return
	_updating = true
	var is_ray := creature_type == CreatureModeScript.RAY
	var mode := creature_type
	if mode != current_editor_mode:
		current_editor_mode = mode
		_rebuild_controls_for_mode(is_ray)

	if is_ray:
		_select_option(ray_head_shape_option, String(parameters.get("ray_head_shape", "manta")))
	else:
		head_shape_grid.select_value(String(parameters.get("head_shape", "rounded")))
		mouth_type_grid.select_value(String(parameters.get("mouth_type", "terminal")))
		if head_ornament_option != null:
			_select_option(head_ornament_option, String(parameters.get("head_ornament", "none")))
		if gill_mark_option != null:
			_select_option(gill_mark_option, String(parameters.get("gill_mark", "none")))
		if barbel_style_option != null:
			_select_option(barbel_style_option, String(parameters.get("barbel_style", "none")))
		eye_style_grid.select_value(String(parameters.get("eye_style", "bead")))
		_select_option(mouth_detail_option, String(parameters.get("mouth_detail", "dot")))
		if snout_appendage_option != null:
			_select_option(snout_appendage_option, String(parameters.get("snout_appendage", "none")))
	_sync_numeric_controls(is_ray)
	for key in numeric_sliders.keys():
		var widgets: Dictionary = numeric_sliders[key]
		var slider := widgets["slider"] as HSlider
		var label := widgets["label"] as Label
		var value := float(parameters.get(key, _default_numeric(key)))
		slider.value = value
		label.text = "%.2f" % value
		UiRows.update_changed_marker(widgets)
	_position_operculum_editor()
	_updating = false
	_apply_row_filter()

# The operculum silhouette editor lives inside the "아가미" section body (added in
# _add_section). It is a persistent node, so we detach it before a slider rebuild
# frees that body, and re-parent it on rebuild. Here we only sync its content/visibility.
func _position_operculum_editor() -> void:
	if operculum_editor == null:
		return
	var is_op := creature_type == CreatureModeScript.FISH \
		and String(parameters.get("gill_mark", "none")) == "operculum"
	operculum_editor.visible = is_op
	if is_op:
		operculum_editor.slot = "operculum"
		operculum_editor.points = parameters.get("operculum_custom_points", BodyProfileScript.DEFAULT_OPERCULUM_POINTS)
		vector_edit_target_changed.emit("operculum")
	else:
		vector_edit_target_changed.emit("")
		vector_edit_preview_changed.emit("operculum", false, Vector2.ZERO, false)

func _sync_numeric_controls(is_ray: bool) -> void:
	var visible_keys := _visible_numeric_keys(is_ray)
	if _same_key_list(current_numeric_keys, visible_keys):
		return
	# Park the persistent operculum editor back on the panel root so it survives the
	# body queue_free below (and isn't orphaned); _add_section re-homes it if needed.
	if operculum_editor != null:
		var prev_parent := operculum_editor.get_parent()
		if prev_parent != self:
			if prev_parent != null:
				prev_parent.remove_child(operculum_editor)
			add_child(operculum_editor)
	for child in slider_container.get_children():
		child.queue_free()
	numeric_sliders.clear()
	section_bodies.clear()
	section_headers.clear()
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
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Default to collapsed except "머리 본체" or "머리"
	var default_expanded := title == "머리 본체" or title == "머리"
	header.button_pressed = bool(section_expanded.get(title, default_expanded))
	
	# Modern visual style for premium accordion look
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.14, 0.16, 0.19)
	style_normal.border_width_left = 4
	style_normal.border_color = Color(0.27, 0.77, 0.81) # Cyan border accent
	style_normal.content_margin_left = 12
	style_normal.content_margin_top = 6
	style_normal.content_margin_bottom = 6
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
	
	slider_container.add_child(header)

	var body := VBoxContainer.new()
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
	
	slider_container.add_child(body)
	for key in keys:
		_add_numeric_row(body, key, source[key])
	# Embed the operculum silhouette editor at the bottom of the gill section.
	if title == "아가미" and operculum_editor != null and String(parameters.get("gill_mark", "none")) == "operculum":
		if operculum_editor.get_parent() != null:
			operculum_editor.get_parent().remove_child(operculum_editor)
		body.add_child(operculum_editor)
	section_bodies[title] = body
	section_headers[title] = header

	var apply := func(expanded: bool) -> void:
		section_expanded[title] = expanded
		body.visible = expanded
		header.text = ("  ▼  " if expanded else "  ▶  ") + title
	apply.call(header.button_pressed)
	header.toggled.connect(func(pressed: bool) -> void: apply.call(pressed))
	_apply_row_filter()

func is_row_changed(key: String) -> bool:
	if not numeric_sliders.has(key):
		return false
	return UiRows.is_changed_from_default(numeric_sliders[key])

func _apply_row_filter() -> void:
	var search_active := search_text.strip_edges() != ""
	var filter_active := show_changed_only or search_active
	for key in numeric_sliders.keys():
		var widgets: Dictionary = numeric_sliders[key]
		var row := widgets.get("row") as Control
		if row == null:
			continue
		row.visible = _row_matches_filter(widgets)
	for title in section_bodies.keys():
		var body := section_bodies[title] as Control
		var header := section_headers.get(title) as Control
		if body == null:
			continue
		var any_visible := false
		for child in body.get_children():
			if child is HBoxContainer and (child as Control).visible:
				any_visible = true
				break
		if header != null:
			header.visible = (not filter_active) or any_visible
		if search_active:
			body.visible = any_visible
		else:
			body.visible = bool(section_expanded.get(title, false)) and ((not show_changed_only) or any_visible)

func _row_matches_filter(widgets: Dictionary) -> bool:
	if show_changed_only and not UiRows.is_changed_from_default(widgets):
		return false
	var query := search_text.strip_edges()
	if query == "":
		return true
	var name_label := widgets.get("name_label") as Label
	return name_label != null and name_label.text.contains(query)

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
		if creature_type != CreatureModeScript.FISH:
			return false
		var appendage := String(parameters.get("snout_appendage", "none"))
		return appendage != "" and appendage != "none"
	if key == "snout_base" or key == "snout_thickness" or key == "snout_taper" or key == "snout_curve":
		return float(parameters.get("snout_length", 0.0)) > 0.001
	if key == "head_top_peak":
		return absf(float(parameters.get("head_top_curve", 0.0))) > 0.001
	if key == "head_bump_pos" or key == "head_bump_width" or key == "head_bump_angle" or key == "head_bump_round":
		return float(parameters.get("head_bump_height", 0.0)) > 0.001
	if key.begins_with("operculum_"):
		return creature_type == CreatureModeScript.FISH and String(parameters.get("gill_mark", "none")) == "operculum"
	return true

func _section_title_for_key(key: String) -> String:
	for section in FISH_SECTIONS:
		var keys: Array = section.get("keys", [])
		if keys.has(key):
			return String(section.get("title", ""))
	return ""

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
		"lower_jaw_length":
			return 1.0
		"lower_jaw_angle":
			return 0.0
		"lower_jaw_thickness":
			return 1.0
		"lower_jaw_tip":
			return 0.0
		"operculum_size":
			return 1.0
		"operculum_height":
			return 1.0
		"operculum_open":
			return 0.0
		"operculum_ridge":
			return 0.45
		"eye_size":
			return 0.055
		"eye_position_x":
			return -0.78
		"eye_position_y":
			return 0.12
		"eye_pupil_scale":
			return 0.6
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
