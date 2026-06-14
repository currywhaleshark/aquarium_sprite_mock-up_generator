extends Node

const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const MainScript := preload("res://scripts/ui/Main.gd")
const MarkingLayerEditorScript := preload("res://scripts/ui/MarkingLayerEditor.gd")
const UiText := preload("res://scripts/ui/UiText.gd")

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)

func _ready() -> void:
	_assert_equal(UiText.option("skate"), "스케이트형", "ray disc option should be Korean")
	_assert_equal(UiText.parameter("wing_length"), "날개 길이", "ray wing length label should be Korean")
	_assert_equal(UiText.parameter("fin_ray_count"), "기조 수", "fin ray count label should be Korean")
	_assert_equal(UiText.parameter("fin_opacity"), "지느러미 투명도", "fin opacity label should be Korean")

	var layer_editor := MarkingLayerEditorScript.new()
	add_child(layer_editor)
	layer_editor.set_layers([
		{"type": "lateral_line", "region": "flank", "blend_mode": "multiply", "color": "#ffffff", "intensity": 0.5, "x_start": 0.0, "x_end": 1.0, "thickness": 0.1}
	])
	var layer_row := layer_editor.get_node_or_null("Layer_0") as HBoxContainer
	if layer_row == null:
		_fail("marking layer row was not created")
		return
	var type_option := layer_row.get_child(0) as OptionButton
	var region_option := layer_row.get_child(1) as OptionButton
	var blend_option := layer_row.get_child(2) as OptionButton
	_assert_equal(type_option.get_item_text(0), "측선", "marking layer type should be Korean")
	_assert_equal(region_option.get_item_text(2), "옆면", "marking layer region should be Korean")
	_assert_equal(blend_option.get_item_text(1), "곱하기", "marking blend mode should be Korean")
	var color_picker := layer_row.get_child(3) as ColorPickerButton
	_assert_equal(color_picker.tooltip_text, "색상", "marking color tooltip should be Korean")
	var remove_button := layer_row.get_child(layer_row.get_child_count() - 1) as Button
	_assert_equal(remove_button.tooltip_text, "레이어 제거", "remove layer tooltip should be Korean")

	var main := MainScript.new()
	add_child(main)
	await get_tree().process_frame
	var archetype_option := main.get("archetype_option") as OptionButton
	if archetype_option == null:
		_fail("archetype option was not created")
		return
	_assert_equal(archetype_option.get_item_text(0), "일반 물고기", "generic archetype label should be Korean")
	var angelfish_index := _find_archetype_index(archetype_option, "angelfish")
	if angelfish_index < 0:
		_fail("angelfish archetype option was not found")
		return
	_assert_equal(archetype_option.get_item_text(angelfish_index), "엔젤피시", "archetype label should be Korean")
	archetype_option.select(angelfish_index)
	main.call("_on_archetype_selected", angelfish_index)
	var read_label := main.get("archetype_read_label") as Label
	if read_label == null:
		_fail("archetype readability label was not created")
		return
	if not read_label.text.contains("높고 납작한 체형") or read_label.text.contains("deep compressed body"):
		_fail("archetype readability priorities should be Korean, got: %s" % read_label.text)
		return

	var rig := FishRigScript.new()
	add_child(rig)
	rig.set_parameters({"body_profile": {"rings": BodyProfileScript.default_fish_rings()}, "creature_type": "fish"})
	_assert_equal(rig.call("_ring_label_by_id", "front_body", "Ring"), "앞몸통", "3D ring guide label should be Korean")

	rig.queue_free()
	main.queue_free()
	layer_editor.queue_free()
	await get_tree().process_frame
	print("UI_KOREAN_LABELS_TEST_OK")
	get_tree().quit(0)

func _find_archetype_index(option: OptionButton, archetype_id: String) -> int:
	for i in option.item_count:
		if String(option.get_item_metadata(i)) == archetype_id:
			return i
	return -1

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s: expected '%s', got '%s'" % [message, expected, actual])
