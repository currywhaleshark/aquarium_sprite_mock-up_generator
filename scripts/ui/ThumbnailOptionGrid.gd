class_name ThumbnailOptionGrid
extends Control

signal value_selected(value: String)

const UiText := preload("res://scripts/ui/UiText.gd")

const COLUMN_COUNT := 3
const CARD_SIZE := Vector2(106, 122)
const IMAGE_SIZE := Vector2(76, 76)
const CARD_PADDING := 6.0

var option_key := ""
var thumb_dir := ""
var grid: GridContainer
var button_group := ButtonGroup.new()
var buttons_by_value := {}

func _ready() -> void:
	_ensure_grid()

func setup(key: String, values: Array, thumbnail_dir: String) -> void:
	option_key = key
	thumb_dir = thumbnail_dir.trim_suffix("/")
	_ensure_grid()
	_clear_grid()
	buttons_by_value.clear()
	for value in values:
		_add_option_button(String(value))
	_sync_minimum_size()

func select_value(value: String) -> void:
	for option_value in buttons_by_value.keys():
		var button := buttons_by_value[option_value] as Button
		button.button_pressed = String(option_value) == value

func _get_minimum_size() -> Vector2:
	return _grid_minimum_size()

func _ensure_grid() -> void:
	if grid != null:
		return
	grid = GridContainer.new()
	grid.columns = COLUMN_COUNT
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(grid)

func _clear_grid() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.free()

func _add_option_button(value: String) -> void:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = button_group
	button.custom_minimum_size = CARD_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.focus_mode = Control.FOCUS_ALL

	var caption := UiText.option(value)
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 3)
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = CARD_PADDING
	layout.offset_top = CARD_PADDING
	layout.offset_right = -CARD_PADDING
	layout.offset_bottom = -CARD_PADDING
	button.add_child(layout)

	var texture := _load_thumbnail(value)
	if texture != null:
		var rect := TextureRect.new()
		rect.custom_minimum_size = IMAGE_SIZE
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture = texture
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.add_child(rect)

	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	layout.add_child(label)

	button.pressed.connect(func() -> void:
		select_value(value)
		value_selected.emit(value)
	)
	grid.add_child(button)
	buttons_by_value[value] = button

func _sync_minimum_size() -> void:
	custom_minimum_size = _grid_minimum_size()
	update_minimum_size()

func _grid_minimum_size() -> Vector2:
	if grid == null:
		return Vector2.ZERO
	return grid.get_combined_minimum_size()

func _load_thumbnail(value: String) -> Texture2D:
	if thumb_dir == "":
		return null
	var path := "%s/%s.png" % [thumb_dir, value]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
