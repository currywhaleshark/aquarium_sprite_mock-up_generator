extends Node

const UiRows := preload("res://scripts/ui/UiRows.gd")

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)

func _ready() -> void:
	var container := VBoxContainer.new()
	add_child(container)

	var widgets := UiRows.add_labeled_slider(container, "Defaulted", {
		"min": 0.0,
		"max": 1.0,
		"step": 0.01,
		"default": 0.4,
		"value": 0.8,
	})
	for key in ["row", "slider", "value_label", "name_label"]:
		if not widgets.has(key):
			_fail("add_labeled_slider missing returned widget key: %s" % key)
			return

	var row := widgets["row"] as HBoxContainer
	if row.get_child_count() != 3:
		_fail("slider row child count changed: %d" % row.get_child_count())
		return
	if not (row.get_child(0) is Label and row.get_child(1) is HSlider and row.get_child(2) is Label):
		_fail("slider row child order changed")
		return

	if not UiRows.is_changed_from_default(widgets):
		_fail("slider with value 0.8 and default 0.4 should be marked changed")
		return
	UiRows.reset_row_to_default(widgets)
	var slider := widgets["slider"] as HSlider
	if absf(slider.value - 0.4) > 0.001:
		_fail("reset_row_to_default did not reset slider value: %.4f" % slider.value)
		return
	if UiRows.is_changed_from_default(widgets):
		_fail("slider should not be changed after default reset")
		return

	var no_default := UiRows.add_labeled_slider(container, "No Default", {
		"min": 0.0,
		"max": 1.0,
		"step": 0.01,
		"value": 0.6,
	})
	UiRows.reset_row_to_default(no_default)
	if UiRows.is_changed_from_default(no_default):
		_fail("slider without default should never be marked changed")
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/ui_rows_defaults.ok", FileAccess.WRITE)
	file.store_string("ui rows default helpers work")
	file.close()
	print("UI_ROWS_DEFAULTS_TEST_OK")
	get_tree().quit(0)
