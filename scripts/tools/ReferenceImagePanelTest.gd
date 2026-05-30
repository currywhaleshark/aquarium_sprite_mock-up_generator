extends Node

const ReferenceImagePanelScript := preload("res://scripts/ui/ReferenceImagePanel.gd")

func _ready() -> void:
	var panel := ReferenceImagePanelScript.new()
	add_child(panel)
	var seen := [{}]
	panel.reference_changed.connect(func(settings: Dictionary) -> void:
		seen[0] = settings
	)
	await get_tree().process_frame

	panel.set_reference_settings({
		"path": "C:/tmp/fish_reference.png",
		"visible": true,
		"opacity": 0.45,
		"scale": 1.2,
		"offset_x": 16.0,
		"offset_y": -24.0
	})
	panel.set_numeric_setting("scale", 1.8)
	panel.set_numeric_setting("offset_x", -32.0)
	panel.set_reference_visible(false)

	assert(String(seen[0].get("path", "")) == "C:/tmp/fish_reference.png")
	assert(not bool(seen[0].get("visible", true)))
	assert(abs(float(seen[0].get("scale", 0.0)) - 1.8) < 0.001)
	assert(abs(float(seen[0].get("offset_x", 0.0)) + 32.0) < 0.001)

	panel.clear_reference()
	assert(String(seen[0].get("path", "")) == "")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/reference_image_panel.ok", FileAccess.WRITE)
	file.store_string("reference image panel settings emitted")
	file.close()
	print("REFERENCE_IMAGE_PANEL_TEST_OK")
	get_tree().quit(0)
