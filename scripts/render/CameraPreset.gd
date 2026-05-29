class_name CameraPreset
extends RefCounted

static func names() -> PackedStringArray:
	return PackedStringArray(["aquarium_side_quarter", "ray_top_quarter", "shark_side_quarter"])

static func get_preset(name: String) -> Dictionary:
	match name:
		"ray_top_quarter":
			return {"yaw": 0.0, "pitch": -56.0, "roll": 0.0, "distance": 6.0, "orthographic_size": 3.0}
		"shark_side_quarter":
			return {"yaw": 0.0, "pitch": -10.0, "roll": 0.0, "distance": 6.0, "orthographic_size": 2.0}
		_:
			return {"yaw": 0.0, "pitch": -18.0, "roll": 0.0, "distance": 6.0, "orthographic_size": 2.25}

static func apply_to_camera(camera: Camera3D, preset_name: String, overrides: Dictionary = {}) -> void:
	var preset := get_preset(preset_name)
	for key in overrides.keys():
		if preset.has(key):
			preset[key] = overrides[key]
	var yaw := deg_to_rad(float(preset.get("yaw", 0.0)))
	var pitch := deg_to_rad(float(preset.get("pitch", -18.0)))
	var distance := float(preset.get("distance", 6.0))
	var direction := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)).normalized()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = float(preset.get("orthographic_size", 2.25))
	camera.position = direction * distance
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.rotation_degrees.z += float(preset.get("roll", 0.0))
