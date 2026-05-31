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
const ReferenceImagePanelScript := preload("res://scripts/ui/ReferenceImagePanel.gd")
const SpriteExporterScript := preload("res://scripts/export/SpriteExporter.gd")
const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")
const CameraPresetScript := preload("res://scripts/render/CameraPreset.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
const UiText := preload("res://scripts/ui/UiText.gd")

const TURN_PREVIEW_DURATION := 0.45

var viewport: SubViewport
var preview_stack: Control
var viewport_container: SubViewportContainer
var reference_overlay: TextureRect
var reference_overlay_source_path := ""
var reference_overlay_source_size := Vector2.ZERO
var camera: Camera3D
var camera_controller: Node
var fin_drag_controller: Node
var world_root: Node3D
var current_rig: CreatureRig
var presets: Array[Dictionary] = []
var current_preset: Dictionary = {}
var preset_option: OptionButton
var preset_name_edit: LineEdit
var save_preset_button: Button
var creature_type_label: Label
var playback_toggle: CheckButton
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
var reference_image_panel: VBoxContainer
var exporter: Node
var turn_left_button: Button
var turn_right_button: Button
var preview_direction_index := 0
var turn_preview_active := false
var turn_preview_elapsed := 0.0
var turn_preview_from_index := 0
var turn_preview_target_index := 0
var turn_preview_step := 0

func _ready() -> void:
	_build_ui()
	_build_preview_world()
	exporter = SpriteExporterScript.new()
	add_child(exporter)
	exporter.export_finished.connect(func(path: String) -> void: export_panel.set_status("출력 완료: %s" % path))
	exporter.export_failed.connect(func(message: String) -> void: export_panel.set_status(message))
	_reload_presets()

func _process(delta: float) -> void:
	_update_preview_turn(delta)

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

	preview_stack = Control.new()
	preview_stack.name = "PreviewStack"
	preview_stack.clip_contents = true
	preview_stack.custom_minimum_size = Vector2(512, 512)
	preview_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_stack.resized.connect(_update_reference_overlay_transform)
	preview_column.add_child(preview_stack)

	viewport_container = SubViewportContainer.new()
	viewport_container.name = "ViewportContainer"
	viewport_container.stretch = true
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.gui_input.connect(_on_preview_gui_input)
	preview_stack.add_child(viewport_container)

	viewport = SubViewport.new()
	viewport.name = "PreviewViewport"
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	reference_overlay = TextureRect.new()
	reference_overlay.name = "ReferenceImageOverlay"
	reference_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reference_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reference_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	reference_overlay.visible = false
	preview_stack.add_child(reference_overlay)

	var lower_preview := HBoxContainer.new()
	preview_column.add_child(lower_preview)
	turn_left_button = Button.new()
	turn_left_button.text = "↶ 좌로 선회"
	turn_left_button.pressed.connect(func() -> void: _start_preview_turn(1))
	lower_preview.add_child(turn_left_button)
	turn_right_button = Button.new()
	turn_right_button.text = "↷ 우로 선회"
	turn_right_button.pressed.connect(func() -> void: _start_preview_turn(-1))
	lower_preview.add_child(turn_right_button)
	display_label = Label.new()
	display_label.text = "표시 미리보기"
	lower_preview.add_child(display_label)
	mini_preview = TextureRect.new()
	mini_preview.texture = viewport.get_texture()
	mini_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mini_preview.custom_minimum_size = Vector2(144, 96)
	lower_preview.add_child(mini_preview)

	var side_scroll := ScrollContainer.new()
	side_scroll.name = "SidePanelScroll"
	side_scroll.custom_minimum_size = Vector2(380, 0)
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(side_scroll)

	var side := VBoxContainer.new()
	side.name = "SidePanelContent"
	side.custom_minimum_size = Vector2(360, 0)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(side)

	var title := Label.new()
	title.text = "절차적 스프라이트 생성기"
	title.add_theme_font_size_override("font_size", 18)
	side.add_child(title)

	preset_option = OptionButton.new()
	preset_option.item_selected.connect(_load_preset)
	side.add_child(preset_option)

	var preset_save_row := HBoxContainer.new()
	preset_save_row.add_theme_constant_override("separation", 6)
	side.add_child(preset_save_row)

	preset_name_edit = LineEdit.new()
	preset_name_edit.placeholder_text = "프리셋 이름"
	preset_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_save_row.add_child(preset_name_edit)

	save_preset_button = Button.new()
	save_preset_button.text = "현재 설정 저장"
	save_preset_button.pressed.connect(_save_current_preset)
	preset_save_row.add_child(save_preset_button)

	creature_type_label = Label.new()
	creature_type_label.text = "타입: 물고기"
	side.add_child(creature_type_label)

	playback_toggle = CheckButton.new()
	playback_toggle.text = "애니메이션 재생"
	playback_toggle.button_pressed = true
	playback_toggle.toggled.connect(func(enabled: bool) -> void:
		if current_rig:
			current_rig.auto_animate = enabled
	)
	side.add_child(playback_toggle)

	var controls := PreviewControlsScript.new()
	controls.camera_preset_changed.connect(func(preset_name: String) -> void:
		current_preset["camera_preset"] = preset_name
		_apply_camera()
	)
	side.add_child(controls)

	reference_image_panel = ReferenceImagePanelScript.new()
	reference_image_panel.reference_changed.connect(func(settings: Dictionary) -> void:
		_on_reference_image_changed(settings)
	)
	side.add_child(reference_image_panel)

	fin_edit_toggle = CheckButton.new()
	fin_edit_toggle.text = "지느러미 편집"
	fin_edit_toggle.toggled.connect(_set_fin_edit_enabled)
	side.add_child(fin_edit_toggle)

	fin_editor_panel = FinEditorPanelScript.new()
	fin_editor_panel.visible = false
	fin_editor_panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	side.add_child(fin_editor_panel)

	head_edit_toggle = CheckButton.new()
	head_edit_toggle.text = "머리 편집"
	head_edit_toggle.toggled.connect(_set_head_edit_enabled)
	side.add_child(head_edit_toggle)

	head_editor_panel = HeadEditorPanelScript.new()
	head_editor_panel.visible = false
	head_editor_panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	side.add_child(head_editor_panel)

	body_edit_toggle = CheckButton.new()
	body_edit_toggle.text = "몸통 편집"
	body_edit_toggle.toggled.connect(_set_body_edit_enabled)
	side.add_child(body_edit_toggle)

	body_editor_panel = BodyEditorPanelScript.new()
	body_editor_panel.visible = false
	body_editor_panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	body_editor_panel.ring_selected.connect(func(ring_id: String) -> void:
		var fish_rig := current_rig as FishRig
		if fish_rig:
			fish_rig.set_selected_body_ring(ring_id)
	)
	side.add_child(body_editor_panel)

	parameter_panel = ParameterPanelScript.new()
	parameter_panel.custom_minimum_size = Vector2(0, 240)
	parameter_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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
	fin_drag_controller = FishFinDragControllerScript.new()
	fin_drag_controller.name = "FishFinDragController"
	add_child(fin_drag_controller)
	fin_drag_controller.call("bind_camera", camera)
	fin_drag_controller.call("bind_input_control", viewport_container)
	fin_drag_controller.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	camera_controller.camera_changed.connect(func(_state: Dictionary) -> void:
		_update_reference_overlay_transform()
	)
	camera_controller.call("bind_input_control", viewport_container)
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
	current_rig.set_parameters(current_preset.get("parameters", {}))
	_reset_preview_direction()
	if playback_toggle:
		current_rig.auto_animate = playback_toggle.button_pressed
	_bind_fin_editor_for_current_rig()
	parameter_panel.set_parameters(current_preset.get("parameters", {}))
	if fin_editor_panel:
		fin_editor_panel.call("set_parameters", current_preset.get("parameters", {}))
	if head_editor_panel:
		head_editor_panel.call("set_parameters", current_preset.get("parameters", {}))
	if body_editor_panel:
		body_editor_panel.call("set_parameters", current_preset.get("parameters", {}))
	if preset_name_edit:
		preset_name_edit.text = String(current_preset.get("name", "unnamed"))
	if reference_image_panel:
		reference_image_panel.call("set_reference_settings", current_preset.get("reference_image", _default_reference_image_settings()))
	else:
		_apply_reference_image_settings(current_preset.get("reference_image", _default_reference_image_settings()))
	if export_panel:
		var export_settings: Dictionary = current_preset.get("export_settings", {})
		export_panel.call("set_direction_count", int(export_settings.get("direction_count", 1)))
	_apply_camera()
	_update_display_preview_label()
	_update_creature_type_label()
	export_panel.set_status("%s 불러옴" % UiText.preset_name(String(current_preset.get("name", "unnamed"))))

func _reload_presets(select_path: String = "") -> void:
	presets = PresetStoreScript.load_all()
	preset_option.clear()
	for preset in presets:
		preset_option.add_item(_preset_option_label(preset))
	if presets.is_empty():
		return
	var selected_index := 0
	if select_path != "":
		for i in presets.size():
			if String(presets[i].get("_preset_path", "")) == select_path:
				selected_index = i
				break
	preset_option.select(selected_index)
	_load_preset(selected_index)

func _preset_option_label(preset: Dictionary) -> String:
	var preset_name := String(preset.get("name", "unnamed"))
	if String(preset.get("_preset_source", "")) == "user":
		return "%s (사용자)" % preset_name
	return UiText.preset_name(preset_name)

func _save_current_preset() -> void:
	if current_preset.is_empty():
		return
	var preset_name := preset_name_edit.text.strip_edges() if preset_name_edit else ""
	if preset_name == "":
		preset_name = String(current_preset.get("name", "user_preset"))
	var preset_to_save := current_preset.duplicate(true)
	preset_to_save["name"] = preset_name
	var parameters: Dictionary = preset_to_save.get("parameters", {})
	if not parameters.is_empty():
		preset_to_save = BodyProfileScript.split_parameters_into_profiles(parameters, preset_to_save)
		preset_to_save["name"] = preset_name
	var result: Dictionary = PresetStoreScript.save_user_preset(preset_name, preset_to_save)
	var error := int(result.get("error", FAILED))
	if error != OK:
		export_panel.set_status("프리셋 저장 실패: %s" % error_string(error))
		return
	var saved_path := String(result.get("path", ""))
	_reload_presets(saved_path)
	export_panel.set_status("프리셋 저장 완료: %s" % preset_name)

func _apply_parameters_from_editor(parameters: Dictionary) -> void:
	var synced_parameters := parameters.duplicate(true)
	current_preset["parameters"] = synced_parameters
	current_preset = BodyProfileScript.split_parameters_into_profiles(synced_parameters, current_preset)
	if current_rig:
		current_rig.set_parameters(synced_parameters)
		if playback_toggle:
			current_rig.auto_animate = playback_toggle.button_pressed
		var fish_rig := current_rig as FishRig
		if fish_rig:
			fish_rig.set_ring_editor_enabled(body_edit_toggle != null and body_edit_toggle.button_pressed)
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
		var fish_rig := current_rig as FishRig
		if fish_rig:
			fish_rig.set_ring_editor_enabled(false)
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
	display_label.text = "목표 표시: %dx%d, 중심 기준" % [int(display_size.get("w", 18)), int(display_size.get("h", 10))]
	mini_preview.custom_minimum_size = Vector2(maxi(96, int(display_size.get("w", 18)) * 4), maxi(64, int(display_size.get("h", 10)) * 4))

func _update_creature_type_label() -> void:
	if creature_type_label == null:
		return
	creature_type_label.text = "타입: %s" % UiText.creature_type(String(current_preset.get("creature_type", "fish")))

func _default_reference_image_settings() -> Dictionary:
	return {
		"path": "",
		"visible": false,
		"scale": 1.0,
		"offset_x": 0.0,
		"offset_y": 0.0,
		"opacity": 0.45
	}

func _on_reference_image_changed(settings: Dictionary) -> void:
	var anchored_settings := settings.duplicate(true)
	_stamp_reference_camera_anchor(anchored_settings)
	current_preset["reference_image"] = anchored_settings
	_apply_reference_image_settings(anchored_settings)

func _apply_reference_image_settings(settings: Dictionary) -> void:
	if reference_overlay == null:
		return
	var effective_settings := settings.duplicate(true)
	if not _has_reference_camera_anchor(effective_settings):
		_stamp_reference_camera_anchor(effective_settings)
		current_preset["reference_image"] = effective_settings
	var path := String(effective_settings.get("path", ""))
	var should_show := bool(effective_settings.get("visible", false)) and path != ""
	if not should_show:
		reference_overlay.visible = false
		return
	if path != reference_overlay_source_path:
		_load_reference_overlay_texture(path)
	reference_overlay.visible = reference_overlay.texture != null
	reference_overlay.modulate = Color(1.0, 1.0, 1.0, clampf(float(effective_settings.get("opacity", 0.45)), 0.05, 1.0))
	_update_reference_overlay_transform()

func _load_reference_overlay_texture(path: String) -> void:
	reference_overlay_source_path = path
	reference_overlay_source_size = Vector2.ZERO
	reference_overlay.texture = null
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		export_panel.set_status("레퍼런스 이미지 불러오기 실패: %s" % error_string(err))
		return
	reference_overlay_source_size = Vector2(image.get_width(), image.get_height())
	reference_overlay.texture = ImageTexture.create_from_image(image)

func _update_reference_overlay_transform() -> void:
	if reference_overlay == null or reference_overlay.texture == null:
		return
	var settings: Dictionary = current_preset.get("reference_image", _default_reference_image_settings())
	var scale_value := maxf(float(settings.get("scale", 1.0)), 0.05)
	var source_size := reference_overlay_source_size
	if source_size == Vector2.ZERO:
		source_size = reference_overlay.texture.get_size()
	var anchor_ortho := maxf(float(settings.get("anchor_orthographic_size", _current_orthographic_size())), 0.001)
	var sync_scale := clampf(anchor_ortho / maxf(_current_orthographic_size(), 0.001), 0.05, 12.0)
	var display_size := source_size * scale_value * sync_scale
	var offset := Vector2(float(settings.get("offset_x", 0.0)), float(settings.get("offset_y", 0.0))) * sync_scale
	var center := _world_to_preview_position(Vector3.ZERO) + offset
	reference_overlay.position = center - display_size * 0.5
	reference_overlay.size = display_size

func _has_reference_camera_anchor(settings: Dictionary) -> bool:
	return settings.has("anchor_orthographic_size")

func _stamp_reference_camera_anchor(settings: Dictionary) -> void:
	settings["anchor_orthographic_size"] = _current_orthographic_size()
	var origin := _world_to_preview_position(Vector3.ZERO)
	settings["anchor_origin_x"] = origin.x
	settings["anchor_origin_y"] = origin.y

func _current_orthographic_size() -> float:
	if camera_controller != null and camera_controller.has_method("get_camera_state"):
		var state: Dictionary = camera_controller.call("get_camera_state")
		return maxf(float(state.get("orthographic_size", 1.0)), 0.001)
	if camera != null:
		return maxf(camera.size, 0.001)
	return 1.0

func _world_to_preview_position(world_point: Vector3) -> Vector2:
	if camera == null or viewport == null or viewport_container == null:
		return preview_stack.size * 0.5 if preview_stack != null else Vector2.ZERO
	var screen_point := camera.unproject_position(world_point)
	var viewport_size := Vector2(viewport.size)
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		screen_point *= Vector2(viewport_container.size.x / viewport_size.x, viewport_container.size.y / viewport_size.y)
	return screen_point

func _reset_preview_direction() -> void:
	preview_direction_index = 0
	turn_preview_active = false
	turn_preview_elapsed = 0.0
	turn_preview_from_index = 0
	turn_preview_target_index = 0
	turn_preview_step = 0
	if current_rig:
		current_rig.rotation_degrees.y = 0.0
		_set_turn_preview_parameters(0.0, 1)

func _start_preview_turn(step: int) -> void:
	if current_rig == null:
		return
	var normalized_step := -1 if step < 0 else 1
	turn_preview_step = normalized_step
	turn_preview_from_index = preview_direction_index
	turn_preview_target_index = posmod(preview_direction_index + normalized_step, 8)
	turn_preview_elapsed = 0.0
	turn_preview_active = true
	if playback_toggle:
		current_rig.auto_animate = playback_toggle.button_pressed
	_update_preview_turn(0.0)

func _update_preview_turn(delta: float) -> void:
	if current_rig == null:
		return
	if not turn_preview_active:
		current_rig.rotation_degrees.y = float(preview_direction_index) * 45.0
		_set_turn_preview_parameters(0.0, 1)
		return
	turn_preview_elapsed += maxf(delta, 0.0)
	var t := clampf(turn_preview_elapsed / TURN_PREVIEW_DURATION, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	var from_yaw := float(turn_preview_from_index) * 45.0
	var target_yaw := from_yaw + float(turn_preview_step) * 45.0
	current_rig.rotation_degrees.y = lerpf(from_yaw, target_yaw, eased)
	_set_turn_preview_parameters(sin(t * PI), turn_preview_step)
	if t >= 1.0:
		preview_direction_index = turn_preview_target_index
		turn_preview_active = false
		current_rig.rotation_degrees.y = float(preview_direction_index) * 45.0
		_set_turn_preview_parameters(0.0, turn_preview_step)

func _set_turn_preview_parameters(turn_amount: float, direction: int) -> void:
	if current_rig == null:
		return
	var parameters: Dictionary = current_rig.get("parameters")
	parameters["turn_amount"] = clampf(turn_amount, 0.0, 1.0)
	parameters["turn_direction"] = -1.0 if direction < 0 else 1.0
	if not parameters.has("turn_tail_lag"):
		parameters["turn_tail_lag"] = 0.75
	if not parameters.has("inside_pectoral_fold"):
		parameters["inside_pectoral_fold"] = 1.0
	current_rig.set("parameters", parameters)

func _export_current() -> void:
	if current_rig == null or current_preset.is_empty():
		return
	var export_settings: Dictionary = current_preset.get("export_settings", {}).duplicate(true)
	if export_panel and export_panel.has_method("get_direction_count"):
		export_settings["direction_count"] = int(export_panel.call("get_direction_count"))
	current_preset["export_settings"] = export_settings
	export_panel.set_status("출력 중...")
	await exporter.export_preset(current_preset, current_rig, viewport)

func _set_fin_edit_enabled(enabled: bool) -> void:
	if fin_drag_controller:
		fin_drag_controller.call("set_enabled", enabled)
	if fin_editor_panel:
		fin_editor_panel.visible = enabled and String(current_preset.get("creature_type", "fish")) == "fish"
	var fish_rig := current_rig as FishRig
	if enabled and fish_rig:
		fish_rig.set_ring_editor_enabled(false)
	if enabled and head_edit_toggle:
		head_edit_toggle.button_pressed = false
	if enabled and body_edit_toggle:
		body_edit_toggle.button_pressed = false
	_sync_edit_input_state()

func _set_head_edit_enabled(enabled: bool) -> void:
	if head_editor_panel:
		head_editor_panel.visible = enabled and String(current_preset.get("creature_type", "fish")) == "fish"
	var fish_rig := current_rig as FishRig
	if enabled and fish_rig:
		fish_rig.set_ring_editor_enabled(false)
	if enabled and fin_edit_toggle:
		fin_edit_toggle.button_pressed = false
	if enabled and body_edit_toggle:
		body_edit_toggle.button_pressed = false
	_sync_edit_input_state()

func _set_body_edit_enabled(enabled: bool) -> void:
	if body_editor_panel:
		body_editor_panel.visible = enabled and String(current_preset.get("creature_type", "fish")) == "fish"
	var fish_rig := current_rig as FishRig
	if fish_rig:
		fish_rig.set_ring_editor_enabled(enabled and String(current_preset.get("creature_type", "fish")) == "fish")
	if enabled and fin_edit_toggle:
		fin_edit_toggle.button_pressed = false
	if enabled and head_edit_toggle:
		head_edit_toggle.button_pressed = false
	_sync_edit_input_state()

func _on_preview_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if body_edit_toggle == null or not body_edit_toggle.button_pressed:
		return
	var fish_rig := current_rig as FishRig
	if fish_rig == null:
		return
	var ring_points: Dictionary = fish_rig.get_body_ring_global_points()
	var best_id := ""
	var best_distance := INF
	var scale := Vector2.ONE
	if viewport.size.x > 0 and viewport.size.y > 0:
		scale = Vector2(viewport_container.size.x / float(viewport.size.x), viewport_container.size.y / float(viewport.size.y))
	for ring_id in ring_points.keys():
		var world_point: Vector3 = ring_points[ring_id]
		var screen_point := camera.unproject_position(world_point) * scale
		var distance := screen_point.distance_to(mouse_event.position)
		if distance < best_distance:
			best_distance = distance
			best_id = String(ring_id)
	if best_id != "" and best_distance <= 42.0:
		body_editor_panel.call("select_ring_by_id", best_id)

func _sync_edit_input_state() -> void:
	if camera_controller:
		camera_controller.set("input_enabled", true)
