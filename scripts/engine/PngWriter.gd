extends RefCounted
class_name PngWriter

static func save_png_to_files(document_data: DocumentData, layout: PrintLayout, output_path: String) -> Error:
	var ext: String = output_path.get_extension()
	var base_no_ext: String = output_path.get_basename()

	if ext.is_empty() or ext != "png":
		ext = "png"

	for page in range(layout.total_pages):
		var page_image: Image = await PngWriter.render_page_to_image(document_data, layout, page)

		if page_image == null:
			Global.notice("Export PNG failed", "Failed to render image on page %d" % page)
			push_error("ExportEngine: Failed to render image on page %d" % page)
			return FAILED

		var path_string: String = ""

		if page == 0:
			path_string = "%s.%s" % [base_no_ext, ext]
		else:
			path_string = "%s_%s.%s" % [base_no_ext, str(page).pad_zeros(2), ext]

		var error: Error = page_image.save_png(path_string)
		if error != OK:
			Global.notice("Export PNG failed", "Failed to save PNG to file: %s" % path_string)
			push_error("ExportEngine: Failed to save PNG to file: %s" % path_string)
			return error

	Global.notice("Export Complete", "PNG document successfully exported to:\n%s" % output_path.get_file())
	ExportEngine.end_timer()
	return OK

static func render_page_to_image(document_data: DocumentData, layout: PrintLayout, page_idx: int) -> Image:
	var dpi: int = document_data.dpi
	var px_per_mm: float = dpi/25.4

	var page_size_px: Vector2i = Vector2i(document_data.paper_size_mm * px_per_mm)

	var master_image: Image = Image.create_empty(page_size_px.x, page_size_px.y, false, Image.FORMAT_RGBA8)
	master_image.fill(Color.WHITE)

	var tiles: Array[PhotoTile] = layout.get_page_tiles(page_idx)

	for tile in tiles:
		var item: PhotoItemData = tile.photo_item
		if item == null or item.asset == null:
			continue

		var frame_pos_px: Vector2i = Vector2i(tile.rect_mm.position * px_per_mm)
		var frame_size_px: Vector2i = Vector2i(tile.rect_mm.size * px_per_mm)

		var tile_image: Image = await ExportEngine.bake_tile_image(tile, dpi)

		if tile_image == null:
			return null

		master_image.blend_rect(tile_image, Rect2i(Vector2i.ZERO, tile_image.get_size()), frame_pos_px)

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
