class_name PhotoItemData
extends Resource

# DATA
@export var asset: AssetData:
	set(new):
		if asset and asset.changed.is_connected(emit_changed):
			asset.changed.disconnect(emit_changed)
		asset = new
		asset.changed.connect(emit_changed)
		emit_changed()

enum Rotation {
	ROTATE_0,
	ROTATE_90,
	ROTATE_180,
	ROTATE_270,
}

class Framing extends Resource:
	var scale: float = 1
	var offset: Vector2 = Vector2.ZERO

	var top_left_corner: Vector2 = Vector2.ZERO
	var top_right_corner: Vector2 = Vector2.ZERO
	var bottom_left_corner: Vector2 = Vector2.ZERO
	var bottom_right_corner: Vector2 = Vector2.ZERO

	var fitting_mode: FittingMode = FittingMode.FILL

# TRANSFORMS
@export var size_mm: Vector2 = Vector2(30.0, 40.0):
	set(new):
		size_mm = new
		emit_changed()

# @export var rotation: Rotation = Rotation.ROTATE_0:
# 	set(new):
# 		rotation = new
# 		emit_changed()

# @export var flipped_h: bool = false:
# 	set(new):
# 		flipped_h = new
# 		emit_changed()

# @export var flipped_v: bool = false:
# 	set(new):
# 		flipped_v = new
# 		emit_changed()

@export var isolate_row: bool = false:
	set(new):
		isolate_row = new
		emit_changed()

@export var isolate_page: bool = false:
	set(new):
		isolate_page = new
		emit_changed()

enum FittingMode { FILL, FIT, STRETCH, DISTORT }

enum FilterMode { NEAREST, BILINEAR, CUBIC, TRILINEAR, LANCZOS }

# IMAGE
@export var quantity: int = 1:
	set(new):
		quantity = max(new,1)
		emit_changed()

@export var filter_mode: FilterMode = FilterMode.LANCZOS:
	set(new):
		filter_mode = new
		emit_changed()

# FRAMINGS INCLUDES SCALE, OFFSETS AND FITTING MODE AS DICTS
# {
#     scale: float, <- in percentage
#     offset: Vector2, <- in percentage
#     fitting_mode: FittingMode,
# }
var framings: Dictionary[int, Framing] = {}

# EFFECTS
@export var border_enabled: bool = true:
	set(new):
		border_enabled = new
		emit_changed()

@export var border_width: float = 0.2:
	set(new):
		border_width = new
		emit_changed()

@export var border_color: Color = Color.BLACK:
	set(new):
		border_color = new
		emit_changed()

func apply_framing_to_all(base_index: int):
	for f in framings.keys():
		if f == base_index:
			continue
		framings[f] = framings[base_index].duplicate()
	emit_changed()

func set_framing(index: int, new_scale: float, new_offset: Vector2, new_fitting_mode: FittingMode):
	var new_framing = Framing.new()
	new_framing.scale = max(new_scale,1)
	new_framing.offset = new_offset.clamp(Vector2(-1,-1), Vector2( 1, 1))
	new_framing.fitting_mode = new_fitting_mode
	framings[index] = new_framing
	emit_changed()

func set_framing_scale(index: int, new: float, ratio: bool = false):
	var f = get_framing(index)
	var old_scale = f.scale
	set_framing(index, new, f.offset, f.fitting_mode)
	if ratio:
		var new_rect = get_image_rect_mm(index)
		var max_offset = (new_rect.size - size_mm)
		var offset_aspect_x = (new_rect.size.x - size_mm.x/(old_scale/new))/max_offset.x if max_offset.x > 0 else 0
		var offset_aspect_y = (new_rect.size.y - size_mm.y/(old_scale/new))/max_offset.y if max_offset.y > 0 else 0
		set_framing_offset(index, f.offset * Vector2(offset_aspect_x,offset_aspect_y))

func set_framing_offset(index: int, new: Vector2):
	var f = get_framing(index)
	var image_rect = get_image_rect_mm(index)

	var zero_x = image_rect.size.x - size_mm.x == 0
	var zero_y = image_rect.size.y - size_mm.y == 0

	set_framing(index, f.scale, Vector2(0.0 if zero_x else new.x, 0.0 if zero_y else new.y), f.fitting_mode)

func set_framing_offset_x(index: int, new: float):
	var f = get_framing(index)
	set_framing_offset(index, Vector2(new, f.offset.y))

func set_framing_offset_y(index: int, new: float):
	var f = get_framing(index)
	set_framing_offset(index, Vector2(f.offset.x, new))

func set_framing_fitting_mode(index: int, new: int):
	var f = get_framing(index)
	set_framing(index, f.scale, f.offset, new as FittingMode)

func get_framing(index: int) -> Framing:
	if framings.has(index):
		return framings[index]
	return Framing.new()

func get_distort_matrix(index: int):
	var framing: Framing = get_framing(index)

	var p0: Vector2 = framing.top_left_corner
	var p1: Vector2 = framing.top_right_corner
	var p2: Vector2 = framing.bottom_right_corner
	var p3: Vector2 = framing.bottom_left_corner

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
func get_image_rect_mm(index: int) -> Rect2:
	if asset == null:
		return Rect2(Vector2.ZERO, size_mm)

	var framing = get_framing(index)

	var scale = framing.scale
	var offset = framing.offset
	var fitting_mode = framing.fitting_mode

	# 1. Fetch aspect ratio safely (e.g. from preview texture or cached dimensions)
	var preview_tex = asset.get_preview_texture(index)
	if preview_tex == null:
		return Rect2(Vector2.ZERO, size_mm)

	var tex_size: Vector2 = preview_tex.get_size()
	var image_aspect: float = tex_size.aspect()

	var h: float = 0
	var w: float = 0
	var x: float = 0
	var y: float = 0

	match fitting_mode:
		FittingMode.FIT:
			if size_mm.aspect() > image_aspect:
				h = size_mm.y
				w = size_mm.y * image_aspect
				x = (size_mm.x - w) * (0.5 + 0.5*offset.x)
			else:
				w = size_mm.x
				h = size_mm.x / image_aspect
				y = (size_mm.y - h) * (0.5 - 0.5*offset.y)
		FittingMode.FILL:
			if size_mm.aspect() > image_aspect:
				w = size_mm.x * scale
				h = size_mm.x * scale / image_aspect
			else:
				h = size_mm.y * scale
				w = size_mm.y * image_aspect * scale
			y = (size_mm.y - h) * (1 - offset.y) * 0.5
			x = (size_mm.x - w) * (1 + offset.x) * 0.5
		FittingMode.STRETCH, FittingMode.DISTORT:
			w = size_mm.x
			h = size_mm.y

	return Rect2(x, y, w, h)
