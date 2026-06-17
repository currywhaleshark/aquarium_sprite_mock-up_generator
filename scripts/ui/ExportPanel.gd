class_name ExportPanel
extends VBoxContainer

signal export_requested
signal stylize_options_changed(options: Dictionary)
signal stylize_preview_refresh_requested

const SpriteStylizerScript := preload("res://scripts/export/SpriteStylizer.gd")
const UiRows := preload("res://scripts/ui/UiRows.gd")

var direction_toggle: CheckButton
var turn_clips_toggle: CheckButton
var stylize_toggle: CheckButton
var stylize_color_slider: HSlider
var stylize_outline_slider: HSlider
var stylize_color_label: Label
var stylize_outline_label: Label
var stylize_preview_texture: TextureRect
var stylize_preview_refresh_button: Button
var stylize_preview_source: Image
var status_label: Label
var progress_bar: ProgressBar

func _ready() -> void:
	direction_toggle = CheckButton.new()
	direction_toggle.text = "8방향 추출"
	direction_toggle.toggled.connect(func(_enabled: bool) -> void:
		_sync_turn_clips_toggle()
	)
	add_child(direction_toggle)

	turn_clips_toggle = CheckButton.new()
	turn_clips_toggle.text = "선회 클립 포함"
	turn_clips_toggle.tooltip_text = "8방향 출력에서 좌/우 45도 선회 클립을 추가합니다."
	add_child(turn_clips_toggle)

	stylize_toggle = CheckButton.new()
	stylize_toggle.text = "2D 스타일(외곽선·셀)"
	stylize_toggle.tooltip_text = "추출 시 외곽선과 셀 음영(색 단계화)을 적용해 평면 2D 스프라이트 느낌을 냅니다."
	stylize_toggle.button_pressed = true
	stylize_toggle.toggled.connect(func(_enabled: bool) -> void:
		_sync_stylize_controls()
	)
	add_child(stylize_toggle)

	_add_stylize_strength_controls()

	var button := Button.new()
	button.text = "PNG + 스프라이트시트 출력"
	button.pressed.connect(func() -> void: export_requested.emit())
	add_child(button)

	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0
	progress_bar.show_percentage = true
	progress_bar.visible = false
	add_child(progress_bar)

	status_label = Label.new()
	status_label.text = "준비됨"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)
	_sync_turn_clips_toggle()
	_sync_stylize_controls()

func set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func set_progress(value: float) -> void:
	if progress_bar:
		progress_bar.visible = true
		progress_bar.value = clampf(value, 0.0, 1.0)

func end_progress() -> void:
	if progress_bar:
		progress_bar.visible = false
		progress_bar.value = 0.0

func get_direction_count() -> int:
	if direction_toggle == null:
		return 1
	return 8 if direction_toggle.button_pressed else 1

func set_direction_count(direction_count: int) -> void:
	if direction_toggle:
		direction_toggle.button_pressed = direction_count == 8
	_sync_turn_clips_toggle()

func get_stylize_enabled() -> bool:
	return stylize_toggle != null and stylize_toggle.button_pressed

func set_stylize_enabled(enabled: bool) -> void:
	if stylize_toggle:
		stylize_toggle.button_pressed = enabled
	_sync_stylize_controls()

func get_stylize_color_strength() -> float:
	return float(stylize_color_slider.value) if stylize_color_slider != null else SpriteStylizerScript.DEFAULT_COLOR_STRENGTH

func set_stylize_color_strength(value: float) -> void:
	if stylize_color_slider:
		stylize_color_slider.value = clampf(value, 0.0, SpriteStylizerScript.MAX_STRENGTH)
	_update_stylize_preview()

func get_stylize_outline_strength() -> float:
	return float(stylize_outline_slider.value) if stylize_outline_slider != null else SpriteStylizerScript.DEFAULT_OUTLINE_STRENGTH

func set_stylize_outline_strength(value: float) -> void:
	if stylize_outline_slider:
		stylize_outline_slider.value = clampf(value, 0.0, SpriteStylizerScript.MAX_STRENGTH)
	_update_stylize_preview()

func get_stylize_options() -> Dictionary:
	return SpriteStylizerScript.options_for_controls(get_stylize_enabled(), get_stylize_color_strength(), get_stylize_outline_strength())

func set_stylize_options(options: Dictionary) -> void:
	set_stylize_enabled(bool(options.get("enabled", true)))
	set_stylize_color_strength(float(options.get("color_strength", SpriteStylizerScript.DEFAULT_COLOR_STRENGTH)))
	set_stylize_outline_strength(float(options.get("outline_strength", SpriteStylizerScript.DEFAULT_OUTLINE_STRENGTH)))

func set_stylize_preview_source(image: Image) -> void:
	if image == null or image.is_empty():
		return
	stylize_preview_source = _scaled_preview_source(image)
	_update_stylize_preview()

func request_stylize_preview_refresh() -> void:
	stylize_preview_refresh_requested.emit()

func get_include_turn_clips() -> bool:
	if turn_clips_toggle == null:
		return false
	return get_direction_count() == 8 and turn_clips_toggle.button_pressed

