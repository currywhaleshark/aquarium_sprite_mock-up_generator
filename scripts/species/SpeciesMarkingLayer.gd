class_name SpeciesMarkingLayer
extends RefCounted

const MAX_MARKING_LAYERS := 8

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

const ZONE_BODY := 0
const ZONE_HEAD := 1
const ZONE_FIN := 2

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
	"reticulated_zone": TYPE_RETICULATED_ZONE
}

const ZONE_BY_NAME := {
	"body": ZONE_BODY,
	"head": ZONE_HEAD,
	"fin": ZONE_FIN
}

static func encode_uniforms(raw_layers: Variant) -> Dictionary:
	var normalized := _normalize_layers(raw_layers)
	var encoded := {"marking_count": normalized.size()}
	for i in MAX_MARKING_LAYERS:
		if i < normalized.size():
			var layer: Dictionary = normalized[i]
			encoded["marking_type_%d" % i] = int(layer["type_id"])
			encoded["marking_zone_%d" % i] = int(layer["zone_id"])
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
			encoded["marking_zone_%d" % i] = ZONE_BODY
			encoded["marking_color_%d" % i] = Color(1, 1, 1, 1)
			encoded["marking_rect_%d" % i] = Vector4(0.0, 1.0, 0.0, 0.05)
			encoded["marking_params_%d" % i] = Vector4(0.0, 0.025, 0.0, float(i))
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
		layer["color"] = String(layer.get("color", "#ffffff"))
		layer["x_start"] = clampf(float(layer.get("x_start", 0.0)), 0.0, 1.0)
		layer["x_end"] = clampf(float(layer.get("x_end", 1.0)), 0.0, 1.0)
		if float(layer["x_end"]) < float(layer["x_start"]):
			var tmp := float(layer["x_start"])
			layer["x_start"] = float(layer["x_end"])
			layer["x_end"] = tmp
		layer["y"] = clampf(float(layer.get("y", 0.0)), -1.0, 1.0)
		layer["thickness"] = maxf(float(layer.get("thickness", 0.05)), 0.001)
		layer["intensity"] = clampf(float(layer.get("intensity", 1.0)), 0.0, 1.0)
		layer["softness"] = maxf(float(layer.get("softness", 0.025)), 0.001)
		layer["emissive"] = clampf(float(layer.get("emissive", 0.0)), 0.0, 1.0)
		layers.append(layer)
	return layers

static func _as_color(value: Variant) -> Color:
	if value is Color:
		return value
	if typeof(value) == TYPE_STRING:
		return Color.html(value)
	return Color(1, 1, 1, 1)
