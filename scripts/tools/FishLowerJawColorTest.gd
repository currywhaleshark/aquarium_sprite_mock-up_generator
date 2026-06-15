extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const ParameterPanelScript := preload("res://scripts/ui/ParameterPanel.gd")
const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")

var _failed := false

func _ready() -> void:
	var fish: Node = FishRigScript.new()
	add_child(fish)
	fish.set("auto_animate", false)
	var requested_color := Color.html("#6e8a91")
	fish.call("set_parameters", {
		"creature_type": "fish",
		"shell_enabled": 1.0,
		"base_color": "#46c6cf",
		"belly_color": "#c8f4ec",
		"mouth_type": "terminal",
		"mouth_open": 0.35,
		"mouth_size": 0.12,
		"lower_jaw_color": "#6e8a91"
	})
	await get_tree().process_frame

	var lower_jaw := fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as MeshInstance3D
	if not _require(lower_jaw != null, "MouthLowerJaw must exist"):
		return
	var material := lower_jaw.material_override as StandardMaterial3D
	if not _require(material != null, "MouthLowerJaw must use a StandardMaterial3D"):
		return
	if not _require(_same_rgb(material.albedo_color, requested_color), "MouthLowerJaw must use lower_jaw_color"):
		return

	var normalized := PresetStoreScript.normalize_preset({
		"creature_type": "fish",
		"parameters": {
			"base_color": "#46c6cf",
			"belly_color": "#c8f4ec"
		}
	})
	var parameters: Dictionary = normalized.get("parameters", {})
	if not _require(parameters.has("lower_jaw_color"), "fish presets must expose lower_jaw_color by default"):
		return

	var panel := ParameterPanelScript.new()
	add_child(panel)
	await get_tree().process_frame
	panel.set_parameters(parameters)
	if not _require(panel.get("color_pickers").has("lower_jaw_color"), "color panel must create a picker for lower_jaw_color"):
		return

	print("FISH_LOWER_JAW_COLOR_TEST_OK")
	get_tree().quit(0)

func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.001 and absf(a.g - b.g) < 0.001 and absf(a.b - b.b) < 0.001

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failed = true
	push_error(message)
	get_tree().quit(1)
	return false
