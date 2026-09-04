class_name PerspectiveMath
extends RefCounted

static func get_homogenous_matrix(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2):
	# p0: Top-Left, p1: Top-Right, p2: Bottom-Right, p3: Bottom-Left
	var dx1: float = p1.x - p2.x
	var dx2: float = p3.x - p2.x
	var dx3: float = p0.x - p1.x + p2.x - p3.x

	var dy1: float = p1.y - p2.y
	var dy2: float = p3.y - p2.y
	var dy3: float = p0.y - p1.y + p2.y - p3.y

	# Affine check (parallelogram)
	if abs(dx3) < 0.0001 and abs(dy3) < 0.0001:
		return Basis(
			Vector3(p1.x - p0.x, p1.y - p0.y, 0.0), # Column 0
			Vector3(p2.x - p1.x, p2.y - p1.y, 0.0), # Column 1
			Vector3(p0.x,        p0.y,        1.0)  # Column 2
		)

	# Projective Homography calculation
	var det: float = (dx1 * dy2) - (dx2 * dy1)
	if abs(det) < 0.00001:
		return Basis() # Degenerate quad fallback

	var g: float = ((dx3 * dy2) - (dx2 * dy3)) / det
	var h: float = ((dx1 * dy3) - (dx3 * dy1)) / det

	var a: float = p1.x - p0.x + (g * p1.x)
	var b: float = p3.x - p0.x + (h * p3.x)
	var c: float = p0.x

	var d: float = p1.y - p0.y + (g * p1.y)
	var e: float = p3.y - p0.y + (h * p3.y)
	var f: float = p0.y

	# Return as a 3x3 Basis (columns X, Y, Z)
	return Basis(
		Vector3(a, d, g), # Column 0
		Vector3(b, e, h), # Column 1
		Vector3(c, f, 1.0) # Column 2
	)

static func calculate_aspect_ratio(
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	p3: Vector2,
	image_aspect: float
) -> float:
	# 1. Convert normalized [0, 1] points into isotropic, center-origin 3D rays
	# We scale X by image_aspect so horizontal and vertical units are physically square
	var m1: Vector3 = Vector3((p0.x - 0.5) * image_aspect, (p0.y - 0.5), 1.0) # Top-Left
	var m2: Vector3 = Vector3((p1.x - 0.5) * image_aspect, (p1.y - 0.5), 1.0) # Top-Right
	var m3: Vector3 = Vector3((p3.x - 0.5) * image_aspect, (p3.y - 0.5), 1.0) # Bottom-Left
	var m4: Vector3 = Vector3((p2.x - 0.5) * image_aspect, (p2.y - 0.5), 1.0) # Bottom-Right

	# 2. Vanishing line intersection cross-products
	var k2_denom: float = (m2.cross(m4)).dot(m3)
	var k3_denom: float = (m3.cross(m4)).dot(m2)

	# Parallel edges (face-on photo with no perspective tilt) -> Fallback to edge average
	if abs(k2_denom) < 0.00001 or abs(k3_denom) < 0.00001:
		return _fallback_aspect_ratio(p0, p1, p2, p3, image_aspect)

	var k2: float = (m1.cross(m4)).dot(m3) / k2_denom
	var k3: float = (m1.cross(m4)).dot(m2) / k3_denom

	# If scalar multipliers are invalid (pins crossed or collinear) -> Fallback
	if abs(k2 - 1.0) < 0.0001 or abs(k3 - 1.0) < 0.0001:
		return _fallback_aspect_ratio(p0, p1, p2, p3, image_aspect)

	# 3. Solve for focal length squared (f^2)
	var v_diff2: Vector2 = Vector2((k2 * m2.x) - m1.x, (k2 * m2.y) - m1.y)
	var v_diff3: Vector2 = Vector2((k3 * m3.x) - m1.x, (k3 * m3.y) - m1.y)

	var f_squared: float = -(v_diff2.x * v_diff3.x + v_diff2.y * v_diff3.y) / ((k2 - 1.0) * (k3 - 1.0))

	# If f^2 is negative or nearly zero, camera tilt is too subtle -> Fallback
	if f_squared <= 0.01:
		return _fallback_aspect_ratio(p0, p1, p2, p3, image_aspect)

	var f: float = sqrt(f_squared)

	# 4. Reconstruct the 3D rays from the camera lens
	var v1_3d: Vector3 = Vector3(m1.x, m1.y, f)
	var v2_3d: Vector3 = Vector3(m2.x, m2.y, f) * k2
	var v3_3d: Vector3 = Vector3(m3.x, m3.y, f) * k3

	# 5. Measure real 3D physical distances
	var physical_width: float = (v2_3d - v1_3d).length()
	var physical_height: float = (v3_3d - v1_3d).length()

	if physical_height <= 0.0001:
		return 1.0

	return physical_width / physical_height


## Fallback for flat, straight-on photos where opposite lines are parallel
static func _fallback_aspect_ratio(
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	p3: Vector2,
	image_aspect: float
) -> float:
	# Convert points to metric coordinates
	var m0: Vector2 = Vector2(p0.x * image_aspect, p0.y)
	var m1: Vector2 = Vector2(p1.x * image_aspect, p1.y)
	var m2: Vector2 = Vector2(p2.x * image_aspect, p2.y)
	var m3: Vector2 = Vector2(p3.x * image_aspect, p3.y)

	var w1: float = m0.distance_to(m1) # Top edge
	var w2: float = m3.distance_to(m2) # Bottom edge
	var h1: float = m0.distance_to(m3) # Left edge
	var h2: float = m1.distance_to(m2) # Right edge

	var avg_w: float = (w1 + w2) * 0.5
	var avg_h: float = (h1 + h2) * 0.5

	if avg_h <= 0.0001:
		return 1.0

	return avg_w / avg_h
