class_name PdfWriter
extends RefCounted

## Points per millimeter constant (72 pt per inch / 25.4 mm)
const MM_TO_PT: float = 72.0 / 25.4

## Saves an object-based multi-page PDF where unique photo tiles are de-duplicated and stamped.
static func save_pdf_to_file(
	doc: DocumentData,
	layout: PrintLayout,
	output_path: String,
	baked_images_map: Dictionary # PhotoItemData, Index -> Image (Baked 300 DPI sticker)
) -> Error:

	Global.progress_update("Preparing PDF", 0)
	await Engine.get_main_loop().process_frame

	var ext: String = output_path.get_extension()

	if ext.is_empty() or ext != "pdf":
		output_path += ".pdf"

	if layout.is_empty():
		Global.notice("Export Failed", "There are no photo items placed on the sheet to export.")
		push_error("PdfWriter: Layout is empty.")
		return ERR_INVALID_PARAMETER

	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		var err = FileAccess.get_open_error()
		Global.notice("Export Failed", "Could not create PDF file at:\n%s\n(Error code: %d)" % [output_path, err])
		push_error("PdfWriter: Failed to open file at: %s (Error: %d)" % [output_path, err])
		return err

	var num_pages: int = layout.total_pages
	var page_w_pt: float = doc.paper_size_mm.x * MM_TO_PT
	var page_h_pt: float = doc.paper_size_mm.y * MM_TO_PT

	var offsets: Array[int] = []

	# Write standard PDF header
	file.store_string("%PDF-1.4\n")
	# Binary marker to prevent text-mode mangling across OSes
	file.store_buffer(PackedByteArray([0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]))

	# 1. Map each unique PhotoItemData to an XObject image resource name and object ID
	var item_to_resource_id: Dictionary = {} # PhotoItemData, Index -> int (e.g. 0 for /Im0)
	var image_items: Array[Array] = []
	var res_counter: int = 0

	Global.progress_update("Preparing Images", 0.1)
	await Engine.get_main_loop().process_frame

	for item in doc.photo_items:
		for index in item.asset.get_count():
			if baked_images_map.has([item, index]) and not item_to_resource_id.has([item, index]):
				item_to_resource_id[[item, index]] = res_counter
				image_items.append([item,index])
				res_counter += 1

	var first_img_obj_id: int = 3
	var first_page_obj_id: int = first_img_obj_id + image_items.size()

	# --- OBJ 1: Catalog ---
	offsets.append(file.get_position())
	file.store_string("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")

	# --- OBJ 2: Pages Parent Tree ---
	offsets.append(file.get_position())
	var page_refs: String = ""
	for p in range(num_pages):
		var p_obj: int = first_page_obj_id + (p * 2)
		page_refs += "%d 0 R " % p_obj

	file.store_string(
		"2 0 obj\n<< /Type /Pages /Kids [ %s] /Count %d >>\nendobj\n"
		% [page_refs, num_pages]
	)

	# --- IMAGE XOBJECTS (De-duplicated) ---
	var xobject_resource_dict: String = "<< "

	var total_images: int = image_items.size()
	var images_to_encode: Array[Image] = []
	var jpg_buffers: Array[PackedByteArray] = []

	images_to_encode.resize(total_images)
	jpg_buffers.resize(total_images)

	Global.progress_update("Encoding Images", 0.3)
	await Engine.get_main_loop().process_frame

	for i in range(total_images):
		var item = image_items[i]
		images_to_encode[i] = baked_images_map[[item[0], item[1]]]

	var mutex: Mutex = Mutex.new()
	var shared_counter: Dictionary = {
		"current": 0,
		"total": total_images
	}

	var encode_task = func(i: int):
		var img = images_to_encode[i]
		jpg_buffers[i] = img.save_jpg_to_buffer(0.90)
		mutex.lock()
		shared_counter["current"] += 1
		mutex.unlock()

	# var start_time: float = Time.get_ticks_usec()

	var group_id: int = WorkerThreadPool.add_group_task(
		encode_task,
		total_images,
		-1,
		true,
		"PDF_JPEG_ENCODING"
	)

	while shared_counter["current"] < shared_counter["total"]:
		Global.progress_update("Encoding Images (%d/%d)" % [shared_counter["current"],shared_counter["total"]], shared_counter["current"]/float(shared_counter["total"]))
		await Engine.get_main_loop().process_frame

	WorkerThreadPool.wait_for_group_task_completion(group_id)

	# print("Image -> JPEG: " + str((Time.get_ticks_usec() - start_time)/1000.0))

	Global.progress_update("Writing Images to PDF", 0.3)
	await Engine.get_main_loop().process_frame

	var milestone: float = Time.get_ticks_msec()

	for i in range(total_images):
		var img: Image = images_to_encode[i]
		var obj_id: int = first_img_obj_id + i
		var jpg_buffer: PackedByteArray = jpg_buffers[i]

		xobject_resource_dict += "/Im%d %d 0 R " % [i, obj_id]

		offsets.append(file.get_position())
		file.store_string(
			"%d 0 obj\n<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length %d >>\nstream\n"
			% [obj_id, img.get_width(), img.get_height(), jpg_buffer.size()]
		)
		file.store_buffer(jpg_buffer)
		file.store_string("\nendstream\nendobj\n")

		if Time.get_ticks_msec() - milestone > 100:
			milestone = Time.get_ticks_msec()
			Global.progress_update("Writing Images to PDF", 0.3 + 0.5*(i/float(total_images)))
			await Engine.get_main_loop().process_frame

	xobject_resource_dict += ">>"

	Global.progress_update("Arranging Images in PDF", 0.8)
	await Engine.get_main_loop().process_frame

	milestone = Time.get_ticks_msec()

	# --- PAGES & DRAWING CONTENT STREAMS ---
	for p in range(num_pages):
		var page_obj_id: int = first_page_obj_id + (p * 2)
		var content_obj_id: int = page_obj_id + 1

		var tiles: Array[PhotoTile] = layout.get_page_tiles(p)

		# Build PostScript drawing commands for this page
		var content_str: String = ""

		for tile in tiles:
			var item: PhotoItemData = tile.photo_item
			if not item_to_resource_id.has([item, tile.sub_asset_index]):
				continue

			var res_id: int = item_to_resource_id[[item, tile.sub_asset_index]]

			# Convert mm to PDF points
			var tile_w_pt: float = tile.rect_mm.size.x * MM_TO_PT
			var tile_h_pt: float = tile.rect_mm.size.y * MM_TO_PT
			var tile_x_pt: float = tile.rect_mm.position.x * MM_TO_PT

			# Flip Y coordinate (PDF origin is bottom-left, Godot is top-left)
			var tile_y_pt: float = (doc.paper_size_mm.y - tile.rect_mm.position.y - tile.rect_mm.size.y) * MM_TO_PT

			# 1. Stamp Image Matrix: q (push state), cm (transform), /ImX Do (draw), Q (pop state)
			content_str += (
				"q\n%.2f 0 0 %.2f %.2f %.2f cm\n/Im%d Do\nQ\n"
				% [tile_w_pt, tile_h_pt, tile_x_pt, tile_y_pt, res_id]
			)

			# 2. Draw Vector Cut Border (if enabled)
			if item.border_enabled and item.border_width > 0.0:
				var border_w_pt: float = max(0.5, item.border_width * MM_TO_PT)
				var c: Color = item.border_color
				# Set stroke color (RG), line width (w), draw rectangle (re), stroke (S)
				content_str += (
					"q\n%.2f w\n%.3f %.3f %.3f RG\n%.2f %.2f %.2f %.2f re\nS\nQ\n"
					% [border_w_pt, c.r, c.g, c.b, tile_x_pt, tile_y_pt, tile_w_pt, tile_h_pt]
				)

		var content_buffer: PackedByteArray = content_str.to_utf8_buffer()

		# Write Page Dictionary
		offsets.append(file.get_position())
		file.store_string(
			"%d 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.2f %.2f] /Contents %d 0 R /Resources << /XObject %s >> >>\nendobj\n"
			% [page_obj_id, page_w_pt, page_h_pt, content_obj_id, xobject_resource_dict]
		)

		# Write Page Content Stream
		offsets.append(file.get_position())
		file.store_string(
			"%d 0 obj\n<< /Length %d >>\nstream\n%sendstream\nendobj\n"
			% [content_obj_id, content_buffer.size(), content_str]
		)

		if Time.get_ticks_msec() - milestone > 100:
			milestone = Time.get_ticks_msec()
			Global.progress_update("Arranging Images in PDF", 0.8 + 0.2*(p/float(num_pages)))
			await Engine.get_main_loop().process_frame

	# --- WRITE CROSS-REFERENCE TABLE (XREF) ---
	var xref_offset: int = file.get_position()
	var total_objects: int = offsets.size() + 1

	file.store_string("xref\n0 %d\n" % total_objects)
	file.store_string("0000000000 65535 f \n")

	for offset in offsets:
		file.store_string("%010d 00000 n \n" % offset)

	# --- WRITE TRAILER ---
	file.store_string("trailer\n<< /Size %d /Root 1 0 R >>\n" % total_objects)
	file.store_string("startxref\n%d\n%%%%EOF\n" % xref_offset)

	file.close()
	Global.notice.call_deferred("Export Complete", "PDF document successfully exported to:\n%s" % output_path.get_file())
	Global.progress_finished()
	ExportEngine.end_timer()
	return OK
