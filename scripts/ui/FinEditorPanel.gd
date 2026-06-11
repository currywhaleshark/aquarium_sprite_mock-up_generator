class_name FinEditorPanel
extends VBoxContainer

signal parameters_changed(parameters: Dictionary)
signal numeric_slider_changed(key: String)
signal vector_edit_target_changed(slot: String)
signal vector_edit_preview_changed(slot: String, active: bool, norm_position: Vector2, ghost: bool)

const UiText := preload("res://scripts/ui/UiText.gd")
const UiRows := preload("res://scripts/ui/UiRows.gd")
const FinVectorEditorScript := preload("res://scripts/ui/FinVectorEditor.gd")

const SLOT_LABELS := {
	"dorsal_1": "Dorsal 1",
	"dorsal_2": "Dorsal 2",
	"pectoral": "Pectoral",
	"pelvic": "Pelvic",
	"anal": "Anal",
	"caudal": "Caudal",
	"adipose_fin": "Adipose",
	"finlet": "Finlet",
	"cephalic": "Cephalic"
}

const SHAPES := {
	"dorsal_1": ["single", "spiny", "split", "trailing", "trigger", "bezier", "custom"],
	"dorsal_2": ["single", "spiny", "split", "trailing", "trigger", "bezier", "custom"],
	"pectoral": ["oval", "triangle", "long", "rounded", "bezier", "custom"],
	"pelvic": ["triangle", "oval", "long", "rounded", "bezier", "custom"],
	"anal": ["long", "single", "spiny", "rounded", "bezier", "custom"],
	"adipose_fin": ["nub", "single", "rounded", "triangle", "bezier", "custom"],
	"finlet": ["triangle", "single", "rounded", "bezier", "custom"],
	"caudal": [
		"forked_shallow", "forked_deep", "truncate", "rounded", "pointed", "lunate",
		"fan", "double_fan", "halfmoon", "veil", "crowntail", "spade", "lyre",
		"top_sword", "bottom_sword", "double_sword", "butterfly",
		"shark_heterocercal", "thresher", "custom"
	],
	"cephalic": ["none", "rolled", "unfolded"]
}

const NUMERIC_KEYS := {
	"dorsal_1": {
		"dorsal_1_length": {"min": 0.08, "max": 1.2, "step": 0.005, "fallback": 0.42},
		"dorsal_1_height": {"min": 0.04, "max": 0.8, "step": 0.005, "fallback_key": "dorsal_fin_size", "fallback": 0.28},
		"dorsal_fin_offset_x": {"min": -0.55, "max": 0.55, "step": 0.005, "fallback": 0.0},
		"dorsal_1_softness": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback_key": "fin_softness", "fallback": 0.0},
		"dorsal_1_rigidity": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback_key": "fin_rigidity", "fallback": 0.0}
	},
	"dorsal_2": {
		"dorsal_2_length": {"min": 0.08, "max": 1.2, "step": 0.005, "fallback": 0.34},
		"dorsal_2_height": {"min": 0.04, "max": 0.8, "step": 0.005, "fallback": 0.18},
		"dorsal_2_softness": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback_key": "fin_softness", "fallback": 0.0},
		"dorsal_2_rigidity": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback_key": "fin_rigidity", "fallback": 0.0}
	},
	"pectoral": {
		"pectoral_fin_size": {"min": 0.04, "max": 0.6, "step": 0.005, "fallback": 0.16},
		"pectoral_fin_offset_x": {"min": -0.55, "max": 0.55, "step": 0.005, "fallback": 0.0},
		"pectoral_fin_yaw": {"min": -180.0, "max": 180.0, "step": 1.0, "fallback": 25.0},
		"pectoral_fin_pitch": {"min": -180.0, "max": 180.0, "step": 1.0, "fallback": 0.0},
		"pectoral_fin_roll": {"min": -180.0, "max": 180.0, "step": 1.0, "fallback": -28.0},
		"pectoral_softness": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback_key": "fin_softness", "fallback": 0.0},
		"pectoral_rigidity": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback_key": "fin_rigidity", "fallback": 0.0}
	},
	"pelvic": {
		"pelvic_length": {"min": 0.04, "max": 0.7, "step": 0.005, "fallback": 0.22},
		"pelvic_height": {"min": 0.03, "max": 0.5, "step": 0.005, "fallback": 0.14},
		"pelvic_softness": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback_key": "fin_softness", "fallback": 0.0},
		"pelvic_rigidity": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback_key": "fin_rigidity", "fallback": 0.0}
	},
	"anal": {
		"anal_length": {"min": 0.04, "max": 1.0, "step": 0.005, "fallback": 0.36},
		"anal_height": {"min": 0.03, "max": 0.7, "step": 0.005, "fallback_key": "anal_fin_size", "fallback": 0.2},
		"anal_fin_offset_x": {"min": -0.55, "max": 0.55, "step": 0.005, "fallback": 0.0},
		"anal_softness": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback_key": "fin_softness", "fallback": 0.0},
		"anal_rigidity": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback_key": "fin_rigidity", "fallback": 0.0}
	},
	"caudal": {
		"tail_fin_size": {"min": 0.08, "max": 1.2, "step": 0.005, "fallback": 0.46},
		"caudal_height_scale": {"min": 0.2, "max": 1.8, "step": 0.005, "fallback": 0.72},
		"caudal_softness": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback_key": "fin_softness", "fallback": 0.0},
		"caudal_rigidity": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback_key": "fin_rigidity", "fallback": 0.0}
	},
	"adipose_fin": {
		"adipose_fin_size": {"min": 0.04, "max": 0.7, "step": 0.005, "fallback": 0.24},
		"adipose_fin_height": {"min": 0.04, "max": 0.8, "step": 0.005, "fallback": 0.18},
		"adipose_fin_roundness": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback": 0.75},
		"adipose_fin_opacity": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback": 0.72},
		"adipose_fin_rayed": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback": 0.0}
	},
	"finlet": {
		"finlet_dorsal_count": {"min": 0.0, "max": 12.0, "step": 1.0, "fallback": 0.0},
		"finlet_ventral_count": {"min": 0.0, "max": 12.0, "step": 1.0, "fallback": 0.0},
		"finlet_size": {"min": 0.04, "max": 0.7, "step": 0.005, "fallback": 0.25},
		"finlet_taper": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback": 0.35},
		"finlet_spacing": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback": 0.72},
		"finlet_pitch": {"min": -1.0, "max": 1.0, "step": 0.01, "fallback": 0.25},
		"finlet_color_blend": {"min": 0.0, "max": 1.0, "step": 0.01, "fallback": 0.5}
	}
}

