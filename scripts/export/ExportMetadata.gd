class_name ExportMetadata
extends RefCounted

const RenderSettingsScript := preload("res://scripts/render/RenderSettings.gd")

static func build(preset: Dictionary, frame_size: Vector2i) -> Dictionary:
	var export_settings: Dictionary = preset.get("export_settings", {})
	var display_size: Dictionary = preset.get("display_target_size", {"w": 18, "h": 10})
	return {
		"sprite_key": "fish.generated.%s" % String(preset.get("name", "unnamed")),
		"creature_type": String(preset.get("creature_type", "fish")),
		"frame_count": int(export_settings.get("frame_count", RenderSettingsScript.DEFAULT_FRAME_COUNT)),
		"frame_ticks": int(export_settings.get("frame_ticks", RenderSettingsScript.DEFAULT_FRAME_TICKS)),
		"source_frame_size": {"w": frame_size.x, "h": frame_size.y},
		"recommended_display_size": {"w": int(display_size.get("w", 18)), "h": int(display_size.get("h", 10))},
		"sprite_facing_left": bool(export_settings.get("sprite_facing_left", true)),
		"anchor": RenderSettingsScript.ANCHOR,
		"camera_preset": String(preset.get("camera_preset", "aquarium_side_quarter"))
	}
