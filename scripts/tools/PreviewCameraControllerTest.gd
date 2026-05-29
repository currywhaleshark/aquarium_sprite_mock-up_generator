extends Node

const ControllerScript := preload("res://scripts/ui/PreviewCameraController.gd")

func _ready() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	var controller := ControllerScript.new()
	add_child(controller)
	controller.bind_camera(camera)
	controller.reset_from_preset({"yaw": 0.0, "pitch": -18.0, "roll": 0.0, "distance": 6.0, "orthographic_size": 2.25})

	controller.rotate_view(Vector2(100.0, -50.0))
	assert(abs(controller.yaw_degrees - -35.0) < 0.001)
	assert(abs(controller.pitch_degrees - -0.5) < 0.001)

	controller.zoom_steps(-2.0)
	assert(camera.size < 2.25)

	controller.pan_view(Vector2(20.0, 10.0))
	assert(controller.target.length() > 0.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/preview_camera_controller.ok", FileAccess.WRITE)
	file.store_string(JSON.stringify(controller.get_camera_state()))
	file.close()
	print("PREVIEW_CAMERA_CONTROLLER_TEST_OK")
	get_tree().quit(0)
