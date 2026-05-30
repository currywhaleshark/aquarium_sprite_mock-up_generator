extends Node

const HeadEditorPanelScript := preload("res://scripts/ui/HeadEditorPanel.gd")

func _ready() -> void:
	var panel := HeadEditorPanelScript.new()
	add_child(panel)
	var seen := [{}]
	panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		seen[0] = parameters
	)
	panel.set_parameters({
		"head_shape": "rounded",
		"mouth_type": "terminal",
		"head_offset": -0.58,
		"eye_position_y": 0.12,
		"snout_length": 0.0,
		"mouth_size": 0.08
	})
	panel.set_head_shape("steep_forehead")
	panel.set_mouth_type("inferior")
	panel.set_numeric_parameter("snout_length", 0.24)
	panel.set_numeric_parameter("head_offset", -0.72)
	panel.set_numeric_parameter("eye_position_y", 0.2)
	assert(String(seen[0].get("head_shape", "")) == "steep_forehead")
	assert(String(seen[0].get("mouth_type", "")) == "inferior")
	assert(abs(float(seen[0].get("snout_length", 0.0)) - 0.24) < 0.001)
	assert(abs(float(seen[0].get("head_offset", 0.0)) + 0.72) < 0.001)
	assert(abs(float(seen[0].get("eye_position_y", 0.0)) - 0.2) < 0.001)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/head_editor_panel.ok", FileAccess.WRITE)
	file.store_string("head editor panel parameters emitted")
	file.close()
	print("HEAD_EDITOR_PANEL_TEST_OK")
	get_tree().quit(0)
