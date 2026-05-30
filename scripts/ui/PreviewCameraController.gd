class_name PreviewCameraController
extends Node

signal camera_changed(state: Dictionary)

const ROTATE_SENSITIVITY := 0.35
const PAN_SENSITIVITY := 0.0016
const ZOOM_STEP := 1.12
const MIN_PITCH := -82.0
const MAX_PITCH := 28.0
const MIN_ORTHO_SIZE := 0.6
const MAX_ORTHO_SIZE := 8.0

var camera: Camera3D
var input_control: Control
var yaw_degrees := 0.0
var pitch_degrees := -18.0
var roll_degrees := 0.0
var distance := 6.0
var orthographic_size := 2.25
var target := Vector3.ZERO
var input_enabled := true

var _drag_mode := ""

func bind_camera(new_camera: Camera3D) -> void:
	camera = new_camera
	_apply_camera()

func bind_input_control(control: Control) -> void:
	if input_control and input_control.gui_input.is_connected(_on_gui_input):
		input_control.gui_input.disconnect(_on_gui_input)
	input_control = control
	if input_control:
		input_control.gui_input.connect(_on_gui_input)

func reset_from_preset(preset: Dictionary) -> void:
	yaw_degrees = float(preset.get("yaw", 0.0))
	pitch_degrees = float(preset.get("pitch", -18.0))
	roll_degrees = float(preset.get("roll", 0.0))
	distance = float(preset.get("distance", 6.0))
	orthographic_size = float(preset.get("orthographic_size", 2.25))
	target = _variant_to_vector3(preset.get("target", Vector3.ZERO))
	_apply_camera()

func rotate_view(delta: Vector2) -> void:
	yaw_degrees -= delta.x * ROTATE_SENSITIVITY
	pitch_degrees = clampf(pitch_degrees - delta.y * ROTATE_SENSITIVITY, MIN_PITCH, MAX_PITCH)
	_apply_camera()

func zoom_steps(steps: float) -> void:
	orthographic_size = clampf(orthographic_size * pow(ZOOM_STEP, steps), MIN_ORTHO_SIZE, MAX_ORTHO_SIZE)
	_apply_camera()

func pan_view(delta: Vector2) -> void:
	if camera == null:
		return
	var basis := camera.global_transform.basis
	var scale := orthographic_size * PAN_SENSITIVITY
	target += (-basis.x * delta.x + basis.y * delta.y) * scale
	_apply_camera()

func get_camera_state() -> Dictionary:
	return {
		"yaw": yaw_degrees,
		"pitch": pitch_degrees,
		"roll": roll_degrees,
		"distance": distance,
		"orthographic_size": orthographic_size,
		"target": {"x": target.x, "y": target.y, "z": target.z}
	}

func _on_gui_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		_drag_mode = "rotate" if event.pressed else ""
		if event.pressed:
			input_control.accept_event()
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		_drag_mode = "pan" if event.pressed else ""
		if event.pressed:
			input_control.accept_event()
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_steps(-1.0)
		input_control.accept_event()
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_steps(1.0)
		input_control.accept_event()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _drag_mode == "rotate":
		rotate_view(event.relative)
		input_control.accept_event()
	elif _drag_mode == "pan":
		pan_view(event.relative)
		input_control.accept_event()

func _apply_camera() -> void:
	if camera == null:
		return
	var yaw := deg_to_rad(yaw_degrees)
	var pitch := deg_to_rad(pitch_degrees)
	var direction := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)).normalized()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = orthographic_size
	camera.position = target + direction * distance
	camera.look_at(target, Vector3.UP)
	camera.rotation_degrees.z += roll_degrees
	camera_changed.emit(get_camera_state())

func _variant_to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO
