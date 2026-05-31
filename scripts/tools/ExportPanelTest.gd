extends Node

const ExportPanelScript := preload("res://scripts/ui/ExportPanel.gd")

func _ready() -> void:
	var panel := ExportPanelScript.new()
	add_child(panel)
	await get_tree().process_frame

	assert(panel.get_direction_count() == 1)
	panel.set_direction_count(8)
	assert(panel.get_direction_count() == 8)
	panel.set_direction_count(1)
	assert(panel.get_direction_count() == 1)

	var file := FileAccess.open("res://exports/test_results/export_panel.ok", FileAccess.WRITE)
	file.store_string("export panel direction count toggle verified")
	file.close()
	print("EXPORT_PANEL_TEST_OK")
	get_tree().quit(0)
