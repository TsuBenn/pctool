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

@export var fitting_mode: FittingMode = FittingMode.FILL:
	set(new):
		if new == FittingMode.DISTORT:
			Global.notice("Feature Not Implemented", "Image Distortions has not been implemented")
			new = fitting_mode
		fitting_mode = new
		emit_changed()

@export var scale: float = 1:
	set(new):
		scale = new
		emit_changed()

@export var offset: Vector2 = Vector2.ZERO:
	set(new):
		offset = new.clamp(Vector2(-1,-1), Vector2(1,1))
		emit_changed()

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


func get_image_rect_mm(index: int) -> Rect2:
	if asset == null:
		return Rect2(Vector2.ZERO, size_mm)

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
