extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const FinDragControllerScript := preload("res://scripts/ui/FishFinDragController.gd")

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
		"anal_attach_t": 0.64
	})
	await get_tree().process_frame

	# Eyes and fins are all exposed as draggable handles.
	var handles := fish.get_drag_handles()
	assert(handles.has("eye_l"))
	assert(handles.has("eye_r"))
	assert(handles.has("pectoral"))
	assert(handles.has("anal"))

	var controller: FishFinDragController = FinDragControllerScript.new()
	add_child(controller)
	controller.bind_fish(fish)

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
