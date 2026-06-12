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
	assert(not PresetStoreScript.find_default_for_mode("shark").is_empty())
	print("PRESET_STORE_MODE_FILTER_TEST_OK")
	get_tree().quit(0)
