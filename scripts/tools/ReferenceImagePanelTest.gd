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
	var preview_texture: TextureRect = panel.get("dialog_preview_texture")
	var preview_label: Label = panel.get("dialog_preview_label")
	assert(preview_texture != null)
	assert(preview_label != null)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var preview_path := "res://exports/test_results/reference_dialog_preview.png"
	var preview_image := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	preview_image.fill(Color(0.9, 0.2, 0.1, 1.0))
	assert(preview_image.save_png(preview_path) == OK)
	panel.call("_update_dialog_preview", preview_path)
	assert(preview_texture.texture != null)
	assert(String(preview_label.text).contains("32x16"))

	panel.call("_update_dialog_preview", "res://exports/test_results/not_an_image.txt")
	assert(preview_texture.texture == null)

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

	var file := FileAccess.open("res://exports/test_results/reference_image_panel.ok", FileAccess.WRITE)
	file.store_string("reference image panel settings emitted")
	file.close()
	print("REFERENCE_IMAGE_PANEL_TEST_OK")
	get_tree().quit(0)
