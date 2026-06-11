class_name DragHandlesOverlay
extends Control

const UiText := preload("res://scripts/ui/UiText.gd")

const PICK_RADIUS_PX := 28.0

var camera: Camera3D
var fish: FishRig
var fin_drag_controller: Node

var draw_fins := false
var draw_head := false
# Set by Main while a numeric editor slider is being adjusted. The fish resolves
# the key to a world-space point and the overlay draws a temporary crosshair there.
var indicator_key := ""
var vector_edit_slot := ""
var vector_edit_marker_active := false
var vector_edit_marker_norm := Vector2.ZERO
var vector_edit_marker_ghost := false

var hovered_handle := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Use process to trigger redraws so we animate smoothly with the fish
	set_process(true)

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_hovered_handle()
	queue_redraw()

func _update_hovered_handle() -> void:
	hovered_handle = ""
	if camera == null or fish == null or not (draw_fins or draw_head or vector_edit_marker_active):
		return
		
	var mouse_pos := get_local_mouse_position()
	var points := fish.get_drag_handles()
	var best_distance := PICK_RADIUS_PX
	
	# Determine scale factor between viewport size and container size
	var scale_factor := Vector2.ONE
	if camera.get_viewport():
		var vp_size: Vector2 = Vector2(camera.get_viewport().size)
		if vp_size.x > 0 and vp_size.y > 0:
			scale_factor = size / vp_size
			
	for handle_id in points.keys():
		if not _should_draw_handle(handle_id):
			continue
		var world_pos: Vector3 = points[handle_id]
		var screen_pos := camera.unproject_position(world_pos) * scale_factor
		var distance := screen_pos.distance_to(mouse_pos)
		if distance < best_distance:
			best_distance = distance
			hovered_handle = String(handle_id)

func _should_draw_handle(handle_id: String) -> bool:
	if handle_id.begins_with("eye") or handle_id == "operculum":
		return draw_head
	else:
		return draw_fins

func _draw() -> void:
	if camera == null or fish == null or not (draw_fins or draw_head or vector_edit_marker_active or indicator_key != ""):
		return
		
	var font := get_theme_font("font")
	var font_size := 12
	
	var points := fish.get_drag_handles()
	var scale_factor := Vector2.ONE
	if camera.get_viewport():
		var vp_size: Vector2 = Vector2(camera.get_viewport().size)
		if vp_size.x > 0 and vp_size.y > 0:
			scale_factor = size / vp_size
			
	var selected_handle: String = String(fin_drag_controller.get("selected_handle") if fin_drag_controller else "")
	
	for handle_id in points.keys():
		if not _should_draw_handle(handle_id):
			continue
			
		var world_pos: Vector3 = points[handle_id]
		var screen_pos := camera.unproject_position(world_pos) * scale_factor
		
		# Determine colors and sizes
		var is_hovered: bool = (handle_id == hovered_handle)
		var is_selected: bool = (handle_id == selected_handle)
		
		var outer_radius := 11.0
		var inner_radius := 5.0
		var main_color := Color(0.1, 0.75, 1.0, 0.8) # Neon Cyan
		var outer_color := Color(0.1, 0.75, 1.0, 0.25)
		
		if is_selected:
			main_color = Color(1.0, 0.45, 0.0, 0.95) # Neon Orange
			outer_color = Color(1.0, 0.45, 0.0, 0.35)
			outer_radius = 13.0
			inner_radius = 6.0
		elif is_hovered:
			main_color = Color(0.15, 0.9, 0.4, 0.9) # Neon Green
			outer_color = Color(0.15, 0.9, 0.4, 0.3)
			outer_radius = 12.0
			inner_radius = 5.5
			
		# Draw outer glow circle
		draw_circle(screen_pos, outer_radius, outer_color)
		# Draw inner solid circle
		draw_circle(screen_pos, inner_radius, main_color)
		# Draw white center dot
		draw_circle(screen_pos, 2.0, Color.WHITE)
		# Draw outer ring border
		draw_arc(screen_pos, outer_radius, 0.0, TAU, 16, Color(1, 1, 1, 0.5 if is_hovered or is_selected else 0.2), 1.0)
		
		# Tooltip text when hovered or selected
		if is_hovered or is_selected:
			var label_text := _get_handle_label(handle_id)
			var text_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var text_pos := screen_pos + Vector2(15, 4)
			
			# Draw background capsule for text readability
			var rect := Rect2(text_pos - Vector2(6, 16), text_size + Vector2(12, 6))
			draw_rect(rect, Color(0, 0, 0, 0.7), true, 4.0)
			draw_rect(rect, main_color, false, 1.0, 4.0)
			
			# Draw text
			draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	if vector_edit_marker_active and vector_edit_slot != "" and fish.has_method("get_vector_edit_marker_world"):
		var world_pos: Vector3 = fish.call("get_vector_edit_marker_world", vector_edit_slot, vector_edit_marker_norm)
		if not is_inf(world_pos.x):
			var screen_pos := camera.unproject_position(world_pos) * scale_factor
			var marker_color := Color(0.15, 0.9, 0.4, 0.95) if vector_edit_marker_ghost else Color(0.72, 0.35, 1.0, 0.95)
			draw_circle(screen_pos, 8.0, Color(marker_color.r, marker_color.g, marker_color.b, 0.22))
			draw_arc(screen_pos, 8.0, 0.0, TAU, 18, marker_color, 1.5)
			draw_circle(screen_pos, 3.0, marker_color)
			draw_circle(screen_pos, 1.2, Color.WHITE)

	if indicator_key != "" and fish.has_method("get_indicator_world"):
		var indicator_world: Vector3 = fish.call("get_indicator_world", indicator_key)
		if not is_inf(indicator_world.x):
			var hp := camera.unproject_position(indicator_world) * scale_factor
			var amber := Color(1.0, 0.7, 0.1, 0.95)
			draw_circle(hp, 9.0, Color(1.0, 0.7, 0.1, 0.22))
			draw_arc(hp, 9.0, 0.0, TAU, 20, amber, 2.0)
			draw_line(hp - Vector2(13, 0), hp + Vector2(13, 0), amber, 1.5)
			draw_line(hp - Vector2(0, 13), hp + Vector2(0, 13), amber, 1.5)
			var label := _indicator_label(indicator_key)
			var lsize: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var lpos := hp + Vector2(16, 4)
			var lrect := Rect2(lpos - Vector2(6, 16), lsize + Vector2(12, 6))
			draw_rect(lrect, Color(0, 0, 0, 0.7), true, 4.0)
			draw_rect(lrect, amber, false, 1.0, 4.0)
			draw_string(font, lpos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _indicator_label(key: String) -> String:
	if key == "x" \
		or key == "y_offset" \
		or key == "upper_height" \
		or key == "lower_height" \
		or key == "width" \
		or key == "top_width" \
		or key == "bottom_width" \
		or key == "top_flatness" \
		or key == "bottom_flatness" \
		or key == "left_flatness" \
		or key == "right_flatness" \
		or key == "roundness" \
		or key == "sway_weight":
		return UiText.ring_parameter(key)
	return UiText.parameter(key)

func _get_handle_label(handle_id: String) -> String:
	match handle_id:
		"eye_l":
			return "왼쪽 눈"
		"eye_r":
			return "오른쪽 눈"
		"operculum":
			return "아가미덮개"
		"pectoral":
			return "가슴지느러미"
		"pelvic":
			return "배지느러미"
		"anal":
			return "뒷지느러미"
		"dorsal", "dorsal_1":
			return "등지느러미 1"
		"dorsal_2":
			return "등지느러미 2"
	return handle_id.capitalize()
