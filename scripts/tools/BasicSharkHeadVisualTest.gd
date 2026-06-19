extends Node

const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")
const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")
const SharkHeadProfile := preload("res://scripts/creature/SharkHeadProfile.gd")

const HEAD_GLOBAL_KEYS := [
	"head_size",
	"head_length",
	"head_offset",
	"eye_size",
	"eye_position_x",
	"eye_position_y",
	"eye_bulge",
	"eye_pupil_scale"
]

const HEAD_FIN_KEYS := [
	"forehead_slope",
	"head_flattening",
	"head_top_curve",
	"head_top_peak",
	"head_belly_curve",
	"head_top_flatness",
	"head_bottom_flatness",
	"head_left_flatness",
	"head_right_flatness",
	"snout_length",
	"snout_base",
	"snout_thickness",
	"snout_taper",
	"snout_curve",
	"shark_head_rear_height",
	"shark_head_rear_width",
	"shark_snout_tip_y",
	"shark_mouth_profile",
	"shark_mouth_position_x",
	"shark_mouth_position_y",
	"shark_mouth_width",
	"shark_mouth_curve",
	"shark_mouth_angle",
	"shark_mouth_arc",
	"shark_mouth_gape",
	"shark_jaw_projection",
	"shark_lower_jaw_drop",
	"shark_lower_teeth_visible",
	"shark_tooth_visible_count",
	"shark_tooth_size",
	"shark_tooth_angle",
	"shark_labial_furrow_length"
]

var _failed := false

func _ready() -> void:
	var preset := PresetStoreScript.load_preset("res://presets/basic_shark.json")
	if not _require(not preset.is_empty(), "basic_shark preset must load"):
		return
	var parameters: Dictionary = preset.get("parameters", {})
	if not _require(String(parameters.get("creature_type", "")) == "shark", "basic_shark must normalize as shark"):
		return
	_test_profile_sections_match_parameters(preset, parameters)
	if _failed:
		return

	var shark := SharkRigScript.new()
	add_child(shark)
	shark.set_parameters(parameters)
	await get_tree().process_frame
	_test_basic_shark_eye_is_forward_and_dorsolateral(parameters, shark)
	if _failed:
		return
	_test_basic_shark_mouth_is_subterminal_and_quiet(parameters)
	if _failed:
		return
	_test_basic_shark_head_reads_as_requiem_baseline(parameters)
	if _failed:
		return
	shark.queue_free()
	print("BASIC_SHARK_HEAD_VISUAL_TEST_OK")
	get_tree().quit(0)

func _test_profile_sections_match_parameters(preset: Dictionary, parameters: Dictionary) -> void:
	var global: Dictionary = preset.get("global", {})
	var fin_profile: Dictionary = preset.get("fin_profile", {})
	for key in HEAD_GLOBAL_KEYS:
		if parameters.has(key):
			if not _require(global.has(key), "basic_shark global must include %s" % key):
				return
			if not _require(_same_value(global[key], parameters[key]), "basic_shark global %s must match parameters" % key):
				return
	for key in HEAD_FIN_KEYS:
		if parameters.has(key):
			if not _require(fin_profile.has(key), "basic_shark fin_profile must include %s" % key):
				return
			if not _require(_same_value(fin_profile[key], parameters[key]), "basic_shark fin_profile %s must match parameters" % key):
				return

func _test_basic_shark_eye_is_forward_and_dorsolateral(parameters: Dictionary, shark: Node) -> void:
	var head := shark.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	var eye_l := shark.get_node_or_null("BodyPivot/EyeL") as MeshInstance3D
	var eye_r := shark.get_node_or_null("BodyPivot/EyeR") as MeshInstance3D
	if not _require(head != null and eye_l != null and eye_r != null, "basic_shark head and eyes must exist"):
		return
	var mouth_mid: Vector3 = SharkHeadProfile.mouth_path_frame(parameters, 0.5)["pos"]
	for eye in [eye_l, eye_r]:
		var local := head.to_local(eye.global_position)
		var u := _u_for_x_with_snout(local.x, parameters)
		if not _require(u >= 0.30 and u <= 0.48, "basic_shark eye u %.3f must be front/mid head, not rear neck" % u):
			return
		if not _require(local.y > mouth_mid.y + 0.08, "basic_shark eye y %.3f must sit above mouth line %.3f" % [local.y, mouth_mid.y]):
			return
	if not _require(float(parameters.get("eye_size", 1.0)) >= 0.038 and float(parameters.get("eye_size", 1.0)) <= 0.046, "basic_shark eye_size must be small-to-moderate"):
		return
	if not _require(float(parameters.get("eye_bulge", -1.0)) >= 0.02 and float(parameters.get("eye_bulge", -1.0)) <= 0.08, "basic_shark eye_bulge must keep a subtle oval bead"):
		return

