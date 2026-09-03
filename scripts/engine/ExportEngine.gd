class_name ExportEngine
extends RefCounted

enum ExportMode {
		EXPORT_PNG,
		EXPORT_PDF,
	}

const EXPORT_PNG = ExportMode.EXPORT_PNG
const EXPORT_PDF = ExportMode.EXPORT_PDF

static func export_document(document_data: DocumentData, output_path: String, export_type: int) -> Error:
	if not document_data:
		Global.notice("Export Failed", "No Document Data has been provided!")
		push_error("ExportEngine: No Document Data has been provided!")
		return ERR_INVALID_PARAMETER

	var layout: PrintLayout = _calculate_layout(document_data)
	if layout.is_empty():
		Global.notice("Export Failed", "Document has no content to be exported!")
		push_error("ExportEngine: Document has no content to be exported!")
		return ERR_CANT_CREATE

	match export_type:
		EXPORT_PNG:
			_export_as_png(document_data, layout, output_path)
		EXPORT_PDF:
			_export_as_pdf(document_data, layout, output_path)
			pass

	return OK

static func _export_as_pdf(document_data: DocumentData, layout: PrintLayout , output_path: String) -> Error:
	var baked_map: Dictionary = {}

	for item in document_data.photo_items:
		if not baked_map.has(item):
			var dummy_tile: PhotoTile = PhotoTile.new(item, 0, Rect2(Vector2.ZERO, item.size_mm), 0, 0)
			var baked_img: Image = bake_tile_image(dummy_tile, document_data.dpi)
			if baked_img:
				baked_map[item] = baked_img

	return PdfWriter.save_pdf_to_file(document_data,layout,output_path,baked_map)

static func _export_as_png(document_data: DocumentData, layout: PrintLayout , output_path: String) -> Error:
	return PngWriter.save_png_to_files(document_data,layout,output_path)

static func bake_tile_image(tile: PhotoTile, dpi: int) -> Image:
	var px_per_mm: float = dpi/25.4


	var tile_w: int = int(tile.rect_mm.size.x * px_per_mm)
	var tile_h: int = int(tile.rect_mm.size.y * px_per_mm)

	var tile_image: Image = Image.create(tile_w, tile_h, false, Image.FORMAT_RGBA8)
	tile_image.fill(Color(1,1,1,1))

	var image_rect_mm: Rect2 = tile.photo_item.get_image_rect_mm(tile.sub_asset_index)

	var item: PhotoItemData = tile.photo_item
	if item == null or item.asset == null:
		return tile_image

	var source_image: Image = item.asset.get_image(tile.sub_asset_index)
	if source_image.is_empty() or source_image == null:
		return tile_image

	var asset_image: Image = source_image.duplicate()
	if asset_image.get_format() != Image.FORMAT_RGBA8:
		asset_image.convert(Image.FORMAT_RGBA8)

	var crop_size_px: Vector2i = image_rect_mm.size * px_per_mm
	var crop_pos_px: Vector2i = image_rect_mm.position * px_per_mm

	asset_image.resize(crop_size_px.x, crop_size_px.y, tile.photo_item.filter_mode as Image.Interpolation)

	var src_x : int = max(-crop_pos_px.x,0)
	var src_y : int = max(-crop_pos_px.y,0)

	var src_w : int = tile_w
	var src_h : int = tile_h

	var dst_x : int = max(crop_pos_px.x, 0)
	var dst_y : int = max(crop_pos_px.y, 0)

	tile_image.blend_rect(asset_image, Rect2i(src_x,src_y,src_w,src_h), Vector2i(dst_x,dst_y))

	return tile_image

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

		if photo_item.isolate_row and not photo_item.isolate_page and current_x != start_x:
			current_x = start_x
			current_y += row_height + spacing
			row_height = 0.0

			if current_y + tile_size.y > max_y:
				current_x = start_x
				current_y = start_y
				row_height = 0
				current_page += 1

		if photo_item.isolate_page and (current_x != start_x or current_y != start_y):
			current_x = start_x
			current_y = start_y
			row_height = 0
			current_page += 1

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

		if photo_item.isolate_row and not photo_item.isolate_page:
			current_x = start_x
			current_y += row_height + spacing
			row_height = 0.0

			if current_y + tile_size.y > max_y:
				current_x = start_x
				current_y = start_y
				row_height = 0
				current_page += 1

		if photo_item.isolate_page:
			current_x = start_x
			current_y = start_y
			row_height = 0
			current_page += 1

	return layout
