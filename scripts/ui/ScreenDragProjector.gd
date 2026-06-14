class_name ScreenDragProjector
extends RefCounted

static func screen_delta_on_plane(
	camera: Camera3D,
	from_pos: Vector2,
	to_pos: Vector2,
	plane_point: Vector3,
	plane_normal: Vector3
) -> Vector3:
	if camera == null or plane_normal.length_squared() < 0.000001:
		return Vector3.ZERO
	var normal := plane_normal.normalized()
	var plane := Plane(normal, normal.dot(plane_point))
	var from_hit = plane.intersects_ray(camera.project_ray_origin(from_pos), camera.project_ray_normal(from_pos))
	var to_hit = plane.intersects_ray(camera.project_ray_origin(to_pos), camera.project_ray_normal(to_pos))
	if typeof(from_hit) != TYPE_VECTOR3 or typeof(to_hit) != TYPE_VECTOR3:
		return Vector3.ZERO
	return to_hit - from_hit
