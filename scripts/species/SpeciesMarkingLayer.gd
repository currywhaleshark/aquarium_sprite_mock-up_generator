class_name SpeciesMarkingLayer
extends RefCounted

const MAX_MARKING_LAYERS := 8
const MAX_FIN_MARKING_LAYERS := 4

const TYPE_NONE := 0
const TYPE_LATERAL_LINE := 1
const TYPE_HORIZONTAL_BAND := 2
const TYPE_VERTICAL_BAR := 3
const TYPE_CAUDAL_SPOT := 4
const TYPE_HEAD_MASK := 5
const TYPE_SADDLE := 6
const TYPE_OCELLUS := 7
const TYPE_CALICO_PATCH := 8
const TYPE_FIN_EDGE := 9
const TYPE_FIN_SPOTS := 10
const TYPE_SCALE_GRID := 11
const TYPE_RETICULATED_ZONE := 12
const TYPE_REGION_COLOR := 13
const TYPE_SCALE_REGION := 14
const TYPE_IRIDESCENCE_REGION := 15

const ZONE_BODY := 0
const ZONE_HEAD := 1
const ZONE_FIN := 2

const REGION_BODY := 0
const REGION_DORSAL := 1
const REGION_FLANK := 2
const REGION_VENTRAL := 3
const REGION_DORSAL_FLANK := 4
const REGION_VENTRAL_FLANK := 5
const REGION_HEAD := 6
const REGION_CHEEK := 7
const REGION_OPERCULUM := 8
const REGION_CAUDAL_PEDUNCLE := 9
const REGION_MEDIAN_FIN := 10
const REGION_PAIRED_FIN := 11
const REGION_CAUDAL_FIN := 12
const REGION_SPECIAL_FIN := 13
const REGION_FIN := 14

const BLEND_NORMAL := 0
const BLEND_MULTIPLY := 1
const BLEND_SCREEN := 2
const BLEND_ADD := 3

const TYPE_BY_NAME := {
	"lateral_line": TYPE_LATERAL_LINE,
	"horizontal_band": TYPE_HORIZONTAL_BAND,
	"vertical_bar": TYPE_VERTICAL_BAR,
	"caudal_spot": TYPE_CAUDAL_SPOT,
	"head_mask": TYPE_HEAD_MASK,
	"saddle": TYPE_SADDLE,
	"ocellus": TYPE_OCELLUS,
	"calico_patch": TYPE_CALICO_PATCH,
	"fin_edge": TYPE_FIN_EDGE,
	"fin_spots": TYPE_FIN_SPOTS,
	"scale_grid": TYPE_SCALE_GRID,
	"reticulated_zone": TYPE_RETICULATED_ZONE,
	"region_color": TYPE_REGION_COLOR,
	"scale_region": TYPE_SCALE_REGION,
	"iridescence_region": TYPE_IRIDESCENCE_REGION
}

const ZONE_BY_NAME := {
	"body": ZONE_BODY,
	"head": ZONE_HEAD,
	"fin": ZONE_FIN
}

const REGION_BY_NAME := {
	"body": REGION_BODY,
	"dorsal": REGION_DORSAL,
	"flank": REGION_FLANK,
	"ventral": REGION_VENTRAL,
	"dorsal_flank": REGION_DORSAL_FLANK,
	"ventral_flank": REGION_VENTRAL_FLANK,
	"head": REGION_HEAD,
	"cheek": REGION_CHEEK,
	"operculum": REGION_OPERCULUM,
	"caudal_peduncle": REGION_CAUDAL_PEDUNCLE,
	"median_fin": REGION_MEDIAN_FIN,
	"paired_fin": REGION_PAIRED_FIN,
	"caudal_fin": REGION_CAUDAL_FIN,
	"special_fin": REGION_SPECIAL_FIN,
	"fin": REGION_FIN
}

const BLEND_BY_NAME := {
	"normal": BLEND_NORMAL,
	"multiply": BLEND_MULTIPLY,
	"screen": BLEND_SCREEN,
	"add": BLEND_ADD
}

static func encode_uniforms(raw_layers: Variant) -> Dictionary:
	var normalized := _normalize_layers(raw_layers)
	var encoded := {"marking_count": normalized.size()}
	for i in MAX_MARKING_LAYERS:
		if i < normalized.size():
			var layer: Dictionary = normalized[i]
			encoded["marking_type_%d" % i] = int(layer["type_id"])
			encoded["marking_region_%d" % i] = int(layer["region_id"])
			encoded["marking_blend_%d" % i] = int(layer["blend_id"])
			encoded["marking_color_%d" % i] = _as_color(layer.get("color", "#ffffff"))
			encoded["marking_rect_%d" % i] = Vector4(
				float(layer.get("x_start", 0.0)),
				float(layer.get("x_end", 1.0)),
				float(layer.get("y", 0.0)),
				float(layer.get("thickness", 0.05))
			)
			encoded["marking_params_%d" % i] = Vector4(
				float(layer.get("intensity", 1.0)),
				float(layer.get("softness", 0.025)),
				float(layer.get("emissive", 0.0)),
				float(layer.get("seed", i))
			)
		else:
			encoded["marking_type_%d" % i] = TYPE_NONE
			encoded["marking_region_%d" % i] = REGION_BODY
			encoded["marking_blend_%d" % i] = BLEND_NORMAL
			encoded["marking_color_%d" % i] = Color(1, 1, 1, 1)
			encoded["marking_rect_%d" % i] = Vector4(0.0, 1.0, 0.0, 0.05)
			encoded["marking_params_%d" % i] = Vector4(0.0, 0.025, 0.0, float(i))
	return encoded

