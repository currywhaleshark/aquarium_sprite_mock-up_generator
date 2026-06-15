extends Node

const SpriteStylizerScript := preload("res://scripts/export/SpriteStylizer.gd")

func _ready() -> void:
	_test_resolve_options_defaults_off_and_merges()
	_test_posterize_collapses_value_gradient()
	_test_outline_wraps_silhouette_and_spares_background()
	_test_crisp_alpha_hardens_fringe()
	_test_disabled_options_are_a_noop()
	print("SPRITE_STYLIZER_TEST_OK")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)

func _test_resolve_options_defaults_off_and_merges() -> void:
	var defaults := SpriteStylizerScript.resolve_options({})
	if bool(defaults.get("enabled", true)):
		_fail("stylize should default to disabled when unset")
		return
	var merged := SpriteStylizerScript.resolve_options({"stylize": {"enabled": true, "posterize_levels": 3}})
	if not bool(merged.get("enabled", false)) or int(merged.get("posterize_levels", 0)) != 3:
		_fail("stylize overrides should layer over defaults")
		return
	# Untouched keys keep their default.
	if not merged.has("outline_color"):
		_fail("merged options should retain default keys")

func _test_posterize_collapses_value_gradient() -> void:
	var size := 24
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	# A smooth value ramp across X at a fixed hue: the kind of gradient that reads 3D.
	for y in size:
		for x in size:
			var v := float(x) / float(size - 1)
			image.set_pixel(x, y, Color.from_hsv(0.5, 0.6, v, 1.0))
	SpriteStylizerScript.stylize(image, {"posterize_levels": 3, "outline_width": 0, "outline_scale": 0.0})
	var distinct := {}
	for x in size:
		var key := str(snappedf(image.get_pixel(x, 0).v, 0.001))
		distinct[key] = true
	# 3 levels means at most 3 flat value bands across the whole ramp.
	if distinct.size() > 3:
		_fail("posterize to 3 levels should leave <= 3 value bands, got %d" % distinct.size())
		return
	if distinct.size() < 2:
		_fail("posterize should still leave more than one band on a full ramp")

func _test_outline_wraps_silhouette_and_spares_background() -> void:
	var size := 12
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Solid opaque block in the middle (rows/cols 4..7).
	for y in range(4, 8):
		for x in range(4, 8):
			image.set_pixel(x, y, Color(1, 0, 0, 1))
	var outline := Color.html("#0000ff")
	SpriteStylizerScript.stylize(image, {
		"posterize_levels": 0,
		"outline_width": 1,
		"outline_color": "#0000ff",
		"crisp_alpha": true,
		"alpha_threshold": 0.5,
	})
	# A pixel just outside the block becomes the outline colour.
	var border := image.get_pixel(3, 5)
	if not border.is_equal_approx(outline):
		_fail("outline should paint the border pixel, got %s" % border)
		return
	# Interior stays the fill colour.
	var interior := image.get_pixel(5, 5)
	if not interior.is_equal_approx(Color(1, 0, 0, 1)):
		_fail("outline must not overwrite interior pixels, got %s" % interior)
		return
	# Far background stays fully transparent.
	if image.get_pixel(0, 0).a > 0.0:
		_fail("outline should not reach distant background pixels")

func _test_crisp_alpha_hardens_fringe() -> void:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.set_pixel(1, 1, Color(0.2, 0.8, 0.3, 0.9)) # above threshold -> opaque
	image.set_pixel(2, 2, Color(0.2, 0.8, 0.3, 0.3)) # below threshold -> cleared
	# outline_width 0 so only the crisp pass runs (crisp is gated on outline today,
	# so enable a 1px outline but assert the alpha snapping it depends on).
	SpriteStylizerScript.stylize(image, {
		"posterize_levels": 0,
		"outline_width": 1,
		"crisp_alpha": true,
		"alpha_threshold": 0.5,
	})
	if image.get_pixel(1, 1).a < 0.999:
		_fail("crisp_alpha should snap above-threshold pixels to opaque")
		return
	# The below-threshold pixel is cleared; it may then be painted as outline (it
	# neighbours the opaque core), so assert it is no longer the original fill.
	var faint := image.get_pixel(2, 2)
	if absf(faint.a - 0.3) < 0.01:
		_fail("crisp_alpha should not leave the original sub-threshold alpha")

func _test_disabled_options_are_a_noop() -> void:
	var image := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	for y in 6:
		for x in 6:
			image.set_pixel(x, y, Color(float(x) / 5.0, 0.4, 0.6, 1.0))
	var before := image.get_data()
	SpriteStylizerScript.stylize(image, {"posterize_levels": 0, "outline_width": 0, "outline_scale": 0.0})
	if image.get_data() != before:
		_fail("stylize with everything disabled should not change the image")
