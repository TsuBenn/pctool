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
	print("Export time: %.2fms" % ((Time.get_ticks_usec() - start_time)/1000))

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

	start_timer()

	match export_type:
		EXPORT_PNG:
			return await _export_as_png(document_data, layout, output_path)
		EXPORT_PDF:
			return await _export_as_pdf(document_data, layout, output_path)

	return OK

static func _export_as_pdf(document_data: DocumentData, layout: PrintLayout , output_path: String) -> Error:
	Global.progress_started("Export to PDF")
	print("----- Started Exporting -----")
	return await PdfWriter.save_pdf_to_file(document_data,layout,output_path)

static func _export_as_png(document_data: DocumentData, layout: PrintLayout , output_path: String) -> Error:
	Global.progress_started("Export to PNG")
	return await PngWriter.save_png_to_files(document_data,layout,output_path)

static func get_tile_indices(document_data: DocumentData) -> Array[Array]:
	var tile_indices: Array[Array] = []
	for item in document_data.photo_items:
		for index in item.asset.get_count():
			tile_indices.append([item, index])
	return tile_indices

static func get_tiles_position(tile_indices: Array[Array]) -> Dictionary:
	var positions: Dictionary = {}
	var position = 0
	for tile in tile_indices:
		positions[tile] = position
		position += 1
	return positions

static func get_tiles_tracker(tile_indices: Array[Array]) -> Dictionary:
	var tracker: Dictionary = {}
	for tile in tile_indices:
		tracker[tile] = false
	return tracker

