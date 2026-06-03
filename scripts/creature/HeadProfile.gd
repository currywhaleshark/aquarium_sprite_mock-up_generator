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
