class_name SpeciesArchetype
extends RefCounted

const VALID_LAYER_TYPES := {
	"lateral_line": true,
	"horizontal_band": true,
	"vertical_bar": true,
	"caudal_spot": true,
	"head_mask": true,
	"saddle": true,
	"ocellus": true,
	"calico_patch": true,
	"fin_edge": true,
	"fin_spots": true,
	"scale_grid": true,
	"region_color": true,
	"scale_region": true,
	"iridescence_region": true,
	"reticulated_zone": true
}

static func normalize(raw: Dictionary) -> Dictionary:
	var archetype := raw.duplicate(true)
	archetype["id"] = String(archetype.get("id", "")).strip_edges()
	archetype["label"] = String(archetype.get("label", archetype["id"])).strip_edges()
	archetype["creature_type"] = String(archetype.get("creature_type", "fish"))
	if not archetype.has("profile_overrides") or typeof(archetype["profile_overrides"]) != TYPE_DICTIONARY:
		archetype["profile_overrides"] = {}
	archetype["marking_layers"] = normalize_marking_layers(archetype.get("marking_layers", []))
	if not archetype.has("variant_controls") or typeof(archetype["variant_controls"]) != TYPE_DICTIONARY:
		archetype["variant_controls"] = {}
	return archetype

static func normalize_marking_layers(raw_layers: Variant) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	if typeof(raw_layers) != TYPE_ARRAY:
		return layers
	for raw_layer in raw_layers:
		if typeof(raw_layer) != TYPE_DICTIONARY:
			continue
		var layer: Dictionary = raw_layer.duplicate(true)
		var layer_type := String(layer.get("type", ""))
		if not VALID_LAYER_TYPES.has(layer_type):
			push_warning("Unknown species marking layer type: %s" % layer_type)
			continue
		layer["type"] = layer_type
		layer["zone"] = String(layer.get("zone", "body"))
		layer["x_start"] = clampf(float(layer.get("x_start", 0.0)), 0.0, 1.0)
		layer["x_end"] = clampf(float(layer.get("x_end", 1.0)), 0.0, 1.0)
		if layer_type != "scale_region" and layer_type != "iridescence_region":
			layer["color"] = String(layer.get("color", "#ffffff"))
		if layer_type != "region_color" and layer_type != "scale_region" and layer_type != "iridescence_region":
			layer["y"] = clampf(float(layer.get("y", 0.0)), -1.0, 1.0)
			layer["thickness"] = maxf(float(layer.get("thickness", 0.05)), 0.001)
		if layer_type != "scale_region" and layer_type != "iridescence_region":
			layer["emissive"] = clampf(float(layer.get("emissive", 0.0)), 0.0, 1.0)
		layers.append(layer)
	return layers
