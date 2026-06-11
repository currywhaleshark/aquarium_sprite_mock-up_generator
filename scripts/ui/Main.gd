extends Control

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const RayRigScript := preload("res://scripts/creature/RayRig.gd")
const ParameterPanelScript := preload("res://scripts/ui/ParameterPanel.gd")
const ExportPanelScript := preload("res://scripts/ui/ExportPanel.gd")
const PreviewControlsScript := preload("res://scripts/ui/PreviewControls.gd")
const PreviewCameraControllerScript := preload("res://scripts/ui/PreviewCameraController.gd")
const FishFinDragControllerScript := preload("res://scripts/ui/FishFinDragController.gd")
const BodyRingDragControllerScript := preload("res://scripts/ui/BodyRingDragController.gd")
const FinEditorPanelScript := preload("res://scripts/ui/FinEditorPanel.gd")
const HeadEditorPanelScript := preload("res://scripts/ui/HeadEditorPanel.gd")
const BodyEditorPanelScript := preload("res://scripts/ui/BodyEditorPanel.gd")
const ReferenceImagePanelScript := preload("res://scripts/ui/ReferenceImagePanel.gd")
const SpriteExporterScript := preload("res://scripts/export/SpriteExporter.gd")
const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")
const SpeciesArchetypeStoreScript := preload("res://scripts/species/SpeciesArchetypeStore.gd")
const CameraPresetScript := preload("res://scripts/render/CameraPreset.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
const UiText := preload("res://scripts/ui/UiText.gd")
const DragHandlesOverlayScript := preload("res://scripts/ui/DragHandlesOverlay.gd")

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
var body_ring_drag_controller: Node
var drag_handles_overlay: Control
var indicator_timer: Timer
var hovered_slider_key := ""
var preview_bg: ColorRect
var world_root: Node3D
var current_rig: CreatureRig
var presets: Array[Dictionary] = []
var species_archetypes: Array[Dictionary] = []
var current_preset: Dictionary = {}
var preset_option: OptionButton
var archetype_option: OptionButton
var archetype_strength_slider: HSlider
var archetype_read_label: Label
var apply_archetype_button: Button
var new_variant_button: Button
var side_tabs: TabContainer
var preset_name_edit: LineEdit
var save_preset_button: Button
var creature_type_label: Label
var playback_toggle: CheckButton
var parameter_panel: ParameterPanel
var color_panel: ParameterPanel
var motion_panel: ParameterPanel
# Side-panel sections that can detach into their own movable window, keyed by id
# ("color", "motion", ...). Each value is a PoppablePanel owning its window/button.
var poppables: Dictionary = {}
var export_panel: VBoxContainer
var mini_preview: TextureRect
var display_label: Label
var fin_edit_toggle: CheckButton
var editor_panel_scroll: ScrollContainer
var editor_panel_stack: VBoxContainer
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
var _is_exporting := false
var turn_preview_elapsed := 0.0
var turn_preview_from_index := 0
var turn_preview_target_index := 0
var turn_preview_step := 0
var _pending_editor_parameters: Dictionary = {}
var _editor_parameter_apply_pending := false

# A side-panel section that can detach into its own movable, resizable window and
# re-dock when the window closes. The panel is the same node wherever it is parented,
# so set_parameters and its change signals keep working in both states.
class PoppablePanel extends RefCounted:
	var panel: Control
	var dock: Node
	var window: Window
	var window_body: VBoxContainer
	var popout_button: Button
	var dock_notice: Control

	func pop_out() -> void:
		if panel == null or window == null or window_body == null:
			return
		if panel.get_parent() != window_body:
			if panel.get_parent() != null:
				panel.get_parent().remove_child(panel)
			window_body.add_child(panel)
		if popout_button != null:
			popout_button.visible = false
		if dock_notice != null:
			dock_notice.visible = true
		window.visible = true
		window.grab_focus()

	func dock_back() -> void:
		if panel == null or dock == null:
			return
		if panel.get_parent() != dock:
			if panel.get_parent() != null:
				panel.get_parent().remove_child(panel)
			dock.add_child(panel)
		if window != null:
			window.visible = false
		if popout_button != null:
			popout_button.visible = true
		if dock_notice != null:
			dock_notice.visible = false

func _ready() -> void:
	_build_ui()
	_build_preview_world()
	exporter = SpriteExporterScript.new()
	add_child(exporter)
	exporter.export_finished.connect(_on_export_finished)
	exporter.export_failed.connect(_on_export_failed)
	exporter.export_progress.connect(_on_export_progress)
	_reload_presets()

func _process(delta: float) -> void:
	_flush_editor_parameter_apply()
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

	preview_bg = ColorRect.new()
	preview_bg.name = "PreviewBg"
	preview_bg.color = Color(0.1, 0.12, 0.15, 1.0)
	preview_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_stack.add_child(preview_bg)

	viewport_container = SubViewportContainer.new()
	viewport_container.name = "ViewportContainer"
	viewport_container.stretch = true
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_stack.add_child(viewport_container)

	viewport = SubViewport.new()
	viewport.name = "PreviewViewport"
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	drag_handles_overlay = DragHandlesOverlayScript.new()
	drag_handles_overlay.name = "DragHandlesOverlay"
	drag_handles_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drag_handles_overlay.visible = false
	preview_stack.add_child(drag_handles_overlay)

	# Auto-hides the temporary slider indicator a moment after the last adjustment.
	indicator_timer = Timer.new()
	indicator_timer.one_shot = true
	indicator_timer.wait_time = 2.0
	indicator_timer.timeout.connect(func() -> void:
		if drag_handles_overlay:
			drag_handles_overlay.indicator_key = ""
			_update_overlay_visibility()
	)
	add_child(indicator_timer)

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

	# The side panel is a fixed-width column: a small header (title + presets) stays
	# pinned at the top and a TabContainer fills the rest, so the tab bar never
	# scrolls away. Each tab scrolls its own content internally.
	var side := VBoxContainer.new()
	side.name = "SidePanelContent"
	side.custom_minimum_size = Vector2(380, 0)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(side)

	var title := Label.new()
	title.text = "절차적 스프라이트 생성기"
	title.add_theme_font_size_override("font_size", 18)
	side.add_child(title)

	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 6)
	side.add_child(preset_row)
	
	preset_option = OptionButton.new()
	preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_option.item_selected.connect(_load_preset)
	preset_row.add_child(preset_option)
	
	var reset_preset_button := Button.new()
	reset_preset_button.text = "초기화"
	reset_preset_button.pressed.connect(func() -> void:
		_load_preset(preset_option.selected)
	)
	preset_row.add_child(reset_preset_button)

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

	_build_archetype_section(side)

	creature_type_label = Label.new()
	creature_type_label.text = "타입: 물고기"
	side.add_child(creature_type_label)

	# Split the long side panel into focused tabs so it stays easy to scan. The
	# preset/title block above stays fixed; everything else lives in one of three
	# tabs (shape editing / view & camera / export). Member references and signal
	# connections are unchanged — only the parent containers differ.
	side_tabs = TabContainer.new()
	side_tabs.name = "SideTabs"
	side_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(side_tabs)

	var shape_tab := _make_tab_page("모양·편집")
	var color_tab := _make_tab_page("색상")
	var motion_tab := _make_tab_page("움직임")
	var view_tab := _make_tab_page("표시·카메라")
	var export_tab := _make_tab_page("출력")

	# --- 표시·카메라 탭 ---
	playback_toggle = CheckButton.new()
	playback_toggle.text = "애니메이션 재생"
	playback_toggle.button_pressed = true
	playback_toggle.toggled.connect(func(enabled: bool) -> void:
		if current_rig:
			current_rig.auto_animate = enabled
	)
	view_tab.add_child(playback_toggle)

	var controls := PreviewControlsScript.new()
	controls.camera_preset_changed.connect(func(preset_name: String) -> void:
		current_preset["camera_preset"] = preset_name
		_apply_camera()
	)
	view_tab.add_child(controls)

	var frame_export_button := Button.new()
	frame_export_button.text = "익스포트 프레이밍 보기"
	frame_export_button.tooltip_text = "미리보기 카메라를 실제 출력과 동일하게 전체가 들어오도록 맞춥니다 (R로 원래 뷰 복귀)."
	frame_export_button.pressed.connect(_frame_to_export)
	view_tab.add_child(frame_export_button)

	var bg_color_row := HBoxContainer.new()
	bg_color_row.add_theme_constant_override("separation", 6)
	view_tab.add_child(bg_color_row)

	var bg_label := Label.new()
	bg_label.text = "미리보기 배경색"
	bg_label.custom_minimum_size = Vector2(112, 0)
	bg_color_row.add_child(bg_label)

	var bg_picker := ColorPickerButton.new()
	bg_picker.color = Color(0.1, 0.12, 0.15, 1.0)
	bg_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg_picker.color_changed.connect(func(color: Color) -> void:
		if preview_bg:
			preview_bg.color = color
	)
	bg_color_row.add_child(bg_picker)

	reference_image_panel = ReferenceImagePanelScript.new()
	reference_image_panel.reference_changed.connect(func(settings: Dictionary) -> void:
		_on_reference_image_changed(settings)
	)
	view_tab.add_child(reference_image_panel)

	# --- 모양·편집 탭 ---
	var edit_section_label := Label.new()
	edit_section_label.text = "부위 편집"
	edit_section_label.add_theme_font_size_override("font_size", 15)
	shape_tab.add_child(edit_section_label)

	var toggle_container := HBoxContainer.new()
	toggle_container.name = "EditToggleContainer"
	toggle_container.add_theme_constant_override("separation", 6)
	shape_tab.add_child(toggle_container)

	body_edit_toggle = CheckButton.new()
	body_edit_toggle.text = "몸통"
	body_edit_toggle.toggled.connect(_set_body_edit_enabled)
	toggle_container.add_child(body_edit_toggle)

	fin_edit_toggle = CheckButton.new()
	fin_edit_toggle.text = "지느러미"
	fin_edit_toggle.toggled.connect(_set_fin_edit_enabled)
	toggle_container.add_child(fin_edit_toggle)

	head_edit_toggle = CheckButton.new()
	head_edit_toggle.text = "머리"
	head_edit_toggle.toggled.connect(_set_head_edit_enabled)
	toggle_container.add_child(head_edit_toggle)

	# Apply premium segmented button styling
	var empty_tex := PlaceholderTexture2D.new()
	empty_tex.size = Vector2(0, 0)
	
	for toggle in [body_edit_toggle, fin_edit_toggle, head_edit_toggle]:
		toggle.add_theme_icon_override("checked", empty_tex)
		toggle.add_theme_icon_override("unchecked", empty_tex)
		toggle.add_theme_icon_override("checked_disabled", empty_tex)
		toggle.add_theme_icon_override("unchecked_disabled", empty_tex)
		toggle.alignment = HORIZONTAL_ALIGNMENT_CENTER
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var style_normal := StyleBoxFlat.new()
		style_normal.bg_color = Color(0.14, 0.16, 0.19)
		style_normal.content_margin_top = 8
		style_normal.content_margin_bottom = 8
		style_normal.corner_radius_top_left = 6
		style_normal.corner_radius_bottom_left = 6
		style_normal.corner_radius_top_right = 6
		style_normal.corner_radius_bottom_right = 6
		
		var style_hover := style_normal.duplicate() as StyleBoxFlat
		style_hover.bg_color = Color(0.2, 0.23, 0.27)
		
		var style_pressed := style_normal.duplicate() as StyleBoxFlat
		style_pressed.bg_color = Color(0.27, 0.77, 0.81) # Cyan highlight for active mode
		
		var style_disabled := style_normal.duplicate() as StyleBoxFlat
		style_disabled.bg_color = Color(0.1, 0.11, 0.12)
		
		toggle.add_theme_stylebox_override("normal", style_normal)
		toggle.add_theme_stylebox_override("hover", style_hover)
		toggle.add_theme_stylebox_override("pressed", style_pressed)
		toggle.add_theme_stylebox_override("disabled", style_disabled)
		toggle.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		toggle.add_theme_color_override("font_color", Color(0.8, 0.82, 0.85))
		toggle.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		toggle.add_theme_color_override("font_pressed_color", Color(0.08, 0.09, 0.11)) # Dark font on light bg
		toggle.add_theme_color_override("font_disabled_color", Color(0.4, 0.42, 0.45))

	editor_panel_scroll = ScrollContainer.new()
	editor_panel_scroll.name = "EditorPanelScroll"
	editor_panel_scroll.visible = false
	editor_panel_scroll.custom_minimum_size = Vector2(0, 180)
	editor_panel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shape_tab.add_child(editor_panel_scroll)

	editor_panel_stack = VBoxContainer.new()
	editor_panel_stack.name = "EditorPanelStack"
	editor_panel_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_panel_scroll.add_child(editor_panel_stack)

	fin_editor_panel = FinEditorPanelScript.new()
	fin_editor_panel.visible = false
	fin_editor_panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	fin_editor_panel.numeric_slider_changed.connect(_on_editor_numeric_slider_changed)
	fin_editor_panel.numeric_slider_hovered.connect(_on_editor_numeric_slider_hovered)
	fin_editor_panel.vector_edit_target_changed.connect(func(slot: String) -> void:
		if slot == "" or not fin_editor_panel.visible:
			_set_vector_edit_marker_slot("")
	)
	fin_editor_panel.vector_edit_preview_changed.connect(func(slot: String, active: bool, norm_position: Vector2, ghost: bool) -> void:
		_set_vector_edit_preview_marker(slot, active and fin_editor_panel.visible, norm_position, ghost)
	)
	editor_panel_stack.add_child(fin_editor_panel)

	head_editor_panel = HeadEditorPanelScript.new()
	head_editor_panel.visible = false
	head_editor_panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	head_editor_panel.numeric_slider_changed.connect(_on_editor_numeric_slider_changed)
	head_editor_panel.numeric_slider_hovered.connect(_on_editor_numeric_slider_hovered)
	head_editor_panel.vector_edit_target_changed.connect(func(slot: String) -> void:
		if slot == "" or not head_editor_panel.visible:
			_set_vector_edit_marker_slot("")
	)
	head_editor_panel.vector_edit_preview_changed.connect(func(slot: String, active: bool, norm_position: Vector2, ghost: bool) -> void:
		_set_vector_edit_preview_marker(slot, active and head_editor_panel.visible, norm_position, ghost)
	)
	editor_panel_stack.add_child(head_editor_panel)

	body_editor_panel = BodyEditorPanelScript.new()
	body_editor_panel.visible = false
	body_editor_panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	body_editor_panel.numeric_slider_changed.connect(_on_editor_numeric_slider_changed)
	body_editor_panel.numeric_slider_hovered.connect(_on_editor_numeric_slider_hovered)
	body_editor_panel.ring_selected.connect(func(ring_id: String) -> void:
		var fish_rig := current_rig as FishRig
		if fish_rig:
			fish_rig.set_selected_body_ring(ring_id)
	)
	editor_panel_stack.add_child(body_editor_panel)

	parameter_panel = ParameterPanelScript.new()
	parameter_panel.custom_minimum_size = Vector2(0, 240)
	parameter_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Colour and motion live in their own tabs, so the shape tab's panel hides them.
	parameter_panel.excluded_categories = ["Color Settings", "Pattern Settings", "Motion Settings"]
	parameter_panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	shape_tab.add_child(parameter_panel)

	# --- 색상 탭 ---
	# The colour/pattern editor (especially the wide regional marking-layer rows) is
	# cramped in the fixed-width side panel, so let it detach into a movable window.
	color_panel = ParameterPanelScript.new()
	color_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	color_panel.included_categories = ["Color Settings", "Pattern Settings"]
	color_panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	poppables["color"] = _make_poppable("Color", color_tab, color_panel, "색상 · 무늬")

	# --- 움직임 탭 ---
	motion_panel = ParameterPanelScript.new()
	motion_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	motion_panel.included_categories = ["Motion Settings"]
	motion_panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	poppables["motion"] = _make_poppable("Motion", motion_tab, motion_panel, "움직임")

	# --- 출력 탭 ---
	export_panel = ExportPanelScript.new()
	export_panel.export_requested.connect(_export_current)
	export_tab.add_child(export_panel)

	var help_title := Button.new()
	help_title.text = "> 조작 도움말"
	help_title.toggle_mode = true
	help_title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	export_tab.add_child(help_title)

	var help_body := VBoxContainer.new()
	help_body.visible = false
	help_body.add_theme_constant_override("separation", 2)
	export_tab.add_child(help_body)

	help_title.toggled.connect(func(opened: bool) -> void:
		help_body.visible = opened
		help_title.text = "%s 조작 도움말" % ["v" if opened else ">"]
	)
	
	var help_items := [
		"마우스 좌클릭 드래그: 카메라 회전 / 드래그 핸들 이동",
		"마우스 휠클릭 드래그: 카메라 평행 이동 (Pan)",
		"마우스 휠 스크롤: 카메라 줌 (Zoom)",
		"Space 키: 애니메이션 재생 / 일시정지",
		"R 키: 카메라 뷰 방향/줌 초기화",
		"1, 2, 3 키: 편집 모드 전환 (1:몸통, 2:지느러미, 3:머리)",
		"Shift 키 누른 채 드래그: 슬라이더 값 미세 조절"
	]
	for item in help_items:
		var item_label := Label.new()
		item_label.text = "• " + item
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_label.add_theme_font_size_override("font_size", 11)
		help_body.add_child(item_label)

