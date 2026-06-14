extends Node

const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
const BodySilhouetteEditorScript := preload("res://scripts/ui/BodySilhouetteEditor.gd")

var _failed := false

func _ready() -> void:
	var editor := BodySilhouetteEditorScript.new()
	add_child(editor)
	var rings: Array = BodyProfileScript.ensure_body_profile({})["rings"]
	editor.set_rings(rings)

	var mid_ring: Dictionary = _ring_by_id(rings, "mid_body")
	var top_pos: Vector2 = editor.handle_norm_position("mid_body", "top")
	_require(top_pos.distance_to(Vector2(
		float(mid_ring.get("x", 0.0)),
		float(mid_ring.get("y_offset", 0.0)) + float(mid_ring.get("upper_height", 0.0))
	)) < 0.001, "side top handle must map to x and y_offset + upper_height")

	var changes: Array[Dictionary] = []
	editor.ring_value_changed.connect(func(ring_id: String, key: String, value: float) -> void:
		changes.append({"ring_id": ring_id, "key": key, "value": value})
	)
	editor.apply_handle_drag("mid_body", "top", Vector2(0.0, 0.1))
	_require(changes.size() == 1, "top drag should emit exactly one value change")
	_require(String(changes[0].get("ring_id", "")) == "mid_body", "top drag should target mid_body")
	_require(String(changes[0].get("key", "")) == "upper_height", "top drag should emit upper_height only")
	_require(abs(float(changes[0].get("value", 0.0)) - 0.56) < 0.001, "top drag should add to upper_height")

	changes.clear()
	editor.apply_handle_drag("mid_body", "center", Vector2(-0.5, 0.2))
	_require(changes.size() == 2, "center drag should emit x and y_offset")
	_require(String(changes[0].get("key", "")) == "x", "center drag first value should be x")
	_require(String(changes[1].get("key", "")) == "y_offset", "center drag second value should be y_offset")
	var front_ring: Dictionary = _ring_by_id(rings, "front_body")
	var rear_ring: Dictionary = _ring_by_id(rings, "rear_body")
	var moved_x := float(changes[0].get("value", 0.0))
	_require(moved_x > float(front_ring.get("x", 0.0)), "center x drag should clamp after previous ring")
	_require(moved_x < float(rear_ring.get("x", 1.0)), "center x drag should stay before next ring")
	_require(abs(float(changes[1].get("value", 0.0)) - 0.2) < 0.001, "center y drag should update y_offset")

	var picked: Array[String] = []
	editor.ring_pick_requested.connect(func(ring_id: String) -> void:
		picked.append(ring_id)
	)
	editor.request_select("head")
	_require(picked == ["head"], "request_select should emit ring_pick_requested")

	var add_requests: Array[float] = []
	editor.ring_add_requested.connect(func(x: float) -> void:
		add_requests.append(x)
	)
	editor.request_add_at(0.5)
	_require(add_requests.size() == 1 and abs(add_requests[0] - 0.5) < 0.001, "request_add_at should emit x")

	var delete_requests: Array[String] = []
	editor.ring_delete_requested.connect(func(ring_id: String) -> void:
		delete_requests.append(ring_id)
	)
	editor.request_delete("mid_body")
	_require(delete_requests == ["mid_body"], "request_delete should emit ring_delete_requested")

	editor.view_mode = "width"
	var width_top_pos: Vector2 = editor.handle_norm_position("mid_body", "top_width")
	_require(width_top_pos.distance_to(Vector2(
		float(mid_ring.get("x", 0.0)),
		float(mid_ring.get("top_width", mid_ring.get("width", 0.0)))
	)) < 0.001, "width top handle must map to x and top_width")
	var width_bottom_pos: Vector2 = editor.handle_norm_position("mid_body", "bottom_width")
	_require(width_bottom_pos.distance_to(Vector2(
		float(mid_ring.get("x", 0.0)),
		-float(mid_ring.get("bottom_width", mid_ring.get("width", 0.0)))
	)) < 0.001, "width bottom handle must map to x and -bottom_width")

	changes.clear()
	editor.apply_handle_drag("mid_body", "top_width", Vector2(0.0, 0.1))
	_require(changes.size() == 1, "top_width drag should emit one value")
	if changes.size() == 1:
		_require(String(changes[0].get("key", "")) == "top_width", "top_width drag should emit top_width only")
		_require(abs(float(changes[0].get("value", 0.0)) - 0.48) < 0.001, "top_width drag should increase top_width")

	changes.clear()
	editor.apply_handle_drag("mid_body", "bottom_width", Vector2(0.0, -0.1))
	_require(changes.size() == 1, "bottom_width drag should emit one value")
	if changes.size() == 1:
		_require(String(changes[0].get("key", "")) == "bottom_width", "bottom_width drag should emit bottom_width only")
		_require(abs(float(changes[0].get("value", 0.0)) - 0.48) < 0.001, "bottom_width drag should increase when dragged downward")

	if _failed:
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/body_silhouette_editor.ok", FileAccess.WRITE)
	file.store_string("body silhouette side view editor emits ring mutations")
	file.close()
	print("BODY_SILHOUETTE_EDITOR_TEST_OK")
	get_tree().quit(0)

func _ring_by_id(rings: Array, ring_id: String) -> Dictionary:
	for ring in rings:
		if String(ring.get("id", "")) == ring_id:
			return ring
	return {}

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
