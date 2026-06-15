extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const MainScript := preload("res://scripts/ui/Main.gd")

func _ready() -> void:
	var main := MainScript.new()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var toggle := main.get("death_pose_toggle") as CheckButton
	if not _require(toggle != null, "death pose toggle must exist beside turn controls"):
		return
	toggle.toggled.emit(true)
	await get_tree().process_frame
	await get_tree().process_frame

	var fish := main.get("current_rig") as FishRig
	if not _require(fish != null, "current rig must be a fish"):
		return
	fish.auto_animate = false
	var parameters: Dictionary = fish.get("parameters")
	if not _require(bool(parameters.get("death_pose_enabled", false)), "death toggle must write death_pose_enabled"):
		return

	fish.apply_pose(0.25)
	var body_pivot := fish.get_node_or_null("BodyPivot") as Node3D
	if not _require(body_pivot != null, "fish must have BodyPivot"):
		return
	if not _require(absf(absf(body_pivot.rotation_degrees.x) - 180.0) < 0.01, "death pose must turn belly up"):
		return
	if not _require(fish.position.y > 0.005, "death pose must keep a small floating bob"):
		return

	var shell := fish.get("outer_shell") as MeshInstance3D
	if not _require(shell != null, "death pose fish must keep outer shell"):
		return
	var body_material := shell.material_override as ShaderMaterial
	if not _require(body_material != null, "outer shell must use body shader material"):
		return
	var dead_base := body_material.get_shader_parameter("base_color") as Color
	var live_base := Color.html("#46c6cf")
	if not _require(dead_base.s < live_base.s * 0.5, "death pose must reduce body color saturation"):
		return

	var pupil := fish.get_node_or_null("BodyPivot/EyeL/Pupil") as MeshInstance3D
	if not _require(pupil != null, "death pose fish must keep eye pupil node"):
		return
	var pupil_material := pupil.material_override as StandardMaterial3D
	if not _require(pupil_material != null, "pupil must use a material"):
		return
	if not _require(pupil_material.albedo_color.v > 0.75, "death pose pupil must turn pale"):
		return
	if not _require(pupil_material.albedo_color.s < 0.2, "death pose pupil must be desaturated"):
		return

	print("DEATH_POSE_TOGGLE_TEST_OK")
	get_tree().quit(0)

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
