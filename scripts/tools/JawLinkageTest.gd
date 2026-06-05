extends Node

# Unit test for HeadProfile.jaw_landmarks (Phase 7 anatomical jaw linkage core).
# Pure math, no FishRig build - verifies the landmark kinematics the carve and the
# mouth meshes will both consume.

const HeadProfile := preload("res://scripts/creature/HeadProfile.gd")

func _ready() -> void:
	var bite := -0.05

	# 1. Neutral defaults (gape 0, no protrusion, ratio 1): both jaw tips meet at the
	#    snout front on the bite line, the hinge sits where asked.
	var neutral := {"mouth_center_y": bite}
	var lm0 := HeadProfile.jaw_landmarks(neutral, 0.0)
	assert(lm0["gape_angle"] == 0.0)
	assert(_approx(lm0["hinge"], Vector2(0.0, bite)))
	assert(_approx(lm0["upper_tip"], Vector2(HeadProfile.JAW_SNOUT_FRONT_X, bite)))
	assert(_approx(lm0["lower_tip"], Vector2(HeadProfile.JAW_SNOUT_FRONT_X, bite)))

	# 2. Opening the mouth swings the lower jaw DOWN monotonically while the upper tip
	#    (no protrusion) stays on the bite line.
	var prev_y: float = lm0["lower_tip"].y
	for i in range(1, 6):
		var g := float(i) / 5.0
		var lm := HeadProfile.jaw_landmarks(neutral, g)
		assert(lm["lower_tip"].y < prev_y - 1e-6)   # drops further each step
		assert(absf(lm["upper_tip"].y - bite) < 1e-6) # upper jaw fixed without protrusion
		assert(lm["gape_angle"] > 0.0)
		prev_y = lm["lower_tip"].y

	# 3. Protrusion coupling: zero at closed, full jaw_protrusion at full gape, nonlinear
	#    (lags early). With protrusion on, opening throws the premaxilla FORWARD (-x).
	assert(HeadProfile.jaw_protrusion_coupling(0.0) == 0.0)
	assert(absf(HeadProfile.jaw_protrusion_coupling(1.0) - 1.0) < 1e-6)
	assert(HeadProfile.jaw_protrusion_coupling(0.5) < 0.5) # late throw (g*g)
	var protr := {"mouth_center_y": bite, "jaw_protrusion": 0.2}
	var pc := HeadProfile.jaw_landmarks(protr, 0.0)
	var po := HeadProfile.jaw_landmarks(protr, 1.0)
	assert(absf(pc["upper_tip"].x - HeadProfile.JAW_SNOUT_FRONT_X) < 1e-6) # closed = rest
	assert(po["upper_tip"].x < pc["upper_tip"].x - 0.19)                   # ~full 0.2 forward
	assert(po["upper_tip"].y < pc["upper_tip"].y)                          # and slightly down

	# 4. lower_upper_ratio sets the rest overbite/underbite at the front of the mouth.
	var under := HeadProfile.jaw_landmarks({"mouth_center_y": bite, "lower_upper_ratio": 1.4}, 0.0)
	assert(under["lower_tip"].x < under["upper_tip"].x - 1e-6) # lower juts past upper
	var over := HeadProfile.jaw_landmarks({"mouth_center_y": bite, "lower_upper_ratio": 0.6}, 0.0)
	assert(over["lower_tip"].x > over["upper_tip"].x + 1e-6)   # upper overhangs lower

	# 5. Hinge position = jaw length: a hinge set further back gives a longer lever, so at
	#    the same gape the lower-jaw tip drops further (bigger arc).
	var fwd_hinge := HeadProfile.jaw_landmarks({"mouth_center_y": bite, "jaw_hinge_x": -0.2}, 1.0)
	var back_hinge := HeadProfile.jaw_landmarks({"mouth_center_y": bite, "jaw_hinge_x": 0.2}, 1.0)
	assert(back_hinge["lower_tip"].y < fwd_hinge["lower_tip"].y - 0.01)

	print("JAW_LINKAGE_TEST_OK")
	get_tree().quit(0)

func _approx(a: Vector2, b: Vector2, eps: float = 1e-5) -> bool:
	return a.distance_to(b) < eps
