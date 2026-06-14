extends Node

const CreatureModeScript := preload("res://scripts/creature/CreatureMode.gd")
const CreatureRigFactoryScript := preload("res://scripts/creature/CreatureRigFactory.gd")
const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const RayRigScript := preload("res://scripts/creature/RayRig.gd")
const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")
const UiText := preload("res://scripts/ui/UiText.gd")

func _ready() -> void:
	assert(CreatureModeScript.mode_ids() == ["fish", "ray", "shark"])
	assert(CreatureModeScript.normalize("unknown") == "fish")
	assert(UiText.creature_type("shark") == "상어")
	assert(CreatureModeScript.default_camera("ray") == "ray_top_quarter")
	assert(CreatureModeScript.default_camera("shark") == "shark_side_quarter")
	assert(CreatureModeScript.supports_archetypes("fish"))
	assert(not CreatureModeScript.supports_archetypes("ray"))
	assert(not CreatureModeScript.supports_archetypes("shark"))
	assert(CreatureRigFactoryScript.create("fish").get_script() == FishRigScript)
	assert(CreatureRigFactoryScript.create("ray").get_script() == RayRigScript)
	assert(CreatureRigFactoryScript.create("shark").get_script() == SharkRigScript)
	print("CREATURE_MODE_REGISTRY_TEST_OK")
	get_tree().quit(0)
