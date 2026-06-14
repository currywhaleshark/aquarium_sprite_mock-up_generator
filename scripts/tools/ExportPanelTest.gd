extends Node

const ExportPanelScript := preload("res://scripts/ui/ExportPanel.gd")

func _ready() -> void:
	var panel := ExportPanelScript.new()
	add_child(panel)
	await get_tree().process_frame

	assert(panel.get_direction_count() == 1)
	assert(not panel.get_include_turn_clips())
	panel.set_direction_count(8)
	assert(panel.get_direction_count() == 8)
	panel.set_include_turn_clips(true)
	assert(panel.get_include_turn_clips())
	panel.set_direction_count(1)
	assert(panel.get_direction_count() == 1)
	assert(not panel.get_include_turn_clips())
	panel.set_include_turn_clips(false)
	assert(not panel.get_include_turn_clips())

	var file := FileAccess.open("res://exports/test_results/export_panel.ok", FileAccess.WRITE)
	file.store_string("export panel direction count toggle verified")
	file.close()
	print("EXPORT_PANEL_TEST_OK")
	get_tree().quit(0)
