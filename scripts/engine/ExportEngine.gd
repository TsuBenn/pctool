class_name ExportEngine
extends RefCounted

static func export_document(document_data: DocumentData, output_path: String) -> Error:
	if not document_data:
		push_error("ExportEngine: No Document Data has been provided!")
		return ERR_INVALID_PARAMETER

	var layout: PrintLayout = _calculate_layout(document_data)
	if layout.is_empty():
		push_error("ExportEngine: Document has no content to be exported!")
		return ERR_CANT_CREATE

	var total_pages: int = layout.total_pages
	var base_no_ext: String = output_path.get_basename()
	var ext: String = output_path.get_extension()

	if ext.is_empty():
		ext = "png"

	for page_idx in range(total_pages):
		var page_image: Image = render_page_to_image(document_data, layout, page_idx)
		if page_image == null:
			push_error("ExportEngine: Failed to render image on page %d" % page_idx)
			return FAILED

		var path_string: String = "%s_%s.%s" % [base_no_ext, str(page_idx).pad_zeros(2), ext]

		var error: Error = page_image.save_png(path_string)
		if error != OK:
			push_error("ExportEngine: Failed to save PNG to file: %s" % path_string)
			return error

	return OK

static func render_page_to_image(document_data: DocumentData, layout: PrintLayout, page_idx: int):
	var dpi: int = document_data.dpi
	var px_per_mm: float = dpi/25.4

	var page_size_px: Vector2i = Vector2i(document_data.paper_size_mm * px_per_mm)

	var master_image: Image = Image.create(page_size_px.x, page_size_px.y, false, Image.FORMAT_RGBA8)
	master_image.fill(Color.WHITE)

	var tiles: Array[PhotoTile] = layout.get_page_tiles(page_idx)

	for tile in tiles:
		var item: PhotoItemData = tile.photo_item
		if item == null or item.asset == null:
			continue

		var raw_source: Image = item.asset.get_image(tile.sub_asset_index)
		if raw_source == null or raw_source.is_empty():
			continue

		var photo_img: Image = raw_source.duplicate()

		if photo_img.get_format() != Image.FORMAT_RGBA8:
			photo_img.convert(Image.FORMAT_RGBA8)

		var frame_pos_px: Vector2i = Vector2i(tile.rect_mm.position * px_per_mm)
		var frame_size_px: Vector2i = Vector2i(tile.rect_mm.size * px_per_mm)

		var image_rect_mm: Rect2 = item.get_image_rect_mm(tile.sub_asset_index)
		var crop_pos_px: Vector2i = Vector2i(image_rect_mm.position * px_per_mm)
		var crop_size_px: Vector2i = Vector2i(image_rect_mm.size * px_per_mm)

		photo_img.resize(crop_size_px.x, crop_size_px.y, int(item.filter_mode))

		_blend_photo_img(master_image,photo_img,frame_size_px,frame_pos_px,crop_pos_px)

		if item.border_enabled and item.border_width > 0:
			var border_width: int = max(item.border_width, 1) * px_per_mm
			_draw_border_rect(master_image, frame_pos_px, frame_size_px, border_width, item.border_color)

	return master_image


static func _draw_border_rect(master_img: Image, frame_pos: Vector2i, frame_size: Vector2i, thickness: int, color: Color):
	var x1: int = frame_pos.x
	var y1: int = frame_pos.y
	var x2: int = frame_pos.x + frame_size.x - 1
	var y2: int = frame_pos.y + frame_size.y - 1

	for t in range(thickness):
		for x in range(x1, x2 + 1):
			master_img.set_pixel(x, y1 + t, color)
			master_img.set_pixel(x, y2 - t, color)
		for y in range(y1, y2 + 1):
			master_img.set_pixel(x1 + t, y, color)
			master_img.set_pixel(x2 - t, y, color)

static func _blend_photo_img(
		master_img: Image,
		photo_img: Image,
		frame_size: Vector2i,
		frame_pos: Vector2i,
		crop_offset_px: Vector2i,
	) -> void:

	var src_x: int = max(-crop_offset_px.x, 0)
	var src_y: int = max(-crop_offset_px.y, 0)

	var src_w: int = min(photo_img.get_width() - src_x, frame_size.x)
	var src_h: int = min(photo_img.get_height() - src_y, frame_size.y)

	var dst_x: int = frame_pos.x + max(crop_offset_px.x, 0)
	var dst_y: int = frame_pos.y + max(crop_offset_px.y, 0)

	master_img.blend_rect(photo_img, Rect2i(src_x,src_y,src_w,src_h), Vector2i(dst_x,dst_y))

static func _calculate_layout(document_data: DocumentData) -> PrintLayout:
	var layout: PrintLayout = PrintLayout.new()

	var start_x: float = document_data.margins_mm
	var start_y: float = document_data.margins_mm
	var max_x: float = document_data.paper_size_mm.x - document_data.margins_mm
	var max_y: float = document_data.paper_size_mm.y - document_data.margins_mm
	var spacing: float = document_data.spacing_mm

	var current_x: float = start_x
	var current_y: float = start_y
	var row_height: float = 0.0
	var current_page: int = 0

	for photo_item: PhotoItemData in document_data.photo_items:
		var tile_size = photo_item.size_mm

		if tile_size.x > max_x - start_x or tile_size.y > max_y - start_y:
			layout.unplaced_items.append(photo_item)
			continue

		for copy in photo_item.quantity:
			if current_x > start_x and (current_x + tile_size.x > max_x):
				current_x = start_x
				current_y += row_height + spacing
				row_height = 0.0

			if current_y + tile_size.y > max_y:
				current_x = start_x
				current_y = start_y
				row_height = 0
				current_page += 1

			var new_tile = PhotoTile.new(
				photo_item,
				current_page,
				Rect2(Vector2(current_x, current_y), Vector2(tile_size.x, tile_size.y)),
				copy,
				0
			)
			layout.add_tile(new_tile)

			current_x += tile_size.x + spacing

			row_height = max(row_height, tile_size.y)

	return layout