# Adds one page to side_tabs. The VBox is the direct tab child (its name is the tab
# title) and fills the tab area, so a child marked EXPAND_FILL (e.g. the parameter
# panel) stretches to consume leftover vertical space instead of leaving a gap.
func _make_tab_page(tab_title: String) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.name = tab_title
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_tabs.add_child(content)
	return content

# Wraps an already-created (not yet parented) `panel` in pop-out plumbing: an in-tab
# "pop out" button, an in-tab notice with a re-dock button shown while detached, and
# a movable window that hosts the panel when popped out. Returns the PoppablePanel.
func _make_poppable(id: String, dock_host: VBoxContainer, panel: Control, window_title: String) -> PoppablePanel:
	var p := PoppablePanel.new()
	p.panel = panel
	p.dock = dock_host

	var popout_row := HBoxContainer.new()
	popout_row.name = "%sPopoutRow" % id
	popout_row.alignment = BoxContainer.ALIGNMENT_END
	dock_host.add_child(popout_row)
	p.popout_button = Button.new()
	p.popout_button.name = "%sPopoutButton" % id
	p.popout_button.text = "↗ 창으로 빼기"
	p.popout_button.tooltip_text = "%s 편집기를 이동·크기조절 가능한 별도 창으로 분리합니다." % window_title
	p.popout_button.pressed.connect(p.pop_out)
	popout_row.add_child(p.popout_button)

	p.dock_notice = _make_dock_notice(id, window_title, p)
	p.dock_notice.visible = false
	dock_host.add_child(p.dock_notice)

	dock_host.add_child(panel)

	p.window = Window.new()
	p.window.name = "%sWindow" % id
	p.window.title = "%s 편집기" % window_title
	p.window.min_size = Vector2i(420, 360)
	p.window.size = Vector2i(560, 640)
	p.window.visible = false
	p.window.close_requested.connect(p.dock_back)
	add_child(p.window)

	p.window_body = VBoxContainer.new()
	p.window_body.name = "%sWindowBody" % id
	p.window_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	p.window_body.add_theme_constant_override("separation", 6)
	p.window.add_child(p.window_body)
	var window_redock_button := Button.new()
	window_redock_button.text = "⤵ 패널로 되돌리기"
	window_redock_button.pressed.connect(p.dock_back)
	p.window_body.add_child(window_redock_button)

	return p

