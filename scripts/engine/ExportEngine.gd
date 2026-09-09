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
	var baked_map: Dictionary = await bake_tile_images(document_data)
	return await PdfWriter.save_pdf_to_file(document_data,layout,output_path,baked_map)

static func _export_as_png(document_data: DocumentData, layout: PrintLayout , output_path: String) -> Error:
	Global.progress_started("Export to PNG")
	return await PngWriter.save_png_to_files(document_data,layout,output_path)

static func bake_tile_images(document_data: DocumentData):
	var baked_map: Dictionary = {}
	var render_tasks: Array[Dictionary] = []

	var px_per_mm: float = (document_data.dpi/25.4)

	var tiles_to_bake: int = 0

	for item in document_data.photo_items:
		tiles_to_bake += item.asset.get_count()

	var milestone: float = Time.get_ticks_msec()
	var tiles_baked: int = 0

	Global.progress_update("Preparing Tiles (%d/%d)" % [tiles_baked, tiles_to_bake], 0)
	await Engine.get_main_loop().process_frame

	for item in document_data.photo_items:
		for index in item.asset.get_count():
			var framing = item.get_framing(index)
			var image_rect = item.get_image_rect_mm(index)

			# var raw_img: Image = item.asset.get_image(index).duplicate()
			# raw_img.resize(round(image_rect.size.x*px_per_mm), round(image_rect.size.y*px_per_mm), Image.INTERPOLATE_TRILINEAR)
			# var raw_tex: Texture2D = ImageTexture.create_from_image(raw_img)

			var raw_tex: Texture2D = item.asset.get_preview_texture(index)

			if raw_tex == null:
				return null

			var tree: SceneTree = Engine.get_main_loop() as SceneTree

			var shader_mat: ShaderMaterial = null
			if tree and tree.current_scene and tree.current_scene.distort_shader_material:
				shader_mat = tree.current_scene.distort_shader_material
			else:
				Global.notice("Tile Renderer Failed", "Missing Shader Material")
				return null

			var homography_mat: Basis = item.get_distort_matrix(index)
			shader_mat.set_shader_parameter("u_homography_matrix", homography_mat if framing.fitting_mode == PhotoItemData.FittingMode.DISTORT else Basis.IDENTITY)
			shader_mat.set_shader_parameter("out_bound_opacity", 1)

			var viewport_rid: RID = RenderingServer.viewport_create()
			var canvas_rid: RID = RenderingServer.canvas_create()
			var canvas_item_rid: RID = RenderingServer.canvas_item_create()


			RenderingServer.viewport_set_size(viewport_rid, round(item.size_mm.x * px_per_mm), round(item.size_mm.y * px_per_mm))
			RenderingServer.viewport_set_transparent_background(viewport_rid, true)
			RenderingServer.viewport_attach_canvas(viewport_rid, canvas_rid)
			RenderingServer.viewport_set_active(viewport_rid, true)
			RenderingServer.viewport_set_update_mode(viewport_rid, RenderingServer.VIEWPORT_UPDATE_ONCE)

			RenderingServer.canvas_item_set_parent(canvas_item_rid, canvas_rid)
			RenderingServer.canvas_item_set_material(canvas_item_rid, shader_mat.get_rid())
			RenderingServer.canvas_item_set_default_texture_filter(canvas_item_rid, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR)

			var dest_rect: Rect2 = Rect2(image_rect.position*px_per_mm, image_rect.size*px_per_mm)
			RenderingServer.canvas_item_add_rect(canvas_item_rid, dest_rect, Color.WHITE)
			RenderingServer.canvas_item_add_texture_rect(canvas_item_rid, dest_rect, raw_tex.get_rid())

			render_tasks.append({
				"item": item,
				"index": index,
				"viewport": viewport_rid,
				"canvas": canvas_rid,
				"canvas_item": canvas_item_rid,
			})

			tiles_baked += 1
			if Time.get_ticks_msec() - milestone > 100:
				milestone = Time.get_ticks_msec()
				Global.progress_update("Preparing Tiles (%d/%d)" % [tiles_baked, tiles_to_bake], float(tiles_baked)/tiles_to_bake)
				await Engine.get_main_loop().process_frame

	if render_tasks.is_empty():
		return baked_map

	Global.progress_update("Rendering %d Tiles" % tiles_to_bake, 0)
	await Engine.get_main_loop().process_frame

	# await RenderingServer.frame_post_draw
	RenderingServer.force_draw()

	Global.progress_update("Rendering %d Tiles" % tiles_to_bake, 1)
	await Engine.get_main_loop().process_frame

	Global.progress_update("Baking %d Tiles" % tiles_to_bake, 0)
	await Engine.get_main_loop().process_frame

	milestone = Time.get_ticks_msec()
	tiles_baked = 0

	for task in render_tasks:
		var viewport: RID = task["viewport"]
		var canvas: RID = task["canvas"]
		var canvas_item: RID = task["canvas_item"]

		var item: PhotoItemData = task["item"]
		var index: int = task["index"]

		var rendered_tex_rid: RID = RenderingServer.viewport_get_texture(viewport)
		var rendered_img: Image = RenderingServer.texture_2d_get(rendered_tex_rid)

		if rendered_img:
			baked_map[[item, index]] = rendered_img

		RenderingServer.free_rid(viewport)
		RenderingServer.free_rid(canvas)
		RenderingServer.free_rid(canvas_item)
		RenderingServer.free_rid(rendered_tex_rid)

		tiles_baked += 1
		if Time.get_ticks_msec() - milestone > 100:
			milestone = Time.get_ticks_msec()
			Global.progress_update("Baking Tiles (%d/%d)" % [tiles_baked, render_tasks.size()], float(tiles_baked)/render_tasks.size())
			await Engine.get_main_loop().process_frame

	Global.progress_update("Baking %d Tiles" % tiles_to_bake, 1)
	await Engine.get_main_loop().process_frame

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
