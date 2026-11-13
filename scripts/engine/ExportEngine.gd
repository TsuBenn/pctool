class_name ExportEngine
extends RefCounted

enum ExportMode {
	EXPORT_PNG,
	EXPORT_PDF,
}

const EXPORT_PNG = ExportMode.EXPORT_PNG
const EXPORT_PDF = ExportMode.EXPORT_PDF

static var start_time: float

static func start_timer():
	start_time = Time.get_ticks_usec()


static func end_timer():
	print("Export time: %.2fms" % ((Time.get_ticks_usec() - start_time) / 1000))

static func export_document(
	document_data: DocumentData, output_path: String, export_type: int, open_on_finished: bool
) -> Error:
	if not document_data:
		Global.notice("Export Failed", "No Document Data has been provided!")
		push_error("ExportEngine: No Document Data has been provided!")
		return ERR_INVALID_PARAMETER

	var layout: PrintLayout = _calculate_layout(document_data)
	if layout.is_empty():
		Global.notice("Export Failed", "Document has no content to be exported!")
		push_error("ExportEngine: Document has no content to be exported!")
		return ERR_CANT_CREATE

	start_timer()

	document_data.export_path = output_path.get_base_dir()

	var engine = prepare_workload(document_data, layout)

	match export_type:
		EXPORT_PNG:
			if engine.export_as_png(output_path) == OK:
				while engine.get_status() == 1:
					print("cooking")
				print("done")
		EXPORT_PDF:
			if engine.export_as_pdf(output_path) == OK:
				Global.progress_started("Export to PDF")
				while engine.get_status() == 1:
					if Global.progress_flag:
						engine.cancel_export()
						Global.progress_finished()
						Global.notice("Export Canceled", "PDF Exportation has been Canceled by User" % output_path.get_file())
						return OK
					Global.progress_update("Exporting to PDF", engine.get_progress())
					await Engine.get_main_loop().process_frame
				match engine.get_status():
					2:
						Global.notice.call_deferred("Export Complete", "PDF document successfully exported to:\n%s" % output_path.get_file())
					_:
						Global.notice.call_deferred("Export Failed", "PDF document failed to export to:\n%s" % output_path.get_file())
				Global.progress_finished()

	end_timer()
	return OK

static func prepare_workload(document_data: DocumentData, layout: PrintLayout) -> RsExportEngine:
	var engine = RsExportEngine.new_engine(document_data.paper_size_mm, document_data.dpi)
	for asset in document_data.assets:
		if asset is GroupAssetData:
			for sub_asset in asset.children:
				if not engine.add_asset(sub_asset.id, sub_asset.source_path, sub_asset is PdfAssetData):
					return
			continue

		if not engine.add_asset(asset.id, asset.source_path, asset is PdfAssetData):
			return

	for page in layout.pages:
		for tile: PhotoTile in page:
			var asset = tile.photo_item.asset
			var photo_item = tile.photo_item
			var index = tile.sub_asset_index
			var asset_id = asset.id
			if asset is GroupAssetData:
				asset_id = asset.get_child(index).id
				index = 0
			if not engine.add_tile(asset_id, tile.rect_mm, photo_item.get_image_rect_mm(tile.sub_asset_index), index, tile.page_index, photo_item.border_width, photo_item.border_color):
				return
			var framing = photo_item.get_framing(index)
			if framing.fitting_mode == photo_item.FittingMode.DISTORT:
				engine.set_last_tile_perspective(
					index,
					framing.top_left_corner,
					framing.top_right_corner,
					framing.bottom_right_corner,
					framing.bottom_left_corner
				)

	return engine

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
		var sub_asset_count = photo_item.asset.get_count()

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
			for sub_asset_index in sub_asset_count:
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
					sub_asset_index
				)
				layout.add_tile(new_tile)

				current_x += tile_size.x + spacing

				row_height = max(row_height, tile_size.y)

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

	return layout
