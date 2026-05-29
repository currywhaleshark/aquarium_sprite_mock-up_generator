extends Control

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const RayRigScript := preload("res://scripts/creature/RayRig.gd")
const ParameterPanelScript := preload("res://scripts/ui/ParameterPanel.gd")
const ExportPanelScript := preload("res://scripts/ui/ExportPanel.gd")
const PreviewControlsScript := preload("res://scripts/ui/PreviewControls.gd")
const PreviewCameraControllerScript := preload("res://scripts/ui/PreviewCameraController.gd")
const FishFinDragControllerScript := preload("res://scripts/ui/FishFinDragController.gd")
const FinEditorPanelScript := preload("res://scripts/ui/FinEditorPanel.gd")
const HeadEditorPanelScript := preload("res://scripts/ui/HeadEditorPanel.gd")
const BodyEditorPanelScript := preload("res://scripts/ui/BodyEditorPanel.gd")
const SpriteExporterScript := preload("res://scripts/export/SpriteExporter.gd")
const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")
const CameraPresetScript := preload("res://scripts/render/CameraPreset.gd")

var viewport: SubViewport
var viewport_container: SubViewportContainer
var camera: Camera3D
var camera_controller: Node
var fin_drag_controller: Node
var world_root: Node3D
var current_rig: Node3D
var presets: Array[Dictionary] = []
var current_preset: Dictionary = {}
var preset_option: OptionButton
var parameter_panel: ScrollContainer
var export_panel: VBoxContainer
var mini_preview: TextureRect
var display_label: Label
var fin_edit_toggle: CheckButton
var fin_editor_panel: VBoxContainer
var head_edit_toggle: CheckButton
var head_editor_panel: VBoxContainer
var body_edit_toggle: CheckButton
var body_editor_panel: VBoxContainer
var exporter: Node

func _ready() -> void:
	_build_ui()
	_build_preview_world()
	exporter = SpriteExporterScript.new()
	add_child(exporter)
	exporter.export_finished.connect(func(path: String) -> void: export_panel.set_status("Exported: %s" % path))
	exporter.export_failed.connect(func(message: String) -> void: export_panel.set_status(message))
	presets = PresetStoreScript.load_all()
	for preset in presets:
		preset_option.add_item(String(preset.get("name", "unnamed")))
	if not presets.is_empty():
		_load_preset(0)

func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.name = "RootLayout"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var preview_column := VBoxContainer.new()
	preview_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(preview_column)

	viewport_container = SubViewportContainer.new()
	viewport_container.name = "ViewportContainer"
	viewport_container.stretch = true
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_column.add_child(viewport_container)

	viewport = SubViewport.new()
	viewport.name = "PreviewViewport"
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	var lower_preview := HBoxContainer.new()
	preview_column.add_child(lower_preview)
	display_label = Label.new()
	display_label.text = "Display preview"
	lower_preview.add_child(display_label)
	mini_preview = TextureRect.new()
	mini_preview.texture = viewport.get_texture()
	mini_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mini_preview.custom_minimum_size = Vector2(144, 96)
	lower_preview.add_child(mini_preview)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(360, 0)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(side)

	var title := Label.new()
	title.text = "Procedural Sprite Generator"
	title.add_theme_font_size_override("font_size", 18)
	side.add_child(title)

	preset_option = OptionButton.new()
	preset_option.item_selected.connect(_load_preset)
	side.add_child(preset_option)

	var controls := PreviewControlsScript.new()
	controls.camera_preset_changed.connect(func(preset_name: String) -> void:
		current_preset["camera_preset"] = preset_name
		_apply_camera()
	)
	side.add_child(controls)

	fin_edit_toggle = CheckButton.new()
	fin_edit_toggle.text = "Fin Edit"
	fin_edit_toggle.toggled.connect(_set_fin_edit_enabled)
	side.add_child(fin_edit_toggle)

	fin_editor_panel = FinEditorPanelScript.new()
	fin_editor_panel.visible = false
	fin_editor_panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	side.add_child(fin_editor_panel)

	head_edit_toggle = CheckButton.new()
	head_edit_toggle.text = "Head Edit"
	head_edit_toggle.toggled.connect(_set_head_edit_enabled)
	side.add_child(head_edit_toggle)

	head_editor_panel = HeadEditorPanelScript.new()
	head_editor_panel.visible = false
	head_editor_panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	side.add_child(head_editor_panel)

	body_edit_toggle = CheckButton.new()
	body_edit_toggle.text = "Body Edit"
	body_edit_toggle.toggled.connect(_set_body_edit_enabled)
	side.add_child(body_edit_toggle)

	body_editor_panel = BodyEditorPanelScript.new()
	body_editor_panel.visible = false
	body_editor_panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	side.add_child(body_editor_panel)

	parameter_panel = ParameterPanelScript.new()
	parameter_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parameter_panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	side.add_child(parameter_panel)

	export_panel = ExportPanelScript.new()
	export_panel.export_requested.connect(_export_current)
	side.add_child(export_panel)