# Builds the placeholder shown in a tab while its panel is detached, with a
# one-click way to bring it back.
func _make_dock_notice(id: String, window_title: String, p: PoppablePanel) -> Control:
	var box := VBoxContainer.new()
	box.name = "%sDockNotice" % id
	box.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = "%s 편집기가 별도 창에 있습니다." % window_title
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var redock := Button.new()
	redock.text = "⤵ 패널로 되돌리기"
	redock.pressed.connect(p.dock_back)
	box.add_child(redock)
	return box

func _build_archetype_section(parent: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "종 아키타입"
	title.add_theme_font_size_override("font_size", 15)
	parent.add_child(title)

	var archetype_row := HBoxContainer.new()
	archetype_row.add_theme_constant_override("separation", 6)
	parent.add_child(archetype_row)

	archetype_option = OptionButton.new()
	archetype_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archetype_option.item_selected.connect(_on_archetype_selected)
	archetype_row.add_child(archetype_option)

	apply_archetype_button = Button.new()
	apply_archetype_button.text = "적용"
	apply_archetype_button.pressed.connect(_apply_selected_archetype)
	archetype_row.add_child(apply_archetype_button)

	var strength_row := HBoxContainer.new()
	strength_row.add_theme_constant_override("separation", 6)
	parent.add_child(strength_row)

	var strength_label := Label.new()
	strength_label.text = "강도"
	strength_label.custom_minimum_size = Vector2(44, 0)
	strength_row.add_child(strength_label)

	archetype_strength_slider = HSlider.new()
	archetype_strength_slider.min_value = 0.0
	archetype_strength_slider.max_value = 1.0
	archetype_strength_slider.step = 0.05
	archetype_strength_slider.value = 1.0
	archetype_strength_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strength_row.add_child(archetype_strength_slider)

	new_variant_button = Button.new()
	new_variant_button.text = "새 변형"
	new_variant_button.pressed.connect(_apply_new_archetype_variant)
	strength_row.add_child(new_variant_button)

	archetype_read_label = Label.new()
	archetype_read_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	archetype_read_label.add_theme_font_size_override("font_size", 11)
	parent.add_child(archetype_read_label)

	_load_species_archetype_options()

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
	fin_drag_controller.call("bind_camera_controller", camera_controller)
	fin_drag_controller.call("bind_input_control", viewport_container)
	body_ring_drag_controller = BodyRingDragControllerScript.new()
	body_ring_drag_controller.name = "BodyRingDragController"
	add_child(body_ring_drag_controller)
	body_ring_drag_controller.call("bind_camera", camera)
	body_ring_drag_controller.call("bind_camera_controller", camera_controller)
	body_ring_drag_controller.call("bind_input_control", viewport_container)
	body_ring_drag_controller.call("set_enabled", false)
	if drag_handles_overlay:
		drag_handles_overlay.camera = camera
		drag_handles_overlay.fin_drag_controller = fin_drag_controller
		drag_handles_overlay.body_ring_drag_controller = body_ring_drag_controller
	fin_drag_controller.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	body_ring_drag_controller.parameters_changed.connect(func(parameters: Dictionary) -> void:
		_apply_parameters_from_editor(parameters)
	)
	body_ring_drag_controller.ring_handle_selected.connect(func(ring_id: String) -> void:
		if body_editor_panel:
			body_editor_panel.call("select_ring_by_id", ring_id)
	)
	camera_controller.camera_changed.connect(func(_state: Dictionary) -> void:
		_update_reference_overlay_transform()
	)
	camera_controller.call("bind_input_control", viewport_container)
	_apply_camera()

func _load_species_archetype_options() -> void:
	if archetype_option == null:
		return
	species_archetypes = SpeciesArchetypeStoreScript.load_all()
	archetype_option.clear()
	archetype_option.add_item("Generic Fish")
	archetype_option.set_item_metadata(0, "")
	for archetype in species_archetypes:
		var label := String(archetype.get("label", archetype.get("id", "")))
		archetype_option.add_item(label)
		archetype_option.set_item_metadata(archetype_option.item_count - 1, String(archetype.get("id", "")))
	_update_archetype_read_label()

func _on_archetype_selected(_index: int) -> void:
	_update_archetype_read_label()

func _update_archetype_read_label() -> void:
	if archetype_read_label == null or archetype_option == null:
		return
	var archetype := _selected_archetype()
	if archetype.is_empty():
		archetype_read_label.text = "수동 프리셋"
		return
	var priorities: Array = archetype.get("readability_priority", [])
	archetype_read_label.text = ", ".join(priorities)

func _selected_archetype() -> Dictionary:
	if archetype_option == null or archetype_option.selected < 0:
		return {}
	var selected_id := String(archetype_option.get_item_metadata(archetype_option.selected))
	if selected_id == "":
		return {}
	for archetype in species_archetypes:
		if String(archetype.get("id", "")) == selected_id:
			return archetype
	return SpeciesArchetypeStoreScript.load_archetype(selected_id)

func _sync_archetype_controls(parameters: Dictionary) -> void:
	if archetype_option == null:
		return
	var archetype_id := String(parameters.get("archetype_id", ""))
	var selected_index := 0
	if archetype_id != "":
		for i in archetype_option.item_count:
			if String(archetype_option.get_item_metadata(i)) == archetype_id:
				selected_index = i
				break
	archetype_option.select(selected_index)
	if archetype_strength_slider:
		archetype_strength_slider.value = clampf(float(parameters.get("archetype_strength", 1.0)), 0.0, 1.0)
	_update_archetype_read_label()

func _apply_selected_archetype() -> void:
	var archetype := _selected_archetype()
	if archetype.is_empty() or current_preset.is_empty():
		return
	var parameters: Dictionary = current_preset.get("parameters", {}).duplicate(true)
	var current_id := String(parameters.get("archetype_id", ""))
	var selected_id := String(archetype.get("id", ""))
	var seed := int(parameters.get("variant_seed", _make_variant_seed(-1)))
	if current_id != selected_id:
		seed = _make_variant_seed(seed)
	var strength := 1.0
	if archetype_strength_slider:
		strength = float(archetype_strength_slider.value)
	var applied := SpeciesArchetypeStoreScript.apply_archetype(parameters, archetype, strength, seed)
	_apply_archetype_parameters(applied)
	if export_panel:
		export_panel.set_status("%s 아키타입 적용" % String(archetype.get("label", selected_id)))

func _apply_new_archetype_variant() -> void:
	var archetype := _selected_archetype()
	if archetype.is_empty() and not current_preset.is_empty():
		var parameters: Dictionary = current_preset.get("parameters", {})
		var archetype_id := String(parameters.get("archetype_id", ""))
		if archetype_id != "":
			archetype = SpeciesArchetypeStoreScript.load_archetype(archetype_id)
	if archetype.is_empty() or current_preset.is_empty():
		return
	var parameters: Dictionary = current_preset.get("parameters", {}).duplicate(true)
	var previous_seed := int(parameters.get("variant_seed", -1))
	var strength := 1.0
	if archetype_strength_slider:
		strength = float(archetype_strength_slider.value)
	var applied := SpeciesArchetypeStoreScript.apply_archetype(parameters, archetype, strength, _make_variant_seed(previous_seed))
	_apply_archetype_parameters(applied)
	if export_panel:
		export_panel.set_status("%s 새 변형 적용" % String(archetype.get("label", archetype.get("id", ""))))

func _make_variant_seed(previous_seed: int) -> int:
	var seed := int(Time.get_ticks_usec() & 0x7fffffff)
	if seed == previous_seed:
		seed = int((seed + 1) & 0x7fffffff)
	return seed

func _apply_archetype_parameters(parameters: Dictionary) -> void:
	current_preset["creature_type"] = "fish"
	current_preset["type"] = "fish"
	if (current_rig as FishRig) == null:
		_discard_current_rig()
		current_rig = FishRigScript.new()
		current_rig.name = "ActiveRig"
		world_root.add_child(current_rig)
		_bind_fin_editor_for_current_rig()
	_apply_parameters_from_editor(parameters)
	_sync_archetype_controls(parameters)

func _load_preset(index: int) -> void:
	if index < 0 or index >= presets.size():
		return
	_clear_pending_editor_apply()
	current_preset = presets[index].duplicate(true)
	_discard_current_rig()
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
	color_panel.set_parameters(current_preset.get("parameters", {}))
	motion_panel.set_parameters(current_preset.get("parameters", {}))
	if fin_editor_panel:
		fin_editor_panel.call("set_parameters", current_preset.get("parameters", {}))
	if head_editor_panel:
		head_editor_panel.call("set_parameters", current_preset.get("parameters", {}))
	if body_editor_panel:
		body_editor_panel.call("set_parameters", current_preset.get("parameters", {}))
	_sync_archetype_controls(current_preset.get("parameters", {}))
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

func _discard_current_rig() -> void:
	if current_rig:
		if current_rig.get_parent():
			current_rig.get_parent().remove_child(current_rig)
		current_rig.queue_free()
		current_rig = null
	if world_root:
		for child in world_root.get_children():
			if child.name == "ActiveRig":
				world_root.remove_child(child)
				child.queue_free()

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
	_pending_editor_parameters = synced_parameters
	_editor_parameter_apply_pending = true

func _flush_editor_parameter_apply() -> void:
	if not _editor_parameter_apply_pending:
		return
	_editor_parameter_apply_pending = false
	if _pending_editor_parameters.is_empty():
		return
	var synced_parameters := _pending_editor_parameters.duplicate(true)
	_pending_editor_parameters.clear()
	if current_rig:
		current_rig.set_parameters(synced_parameters)
		if playback_toggle:
			current_rig.auto_animate = playback_toggle.button_pressed
		if current_rig.has_method("set_ring_editor_enabled"):
			current_rig.call("set_ring_editor_enabled", body_edit_toggle != null and body_edit_toggle.button_pressed)
	_sync_parameter_editors(synced_parameters)

func _clear_pending_editor_apply() -> void:
	_pending_editor_parameters.clear()
	_editor_parameter_apply_pending = false

func _sync_parameter_editors(parameters: Dictionary) -> void:
	if parameter_panel:
		parameter_panel.set_parameters(parameters)
	if color_panel:
		color_panel.set_parameters(parameters)
	if motion_panel:
		motion_panel.set_parameters(parameters)
	if fin_editor_panel:
		fin_editor_panel.call("set_parameters", parameters)
	if head_editor_panel:
		head_editor_panel.call("set_parameters", parameters)
	if body_editor_panel:
		body_editor_panel.call("set_parameters", parameters)

func _bind_fin_editor_for_current_rig() -> void:
	if fin_drag_controller == null:
		return
	if _is_fish():
		fin_drag_controller.call("bind_fish", current_rig)
		fin_drag_controller.call("set_enabled", true)
		if body_ring_drag_controller:
			body_ring_drag_controller.call("bind_fish", current_rig)
		if drag_handles_overlay:
			drag_handles_overlay.fish = current_rig as FishRig
			_update_overlay_visibility()
		if fin_edit_toggle:
			fin_edit_toggle.disabled = false
		if head_edit_toggle:
			head_edit_toggle.disabled = false
		if body_edit_toggle:
			body_edit_toggle.disabled = false
	elif _is_ray():
		fin_drag_controller.call("bind_fish", null)
		fin_drag_controller.call("set_enabled", false)
		if body_ring_drag_controller:
			body_ring_drag_controller.call("bind_fish", null)
			body_ring_drag_controller.call("set_enabled", false)
		if drag_handles_overlay:
			drag_handles_overlay.fish = null
			_update_overlay_visibility()
		if fin_edit_toggle:
			fin_edit_toggle.disabled = false
		if head_edit_toggle:
			head_edit_toggle.disabled = false
		if body_edit_toggle:
			body_edit_toggle.disabled = false
	else:
		fin_drag_controller.call("bind_fish", null)
		fin_drag_controller.call("set_enabled", false)
		if body_ring_drag_controller:
			body_ring_drag_controller.call("bind_fish", null)
			body_ring_drag_controller.call("set_enabled", false)
		if drag_handles_overlay:
			drag_handles_overlay.fish = null
			_update_overlay_visibility()
		if current_rig and current_rig.has_method("set_ring_editor_enabled"):
			current_rig.call("set_ring_editor_enabled", false)
		if fin_edit_toggle:
			fin_edit_toggle.button_pressed = false
			fin_edit_toggle.disabled = true
		if head_edit_toggle:
			head_edit_toggle.button_pressed = false
			head_edit_toggle.disabled = true
		if body_edit_toggle:
			body_edit_toggle.button_pressed = false
			body_edit_toggle.disabled = true

func _export_resolution() -> Vector2i:
	var export_settings: Dictionary = current_preset.get("export_settings", {})
	var rd: Dictionary = export_settings.get("render_resolution", {"w": 256, "h": 256})
	return Vector2i(int(rd.get("w", 256)), int(rd.get("h", 256)))

# Snaps the preview camera to match the export's auto-fit framing (whole creature in
# frame) using the same calculation the exporter uses. R / reset restores the preset.
func _frame_to_export() -> void:
	if current_rig == null or camera_controller == null:
		return
	var framing: Dictionary = SpriteExporterScript.compute_fit_framing(current_rig, _export_resolution())
	if float(framing.get("radius", 0.0)) <= 0.0001:
		return
	camera_controller.set("orthographic_size", float(framing.get("ortho_size", 2.25)))
	camera_controller.set("target", Vector3(0.0, float(framing.get("center_y", 0.0)), 0.0))
	camera_controller.call("_apply_camera")

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
		"rotation": 0.0,
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
	reference_overlay.pivot_offset = display_size * 0.5
	reference_overlay.rotation_degrees = float(settings.get("rotation", 0.0))

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
	_apply_camera()

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
	if _is_exporting:
		return
	if not turn_preview_active:
		current_rig.rotation_degrees.y = float(preview_direction_index) * 45.0
		_set_turn_preview_parameters(0.0, 1, 0.0)
		return
	turn_preview_elapsed += maxf(delta, 0.0)
	var t := clampf(turn_preview_elapsed / TURN_PREVIEW_DURATION, 0.0, 1.0)
	# Delay global rotation so that head bend is already entered before global yaw rotation begins
	var rot_t := clampf((t - 0.15) / 0.85, 0.0, 1.0)
	var eased := rot_t * rot_t * (3.0 - 2.0 * rot_t)
	var from_yaw := float(turn_preview_from_index) * 45.0
	var target_yaw := from_yaw + float(turn_preview_step) * 45.0
	current_rig.rotation_degrees.y = lerpf(from_yaw, target_yaw, eased)
	_set_turn_preview_parameters(sin(t * PI), turn_preview_step, t)
	if t >= 1.0:
		preview_direction_index = turn_preview_target_index
		turn_preview_active = false
		current_rig.rotation_degrees.y = float(preview_direction_index) * 45.0
		_set_turn_preview_parameters(0.0, turn_preview_step, 0.0)

func _set_turn_preview_parameters(turn_amount: float, direction: int, turn_phase: float = 0.0) -> void:
	if current_rig == null:
		return
	var parameters: Dictionary = current_rig.get("parameters")
	parameters["turn_amount"] = clampf(turn_amount, 0.0, 1.0)
	parameters["turn_direction"] = -1.0 if direction < 0 else 1.0
	parameters["turn_phase"] = clampf(turn_phase, 0.0, 1.0)
	if not parameters.has("turn_tail_lag"):
		parameters["turn_tail_lag"] = 0.75
	if not parameters.has("inside_pectoral_fold"):
		parameters["inside_pectoral_fold"] = 0.8
	if not parameters.has("outside_pectoral_brace"):
		parameters["outside_pectoral_brace"] = 0.5
	if not parameters.has("turn_curve_bias"):
		parameters["turn_curve_bias"] = 0.5
	if not parameters.has("turn_median_fin_bias"):
		parameters["turn_median_fin_bias"] = 0.5
	if not parameters.has("turn_bank_roll"):
		parameters["turn_bank_roll"] = 10.0
	current_rig.set("parameters", parameters)

func _on_export_finished(path: String) -> void:
	if export_panel:
		export_panel.end_progress()
		export_panel.set_status("출력 완료: %s" % path)

func _on_export_failed(message: String) -> void:
	if export_panel:
		export_panel.end_progress()
		export_panel.set_status(message)

func _on_export_progress(value: float, message: String) -> void:
	if export_panel:
		export_panel.set_progress(value)
		export_panel.set_status(message)

func _export_current() -> void:
	if _is_exporting:
		return
	if current_rig == null or current_preset.is_empty():
		return
	var export_settings: Dictionary = current_preset.get("export_settings", {}).duplicate(true)
	if export_panel and export_panel.has_method("get_direction_count"):
		export_settings["direction_count"] = int(export_panel.call("get_direction_count"))
	current_preset["export_settings"] = export_settings
	export_panel.set_status("출력 중...")
	_is_exporting = true
	await exporter.export_preset(current_preset, current_rig, viewport)
	_is_exporting = false

func _set_fin_edit_enabled(enabled: bool) -> void:
	if fin_editor_panel:
		fin_editor_panel.visible = enabled and (_is_fish() or _is_ray())
	_update_editor_panel_scroll_visibility()
	if enabled and current_rig and current_rig.has_method("set_ring_editor_enabled"):
		current_rig.call("set_ring_editor_enabled", false)
	if enabled:
		_select_exclusive_edit_toggle(fin_edit_toggle)
	if drag_handles_overlay:
		drag_handles_overlay.draw_fins = enabled
		if not enabled and String(drag_handles_overlay.vector_edit_slot) != "operculum":
			_set_vector_edit_marker_slot("")
		_update_overlay_visibility()
	_sync_edit_input_state()

func _set_head_edit_enabled(enabled: bool) -> void:
	if head_editor_panel:
		head_editor_panel.visible = enabled and (_is_fish() or _is_ray())
	_update_editor_panel_scroll_visibility()
	if enabled and current_rig and current_rig.has_method("set_ring_editor_enabled"):
		current_rig.call("set_ring_editor_enabled", false)
	if enabled:
		_select_exclusive_edit_toggle(head_edit_toggle)
	if drag_handles_overlay:
		drag_handles_overlay.draw_head = enabled
		if not enabled:
			drag_handles_overlay.indicator_key = ""
			if String(drag_handles_overlay.vector_edit_slot) == "operculum":
				_set_vector_edit_marker_slot("")
		_update_overlay_visibility()
	_sync_edit_input_state()

func _set_vector_edit_marker_slot(slot: String) -> void:
	if drag_handles_overlay == null:
		return
	drag_handles_overlay.vector_edit_slot = slot
	drag_handles_overlay.vector_edit_marker_active = false
	drag_handles_overlay.vector_edit_marker_norm = Vector2.ZERO
	drag_handles_overlay.vector_edit_marker_ghost = false
	_update_overlay_visibility()

func _set_vector_edit_preview_marker(slot: String, active: bool, norm_position: Vector2, ghost: bool) -> void:
	if drag_handles_overlay == null:
		return
	drag_handles_overlay.vector_edit_slot = slot if active else ""
	drag_handles_overlay.vector_edit_marker_active = active
	drag_handles_overlay.vector_edit_marker_norm = norm_position
	drag_handles_overlay.vector_edit_marker_ghost = ghost
	_update_overlay_visibility()

func _on_editor_numeric_slider_changed(key: String) -> void:
	if drag_handles_overlay == null:
		return
	if key == "":
		drag_handles_overlay.indicator_key = ""
		if indicator_timer:
			indicator_timer.stop()
		_update_overlay_visibility()
		return
	drag_handles_overlay.indicator_key = key
	if indicator_timer and hovered_slider_key != key:
		indicator_timer.start()
	_update_overlay_visibility()

func _on_editor_numeric_slider_hovered(key: String) -> void:
	hovered_slider_key = key
	if drag_handles_overlay == null:
		return
	if indicator_timer:
		indicator_timer.stop()
	drag_handles_overlay.indicator_key = key
	_update_overlay_visibility()

func _set_body_edit_enabled(enabled: bool) -> void:
	if body_editor_panel:
		body_editor_panel.visible = enabled and (_is_fish() or _is_ray())
	_update_editor_panel_scroll_visibility()
	if current_rig and current_rig.has_method("set_ring_editor_enabled"):
		current_rig.call("set_ring_editor_enabled", enabled)
	if enabled:
		_select_exclusive_edit_toggle(body_edit_toggle)
	if drag_handles_overlay:
		drag_handles_overlay.draw_body_rings = enabled and _is_fish()
		_update_overlay_visibility()
	_sync_edit_input_state()

func _select_exclusive_edit_toggle(active_toggle: CheckButton) -> void:
	for toggle in [fin_edit_toggle, head_edit_toggle, body_edit_toggle]:
		if toggle != null and toggle != active_toggle:
			toggle.button_pressed = false
	# Bring the shape/edit tab forward so the activated editor panel is visible.
	if side_tabs:
		side_tabs.current_tab = 0

func _update_editor_panel_scroll_visibility() -> void:
	if editor_panel_scroll == null:
		return
	var editing_active := (
		(fin_editor_panel != null and fin_editor_panel.visible)
		or (head_editor_panel != null and head_editor_panel.visible)
		or (body_editor_panel != null and body_editor_panel.visible)
	)
	editor_panel_scroll.visible = editing_active
	if parameter_panel:
		parameter_panel.visible = not editing_active

func _is_fish() -> bool:
	return String(current_preset.get("creature_type", "fish")) == "fish"

func _is_ray() -> bool:
	return String(current_preset.get("creature_type", "fish")) == "ray"

func _on_preview_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if body_edit_toggle == null or not body_edit_toggle.button_pressed:
		return
	if current_rig == null or not current_rig.has_method("get_body_ring_global_points"):
		return
	var ring_points: Dictionary = current_rig.call("get_body_ring_global_points")
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
	var body_active := body_edit_toggle != null and body_edit_toggle.button_pressed and _is_fish()
	if fin_drag_controller:
		fin_drag_controller.call("set_enabled", _is_fish() and not body_active)
	if body_ring_drag_controller:
		body_ring_drag_controller.call("set_enabled", body_active)

func _update_overlay_visibility() -> void:
	if drag_handles_overlay:
		drag_handles_overlay.visible = _is_fish() and (drag_handles_overlay.draw_fins or drag_handles_overlay.draw_head or drag_handles_overlay.draw_body_rings or drag_handles_overlay.vector_edit_marker_active or String(drag_handles_overlay.indicator_key) != "")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			if playback_toggle:
				playback_toggle.button_pressed = not playback_toggle.button_pressed
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			_reset_preview_direction()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_D:
			_toggle_part_debug()
			get_viewport().set_input_as_handled()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_3:
			var index: int = int(event.keycode) - int(KEY_1)
			match index:
				0:
					if body_edit_toggle and not body_edit_toggle.disabled:
						body_edit_toggle.button_pressed = not body_edit_toggle.button_pressed
				1:
					if fin_edit_toggle and not fin_edit_toggle.disabled:
						fin_edit_toggle.button_pressed = not fin_edit_toggle.button_pressed
				2:
					if head_edit_toggle and not head_edit_toggle.disabled:
						head_edit_toggle.button_pressed = not head_edit_toggle.button_pressed
			get_viewport().set_input_as_handled()

# --- Part debug coloring (press D) -----------------------------------------
# Recolors every mesh of the active rig by part so overlapping surfaces can be
# told apart. The outer shell turns semi-transparent and the operculum flap /
# gill opening draw with no depth test (x-ray), so a flap buried inside the
# shell is still visible. Press D again to restore the real materials.
var _part_debug := false
var _part_debug_saved := {}
var _part_debug_mats := {}

func _toggle_part_debug() -> void:
	_part_debug = not _part_debug
	if current_rig == null:
		return
	if _part_debug:
		_part_debug_saved.clear()
		for mi in _all_mesh_instances(current_rig, []):
			_part_debug_saved[mi] = mi.material_override
			mi.material_override = _debug_material_for(mi.name)
		print("[part-debug] ON — shell=cyan(translucent) head=orange operculum=magenta(xray) opening=black(xray) fin=green eye=white jaw=yellow")
	else:
		for mi in _part_debug_saved.keys():
			if is_instance_valid(mi):
				mi.material_override = _part_debug_saved[mi]
		_part_debug_saved.clear()
		print("[part-debug] OFF")

func _all_mesh_instances(node: Node, out: Array) -> Array:
	for c in node.get_children():
		if c is MeshInstance3D:
			out.append(c)
		_all_mesh_instances(c, out)
	return out

func _debug_material_for(node_name: String) -> StandardMaterial3D:
	var key := "default"
	var xray := false
	if node_name.contains("Opening"):
		key = "opening"
		xray = true
	elif node_name.begins_with("OperculumFlap"):
		key = "operculum"
		xray = true
	elif node_name == "OuterShell":
		key = "shell"
	elif node_name == "Head":
		key = "head"
	elif node_name.contains("Fin"):
		key = "fin"
	elif node_name.contains("Eye"):
		key = "eye"
	elif node_name.contains("Jaw") or node_name.contains("Mouth"):
		key = "jaw"
	if _part_debug_mats.has(key):
		return _part_debug_mats[key]
	var colors := {
		"shell": Color(0.2, 0.8, 1.0, 0.22),
		"head": Color(1.0, 0.55, 0.1),
		"operculum": Color(1.0, 0.1, 0.8),
		"opening": Color(0.04, 0.04, 0.05),
		"fin": Color(0.3, 0.9, 0.35),
		"eye": Color(1.0, 1.0, 1.0),
		"jaw": Color(1.0, 0.85, 0.2),
		"default": Color(0.6, 0.6, 0.62),
	}
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colors[key]
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if key == "shell":
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if xray:
		mat.no_depth_test = true
	_part_debug_mats[key] = mat
	return mat
