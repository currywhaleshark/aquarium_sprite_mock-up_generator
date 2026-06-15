extends Node

const ExportMetadataScript := preload("res://scripts/export/ExportMetadata.gd")
const SpriteExporterScript := preload("res://scripts/export/SpriteExporter.gd")

func _ready() -> void:
	if not _assert_death_pose_metadata():
		return
	if not _assert_death_pose_ignores_turn_row_pose():
		return
	print("DEATH_POSE_EXPORT_TEST_OK")
	get_tree().quit(0)

func _assert_death_pose_metadata() -> bool:
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
	if not _require(String(metadata.get("pose_clip", "")) == "death", "death pose metadata must use death clip"):
		return false
	if not _require(not bool(metadata.get("turn_clips_enabled", true)), "death pose export must not include turn clips"):
		return false
	if not _require(int(metadata.get("sheet_rows", 0)) == 8, "death pose 8-direction export must have exactly 8 rows"):
		return false
	var rows: Array = metadata.get("animation_rows", [])
	if not _require(rows.size() == 8, "death pose metadata must expose one row per direction"):
		return false
	for row_value in rows:
		var row: Dictionary = row_value
		if not _require(String(row.get("clip", "")) == "death", "death pose rows must be tagged death"):
			return false
	return true

func _assert_death_pose_ignores_turn_row_pose() -> bool:
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
	var turn_row: Dictionary = SpriteExporterScript.animation_rows(8, true)[8]
	exporter.call("_apply_export_row_pose", dummy_rig, Vector3.ZERO, original_parameters, turn_row, 1, 3, 8)
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