func set_include_turn_clips(enabled: bool) -> void:
	if turn_clips_toggle:
		turn_clips_toggle.button_pressed = enabled
	_sync_turn_clips_toggle()

func _sync_turn_clips_toggle() -> void:
	if turn_clips_toggle == null:
		return
	var enabled := get_direction_count() == 8
	if not enabled:
		turn_clips_toggle.button_pressed = false
	turn_clips_toggle.disabled = not enabled
	turn_clips_toggle.tooltip_text = "8방향 출력에서 좌/우 45도 선회 클립을 추가합니다." if enabled else "선회 클립은 8방향 출력에서만 사용할 수 있습니다."

func _add_stylize_strength_controls() -> void:
	var color_widgets := UiRows.add_labeled_slider(self, "색상 변형", {
		"label_width": 96,
		"min": 0.0,
		"max": SpriteStylizerScript.MAX_STRENGTH,
		"step": 0.05,
		"value": SpriteStylizerScript.DEFAULT_COLOR_STRENGTH,
		"default": SpriteStylizerScript.DEFAULT_COLOR_STRENGTH,
	})
	stylize_color_slider = color_widgets["slider"] as HSlider
	stylize_color_label = color_widgets["value_label"] as Label
	stylize_color_slider.value_changed.connect(func(value: float) -> void:
		stylize_color_label.text = "%.2f" % value
		UiRows.update_changed_marker(color_widgets)
		_update_stylize_preview()
		stylize_options_changed.emit(get_stylize_options())
	)

	var outline_widgets := UiRows.add_labeled_slider(self, "아웃라인", {
		"label_width": 96,
		"min": 0.0,
		"max": SpriteStylizerScript.MAX_STRENGTH,
		"step": 0.05,
		"value": SpriteStylizerScript.DEFAULT_OUTLINE_STRENGTH,
		"default": SpriteStylizerScript.DEFAULT_OUTLINE_STRENGTH,
	})
	stylize_outline_slider = outline_widgets["slider"] as HSlider
	stylize_outline_label = outline_widgets["value_label"] as Label
	stylize_outline_slider.value_changed.connect(func(value: float) -> void:
		stylize_outline_label.text = "%.2f" % value
		UiRows.update_changed_marker(outline_widgets)
		_update_stylize_preview()
		stylize_options_changed.emit(get_stylize_options())
	)

	stylize_preview_texture = TextureRect.new()
	stylize_preview_texture.name = "StylizePreview"
	stylize_preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stylize_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stylize_preview_texture.custom_minimum_size = Vector2(128, 84)
	add_child(stylize_preview_texture)

	stylize_preview_refresh_button = Button.new()
	stylize_preview_refresh_button.text = "현재 물고기 미리보기 갱신"
	stylize_preview_refresh_button.tooltip_text = "현재 편집 중인 물고기를 작은 이미지로 캡처해 색상 변형과 아웃라인 미리보기에 사용합니다."
	stylize_preview_refresh_button.pressed.connect(request_stylize_preview_refresh)
	add_child(stylize_preview_refresh_button)

	stylize_preview_source = _make_default_stylize_preview()
	_update_stylize_preview()

func _sync_stylize_controls() -> void:
	var enabled := get_stylize_enabled()
	if stylize_color_slider:
		stylize_color_slider.editable = enabled
	if stylize_outline_slider:
		stylize_outline_slider.editable = enabled
	_update_stylize_preview()
	stylize_options_changed.emit(get_stylize_options())

func _update_stylize_preview() -> void:
	if stylize_preview_texture == null:
		return
	var source := stylize_preview_source if stylize_preview_source != null and not stylize_preview_source.is_empty() else _make_default_stylize_preview()
	var image := source.duplicate()
	if get_stylize_enabled():
		SpriteStylizerScript.stylize(image, get_stylize_options())
	stylize_preview_texture.texture = ImageTexture.create_from_image(image)

func _make_default_stylize_preview() -> Image:
	var image := Image.create(96, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(48.0, 32.0)
	var radius := Vector2(34.0, 17.0)
	for y in image.get_height():
		for x in image.get_width():
			var p := Vector2(float(x), float(y))
			var d := Vector2((p.x - center.x) / radius.x, (p.y - center.y) / radius.y)
			var dist := d.length()
			if dist > 1.0:
				continue
			var shade := clampf(0.95 - float(y) / float(image.get_height()) * 0.45 + float(x) / float(image.get_width()) * 0.08, 0.2, 1.0)
			var alpha := clampf((1.0 - dist) * 8.0, 0.0, 1.0)
			image.set_pixel(x, y, Color.from_hsv(0.52, 0.62, shade, alpha))
	return image

func _scaled_preview_source(image: Image) -> Image:
	var preview := image.duplicate()
	var max_side := 128
	var longest := maxi(preview.get_width(), preview.get_height())
	if longest > max_side:
		var scale := float(max_side) / float(longest)
		preview.resize(maxi(1, int(round(float(preview.get_width()) * scale))), maxi(1, int(round(float(preview.get_height()) * scale))), Image.INTERPOLATE_LANCZOS)
	return preview
