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
