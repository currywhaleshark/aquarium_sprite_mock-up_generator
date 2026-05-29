extends Node

const BodyEditorPanelScript := preload("res://scripts/ui/BodyEditorPanel.gd")

func _ready() -> void:
	var panel := BodyEditorPanelScript.new()
	add_child(panel)
	var seen := [{}]
	panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		seen[0] = parameters
	)
	panel.set_parameters({
		"body_profile_shape": "fusiform",
		"head_depth_scale": 0.9,
		"midbody_depth_scale": 1.0
	})
	panel.set_body_profile_shape("deep_compressed")
	assert(String(seen[0].get("body_profile_shape", "")) == "deep_compressed")
	panel.set_numeric_parameter("midbody_depth_scale", 1.42)
	panel.set_numeric_parameter("lateral_compression", 0.55)
	panel.set_numeric_parameter("body_depth_bias", -0.75)
	panel.set_numeric_parameter("head_vertical_offset", 0.21)
	panel.set_numeric_parameter("tail_vertical_offset", -0.19)

	assert(String(seen[0].get("body_profile_shape", "")) == "custom")
	assert(abs(float(seen[0].get("midbody_depth_scale", 0.0)) - 1.42) < 0.001)
	assert(abs(float(seen[0].get("lateral_compression", 0.0)) - 0.55) < 0.001)
	assert(abs(float(seen[0].get("body_depth_bias", 0.0)) + 0.75) < 0.001)
	assert(abs(float(seen[0].get("head_vertical_offset", 0.0)) - 0.21) < 0.001)
	assert(abs(float(seen[0].get("tail_vertical_offset", 0.0)) + 0.19) < 0.001)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/body_editor_panel.ok", FileAccess.WRITE)
	file.store_string("body editor panel parameters emitted")
	file.close()
	print("BODY_EDITOR_PANEL_TEST_OK")
	get_tree().quit(0)
