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

# How far past the snout window the vertical shift blends back into the head body.
const JAW_BLEND_SPAN := 0.18

# Vertical shift applied so the whole snout translates with the jaw (the mouth's
# offset from its no-jaw baseline). The snout (u < snout_base) moves as a RIGID block
# by `shift` - it does not curve - then ramps smoothly to 0 over JAW_BLEND_SPAN so it
# rejoins the head body without a step.
static func snout_y_shift(shift: float, u: float, snout_base: float = SNOUT_BLEND_HALF) -> float:
	if shift == 0.0:
		return 0.0
	if u <= snout_base:
		return shift
	if u >= snout_base + JAW_BLEND_SPAN:
		return 0.0
	var t := (u - snout_base) / JAW_BLEND_SPAN
	return shift * (1.0 - smoothstep(0.0, 1.0, t))
