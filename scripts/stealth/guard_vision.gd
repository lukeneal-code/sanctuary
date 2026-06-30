class_name GuardVision
extends RefCounted
## Pure geometric vision predicate for the stealth guard. No physics, no Node, so
## the cone maths is unit-testable headless. The line-of-sight raycast (does a
## wall block the view?) lives on guard.gd and is exercised by the smoke test.


## True when `target` is within a cone of half-angle fov_deg/2 around `forward`,
## measured from `eye_pos`, and no further than `sight_range`. `forward` need not
## be normalized. A target at the eye, a zero forward, or beyond range -> false.
static func in_view_cone(
	eye_pos: Vector3, forward: Vector3, fov_deg: float, sight_range: float, target: Vector3
) -> bool:
	var to_target: Vector3 = target - eye_pos
	var dist: float = to_target.length()
	if dist == 0.0 or dist > sight_range:
		return false
	if forward.length() == 0.0:
		return false
	return forward.angle_to(to_target) <= deg_to_rad(fov_deg) * 0.5
