class_name ReferenceImagePanel
extends VBoxContainer

signal reference_changed(settings: Dictionary)

const UiText := preload("res://scripts/ui/UiText.gd")
const UiRows := preload("res://scripts/ui/UiRows.gd")

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
var dialog_preview_texture: TextureRect
var dialog_preview_label: Label
var _dialog_preview_path := ""
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
	file_dialog.use_native_dialog = false
	file_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; 이미지 파일"])
	file_dialog.file_selected.connect(_on_file_selected)
	_add_dialog_preview(file_dialog)
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
	_update_dialog_preview("")
	file_dialog.popup_centered_ratio(0.7)

func _on_file_selected(path: String) -> void:
	settings["path"] = path
	settings["visible"] = true
	_update_dialog_preview(path)
	_emit_and_refresh()

func _process(_delta: float) -> void:
	if file_dialog == null or not file_dialog.visible:
		return
	var candidate_path := String(file_dialog.get("current_path"))
	if candidate_path == "":
		var current_dir := String(file_dialog.get("current_dir"))
		var current_file := String(file_dialog.get("current_file"))
		if current_dir != "" and current_file != "":
			candidate_path = current_dir.path_join(current_file)
	if candidate_path != _dialog_preview_path:
		_update_dialog_preview(candidate_path)

func _add_numeric_row(parent: VBoxContainer, key: String) -> void:
	var config: Dictionary = NUMERIC_SETTINGS[key]
	var widgets := UiRows.add_labeled_slider(parent, UiText.reference_label(key), {
		"label_width": 82,
		"value_width": 48,
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
			set_numeric_setting(key, value)
	)

func _add_dialog_preview(dialog: FileDialog) -> void:
	var preview_box := VBoxContainer.new()
	preview_box.name = "ReferenceDialogPreview"
	preview_box.custom_minimum_size = Vector2(240, 190)
	preview_box.add_theme_constant_override("separation", 4)
	dialog.get_vbox().add_child(preview_box)

	var title := Label.new()
	title.text = "선택 이미지 미리보기"
	preview_box.add_child(title)

	dialog_preview_texture = TextureRect.new()
	dialog_preview_texture.custom_minimum_size = Vector2(240, 150)
	dialog_preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialog_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_box.add_child(dialog_preview_texture)

	dialog_preview_label = Label.new()
	dialog_preview_label.text = "이미지를 선택하면 미리보기가 표시됩니다"
	dialog_preview_label.clip_text = true
	dialog_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_box.add_child(dialog_preview_label)

func _update_dialog_preview(path: String) -> void:
	_dialog_preview_path = path
	if dialog_preview_texture == null or dialog_preview_label == null:
		return
	var extension := path.get_extension().to_lower()
	if path == "" or not ["png", "jpg", "jpeg", "webp"].has(extension) or not FileAccess.file_exists(path):
		dialog_preview_texture.texture = null
		dialog_preview_label.text = "미리보기 없음"
		return
	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		dialog_preview_texture.texture = null
		dialog_preview_label.text = "미리보기 불러오기 실패"
		return
	dialog_preview_texture.texture = ImageTexture.create_from_image(image)
	dialog_preview_label.text = "%s (%dx%d)" % [path.get_file(), image.get_width(), image.get_height()]

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
