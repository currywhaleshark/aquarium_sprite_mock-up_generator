class_name BodySilhouetteEditor
extends Control

signal ring_value_changed(ring_id: String, key: String, value: float)
signal ring_pick_requested(ring_id: String)
signal ring_add_requested(x: float)
signal ring_delete_requested(ring_id: String)

const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")

const PADDING := 24.0
const HANDLE_RADIUS := 6.0
const HOVER_RADIUS := 11.0
const SIDE_Y_MIN := -1.6
const SIDE_Y_MAX := 1.6
const WIDTH_Y_MIN := -1.2
const WIDTH_Y_MAX := 1.2
const CENTER_X_MARGIN := 0.005

var rings: Array = []:
	set(value):
		rings = _duplicate_rings(value)
		queue_redraw()

var selected_ring_id := "":
	set(value):
		selected_ring_id = value
		queue_redraw()

var view_mode := "side":
	set(value):
		view_mode = value
		queue_redraw()

var hovered_ring_id := ""
var hovered_handle := ""
var dragged_ring_id := ""
var dragged_handle := ""
var hovered_segment := -1
var ghost_position := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(260, 150)
	clip_contents = true
	set_process(true)

func _process(_delta: float) -> void:
	if not visible:
		return
	if dragged_ring_id != "" and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_drag()
	if dragged_ring_id == "":
		_update_hover_at(get_local_mouse_position())

func set_rings(value: Array) -> void:
	rings = value

func handle_norm_position(ring_id: String, handle: String) -> Vector2:
	var ring := _ring_by_id(ring_id)
	if ring.is_empty():
		return Vector2.ZERO
	var x := float(ring.get("x", 0.0))
	var y_offset := float(ring.get("y_offset", 0.0))
	if view_mode == "width":
		match handle:
			"top_width":
				return Vector2(x, float(ring.get("top_width", ring.get("width", 0.0))))
			"bottom_width":
				return Vector2(x, -float(ring.get("bottom_width", ring.get("width", 0.0))))
			"center":
				return Vector2(x, 0.0)
		return Vector2(x, 0.0)
	match handle:
		"top":
			return Vector2(x, y_offset + float(ring.get("upper_height", 0.0)))
		"bottom":
			return Vector2(x, y_offset - float(ring.get("lower_height", 0.0)))
		"center":
			return Vector2(x, y_offset)
	return Vector2(x, y_offset)

func apply_handle_drag(ring_id: String, handle: String, delta_norm: Vector2) -> void:
	var index := _ring_index_by_id(ring_id)
	if index < 0:
		return
	var ring: Dictionary = rings[index]
	match handle:
		"top":
			var next_upper := _clamp_ring_key("upper_height", float(ring.get("upper_height", 0.0)) + delta_norm.y)
			ring_value_changed.emit(ring_id, "upper_height", next_upper)
		"bottom":
			var next_lower := _clamp_ring_key("lower_height", float(ring.get("lower_height", 0.0)) - delta_norm.y)
			ring_value_changed.emit(ring_id, "lower_height", next_lower)
		"top_width":
			var next_top_width := _clamp_ring_key("top_width", float(ring.get("top_width", ring.get("width", 0.0))) + delta_norm.y)
			ring_value_changed.emit(ring_id, "top_width", next_top_width)
		"bottom_width":
			var next_bottom_width := _clamp_ring_key("bottom_width", float(ring.get("bottom_width", ring.get("width", 0.0))) - delta_norm.y)
			ring_value_changed.emit(ring_id, "bottom_width", next_bottom_width)
		"center":
			var next_x := _clamp_center_x(index, float(ring.get("x", 0.0)) + delta_norm.x)
			ring_value_changed.emit(ring_id, "x", next_x)
			if view_mode == "side":
				var next_y := _clamp_ring_key("y_offset", float(ring.get("y_offset", 0.0)) + delta_norm.y)
				ring_value_changed.emit(ring_id, "y_offset", next_y)

func request_select(ring_id: String) -> void:
	if ring_id == "":
		return
	ring_pick_requested.emit(ring_id)

func request_add_at(x: float) -> void:
	ring_add_requested.emit(clampf(x, 0.0, 1.0))

