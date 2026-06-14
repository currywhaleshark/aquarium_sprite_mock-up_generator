class_name ExportDirections
extends RefCounted

const EIGHT_DIRECTIONS := [
	"east",
	"north_east",
	"north",
	"north_west",
	"west",
	"south_west",
	"south",
	"south_east"
]

const TURN_DELTA_DEGREES := 45

static func normalized_direction_count(value: int) -> int:
	return 8 if value == 8 else 1

static func direction_names(direction_count: int) -> Array[String]:
	var names: Array[String] = []
	if normalized_direction_count(direction_count) == 8:
		for direction in EIGHT_DIRECTIONS:
			names.append(String(direction))
	else:
		names.append("east")
	return names

static func direction_yaw_degrees(direction_index: int) -> float:
	return float(posmod(225 + posmod(direction_index, 8) * 45, 360))

static func export_yaw_degrees(direction_count: int, direction_index: int, original_yaw: float) -> float:
	if normalized_direction_count(direction_count) == 8:
		return direction_yaw_degrees(direction_index)
	return original_yaw

static func include_turn_clips_enabled(direction_count: int, export_settings: Dictionary) -> bool:
	return normalized_direction_count(direction_count) == 8 and bool(export_settings.get("include_turn_clips", false))

static func animation_rows(direction_count: int, include_turn_clips: bool = false) -> Array:
	var normalized_count := normalized_direction_count(direction_count)
	var directions := direction_names(normalized_count)
	var rows := []
	for direction_index in directions.size():
		var direction_name := String(directions[direction_index])
		rows.append({
			"row": rows.size(),
			"clip": "swim",
			"direction": direction_name,
			"direction_index": direction_index,
			"frame_dir": direction_name if normalized_count == 8 else ""
		})
	if normalized_count != 8 or not include_turn_clips:
		return rows
	_append_turn_rows(rows, directions, "turn_left", "left", 1)
	_append_turn_rows(rows, directions, "turn_right", "right", -1)
	return rows

static func _append_turn_rows(rows: Array, directions: Array[String], clip_name: String, turn_direction: String, turn_step: int) -> void:
	for direction_index in _turn_row_direction_indices(directions.size(), turn_step):
		var from_direction := String(directions[direction_index])
		var to_index := posmod(direction_index + turn_step, directions.size())
		var to_direction := String(directions[to_index])
		rows.append({
			"row": rows.size(),
			"clip": clip_name,
			"direction": from_direction,
			"direction_index": direction_index,
			"from_direction": from_direction,
			"from_direction_index": direction_index,
			"to_direction": to_direction,
			"to_direction_index": to_index,
			"turn_direction": turn_direction,
			"turn_step": turn_step,
			"delta_degrees": TURN_DELTA_DEGREES,
			"chainable": true,
			"frame_dir": "%s/from_%s_to_%s" % [clip_name, from_direction, to_direction]
		})

static func _turn_row_direction_indices(direction_count: int, turn_step: int) -> Array[int]:
	var indices: Array[int] = []
	if turn_step < 0 and direction_count > 1:
		indices.append(0)
		for direction_index in range(direction_count - 1, 0, -1):
			indices.append(direction_index)
	else:
		for direction_index in direction_count:
			indices.append(direction_index)
	return indices