static func bake_tile_images(tile_indices: Array[Array], dpi: int, processed_tiles: int = 0) -> Dictionary:

	print("----- Baking Tile Images -----")
	Global.print_memory_usage()
	Global.print_video_memory_usage()
	print("------------------------------")

	var MAX_RAM_MB: float = 1000
	var MAX_VRAM_MB: float = 1000

	var baked_map: Dictionary = {}
	var render_tasks: Array[Dictionary] = []

	var px_per_mm: float = (dpi/25.4)

	var milestone: float = Time.get_ticks_msec()

	var temp_mat : Array[ShaderMaterial] = []

	var total_tiles: int = tile_indices.size()

	var texture_map: Dictionary = {} # [item, index] -> Texture2D

	var mutex: Mutex = Mutex.new()
	var shared_counter: Dictionary = {
		"current": 0,
		"total": total_tiles,
		"canceled": false,
		"mb": 0,
		"logged": false,
	}

	var create_texture = func(i: int):
		mutex.lock()
		if shared_counter["canceled"]:
			mutex.unlock()
			return
		if shared_counter["mb"] > MAX_VRAM_MB:
			if not shared_counter["logged"]:
				print.call_deferred("Exeeded %.2f/%.2f MB of VRAM, offloading... (%d/%d)" % [shared_counter["mb"], MAX_VRAM_MB, shared_counter["current"] + processed_tiles, total_tiles + processed_tiles])
				shared_counter["logged"] = true
				shared_counter["canceled"] = true
			mutex.unlock()
			return
		mutex.unlock()

		var tile = tile_indices[i]
		var item: PhotoItemData = tile[0]
		var index: int = tile[1]
		var raw_img: Image = item.asset.get_image(index)
		# var raw_tex: ImageTexture = ImageTexture.create_from_image(raw_img)

		mutex.lock()
		if shared_counter["mb"] > MAX_VRAM_MB:
			if not shared_counter["logged"]:
				print.call_deferred("Exeeded %.2f/%.2f MB of VRAM, offloading... (%d/%d)" % [shared_counter["mb"], MAX_VRAM_MB, shared_counter["current"] + processed_tiles, total_tiles + processed_tiles])
				shared_counter["logged"] = true
				shared_counter["canceled"] = true
			mutex.unlock()
			return
		shared_counter["mb"] += ((raw_img.get_size().x*raw_img.get_size().y*4)/(1024.0*1024.0)) * 1.3333
		shared_counter["current"] += 1
		texture_map[tile] = raw_img
		mutex.unlock()

	var group_id: int = WorkerThreadPool.add_group_task(
		create_texture,
		total_tiles,
		-1,
		true,
		"CREATING_TEXTURE"
	)

	while (shared_counter["current"] < shared_counter["total"] and not shared_counter["canceled"]):
		if Global.progress_flag:
			return {}
		Global.progress_update("Decoding Tiles (%d/%d)" % [shared_counter["current"] + processed_tiles, total_tiles + processed_tiles], float(shared_counter["current"] + processed_tiles)/(total_tiles + processed_tiles))
		await Engine.get_main_loop().process_frame

	WorkerThreadPool.wait_for_group_task_completion(group_id)

	# for i in range(total_tiles):
	# 	create_texture.call(i)

	# PLEASE DO NOT ALLOCATE GPU MEMORIES IN MULTI THREADS
	for tile in texture_map.keys():
		var img: Image = texture_map[tile]
		var tex: ImageTexture = ImageTexture.create_from_image(img)
		texture_map[tile] = tex

	# print(shared_counter)
	# print(texture_map.keys())
	# print(Global.print_memory_usage())
	# print(Global.print_video_memory_usage())

	# Global.cancel_progress()

	# return {}

	print("----- Decoding Tiles Done! -----")
	Global.print_memory_usage()
	Global.print_video_memory_usage()

	# print(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/ (1024.0 * 1024.0))

	var tile_calls: int = 0

	while ((Global.get_memory_usage_mb() <= MAX_RAM_MB) and tile_calls < total_tiles) or tile_calls == 0:
		for tile in texture_map.keys():
			var item: PhotoItemData = tile[0]
			var index: int = tile[1]

			var framing = item.get_framing(index)
			var image_rect = item.get_image_rect_mm(index)

			var raw_tex: Texture2D = texture_map[tile]

			if raw_tex == null:
				return baked_map

			var tree: SceneTree = Engine.get_main_loop() as SceneTree

			var shader_mat: ShaderMaterial = null
			if tree and tree.current_scene and tree.current_scene.distort_shader_material:
				shader_mat = tree.current_scene.distort_shader_material as ShaderMaterial
			else:
				Global.notice("Tile Renderer Failed", "Missing Shader Material")
				return baked_map

			var mat: ShaderMaterial = shader_mat.duplicate()
			temp_mat.append(mat)

			var homography_mat: Basis = item.get_distort_matrix(index)
			mat.set_shader_parameter("u_homography_matrix", homography_mat if framing.fitting_mode == PhotoItemData.FittingMode.DISTORT else Basis.IDENTITY)
			mat.set_shader_parameter("out_bound_opacity", 1)

			var viewport_rid: RID = RenderingServer.viewport_create()
			var canvas_rid: RID = RenderingServer.canvas_create()
			var canvas_item_rid: RID = RenderingServer.canvas_item_create()
			var texture_rid: RID = raw_tex.get_rid()
			var material_rid: RID = mat.get_rid()


			RenderingServer.viewport_set_size(viewport_rid, round(item.size_mm.x * px_per_mm), round(item.size_mm.y * px_per_mm))
			RenderingServer.viewport_set_transparent_background(viewport_rid, true)
			RenderingServer.viewport_attach_canvas(viewport_rid, canvas_rid)
			RenderingServer.viewport_set_active(viewport_rid, true)
			RenderingServer.viewport_set_update_mode(viewport_rid, RenderingServer.VIEWPORT_UPDATE_ONCE)

			RenderingServer.canvas_item_set_parent(canvas_item_rid, canvas_rid)
			RenderingServer.canvas_item_set_material(canvas_item_rid, material_rid)
			RenderingServer.canvas_item_set_default_texture_filter(canvas_item_rid, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR)

			var dest_rect: Rect2 = Rect2(image_rect.position*px_per_mm, image_rect.size*px_per_mm)
			RenderingServer.canvas_item_add_rect(canvas_item_rid, dest_rect, Color.WHITE)
			RenderingServer.canvas_item_add_texture_rect(canvas_item_rid, dest_rect, texture_rid)

			render_tasks.append({
				"item": item,
				"index": index,
				"viewport": viewport_rid,
				"canvas": canvas_rid,
				"canvas_item": canvas_item_rid,
			})

			if Global.progress_flag:
				break

			tile_calls += 1

			# if Global.get_video_memory_usage_mb() > MAX_VRAM_MB:
			# 	print("Exeeded %.2f/%.2f MB of VRAM, offloading... (%d/%d)" % [Global.get_video_memory_usage_mb(), MAX_VRAM_MB, tile_calls + processed_tiles, total_tiles + processed_tiles])
			# 	break
			if Global.get_memory_usage_mb() > MAX_RAM_MB:
				print("Exeeded %.2f/%.2f MB of RAM, offloading... (%d/%d)" % [Global.get_memory_usage_mb(), MAX_RAM_MB,tile_calls + processed_tiles, total_tiles + processed_tiles])
				break

			if Time.get_ticks_msec() - milestone > 100:
				milestone = Time.get_ticks_msec()
				Global.progress_update("Preparing Tiles (%d/%d)" % [tile_calls + processed_tiles, total_tiles + processed_tiles], float(tile_calls + processed_tiles)/total_tiles + processed_tiles)
				await Engine.get_main_loop().process_frame

		if render_tasks.is_empty():
			return baked_map

		Global.progress_update("Rendering %d Tiles" % total_tiles, 0)
		await Engine.get_main_loop().process_frame

		# await RenderingServer.frame_post_draw
		RenderingServer.force_draw()

		print("----- Baked Tiles Done! -----")
		Global.print_memory_usage()
		Global.print_video_memory_usage()

		temp_mat.clear()
		texture_map.clear()

		Global.progress_update("Rendering %d Tiles" % total_tiles, 1)
		await Engine.get_main_loop().process_frame

		Global.progress_update("Baking Tiles (%d/%d)" % [tile_calls + processed_tiles, total_tiles + processed_tiles], float(tile_calls)/total_tiles)
		await Engine.get_main_loop().process_frame

		milestone = Time.get_ticks_msec()

		for task in render_tasks:
			var viewport: RID = task["viewport"]
			var canvas: RID = task["canvas"]
			var canvas_item: RID = task["canvas_item"]

			if not Global.progress_flag:
				var item: PhotoItemData = task["item"]
				var index: int = task["index"]

				var rendered_tex_rid: RID = RenderingServer.viewport_get_texture(viewport)
				var rendered_img: Image = RenderingServer.texture_2d_get(rendered_tex_rid)

				if rendered_img:
					baked_map[[item, index]] = rendered_img

			RenderingServer.free_rid(viewport)
			RenderingServer.free_rid(canvas)
			RenderingServer.free_rid(canvas_item)

			if Time.get_ticks_msec() - milestone > 100:
				milestone = Time.get_ticks_msec()
				Global.progress_update("Baking Tiles (%d/%d)" % [tile_calls + processed_tiles, total_tiles + processed_tiles], float(tile_calls + processed_tiles)/total_tiles + processed_tiles)
				await Engine.get_main_loop().process_frame

		render_tasks.clear()

	if (Global.get_memory_usage_mb() > MAX_RAM_MB):
		print("Exeeded %.2f/%.2f MB of RAM, offloading... (%d/%d)" % [Global.get_memory_usage_mb(), MAX_RAM_MB,tile_calls + processed_tiles, total_tiles + processed_tiles])

	print("----- Finished Baking Tiles -----")
	Global.print_memory_usage()
	Global.print_video_memory_usage()

	return baked_map

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
