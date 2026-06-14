extends Node

const HeadEditorPanelScript := preload("res://scripts/ui/HeadEditorPanel.gd")
const FinVectorEditorScript := preload("res://scripts/ui/FinVectorEditor.gd")
const BodyRingDragControllerScript := preload("res://scripts/ui/BodyRingDragController.gd")
const FishFinDragControllerScript := preload("res://scripts/ui/FishFinDragController.gd")

var _failed := false

class StubCameraController extends Node:
	var suppressed := false
	func set_drag_suppressed(value: bool) -> void:
		suppressed = value

class StubBodyRingFish extends Node3D:
	var parameters := {"body_profile": {"rings": [{"id": "mid_body"}]}}
	var drag_calls := 0
	var last_delta := Vector3.ZERO

	func get_body_ring_handles() -> Dictionary:
		return {
			"mid_body": {
				"center": global_transform * Vector3.ZERO,
				"top": global_transform * Vector3(0.0, 0.3, 0.0),
				"bottom": global_transform * Vector3(0.0, -0.3, 0.0)
			}
		}

	func get_body_ring_drag_plane(ring_id: String, part: String) -> Dictionary:
		var handles := get_body_ring_handles()
		return {
			"point": handles[ring_id][part],
			"normal": Vector3.BACK
		}

	func drag_ring_handle(_ring_id: String, _part: String, world_delta: Vector3) -> void:
		drag_calls += 1
		last_delta += world_delta

class StubHeadHandleFish extends FishRig:
	var jaw_calls := 0
	var bump_calls := 0
	var jaw_delta := Vector3.ZERO
	var bump_delta := Vector3.ZERO

	func get_drag_handles() -> Dictionary:
		return {
			"jaw_hinge": global_transform * Vector3.ZERO,
			"head_bump": global_transform * Vector3(0.0, 0.25, 0.0)
		}

	func get_head_drag_plane(handle_id: String) -> Dictionary:
		return {
			"point": get_drag_handles()[handle_id],
			"normal": Vector3.BACK
		}

	func move_jaw_hinge(world_delta: Vector3) -> void:
		jaw_calls += 1
		jaw_delta += world_delta
		parameters["jaw_hinge_x"] = float(parameters.get("jaw_hinge_x", 0.0)) + world_delta.x
		parameters["jaw_hinge_y"] = float(parameters.get("jaw_hinge_y", 0.0)) + world_delta.y

	func move_head_bump(world_delta: Vector3) -> void:
		bump_calls += 1
		bump_delta += world_delta
		parameters["head_bump_pos"] = float(parameters.get("head_bump_pos", 0.0)) + world_delta.x
		parameters["head_bump_height"] = float(parameters.get("head_bump_height", 0.0)) + world_delta.y

func _ready() -> void:
	await _test_head_slider_emits_during_drag()
	_test_vector_editor_emits_during_drag()
	await _test_vector_editor_recovers_preview_marker_after_missed_release()
	_test_vector_editor_emits_single_preview_marker()
	await _test_head_handle_ignores_motion_inside_click_threshold()
	await _test_head_handle_controller_throttles_live_drag()
	await _test_body_ring_controller_throttles_live_drag()
	await _test_body_ring_click_only_does_not_emit_parameters()
	if _failed:
		get_tree().quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/editor_drag_emission.ok", FileAccess.WRITE)
	file.store_string("editor drag emissions stay realtime")
	file.close()
	print("EDITOR_DRAG_EMISSION_TEST_OK")
	get_tree().quit(0)

func _test_head_slider_emits_during_drag() -> void:
	var panel := HeadEditorPanelScript.new()
	add_child(panel)
	panel.set_parameters({"creature_type": "fish", "head_size": 0.4})
	await get_tree().process_frame
	var seen := [0]
	var last_size := [0.0]
	panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		seen[0] += 1
		last_size[0] = float(parameters.get("head_size", 0.0))
	)
	var slider := _find_head_slider(panel, "head_size")
	_require(slider != null, "head_size slider exists")
	slider.value = 0.48
	slider.value = 0.62
	_require(seen[0] == 2, "head slider should emit during drag; seen=%d value=%.3f slider=%.3f" % [seen[0], last_size[0], slider.value])
	_require(absf(last_size[0] - 0.62) < 0.001, "head slider realtime emit carries final value; seen=%d value=%.3f slider=%.3f" % [seen[0], last_size[0], slider.value])
	panel.queue_free()