func _build_preview_world() -> void:
	world_root = Node3D.new()
	world_root.name = "WorldRoot"
	viewport.add_child(world_root)

	var light := DirectionalLight3D.new()
	light.name = "KeyLight"
	light.light_energy = 2.1
	light.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	world_root.add_child(light)

	var fill := OmniLight3D.new()
	fill.name = "SoftFill"
	fill.light_energy = 0.45
	fill.position = Vector3(-1.2, 1.1, 2.0)
	world_root.add_child(fill)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	viewport.add_child(camera)
	viewport.world_3d = World3D.new()
	camera_controller = PreviewCameraControllerScript.new()
	camera_controller.name = "PreviewCameraController"
	add_child(camera_controller)
	camera_controller.call("bind_camera", camera)
	camera_controller.call("bind_input_control", viewport_container)
	fin_drag_controller = FishFinDragControllerScript.new()
	fin_drag_controller.name = "FishFinDragController"
	add_child(fin_drag_controller)
	fin_drag_controller.call("bind_camera", camera)
	fin_drag_controller.call("bind_input_control", viewport_container)
	fin_drag_controller.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	_apply_camera()

func _load_preset(index: int) -> void:
	if index < 0 or index >= presets.size():
		return
	current_preset = presets[index].duplicate(true)
	if current_rig:
		current_rig.queue_free()
	var creature_type := String(current_preset.get("creature_type", "fish"))
	if creature_type == "ray":
		current_rig = RayRigScript.new()
	else:
		current_rig = FishRigScript.new()
	current_rig.name = "ActiveRig"
	world_root.add_child(current_rig)
	current_rig.call("set_parameters", current_preset.get("parameters", {}))
	_bind_fin_editor_for_current_rig()
	parameter_panel.set_parameters(current_preset.get("parameters", {}))
	if fin_editor_panel:
		fin_editor_panel.call("set_parameters", current_preset.get("parameters", {}))
	if head_editor_panel:
		head_editor_panel.call("set_parameters", current_preset.get("parameters", {}))
	if body_editor_panel:
		body_editor_panel.call("set_parameters", current_preset.get("parameters", {}))
	_apply_camera()
	_update_display_preview_label()
	export_panel.set_status("Loaded %s" % String(current_preset.get("name", "unnamed")))

func _apply_parameters_from_editor(parameters: Dictionary) -> void:
	var synced_parameters := parameters.duplicate(true)
	current_preset["parameters"] = synced_parameters
	if current_rig:
		current_rig.call("set_parameters", synced_parameters)
	_sync_parameter_editors(synced_parameters)

func _sync_parameter_editors(parameters: Dictionary) -> void:
	if parameter_panel:
		parameter_panel.call("set_parameters", parameters)
	if fin_editor_panel:
		fin_editor_panel.call("set_parameters", parameters)
	if head_editor_panel:
		head_editor_panel.call("set_parameters", parameters)
	if body_editor_panel:
		body_editor_panel.call("set_parameters", parameters)

