extends Node

const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")

func _ready() -> void:
	var fish_presets := PresetStoreScript.load_all("fish")
	var ray_presets := PresetStoreScript.load_all("ray")
	var shark_presets := PresetStoreScript.load_all("shark")
	assert(fish_presets.size() > 0)
	assert(ray_presets.size() > 0)
	assert(shark_presets.size() > 0)
	for preset in fish_presets:
		assert(String(preset.get("creature_type", "")) == "fish")
		assert(String(preset.get("type", "")) == "fish")
	for preset in ray_presets:
		assert(String(preset.get("creature_type", "")) == "ray")
		assert(String(preset.get("type", "")) == "ray")
	for preset in shark_presets:
		assert(String(preset.get("creature_type", "")) == "shark")
		assert(String(preset.get("type", "")) == "shark")
	var default_shark := PresetStoreScript.find_default_for_mode("shark")
	assert(not default_shark.is_empty())
	assert(String(default_shark.get("name", "")) == "basic_shark")
	var default_shark_parameters: Dictionary = default_shark.get("parameters", {})
	assert(abs(float(default_shark_parameters.get("body_length", 0.0)) - 3.8) < 0.001)
	assert(abs(float(default_shark_parameters.get("snout_length", 0.0)) - 0.545) < 0.001)
	assert(String(default_shark_parameters.get("caudal_shape", "")) == "thresher")
	assert(String(default_shark_parameters.get("dorsal_1_shape", "")) == "custom")
	assert((default_shark_parameters.get("dorsal_1_custom_points", []) as Array).size() == 10)
	print("PRESET_STORE_MODE_FILTER_TEST_OK")
	get_tree().quit(0)
