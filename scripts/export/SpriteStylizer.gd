class_name SpriteStylizer
extends RefCounted

# Post-process that gives the rendered 3D fish a flat 2D-game-sprite read without
# touching the rig, meshes, or shaders. It runs on each exported frame image right
# before it is saved (SpriteExporter), so the live editor preview keeps the fast
# smooth render while the *exported* sheet/GIF gets the stylised look.
#
# Two cues do almost all the work of de-3D-ing an already-unshaded render:
#   1. Cel banding (posterize) -- the smooth back->belly countershading gradient is
#      the strongest 3D tell. Quantising brightness into a few flat steps reads as
#      hand-painted cel shading instead of a render. Hue and saturation are kept so
#      the fish holds its colour identity; only the value (light/shadow) is banded.
#   2. Silhouette outline -- 2D sprites almost always carry an ink line. We grow a
#      solid-colour border around the alpha silhouette (crisping the anti-aliased
#      fringe first so the line reads sharp).
#
# Defaults are tuned for the ~256 px exports; the outline width auto-scales with the
# frame size so higher-resolution exports get a proportionally thicker line.

const DEFAULT_OUTLINE_COLOR := "#11181d"

# Merged stylise options: caller-supplied export_settings["stylize"] layered over
# the defaults. "enabled" defaults OFF so programmatic exports (smoke tests, QA
# shots) stay unchanged unless they opt in; the editor's export toggle sets it.
static func resolve_options(export_settings: Dictionary) -> Dictionary:
	var options := default_options()
	var overrides: Variant = export_settings.get("stylize", {})
	if overrides is Dictionary:
		for key in (overrides as Dictionary).keys():
			options[key] = (overrides as Dictionary)[key]
	return options

static func default_options() -> Dictionary:
	return {
		"enabled": false,
		"posterize_levels": 5, # value bands; < 2 disables cel banding
		"outline_width": 0, # px; 0 = auto from frame size via outline_scale
		"outline_scale": 0.011, # fraction of min(w, h) used when outline_width == 0
		"outline_color": DEFAULT_OUTLINE_COLOR,
		"crisp_alpha": true, # snap the AA fringe to a hard silhouette
		"alpha_threshold": 0.5, # silhouette cutoff for crisping + outline
	}

# Applies the stylise pass in place. Order matters: cel-band the interior first so
# the flat outline colour is never itself posterised, then crisp + draw the outline.
static func stylize(image: Image, options: Dictionary) -> void:
	if image == null or image.is_empty():
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var levels := int(options.get("posterize_levels", 0))
	if levels >= 2:
		_posterize_value(image, levels)
	var width := _effective_outline_width(image, options)
	if width > 0:
		var threshold := clampf(float(options.get("alpha_threshold", 0.5)), 0.0, 1.0)
		if bool(options.get("crisp_alpha", true)):
			_crisp_alpha(image, threshold)
		_add_outline(image, width, _as_color(options.get("outline_color", DEFAULT_OUTLINE_COLOR)), threshold)

static func _effective_outline_width(image: Image, options: Dictionary) -> int:
	var explicit := int(options.get("outline_width", 0))
	if explicit > 0:
		return explicit
	var scale := float(options.get("outline_scale", 0.0))
	if scale <= 0.0:
		return 0
	var minor := mini(image.get_width(), image.get_height())
	return maxi(1, int(round(float(minor) * scale)))

# Quantise brightness into `levels` flat steps while keeping hue + saturation, so a
# smooth gradient collapses into a few cel bands. Transparent pixels are skipped.
static func _posterize_value(image: Image, levels: int) -> void:
	var steps := float(maxi(levels, 2) - 1)
	var w := image.get_width()
	var h := image.get_height()
	for y in h:
		for x in w:
			var c := image.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var quantised_v: float = round(c.v * steps) / steps
			image.set_pixel(x, y, Color.from_hsv(c.h, c.s, quantised_v, c.a))

# Snap the anti-aliased edge to a hard silhouette: pixels at/above the threshold go
# fully opaque, the rest fully transparent. RGB is preserved so colours don't shift.
static func _crisp_alpha(image: Image, threshold: float) -> void:
	var w := image.get_width()
	var h := image.get_height()
	for y in h:
		for x in w:
			var c := image.get_pixel(x, y)
			c.a = 1.0 if c.a >= threshold else 0.0
			image.set_pixel(x, y, c)

# Grows a solid-colour outline around the silhouette. The silhouette mask is read
# once into a flat byte array, then dilated `width` times (8-neighbour) so the cost
# scales linearly with width instead of width^2. Only newly covered (formerly
# transparent) pixels are painted, so interior colours are preserved.
static func _add_outline(image: Image, width: int, color: Color, threshold: float) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var data := image.get_data()
	var cutoff := int(clampf(threshold, 0.0, 1.0) * 255.0)
	var count := w * h
	var solid := PackedByteArray()
	solid.resize(count)
	for i in count:
		solid[i] = 1 if data[i * 4 + 3] >= cutoff else 0
	var grown := solid.duplicate()
	for _step in width:
		var next := grown.duplicate()
		for y in h:
			var row := y * w
			var has_up := y > 0
			var has_down := y < h - 1
			for x in w:
				var idx := row + x
				if grown[idx] == 1:
					continue
				var has_left := x > 0
				var has_right := x < w - 1
				var up := idx - w
				var down := idx + w
				if (has_left and grown[idx - 1] == 1) \
						or (has_right and grown[idx + 1] == 1) \
						or (has_up and grown[up] == 1) \
						or (has_down and grown[down] == 1) \
						or (has_up and has_left and grown[up - 1] == 1) \
						or (has_up and has_right and grown[up + 1] == 1) \
						or (has_down and has_left and grown[down - 1] == 1) \
						or (has_down and has_right and grown[down + 1] == 1):
					next[idx] = 1
		grown = next
	for y in h:
		var row := y * w
		for x in w:
			var idx := row + x
			if grown[idx] == 1 and solid[idx] == 0:
				image.set_pixel(x, y, color)

static func _as_color(value: Variant) -> Color:
	if value is Color:
		return value
	if typeof(value) == TYPE_STRING:
		return Color.html(String(value))
	return Color.html(DEFAULT_OUTLINE_COLOR)
