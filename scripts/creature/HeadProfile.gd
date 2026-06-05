extends RefCounted

# Shared head-silhouette math.
#
# The head shape is realised in two different parametrisations that must stay in
# lock-step or the body shell stops fitting the head:
#   * PrimitiveFactory.deformed_head_mesh - FORWARD vertex displacement of a unit
#     sphere (iterates phi/theta, produces deformed x/y/z).
#   * FishRig._get_head_contour_radius - INVERSE radius-at-x sampler (given a world
#     x along the head, returns the silhouette radius so the shell tube can hug it).
#
# Phase 0 of the head-sculpt rework centralises every shape constant and per-feature
# formula here so the forward and inverse paths read the same numbers. Behaviour is
# intentionally unchanged from the previous inline implementations; later phases
# replace these discrete-shape branches with continuous controls in one place.

# Only the front of the head (u < snout_base, where u = base_x + 0.5, 0 = snout
# tip .. 1 = neck) participates in the snout stretch. SNOUT_BLEND_HALF is the
# legacy/default window (whole front half) that reproduces the pre-Phase-1 shape.
const SNOUT_BLEND_HALF := 0.5

# Continuous snout sculpt controls (Phase 1). Defaults are NEUTRAL: with these the
# head is identical to the legacy snout_length-only behaviour.
#   snout_base      width of the stretch window (smaller = a thin tube protruding
#                   from an otherwise normal head; larger = the whole front elongates)
#   snout_thickness girth at the snout tip as a fraction of the undeformed radius
#   snout_taper     how sharply the girth narrows toward the tip (0 = even, 1 = pointed)
const SNOUT_SCULPT_DEFAULTS := {
	"snout_base": 0.5,
	"snout_thickness": 1.0,
	"snout_taper": 0.0,
}

const HUMP_BASE_HEIGHT := 0.16
const HUMP_SLOPE_GAIN := 0.15
const STEEP_FOREHEAD_SCALE := 0.72
const STEEP_FOREHEAD_X_SHIFT := 0.35

# Flattening is applied differently in the two paths today: the mesh squashes only
# the lower hemisphere, the contour squashes the silhouette radius. Kept as two
# named constants so the discrepancy is explicit; Phase 2 reconciles them.
const FLATTEN_MESH_FACTOR := 0.65
const FLATTEN_CONTOUR_FACTOR := 0.825

const CEPHALOFOIL_Z_GAIN := 2.2
const CEPHALOFOIL_Y_SCALE := 0.42
const CEPHALOFOIL_SWEEP := 0.18

# Forward: how far a vertex inside the snout window is pulled toward the tip.
static func snout_forward_x_shift(snout_length: float, u: float, snout_base: float = SNOUT_BLEND_HALF) -> float:
	if snout_length <= 0.0 or u >= snout_base:
		return 0.0
	var stretch_t := 1.0 - (u / snout_base)
	return snout_length * stretch_t * stretch_t

# Inverse of snout_forward_x_shift: given a stretched local x, recover the
# base-sphere x it originated from. Returns x unchanged outside the snout window.
# Derivation: x_world = x_base - L*((a - 0.5 - x_base)/a)^2 with a = snout_base,
# L = snout_length. Substituting s = a - 0.5 - x_base gives the quadratic
# (L/a^2)s^2 + s + (x_world - a + 0.5) = 0; take the non-negative root for s.
static func snout_base_x(snout_length: float, x: float, snout_base: float = SNOUT_BLEND_HALF) -> float:
	if snout_length <= 0.001 or x >= snout_base - 0.5:
		return x
	var a := snout_base
	var coeff := snout_length / (a * a)
	var disc := 1.0 - 4.0 * coeff * (x - a + 0.5)
	if disc < 0.0:
		return x
	var s := (-1.0 + sqrt(disc)) / (2.0 * coeff)
	return a - 0.5 - s

# Radial (girth) multiplier applied to the y/z radius inside the snout window.
# Returns 1.0 (neutral) outside the window or with default thickness/taper.
static func snout_radial_scale(snout_length: float, u: float, snout_base: float, thickness: float, taper: float) -> float:
	if snout_length <= 0.0 or u >= snout_base:
		return 1.0
	var w := 1.0 - (u / snout_base) # 1 at the tip, 0 at the window base
	var shaped := pow(w, lerpf(1.0, 3.0, clampf(taper, 0.0, 1.0)))
	return lerpf(1.0, thickness, shaped)

