class_name BodyEditorPanel
extends VBoxContainer

signal parameters_changed(parameters: Dictionary)
signal ring_selected(ring_id: String)
signal numeric_slider_changed(key: String)

const UiText := preload("res://scripts/ui/UiText.gd")
const UiRows := preload("res://scripts/ui/UiRows.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")

const RING_NUMERIC_KEYS := {
	"x": {"min": 0.0, "max": 1.0, "step": 0.005},
	"y_offset": {"min": -0.8, "max": 0.8, "step": 0.005},
	"upper_height": {"min": 0.02, "max": 1.4, "step": 0.005},
	"lower_height": {"min": 0.02, "max": 1.4, "step": 0.005},
	"width": {"min": 0.02, "max": 1.2, "step": 0.005},
	"top_width": {"min": 0.02, "max": 1.2, "step": 0.005},
	"bottom_width": {"min": 0.02, "max": 1.2, "step": 0.005},
	"top_flatness": {"min": 0.0, "max": 1.0, "step": 0.005},
	"bottom_flatness": {"min": 0.0, "max": 1.0, "step": 0.005},
	"left_flatness": {"min": 0.0, "max": 1.0, "step": 0.005},
	"right_flatness": {"min": 0.0, "max": 1.0, "step": 0.005},
	"roundness": {"min": 0.0, "max": 1.0, "step": 0.005},
	"sway_weight": {"min": 0.0, "max": 1.5, "step": 0.005}
}

var parameters: Dictionary = {}
var selected_ring_id := ""
var ring_buttons := {}
var ring_list: VBoxContainer
var selected_label: Label
var numeric_sliders := {}
var search_edit: LineEdit
var search_text := ""
var changed_only_check: CheckBox
var show_changed_only := false
var _updating := false

func _ready() -> void:
	add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "선택 링 설정"
	title.add_theme_font_size_override("font_size", 15)
	add_child(title)

	var nav := HBoxContainer.new()
	add_child(nav)
	var previous := Button.new()
	previous.text = "이전 링"
	previous.pressed.connect(select_previous_ring)
	nav.add_child(previous)
	var next := Button.new()
	next.text = "다음 링"
	next.pressed.connect(select_next_ring)
	nav.add_child(next)

	ring_list = VBoxContainer.new()
	ring_list.name = "BodyRingList"
	add_child(ring_list)

	selected_label = Label.new()
	selected_label.text = "링: -"
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(selected_label)

	search_edit = UiRows.add_filter_row(self, UiText.slider_search_placeholder())
	search_edit.text_changed.connect(func(text: String) -> void:
		set_search_text(text)
	)

	changed_only_check = CheckBox.new()
	changed_only_check.text = UiText.changed_only_filter()
	changed_only_check.toggled.connect(func(enabled: bool) -> void:
		show_changed_only = enabled
		_apply_row_filter()
	)
	add_child(changed_only_check)

	for key in RING_NUMERIC_KEYS.keys():
		_add_numeric_row(key)

	var actions := HBoxContainer.new()
	add_child(actions)
	var reset := Button.new()
	reset.text = "링 초기화"
	reset.pressed.connect(reset_selected_ring)
	actions.add_child(reset)
	var duplicate := Button.new()
	duplicate.text = "복제"
	duplicate.pressed.connect(duplicate_selected_ring)
	actions.add_child(duplicate)

	var structural := HBoxContainer.new()
	add_child(structural)
	var add_ring := Button.new()
	add_ring.text = "새 링 추가"
	add_ring.pressed.connect(add_ring_after_selected)
	structural.add_child(add_ring)
	var delete_ring := Button.new()
	delete_ring.text = "링 삭제"
	delete_ring.pressed.connect(delete_selected_ring)
	structural.add_child(delete_ring)

	_refresh_controls()

func set_parameters(new_parameters: Dictionary) -> void:
	parameters = new_parameters.duplicate(true)
	parameters["body_profile"] = BodyProfileScript.ensure_body_profile(parameters)
	var rings := _rings()
	if selected_ring_id == "" and not rings.is_empty():
		selected_ring_id = String(rings[0].get("id", ""))
	if BodyProfileScript.find_ring_index(rings, selected_ring_id) < 0 and not rings.is_empty():
		selected_ring_id = String(rings[0].get("id", ""))
	_refresh_controls()

