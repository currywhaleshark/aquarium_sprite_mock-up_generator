extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

# Barbels must hang from the chin (just below the mouth anchor) and stay there when
# the snout is sheared/curled upward. Regression for barbels riding the snout-tip
# displacement onto the forehead and reading as horns (e.g. arowana-style presets
# with high jaw_offset + snout_curve). MouthLowerJaw sits at the mouth anchor for
# every mouth_open value, so it is the reference (the "Mouth" decal only exists for
# closed mouths).
func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	var base := {
		"shell_enabled": 1.0,
		"head_shape": "rounded",
		"mouth_type": "terminal",
		"mouth_size": 0.12,
		"barbel_style": "koi",
		"jaw_offset": 0.0,
		"snout_curve": 0.0,
		"snout_length": 0.3
	}
	fish.set_parameters(base)
	await get_tree().process_frame
	if not _barbels_at_chin(fish, "straight snout"):
		get_tree().quit(1)
		return

	var curled := base.duplicate(true)
	curled["jaw_offset"] = 0.135
	curled["snout_curve"] = 0.9
	fish.set_parameters(curled)
	await get_tree().process_frame
	if not _barbels_at_chin(fish, "curled snout"):
		get_tree().quit(1)
		return

	# All barbel styles share the anchor.
	for style in ["cory", "loach"]:
		var styled := curled.duplicate(true)
		styled["barbel_style"] = style
		fish.set_parameters(styled)
		await get_tree().process_frame
		if fish.get_node_or_null("BodyPivot/Head/BarbelCluster_%s" % style) == null:
			push_error("Barbel cluster missing for style %s" % style)
			get_tree().quit(1)
			return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/barbel_anchor.ok", FileAccess.WRITE)
	file.store_string("barbels anchored at the chin under the mouth")
	file.close()
	print("BARBEL_ANCHOR_TEST_OK")
	get_tree().quit(0)

func _barbels_at_chin(fish: FishRig, context: String) -> bool:
	var cluster := fish.get_node_or_null("BodyPivot/Head/BarbelCluster_koi") as Node3D
	var lower_jaw := fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as Node3D
	if cluster == null or lower_jaw == null:
		push_error("Missing barbel cluster or lower jaw node (%s)" % context)
		return false
	# Below the mouth (chin), never above it, and horizontally at the mouth front.
	if cluster.position.y >= lower_jaw.position.y:
		push_error("Barbels above the mouth (%s): barbel y %f vs mouth y %f" % [context, cluster.position.y, lower_jaw.position.y])
		return false
	if absf(cluster.position.x - lower_jaw.position.x) > 0.05:
		push_error("Barbels detached from the mouth front (%s): barbel x %f vs mouth x %f" % [context, cluster.position.x, lower_jaw.position.x])
		return false
	return true