var parameters: Dictionary = {}
var selected_slot := "dorsal_1"
var slot_option: OptionButton
var enabled_check: CheckBox
var attach_row_container: HBoxContainer
var attach_slider: HSlider
var shape_option: OptionButton
var numeric_container: VBoxContainer
var numeric_sliders := {}
var vector_editor: Control
var search_edit: LineEdit
var search_text := ""
var changed_only_check: CheckBox
var show_changed_only := false
var _updating := false

func _ready() -> void:
	var title := Label.new()
	title.text = "지느러미 편집"
	title.add_theme_font_size_override("font_size", 15)
	add_child(title)

	slot_option = OptionButton.new()
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

	attach_row_container = HBoxContainer.new()
	var attach_label := Label.new()
	attach_label.text = "부착 위치"
	attach_label.custom_minimum_size = Vector2(72, 0)
	attach_row_container.add_child(attach_label)
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
	attach_row_container.add_child(attach_slider)
	add_child(attach_row_container)

	shape_option = OptionButton.new()
	shape_option.item_selected.connect(func(index: int) -> void:
		if _updating:
			return
		set_slot_shape(selected_slot, String(shape_option.get_item_metadata(index)))
	)
	add_child(shape_option)

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

	numeric_container = VBoxContainer.new()
	numeric_container.add_theme_constant_override("separation", 1)
	add_child(numeric_container)

	vector_editor = FinVectorEditorScript.new()
	vector_editor.visible = false
	vector_editor.points_changed.connect(func(pts: Array) -> void:
		if _updating:
			return
		parameters[selected_slot + "_custom_points"] = pts
		parameters_changed.emit(parameters.duplicate(true))
	)
	vector_editor.preview_marker_changed.connect(func(active: bool, norm_position: Vector2, ghost: bool) -> void:
		vector_edit_preview_changed.emit(selected_slot, active and vector_editor.visible, norm_position, ghost)
	)
	add_child(vector_editor)

	_refresh_controls()

func set_parameters(new_parameters: Dictionary) -> void:
	parameters = new_parameters.duplicate(true)
	_refresh_controls()

func set_search_text(text: String) -> void:
	search_text = text
	if search_edit != null and search_edit.text != search_text:
		search_edit.text = search_text
	_apply_row_filter()

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

func _populate_slots() -> void:
	if slot_option == null:
		return
	var is_ray := String(parameters.get("creature_type", "fish")) == "ray"
	var expected_slots := []
	if is_ray:
		expected_slots = ["cephalic", "pelvic"]
	else:
		expected_slots = ["dorsal_1", "dorsal_2", "pectoral", "pelvic", "anal", "caudal", "adipose_fin", "finlet"]
	
	var matches := true
	if slot_option.item_count != expected_slots.size():
		matches = false
	else:
		for i in range(expected_slots.size()):
			if String(slot_option.get_item_metadata(i)) != expected_slots[i]:
				matches = false
				break
	
	if not matches:
		var current_sel := selected_slot
		slot_option.clear()
		for slot_id in expected_slots:
			var label := UiText.ray_fin_slot(slot_id) if is_ray else UiText.fin_slot(slot_id)
			slot_option.add_item(label)
			slot_option.set_item_metadata(slot_option.item_count - 1, slot_id)
		var new_index := expected_slots.find(current_sel)
		if new_index < 0:
			new_index = 0
		slot_option.select(new_index)
		selected_slot = expected_slots[new_index]

