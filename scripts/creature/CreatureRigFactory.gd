class_name CreatureRigFactory
extends RefCounted

const CreatureModeScript := preload("res://scripts/creature/CreatureMode.gd")
const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const RayRigScript := preload("res://scripts/creature/RayRig.gd")
const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")

static func create(mode: String) -> CreatureRig:
	match CreatureModeScript.normalize(mode):
		CreatureModeScript.RAY:
			return RayRigScript.new()
		CreatureModeScript.SHARK:
			return SharkRigScript.new()
		_:
			return FishRigScript.new()
