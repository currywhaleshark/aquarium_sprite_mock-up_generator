extends Node

const HeadEditorPanelScript := preload("res://scripts/ui/HeadEditorPanel.gd")
const FinEditorPanelScript := preload("res://scripts/ui/FinEditorPanel.gd")
const FishFinDragControllerScript := preload("res://scripts/ui/FishFinDragController.gd")
const FishRigScript := preload("res://scripts/creature/FishRig.gd")

var _failed := false

func _ready() -> void:
	await _test_head_focus_key()
	await _test_fin_select_slot()
	await _test_handle_click_signal()
	if _failed:
		get_tree().quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/pick_to_edit.ok", FileAccess.WRITE)
	file.store_string("preview clicks focus editor sections")
	file.close()
	print("PICK_TO_EDIT_TEST_OK")
	get_tree().quit(0)

func _test_head_focus_key() -> void:
	var panel := HeadEditorPanelScript.new()
	add_child(panel)
	panel.set_parameters({
		"head_shape": "rounded",
		"mouth_type": "terminal",
		"gill_mark": "none",
		"head_bump_height": 0.3
	})
	await get_tree().process_frame
	var mouth_header: Button = panel.get("section_headers")["입"]
	mouth_header.button_pressed = false
	await get_tree().process_frame
	if not _require(panel.has_method("focus_key"), "HeadEditorPanel should expose focus_key"):
		panel.queue_free()
		return
	var row: Control = panel.focus_key("jaw_hinge_x")
	_require(row != null, "focus_key should return the numeric row")
	_require(bool(panel.get("section_expanded")["입"]), "focus_key should expand the mouth section")
	_require(row == panel.get("numeric_sliders")["jaw_hinge_x"]["row"], "focus_key should return the exact slider row")
	_require(panel.focus_key("operculum_position_x") == null, "focus_key should return null for hidden keys")
	panel.queue_free()

func _test_fin_select_slot() -> void:
	var panel := FinEditorPanelScript.new()
	add_child(panel)
	panel.set_parameters({
		"pectoral_attach_t": 0.32,
		"pectoral_shape": "oval"
	})
	await get_tree().process_frame
	if not _require(panel.has_method("select_slot"), "FinEditorPanel should expose select_slot"):
		panel.queue_free()
		return
	panel.select_slot("pectoral")
	_require(String(panel.get("selected_slot")) == "pectoral", "select_slot should update selected_slot")
	var slot_option := panel.get("slot_option") as OptionButton
	_require(String(slot_option.get_item_metadata(slot_option.selected)) == "pectoral", "select_slot should sync slot option")
	_require(panel.get("numeric_sliders").has("pectoral_fin_size"), "select_slot should rebuild pectoral controls")
	panel.queue_free()

func _test_handle_click_signal() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"shell_enabled": 1.0,
		"head_bump_height": 0.3
	})
	await get_tree().process_frame
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(0.0, 0.0, 6.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	var input := Control.new()
	input.size = Vector2(512, 512)
	add_child(input)
	var controller: FishFinDragController = FishFinDragControllerScript.new()
	add_child(controller)
	controller.bind_fish(fish)
	controller.bind_camera(camera)
	controller.bind_input_control(input)
	controller.allowed_handle_filter = func(handle_id: String) -> bool:
		return handle_id == "jaw_hinge"
	await get_tree().process_frame
	var clicked := [""]
	if not _require(controller.has_signal("handle_clicked"), "FishFinDragController should expose handle_clicked"):
		controller.queue_free()
		input.queue_free()
		camera.queue_free()
		fish.queue_free()
		return
	controller.handle_clicked.connect(func(handle_id: String) -> void:
		clicked[0] = handle_id
	)
	var pos := camera.unproject_position(fish.get_drag_handles()["jaw_hinge"])
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	controller._handle_mouse_button(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = pos + Vector2(2.0, 1.0)
	controller._handle_mouse_button(release)
	_require(clicked[0] == "jaw_hinge", "small press-release should emit handle_clicked for jaw_hinge")
	controller.queue_free()
	input.queue_free()
	camera.queue_free()
	fish.queue_free()

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failed = true
	push_error(message)
	return false