# Multiplier applied to the y/z radius in the front half to sharpen the snout.
static func taper_factor(shape: String, u: float) -> float:
	if shape == "pointed" or shape == "tapered":
		return lerpf(0.12, 1.0, u / SNOUT_BLEND_HALF)
	if shape == "blunt":
		return lerpf(0.68, 1.0, pow(u / SNOUT_BLEND_HALF, 0.4))
	return 1.0

# Height of the nuchal/forehead mass for the given forehead slope.
static func hump_height(forehead_slope: float) -> float:
	return HUMP_BASE_HEIGHT + forehead_slope * HUMP_SLOPE_GAIN

# Vertical arc (local units) of the snout tip at |snout_curve| = 1.
const SNOUT_CURVE_SCALE := 0.4

# Vertical deformation of the snout. Two stacked effects, both pinned to 0 at the
# snout base (u = snout_base) so the head body never moves:
#   * jaw shear (`shift`): a LINEAR ramp - the tip follows the mouth, straight edges,
#     so a symmetric snout (◁) shears into a flat-top / flat-bottom right triangle.
#   * curve (`curve`, -1..1): a QUADRATIC arc that bends the snout up (+) or down (-)
#     with the bend concentrated toward the tip; magnitude sets how much it curls.
static func snout_y_shift(shift: float, u: float, snout_base: float = SNOUT_BLEND_HALF, curve: float = 0.0) -> float:
	if u >= snout_base:
		return 0.0
	var t := 1.0 - u / snout_base # 1 at the tip, 0 at the snout base
	return shift * t + curve * SNOUT_CURVE_SCALE * t * t

# Continuous dorsal/ventral head profile (Phase 2). Each is a smooth bell along the
# head centered at `peak` (0 = snout, 1 = nape) that raises (+) or lowers (-) the top
# or bottom silhouette, weighted by the cross-section girth so it fades at the poles.
# Replaces the freedom the discrete hump/steep_forehead/flattened shapes used to bake
# in: + dorsal = nuchal hump (Napoleon wrasse), - dorsal = flat/concave top (arowana),
# - ventral = flat belly/throat. Defaults are 0 (neutral, no change).
const PROFILE_GAIN := 0.5
const PROFILE_SPAN := 0.5

static func _profile_long_weight(u: float, peak: float) -> float:
	var d := (u - peak) / PROFILE_SPAN
	return clampf(1.0 - d * d, 0.0, 1.0)

# Added to a top vertex's y (y > 0).
static func dorsal_offset(u: float, sin_phi: float, curve: float, peak: float) -> float:
	if curve == 0.0:
		return 0.0
	return curve * PROFILE_GAIN * sin_phi * _profile_long_weight(u, peak)

# Downward magnitude for a bottom vertex (y < 0); the caller adds it to y (push down)
# for positive curve and pulls the belly in (flatter) for negative curve.
static func ventral_offset(u: float, sin_phi: float, curve: float, peak: float) -> float:
	if curve == 0.0:
		return 0.0
	return curve * PROFILE_GAIN * sin_phi * _profile_long_weight(u, peak)

# Localized crown/forehead bump (Phase 3). Unlike the dorsal profile, which only
# raises the top silhouette and fades to nothing at the narrowing snout, this is a
# rounded dome on the upper surface centered at head-local x = `pos`. The caller
# raises y by height * falloff and pushes x by -forward * height * falloff, so a
# forward lean makes the bump JUT OUT in front (Napoleon-wrasse-style overhang)
# rather than only bulging upward.
#
# The dome has a DEFINED edge at |x - pos| = width (it reads as a distinct mass, not
# a soft gaussian blend). `round` shapes that edge: 0 = soft shoulder that eases into
# the head, 1 = a steep, bulbous dome that pops out. Returns the weight (0 off it).
static func head_bump_falloff(x: float, theta: float, pos: float, width: float, round_amount: float = 0.6) -> float:
	var w_top := sin(theta) # 1 at the top, 0 at the sides, <0 underneath
	if w_top <= 0.0:
		return 0.0
	var d := (x - pos) / maxf(width, 0.001)
	var cap := maxf(1.0 - d * d, 0.0)
	# Lower exponent -> rounder top, steeper (more distinct) shoulder.
	var p := lerpf(2.0, 0.5, clampf(round_amount, 0.0, 1.0))
	return pow(cap, p) * w_top

