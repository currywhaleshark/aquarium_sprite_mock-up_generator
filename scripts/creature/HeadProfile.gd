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

# Only the front half of the head (u < SNOUT_BLEND_HALF, where u = base_x + 0.5,
# 0 = snout tip .. 1 = neck) participates in the snout stretch.
const SNOUT_BLEND_HALF := 0.5

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

# Forward: how far a front-half vertex is pulled toward the snout tip.
static func snout_forward_x_shift(snout_length: float, u: float) -> float:
	var stretch_t := 1.0 - (u / SNOUT_BLEND_HALF)
	return snout_length * stretch_t * stretch_t

# Inverse of snout_forward_x_shift: given a stretched local x (< 0), recover the
# base-sphere x it originated from. Returns x unchanged when there is no snout.
static func snout_base_x(snout_length: float, x: float) -> float:
	if snout_length <= 0.001 or x >= 0.0:
		return x
	var disc := 1.0 - 16.0 * snout_length * x
	if disc < 0.0:
		return x
	return (1.0 - sqrt(disc)) / (8.0 * snout_length)

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
