extends RefCounted
class_name PngWriter

static func save_png_to_files(document_data: DocumentData, layout: PrintLayout, output_path: String) -> Error:
	var ext: String = output_path.get_extension()
	var base_no_ext: String = output_path.get_basename()

	if ext.is_empty() or ext != "png":
		ext = "png"

	for page in range(layout.total_pages):
		var page_image: Image = PngWriter.render_page_to_image(document_data, layout, page)

		if page_image == null:
			Global.notice("Export failed", "Failed to render image on page %d" % page)
			push_error("ExportEngine: Failed to render image on page %d" % page)
			return FAILED

		var path_string: String = ""

		if page == 0:
			path_string = "%s.%s" % [base_no_ext, ext]
		else:
			path_string = "%s_%s.%s" % [base_no_ext, str(page).pad_zeros(2), ext]

		var error: Error = page_image.save_png(path_string)
		if error != OK:
			Global.notice("Export failed", "Failed to save PNG to file: %s" % path_string)
			push_error("ExportEngine: Failed to save PNG to file: %s" % path_string)
			return error

	Global.notice("Export Complete", "PNG document successfully exported to:\n%s" % output_path.get_file())
	return OK

static func render_page_to_image(document_data: DocumentData, layout: PrintLayout, page_idx: int) -> Image:
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
			var border_width: int = max(item.border_width, 0.2) * px_per_mm
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