func _refresh_controls() -> void:
	if slot_option == null:
		return
	_updating = true
	_populate_slots()
	
	var is_ray := String(parameters.get("creature_type", "fish")) == "ray"
	if is_ray:
		enabled_check.visible = false
		attach_row_container.visible = false
		shape_option.visible = selected_slot == "cephalic"
	else:
		enabled_check.visible = true
		attach_row_container.visible = true
		shape_option.visible = true
	
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
	
	# Update Vector Editor Canvas
	if vector_editor != null:
		if current_shape == "custom":
			vector_editor.visible = true
			vector_editor.slot = selected_slot
			var default_pts := []
			if selected_slot == "caudal":
				default_pts = [0.0, 0.44, 0.88, 0.98, 1.0, 0.0, 0.88, -0.98, 0.0, -0.44]
			elif selected_slot == "adipose_fin":
				default_pts = [-0.45, 0.0, -0.10, 1.0, 0.45, 0.25, 0.40, 0.0]
			elif selected_slot == "finlet":
				default_pts = [-0.45, 0.0, 0.0, 1.0, 0.45, 0.0]
			elif selected_slot == "pectoral" or selected_slot == "pelvic":
				default_pts = [-0.5, 0.2, 0.0, 0.5, 0.5, 0.0, 0.0, -0.5, -0.5, -0.2]
			else:
				default_pts = [-0.5, 0.0, -0.25, 0.6, 0.0, 0.8, 0.25, 0.6, 0.5, 0.0]
			vector_editor.points = parameters.get(selected_slot + "_custom_points", default_pts)
			vector_edit_target_changed.emit(selected_slot)
		else:
			vector_editor.visible = false
			vector_edit_target_changed.emit("")
			vector_edit_preview_changed.emit(selected_slot, false, Vector2.ZERO, false)
			
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
			UiRows.set_row_default(widgets, _numeric_default(String(key), slot_keys[key]))
			slider.value = value
			label.text = "%.2f" % value
			UiRows.update_changed_marker(widgets)
	else:
		for child in numeric_container.get_children():
			child.queue_free()
		numeric_sliders.clear()
		for key in slot_keys.keys():
			_add_numeric_row(String(key), slot_keys[key])
	_apply_row_filter()

func _add_numeric_row(key: String, config: Dictionary) -> void:
	var widgets := UiRows.add_labeled_slider(numeric_container, UiText.fin_parameter(key), {
		"label_width": 112,
		"min": float(config.get("min", 0.0)),
		"max": float(config.get("max", 1.0)),
		"step": float(config.get("step", 0.005)),
		"default": _numeric_default(key, config),
		"value": _numeric_value(key, config),
	})
	var slider := widgets["slider"] as HSlider
	var value_label := widgets["value_label"] as Label
	widgets["label"] = value_label
	numeric_sliders[key] = widgets
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%.2f" % value
		UiRows.update_changed_marker(widgets)
		_apply_row_filter()
		if not _updating:
			numeric_slider_changed.emit(key)
			set_numeric_parameter(key, value)
	)

func _numeric_value(key: String, config: Dictionary) -> float:
	if parameters.has(key):
		return float(parameters[key])
	var fallback_key := String(config.get("fallback_key", ""))
	if fallback_key != "" and parameters.has(fallback_key):
		return float(parameters[fallback_key])
	return float(config.get("fallback", 0.0))

func _numeric_default(_key: String, config: Dictionary) -> float:
	var fallback_key := String(config.get("fallback_key", ""))
	if fallback_key != "" and parameters.has(fallback_key):
		return float(parameters[fallback_key])
	return float(config.get("fallback", 0.0))

func is_row_changed(key: String) -> bool:
	if not numeric_sliders.has(key):
		return false
	return UiRows.is_changed_from_default(numeric_sliders[key])

func _apply_row_filter() -> void:
	for key in numeric_sliders.keys():
		var widgets: Dictionary = numeric_sliders[key]
		var row := widgets.get("row") as Control
		if row == null:
			continue
		row.visible = _row_matches_filter(widgets)

func _row_matches_filter(widgets: Dictionary) -> bool:
	if show_changed_only and not UiRows.is_changed_from_default(widgets):
		return false
	var query := search_text.strip_edges()
	if query == "":
		return true
	var name_label := widgets.get("name_label") as Label
	return name_label != null and name_label.text.contains(query)

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
		"adipose_fin":
			return "adipose_fin_position"
	return ""

func _shape_key(slot_id: String) -> String:
	match slot_id:
		"cephalic":
			return "cephalic_horns"
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
	if slot_id == "dorsal_2" or slot_id == "pelvic" or slot_id == "adipose_fin" or slot_id == "finlet":
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
		"adipose_fin":
			return 0.82
	return 0.5
