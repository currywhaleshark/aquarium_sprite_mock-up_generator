class_name FishFinDragController
extends Node

signal parameters_changed(parameters: Dictionary)

const DRAG_WORLD_PER_PIXEL := 0.004
const PICK_RADIUS_PX := 28.0

var fish: FishRig
var camera: Camera3D
var camera_controller: Node
var input_control: Control
var enabled := true
var selected_handle := ""

func bind_fish(new_fish: FishRig) -> void:
	fish = new_fish
	_release()

func bind_camera(new_camera: Camera3D) -> void:
	camera = new_camera

func bind_camera_controller(controller: Node) -> void:
	camera_controller = controller

func bind_input_control(control: Control) -> void:
	if input_control and input_control.gui_input.is_connected(_on_gui_input):
		input_control.gui_input.disconnect(_on_gui_input)
	input_control = control
	if input_control:
		input_control.gui_input.connect(_on_gui_input)

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_release()

func drag_fin_by_pixels(handle_id: String, delta: Vector2) -> void:
	if fish == null:
		return
	_apply_handle_drag(handle_id, delta)
	parameters_changed.emit(fish.parameters.duplicate(true))

# Applies the drag to the live rig without emitting, so mouse motion only does
# the cheap node repositioning instead of a full rebuild + panel rebuild.
func _drag_live(handle_id: String, delta: Vector2) -> void:
	if fish == null:
		return
	_apply_handle_drag(handle_id, delta)

func _apply_handle_drag(handle_id: String, delta: Vector2) -> void:
	# Screen-right travels toward the tail (+x); screen-up raises the handle (+y).
	var delta_x := delta.x * DRAG_WORLD_PER_PIXEL
	var delta_y := -delta.y * DRAG_WORLD_PER_PIXEL
	if handle_id.begins_with("eye"):
		# Eyes move freely on the head and stay left/right symmetric by construction.
		fish.move_eye(delta_x, delta_y)
	elif handle_id == "pectoral":
		# Pectorals move freely while keeping both sides mirrored.
		fish.move_pectoral(delta_x, delta_y)
	else:
		# Median fins (dorsal/anal/pelvic) only slide fore/aft along the centerline.
		fish.move_fin_attach(handle_id, delta_x)

func _on_gui_input(event: InputEvent) -> void:
	if not enabled or fish == null:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		selected_handle = _pick_handle(event.position)
		if selected_handle != "":
			_set_camera_suppressed(true)
			input_control.accept_event()
	else:
		if selected_handle != "":
			# Commit the drag once on release so the preset and editor panels
			# only rebuild a single time instead of on every mouse motion.
			parameters_changed.emit(fish.parameters.duplicate(true))
			input_control.accept_event()
		_release()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if selected_handle != "":
		_drag_live(selected_handle, event.relative)
		input_control.accept_event()
	else:
		var hover := _pick_handle(event.position)
		if hover != "":
			input_control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			input_control.mouse_default_cursor_shape = Control.CURSOR_ARROW

func _release() -> void:
	selected_handle = ""
	_set_camera_suppressed(false)
	if input_control:
		input_control.mouse_default_cursor_shape = Control.CURSOR_ARROW

func _set_camera_suppressed(value: bool) -> void:
	if camera_controller and camera_controller.has_method("set_drag_suppressed"):
		camera_controller.call("set_drag_suppressed", value)

func _pick_handle(mouse_position: Vector2) -> String:
	if camera == null or fish == null:
		return ""
	var points: Dictionary = fish.get_drag_handles()
	var best_handle := ""
	var best_distance := PICK_RADIUS_PX
	for handle_id in points.keys():
		var screen_position := camera.unproject_position(points[handle_id])
		var distance := screen_position.distance_to(mouse_position)
		if distance < best_distance:
			best_distance = distance
			best_handle = String(handle_id)
	return best_handle
