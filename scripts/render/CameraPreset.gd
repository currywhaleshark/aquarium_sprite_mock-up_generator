class_name CameraPreset
extends RefCounted

const SPRITE_QUARTER_2TO1 := "sprite_quarter_2to1"
const SPRITE_QUARTER_LOGICAL_GRID_CELL := 40.0
const SPRITE_QUARTER_PROJECTION_X_SCALE := 0.72
const SPRITE_QUARTER_PROJECTION_Y_SCALE := 0.36

static func names() -> PackedStringArray:
	return PackedStringArray(["aquarium_side_quarter", "ray_top_quarter", "shark_side_quarter"])

static func get_preset(name: String) -> Dictionary:
	match name:
		"sprite_quarter_2to1":
			return {"yaw": 45.0, "pitch": -30.0, "roll": 0.0, "distance": 6.0, "orthographic_size": 2.25}
		"ray_top_quarter":
			return {"yaw": 0.0, "pitch": -56.0, "roll": 0.0, "distance": 6.0, "orthographic_size": 3.0}
		"shark_side_quarter":
			return {"yaw": 0.0, "pitch": -10.0, "roll": 0.0, "distance": 6.0, "orthographic_size": 2.0}
		_:
			return {"yaw": 0.0, "pitch": -18.0, "roll": 0.0, "distance": 6.0, "orthographic_size": 2.25}

static func sprite_quarter_projection() -> Dictionary:
	var projected_w := SPRITE_QUARTER_LOGICAL_GRID_CELL * SPRITE_QUARTER_PROJECTION_X_SCALE * 2.0
	var projected_h := SPRITE_QUARTER_LOGICAL_GRID_CELL * SPRITE_QUARTER_PROJECTION_Y_SCALE * 2.0
	return {
		"logical_grid_cell": SPRITE_QUARTER_LOGICAL_GRID_CELL,
		"projection_x_scale": SPRITE_QUARTER_PROJECTION_X_SCALE,
		"projection_y_scale": SPRITE_QUARTER_PROJECTION_Y_SCALE,
		"projected_cell_size": {"w": projected_w, "h": projected_h},
		"tile_ratio": projected_w / maxf(projected_h, 0.0001)
	}

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
