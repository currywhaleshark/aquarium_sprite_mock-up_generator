class_name RayRig
extends "res://scripts/creature/CreatureRig.gd"

const PF := preload("res://scripts/creature/PrimitiveFactory.gd")
const TMF := preload("res://scripts/materials/ToonMaterialFactory.gd")

var disc_body: Node3D
var wing_pivot_l: Node3D
var wing_pivot_r: Node3D
var tail_pivot_1: Node3D
var tail_pivot_2: Node3D
var mantle_shell: MeshInstance3D
var mantle_radius_x := 0.0
var mantle_radius_z := 0.0
var mantle_crown_height := 0.0
var mantle_segments := 48

func rebuild() -> void:
	super.rebuild()
	await get_tree().process_frame
	mantle_shell = null
	var base_mat := TMF.make_surface(param_color("base_color", "#6dbbc3"), param_float("shadow_strength", 0.35), param_float("highlight_strength", 0.5))
	var underside_mat := TMF.make_surface(param_color("underside_color", "#d7f0ed"), 0.18, 0.45)
	var eye_mat := TMF.make_dark("#10161a")
	var shell_color := param_color("base_color", "#6dbbc3").lerp(param_color("underside_color", "#d7f0ed"), param_float("shell_color_mix", 0.16))
	var shell_mat := TMF.make_shell(shell_color, param_float("shell_opacity", 0.68))

	var disc_width := param_float("disc_width", 1.35)
	var disc_length := param_float("disc_length", 1.05)
	var disc_thickness := param_float("disc_thickness", 0.16)
	var wing_width := param_float("wing_width", 1.25)
	var wing_length := param_float("wing_length", 1.02)
	var wing_curve := param_float("wing_curve", 0.05)
	var tail_length := param_float("tail_length", 1.35)
	var tail_thickness := param_float("tail_thickness", 0.055)

	disc_body = Node3D.new()
	disc_body.name = "DiscBody"
	add_child(disc_body)

	if param_float("shell_enabled", 1.0) > 0.5:
		var shell_expand := param_float("shell_expand", 0.08)
		mantle_radius_x = disc_length * 0.56 + wing_length * 0.28 + shell_expand
		mantle_radius_z = disc_width * 0.52 + wing_width * 0.34 + shell_expand
		mantle_crown_height = disc_thickness * 0.72 + shell_expand * 0.25
		mantle_shell = PF.ray_mantle_shell(
			"MantleShell",
			mantle_radius_x,
			mantle_radius_z,
			mantle_crown_height,
			shell_mat,
			mantle_segments
		)
		disc_body.add_child(mantle_shell)

	var disc := PF.ellipsoid("Disc", Vector3(disc_length, disc_thickness, disc_width), base_mat)
	disc_body.add_child(disc)

	var underside := PF.ellipsoid("UndersidePatch", Vector3(disc_length * 0.58, disc_thickness * 0.32, disc_width * 0.55), underside_mat)
	underside.position.y = -disc_thickness * 0.35
	disc_body.add_child(underside)

	wing_pivot_l = Node3D.new()
	wing_pivot_l.name = "WingPivotL"
	disc_body.add_child(wing_pivot_l)
	var wing_l := PF.ray_wing("WingL", -1.0, wing_length, wing_width, wing_curve, base_mat)
	wing_pivot_l.add_child(wing_l)

	wing_pivot_r = Node3D.new()
	wing_pivot_r.name = "WingPivotR"
	disc_body.add_child(wing_pivot_r)
	var wing_r := PF.ray_wing("WingR", 1.0, wing_length, wing_width, wing_curve, base_mat)
	wing_pivot_r.add_child(wing_r)

	var eye_spacing := param_float("eye_spacing", 0.34)
	var eye_size := param_float("eye_size", 0.045)
	for side in [-1.0, 1.0]:
		var eye := PF.ellipsoid("Eye%s" % ("L" if side < 0.0 else "R"), Vector3(eye_size, eye_size, eye_size), eye_mat)
		eye.position = Vector3(-disc_length * 0.28, disc_thickness * 0.48, side * eye_spacing)
		disc_body.add_child(eye)

	tail_pivot_1 = Node3D.new()
	tail_pivot_1.name = "TailPivot1"
	tail_pivot_1.position = Vector3(disc_length * 0.48, 0.0, 0.0)
	disc_body.add_child(tail_pivot_1)

	var tail_1 := PF.tapered_segment("Tail1", tail_length * 0.62, tail_thickness, tail_thickness, base_mat)
	tail_1.position = Vector3(tail_length * 0.31, 0.0, 0.0)
	tail_pivot_1.add_child(tail_1)

	tail_pivot_2 = Node3D.new()
	tail_pivot_2.name = "TailPivot2"
	tail_pivot_2.position = Vector3(tail_length * 0.62, 0.0, 0.0)
	tail_pivot_1.add_child(tail_pivot_2)

	var tail_tip := PF.tapered_segment("TailTip", tail_length * 0.38, tail_thickness * 0.55, tail_thickness * 0.55, base_mat)
	tail_tip.position = Vector3(tail_length * 0.19, 0.0, 0.0)
	tail_pivot_2.add_child(tail_tip)

func apply_pose(loop_phase: float) -> void:
	var wave := sin(loop_phase * TAU)
	position.y = wave * param_float("glide_bob_amount", 0.025)
	if disc_body:
		disc_body.rotation_degrees.z = wave * 1.2
	var flap := wave * param_float("flap_amplitude", 8.0)
	if wing_pivot_l:
		wing_pivot_l.rotation_degrees.x = flap
	if wing_pivot_r:
		wing_pivot_r.rotation_degrees.x = flap
	var follow := param_float("tail_follow_amount", 5.0)
	if tail_pivot_1:
		tail_pivot_1.rotation_degrees.y = sin(loop_phase * TAU - 0.7) * follow
	if tail_pivot_2:
		tail_pivot_2.rotation_degrees.y = sin(loop_phase * TAU - 1.1) * follow * 1.4
	_deform_shell(flap)

func _deform_shell(flap: float) -> void:
	if mantle_shell == null:
		return
	var flap_lift := flap * 0.01
	PF.update_ray_mantle_shell(mantle_shell, mantle_radius_x, mantle_radius_z, mantle_crown_height, flap_lift, mantle_segments)
