extends RefCounted
class_name PngWriter

static func save_png_to_files(document_data: DocumentData, layout: PrintLayout, output_path: String) -> Error:
	var ext: String = output_path.get_extension()
	var base_no_ext: String = output_path.get_basename()

	if ext.is_empty() or ext != "png":
		ext = "png"

	var baked_map: Dictionary = await ExportEngine.bake_tile_images(document_data)
	var texture_map: Array[Texture2D] = []

	var page_images: Dictionary = {}
	var render_tasks: Array[Dictionary] = []

	var px_per_mm: float = document_data.dpi/ 25.4

	var milestone: int = Time.get_ticks_msec()
	var tiles_baked: int = 0

	Global.progress_update("Preparing Pages (%d/%d)" % [tiles_baked, layout.total_pages], float(tiles_baked)/layout.total_pages)
	await Engine.get_main_loop().process_frame

	for page in range(layout.total_pages):
		var viewport: RID = RenderingServer.viewport_create()
		var canvas: RID = RenderingServer.canvas_create()
		var canvas_item: RID = RenderingServer.canvas_item_create()

		var paper_size_px: Vector2i = round(document_data.paper_size_mm * px_per_mm)
		RenderingServer.viewport_set_size(viewport, paper_size_px.x, paper_size_px.y)
		RenderingServer.viewport_attach_canvas(viewport, canvas)
		RenderingServer.viewport_set_active(viewport, true)
		RenderingServer.viewport_set_update_mode(viewport, RenderingServer.VIEWPORT_UPDATE_ONCE)

		RenderingServer.canvas_item_set_parent(canvas_item, canvas)
		RenderingServer.canvas_item_set_default_texture_filter(canvas_item, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR)

		RenderingServer.canvas_item_add_rect(canvas_item, Rect2(Vector2.ZERO, paper_size_px), Color.WHITE)

		for tile in layout.get_page_tiles(page):
			var tile_image: Image = baked_map[[tile.photo_item, tile.sub_asset_index]]
			var tile_tex: Texture2D = ImageTexture.create_from_image(tile_image)
			texture_map.append(tile_tex)
			var tile_item: PhotoItemData = tile.photo_item
			var position: Vector2i = tile.rect_mm.position*px_per_mm
			var size: Vector2i = tile.rect_mm.size*px_per_mm

			var border_width: int = max(1, int(tile_item.border_width*px_per_mm))

			RenderingServer.canvas_item_add_texture_rect(canvas_item, Rect2(position,size), tile_tex.get_rid())

			if tile_item.border_enabled:
				RenderingServer.canvas_item_add_rect(canvas_item, Rect2(position, Vector2(size.x, border_width)), tile_item.border_color)
				RenderingServer.canvas_item_add_rect(canvas_item, Rect2(position, Vector2(border_width, size.y)), tile_item.border_color)
				RenderingServer.canvas_item_add_rect(canvas_item, Rect2(Vector2(position.x + size.x - border_width,position.y), Vector2(border_width, size.y)), tile_item.border_color)
				RenderingServer.canvas_item_add_rect(canvas_item, Rect2(Vector2(position.x,position.y + size.y - border_width), Vector2(size.x, border_width)), tile_item.border_color)

		render_tasks.append({
			"page": page,
			"viewport": viewport,
			"canvas": canvas,
			"canvas_item": canvas_item,
		})

		tiles_baked += 1
		if Time.get_ticks_msec() - milestone > 100:
			milestone = Time.get_ticks_msec()
			Global.progress_update("Preparing Pages (%d/%d)" % [tiles_baked, layout.total_pages], float(tiles_baked)/layout.total_pages)
			await Engine.get_main_loop().process_frame

	if render_tasks.is_empty():
		Global.notice("Export PNG failed", "Failed to render pages")
		push_error("ExportEngine: Failed to render pages")
		return FAILED

	Global.progress_update("Rendering %d Pages" % layout.total_pages, 0)
	await Engine.get_main_loop().process_frame

	# await RenderingServer.frame_post_draw
	RenderingServer.force_draw()

	Global.progress_update("Rendering %d Pages" % layout.total_pages, 1)
	await Engine.get_main_loop().process_frame

	Global.progress_update("Baking %d Pages" % layout.total_pages, 0)
	await Engine.get_main_loop().process_frame

	tiles_baked = 0
	milestone = Time.get_ticks_msec()

	# var start_time: float = Time.get_ticks_usec()

	for task in render_tasks:
		var viewport: RID = task["viewport"]
		var canvas: RID = task["canvas"]
		var canvas_item: RID = task["canvas_item"]

		var rendered_tex_rid: RID = RenderingServer.viewport_get_texture(viewport)
		var rendered_img: Image = RenderingServer.texture_2d_get(rendered_tex_rid)

		if rendered_img:
			page_images[task["page"]] = rendered_img

		RenderingServer.free_rid(viewport)
		RenderingServer.free_rid(canvas)
		RenderingServer.free_rid(canvas_item)
		RenderingServer.free_rid(rendered_tex_rid)

		tiles_baked += 1
		if Time.get_ticks_msec() - milestone > 100:
			milestone = Time.get_ticks_msec()
			Global.progress_update("Baking Pages (%d/%d)" % [tiles_baked, render_tasks.size()], float(tiles_baked)/render_tasks.size())
			await Engine.get_main_loop().process_frame

	# print("Baking Page: " + str((Time.get_ticks_usec() - start_time)/1000.0) + "ms")

	Global.progress_update("Baking %d Pages" % layout.total_pages, 1)
	await Engine.get_main_loop().process_frame

	texture_map.clear()

	# var start_time: float = Time.get_ticks_usec()

	Global.progress_update("Encoding Pages", 0)
	await Engine.get_main_loop().process_frame

	var page_buffers: Array[PackedByteArray] = []
	page_buffers.resize(layout.total_pages)

	var mutex: Mutex = Mutex.new()
	var shared_counter: Dictionary = {
		"current": 0,
		"total": layout.total_pages
	}

	var encode_task = func(i: int):
		var img: Image = page_images[i]
		page_buffers[i] = img.save_png_to_buffer()
		mutex.lock()
		shared_counter["current"] += 1
		mutex.unlock()


	var group_id: int = WorkerThreadPool.add_group_task(
		encode_task,
		layout.total_pages,
		-1,
		true,
		"PNG_ENCODE_PAGES"
	)

	while shared_counter["current"] < shared_counter["total"]:
		Global.progress_update("Encoding Pages (%d/%d)" % [shared_counter["current"],shared_counter["total"]], shared_counter["current"]/float(shared_counter["total"]))
		await Engine.get_main_loop().process_frame

	WorkerThreadPool.wait_for_group_task_completion(group_id)

	Global.progress_update("Writing Pages to PNGs (%d/%d)" % [0, layout.total_pages], 0)
	await Engine.get_main_loop().process_frame

	for page in range(layout.total_pages):
		var path_string: String = ""

		if page == 0:
			path_string = "%s.%s" % [base_no_ext, ext]
		else:
			path_string = "%s_%s.%s" % [base_no_ext, str(page).pad_zeros(2), ext]

		var file = FileAccess.open(path_string, FileAccess.WRITE)

		var error: Error = OK

		if file == null:
			error = FileAccess.get_open_error()

		file.store_buffer(page_buffers[page])
		file.close()

		if error != OK:
			Global.notice("Export PNG failed", "Failed to save PNG to file: %s" % path_string)
			push_error("ExportEngine: Failed to save PNG to file: %s" % path_string)
			return error

		Global.progress_update("Writing Pages to PNGs (%d/%d)" % [page, layout.total_pages], float(page)/layout.total_pages)
		await Engine.get_main_loop().process_frame

	# print("IO: " + str((Time.get_ticks_usec() - start_time)/1000.0) + "ms")

	Global.notice("Export Complete", "PNG document successfully exported to:\n%s" % output_path.get_file())
	Global.progress_finished()
	ExportEngine.end_timer()
	return OK
