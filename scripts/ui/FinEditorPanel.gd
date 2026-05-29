class_name FinEditorPanel
extends VBoxContainer

signal parameters_changed(parameters: Dictionary)

const SLOT_LABELS := {
	"dorsal_1": "Dorsal 1",
	"dorsal_2": "Dorsal 2",
	"pectoral": "Pectoral",
	"pelvic": "Pelvic",
	"anal": "Anal",
	"caudal": "Caudal"
}

const SHAPES := {
	"dorsal_1": ["single", "spiny", "split", "trailing", "trigger"],
	"dorsal_2": ["single", "spiny", "split", "trailing", "trigger"],
	"pectoral": ["oval", "triangle", "long", "rounded"],
	"pelvic": ["triangle", "oval", "long", "rounded"],
	"anal": ["long", "single", "spiny", "rounded"],
	"caudal": ["forked_shallow", "forked_deep", "truncate", "rounded", "pointed", "lunate", "shark_heterocercal", "thresher"]
}

var parameters: Dictionary = {}
var selected_slot := "dorsal_1"
var slot_option: OptionButton
var enabled_check: CheckBox
var attach_slider: HSlider
var shape_option: OptionButton
var _updating := false

func _ready() -> void:
	var title := Label.new()
	title.text = "Fin Editor"
	title.add_theme_font_size_override("font_size", 15)
	add_child(title)

	slot_option = OptionButton.new()
	for slot_id in SLOT_LABELS.keys():
		slot_option.add_item(SLOT_LABELS[slot_id])
		slot_option.set_item_metadata(slot_option.item_count - 1, slot_id)
	slot_option.item_selected.connect(func(index: int) -> void:
		selected_slot = String(slot_option.get_item_metadata(index))
		_refresh_controls()
	)
	add_child(slot_option)

	enabled_check = CheckBox.new()
	enabled_check.text = "Enabled"
	enabled_check.toggled.connect(func(value: bool) -> void:
		if _updating:
			return
		set_slot_enabled(selected_slot, value)
	)
	add_child(enabled_check)

	var attach_row := HBoxContainer.new()
	var attach_label := Label.new()
	attach_label.text = "Attach"
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
		set_slot_shape(selected_slot, shape_option.get_item_text(index))
	)
	add_child(shape_option)
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

func _refresh_controls() -> void:
	if slot_option == null:
		return
	_updating = true
	enabled_check.button_pressed = float(parameters.get(_enabled_key(selected_slot), _default_enabled(selected_slot))) > 0.5
	var attach_key := _attach_key(selected_slot)
	attach_slider.editable = attach_key != ""
	attach_slider.value = float(parameters.get(attach_key, _default_attach(selected_slot))) if attach_key != "" else 0.5
	shape_option.clear()
	var shapes: Array = SHAPES.get(selected_slot, ["single"])
	for shape in shapes:
		shape_option.add_item(String(shape))
	var current_shape := String(parameters.get(_shape_key(selected_slot), shapes[0]))
	for i in shape_option.item_count:
		if shape_option.get_item_text(i) == current_shape:
			shape_option.select(i)
			break
	_updating = false

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