func request_delete(ring_id: String) -> void:
	if ring_id == "":
		return
	ring_delete_requested.emit(ring_id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_update_hover_at(button.position)
				if hovered_ring_id != "":
					request_select(hovered_ring_id)
					dragged_ring_id = hovered_ring_id
					dragged_handle = hovered_handle
				elif hovered_segment != -1:
					request_add_at(_to_norm(ghost_position).x)
			else:
				_finish_drag()
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			_update_hover_at(button.position)
			if hovered_ring_id != "":
				request_delete(hovered_ring_id)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if dragged_ring_id != "":
			apply_handle_drag(dragged_ring_id, dragged_handle, _pixel_delta_to_norm(motion.relative))
		else:
			_update_hover_at(motion.position)

func _finish_drag() -> void:
	dragged_ring_id = ""
	dragged_handle = ""
	_update_hover_at(get_local_mouse_position())
	queue_redraw()

func _duplicate_rings(value: Array) -> Array:
	var copy: Array = []
	for ring in value:
		if typeof(ring) == TYPE_DICTIONARY:
			copy.append((ring as Dictionary).duplicate(true))
	return copy

func _ring_by_id(ring_id: String) -> Dictionary:
	for ring in rings:
		if String(ring.get("id", "")) == ring_id:
			return ring
	return {}

func _ring_index_by_id(ring_id: String) -> int:
	for i in rings.size():
		if String(rings[i].get("id", "")) == ring_id:
			return i
	return -1

func _clamp_ring_key(key: String, value: float) -> float:
	var ranges: Dictionary = BodyProfileScript.RING_KEY_RANGES
	if not ranges.has(key):
		return value
	var config: Dictionary = ranges[key]
	return clampf(value, float(config.get("min", value)), float(config.get("max", value)))

func _clamp_center_x(index: int, value: float) -> float:
	var min_x := 0.0
	var max_x := 1.0
	if index > 0:
		min_x = float(rings[index - 1].get("x", 0.0)) + CENTER_X_MARGIN
	if index < rings.size() - 1:
		max_x = float(rings[index + 1].get("x", 1.0)) - CENTER_X_MARGIN
	if min_x > max_x:
		var midpoint := (min_x + max_x) * 0.5
		min_x = midpoint
		max_x = midpoint
	return clampf(value, min_x, max_x)

func _handles_for_ring(ring: Dictionary) -> Array[Dictionary]:
	var ring_id := String(ring.get("id", ""))
	return [
		{"ring_id": ring_id, "handle": _top_handle_name(), "position": handle_norm_position(ring_id, _top_handle_name())},
		{"ring_id": ring_id, "handle": "center", "position": handle_norm_position(ring_id, "center")},
		{"ring_id": ring_id, "handle": _bottom_handle_name(), "position": handle_norm_position(ring_id, _bottom_handle_name())}
	]

func _update_hover_at(mouse_pos: Vector2) -> void:
	var best_dist := HOVER_RADIUS
	hovered_ring_id = ""
	hovered_handle = ""
	hovered_segment = -1
	for ring in rings:
		for handle_info in _handles_for_ring(ring):
			var pix := _to_pixel(handle_info["position"])
			var dist := mouse_pos.distance_to(pix)
			if dist < best_dist:
				best_dist = dist
				hovered_ring_id = String(handle_info["ring_id"])
				hovered_handle = String(handle_info["handle"])
	if hovered_ring_id != "":
		queue_redraw()
		return
	var top_positions := _ordered_handle_positions(_top_handle_name())
	var bottom_positions := _ordered_handle_positions(_bottom_handle_name())
	hovered_segment = _nearest_segment(mouse_pos, top_positions)
	if hovered_segment == -1:
		hovered_segment = _nearest_segment(mouse_pos, bottom_positions)
	queue_redraw()

func _nearest_segment(mouse_pos: Vector2, positions: Array[Vector2]) -> int:
	var best_segment := -1
	var best_dist := 7.0
	for i in range(positions.size() - 1):
		var p1 := _to_pixel(positions[i])
		var p2 := _to_pixel(positions[i + 1])
		var ab := p2 - p1
		var ap := mouse_pos - p1
		var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var projection := p1 + ab * t
		var dist := mouse_pos.distance_to(projection)
		if dist < best_dist:
			best_dist = dist
			best_segment = i
			ghost_position = projection
	return best_segment

func _ordered_handle_positions(handle: String) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for ring in rings:
		positions.append(handle_norm_position(String(ring.get("id", "")), handle))
	return positions

func _top_handle_name() -> String:
	return "top_width" if view_mode == "width" else "top"

func _bottom_handle_name() -> String:
	return "bottom_width" if view_mode == "width" else "bottom"

func _y_min() -> float:
	return WIDTH_Y_MIN if view_mode == "width" else SIDE_Y_MIN

func _y_max() -> float:
	return WIDTH_Y_MAX if view_mode == "width" else SIDE_Y_MAX

func _to_pixel(norm: Vector2) -> Vector2:
	var w := maxf(size.x - PADDING * 2.0, 1.0)
	var h := maxf(size.y - PADDING * 2.0, 1.0)
	var px := PADDING + clampf(norm.x, 0.0, 1.0) * w
	var min_y := _y_min()
	var max_y := _y_max()
	var ty := (clampf(norm.y, min_y, max_y) - min_y) / (max_y - min_y)
	var py := PADDING + (1.0 - ty) * h
	return Vector2(px, py)

func _to_norm(pix: Vector2) -> Vector2:
	var w := maxf(size.x - PADDING * 2.0, 1.0)
	var h := maxf(size.y - PADDING * 2.0, 1.0)
	var nx := clampf((pix.x - PADDING) / w, 0.0, 1.0)
	var ty := 1.0 - clampf((pix.y - PADDING) / h, 0.0, 1.0)
	var ny := lerpf(_y_min(), _y_max(), ty)
	return Vector2(nx, ny)

func _pixel_delta_to_norm(delta: Vector2) -> Vector2:
	var w := maxf(size.x - PADDING * 2.0, 1.0)
	var h := maxf(size.y - PADDING * 2.0, 1.0)
	return Vector2(delta.x / w, -delta.y / h * (_y_max() - _y_min()))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.html("#16161a"), true)
	_draw_grid()
	if rings.is_empty():
		return
	_draw_polyline(_ordered_handle_positions(_top_handle_name()), Color.html("#00d5ff"), 2.0)
	_draw_polyline(_ordered_handle_positions(_bottom_handle_name()), Color.html("#00d5ff"), 2.0)
	for ring in rings:
		var ring_id := String(ring.get("id", ""))
		var center := _to_pixel(handle_norm_position(ring_id, "center"))
		var top := _to_pixel(handle_norm_position(ring_id, _top_handle_name()))
		var bottom := _to_pixel(handle_norm_position(ring_id, _bottom_handle_name()))
		draw_line(top, bottom, Color(1.0, 1.0, 1.0, 0.12), 1.0)
		for handle_info in _handles_for_ring(ring):
			_draw_handle(String(handle_info["ring_id"]), String(handle_info["handle"]), _to_pixel(handle_info["position"]))
		draw_circle(center, 1.5, Color.WHITE)
	if hovered_segment != -1 and hovered_ring_id == "":
		draw_circle(ghost_position, HANDLE_RADIUS, Color(0.15, 0.9, 0.4, 0.35))

