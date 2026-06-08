extends Node

const HeadEditorPanelScript := preload("res://scripts/ui/HeadEditorPanel.gd")
const FinVectorEditorScript := preload("res://scripts/ui/FinVectorEditor.gd")

var _failed := false

func _ready() -> void:
	await _test_head_slider_emits_during_drag()
	_test_vector_editor_emits_during_drag()
	await _test_vector_editor_recovers_preview_marker_after_missed_release()
	_test_vector_editor_emits_single_preview_marker()
	if _failed:
		get_tree().quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/editor_drag_emission.ok", FileAccess.WRITE)
	file.store_string("editor drag emissions stay realtime")
	file.close()
	print("EDITOR_DRAG_EMISSION_TEST_OK")
	get_tree().quit(0)

func _test_head_slider_emits_during_drag() -> void:
	var panel := HeadEditorPanelScript.new()
	add_child(panel)
	panel.set_parameters({"creature_type": "fish", "head_size": 0.4})
	await get_tree().process_frame
	var seen := [0]
	var last_size := [0.0]
	panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		seen[0] += 1
		last_size[0] = float(parameters.get("head_size", 0.0))
	)
	var slider := _find_head_slider(panel, "head_size")
	_require(slider != null, "head_size slider exists")
	slider.value = 0.48
	slider.value = 0.62
	_require(seen[0] == 2, "head slider should emit during drag; seen=%d value=%.3f slider=%.3f" % [seen[0], last_size[0], slider.value])
	_require(absf(last_size[0] - 0.62) < 0.001, "head slider realtime emit carries final value; seen=%d value=%.3f slider=%.3f" % [seen[0], last_size[0], slider.value])
	panel.queue_free()

func _test_vector_editor_emits_during_drag() -> void:
	var editor := FinVectorEditorScript.new()
	add_child(editor)
	editor.slot = "operculum"
	editor.points = [0.0, -0.5, 0.0, 0.5, 1.0, 0.0]
	editor.dragged_index = 1
	var seen := [0]
	editor.points_changed.connect(func(_points: Array) -> void:
		seen[0] += 1
	)
	var motion := InputEventMouseMotion.new()
	editor.call("_gui_input", motion)
	_require(seen[0] == 1, "vector editor should emit during drag for realtime preview; seen=%d dragged=%d" % [seen[0], int(editor.get("dragged_index"))])
	editor.queue_free()

func _test_vector_editor_recovers_preview_marker_after_missed_release() -> void:
	var editor := FinVectorEditorScript.new()
	add_child(editor)
	editor.slot = "operculum"
	editor.size = Vector2(240, 180)
	editor.points = [0.0, -0.5, 0.0, 0.5, 1.0, 0.0]
	await get_tree().process_frame
	editor.dragged_index = 1
	editor.call("_process", 0.016)
	_require(int(editor.get("dragged_index")) == -1, "vector editor should clear a stuck drag when the mouse button is no longer pressed")
	editor.call("_update_mouse_over_states_at", Vector2(120, 74))
	_require(int(editor.get("hovered_segment")) != -1, "vector editor should restore insert preview marker after stuck drag clears")
	editor.queue_free()

func _test_vector_editor_emits_single_preview_marker() -> void:
	var editor := FinVectorEditorScript.new()
	add_child(editor)
	editor.slot = "operculum"
	editor.size = Vector2(240, 180)
	editor.points = [0.0, -0.5, 0.0, 0.5, 1.0, 0.0]
	_require(editor.has_signal("preview_marker_changed"), "vector editor should expose preview_marker_changed signal")
	if not editor.has_signal("preview_marker_changed"):
		editor.queue_free()
		return
	var seen := []
	editor.preview_marker_changed.connect(func(active: bool, norm_position: Vector2, ghost: bool) -> void:
		seen.append({"active": active, "norm": norm_position, "ghost": ghost})
	)
	editor.call("_update_mouse_over_states_at", Vector2(24, 114))
	_require(seen.size() == 1, "vector editor should emit one hovered point marker")
	_require(bool(seen[-1].get("active", false)), "hovered point marker should be active")
	_require(not bool(seen[-1].get("ghost", true)), "hovered point marker should not be ghost")
	editor.call("_update_mouse_over_states_at", Vector2(120, 74))
	_require(seen.size() == 2, "vector editor should emit one ghost marker")
	_require(bool(seen[-1].get("active", false)), "ghost marker should be active")
	_require(bool(seen[-1].get("ghost", false)), "ghost marker should be marked ghost")
	editor.call("_update_mouse_over_states_at", Vector2(220, 170))
	_require(seen.size() == 3, "vector editor should emit clear marker when hover leaves")
	_require(not bool(seen[-1].get("active", true)), "marker should clear when hover leaves")
	editor.queue_free()

func _find_head_slider(panel: Node, key: String) -> HSlider:
	var numeric_sliders: Dictionary = panel.get("numeric_sliders")
	if not numeric_sliders.has(key):
		return null
	var widgets: Dictionary = numeric_sliders[key]
	return widgets.get("slider") as HSlider

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
