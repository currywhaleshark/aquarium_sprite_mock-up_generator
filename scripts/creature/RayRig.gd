class_name RayRig
extends "res://scripts/creature/CreatureRig.gd"

const PF := preload("res://scripts/creature/PrimitiveFactory.gd")
const TMF := preload("res://scripts/materials/ToonMaterialFactory.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
const UiText := preload("res://scripts/ui/UiText.gd")

var disc_body: Node3D
var body_mesh: MeshInstance3D
var eye_l: MeshInstance3D
var eye_r: MeshInstance3D
var tail_pivot_1: Node3D
var tail_pivot_2: Node3D
var cephalic_l: MeshInstance3D
var cephalic_r: MeshInstance3D
var pelvic_l: MeshInstance3D
var pelvic_r: MeshInstance3D

var mantle_radius_x := 0.0
var mantle_radius_z := 0.0
var mantle_crown_height := 0.0

var top_rest_vertices: PackedVector3Array
var bottom_rest_vertices: PackedVector3Array

var ring_editor_enabled := false
var selected_body_ring_id := ""
var body_ring_world_points := {}
var shell_profile: Array[Vector3] = []
var shell_center_y_offsets: Array[float] = []
var shell_ring_ids: Array[String] = []

func rebuild() -> void:
	super.rebuild()
	await get_tree().process_frame
	body_mesh = null
	eye_l = null
	eye_r = null
	cephalic_l = null
	cephalic_r = null
	pelvic_l = null
	pelvic_r = null
	
	var base_mat := TMF.make_surface(param_color("base_color", "#6dbbc3"), param_float("shadow_strength", 0.35), param_float("highlight_strength", 0.5))
	var underside_mat := TMF.make_surface(param_color("underside_color", "#d7f0ed"), 0.18, 0.45)
	var eye_mat := TMF.make_dark("#10161a")

	var disc_width := param_float("disc_width", 1.35)
	var disc_length := param_float("disc_length", 1.05)
	var disc_thickness := param_float("disc_thickness", 0.16)
	var wing_width := param_float("wing_width", 1.25)
	var tail_length := param_float("tail_length", 1.35)
	var tail_thickness := param_float("tail_thickness", 0.055)
	var shell_roundness := param_float("shell_roundness", 1.0)
	var cephalic_style := String(parameters.get("cephalic_horns", "none"))

	var body_profile := BodyProfileScript.ensure_body_profile(parameters)
	parameters["body_profile"] = body_profile
	var rings: Array = body_profile.get("rings", [])
	var head_shape := String(parameters.get("ray_head_shape", "manta"))
	var snout_len := param_float("snout_length", 0.3)

	disc_body = Node3D.new()
	disc_body.name = "DiscBody"
	add_child(disc_body)

	# 1. Build the seamless unified body mesh (double-sided)
	mantle_radius_x = disc_length * 0.5
	mantle_radius_z = wing_width
	mantle_crown_height = disc_thickness
	
	shell_profile.clear()
	shell_center_y_offsets.clear()
	shell_ring_ids.clear()
	
	for i in rings.size():
		var ring: Dictionary = BodyProfileScript.normalize_ring(rings[i], i)
		var ring_id := String(ring.get("id", ""))
		var rx := float(ring["x"])
		var lx := -mantle_radius_x + 2.0 * mantle_radius_x * rx
		var radius_y := disc_thickness * (float(ring["upper_height"]) + float(ring["lower_height"])) * 0.5
		var center_y := disc_thickness * (float(ring["y_offset"]) + (float(ring["upper_height"]) - float(ring["lower_height"])) * 0.5)
		var radius_z := wing_width * (float(ring["width"]) / 0.45)
		
		shell_profile.append(Vector3(lx, radius_y, radius_z))
		shell_center_y_offsets.append(center_y)
		shell_ring_ids.append(ring_id)
	
	var array_mesh := PF.build_ray_grid_mesh(mantle_radius_x, mantle_radius_z, mantle_crown_height, shell_roundness, true, rings, head_shape, snout_len)
	body_mesh = MeshInstance3D.new()
	body_mesh.name = "BodyMesh"
	body_mesh.mesh = array_mesh
	body_mesh.set_surface_override_material(0, base_mat)
	body_mesh.set_surface_override_material(1, underside_mat)
	disc_body.add_child(body_mesh)
	
	# Cache rest vertices for Y-deformation
	var top_arrays = array_mesh.surface_get_arrays(0)
	top_rest_vertices = top_arrays[Mesh.ARRAY_VERTEX]
	var bottom_arrays = array_mesh.surface_get_arrays(1)
	bottom_rest_vertices = bottom_arrays[Mesh.ARRAY_VERTEX]

	# 2. Cephalic Horns (if enabled)
	var eye_spacing := param_float("eye_spacing", 0.34)
	if cephalic_style != "none":
		var horn_len := disc_length * 0.22
		var horn_thick := disc_thickness * 0.35
		cephalic_l = PF.ray_cephalic_lobe("CephalicL", cephalic_style, horn_len, horn_thick, base_mat)
		cephalic_l.position = Vector3(-disc_length * 0.45, disc_thickness * 0.15, -eye_spacing * 0.72)
		cephalic_l.rotation_degrees = Vector3(0, 15, 0)
		disc_body.add_child(cephalic_l)

		cephalic_r = PF.ray_cephalic_lobe("CephalicR", cephalic_style, horn_len, horn_thick, base_mat)
		cephalic_r.position = Vector3(-disc_length * 0.45, disc_thickness * 0.15, eye_spacing * 0.72)
		cephalic_r.rotation_degrees = Vector3(0, -15, 0)
		disc_body.add_child(cephalic_r)

	# 3. Pelvic Lobes (always present in rays next to tail base)
	var pelvic_len_val := param_float("pelvic_length", 0.22)
	var pelvic_h_val := param_float("pelvic_height", 0.14)
	var pelvic_w := disc_width * pelvic_h_val * 1.5
	var pelvic_l_len := disc_length * pelvic_len_val * 1.1
	var pelvic_t := disc_thickness * pelvic_h_val * 2.2
	
	pelvic_l = PF.ellipsoid("PelvicL", Vector3(pelvic_l_len, pelvic_t, pelvic_w), base_mat)
	pelvic_l.position = Vector3(disc_length * 0.42, -disc_thickness * 0.15, -disc_width * 0.16)
	pelvic_l.rotation_degrees = Vector3(0, -8, 0)
	disc_body.add_child(pelvic_l)
	
	pelvic_r = PF.ellipsoid("PelvicR", Vector3(pelvic_l_len, pelvic_t, pelvic_w), base_mat)
	pelvic_r.position = Vector3(disc_length * 0.42, -disc_thickness * 0.15, disc_width * 0.16)
	pelvic_r.rotation_degrees = Vector3(0, 8, 0)
	disc_body.add_child(pelvic_r)

	# 4. Eyes (positioned on top of the dome)
	var eye_size := param_float("eye_size", 0.045)
	
	eye_l = PF.ellipsoid("EyeL", Vector3(eye_size, eye_size, eye_size), eye_mat)
	eye_l.position = Vector3(-disc_length * 0.28, disc_thickness * 0.48, -eye_spacing)
	disc_body.add_child(eye_l)

	# 5. Eye R
	eye_r = PF.ellipsoid("EyeR", Vector3(eye_size, eye_size, eye_size), eye_mat)
	eye_r.position = Vector3(-disc_length * 0.28, disc_thickness * 0.48, eye_spacing)
	disc_body.add_child(eye_r)

	# 5. Tail
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
	
	_update_body_ring_world_points()
	if ring_editor_enabled or param_float("show_ring_guides", 0.0) > 0.5:
		_add_ring_guides()

func apply_pose(loop_phase: float) -> void:
	# Glide bobbing
	var bob_wave := sin(loop_phase * TAU)
	position.y = bob_wave * param_float("glide_bob_amount", 0.025)
	if disc_body:
		disc_body.rotation_degrees.z = bob_wave * 1.2
		
	# Locomotion Mode configurations
	var loc_mode := String(parameters.get("ray_locomotion_mode", "rajiform"))
	var wave_ripples := param_float("wave_ripples", 1.2)
	var flap_amp := param_float("flap_amplitude", 8.0)
	var sync_mode := String(parameters.get("pectoral_flap_sync", "alternating"))
	
	if loc_mode == "mobuliform":
		wave_ripples = 0.6
		flap_amp *= 1.5
	elif loc_mode == "rajiform":
		wave_ripples = 1.6
	elif loc_mode == "punting":
		# Minimal background breathing wave for body wings when walking on substrate
		flap_amp = 1.5
		wave_ripples = 1.0

	var get_wave_y := func(pos: Vector3) -> float:
		var wing_t := absf(pos.z) / maxf(mantle_radius_z, 0.001)
		var amp := flap_amp * 0.025 * pow(wing_t, 1.5)
		var t_x := (pos.x + mantle_radius_x) / maxf(2.0 * mantle_radius_x, 0.001)
		var phase := loop_phase * TAU - t_x * wave_ripples * TAU
		var side_phase := 0.0
		if pos.z < 0.0 and sync_mode == "alternating":
			side_phase = PI
		return amp * sin(phase + side_phase)

	# Deform body mesh Top Surface
	if body_mesh and body_mesh.mesh:
		var top_arrays = body_mesh.mesh.surface_get_arrays(0)
		var top_verts: PackedVector3Array = top_arrays[Mesh.ARRAY_VERTEX]
		for i in top_verts.size():
			var p_rest := top_rest_vertices[i]
			top_verts[i].y = p_rest.y + get_wave_y.call(p_rest)
		top_arrays[Mesh.ARRAY_VERTEX] = top_verts
		
		# Deform body mesh Bottom Surface
		var bottom_arrays = body_mesh.mesh.surface_get_arrays(1)
		var bottom_verts: PackedVector3Array = bottom_arrays[Mesh.ARRAY_VERTEX]
		for i in bottom_verts.size():
			var p_rest := bottom_rest_vertices[i]
			bottom_verts[i].y = p_rest.y + get_wave_y.call(p_rest)
		bottom_arrays[Mesh.ARRAY_VERTEX] = bottom_verts
		
		var new_mesh := ArrayMesh.new()
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, top_arrays)
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bottom_arrays)
		body_mesh.mesh = new_mesh

	# Move Eyes vertically in sync with body wave
	var eye_rest_y = param_float("disc_thickness", 0.16) * 0.48
	if eye_l:
		eye_l.position.y = eye_rest_y + get_wave_y.call(eye_l.position)
	if eye_r:
		eye_r.position.y = eye_rest_y + get_wave_y.call(eye_r.position)
		
	# Move Cephalic Horns vertically and tilt them in sync with body wave
	var snout_y: float = get_wave_y.call(Vector3(-mantle_radius_x * 0.9, 0.0, 0.0))
	var horn_base_y := param_float("disc_thickness", 0.16) * 0.15
	if cephalic_l:
		cephalic_l.position.y = horn_base_y + snout_y
		cephalic_l.rotation_degrees.x = snout_y * 15.0
	if cephalic_r:
		cephalic_r.position.y = horn_base_y + snout_y
		cephalic_r.rotation_degrees.x = snout_y * 15.0

	# Animate Pelvic Fins
	var base_pelvic_y := -param_float("disc_thickness", 0.16) * 0.15
	if loc_mode == "punting":
		# Punting: pelvic fins rowing / walking back and forth
		var row_phase := loop_phase * TAU
		var row_angle_l := sin(row_phase) * 22.0
		var row_angle_r := sin(row_phase + PI) * 22.0 # Alternating bipedal punting
		
		if pelvic_l:
			pelvic_l.rotation_degrees = Vector3(cos(row_phase) * 6.0, -8.0 + row_angle_l, 0.0)
			pelvic_l.position.y = base_pelvic_y + sin(row_phase) * 0.03
		if pelvic_r:
			pelvic_r.rotation_degrees = Vector3(cos(row_phase + PI) * 6.0, 8.0 + row_angle_r, 0.0)
			pelvic_r.position.y = base_pelvic_y + sin(row_phase + PI) * 0.03
	else:
		# Swimming modes: wave in phase with tail base
		if pelvic_l:
			var wave_y_l: float = get_wave_y.call(pelvic_l.position)
			pelvic_l.position.y = base_pelvic_y + wave_y_l
			pelvic_l.rotation_degrees = Vector3(0.0, -8.0, wave_y_l * 12.0)
		if pelvic_r:
			var wave_y_r: float = get_wave_y.call(pelvic_r.position)
			pelvic_r.position.y = base_pelvic_y + wave_y_r
			pelvic_r.rotation_degrees = Vector3(0.0, 8.0, -wave_y_r * 12.0)
		
	# Move Tail base vertically in sync with body wave
	if tail_pivot_1:
		var tail_base_pos := Vector3(param_float("disc_length", 1.05) * 0.48, 0.0, 0.0)
		tail_pivot_1.position.y = get_wave_y.call(tail_base_pos)

	# Tail follow rotation
	var follow := param_float("tail_follow_amount", 5.0)
	if tail_pivot_1:
		tail_pivot_1.rotation_degrees.y = sin(loop_phase * TAU - 0.7) * follow
	if tail_pivot_2:
		tail_pivot_2.rotation_degrees.y = sin(loop_phase * TAU - 1.1) * follow * 1.4

