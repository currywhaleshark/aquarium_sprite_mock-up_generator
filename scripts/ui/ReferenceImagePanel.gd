class_name ReferenceImagePanel
extends VBoxContainer

signal reference_changed(settings: Dictionary)

const UiText := preload("res://scripts/ui/UiText.gd")

const NUMERIC_SETTINGS := {
	"scale": {"min": 0.05, "max": 4.0, "step": 0.01},
	"offset_x": {"min": -900.0, "max": 900.0, "step": 1.0},
	"offset_y": {"min": -700.0, "max": 700.0, "step": 1.0},
	"opacity": {"min": 0.05, "max": 1.0, "step": 0.01}
}

var settings := {
	"path": "",
	"visible": false,
	"scale": 1.0,
	"offset_x": 0.0,
	"offset_y": 0.0,
	"opacity": 0.45
}
var path_label: Label
var visible_check: CheckButton
var numeric_sliders := {}
var file_dialog: FileDialog
var _updating := false

func _ready() -> void:
	add_theme_constant_override("separation", 5)

	var title := Button.new()
	title.text = "v 참조 이미지"
	title.toggle_mode = true
	title.button_pressed = true
	title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(title)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 4)
	add_child(body)
	title.toggled.connect(func(opened: bool) -> void:
		body.visible = opened
		title.text = "%s 참조 이미지" % ("v" if opened else ">")
	)

	var actions := HBoxContainer.new()
	body.add_child(actions)
	var load_button := Button.new()
	load_button.text = "불러오기 / 교체"
	load_button.pressed.connect(_open_file_dialog)
	actions.add_child(load_button)
	var clear_button := Button.new()
	clear_button.text = "삭제"
	clear_button.pressed.connect(clear_reference)
	actions.add_child(clear_button)

	visible_check = CheckButton.new()
	visible_check.text = "이미지 표시"
	visible_check.toggled.connect(func(enabled: bool) -> void:
		if not _updating:
			set_reference_visible(enabled)
	)
	body.add_child(visible_check)

	path_label = Label.new()
	path_label.text = "불러온 이미지 없음"
	path_label.clip_text = true
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(path_label)

	for key in NUMERIC_SETTINGS.keys():
		_add_numeric_row(body, key)

	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; 이미지 파일"])
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)
	_refresh_controls()

func set_reference_settings(new_settings: Dictionary) -> void:
	for key in settings.keys():
		if new_settings.has(key):
			settings[key] = new_settings[key]
	_refresh_controls()
	reference_changed.emit(settings.duplicate(true))

func set_reference_visible(enabled: bool) -> void:
	settings["visible"] = enabled and String(settings.get("path", "")) != ""
	_emit_and_refresh()

func set_numeric_setting(key: String, value: float) -> void:
	if not NUMERIC_SETTINGS.has(key):
		return
	var config: Dictionary = NUMERIC_SETTINGS[key]
	settings[key] = clampf(value, float(config["min"]), float(config["max"]))
	_emit_and_refresh()

func clear_reference() -> void:
	settings["path"] = ""
	settings["visible"] = false
	_emit_and_refresh()

func _open_file_dialog() -> void:
	if file_dialog == null:
		return
	file_dialog.popup_centered_ratio(0.7)

func _on_file_selected(path: String) -> void:
	settings["path"] = path
	settings["visible"] = true
	_emit_and_refresh()

func _add_numeric_row(parent: VBoxContainer, key: String) -> void:
	var config: Dictionary = NUMERIC_SETTINGS[key]
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 28)
	var label := Label.new()
	label.text = UiText.reference_label(key)
	label.custom_minimum_size = Vector2(82, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = float(config["min"])
	slider.max_value = float(config["max"])
	slider.step = float(config["step"])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(48, 0)
	row.add_child(value_label)
	numeric_sliders[key] = {"slider": slider, "label": value_label}
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%.2f" % value
		if not _updating:
			set_numeric_setting(key, value)
	)
	parent.add_child(row)

func _emit_and_refresh() -> void:
	reference_changed.emit(settings.duplicate(true))
	_refresh_controls()

func _refresh_controls() -> void:
	if visible_check == null:
		return
	_updating = true
	var path := String(settings.get("path", ""))
	visible_check.button_pressed = bool(settings.get("visible", false)) and path != ""
	path_label.text = path.get_file() if path != "" else "불러온 이미지 없음"
	for key in numeric_sliders.keys():
		var widgets: Dictionary = numeric_sliders[key]
		var slider := widgets["slider"] as HSlider
		var label := widgets["label"] as Label
		var value := float(settings.get(key, 0.0))
		slider.value = value
		label.text = "%.2f" % value
	_updating = false
