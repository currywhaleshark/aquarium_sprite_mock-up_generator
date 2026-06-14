class_name BodyRingDragController
extends Node

signal parameters_changed(parameters: Dictionary)
signal ring_handle_selected(ring_id: String)

const ScreenDragProjectorScript := preload("res://scripts/ui/ScreenDragProjector.gd")

const PICK_RADIUS_PX := 28.0
const CENTER_PICK_BIAS_PX := 2.0

var fish: Node
var camera: Camera3D
var camera_controller: Node
var input_control: Control
var enabled := true
var selected_ring_id := ""
var selected_part := ""
var hovered_ring_id := ""
var hovered_part := ""

var _previous_mouse_pos := Vector2.ZERO
var _accumulated_world_delta := Vector3.ZERO
var _drag_changed := false

func _ready() -> void:
	set_process(true)

func bind_fish(new_fish: Node) -> void:
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

func _process(_delta: float) -> void:
	_apply_accumulated_drag()

func _on_gui_input(event: InputEvent) -> void:
	if not enabled or fish == null:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if not enabled or fish == null or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		var picked := _pick_handle(event.position)
		selected_ring_id = String(picked.get("ring_id", ""))
		selected_part = String(picked.get("part", ""))
		if selected_ring_id != "" and selected_part != "":
			_previous_mouse_pos = event.position
			_accumulated_world_delta = Vector3.ZERO
			_drag_changed = false
			ring_handle_selected.emit(selected_ring_id)
			_set_camera_suppressed(true)
			if input_control:
				input_control.accept_event()
	else:
		if selected_ring_id != "":
			_apply_accumulated_drag()
			if _drag_changed:
				var params: Dictionary = fish.get("parameters")
				parameters_changed.emit(params.duplicate(true))
			if input_control:
				input_control.accept_event()
		_release()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not enabled or fish == null:
		return
	if selected_ring_id != "":
		var plane: Dictionary = fish.call("get_body_ring_drag_plane", selected_ring_id, selected_part)
		var world_delta: Vector3 = ScreenDragProjectorScript.screen_delta_on_plane(
			camera,
			_previous_mouse_pos,
			event.position,
			plane.get("point", Vector3.ZERO),
			plane.get("normal", Vector3.BACK)
		)
		_accumulated_world_delta += world_delta
		_previous_mouse_pos = event.position
		if input_control:
			input_control.accept_event()
	else:
		var hover := _pick_handle(event.position)
		hovered_ring_id = String(hover.get("ring_id", ""))
		hovered_part = String(hover.get("part", ""))
		if input_control:
			input_control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered_ring_id != "" else Control.CURSOR_ARROW

func _pick_handle(mouse_position: Vector2) -> Dictionary:
	if camera == null or fish == null or not fish.has_method("get_body_ring_handles"):
		return {}
	var handles: Dictionary = fish.call("get_body_ring_handles")
	var best := {}
	var best_score := PICK_RADIUS_PX
	for ring_id in handles.keys():
		var ring_handles: Dictionary = handles[ring_id]
		for part in ["top", "bottom", "center"]:
			if not ring_handles.has(part):
				continue
			var world_position: Vector3 = ring_handles[part]
			var screen_position := camera.unproject_position(world_position)
			var bias := CENTER_PICK_BIAS_PX if part == "center" else 0.0
			var score := screen_position.distance_to(mouse_position) + bias
			if score < best_score:
				best_score = score
				best = {"ring_id": String(ring_id), "part": String(part)}
	return best

func _apply_accumulated_drag() -> void:
	if selected_ring_id == "" or fish == null or _accumulated_world_delta.length_squared() <= 0.0000001:
		return
	fish.call("drag_ring_handle", selected_ring_id, selected_part, _accumulated_world_delta)
	_accumulated_world_delta = Vector3.ZERO
	_drag_changed = true

func _release() -> void:
	selected_ring_id = ""
	selected_part = ""
	hovered_ring_id = ""
	hovered_part = ""
	_accumulated_world_delta = Vector3.ZERO
	_drag_changed = false
	_set_camera_suppressed(false)
	if input_control:
		input_control.mouse_default_cursor_shape = Control.CURSOR_ARROW

func _set_camera_suppressed(value: bool) -> void:
	if camera_controller and camera_controller.has_method("set_drag_suppressed"):
		camera_controller.call("set_drag_suppressed", value)
