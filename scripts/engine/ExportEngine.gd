class_name ExportEngine
extends RefCounted

enum ExportMode {
		EXPORT_PNG,
		EXPORT_PDF,
	}

const EXPORT_PNG = ExportMode.EXPORT_PNG
const EXPORT_PDF = ExportMode.EXPORT_PDF

static var gpu_render: bool = false

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

	gpu_render = document_data.gpu_render

	start_timer()

	match export_type:
		EXPORT_PNG:
			return await _export_as_png(document_data, layout, output_path)
		EXPORT_PDF:
			return await _export_as_pdf(document_data, layout, output_path)

	return OK

static func _export_as_pdf(document_data: DocumentData, layout: PrintLayout , output_path: String) -> Error:
	var baked_map: Dictionary = {}

	for item in document_data.photo_items:
		if not baked_map.has(item):
			var dummy_tile: PhotoTile = PhotoTile.new(item, 0, Rect2(Vector2.ZERO, item.size_mm), 0, 0)
			var baked_img: Image = await bake_tile_image(dummy_tile, document_data.dpi)
			if baked_img:
				baked_map[item] = baked_img
			else:
				Global.notice("Export PDF failed", "Failed to render image")
				push_error("ExportEngine: Failed to render image on page")
				return FAILED

	return PdfWriter.save_pdf_to_file(document_data,layout,output_path,baked_map)

static func _export_as_png(document_data: DocumentData, layout: PrintLayout , output_path: String) -> Error:
	return await PngWriter.save_png_to_files(document_data,layout,output_path)

static func bake_tile_image_gpu(tile: PhotoTile, dpi: int) -> Image:
	var item: PhotoItemData = tile.photo_item
	if item == null or item.asset == null:
		return null

	var image_rect: Rect2 = item.get_image_rect_mm(tile.sub_asset_index)
	var framing: PhotoItemData.Framing = item.get_framing(tile.sub_asset_index)

	var raw_tex: Texture2D = item.asset.get_preview_texture(tile.sub_asset_index)
	if raw_tex == null:
		return null

	var px_per_mm: float = dpi/25.4

	var frame_size_px: Vector2i = Vector2i(round(item.size_mm * px_per_mm))

	var viewport: SubViewport = SubViewport.new()
	viewport.size = frame_size_px
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var color_rect: ColorRect = ColorRect.new()
	color_rect.color = Color.WHITE
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT, false)
	viewport.add_child(color_rect)

	var tree: SceneTree = Engine.get_main_loop() as SceneTree

	var shader_mat: ShaderMaterial = null
	if tree and tree.current_scene and tree.current_scene.distort_shader_material:
		shader_mat = tree.current_scene.distort_shader_material
	else:
		Global.notice("Tile Renderer Failed", "Missing Shader Material")
		return null


	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.texture = raw_tex
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.size = image_rect.size * px_per_mm
	tex_rect.position = image_rect.position * px_per_mm
	tex_rect.material = shader_mat
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS

	var homography_mat: Basis = item.get_distort_matrix(tile.sub_asset_index)
	shader_mat.set_shader_parameter("u_homography_matrix", homography_mat if framing.fitting_mode == PhotoItemData.FittingMode.DISTORT else Basis.IDENTITY)
	shader_mat.set_shader_parameter("out_bound_opacity", 0.0)

	viewport.add_child(tex_rect)

	# 4. Attach to scene tree temporarily so the GPU can render it
	tree.root.add_child(viewport)

	# Wait for the GPU to complete the render pass
	await RenderingServer.frame_post_draw

	# 5. Extract the rendered high-res pixels
	var rendered_img: Image = viewport.get_texture().get_image()

	# 6. Clean up temporary viewport from memory
	tree.root.remove_child(viewport)
	viewport.queue_free()

	if rendered_img.get_format() != Image.FORMAT_RGBA8:
		rendered_img.convert(Image.FORMAT_RGBA8)

	return rendered_img

static func bake_tile_image(tile: PhotoTile, dpi: int) -> Image:
	if gpu_render:
		return await bake_tile_image_gpu(tile, dpi)

	var item: PhotoItemData = tile.photo_item
	if item == null or item.asset == null:
		return null

	if item.get_framing(tile.sub_asset_index).fitting_mode == PhotoItemData.FittingMode.DISTORT:
		return await bake_tile_image_gpu(tile, dpi)

	var px_per_mm: float = dpi/25.4

	var tile_w: int = int(tile.rect_mm.size.x * px_per_mm)
	var tile_h: int = int(tile.rect_mm.size.y * px_per_mm)

	var tile_image: Image = Image.create_empty(tile_w, tile_h, false, Image.FORMAT_RGBA8)
	tile_image.fill(Color(1,1,1,1))

	var image_rect_mm: Rect2 = tile.photo_item.get_image_rect_mm(tile.sub_asset_index)

	var source_image: Image = item.asset.get_image(tile.sub_asset_index)
	if source_image.is_empty() or source_image == null:
		return tile_image

	var asset_image: Image = source_image.duplicate()
	if asset_image.get_format() != Image.FORMAT_RGBA8:
		asset_image.convert(Image.FORMAT_RGBA8)

	var crop_size_px: Vector2i = image_rect_mm.size * px_per_mm
	var crop_pos_px: Vector2i = image_rect_mm.position * px_per_mm

	asset_image.resize(crop_size_px.x, crop_size_px.y, Image.INTERPOLATE_LANCZOS)

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
