extends Node

# Regression: editing a body ring's upper_height must not move the lower silhouette and
# vice versa. The shell ring was a symmetric ellipse about a shifted center, so raising
# the upper height also pushed the widest point up and reshaped the belly. Shell rings now
# carry an independent upper/lower radius (egg cross-section), so each height only affects
# its own side. This builds the shell mesh, nudges one height, and asserts the opposite
# extreme and the side height hold still.

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")

const RING := 3
const SEG := 28

func _yspan(fish) -> Dictionary:
	var shell := fish.get_node_or_null("BodyPivot/OuterShell") as MeshInstance3D
	var verts: PackedVector3Array = shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var base := RING * (SEG + 1)
	return {
		"top": verts[base + int(SEG / 4)].y,       # angle 90
		"side": verts[base].y,                       # angle 0
		"bottom": verts[base + int(3 * SEG / 4)].y,  # angle 270
	}

func _nudge_all_rings(fish, key: String, delta: float) -> void:
	var rings: Array = fish.parameters["body_profile"]["rings"]
	for r in rings:
		r[key] = float(r[key]) + delta
	fish.parameters["body_profile"]["rings"] = rings
	fish.set_parameters(fish.parameters)

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	var params := {"shell_enabled": 1.0}
	params["body_profile"] = BodyProfileScript.ensure_body_profile({})
	fish.set_parameters(params)
	await get_tree().process_frame

	# Raise upper_height: top rises, bottom + side hold.
	var a := _yspan(fish)
	_nudge_all_rings(fish, "upper_height", 0.15)
	await get_tree().process_frame
	var b := _yspan(fish)
	assert(b["top"] - a["top"] > 0.05)
	assert(absf(b["bottom"] - a["bottom"]) < 0.0005)
	assert(absf(b["side"] - a["side"]) < 0.0005)

	# Reset, then raise lower_height: bottom drops, top + side hold.
	fish.set_parameters(params)
	await get_tree().process_frame
	var c := _yspan(fish)
	_nudge_all_rings(fish, "lower_height", 0.15)
	await get_tree().process_frame
	var d := _yspan(fish)
	assert(c["bottom"] - d["bottom"] > 0.05)
	assert(absf(d["top"] - c["top"]) < 0.0005)
	assert(absf(d["side"] - c["side"]) < 0.0005)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/ring_height_decouple.ok", FileAccess.WRITE)
	file.store_string("upper/lower ring heights are independent")
	file.close()
	print("RING_HEIGHT_DECOUPLE_TEST_OK")
	get_tree().quit(0)
