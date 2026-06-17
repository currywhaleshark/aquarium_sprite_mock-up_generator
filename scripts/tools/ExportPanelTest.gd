extends Node

const ExportPanelScript := preload("res://scripts/ui/ExportPanel.gd")

func _ready() -> void:
	var panel := ExportPanelScript.new()
	add_child(panel)
	var refresh_requests := [0]
	panel.stylize_preview_refresh_requested.connect(func() -> void:
		refresh_requests[0] += 1
	)
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
	assert(panel.get_stylize_enabled())
	assert(absf(panel.get_stylize_color_strength() - 1.0) < 0.001)
	assert(absf(panel.get_stylize_outline_strength() - 1.0) < 0.001)
	panel.set_stylize_color_strength(1.65)
	panel.set_stylize_outline_strength(0.35)
	assert(absf(panel.get_stylize_color_strength() - 1.65) < 0.001)
	assert(absf(panel.get_stylize_outline_strength() - 0.35) < 0.001)
	panel.set_stylize_color_strength(3.0)
	panel.set_stylize_outline_strength(-1.0)
	assert(absf(panel.get_stylize_color_strength() - 2.0) < 0.001)
	assert(absf(panel.get_stylize_outline_strength() - 0.0) < 0.001)
	var options := panel.get_stylize_options()
	assert(bool(options.get("enabled", false)))
	assert(absf(float(options.get("color_strength", -1.0)) - 2.0) < 0.001)
	assert(absf(float(options.get("outline_strength", -1.0)) - 0.0) < 0.001)
	var preview := panel.get("stylize_preview_texture") as TextureRect
	assert(preview != null)
	assert(preview.texture != null)
	assert(preview.custom_minimum_size.x >= 96.0)
	var refresh_button := panel.get("stylize_preview_refresh_button") as Button
	assert(refresh_button != null)
	panel.request_stylize_preview_refresh()
	assert(refresh_requests[0] == 1)
	var large_preview_source := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	large_preview_source.fill(Color(0.8, 0.3, 0.1, 1.0))
	panel.set_stylize_preview_source(large_preview_source)
	var stored_source := panel.get("stylize_preview_source") as Image
	assert(stored_source != null)
	assert(stored_source.get_width() <= 128)
	assert(stored_source.get_height() <= 128)

	var file := FileAccess.open("res://exports/test_results/export_panel.ok", FileAccess.WRITE)
	file.store_string("export panel direction count toggle verified")
	file.close()
	print("EXPORT_PANEL_TEST_OK")
	get_tree().quit(0)
