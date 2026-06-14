class_name ExportMetadata
extends RefCounted

const RenderSettingsScript := preload("res://scripts/render/RenderSettings.gd")
const ExportDirectionsScript := preload("res://scripts/export/ExportDirections.gd")
const CameraPresetScript := preload("res://scripts/render/CameraPreset.gd")

static func build(preset: Dictionary, frame_size: Vector2i) -> Dictionary:
	var export_settings: Dictionary = preset.get("export_settings", {})
	var display_size: Dictionary = preset.get("display_target_size", {"w": 18, "h": 10})
	var frame_count := int(export_settings.get("frame_count", RenderSettingsScript.DEFAULT_FRAME_COUNT))
	var direction_count := ExportDirectionsScript.normalized_direction_count(int(export_settings.get("direction_count", 1)))
	var directions := ExportDirectionsScript.direction_names(direction_count)
	var include_turn_clips := ExportDirectionsScript.include_turn_clips_enabled(direction_count, export_settings)
	var animation_rows := ExportDirectionsScript.animation_rows(direction_count, include_turn_clips)
	var uses_fixed_quarter_camera := direction_count == 8
	var camera_preset_name := CameraPresetScript.SPRITE_QUARTER_2TO1 if uses_fixed_quarter_camera else String(preset.get("camera_preset", "aquarium_side_quarter"))
	var camera_defaults := CameraPresetScript.get_preset(camera_preset_name)
	var camera_yaw := float(camera_defaults.get("yaw", 0.0))
	var camera_pitch := float(camera_defaults.get("pitch", -18.0))
	var camera_roll := float(camera_defaults.get("roll", 0.0))
	if not uses_fixed_quarter_camera:
		camera_yaw = float(preset.get("camera_yaw", camera_yaw))
		camera_pitch = float(preset.get("camera_pitch", camera_pitch))
		camera_roll = float(preset.get("camera_roll", camera_roll))
	var metadata := {
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
		"sheet_rows": animation_rows.size(),
		"animation_rows": animation_rows,
		"turn_clips_enabled": include_turn_clips,
		"turn_clip_degrees": ExportDirectionsScript.TURN_DELTA_DEGREES if include_turn_clips else 0,
		"turn_clip_directions": ["left", "right"] if include_turn_clips else [],
		"anchor": RenderSettingsScript.ANCHOR,
		"camera_preset": camera_preset_name,
		"camera_yaw": camera_yaw,
		"camera_pitch": camera_pitch,
		"camera_roll": camera_roll
	}
	if uses_fixed_quarter_camera:
		metadata["world_projection"] = CameraPresetScript.sprite_quarter_projection()
	return metadata
