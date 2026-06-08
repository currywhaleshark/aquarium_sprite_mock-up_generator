class_name FinVectorEditor
extends Control

signal points_changed(points: Array)

const PADDING := 24.0
const HANDLE_RADIUS := 6.0
const HOVER_RADIUS := 10.0

var slot := "dorsal_1":
	set(val):
		slot = val
		queue_redraw()

var points: Array = []:
	set(val):
		points = val.duplicate()
		queue_redraw()

var hovered_index := -1
var dragged_index := -1
var hovered_segment := -1
var ghost_position := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(240, 180)
	clip_contents = true
	set_process(true)

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_mouse_over_states()

func _update_mouse_over_states() -> void:
	if points.size() < 6 or dragged_index != -1:
		return

	var mouse_pos := get_local_mouse_position()
	var best_dist := HOVER_RADIUS
	hovered_index = -1
	hovered_segment = -1

	# Check vertex hover
	for i in range(points.size() / 2):
		var pt := Vector2(points[i * 2], points[i * 2 + 1])
		var pix := _to_pixel(pt)
		var dist := mouse_pos.distance_to(pix)
		if dist < best_dist:
			best_dist = dist
			hovered_index = i

	if hovered_index != -1:
		queue_redraw()
		return

	# Check segment hover to support adding points on click
	var best_seg_dist := 6.0
	for i in range(points.size() / 2 - 1):
		var p1 := _to_pixel(Vector2(points[i * 2], points[i * 2 + 1]))
		var p2 := _to_pixel(Vector2(points[(i + 1) * 2], points[(i + 1) * 2 + 1]))
		
		# Find projection of mouse on segment p1->p2
		var ab := p2 - p1
		var ap := mouse_pos - p1
		var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var proj := p1 + t * ab
		var dist := mouse_pos.distance_to(proj)
		if dist < best_seg_dist:
			best_seg_dist = dist
			hovered_segment = i
			ghost_position = proj

	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Drag existing point or add a new one
				if hovered_index != -1:
					# Check if it is a locked root point
					if not _is_root_locked(hovered_index):
						dragged_index = hovered_index
				elif hovered_segment != -1:
					# Add new point on the segment
					var norm_pos := _to_norm(ghost_position)
					points.insert((hovered_segment + 1) * 2, norm_pos.x)
					points.insert((hovered_segment + 1) * 2 + 1, norm_pos.y)
					dragged_index = hovered_segment + 1
					points_changed.emit(points.duplicate())
					queue_redraw()
			else:
				# Release drag
				dragged_index = -1
				queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Delete hovered point
			if hovered_index != -1 and not _is_root_locked(hovered_index):
				if points.size() > 6: # Maintain at least 3 points
					points.remove_at(hovered_index * 2 + 1)
					points.remove_at(hovered_index * 2)
					hovered_index = -1
					points_changed.emit(points.duplicate())
					queue_redraw()
	elif event is InputEventMouseMotion:
		if dragged_index != -1:
			var mouse_pos := get_local_mouse_position()
			var norm_pos := _to_norm(mouse_pos)
			
			# Clamp based on slots
			if slot == "caudal" or slot == "operculum":
				norm_pos.x = clampf(norm_pos.x, 0.0, 1.0)
				norm_pos.y = clampf(norm_pos.y, -1.0, 1.0)
			elif slot == "pectoral" or slot == "pelvic":
				norm_pos.x = clampf(norm_pos.x, -0.5, 0.5)
				norm_pos.y = clampf(norm_pos.y, -1.0, 1.0)
			else:
				norm_pos.x = clampf(norm_pos.x, -0.5, 0.5)
				norm_pos.y = clampf(norm_pos.y, 0.0, 1.0)
				
			points[dragged_index * 2] = norm_pos.x
			points[dragged_index * 2 + 1] = norm_pos.y
			points_changed.emit(points.duplicate())
			queue_redraw()

func _is_root_locked(idx: int) -> bool:
	# Operculum is a free closed silhouette with no attachment anchor to pin.
	if slot == "operculum":
		return false
	# Root points (first and last vertex) are locked to maintain attachment anchor
	return idx == 0 or idx == (points.size() / 2 - 1)

func _to_pixel(norm: Vector2) -> Vector2:
	var w := size.x - PADDING * 2
	var h := size.y - PADDING * 2
	if slot == "caudal" or slot == "operculum":
		# X: [0.0, 1.0] -> [PADDING, PADDING + w]
		# Y: [-1.0, 1.0] -> [PADDING + h, PADDING] (y-flip)
		var px := PADDING + norm.x * w
		var py := PADDING + (1.0 - (norm.y + 1.0) * 0.5) * h
		return Vector2(px, py)
	elif slot == "pectoral" or slot == "pelvic":
		# X: [-0.5, 0.5] -> [PADDING, PADDING + w]
		# Y: [-1.0, 1.0] -> [PADDING + h, PADDING] (y-flip)
		var px := PADDING + (norm.x + 0.5) * w
		var py := PADDING + (1.0 - (norm.y + 1.0) * 0.5) * h
		return Vector2(px, py)
	else:
		# X: [-0.5, 0.5] -> [PADDING, PADDING + w]
		# Y: [0.0, 1.0] -> [PADDING + h, PADDING]
		var px := PADDING + (norm.x + 0.5) * w
		var py := PADDING + (1.0 - norm.y) * h
		return Vector2(px, py)

