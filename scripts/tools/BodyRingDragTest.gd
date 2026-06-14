extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")

const RING_ID := "mid_body"

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	var params := {"shell_enabled": 1.0}
	params["body_profile"] = BodyProfileScript.ensure_body_profile({})
	fish.set_parameters(params)
	fish.set_ring_editor_enabled(true)
	fish.set_selected_body_ring(RING_ID)
	await get_tree().process_frame

	var handles: Dictionary = fish.get_body_ring_handles()
	assert(handles.has(RING_ID))
	var ring_handles: Dictionary = handles[RING_ID]
	assert(ring_handles.has("center"))
	assert(ring_handles.has("top"))
	assert(ring_handles.has("bottom"))
	assert(_near(ring_handles["center"], _guide_world(fish, "RingCenter_%s" % RING_ID)))
	assert(_near(ring_handles["top"], _guide_world(fish, "RingTop_%s" % RING_ID)))
	assert(_near(ring_handles["bottom"], _guide_world(fish, "RingBottom_%s" % RING_ID)))

	var plane: Dictionary = fish.get_body_ring_drag_plane(RING_ID, "top")
	assert(_near(plane["point"], ring_handles["top"]))
	assert(_near(plane["normal"], fish.body_pivot.global_transform.basis.z.normalized()))

	var before_top := _ring(fish, RING_ID).duplicate(true)
	fish.drag_ring_handle(RING_ID, "top", Vector3(0.0, 0.1, 0.0))
	var after_top := _ring(fish, RING_ID)
	assert(float(after_top["upper_height"]) > float(before_top["upper_height"]))
	assert(_unchanged(after_top, before_top, ["x", "y_offset", "lower_height", "width", "top_width", "bottom_width"]))
	assert(fish.get_body_ring_handles()[RING_ID]["top"].y > ring_handles["top"].y)

	var before_bottom := _ring(fish, RING_ID).duplicate(true)
	fish.drag_ring_handle(RING_ID, "bottom", Vector3(0.0, -0.1, 0.0))
	var after_bottom := _ring(fish, RING_ID)
	assert(float(after_bottom["lower_height"]) > float(before_bottom["lower_height"]))
	assert(_unchanged(after_bottom, before_bottom, ["x", "y_offset", "upper_height", "width", "top_width", "bottom_width"]))

	var before_center := _ring(fish, RING_ID).duplicate(true)
	fish.drag_ring_handle(RING_ID, "center", Vector3(0.05, 0.04, 0.0))
	var after_center := _ring(fish, RING_ID)
	assert(float(after_center["x"]) > float(before_center["x"]))
	assert(float(after_center["y_offset"]) > float(before_center["y_offset"]))
	assert(_unchanged(after_center, before_center, ["upper_height", "lower_height", "width", "top_width", "bottom_width"]))

	fish.drag_ring_handle(RING_ID, "top", Vector3(0.0, 100.0, 0.0))
	var clamped := _ring(fish, RING_ID)
	assert(absf(float(clamped["upper_height"]) - float(BodyProfileScript.RING_KEY_RANGES["upper_height"]["max"])) < 0.0001)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/body_ring_drag.ok", FileAccess.WRITE)
	file.store_string("body ring drag handles mutate the intended ring fields")
	file.close()
	print("BODY_RING_DRAG_TEST_OK")
	get_tree().quit(0)

func _guide_world(fish: FishRig, node_name: String) -> Vector3:
	var guide := fish.get_node("BodyPivot/BodyRingGuides/%s" % node_name) as Node3D
	return guide.global_position

func _ring(fish: FishRig, ring_id: String) -> Dictionary:
	for ring in fish.parameters["body_profile"]["rings"]:
		if String(ring.get("id", "")) == ring_id:
			return ring
	return {}

func _unchanged(actual: Dictionary, expected: Dictionary, keys: Array[String]) -> bool:
	for key in keys:
		if absf(float(actual.get(key, 0.0)) - float(expected.get(key, 0.0))) > 0.0001:
			return false
	return true

func _near(a: Vector3, b: Vector3, epsilon: float = 0.0001) -> bool:
	return a.distance_to(b) < epsilon
