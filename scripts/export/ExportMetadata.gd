class_name ExportMetadata
extends RefCounted

const RenderSettingsScript := preload("res://scripts/render/RenderSettings.gd")
const ExportDirectionsScript := preload("res://scripts/export/ExportDirections.gd")

static func build(preset: Dictionary, frame_size: Vector2i) -> Dictionary:
	var export_settings: Dictionary = preset.get("export_settings", {})
	var display_size: Dictionary = preset.get("display_target_size", {"w": 18, "h": 10})
	var frame_count := int(export_settings.get("frame_count", RenderSettingsScript.DEFAULT_FRAME_COUNT))
	var direction_count := ExportDirectionsScript.normalized_direction_count(int(export_settings.get("direction_count", 1)))
	var directions := ExportDirectionsScript.direction_names(direction_count)
	return {
		"sprite_key": "fish.generated.%s" % String(preset.get("name", "unnamed")),
		"creature_type": String(preset.get("creature_type", "fish")),
		"frame_count": frame_count,
		"frame_ticks": int(export_settings.get("frame_ticks", RenderSettingsScript.DEFAULT_FRAME_TICKS)),
		"source_frame_size": {"w": frame_size.x, "h": frame_size.y},
		"recommended_display_size": {"w": int(display_size.get("w", 18)), "h": int(display_size.get("h", 10))},
		"sprite_facing_left": bool(export_settings.get("sprite_facing_left", true)),
		"direction_count": direction_count,
		"directions": directions,
		"sheet_columns": frame_count,
		"sheet_rows": direction_count,
		"anchor": RenderSettingsScript.ANCHOR,
		"camera_preset": String(preset.get("camera_preset", "aquarium_side_quarter"))
	}
