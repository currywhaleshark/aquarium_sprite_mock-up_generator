extends Node

const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
const SpeciesArchetypeStoreScript := preload("res://scripts/species/SpeciesArchetypeStore.gd")
const SpeciesMarkingLayerScript := preload("res://scripts/species/SpeciesMarkingLayer.gd")

func _ready() -> void:
	_test_loads_species_archetypes()
	_test_applies_archetype_profiles_and_markings()
	_test_archetype_metadata_round_trips_through_presets()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/species_archetype_store.ok", FileAccess.WRITE)
	file.store_string("species archetypes load, apply, and round-trip")
	file.close()
	print("SPECIES_ARCHETYPE_STORE_TEST_OK")
	get_tree().quit(0)

func _test_loads_species_archetypes() -> void:
	var archetypes := SpeciesArchetypeStoreScript.load_all()
	assert(archetypes.size() >= 2)
	var neon := SpeciesArchetypeStoreScript.load_archetype("neon_tetra")
	assert(String(neon.get("id", "")) == "neon_tetra")
	assert(String(neon.get("label", "")) == "Neon Tetra")
	assert(String(neon.get("creature_type", "")) == "fish")
	assert((neon.get("marking_layers", []) as Array).size() >= 2)

func _test_applies_archetype_profiles_and_markings() -> void:
	var base := {
		"body_length": 1.0,
		"body_height": 0.5,
		"tail_fin_size": 0.5,
		"caudal_shape": "rounded",
		"base_color": "#ffffff",
		"body_profile": {"rings": BodyProfileScript.default_fish_rings()}
	}
	var neon := SpeciesArchetypeStoreScript.load_archetype("neon_tetra")
	var partial := SpeciesArchetypeStoreScript.apply_archetype(base, neon, 0.25, 7)
	assert(String(partial.get("archetype_id", "")) == "neon_tetra")
	assert(abs(float(partial.get("body_length", 0.0)) - 1.1375) < 0.001)
	assert(String(partial.get("caudal_shape", "")) == "rounded")

	var applied := SpeciesArchetypeStoreScript.apply_archetype(base, neon, 1.0, 7)
	assert(String(applied.get("archetype_id", "")) == "neon_tetra")
	assert(abs(float(applied.get("body_length", 0.0)) - 1.55) < 0.001)
	assert(abs(float(applied.get("body_height", 0.0)) - 0.34) < 0.001)
	assert(String(applied.get("caudal_shape", "")) == "forked_shallow")
	assert(String(applied.get("body_profile_shape", "")) == "slender_lateral")
	assert(String(applied.get("swim_mode", "")) == "general")
	assert(int(applied.get("variant_seed", 0)) == 7)
	var layers: Array = applied.get("marking_layers", [])
	assert(layers.size() == 2)
	assert(String(layers[0].get("type", "")) == "lateral_line")
	assert(String(layers[1].get("type", "")) == "horizontal_band")
	assert(String(layers[0].get("region", "")) == "flank")
	assert(String(layers[0].get("blend_mode", "")) == "screen")
	assert(String(layers[1].get("region", "")) == "ventral_flank")
	assert(String(layers[1].get("blend_mode", "")) == "normal")

	var betta := SpeciesArchetypeStoreScript.load_archetype("betta")
	var betta_fin := SpeciesMarkingLayerScript.encode_fin_uniforms(betta.get("marking_layers", []), "median_fin")
	assert(int(betta_fin.get("fin_marking_count", 0)) >= 1)
	var guppy := SpeciesArchetypeStoreScript.load_archetype("guppy")
	var guppy_fin := SpeciesMarkingLayerScript.encode_fin_uniforms(guppy.get("marking_layers", []), "caudal_fin")
	assert(int(guppy_fin.get("fin_marking_count", 0)) >= 1)

func _test_archetype_metadata_round_trips_through_presets() -> void:
	var neon := SpeciesArchetypeStoreScript.load_archetype("neon_tetra")
	var applied := SpeciesArchetypeStoreScript.apply_archetype({
		"body_length": 1.0,
		"body_height": 0.5,
		"base_color": "#ffffff"
	}, neon, 1.0, 12)
	var split := BodyProfileScript.split_parameters_into_profiles(applied, {"name": "neon_round_trip"})
	assert(String(split.get("archetype_id", "")) == "neon_tetra")
	assert(abs(float(split.get("archetype_strength", 0.0)) - 1.0) < 0.001)
	assert(int(split.get("variant_seed", 0)) == 12)
	assert((split.get("marking_layers", []) as Array).size() == 2)

	var rebuilt := BodyProfileScript.make_parameters_from_structured_preset(split)
	assert(String(rebuilt.get("archetype_id", "")) == "neon_tetra")
	assert(abs(float(rebuilt.get("archetype_strength", 0.0)) - 1.0) < 0.001)
	assert(int(rebuilt.get("variant_seed", 0)) == 12)
	assert((rebuilt.get("marking_layers", []) as Array).size() == 2)
