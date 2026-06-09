extends Node

const MainScript := preload("res://scripts/ui/Main.gd")

func _ready() -> void:
	var main := MainScript.new()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var color_panel: Control = main.get("color_panel")
	var dock: Node = main.get("color_panel_dock")
	var window: Window = main.get("color_panel_window")
	var window_body: Node = main.get("color_panel_window_body")
	var popout_button: Button = main.get("color_panel_popout_button")
	var dock_notice: Control = main.get("color_panel_dock_notice")
	assert(color_panel != null)
	assert(dock != null)
	assert(window != null)
	assert(window_body != null)
	assert(popout_button != null)
	assert(dock_notice != null)

	# Starts docked in the colour tab; the window is hidden and the notice is off.
	assert(color_panel.get_parent() == dock)
	assert(not window.visible)
	assert(popout_button.visible)
	assert(not dock_notice.visible)

	# Pop out: the panel reparents into the window, the tab shows the re-dock notice.
	main.call("_pop_out_color_panel")
	await get_tree().process_frame
	assert(color_panel.get_parent() == window_body)
	assert(window.visible)
	assert(not popout_button.visible)
	assert(dock_notice.visible)

	# Parameters still flow to the panel while it is detached.
	color_panel.set_parameters({"base_color": "#123456", "belly_color": "#654321", "marking_layers": []})
	await get_tree().process_frame
	assert(color_panel.get_parent() == window_body)
	assert(main.find_child("RegionalMarkingLayerEditor", true, false) != null)

	# Calling pop-out again is idempotent (no duplicate reparent / crash).
	main.call("_pop_out_color_panel")
	await get_tree().process_frame
	assert(color_panel.get_parent() == window_body)

	# Dock back: the panel returns to the tab and the window hides.
	main.call("_dock_color_panel")
	await get_tree().process_frame
	assert(color_panel.get_parent() == dock)
	assert(not window.visible)
	assert(popout_button.visible)
	assert(not dock_notice.visible)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/color_panel_popout.ok", FileAccess.WRITE)
	file.store_string("colour panel pops out to a window and docks back")
	file.close()
	print("COLOR_PANEL_POPOUT_TEST_OK")
	get_tree().quit(0)