func _bind_fin_editor_for_current_rig() -> void:
	if fin_drag_controller == null:
		return
	if String(current_preset.get("creature_type", "fish")) == "fish":
		fin_drag_controller.call("bind_fish", current_rig)
		if fin_edit_toggle:
			fin_edit_toggle.disabled = false
		if head_edit_toggle:
			head_edit_toggle.disabled = false
		if body_edit_toggle:
			body_edit_toggle.disabled = false
	else:
		fin_drag_controller.call("bind_fish", null)
		if fin_edit_toggle:
			fin_edit_toggle.button_pressed = false
			fin_edit_toggle.disabled = true
		if head_edit_toggle:
			head_edit_toggle.button_pressed = false
			head_edit_toggle.disabled = true
		if body_edit_toggle:
			body_edit_toggle.button_pressed = false
			body_edit_toggle.disabled = true

func _apply_camera() -> void:
	if camera == null:
		return
	var preset_name := String(current_preset.get("camera_preset", "aquarium_side_quarter"))
	var overrides := {
		"yaw": current_preset.get("camera_yaw", CameraPresetScript.get_preset(preset_name).get("yaw")),
		"pitch": current_preset.get("camera_pitch", CameraPresetScript.get_preset(preset_name).get("pitch")),
		"roll": current_preset.get("camera_roll", CameraPresetScript.get_preset(preset_name).get("roll")),
		"orthographic_size": current_preset.get("orthographic_size", CameraPresetScript.get_preset(preset_name).get("orthographic_size"))
	}
	var preset := CameraPresetScript.get_preset(preset_name)
	for key in overrides.keys():
		preset[key] = overrides[key]
	if camera_controller:
		camera_controller.call("reset_from_preset", preset)
	else:
		CameraPresetScript.apply_to_camera(camera, preset_name, overrides)

func _update_display_preview_label() -> void:
	var display_size: Dictionary = current_preset.get("display_target_size", {"w": 18, "h": 10})
	display_label.text = "Target display: %dx%d, anchor center" % [int(display_size.get("w", 18)), int(display_size.get("h", 10))]
	mini_preview.custom_minimum_size = Vector2(maxi(96, int(display_size.get("w", 18)) * 4), maxi(64, int(display_size.get("h", 10)) * 4))

func _export_current() -> void:
	if current_rig == null or current_preset.is_empty():
		return
	export_panel.set_status("Exporting...")
	await exporter.export_preset(current_preset, current_rig, viewport)

func _set_fin_edit_enabled(enabled: bool) -> void:
	if fin_drag_controller:
		fin_drag_controller.call("set_enabled", enabled)
	if fin_editor_panel:
		fin_editor_panel.visible = enabled and String(current_preset.get("creature_type", "fish")) == "fish"
	if enabled and head_edit_toggle:
		head_edit_toggle.button_pressed = false
	if enabled and body_edit_toggle:
		body_edit_toggle.button_pressed = false
	_sync_edit_input_state()

func _set_head_edit_enabled(enabled: bool) -> void:
	if head_editor_panel:
		head_editor_panel.visible = enabled and String(current_preset.get("creature_type", "fish")) == "fish"
	if enabled and fin_edit_toggle:
		fin_edit_toggle.button_pressed = false
	if enabled and body_edit_toggle:
		body_edit_toggle.button_pressed = false
	_sync_edit_input_state()

func _set_body_edit_enabled(enabled: bool) -> void:
	if body_editor_panel:
		body_editor_panel.visible = enabled and String(current_preset.get("creature_type", "fish")) == "fish"
	if enabled and fin_edit_toggle:
		fin_edit_toggle.button_pressed = false
	if enabled and head_edit_toggle:
		head_edit_toggle.button_pressed = false
	_sync_edit_input_state()

func _sync_edit_input_state() -> void:
	var editing := false
	if fin_edit_toggle and fin_edit_toggle.button_pressed:
		editing = true
	if head_edit_toggle and head_edit_toggle.button_pressed:
		editing = true
	if body_edit_toggle and body_edit_toggle.button_pressed:
		editing = true
	if camera_controller:
		camera_controller.set("input_enabled", not editing)