func _test_vector_editor_emits_during_drag() -> void:
	var editor := FinVectorEditorScript.new()
	add_child(editor)
	editor.slot = "operculum"
	editor.points = [0.0, -0.5, 0.0, 0.5, 1.0, 0.0]
	editor.dragged_index = 1
	var seen := [0]
	editor.points_changed.connect(func(_points: Array) -> void:
		seen[0] += 1
	)
	var motion := InputEventMouseMotion.new()
	editor.call("_gui_input", motion)
	_require(seen[0] == 1, "vector editor should emit during drag for realtime preview; seen=%d dragged=%d" % [seen[0], int(editor.get("dragged_index"))])
	editor.queue_free()

func _test_vector_editor_recovers_preview_marker_after_missed_release() -> void:
	var editor := FinVectorEditorScript.new()
	add_child(editor)
	editor.slot = "operculum"
	editor.size = Vector2(240, 180)
	editor.points = [0.0, -0.5, 0.0, 0.5, 1.0, 0.0]
	await get_tree().process_frame
	editor.dragged_index = 1
	editor.call("_process", 0.016)
	_require(int(editor.get("dragged_index")) == -1, "vector editor should clear a stuck drag when the mouse button is no longer pressed")
	editor.call("_update_mouse_over_states_at", Vector2(120, 74))
	_require(int(editor.get("hovered_segment")) != -1, "vector editor should restore insert preview marker after stuck drag clears")
	editor.queue_free()

func _test_vector_editor_emits_single_preview_marker() -> void:
	var editor := FinVectorEditorScript.new()
	add_child(editor)
	editor.slot = "operculum"
	editor.size = Vector2(240, 180)
	editor.points = [0.0, -0.5, 0.0, 0.5, 1.0, 0.0]
	_require(editor.has_signal("preview_marker_changed"), "vector editor should expose preview_marker_changed signal")
	if not editor.has_signal("preview_marker_changed"):
		editor.queue_free()
		return
	var seen := []
	editor.preview_marker_changed.connect(func(active: bool, norm_position: Vector2, ghost: bool) -> void:
		seen.append({"active": active, "norm": norm_position, "ghost": ghost})
	)
	editor.call("_update_mouse_over_states_at", Vector2(24, 114))
	_require(seen.size() == 1, "vector editor should emit one hovered point marker")
	_require(bool(seen[-1].get("active", false)), "hovered point marker should be active")
	_require(not bool(seen[-1].get("ghost", true)), "hovered point marker should not be ghost")
	editor.call("_update_mouse_over_states_at", Vector2(120, 74))
	_require(seen.size() == 2, "vector editor should emit one ghost marker")
	_require(bool(seen[-1].get("active", false)), "ghost marker should be active")
	_require(bool(seen[-1].get("ghost", false)), "ghost marker should be marked ghost")
	editor.call("_update_mouse_over_states_at", Vector2(220, 170))
	_require(seen.size() == 3, "vector editor should emit clear marker when hover leaves")
	_require(not bool(seen[-1].get("active", true)), "marker should clear when hover leaves")
	editor.queue_free()

