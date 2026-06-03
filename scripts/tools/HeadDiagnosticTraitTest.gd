extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.set_parameters({
		"head_ornament": "wen",
		"gill_mark": "crescent",
		"barbel_style": "cory",
		"eye_style": "telescope",
		"mouth_detail": "sucker",
		"mouth_type": "inferior",
		"snout_length": 0.08,
		"secondary_color": "#f4b0a8"
	})
	await get_tree().process_frame
	await get_tree().process_frame

	var wen := fish.get_node_or_null("BodyPivot/Head/HeadOrnament_wen") as Node3D
	var gill := fish.get_node_or_null("BodyPivot/Head/GillMark_crescent") as Node3D
	var barbels := fish.get_node_or_null("BodyPivot/Head/BarbelCluster_cory") as Node3D
	var mouth_detail := fish.get_node_or_null("BodyPivot/Head/MouthDetail_sucker") as Node3D
	var eye_l := fish.get_node_or_null("BodyPivot/EyeL") as MeshInstance3D
	var stalk_l := fish.get_node_or_null("BodyPivot/EyeStalkL") as MeshInstance3D
	assert(wen != null)
	assert(wen.get_child_count() >= 5)
	assert(gill != null)
	assert(_max_child_local_y(wen) > 0.38)
	assert(_max_abs_child_local_z(gill) > 0.48)
	assert(barbels != null)
	assert(barbels.get_child_count() >= 4)
	assert(mouth_detail != null)
	var mouth := fish.get_node_or_null("BodyPivot/Head/Mouth") as MeshInstance3D
	assert(mouth != null)
	assert(mouth.position.x < -0.48)
	assert(absf(mouth.position.z) < 0.08)
	assert(fish.get_node_or_null("BodyPivot/Head/MouthR") == null)
	assert(eye_l != null)
	assert(eye_l.scale.x > 0.07)
	assert(stalk_l != null)

	fish.set_parameters({
		"head_ornament": "nuchal_hump",
		"gill_mark": "plate",
		"barbel_style": "koi",
		"eye_style": "tiny_puffer",
		"mouth_detail": "beak",
		"mouth_type": "terminal"
	})
	await get_tree().process_frame
	await get_tree().process_frame
	assert(fish.get_node_or_null("BodyPivot/Head/HeadOrnament_nuchal_hump") != null)
	assert(fish.get_node_or_null("BodyPivot/Head/GillMark_plate") != null)
	var koi_barbels := fish.get_node_or_null("BodyPivot/Head/BarbelCluster_koi") as Node3D
	var beak := fish.get_node_or_null("BodyPivot/Head/MouthDetail_beak") as Node3D
	var tiny_eye := fish.get_node_or_null("BodyPivot/EyeL") as MeshInstance3D
	assert(koi_barbels != null)
	assert(koi_barbels.get_child_count() == 2)
	assert(beak != null)
	assert(tiny_eye != null)
	assert(tiny_eye.scale.x < 0.04)

	var split := BodyProfileScript.split_parameters_into_profiles({
		"head_ornament": "wen",
		"gill_mark": "line",
		"barbel_style": "loach",
		"eye_style": "large",
		"mouth_detail": "lip"
	}, {"name": "head_trait_roundtrip", "type": "fish"})
	var rebuilt := BodyProfileScript.make_parameters_from_structured_preset(split)
	assert(String(rebuilt.get("head_ornament", "")) == "wen")
	assert(String(rebuilt.get("gill_mark", "")) == "line")
	assert(String(rebuilt.get("barbel_style", "")) == "loach")
	assert(String(rebuilt.get("eye_style", "")) == "large")
	assert(String(rebuilt.get("mouth_detail", "")) == "lip")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/head_diagnostic_trait.ok", FileAccess.WRITE)
	file.store_string("head diagnostic traits rendered and round-tripped")
	file.close()
	print("HEAD_DIAGNOSTIC_TRAIT_TEST_OK")
	get_tree().quit(0)

func _max_child_local_y(node: Node) -> float:
	var max_y := -INF
	for child in node.get_children():
		if child is Node3D:
			max_y = maxf(max_y, (child as Node3D).position.y)
	return max_y

func _max_abs_child_local_z(node: Node) -> float:
	var max_z := 0.0
	for child in node.get_children():
		if child is Node3D:
			max_z = maxf(max_z, absf((child as Node3D).position.z))
	return max_z
