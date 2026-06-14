class_name CreatureMode
extends RefCounted

const FISH := "fish"
const RAY := "ray"
const SHARK := "shark"

const MODES := {
	FISH: {
		"default_camera": "aquarium_side_quarter",
		"default_preset": "basic_fish",
		"supports_archetypes": true,
		"supports_fish_drag_overlay": true,
		"supports_body_ring_editor": true
	},
	RAY: {
		"default_camera": "ray_top_quarter",
		"default_preset": "basic_ray",
		"supports_archetypes": false,
		"supports_fish_drag_overlay": false,
		"supports_body_ring_editor": true
	},
	SHARK: {
		"default_camera": "shark_side_quarter",
		"default_preset": "basic_shark",
		"supports_archetypes": false,
		"supports_fish_drag_overlay": true,
		"supports_body_ring_editor": true
	}
}

static func mode_ids() -> Array[String]:
	return [FISH, RAY, SHARK]

static func normalize(value: String) -> String:
	var mode := value.strip_edges().to_lower()
	if mode == "":
		return FISH
	if MODES.has(mode):
		return mode
	push_warning("Unknown creature mode: %s" % value)
	return FISH

static func default_camera(mode: String) -> String:
	return String(_mode_data(mode).get("default_camera", "aquarium_side_quarter"))

static func default_preset(mode: String) -> String:
	return String(_mode_data(mode).get("default_preset", "basic_fish"))

static func supports_archetypes(mode: String) -> bool:
	return bool(_mode_data(mode).get("supports_archetypes", false))

static func supports_fish_drag_overlay(mode: String) -> bool:
	return bool(_mode_data(mode).get("supports_fish_drag_overlay", false))

static func supports_body_ring_editor(mode: String) -> bool:
	return bool(_mode_data(mode).get("supports_body_ring_editor", false))

static func _mode_data(mode: String) -> Dictionary:
	return MODES.get(normalize(mode), MODES[FISH])