func set_ring_editor_enabled(enabled: bool) -> void:
	ring_editor_enabled = enabled
	rebuild()

func set_selected_body_ring(ring_id: String) -> void:
	selected_body_ring_id = ring_id
	parameters["selected_body_ring_id"] = ring_id
	rebuild()

func get_body_ring_global_points() -> Dictionary:
	_update_body_ring_world_points()
	return body_ring_world_points.duplicate(true)

func _update_body_ring_world_points() -> void:
	body_ring_world_points.clear()
	if disc_body == null:
		return
	for i in shell_profile.size():
		var ring_id := shell_ring_ids[i]
		var center_y := shell_center_y_offsets[i]
		body_ring_world_points[ring_id] = disc_body.to_global(Vector3(shell_profile[i].x, center_y, 0.0))

func _add_ring_guides() -> void:
	var guide_root := Node3D.new()
	guide_root.name = "BodyRingGuides"
	disc_body.add_child(guide_root)
	var guide_mat := TMF.make_surface(Color.html("#f6d365"), 0.2, 0.65)
	var selected_mat := TMF.make_surface(Color.html("#ff4d6d"), 0.18, 0.75)
	var endpoint_mat := TMF.make_surface(Color.html("#f8f9fa"), 0.12, 0.55)
	for i in shell_profile.size():
		var ring_id := shell_ring_ids[i]
		var selected := ring_id == selected_body_ring_id
		var center_y := shell_center_y_offsets[i]
		var point := shell_profile[i]
		var center := PF.ellipsoid("RingCenter_%s" % ring_id, Vector3(0.035, 0.035, 0.035), selected_mat if selected else guide_mat)
		center.position = Vector3(point.x, center_y, 0.0)
		guide_root.add_child(center)
		var top := PF.ellipsoid("RingTop_%s" % ring_id, Vector3(0.02, 0.02, 0.02), selected_mat if selected else endpoint_mat)
		top.position = Vector3(point.x, center_y + point.y, 0.0)
		guide_root.add_child(top)
		var bottom := PF.ellipsoid("RingBottom_%s" % ring_id, Vector3(0.02, 0.02, 0.02), selected_mat if selected else endpoint_mat)
		bottom.position = Vector3(point.x, center_y - point.y, 0.0)
		guide_root.add_child(bottom)
		var label := Label3D.new()
		label.name = "RingLabel_%s" % ring_id
		label.text = UiText.body_ring(ring_id, "Ring")
		label.font_size = 18
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(point.x, center_y + point.y + 0.08, 0.0)
		guide_root.add_child(label)