func _test_head_handle_ignores_motion_inside_click_threshold() -> void:
	var setup := await _make_head_drag_setup()
	var fish := setup["fish"] as StubHeadHandleFish
	var controller = setup["controller"]
	var camera := setup["camera"] as Camera3D
	var clicked := [""]
	var emitted := [0]
	controller.handle_clicked.connect(func(handle_id: String) -> void:
		clicked[0] = handle_id
	)
	controller.parameters_changed.connect(func(_parameters: Dictionary) -> void:
		emitted[0] += 1
	)
	var start_pos := camera.unproject_position(fish.get_drag_handles()["jaw_hinge"])
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start_pos
	controller._handle_mouse_button(press)

	var motion := InputEventMouseMotion.new()
	motion.position = start_pos + Vector2(2.0, 1.0)
	motion.relative = Vector2(2.0, 1.0)
	controller._handle_mouse_motion(motion)
	_require(fish.jaw_calls == 0, "small pre-click motion should not mutate jaw hinge; calls=%d" % fish.jaw_calls)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	controller._handle_mouse_button(release)
	_require(clicked[0] == "jaw_hinge", "small motion release should still be a click")
	_require(emitted[0] == 0, "small click should not commit parameters; emitted=%d" % emitted[0])
	_free_head_drag_setup(setup)

func _test_head_handle_controller_throttles_live_drag() -> void:
	var setup := await _make_head_drag_setup()
	var fish := setup["fish"] as StubHeadHandleFish
	var controller = setup["controller"]
	var camera := setup["camera"] as Camera3D
	var camera_controller := setup["camera_controller"] as StubCameraController
	var emitted := [0]
	controller.parameters_changed.connect(func(_parameters: Dictionary) -> void:
		emitted[0] += 1
	)
	var start_pos := camera.unproject_position(fish.get_drag_handles()["jaw_hinge"])
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start_pos
	controller._handle_mouse_button(press)
	_require(camera_controller.suppressed, "head handle drag should suppress camera after handle press")

	for i in 5:
		var motion := InputEventMouseMotion.new()
		motion.position = start_pos + Vector2(10.0 * float(i + 1), -2.0)
		motion.relative = Vector2(10.0, -2.0)
		controller._handle_mouse_motion(motion)
	_require(fish.jaw_calls == 0, "head handle drag should defer rebuild-heavy mutation until _process; calls=%d" % fish.jaw_calls)
	_require(emitted[0] == 0, "head handle drag should not emit during motion; emitted=%d" % emitted[0])

	controller._process(0.016)
	_require(fish.jaw_calls == 1, "head handle drag should apply once per process frame; calls=%d" % fish.jaw_calls)
	_require(fish.jaw_delta.length() > 0.0, "head handle drag should accumulate nonzero world delta")

	for i in 3:
		var motion2 := InputEventMouseMotion.new()
		motion2.position = start_pos + Vector2(70.0 + 8.0 * float(i), -5.0)
		motion2.relative = Vector2(8.0, -1.0)
		controller._handle_mouse_motion(motion2)
	controller._process(0.016)
	_require(fish.jaw_calls == 2, "head handle drag should coalesce more motion into one more process call; calls=%d" % fish.jaw_calls)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = start_pos + Vector2(100.0, -5.0)
	controller._handle_mouse_button(release)
	_require(emitted[0] == 1, "head handle drag should emit once on release; emitted=%d" % emitted[0])
	_require(not camera_controller.suppressed, "head handle drag should release camera suppression")
	_free_head_drag_setup(setup)