func _draw_grid() -> void:
	var grid_color := Color(1.0, 1.0, 1.0, 0.05)
	var axis_color := Color.html("#e03131") * 0.4
	var w := maxf(size.x - PADDING * 2.0, 1.0)
	var h := maxf(size.y - PADDING * 2.0, 1.0)
	for i in range(5):
		var t := float(i) / 4.0
		var x_pos := PADDING + t * w
		var y_pos := PADDING + t * h
		draw_line(Vector2(x_pos, PADDING), Vector2(x_pos, PADDING + h), grid_color, 1.0)
		draw_line(Vector2(PADDING, y_pos), Vector2(PADDING + w, y_pos), grid_color, 1.0)
	var center_y := _to_pixel(Vector2(0.0, 0.0)).y
	draw_line(Vector2(PADDING, center_y), Vector2(PADDING + w, center_y), axis_color, 2.0)

func _draw_polyline(positions: Array[Vector2], color: Color, width: float) -> void:
	for i in range(positions.size() - 1):
		draw_line(_to_pixel(positions[i]), _to_pixel(positions[i + 1]), color, width)

func _draw_handle(ring_id: String, handle: String, position: Vector2) -> void:
	var is_selected := ring_id == selected_ring_id
	var is_hovered := ring_id == hovered_ring_id and handle == hovered_handle
	var is_dragged := ring_id == dragged_ring_id and handle == dragged_handle
	var outer := Color(0.0, 0.95, 1.0, 0.22)
	var inner := Color.html("#00f2fe")
	if is_selected:
		outer = Color(1.0, 0.65, 0.1, 0.35)
		inner = Color.html("#ffb703")
	if is_dragged:
		outer = Color(1.0, 0.45, 0.0, 0.42)
		inner = Color.html("#ff922b")
	elif is_hovered:
		outer = Color(0.15, 0.9, 0.4, 0.33)
		inner = Color.html("#37b24d")
	draw_circle(position, HANDLE_RADIUS + 2.0, outer)
	draw_circle(position, HANDLE_RADIUS - 2.0, inner)
