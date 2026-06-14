extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const FinDragControllerScript := preload("res://scripts/ui/FishFinDragController.gd")
const DragHandlesOverlayScript := preload("res://scripts/ui/DragHandlesOverlay.gd")

class StubCameraController extends Node:
	var suppressed := false
	func set_drag_suppressed(value: bool) -> void:
		suppressed = value

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"shell_enabled": 1.0,
		"eye_size": 0.06,
		"eye_position_x": -0.7,
		"eye_position_y": 0.1,
		"eye_bulge": 0.0,
		"pectoral_attach_t": 0.32,
		"anal_attach_t": 0.64,
		"dorsal_1_shape": "custom",
		"dorsal_1_custom_points": [-0.5, 0.0, 0.0, 0.7, 0.5, 0.0],
		"head_bump_height": 0.3,
		"gill_mark": "operculum",
		"operculum_custom_points": [0.0, -0.5, 0.0, 0.5, 1.0, 0.0]
	})
	await get_tree().process_frame

	# Eyes and fins are all exposed as draggable handles.
	var handles := fish.get_drag_handles()
	assert(handles.has("eye_l"))
	assert(handles.has("eye_r"))
	assert(handles.has("pectoral"))
	assert(handles.has("anal"))
	assert(handles.has("operculum"))
	assert(handles.has("jaw_hinge"))
	assert(handles.has("head_bump"))
	var dorsal_marker: Vector3 = fish.get_vector_edit_marker_world("dorsal_1", Vector2(0.0, 0.7))
	assert(not is_inf(dorsal_marker.x))
	var operculum_marker: Vector3 = fish.get_vector_edit_marker_world("operculum", Vector2(1.0, 0.0))
	assert(not is_inf(operculum_marker.x))
	assert(operculum_marker.z > 0.0)

	var overlay: DragHandlesOverlay = DragHandlesOverlayScript.new()
	add_child(overlay)
	overlay.draw_head = true
	overlay.draw_fins = false
	assert(overlay._should_draw_handle("operculum"))
	assert(overlay._should_draw_handle("jaw_hinge"))
	assert(overlay._should_draw_handle("head_bump"))
	overlay.draw_head = false
	overlay.draw_fins = true
	assert(not overlay._should_draw_handle("operculum"))
	assert(not overlay._should_draw_handle("jaw_hinge"))
	assert(not overlay._should_draw_handle("head_bump"))

	var controller: FishFinDragController = FinDragControllerScript.new()
	add_child(controller)
	controller.bind_fish(fish)
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(0.0, 0.0, 6.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	controller.bind_camera(camera)
	await get_tree().process_frame
	var jaw_screen := camera.unproject_position(handles["jaw_hinge"])
	controller.allowed_handle_filter = func(handle_id: String) -> bool:
		return false
	assert(controller._pick_handle(jaw_screen) == "")
	controller.allowed_handle_filter = func(handle_id: String) -> bool:
		return handle_id.begins_with("eye") or handle_id == "operculum" or handle_id == "jaw_hinge" or handle_id == "head_bump"
	assert(controller._pick_handle(jaw_screen) == "jaw_hinge")

	# Operculum drag is free in 2D and moves the whole gill cover while preserving the
	# separate outline editor points.
	var op_x0 := float(fish.parameters.get("operculum_position_x", 0.0))
	var op_y0 := float(fish.parameters.get("operculum_position_y", 0.0))
	var op_marker0: Vector3 = fish.get_vector_edit_marker_world("operculum", Vector2(0.5, 0.0))
	controller.drag_fin_by_pixels("operculum", Vector2(30.0, -25.0))
	var op_marker1: Vector3 = fish.get_vector_edit_marker_world("operculum", Vector2(0.5, 0.0))
	assert(float(fish.parameters.get("operculum_position_x", 0.0)) > op_x0)
	assert(float(fish.parameters.get("operculum_position_y", 0.0)) > op_y0)
	assert(op_marker1.x > op_marker0.x + 0.01)
	assert(op_marker1.y > op_marker0.y + 0.01)

	# Eye drag is free in 2D: screen-right -> +x, screen-up -> +y.
	var eye_x0 := float(fish.parameters.get("eye_position_x"))
	var eye_y0 := float(fish.parameters.get("eye_position_y"))
	controller.drag_fin_by_pixels("eye_r", Vector2(40.0, -30.0))
	assert(float(fish.parameters.get("eye_position_x")) > eye_x0)
	assert(float(fish.parameters.get("eye_position_y")) > eye_y0)

	# Pectoral drag is free in 2D and keeps both sides mirrored.
	var pec_t0 := float(fish.parameters.get("pectoral_attach_t"))
	controller.drag_fin_by_pixels("pectoral", Vector2(30.0, -20.0))
	assert(float(fish.parameters.get("pectoral_attach_t")) > pec_t0)
	assert(float(fish.parameters.get("pectoral_offset_y", 0.0)) > 0.0)
	var pec_l := fish.get_node("BodyPivot/PectoralFinL") as MeshInstance3D
	var pec_r := fish.get_node("BodyPivot/PectoralFinR") as MeshInstance3D
	assert(abs(pec_l.position.z + pec_r.position.z) < 0.001)
	assert(abs(pec_l.position.y - pec_r.position.y) < 0.001)

	# Median fins only slide fore/aft: vertical input is ignored.
	var anal_t0 := float(fish.parameters.get("anal_attach_t"))
	controller.drag_fin_by_pixels("anal", Vector2(0.0, -50.0))
	assert(abs(float(fish.parameters.get("anal_attach_t")) - anal_t0) < 0.0001)
	controller.drag_fin_by_pixels("anal", Vector2(25.0, 0.0))
	assert(float(fish.parameters.get("anal_attach_t")) > anal_t0)

	# Grabbing a handle suppresses camera orbit; releasing restores it.
	var stub := StubCameraController.new()
	add_child(stub)
	controller.bind_camera_controller(stub)
	controller._set_camera_suppressed(true)
	assert(stub.suppressed)
	controller._set_camera_suppressed(false)
	assert(not stub.suppressed)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/drag_handles.ok", FileAccess.WRITE)
	file.store_string("eye and fin drag handles applied")
	file.close()
	print("DRAG_HANDLES_TEST_OK")
	get_tree().quit(0)
