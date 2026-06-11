extends Node

const ThumbnailOptionGridScript := preload("res://scripts/ui/ThumbnailOptionGrid.gd")
const UiText := preload("res://scripts/ui/UiText.gd")

var _failed := false

func _ready() -> void:
	var grid = ThumbnailOptionGridScript.new()
	add_child(grid)
	grid.setup("head_shape", ["rounded", "pointed"], "res://assets/option_thumbs/head_shape")
	var buttons := _buttons_under(grid)
	_require(buttons.size() == 2, "setup should create one button per option")
	_require(_has_label(buttons[0], UiText.option("rounded")), "first button should caption rounded option")
	_require(_has_label(buttons[1], UiText.option("pointed")), "second button should caption pointed option")
	_require(_texture_rect_under(buttons[0]) != null, "existing thumbnail should create a TextureRect")

	grid.setup("head_shape", ["rounded"], "res://assets/option_thumbs/does_not_exist")
	buttons = _buttons_under(grid)
	_require(buttons.size() == 1, "fallback setup should still create a button")
	_require(_texture_rect_under(buttons[0]) == null, "missing thumbnail should use text-only fallback")
	_require(_has_label(buttons[0], UiText.option("rounded")), "fallback button should keep caption")

	grid.setup("head_shape", ["rounded", "pointed"], "res://assets/option_thumbs/head_shape")
	buttons = _buttons_under(grid)
	var selected_values: Array[String] = []
	grid.value_selected.connect(func(value: String) -> void:
		selected_values.append(value)
	)
	grid.select_value("pointed")
	_require(not buttons[0].button_pressed, "unselected button should not be pressed")
	_require(buttons[1].button_pressed, "selected button should be pressed")
	buttons[0].pressed.emit()
	_require(selected_values == ["rounded"], "button press should emit selected value")
	_require(buttons[0].button_pressed and not buttons[1].button_pressed, "button press should update selected state")

	if _failed:
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/thumbnail_option_grid.ok", FileAccess.WRITE)
	file.store_string("thumbnail option grid loaded thumbnails and selected values")
	file.close()
	print("THUMBNAIL_OPTION_GRID_TEST_OK")
	get_tree().quit(0)

func _buttons_under(root: Node) -> Array[Button]:
	var result: Array[Button] = []
	_collect_buttons(root, result)
	return result

func _collect_buttons(node: Node, result: Array[Button]) -> void:
	for child in node.get_children():
		if child is Button:
			result.append(child)
		_collect_buttons(child, result)

func _has_label(root: Node, text: String) -> bool:
	for child in root.get_children():
		if child is Label and (child as Label).text == text:
			return true
		if _has_label(child, text):
			return true
	return false

func _texture_rect_under(root: Node) -> TextureRect:
	for child in root.get_children():
		if child is TextureRect:
			return child as TextureRect
		var nested := _texture_rect_under(child)
		if nested != null:
			return nested
	return null

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
