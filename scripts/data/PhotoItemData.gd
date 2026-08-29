class_name PhotoItemData
extends Resource

# DATA
@export var asset: AssetData

enum Rotation {
	ROTATE_0,
	ROTATE_90,
	ROTATE_180,
	ROTATE_270,
}

# TRANSFORMS
@export var size_mm: Vector2 = Vector2(30.0, 40.0):
	set(new):
		size_mm = new
		emit_changed()

@export var rotation: Rotation = Rotation.ROTATE_0:
	set(new):
		rotation = new
		emit_changed()

@export var flipped_h: bool = false:
	set(new):
		flipped_h = new
		emit_changed()

@export var flipped_v: bool = false:
	set(new):
		flipped_v = new
		emit_changed()

enum FittingMode { FILL, FIT, STRETCH, DISTORT }

enum FilterMode { NEAREST, BILINEAR, CUBIC, TRILINEAR, LANCZOS }

# IMAGE
@export var quantity: int = 1:
	set(new):
		quantity = new
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
@export var framings: Dictionary = {}

# EFFECTS
@export var border_enabled: bool = false:
	set(new):
		border_enabled = new
		emit_changed()

@export var border_width: float = 0.4:
	set(new):
		border_width = new
		emit_changed()

@export var border_color: Color = Color.BLACK:
	set(new):
		border_color = new
		emit_changed()

func set_framing(index: int, new_scale: float, new_offset: Vector2, new_fitting_mode: FittingMode):
	framings[index] = {
		"scale": new_scale,
		"offset": new_offset.clamp(Vector2(-1,-1), Vector2( 1, 1)),
		"fitting_mode": new_fitting_mode,
	}
	emit_changed()

func get_framing(index: int) -> Dictionary:
	return framings.get(index, {
		"scale": 1.0,
		"offset": Vector2.ZERO,
		"fitting_mode": FittingMode.FILL,
	})

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

	if rotation == Rotation.ROTATE_90 or rotation == Rotation.ROTATE_270:
		image_aspect = 1 / image_aspect

	match fitting_mode:
		FittingMode.FIT:
			if size_mm.aspect() > image_aspect:
				h = size_mm.y
				w = size_mm.y * image_aspect
				x = (size_mm.x - w) * 0.5
			else:
				w = size_mm.x
				h = size_mm.x / image_aspect
				y = (size_mm.y - h) * 0.5
		FittingMode.FILL:
			if size_mm.aspect() > image_aspect:
				w = size_mm.x * scale
				h = size_mm.x * scale / image_aspect
			else:
				h = size_mm.y * scale
				w = size_mm.y * image_aspect * scale
			y = (size_mm.y - h) * (1 - offset.y) * 0.5
			x = (size_mm.x - w) * (1 + offset.x) * 0.5
		FittingMode.STRETCH:
			w = size_mm.x
			h = size_mm.y
		FittingMode.DISTORT:
			pass

	return Rect2(x, y, w, h)
