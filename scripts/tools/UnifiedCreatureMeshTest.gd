extends Node

const PF := preload("res://scripts/creature/PrimitiveFactory.gd")

var _failed := false

func _ready() -> void:
	_test_unified_mesh_shares_head_body_boundary_ring()
	if _failed:
		return
	print("UNIFIED_CREATURE_MESH_TEST_OK")
	get_tree().quit(0)

func _test_unified_mesh_shares_head_body_boundary_ring() -> void:
	var segments := 8
	var head_grid := [
		_make_ring(-1.0, 0.45, 0.35, segments),
		_make_ring(0.0, 1.0, 1.0, segments),
	]
	var body_profile: Array[Vector3] = [
		Vector3(0.0, 1.0, 1.0),
		Vector3(1.0, 0.7, 0.6),
	]
	var mesh: ArrayMesh = PF.build_unified_creature_mesh(head_grid, body_profile, segments)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var expected_ring_count := head_grid.size() + body_profile.size() - 1
	var expected_vertices := expected_ring_count * (segments + 1)
	var expected_indices := (expected_ring_count - 1) * segments * 6
	_require(vertices.size() == expected_vertices, "unified mesh must not duplicate the shared boundary ring")
	_require(indices.size() == expected_indices, "unified mesh must connect every adjacent ring")
	_require(normals.size() == vertices.size(), "unified mesh must provide one normal per vertex")
	var boundary_count := 0
	var boundary_normal_dot := 0.0
	for i in vertices.size():
		var vertex := vertices[i]
		if absf(vertex.x) <= 0.0001:
			boundary_count += 1
			boundary_normal_dot += normals[i].normalized().dot(Vector3(0.0, vertex.y, vertex.z).normalized())
	_require(boundary_count == segments + 1, "head/body boundary ring must appear exactly once")
	_require(boundary_normal_dot / float(maxi(boundary_count, 1)) > 0.4, "boundary normals must be averaged and outward-facing")

func _make_ring(x: float, radius_y: float, radius_z: float, segments: int) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for segment in range(segments + 1):
		var angle := TAU * float(segment) / float(segments)
		ring.append(Vector3(x, sin(angle) * radius_y, cos(angle) * radius_z))
	return ring

func _require(condition: bool, message: String) -> void:
	if condition or _failed:
		return
	_failed = true
	push_error(message)
	get_tree().quit(1)
