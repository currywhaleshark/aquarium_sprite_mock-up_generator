extends Node

const MainScript := preload("res://scripts/ui/Main.gd")

func _ready() -> void:
	var main := MainScript.new()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var output_dir := ProjectSettings.globalize_path("res://exports/test_results")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image_path := output_dir.path_join("reference_camera_sync.png")
	var image := Image.create(24, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 0.2, 0.2, 0.75))
	assert(image.save_png(image_path) == OK)

	var panel: Object = main.get("reference_image_panel")
	var overlay: TextureRect = main.get("reference_overlay")
	var controller: Object = main.get("camera_controller")
	assert(panel != null)
	assert(overlay != null)
	assert(controller != null)

	panel.call("set_reference_settings", {
		"path": image_path,
		"visible": true,
		"scale": 2.0,
		"offset_x": 12.0,
		"offset_y": -8.0,
		"opacity": 0.5
	})
	await get_tree().process_frame
	assert(overlay.visible)
	var initial_size := overlay.size
	var initial_position := overlay.position

	controller.call("zoom_steps", -2.0)
	await get_tree().process_frame
	assert(overlay.size.x > initial_size.x)

	var zoomed_position := overlay.position
	controller.call("pan_view", Vector2(120.0, 0.0))
	await get_tree().process_frame
	assert(overlay.position.distance_to(zoomed_position) > 1.0)
	assert(overlay.position.distance_to(initial_position) > 1.0)

	var file := FileAccess.open("res://exports/test_results/reference_overlay_camera_sync.ok", FileAccess.WRITE)
	file.store_string("reference overlay follows camera zoom and pan")
	file.close()
	print("REFERENCE_OVERLAY_CAMERA_SYNC_TEST_OK")
	get_tree().quit(0)
