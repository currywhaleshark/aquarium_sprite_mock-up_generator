class_name FishFinDragController
extends Node

signal parameters_changed(parameters: Dictionary)

const DRAG_WORLD_PER_PIXEL := 0.004
const PICK_RADIUS_PX := 28.0

var fish: FishRig
var camera: Camera3D
var input_control: Control
var enabled := false
var selected_fin := ""

func bind_fish(new_fish: FishRig) -> void:
	fish = new_fish
	selected_fin = ""

func bind_camera(new_camera: Camera3D) -> void:
	camera = new_camera

func bind_input_control(control: Control) -> void:
	if input_control and input_control.gui_input.is_connected(_on_gui_input):
		input_control.gui_input.disconnect(_on_gui_input)
	input_control = control
	if input_control:
		input_control.gui_input.connect(_on_gui_input)

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		selected_fin = ""

func drag_fin_by_pixels(fin_id: String, delta: Vector2) -> void:
	if fish == null:
		return
	fish.move_fin_attach(fin_id, delta.x * DRAG_WORLD_PER_PIXEL)
	parameters_changed.emit(fish.parameters.duplicate(true))

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
		selected_fin = _pick_fin(event.position)
		if selected_fin != "":
			input_control.accept_event()
	else:
		selected_fin = ""
		input_control.accept_event()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if selected_fin == "":
		return
	drag_fin_by_pixels(selected_fin, event.relative)
	input_control.accept_event()

func _pick_fin(mouse_position: Vector2) -> String:
	if camera == null or fish == null:
		return ""
	var points: Dictionary = fish.get_fin_drag_points()
	var best_fin := ""
	var best_distance := PICK_RADIUS_PX
	for fin_id in points.keys():
		var screen_position := camera.unproject_position(points[fin_id])
		var distance := screen_position.distance_to(mouse_position)
		if distance < best_distance:
			best_distance = distance
			best_fin = String(fin_id)
	return best_fin
