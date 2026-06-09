extends Node

const MainScript := preload("res://scripts/ui/Main.gd")

func _ready() -> void:
	var main := MainScript.new()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var poppables: Dictionary = main.get("poppables")
	assert(poppables.has("color"))
	assert(poppables.has("motion"))

	# The same pop-out/dock contract must hold for every poppable panel.
	await _exercise(poppables["color"], main.get("color_panel"))
	await _exercise(poppables["motion"], main.get("motion_panel"))

	# The regional marking editor lives inside the colour panel and is reachable in
	# the tree whether the panel is docked or detached.
	assert(main.find_child("RegionalMarkingLayerEditor", true, false) != null)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/color_panel_popout.ok", FileAccess.WRITE)
	file.store_string("colour and motion panels pop out to windows and dock back")
	file.close()
	print("COLOR_PANEL_POPOUT_TEST_OK")
	get_tree().quit(0)

func _exercise(p: Object, panel: Control) -> void:
	assert(p != null)
	assert(panel != null)

	# Starts docked in its tab; window hidden, notice off, pop-out button shown.
	assert(panel.get_parent() == p.dock)
	assert(not p.window.visible)
	assert(p.popout_button.visible)
	assert(not p.dock_notice.visible)

	# Pop out: panel reparents into the window, the tab shows the re-dock notice.
	p.pop_out()
	await get_tree().process_frame
	assert(panel.get_parent() == p.window_body)
	assert(p.window.visible)
	assert(not p.popout_button.visible)
	assert(p.dock_notice.visible)

	# Parameters still flow to the panel while detached.
	panel.set_parameters({"base_color": "#123456", "swim_mode": "general", "marking_layers": []})
	await get_tree().process_frame
	assert(panel.get_parent() == p.window_body)

	# Pop-out is idempotent (no duplicate reparent / crash).
	p.pop_out()
	await get_tree().process_frame
	assert(panel.get_parent() == p.window_body)

	# Dock back: panel returns to its tab and the window hides.
	p.dock_back()
	await get_tree().process_frame
	assert(panel.get_parent() == p.dock)
	assert(not p.window.visible)
	assert(p.popout_button.visible)
	assert(not p.dock_notice.visible)
