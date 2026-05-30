extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const FinDragControllerScript := preload("res://scripts/ui/FishFinDragController.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.set_parameters({
		"shell_enabled": 1.0,
		"shell_expand": 0.1,
		"base_color": "#46c6cf",
		"secondary_color": "#d6fbff",
		"dorsal_1_attach_t": 0.45,
		"anal_attach_t": 0.64,
		"pectoral_attach_t": 0.32
	})
	await get_tree().process_frame
	await get_tree().process_frame

	fish.set_fin_attach("dorsal", 0.62)
	fish.set_fin_attach("anal", 0.52)
	fish.set_fin_attach("pectoral", 0.44)

	var dorsal := fish.get_node("BodyPivot/DorsalFin1") as MeshInstance3D
	var anal := fish.get_node("BodyPivot/AnalFin") as MeshInstance3D
	var pectoral_l := fish.get_node("BodyPivot/PectoralFinL") as MeshInstance3D
	var pectoral_r := fish.get_node("BodyPivot/PectoralFinR") as MeshInstance3D
	assert(dorsal.position.x > -0.1)
	assert(anal.position.x < dorsal.position.x)
	assert(pectoral_l.position.x > -0.2)
	assert(abs(pectoral_r.position.x - pectoral_l.position.x) < 0.001)
	assert(abs(pectoral_l.position.z + pectoral_r.position.z) < 0.001)

	var controller: FishFinDragController = FinDragControllerScript.new()
	add_child(controller)
	controller.bind_fish(fish)
	controller.drag_fin_by_pixels("pectoral", Vector2(50.0, 0.0))
	assert(float(fish.parameters.get("pectoral_attach_t", 0.0)) > 0.44)
	assert(abs(pectoral_r.position.x - pectoral_l.position.x) < 0.001)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/fin_drag.ok", FileAccess.WRITE)
	file.store_string("fin drag offsets applied")
	file.close()
	print("FIN_DRAG_TEST_OK")
	get_tree().quit(0)
