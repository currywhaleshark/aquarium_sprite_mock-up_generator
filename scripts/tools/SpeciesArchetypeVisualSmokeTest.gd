extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const SpeciesArchetypeStoreScript := preload("res://scripts/species/SpeciesArchetypeStore.gd")
const SpeciesArchetypeQAExporterScript := preload("res://scripts/tools/SpeciesArchetypeQAExporter.gd")

const REQUIRED_IDS := [
	"neon_tetra",
	"angelfish",
	"betta",
	"goldfish_oranda",
	"guppy",
	"discus",
	"corydoras",
	"puffer",
	"eel_loach",
	"koi_carp"
]

func _ready() -> void:
	var archetypes := SpeciesArchetypeStoreScript.load_all()
	assert(archetypes.size() >= 10)
	var seen := {}
	for archetype in archetypes:
		seen[String(archetype.get("id", ""))] = archetype
	for id in REQUIRED_IDS:
		assert(seen.has(id), "Missing archetype: %s" % id)

	var distinct_shapes := {}
	var distinct_tails := {}
	for id in REQUIRED_IDS:
		var archetype: Dictionary = seen[id]
		var applied := SpeciesArchetypeStoreScript.apply_archetype({}, archetype, 1.0, 100 + REQUIRED_IDS.find(id))
		assert(String(applied.get("archetype_id", "")) == id)
		assert((applied.get("marking_layers", []) as Array).size() > 0)
		distinct_shapes[String(applied.get("body_profile_shape", "default_fish"))] = true
		distinct_tails[String(applied.get("caudal_shape", ""))] = true
		var fish: FishRig = FishRigScript.new()
		add_child(fish)
		fish.auto_animate = false
		fish.set_parameters(applied)
		await get_tree().process_frame
		assert(fish.get_node_or_null("BodyPivot/OuterShell") != null, "No shell for %s" % id)
		assert(fish.get_node_or_null("BodyPivot/Head") != null, "No head for %s" % id)
		_check_signature_nodes(id, fish, applied)
		fish.queue_free()

	assert(distinct_shapes.size() >= 6)
	assert(distinct_tails.size() >= 7)

	var koi: Dictionary = seen["koi_carp"]
	var qa_preset := SpeciesArchetypeQAExporterScript.build_qa_preset(koi, SpeciesArchetypeStoreScript.apply_archetype({}, koi, 1.0, 1))
	var export_settings: Dictionary = qa_preset.get("export_settings", {})
	assert(int(export_settings.get("direction_count", 0)) == 8)
	assert(int(export_settings.get("frame_count", 0)) == 4)
	assert(SpeciesArchetypeQAExporterScript.contact_sheet_path("koi_carp") == "res://exports/_qa/species_archetypes/koi_carp_contact.png")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/species_archetype_visual_smoke.ok", FileAccess.WRITE)
	file.store_string("species archetype pack visual smoke passed")
	file.close()
	print("SPECIES_ARCHETYPE_VISUAL_SMOKE_TEST_OK")
	get_tree().quit(0)

func _check_signature_nodes(id: String, fish: FishRig, applied: Dictionary) -> void:
	match id:
		"neon_tetra":
			assert(String(applied.get("body_profile_shape", "")) == "slender_lateral")
			assert(String(applied.get("caudal_shape", "")) == "forked_shallow")
		"angelfish":
			assert(String(applied.get("body_profile_shape", "")) == "deep_compressed")
			assert(String(applied.get("dorsal_1_shape", "")) == "trailing")
		"betta":
			assert(String(applied.get("caudal_shape", "")) == "halfmoon")
			assert(float(applied.get("fin_ray_strength", 0.0)) > 0.4)
		"goldfish_oranda":
			assert(fish.get_node_or_null("BodyPivot/Head/HeadOrnament_wen") != null)
			assert(String(applied.get("caudal_shape", "")) == "double_fan")
		"corydoras":
			assert(fish.get_node_or_null("BodyPivot/Head/BarbelCluster_cory") != null)
			assert(String(applied.get("mouth_type", "")) == "inferior")
		"puffer":
			assert(String(applied.get("body_profile_shape", "")) == "round_puffer")
			assert(String(applied.get("eye_style", "")) == "tiny_puffer")
		"eel_loach":
			assert(String(applied.get("swim_mode", "")) == "eel")
			assert(String(applied.get("barbel_style", "")) == "loach")
		"koi_carp":
			assert(fish.get_node_or_null("BodyPivot/Head/BarbelCluster_koi") != null)
			assert(String(applied.get("mouth_detail", "")) == "lip")