func _test_body_ring_controller_throttles_live_drag() -> void:
	var fish := StubBodyRingFish.new()
	add_child(fish)
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(0.0, 0.0, 6.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	var input := Control.new()
	input.size = Vector2(512, 512)
	add_child(input)
	var camera_controller := StubCameraController.new()
	add_child(camera_controller)
	var controller = BodyRingDragControllerScript.new()
	add_child(controller)
	controller.bind_fish(fish)
	controller.bind_camera(camera)
	controller.bind_camera_controller(camera_controller)
	controller.bind_input_control(input)
	await get_tree().process_frame

	var emitted := [0]
	controller.parameters_changed.connect(func(_parameters: Dictionary) -> void:
		emitted[0] += 1
	)
	var start_pos := camera.unproject_position(fish.get_body_ring_handles()["mid_body"]["top"])
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start_pos
	controller._handle_mouse_button(press)
	_require(camera_controller.suppressed, "body ring drag should suppress camera after handle press")

	for i in 5:
		var motion := InputEventMouseMotion.new()
		motion.position = start_pos + Vector2(12.0 * float(i + 1), -4.0)
		controller._handle_mouse_motion(motion)
	_require(emitted[0] == 0, "body ring drag should not emit during motion; emitted=%d" % emitted[0])
	_require(fish.drag_calls == 0, "body ring drag should defer rig mutation until _process; calls=%d" % fish.drag_calls)

	controller._process(0.016)
	_require(fish.drag_calls == 1, "body ring drag should apply once per process frame; calls=%d" % fish.drag_calls)
	_require(fish.last_delta.length() > 0.0, "body ring drag should accumulate nonzero world delta")

	for i in 3:
		var motion2 := InputEventMouseMotion.new()
		motion2.position = start_pos + Vector2(90.0 + 8.0 * float(i), -8.0)
		controller._handle_mouse_motion(motion2)
	controller._process(0.016)
	_require(fish.drag_calls == 2, "body ring drag should coalesce more motion into one more process call; calls=%d" % fish.drag_calls)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = start_pos + Vector2(120.0, -8.0)
	controller._handle_mouse_button(release)
	_require(emitted[0] == 1, "body ring drag should emit once on release; emitted=%d" % emitted[0])
	_require(not camera_controller.suppressed, "body ring drag should release camera suppression")
	controller.queue_free()
	camera_controller.queue_free()
	input.queue_free()
	camera.queue_free()
	fish.queue_free()

func _test_body_ring_click_only_does_not_emit_parameters() -> void:
	var fish := StubBodyRingFish.new()
	add_child(fish)
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(0.0, 0.0, 6.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	var input := Control.new()
	input.size = Vector2(512, 512)
	add_child(input)
	var controller = BodyRingDragControllerScript.new()
	add_child(controller)
	controller.bind_fish(fish)
	controller.bind_camera(camera)
	controller.bind_input_control(input)
	await get_tree().process_frame

	var selected := [0]
	var emitted := [0]
	controller.ring_handle_selected.connect(func(_ring_id: String) -> void:
		selected[0] += 1
	)
	controller.parameters_changed.connect(func(_parameters: Dictionary) -> void:
		emitted[0] += 1
	)
	var start_pos := camera.unproject_position(fish.get_body_ring_handles()["mid_body"]["top"])
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start_pos
	controller._handle_mouse_button(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = start_pos
	controller._handle_mouse_button(release)
	_require(selected[0] == 1, "body ring click should still select ring once; selected=%d" % selected[0])
	_require(emitted[0] == 0, "body ring click without motion should not emit parameters; emitted=%d" % emitted[0])
	controller.queue_free()
	input.queue_free()
	camera.queue_free()
	fish.queue_free()

func _make_head_drag_setup() -> Dictionary:
	var fish := StubHeadHandleFish.new()
	add_child(fish)
	fish.parameters = {}
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(0.0, 0.0, 6.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	var input := Control.new()
	input.size = Vector2(512, 512)
	add_child(input)
	var camera_controller := StubCameraController.new()
	add_child(camera_controller)
	var controller = FishFinDragControllerScript.new()
	add_child(controller)
	controller.bind_fish(fish)
	controller.bind_camera(camera)
	controller.bind_camera_controller(camera_controller)
	controller.bind_input_control(input)
	controller.allowed_handle_filter = func(handle_id: String) -> bool:
		return handle_id == "jaw_hinge"
	await get_tree().process_frame
	return {
		"fish": fish,
		"camera": camera,
		"input": input,
		"camera_controller": camera_controller,
		"controller": controller
	}

func _free_head_drag_setup(setup: Dictionary) -> void:
	(setup["controller"] as Node).queue_free()
	(setup["camera_controller"] as Node).queue_free()
	(setup["input"] as Node).queue_free()
	(setup["camera"] as Node).queue_free()
	(setup["fish"] as Node).queue_free()

func _find_head_slider(panel: Node, key: String) -> HSlider:
	var numeric_sliders: Dictionary = panel.get("numeric_sliders")
	if not numeric_sliders.has(key):
		return null
	var widgets: Dictionary = numeric_sliders[key]
	return widgets.get("slider") as HSlider

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
