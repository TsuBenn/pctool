class_name PhotoItemData
extends Resource

# DATA
var _document_data: DocumentData # Used for tracking Undo Redo in the appropriate _document_data

var _commit : bool = true

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

	var top_left_corner: Vector2 = Vector2(0,0)
	var top_right_corner: Vector2 = Vector2(1,0)
	var bottom_left_corner: Vector2 = Vector2(0,1)
	var bottom_right_corner: Vector2 = Vector2(1,1)

	var fitting_mode: FittingMode = FittingMode.FILL

# TRANSFORMS
@export var size_mm: Vector2 = Vector2(30.0, 40.0):
	set(new):
		if size_mm_last_changed == Vector2.INF:
			size_mm_last_changed = size_mm
		size_mm = new
		emit_changed()

var size_mm_last_changed: Vector2 = Vector2.INF

func commit_size():
	if _commit and _document_data:
		var old: Vector2 = size_mm_last_changed
		var new: Vector2 = size_mm
		size_mm_last_changed = Vector2.INF
		# print(old)
		Global.undo_redo[_document_data].create_action("Changed Photo Item's Size [%s]" % new)
		Global.undo_redo[_document_data].add_do_method(
			func():
				_commit = false
				size_mm = new
				_commit = true
		)
		Global.undo_redo[_document_data].add_undo_method(
			func():
				_commit = false
				size_mm = old
				_commit = true
		)
		Global.undo_redo[_document_data].commit_action(false)

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
		if _commit and _document_data:
			var old: bool = isolate_row
			var old_page: bool = isolate_page
			Global.undo_redo[_document_data].create_action("%s Photo Item's Row Isolation" % "Enabled" if new else "Disabled")
			Global.undo_redo[_document_data].add_do_method(
				func():
					_commit = false
					isolate_row = new
					if new:
						isolate_page = false
					_commit = true
			)
			Global.undo_redo[_document_data].add_undo_method(
				func():
					_commit = false
					isolate_row = old
					isolate_page = old_page
					_commit = true
			)
			Global.undo_redo[_document_data].commit_action(false)

		isolate_row = new
		if new:
			_commit = false
			isolate_page = false
			_commit = true

		emit_changed()

@export var isolate_page: bool = false:
	set(new):
		if _commit and _document_data:
			var old_row: bool = isolate_row
			var old: bool = isolate_page
			Global.undo_redo[_document_data].create_action("%s Photo Item's Page Isolation" % "Enabled" if new else "Disabled")
			Global.undo_redo[_document_data].add_do_method(
				func():
					_commit = false
					isolate_page = new
					if new:
						isolate_row = false
					_commit = true
			)
			Global.undo_redo[_document_data].add_undo_method(
				func():
					_commit = false
					isolate_row = old_row
					isolate_page = old
					_commit = true
			)
			Global.undo_redo[_document_data].commit_action(false)

		isolate_page = new
		if new:
			_commit = false
			isolate_row = false
			_commit = true

		emit_changed()

enum FittingMode { FILL, FIT, STRETCH, DISTORT }

# IMAGE
@export var quantity: int = 1:
	set(new):
		if _commit and _document_data:
			var old: int = quantity
			Global.undo_redo[_document_data].create_action("Changed Photo Item's Quantity [%d]" % new)
			Global.undo_redo[_document_data].add_do_method(
				func():
					_commit = false
					quantity = max(new,1)
					_commit = true
			)
			Global.undo_redo[_document_data].add_undo_method(
				func():
					_commit = false
					quantity = old
					_commit = true
			)
			Global.undo_redo[_document_data].commit_action(false)

		quantity = max(new,1)
		emit_changed()

# FRAMINGS INCLUDES SCALE, OFFSETS AND FITTING MODE AS DICTS
# {
#     scale: float, <- in percentage
#     offset: Vector2, <- in percentage
#     fitting_mode: FittingMode,
# }
var framings: Dictionary[int, Framing] = {}
var framings_last_changed: Dictionary[int, Framing] = {}

func commit_framings():
	if framings_last_changed.is_empty():
		return

	var new: Dictionary = framings.duplicate()
	var old: Dictionary = framings_last_changed.duplicate()

	framings_last_changed = {}

	Global.undo_redo[_document_data].create_action("Changed Photo Item's Framings")
	Global.undo_redo[_document_data].add_do_method(
		func():
			_commit = false
			framings = new
			emit_changed()
			_commit = true
	)
	Global.undo_redo[_document_data].add_undo_method(
		func():
			_commit = false
			framings = old
			emit_changed()
			_commit = true
	)
	Global.undo_redo[_document_data].commit_action(false)

# EFFECTS
@export var border_enabled: bool = true:
	set(new):
		if _commit and _document_data:
			var old: bool = border_enabled
			Global.undo_redo[_document_data].create_action("%s Photo Item's Border" % "Enabled" if new else "Disabled")
			Global.undo_redo[_document_data].add_do_method(
				func():
					_commit = false
					border_enabled = new
					_commit = true
			)
			Global.undo_redo[_document_data].add_undo_method(
				func():
					_commit = false
					border_enabled = old
					_commit = true
			)
			Global.undo_redo[_document_data].commit_action(false)

		border_enabled = new
		emit_changed()


@export var border_width_last_changed: float = -1;

@export var border_width: float = 0.2:
	set(new):
		if border_width_last_changed == -1:
			border_width_last_changed = border_width
		border_width = max(0.1,new)
		emit_changed()

