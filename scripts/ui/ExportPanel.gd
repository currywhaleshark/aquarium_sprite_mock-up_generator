class_name ExportPanel
extends VBoxContainer

signal export_requested

var status_label: Label

func _ready() -> void:
	var button := Button.new()
	button.text = "Export PNG + Sheet"
	button.pressed.connect(func() -> void: export_requested.emit())
	add_child(button)
	status_label = Label.new()
	status_label.text = "Ready"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)

func set_status(text: String) -> void:
	if status_label:
		status_label.text = text
