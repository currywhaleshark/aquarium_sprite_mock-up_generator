extends Node

const ScreenDragProjector := preload("res://scripts/ui/ScreenDragProjector.gd")

func _ready() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	_position_camera(camera, 0.0)
	await get_tree().process_frame

	var center := get_viewport().get_visible_rect().size * 0.5
	var plane_point := Vector3.ZERO
	var plane_normal := Vector3.BACK
	var same := ScreenDragProjector.screen_delta_on_plane(camera, center, center, plane_point, plane_normal)
	assert(same.length() < 0.0001)

	_position_camera(camera, 35.0)
	await get_tree().process_frame
	var screen_right := ScreenDragProjector.screen_delta_on_plane(camera, center, center + Vector2(80.0, 0.0), plane_point, plane_normal)
	var screen_up := ScreenDragProjector.screen_delta_on_plane(camera, center, center + Vector2(0.0, -80.0), plane_point, plane_normal)
	assert(screen_right.x > 0.0)
	assert(screen_up.y > 0.0)

	camera.size = 2.0
	await get_tree().process_frame
	var zoomed_in := ScreenDragProjector.screen_delta_on_plane(camera, center, center + Vector2(80.0, 0.0), plane_point, plane_normal).length()
	camera.size = 6.0
	await get_tree().process_frame
	var zoomed_out := ScreenDragProjector.screen_delta_on_plane(camera, center, center + Vector2(80.0, 0.0), plane_point, plane_normal).length()
	assert(zoomed_in < zoomed_out)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/screen_drag_projector.ok", FileAccess.WRITE)
	file.store_string("screen drag projector preserves direction under camera rotation and zoom")
	file.close()
	print("SCREEN_DRAG_PROJECTOR_TEST_OK")
	get_tree().quit(0)

func _position_camera(camera: Camera3D, yaw_degrees: float) -> void:
	var yaw := deg_to_rad(yaw_degrees)
	camera.position = Vector3(sin(yaw) * 6.0, 0.0, cos(yaw) * 6.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)