func set_search_text(text: String) -> void:
	search_text = text
	if search_edit != null and search_edit.text != search_text:
		search_edit.text = search_text
	_apply_row_filter()

func select_ring_by_id(ring_id: String) -> void:
	if BodyProfileScript.find_ring_index(_rings(), ring_id) < 0:
		return
	selected_ring_id = ring_id
	parameters["selected_body_ring_id"] = selected_ring_id
	ring_selected.emit(selected_ring_id)
	_emit_and_refresh()

func select_previous_ring() -> void:
	var rings := _rings()
	var index := BodyProfileScript.find_ring_index(rings, selected_ring_id)
	if index < 0:
		return
	select_ring_by_id(String(rings[maxi(index - 1, 0)].get("id", "")))

func select_next_ring() -> void:
	var rings := _rings()
	var index := BodyProfileScript.find_ring_index(rings, selected_ring_id)
	if index < 0:
		return
	select_ring_by_id(String(rings[mini(index + 1, rings.size() - 1)].get("id", "")))

func set_ring_parameter(key: String, value: float) -> void:
	if not RING_NUMERIC_KEYS.has(key):
		return
	var index := BodyProfileScript.find_ring_index(_rings(), selected_ring_id)
	if index < 0:
		return
	var config: Dictionary = RING_NUMERIC_KEYS[key]
	var rings := _rings()
	var clamped := clampf(value, float(config["min"]), float(config["max"]))
	if key == "width":
		rings[index]["width"] = clamped
		rings[index]["top_width"] = clamped
		rings[index]["bottom_width"] = clamped
	else:
		rings[index][key] = clamped
		if key == "top_width" or key == "bottom_width":
			rings[index]["width"] = (float(rings[index].get("top_width", clamped)) + float(rings[index].get("bottom_width", clamped))) * 0.5
	parameters["body_profile"]["rings"] = rings
	_emit_and_refresh()

func reset_selected_ring() -> void:
	var index := BodyProfileScript.find_ring_index(_rings(), selected_ring_id)
	if index < 0:
		return
	var defaults := BodyProfileScript.default_fish_rings()
	var rings := _rings()
	rings[index] = defaults[mini(index, defaults.size() - 1)].duplicate(true)
	selected_ring_id = String(rings[index].get("id", ""))
	parameters["body_profile"]["rings"] = rings
	parameters["selected_body_ring_id"] = selected_ring_id
	_emit_and_refresh()

func duplicate_selected_ring() -> void:
	var index := BodyProfileScript.find_ring_index(_rings(), selected_ring_id)
	if index < 0:
		return
	var rings := _rings()
	var clone: Dictionary = rings[index].duplicate(true)
	clone["id"] = "%s_copy" % String(clone.get("id", "ring"))
	clone["label"] = "%s 복사본" % String(clone.get("label", "링"))
	clone["x"] = clampf(float(clone.get("x", 0.5)) + 0.035, 0.0, 1.0)
	rings.insert(index + 1, clone)
	_sort_rings_by_x(rings)
	selected_ring_id = String(clone["id"])
	parameters["body_profile"]["rings"] = rings
	parameters["selected_body_ring_id"] = selected_ring_id
	ring_selected.emit(selected_ring_id)
	_emit_and_refresh()

func add_ring_after_selected() -> void:
	var rings := _rings()
	if rings.is_empty():
		parameters["body_profile"]["rings"] = BodyProfileScript.default_fish_rings()
		selected_ring_id = String(_rings()[0].get("id", ""))
		_emit_and_refresh()
		return
	var index := BodyProfileScript.find_ring_index(rings, selected_ring_id)
	index = maxi(index, 0)
	var source: Dictionary = rings[index].duplicate(true)
	var next_x := 1.0 if index >= rings.size() - 1 else float(rings[index + 1].get("x", 1.0))
	source["id"] = "ring_%d" % Time.get_ticks_msec()
	source["label"] = "새 링"
	source["x"] = clampf((float(source.get("x", 0.5)) + next_x) * 0.5, 0.0, 1.0)
	rings.insert(index + 1, source)
	_sort_rings_by_x(rings)
	selected_ring_id = String(source["id"])
	parameters["body_profile"]["rings"] = rings
	parameters["selected_body_ring_id"] = selected_ring_id
	ring_selected.emit(selected_ring_id)
	_emit_and_refresh()

