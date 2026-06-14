class_name ExportPanel
extends VBoxContainer

signal export_requested

var direction_toggle: CheckButton
var turn_clips_toggle: CheckButton
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