func _to_norm(pix: Vector2) -> Vector2:
	var w := size.x - PADDING * 2
	var h := size.y - PADDING * 2
	if slot == "caudal" or slot == "operculum":
		var nx := (pix.x - PADDING) / maxf(w, 1.0)
		var ny := (1.0 - (pix.y - PADDING) / maxf(h, 1.0)) * 2.0 - 1.0
		return Vector2(nx, ny)
	elif slot == "pectoral" or slot == "pelvic":
		var nx := (pix.x - PADDING) / maxf(w, 1.0) - 0.5
		var ny := (1.0 - (pix.y - PADDING) / maxf(h, 1.0)) * 2.0 - 1.0
		return Vector2(nx, ny)
	else:
		var nx := (pix.x - PADDING) / maxf(w, 1.0) - 0.5
		var ny := 1.0 - (pix.y - PADDING) / maxf(h, 1.0)
		return Vector2(nx, ny)

func _draw() -> void:
	# 1. Dark Rounded Background
	draw_rect(Rect2(Vector2.ZERO, size), Color.html("#16161a"), true)
	
	# Draw Coordinate Grid
	var w := size.x - PADDING * 2
	var h := size.y - PADDING * 2
	
	var grid_color := Color(1.0, 1.0, 1.0, 0.05)
	var axis_color := Color.html("#e03131") * 0.4 # Suttle red for anchor axes
	
	# Vertical grid lines
	for i in range(5):
		var tx := float(i) / 4.0
		var x_pos := PADDING + tx * w
		draw_line(Vector2(x_pos, PADDING), Vector2(x_pos, PADDING + h), grid_color, 1.0)
		
	# Horizontal grid lines
	for i in range(5):
		var ty := float(i) / 4.0
		var y_pos := PADDING + ty * h
		draw_line(Vector2(PADDING, y_pos), Vector2(PADDING + w, y_pos), grid_color, 1.0)
		
	# Draw baseline / attachment line
	if slot == "caudal" or slot == "pectoral" or slot == "pelvic" or slot == "operculum":
		# Root is x = 0 (caudal/operculum front hinge) or x = -0.5 (pectoral/pelvic);
		# all map to the left edge of the grid.
		var root_x := PADDING
		draw_line(Vector2(root_x, PADDING), Vector2(root_x, PADDING + h), axis_color, 2.0)
	else:
		# Root is y = 0
		var root_y := PADDING + h
		draw_line(Vector2(PADDING, root_y), Vector2(PADDING + w, root_y), axis_color, 2.0)
		
	if points.size() < 6:
		return
		
	# 2. Draw Fin Boundary Lines
	var poly_line_color := Color.html("#00f2fe") # Neon cyan fin edge
	for i in range(points.size() / 2 - 1):
		var p1 := _to_pixel(Vector2(points[i * 2], points[i * 2 + 1]))
		var p2 := _to_pixel(Vector2(points[(i + 1) * 2], points[(i + 1) * 2 + 1]))
		draw_line(p1, p2, poly_line_color, 2.0)
		
	# Draw a dashed or faint line connecting tip back to root (the baseline closing)
	var p_first := _to_pixel(Vector2(points[0], points[1]))
	var p_last := _to_pixel(Vector2(points[points.size() - 2], points[points.size() - 1]))
	draw_line(p_first, p_last, Color(1, 1, 1, 0.15), 1.0, true)
	
	# 3. Draw ghost handle for hovering segment (Insert Preview)
	if hovered_segment != -1 and hovered_index == -1:
		draw_circle(ghost_position, HANDLE_RADIUS - 1.0, Color(0.15, 0.9, 0.4, 0.4))
		draw_circle(ghost_position, 2.0, Color.WHITE)
		
	# 4. Draw Vertex Handles
	for i in range(points.size() / 2):
		var pt := Vector2(points[i * 2], points[i * 2 + 1])
		var pix := _to_pixel(pt)
		var is_locked := _is_root_locked(i)
		var is_hovered := (i == hovered_index)
		var is_dragged := (i == dragged_index)
		
		if is_locked:
			# Locked points drawn as gray squares
			var sq_size := Vector2(8, 8)
			var rect := Rect2(pix - sq_size * 0.5, sq_size)
			draw_rect(rect, Color.html("#495057"), true)
			draw_rect(rect, Color(1.0, 1.0, 1.0, 0.25), false, 1.0)
		else:
			# Editable points drawn as circles
			var outer_col := Color(0.0, 0.95, 1.0, 0.25)
			var inner_col := Color.html("#00f2fe")
			
			if is_dragged:
				outer_col = Color(1.0, 0.45, 0.0, 0.35)
				inner_col = Color.html("#ff922b") # Neon orange
			elif is_hovered:
				outer_col = Color(0.15, 0.9, 0.4, 0.3)
				inner_col = Color.html("#37b24d") # Neon green
				
			draw_circle(pix, HANDLE_RADIUS + 2.0, outer_col)
			draw_circle(pix, HANDLE_RADIUS - 2.0, inner_col)
			draw_circle(pix, 1.5, Color.WHITE)
