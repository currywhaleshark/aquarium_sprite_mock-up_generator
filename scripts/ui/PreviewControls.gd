class_name PreviewControls
extends VBoxContainer

signal camera_preset_changed(preset_name: String)

const CameraPresetScript := preload("res://scripts/render/CameraPreset.gd")
const UiText := preload("res://scripts/ui/UiText.gd")

var option: OptionButton

func _ready() -> void:
	var label := Label.new()
	label.text = "카메라"
	add_child(label)
	option = OptionButton.new()
	for preset_name in CameraPresetScript.names():
		option.add_item(UiText.camera_preset(preset_name))
		option.set_item_metadata(option.item_count - 1, preset_name)
	option.item_selected.connect(func(index: int) -> void:
		camera_preset_changed.emit(String(option.get_item_metadata(index)))
	)
	add_child(option)

func select_preset(preset_name: String) -> void:
	if option == null:
		return
	for i in option.item_count:
		if String(option.get_item_metadata(i)) == preset_name:
			option.select(i)
			return