func delete_selected_ring() -> void:
	var rings := _rings()
	if rings.size() <= BodyProfileScript.MIN_RING_COUNT:
		return
	var index := BodyProfileScript.find_ring_index(rings, selected_ring_id)
	if index < 0:
		return
	rings.remove_at(index)
	var next_index := mini(index, rings.size() - 1)
	selected_ring_id = String(rings[next_index].get("id", ""))
	parameters["body_profile"]["rings"] = rings
	parameters["selected_body_ring_id"] = selected_ring_id
	ring_selected.emit(selected_ring_id)
	_emit_and_refresh()

func _add_numeric_row(key: String) -> void:
	var config: Dictionary = RING_NUMERIC_KEYS[key]
	var widgets := UiRows.add_labeled_slider(self, UiText.ring_parameter(key), {
		"label_width": 120,
		"min": float(config["min"]),
		"max": float(config["max"]),
		"step": float(config["step"]),
	})
	var slider := widgets["slider"] as HSlider
	var value_label := widgets["value_label"] as Label
	widgets["label"] = value_label
	numeric_sliders[key] = widgets
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%.2f" % value
		UiRows.update_changed_marker(widgets)
		_apply_row_filter()
		if not _updating:
			numeric_slider_changed.emit(key)
			set_ring_parameter(key, value)
	)

func _refresh_controls() -> void:
	if ring_list == null:
		return
	_updating = true
	for child in ring_list.get_children():
		child.queue_free()
	ring_buttons.clear()
	for ring in _rings():
		var button := Button.new()
		var ring_id := String(ring.get("id", ""))
		button.text = UiText.body_ring(ring_id, String(ring.get("label", ring.get("id", "ring"))))
		button.toggle_mode = true
		button.button_pressed = ring_id == selected_ring_id
		button.pressed.connect(func() -> void: select_ring_by_id(ring_id))
		ring_list.add_child(button)
		ring_buttons[ring_id] = button

	var ring := _selected_ring()
	var default_ring := _default_ring(selected_ring_id)
	selected_label.text = "링: %s" % UiText.body_ring(String(ring.get("id", "")), String(ring.get("label", "-")))
	for key in numeric_sliders.keys():
		var widgets: Dictionary = numeric_sliders[key]
		var slider := widgets["slider"] as HSlider
		var label := widgets["label"] as Label
		var value := float(ring.get(key, 0.0))
		if default_ring.has(key):
			UiRows.set_row_default(widgets, float(default_ring[key]))
		else:
			UiRows.clear_row_default(widgets)
		slider.value = value
		label.text = "%.2f" % value
		UiRows.update_changed_marker(widgets)
	_updating = false
	_apply_row_filter()

func _emit_and_refresh() -> void:
	parameters["body_profile"] = BodyProfileScript.ensure_body_profile(parameters)
	parameters["selected_body_ring_id"] = selected_ring_id
	parameters_changed.emit(parameters.duplicate(true))
	_refresh_controls()

func _selected_ring() -> Dictionary:
	for ring in _rings():
		if String(ring.get("id", "")) == selected_ring_id:
			return ring
	return {}

func is_row_changed(key: String) -> bool:
	if not numeric_sliders.has(key):
		return false
	return UiRows.is_changed_from_default(numeric_sliders[key])

func _default_ring(ring_id: String) -> Dictionary:
	for ring in BodyProfileScript.default_fish_rings():
		if String(ring.get("id", "")) == ring_id:
			return ring
	return {}

func _apply_row_filter() -> void:
	for key in numeric_sliders.keys():
		var widgets: Dictionary = numeric_sliders[key]
		var row := widgets.get("row") as Control
		if row == null:
			continue
		row.visible = _row_matches_filter(widgets)

func _row_matches_filter(widgets: Dictionary) -> bool:
	if show_changed_only and not UiRows.is_changed_from_default(widgets):
		return false
	var query := search_text.strip_edges()
	if query == "":
		return true
	var name_label := widgets.get("name_label") as Label
	return name_label != null and name_label.text.contains(query)

func _rings() -> Array:
	if not parameters.has("body_profile"):
		parameters["body_profile"] = BodyProfileScript.ensure_body_profile(parameters)
	var body_profile: Dictionary = parameters["body_profile"]
	return body_profile.get("rings", [])

func _sort_rings_by_x(rings: Array) -> void:
	rings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("x", 0.0)) < float(b.get("x", 0.0))
	)