# ---- Phase 7: anatomical jaw linkage --------------------------------------
# A simplified planar abstraction of the teleost feeding mechanism, expressed in
# head-LOCAL units (head radius 0.5; x = -0.5 snout tip .. +0.5 neck, y up, on the
# midline z = 0 plane). Real teleosts open the mouth by rotating the lower jaw about
# the quadrate-articular joint while a coupled four-bar linkage throws the premaxilla
# (upper jaw) forward; here we collapse that to three landmarks driven by one gape
# input so the head's upper-jaw carve and the lip/lower-jaw/cheek meshes all read the
# SAME geometry (the Phase 0 forward/inverse-sync discipline, now for the jaw).
#
#   jaw_hinge_x        quadrate-articular joint x. +back = longer jaw lever -> the
#                      lower jaw tip sweeps a bigger arc (long-jaw predator); forward
#                      = short crushing jaw.
#   jaw_hinge_y        joint height relative to the bite line.
#   jaw_protrusion     max premaxilla forward (-x) slide at full gape (0 = legacy: the
#                      upper jaw stays fixed). Coupled to gape, so the mouth becomes a
#                      forward tube as it opens.
#   lower_upper_ratio  lower:upper jaw length. 1 = terminal (equal), >1 = lower juts
#                      (superior/underbite), <1 = upper overhangs (inferior/overbite).
const JAW_DEFAULTS := {
	"jaw_hinge_x": 0.0,
	"jaw_hinge_y": 0.0,
	"jaw_protrusion": 0.0,
	"lower_upper_ratio": 1.0,
}

# Max lower-jaw depression the gape input (0..1) maps to. Single source of truth for the
# carve, lower jaw, lower lip and cheeks (FishRig reads it via jaw_landmarks).
const JAW_MAX_GAPE_DEG := 75.0

# Snout-front x the jaws reach to at rest (the bite region of the undeformed sphere).
const JAW_SNOUT_FRONT_X := -0.5

# Nonlinear gape -> protrusion coupling: the premaxilla barely moves at small gape
# then is thrown forward late in the opening, mimicking the four-bar linkage's output.
static func jaw_protrusion_coupling(gape: float) -> float:
	var g := clampf(gape, 0.0, 1.0)
	return g * g

# Returns the jaw landmarks for the given sculpt params at gape (0 closed .. 1 agape):
#   hinge       Vector2 quadrate-articular pivot
#   upper_tip   Vector2 premaxilla tip (protruded when opening)
#   lower_tip   Vector2 dentary/chin tip (swung down about the hinge)
#   gape_angle  float    lower-jaw depression (radians)
#   bite_line_y float    closed-mouth occlusal line
static func jaw_landmarks(p: Dictionary, gape: float) -> Dictionary:
	var g := clampf(gape, 0.0, 1.0)
	var bite_y := float(p.get("mouth_center_y", 0.0))
	var hinge_x := float(p.get("jaw_hinge_x", JAW_DEFAULTS["jaw_hinge_x"]))
	var hinge_y := bite_y + float(p.get("jaw_hinge_y", JAW_DEFAULTS["jaw_hinge_y"]))
	var ratio := maxf(float(p.get("lower_upper_ratio", JAW_DEFAULTS["lower_upper_ratio"])), 0.05)
	var protr := float(p.get("jaw_protrusion", JAW_DEFAULTS["jaw_protrusion"]))

	# Lever length from the hinge forward to the snout-front bite region.
	var upper_len := hinge_x - JAW_SNOUT_FRONT_X
	var lower_len := upper_len * ratio

	# Upper jaw (premaxilla): rest tip at the snout front, then thrown forward + slightly
	# down as the mouth opens.
	var protr_amt := protr * jaw_protrusion_coupling(g)
	var upper_tip := Vector2(hinge_x - upper_len - protr_amt, bite_y - protr_amt * 0.35)

	# Lower jaw: rest tip rotated down about the hinge; it then rides the premaxilla
	# forward a touch so the two jaw tips stay together at the front of the mouth.
	var gape_angle := deg_to_rad(JAW_MAX_GAPE_DEG) * g
	var rest_lower := Vector2(hinge_x - lower_len, bite_y)
	var lower_tip := _rotate_about(rest_lower, Vector2(hinge_x, hinge_y), gape_angle)
	lower_tip.x -= protr_amt

	return {
		"hinge": Vector2(hinge_x, hinge_y),
		"upper_tip": upper_tip,
		"lower_tip": lower_tip,
		"gape_angle": gape_angle,
		"bite_line_y": bite_y,
	}

static func _rotate_about(pt: Vector2, pivot: Vector2, ang: float) -> Vector2:
	var d := pt - pivot
	return pivot + Vector2(d.x * cos(ang) - d.y * sin(ang), d.x * sin(ang) + d.y * cos(ang))
