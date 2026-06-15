extends Node

const ExportMetadataScript := preload("res://scripts/export/ExportMetadata.gd")
const SpriteExporterScript := preload("res://scripts/export/SpriteExporter.gd")

func _ready() -> void:
	if not _assert_death_pose_metadata_includes_death_clip():
		return
	if not _assert_export_rows_select_their_own_pose():
		return
	print("DEATH_POSE_EXPORT_TEST_OK")
	get_tree().quit(0)

func _assert_death_pose_metadata_includes_death_clip() -> bool:
	var metadata := ExportMetadataScript.build({
		"name": "death_export",
		"parameters": {
			"death_pose_enabled": true
		},
		"export_settings": {
			"frame_count": 4,
			"direction_count": 8,
			"include_turn_clips": true
		}
	}, Vector2i(32, 32))
	if not _require(bool(metadata.get("death_pose_enabled", false)), "death pose metadata must mark death_pose_enabled"):
		return false
	if not _require(bool(metadata.get("death_clips_enabled", false)), "death pose metadata must mark death_clips_enabled"):
		return false
	if not _require(String(metadata.get("pose_clip", "")) == "swim", "death pose export must keep swim as the base clip"):
		return false
	if not _require(bool(metadata.get("turn_clips_enabled", false)), "death pose export must keep requested swim turn clips"):
		return false
	if not _require(int(metadata.get("sheet_rows", 0)) == 32, "death pose 8-direction export must add 8 death rows after swim and turn rows"):
		return false
	var rows: Array = metadata.get("animation_rows", [])
	if not _require(rows.size() == 32, "death pose metadata must expose swim, turn, and death rows"):
		return false
	for i in 8:
		var swim_row: Dictionary = rows[i]
		if not _require(String(swim_row.get("clip", "")) == "swim", "first rows must remain swim rows"):
			return false
	for i in range(8, 24):
		var turn_row: Dictionary = rows[i]
		if not _require(String(turn_row.get("clip", "")).begins_with("turn_"), "middle rows must remain turn rows"):
			return false
	for i in range(24, 32):
		var death_row: Dictionary = rows[i]
		if not _require(String(death_row.get("clip", "")) == "death", "final rows must be tagged death"):
			return false
		if not _require(String(death_row.get("frame_dir", "")).begins_with("death/"), "death rows must write to explicit death frame folders"):
			return false
	return true

func _assert_export_rows_select_their_own_pose() -> bool:
	var dummy_script := GDScript.new()
	dummy_script.source_code = "extends \"res://scripts/creature/CreatureRig.gd\"\nvar pose_records := []\nfunc apply_pose(phase: float) -> void:\n\tpose_records.append({\"phase\": phase, \"yaw\": rotation_degrees.y, \"turn_amount\": float(parameters.get(\"turn_amount\", -1.0)), \"turn_phase\": float(parameters.get(\"turn_phase\", -1.0)), \"death_pose_enabled\": bool(parameters.get(\"death_pose_enabled\", false))})"
	dummy_script.reload()
	var dummy_rig := Node3D.new()
	dummy_rig.set_script(dummy_script)
	add_child(dummy_rig)
	var exporter := SpriteExporterScript.new()
	add_child(exporter)
	var original_parameters := {
		"death_pose_enabled": true,
		"turn_amount": 0.25,
		"turn_phase": 0.33
	}
	var rows: Array = SpriteExporterScript.animation_rows(8, true, "swim", true)
	var swim_row: Dictionary = rows[0]
	var turn_row: Dictionary = rows[8]
	var death_row: Dictionary = rows[24]
	var swim_parameters: Dictionary = SpriteExporterScript.row_pose_parameters(original_parameters, swim_row)
	var turn_parameters: Dictionary = SpriteExporterScript.row_pose_parameters(original_parameters, turn_row)
	var death_parameters: Dictionary = SpriteExporterScript.row_pose_parameters(original_parameters, death_row)
	if not _require(not bool(swim_parameters.get("death_pose_enabled", true)), "swim rows must disable death pose even when the preview toggle is on"):
		return false
	if not _require(not bool(turn_parameters.get("death_pose_enabled", true)), "turn rows must disable death pose even when the preview toggle is on"):
		return false
	if not _require(bool(death_parameters.get("death_pose_enabled", false)), "death rows must enable death pose"):
		return false
	exporter.call("_apply_export_row_pose", dummy_rig, Vector3.ZERO, death_parameters, death_row, 1, 3, 8)
	var records: Array = dummy_rig.get("pose_records")
	if not _require(records.size() == 1, "death turn row guard must still apply one pose"):
		return false
	var record: Dictionary = records[0]
	if not _require(_same_float(float(record.get("yaw", 0.0)), 225.0), "death export must keep the source direction yaw instead of tweening a turn"):
		return false
	if not _require(_same_float(float(record.get("turn_amount", 0.0)), 0.25), "death export must not overwrite turn_amount with turn clip motion"):
		return false
	if not _require(bool(record.get("death_pose_enabled", false)), "death export pose must preserve death_pose_enabled"):
		return false
	exporter.call("_apply_export_row_pose", dummy_rig, Vector3.ZERO, turn_parameters, turn_row, 1, 3, 8)
	records = dummy_rig.get("pose_records")
	if not _require(records.size() == 2, "turn row must apply one additional pose"):
		return false
	var turn_record: Dictionary = records[1]
	if not _require(not bool(turn_record.get("death_pose_enabled", true)), "turn export pose must not inherit death_pose_enabled"):
		return false
	if not _require(float(turn_record.get("turn_amount", 0.0)) > 0.0, "turn export pose must still apply turn motion"):
		return false
	dummy_rig.queue_free()
	exporter.queue_free()
	return true

func _same_float(left: float, right: float) -> bool:
	return absf(left - right) < 0.001

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