func commit_border_width():
	if border_width_last_changed == -1:
		return

	var old: float = border_width_last_changed
	var new: float = border_width
	border_width_last_changed = -1
	Global.undo_redo[_document_data].create_action("Changed Photo Item's Border Width [%.2f]" % new)
	Global.undo_redo[_document_data].add_do_method(
		func():
			_commit = false
			border_width = new
			_commit = true
	)
	Global.undo_redo[_document_data].add_undo_method(
		func():
			_commit = false
			border_width = old
			_commit = true
	)
	Global.undo_redo[_document_data].commit_action(false)

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

func set_framing(index: int, new_scale: float, new_offset: Vector2, new_fitting_mode: FittingMode, top_left: Vector2, top_right: Vector2, bottom_right: Vector2, bottom_left: Vector2):
	if framings_last_changed.is_empty():
		framings_last_changed = framings.duplicate()
	var new_framing = Framing.new()
	new_framing.scale = max(new_scale,1)
	new_framing.offset = new_offset.clamp(Vector2(-1,-1), Vector2( 1, 1))
	new_framing.fitting_mode = new_fitting_mode
	new_framing.top_left_corner = top_left.clamp(Vector2(0,0),Vector2(1,1))
	new_framing.top_right_corner = top_right.clamp(Vector2(new_framing.top_left_corner.x, 0), Vector2(1, new_framing.bottom_right_corner.y))
	new_framing.bottom_right_corner = bottom_right.clamp(Vector2(new_framing.bottom_left_corner.x, new_framing.top_right_corner.y), Vector2(1, 1))
	new_framing.bottom_left_corner = bottom_left.clamp(Vector2(0, new_framing.top_left_corner.y), Vector2(1, 1))
	framings[index] = new_framing
	emit_changed()

func set_framing_scale(index: int, new: float, ratio: bool = false):
	var f = get_framing(index)
	var old_scale = f.scale
	set_framing(index, new, f.offset, f.fitting_mode, f.top_left_corner, f.top_right_corner, f.bottom_right_corner, f.bottom_left_corner)
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

	set_framing(index, f.scale, Vector2(0.0 if zero_x else new.x, 0.0 if zero_y else new.y), f.fitting_mode, f.top_left_corner, f.top_right_corner, f.bottom_right_corner, f.bottom_left_corner)

func set_framing_offset_x(index: int, new: float):
	var f = get_framing(index)
	set_framing_offset(index, Vector2(new, f.offset.y))

func set_framing_offset_y(index: int, new: float):
	var f = get_framing(index)
	set_framing_offset(index, Vector2(f.offset.x, new))

func set_framing_fitting_mode(index: int, new: int):
	var f = get_framing(index)
	set_framing(index, f.scale, f.offset, new as FittingMode, f.top_left_corner, f.top_right_corner, f.bottom_right_corner, f.bottom_left_corner)
	commit_framings()

func set_framing_top_left(index: int, new: Vector2):
	var f = get_framing(index)
	set_framing(index, f.scale, f.offset, f.fitting_mode, new, f.top_right_corner, f.bottom_right_corner, f.bottom_left_corner)

func set_framing_top_right(index: int, new: Vector2):
	var f = get_framing(index)
	set_framing(index, f.scale, f.offset, f.fitting_mode, f.top_left_corner, new, f.bottom_right_corner, f.bottom_left_corner)

func set_framing_bottom_right(index: int, new: Vector2):
	var f = get_framing(index)
	set_framing(index, f.scale, f.offset, f.fitting_mode, f.top_left_corner, f.top_right_corner, new, f.bottom_left_corner)

func set_framing_bottom_left(index: int, new: Vector2):
	var f = get_framing(index)
	set_framing(index, f.scale, f.offset, f.fitting_mode, f.top_left_corner, f.top_right_corner, f.bottom_right_corner, new)

func get_framing(index: int) -> Framing:
	if framings.has(index):
		return framings[index]
	return Framing.new()

func get_distort_matrix(index: int) -> Basis:
	var framing: Framing = get_framing(index)

	var p0: Vector2 = framing.top_left_corner
	var p1: Vector2 = framing.top_right_corner
	var p2: Vector2 = framing.bottom_right_corner
	var p3: Vector2 = framing.bottom_left_corner

	return PerspectiveMath.get_homogenous_matrix(p0,p1,p2,p3)

func get_distort_ratio(index: int, image_aspect: float) -> float:
	var framing: Framing = get_framing(index)

	var p0: Vector2 = framing.top_left_corner
	var p1: Vector2 = framing.top_right_corner
	var p2: Vector2 = framing.bottom_right_corner
	var p3: Vector2 = framing.bottom_left_corner

	return PerspectiveMath.calculate_aspect_ratio(p0,p1,p2,p3, image_aspect)

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
		FittingMode.STRETCH:
			w = size_mm.x
			h = size_mm.y
		FittingMode.DISTORT:
			var distorted_aspect = get_distort_ratio(index, image_aspect)
			if size_mm.aspect() > distorted_aspect:
				w = size_mm.x * scale
				h = size_mm.x * scale / distorted_aspect
			else:
				h = size_mm.y * scale
				w = size_mm.y * distorted_aspect * scale
			y = (size_mm.y - h) * (1 - offset.y) * 0.5
			x = (size_mm.x - w) * (1 + offset.x) * 0.5

	return Rect2(x, y, w, h)