static func encode_fin_uniforms(raw_layers: Variant, fin_region: String) -> Dictionary:
	var normalized := _normalize_layers(raw_layers)
	var requested_region_id := int(REGION_BY_NAME.get(fin_region, REGION_MEDIAN_FIN))
	var allowed_type_ids := [
		TYPE_FIN_EDGE,
		TYPE_FIN_SPOTS,
		TYPE_HORIZONTAL_BAND,
		TYPE_VERTICAL_BAR,
		TYPE_REGION_COLOR
	]
	var fin_layers: Array[Dictionary] = []
	for layer in normalized:
		var type_id := int(layer["type_id"])
		var region_id := int(layer["region_id"])
		if not allowed_type_ids.has(type_id):
			continue
		if region_id != REGION_FIN and region_id != requested_region_id:
			continue
		fin_layers.append(layer)
		if fin_layers.size() >= MAX_FIN_MARKING_LAYERS:
			break
	var encoded := {"fin_marking_count": fin_layers.size()}
	for i in MAX_FIN_MARKING_LAYERS:
		if i < fin_layers.size():
			var layer: Dictionary = fin_layers[i]
			encoded["fin_marking_type_%d" % i] = int(layer["type_id"])
			encoded["fin_marking_blend_%d" % i] = int(layer["blend_id"])
			encoded["fin_marking_color_%d" % i] = _as_color(layer.get("color", "#ffffff"))
			encoded["fin_marking_rect_%d" % i] = Vector4(
				float(layer.get("x_start", 0.0)),
				float(layer.get("x_end", 1.0)),
				float(layer.get("y", 0.0)),
				float(layer.get("fin_thickness", layer.get("thickness", 0.08)))
			)
			encoded["fin_marking_params_%d" % i] = Vector4(
				float(layer.get("intensity", 1.0)),
				float(layer.get("softness", 0.025)),
				float(layer.get("emissive", 0.0)),
				float(layer.get("seed", i))
			)
		else:
			encoded["fin_marking_type_%d" % i] = TYPE_NONE
			encoded["fin_marking_blend_%d" % i] = BLEND_NORMAL
			encoded["fin_marking_color_%d" % i] = Color(1, 1, 1, 1)
			encoded["fin_marking_rect_%d" % i] = Vector4(0.0, 1.0, 0.0, 0.08)
			encoded["fin_marking_params_%d" % i] = Vector4(0.0, 0.025, 0.0, float(i))
	return encoded

static func _normalize_layers(raw_layers: Variant) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	if typeof(raw_layers) != TYPE_ARRAY:
		return layers
	for raw_layer in raw_layers:
		if layers.size() >= MAX_MARKING_LAYERS:
			break
		if typeof(raw_layer) != TYPE_DICTIONARY:
			continue
		var type_name := String(raw_layer.get("type", ""))
		if not TYPE_BY_NAME.has(type_name):
			continue
		var zone_name := String(raw_layer.get("zone", "body"))
		var layer: Dictionary = raw_layer.duplicate(true)
		layer["type_id"] = int(TYPE_BY_NAME[type_name])
		layer["zone_id"] = int(ZONE_BY_NAME.get(zone_name, ZONE_BODY))
		var default_region_name := _default_region_name(zone_name)
		var region_name := String(layer.get("region", default_region_name))
		if not REGION_BY_NAME.has(region_name):
			region_name = "body"
		var blend_name := String(layer.get("blend_mode", "normal"))
		if not BLEND_BY_NAME.has(blend_name):
			blend_name = "normal"
		layer["region"] = region_name
		layer["region_id"] = int(REGION_BY_NAME[region_name])
		layer["blend_mode"] = blend_name
		layer["blend_id"] = int(BLEND_BY_NAME[blend_name])
		layer["color"] = String(layer.get("color", "#ffffff"))
		layer["x_start"] = clampf(float(layer.get("x_start", 0.0)), 0.0, 1.0)
		layer["x_end"] = clampf(float(layer.get("x_end", 1.0)), 0.0, 1.0)
		if float(layer["x_end"]) < float(layer["x_start"]):
			var tmp := float(layer["x_start"])
			layer["x_start"] = float(layer["x_end"])
			layer["x_end"] = tmp
		layer["y"] = clampf(float(layer.get("y", 0.0)), -1.0, 1.0)
		layer["thickness"] = maxf(float(layer.get("thickness", 0.05)), 0.001)
		layer["fin_thickness"] = layer["thickness"] if raw_layer.has("thickness") else 0.08
		layer["intensity"] = clampf(float(layer.get("intensity", 1.0)), 0.0, 1.0)
		layer["softness"] = maxf(float(layer.get("softness", 0.025)), 0.001)
		layer["emissive"] = clampf(float(layer.get("emissive", 0.0)), 0.0, 1.0)
		layers.append(layer)
	return layers

static func _default_region_name(zone_name: String) -> String:
	if zone_name == "fin":
		return "fin"
	return "body"

static func _as_color(value: Variant) -> Color:
	if value is Color:
		return value
	if typeof(value) == TYPE_STRING:
		return Color.html(value)
	return Color(1, 1, 1, 1)
