class_name PreviewControls
extends VBoxContainer

signal camera_preset_changed(preset_name: String)

const CameraPresetScript := preload("res://scripts/render/CameraPreset.gd")

var option: OptionButton

func _ready() -> void:
	var label := Label.new()
	label.text = "Camera"
	add_child(label)
	option = OptionButton.new()
	for preset_name in CameraPresetScript.names():
		option.add_item(preset_name)
	option.item_selected.connect(func(index: int) -> void:
		camera_preset_changed.emit(option.get_item_text(index))
	)
	add_child(option)

func select_preset(preset_name: String) -> void:
	if option == null:
		return
	for i in option.item_count:
		if option.get_item_text(i) == preset_name:
			option.select(i)
			return
