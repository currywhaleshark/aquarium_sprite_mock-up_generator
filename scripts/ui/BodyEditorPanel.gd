class_name BodyEditorPanel
extends VBoxContainer

signal parameters_changed(parameters: Dictionary)
signal ring_selected(ring_id: String)

const UiText := preload("res://scripts/ui/UiText.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")

const RING_NUMERIC_KEYS := {
	"x": {"min": 0.0, "max": 1.0, "step": 0.005},
	"y_offset": {"min": -0.8, "max": 0.8, "step": 0.005},
	"upper_height": {"min": 0.02, "max": 1.4, "step": 0.005},
	"lower_height": {"min": 0.02, "max": 1.4, "step": 0.005},
	"width": {"min": 0.02, "max": 1.2, "step": 0.005},
	"roundness": {"min": 0.0, "max": 1.0, "step": 0.005},
	"sway_weight": {"min": 0.0, "max": 1.5, "step": 0.005}
}

var parameters: Dictionary = {}
var selected_ring_id := ""
var ring_buttons := {}
var ring_list: VBoxContainer
var selected_label: Label
var numeric_sliders := {}
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
	rings[index][key] = clampf(value, float(config["min"]), float(config["max"]))
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
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 28)
	var label := Label.new()
	label.text = UiText.ring_parameter(key)
	label.custom_minimum_size = Vector2(120, 0)
	label.clip_text = true
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = float(config["min"])
	slider.max_value = float(config["max"])
	slider.step = float(config["step"])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(44, 0)
	row.add_child(value_label)
	numeric_sliders[key] = {"slider": slider, "label": value_label}
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%.2f" % value
		if not _updating:
			set_ring_parameter(key, value)
	)
	add_child(row)

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
	selected_label.text = "링: %s" % UiText.body_ring(String(ring.get("id", "")), String(ring.get("label", "-")))
	for key in numeric_sliders.keys():
		var widgets: Dictionary = numeric_sliders[key]
		var slider := widgets["slider"] as HSlider
		var label := widgets["label"] as Label
		var value := float(ring.get(key, 0.0))
		slider.value = value
		label.text = "%.2f" % value
	_updating = false

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

func _rings() -> Array:
	if not parameters.has("body_profile"):
		parameters["body_profile"] = BodyProfileScript.ensure_body_profile(parameters)
	var body_profile: Dictionary = parameters["body_profile"]
	return body_profile.get("rings", [])

func _sort_rings_by_x(rings: Array) -> void:
	rings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("x", 0.0)) < float(b.get("x", 0.0))
	)