func _test_basic_shark_mouth_is_subterminal_and_quiet(parameters: Dictionary) -> void:
	var mouth_mid: Vector3 = SharkHeadProfile.mouth_path_frame(parameters, 0.5)["pos"]
	var mouth_u := _u_for_x_with_snout(mouth_mid.x, parameters)
	if not _require(String(parameters.get("shark_mouth_profile", "")) == "predatory_u", "basic_shark should keep predatory_u mouth profile"):
		return
	if not _require(mouth_u >= 0.22 and mouth_u <= 0.40, "basic_shark mouth u %.3f must stay under the front snout/head" % mouth_u):
		return
	if not _require(mouth_mid.y <= -0.14, "basic_shark mouth y %.3f must be ventral/subterminal" % mouth_mid.y):
		return
	if not _require(float(parameters.get("shark_mouth_gape", 1.0)) <= 0.08, "basic_shark mouth gape must be mostly closed"):
		return
	if not _require(float(parameters.get("shark_mouth_width", 1.0)) <= 0.24, "basic_shark mouth width must avoid monster grin"):
		return
	if not _require(float(parameters.get("shark_tooth_visible_count", 99.0)) <= 4.0, "basic_shark teeth must not dominate default preset"):
		return
	if not _require(float(parameters.get("shark_tooth_size", 1.0)) <= 0.014, "basic_shark tooth size must stay subtle"):
		return
	if not _require(not bool(parameters.get("shark_lower_teeth_visible", true)), "basic_shark lower teeth should be hidden by default"):
		return

func _test_basic_shark_head_reads_as_requiem_baseline(parameters: Dictionary) -> void:
	if not _require(float(parameters.get("head_length", 0.0)) >= 0.47 and float(parameters.get("head_length", 0.0)) <= 0.50, "basic_shark head_length must be short robust shark range"):
		return
	if not _require(float(parameters.get("shark_head_rear_height", 0.0)) >= 0.16 and float(parameters.get("shark_head_rear_height", 0.0)) <= 0.26, "basic_shark rear head height must fill gill zone"):
		return
	if not _require(float(parameters.get("shark_head_rear_width", 0.0)) >= 0.18 and float(parameters.get("shark_head_rear_width", 0.0)) <= 0.32, "basic_shark rear head width must fill gill zone"):
		return
	if not _require(float(parameters.get("snout_length", 1.0)) >= 0.12 and float(parameters.get("snout_length", 1.0)) <= 0.15, "basic_shark snout_length must be short-to-moderate"):
		return
	if not _require(float(parameters.get("snout_thickness", 0.0)) >= 0.90 and float(parameters.get("snout_thickness", 0.0)) <= 0.96, "basic_shark snout_thickness must keep a rounded conical rostrum"):
		return
	if not _require(float(parameters.get("snout_taper", 1.0)) >= 0.04 and float(parameters.get("snout_taper", 1.0)) <= 0.10, "basic_shark snout_taper must avoid needle nose"):
		return
	if not _require(float(parameters.get("head_top_flatness", 1.0)) <= 0.14 and float(parameters.get("head_bottom_flatness", 1.0)) <= 0.10, "basic_shark head flatness must be rounded, not square"):
		return
	if not _require(absf(float(parameters.get("head_left_flatness", 1.0))) <= 0.04 and absf(float(parameters.get("head_right_flatness", 1.0))) <= 0.04, "basic_shark side flatness must preserve oval head-on cross-section"):
		return

func _u_for_x_with_snout(x: float, parameters: Dictionary) -> float:
	var front_x := SharkHeadProfile.ROSTRUM_FRONT_X - clampf(float(parameters.get("snout_length", 0.0)), 0.0, 0.6) * 0.35
	return clampf((x - front_x) / (SharkHeadProfile.NECK_X - front_x), 0.0, 1.0)

func _same_value(left: Variant, right: Variant) -> bool:
	if (left is int or left is float) and (right is int or right is float):
		return absf(float(left) - float(right)) < 0.001
	return left == right

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failed = true
	push_error(message)
	get_tree().quit(1)
	return false