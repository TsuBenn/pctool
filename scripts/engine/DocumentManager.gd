class_name DocumentManager
extends RefCounted

const EXTENSION: String = "pctl"
const EXTENSION_DOT: String = ".pctl"
const MANIFEST_FILENAME: String = "project.json"


## Saves a DocumentData instance into a self-contained ZIP-based .pctl package.
static func save_document(doc: DocumentData, output_path: String) -> Error:
	if doc == null:
		Global.notice("Cannot Save Document", "No active document found to save.")
		push_error("DocumentManager: Cannot save null DocumentData!")
		return ERR_INVALID_PARAMETER

	if not output_path.ends_with(EXTENSION_DOT):
		output_path += EXTENSION_DOT

	var packer: ZIPPacker = ZIPPacker.new()
	var err: Error = packer.open(output_path, ZIPPacker.APPEND_CREATE)
	if err != OK:
		Global.notice("Save Failed", "Failed to create project file at:\n%s\n(Error code: %d)" % [output_path, err])
		push_error("DocumentManager: Failed to create package at %s (Error: %d)" % [output_path, err])
		return err

	# 1. Write each unique asset's original compressed bytes into assets/
	var asset_manifest_list: Array[Dictionary] = []
	for asset in doc.assets:
		if asset is ImageAssetData:
			var img_asset: ImageAssetData = asset as ImageAssetData
			var ext: String = img_asset.file_extension if not img_asset.file_extension.is_empty() else "png"
			var internal_name: String = "%s.%s" % [img_asset.id, ext]
			var archive_path: String = "assets/%s" % internal_name

			# Grab raw buffer directly with zero re-encoding overhead
			var img_bytes: PackedByteArray = img_asset.raw_file_buffer
			if img_bytes.is_empty():
				img_bytes = img_asset.original_image.save_png_to_buffer()

			packer.start_file(archive_path)
			packer.write_file(img_bytes)
			packer.close_file()

			asset_manifest_list.append({
				"id": img_asset.id,
				"display_name": img_asset.display_name,
				"source_path": img_asset.source_path,
				"file_name": internal_name
			})

	# 2. Serialize photo items (referencing assets by their ID)
	var item_manifest_list: Array[Dictionary] = []
	for item in doc.photo_items:
		if item == null or item.asset == null:
			continue

		var framings: Dictionary = {}

		for index in item.framings.keys():
			framings[index] = {
				"scale": item.framings[index].scale,
				"offset": [item.framings[index].offset.x, item.framings[index].offset.y],
				"fitting_mode": item.framings[index].fitting_mode,
			}

		item_manifest_list.append({
			"asset_id": item.asset.id,
			"size_mm": [item.size_mm.x, item.size_mm.y],
			"isolate_row": item.rotation,
			"isolate_page": item.isolate_page,
			"quantity": item.quantity,
			"framings": framings,
			"border_enabled": item.border_enabled,
			"border_width": item.border_width,
			"border_color": [item.border_color.r, item.border_color.g, item.border_color.b, item.border_color.a]
		})

	# 3. Assemble root project manifest dictionary
	var project_data: Dictionary = {
		"version": "1.0",
		"paper_size_mm": [doc.paper_size_mm.x, doc.paper_size_mm.y],
		"is_landscape": doc.is_landscape,
		"dpi": doc.dpi,
		"margins_mm": doc.margins_mm,
		"spacing_mm": doc.spacing_mm,
		"assets": asset_manifest_list,
		"photo_items": item_manifest_list
	}

	# 4. Write JSON manifest into the root of the ZIP package
	var json_string: String = JSON.stringify(project_data, " ")
	packer.start_file(MANIFEST_FILENAME)
	packer.write_file(json_string.to_utf8_buffer())
	packer.close_file()

	packer.close()
	# Global.notice("Document Saved", "Project successfully saved to:\n%s" % output_path.get_file())
	return OK


## Loads and unpacks a .pctl ZIP archive back into a live DocumentData instance.
static func open_document(file_path: String) -> DocumentData:
	if not FileAccess.file_exists(file_path):
		Global.notice("Cannot Open Document", "The selected file does not exist:\n%s" % file_path)
		push_error("DocumentManager: File does not exist at: %s" % file_path)
		return null

	var reader: ZIPReader = ZIPReader.new()
	var err: Error = reader.open(file_path)
	if err != OK:
		Global.notice("Open Failed", "Failed to read project archive:\n%s\n(Error code: %d)" % [file_path.get_file(), err])
		push_error("DocumentManager: Failed to open ZIP package at %s (Error: %d)" % [file_path, err])
		return null

	# 1. Read project.json
	if not reader.file_exists(MANIFEST_FILENAME):
		Global.notice("Corrupted File", "This project file is missing its manifest (%s) and cannot be opened." % MANIFEST_FILENAME)
		push_error("DocumentManager: Corrupted project file (missing %s)" % MANIFEST_FILENAME)
		reader.close()
		return null

	var manifest_bytes: PackedByteArray = reader.read_file(MANIFEST_FILENAME)
	var manifest_str: String = manifest_bytes.get_string_from_utf8()

	var json: JSON = JSON.new()
	if json.parse(manifest_str) != OK:
		Global.notice("Parsing Error", "Failed to parse project data:\n%s" % json.get_error_message())
		push_error("DocumentManager: Failed to parse JSON manifest: %s" % json.get_error_message())
		reader.close()
		return null

	var data: Dictionary = json.data
	var doc: DocumentData = DocumentData.new()

	# 2. Restore document paper & margin settings
	var paper_arr: Array = data.get("paper_size_mm", [210.0, 297.0])
	doc.paper_size_mm = Vector2(paper_arr[0], paper_arr[1])
	doc.is_landscape = data.get("is_landscape", false)
	doc.dpi = int(data.get("dpi", 300))
	doc.margins_mm = float(data.get("margins_mm", 5.0))
	doc.spacing_mm = float(data.get("spacing_mm", 5.0))

	# 3. Unpack and hydrate assets
	var asset_map: Dictionary = {} # asset_id -> AssetData
	var assets_arr: Array = data.get("assets", [])

	for asset_dict in assets_arr:
		var asset_id: String = asset_dict.get("id", "")
		var internal_name: String = asset_dict.get("file_name", "")
		var archive_img_path: String = "assets/%s" % internal_name

		if reader.file_exists(archive_img_path):
			var img_bytes: PackedByteArray = reader.read_file(archive_img_path)
			if img_bytes.is_empty():
				push_error("DocumentManager: Asset file in archive is empty: %s" % archive_img_path)
				continue

			var img: Image = Image.new()
			var img_err: Error = FAILED
			var ext: String = internal_name.get_extension().to_lower()

			# Determine loader priority based on stored extension, with safety fallbacks
			if ext in ["jpg", "jpeg"]:
				img_err = img.load_jpg_from_buffer(img_bytes)
				if img_err != OK: img_err = img.load_png_from_buffer(img_bytes)
				if img_err != OK: img_err = img.load_webp_from_buffer(img_bytes)
			elif ext == "webp":
				img_err = img.load_webp_from_buffer(img_bytes)
				if img_err != OK: img_err = img.load_png_from_buffer(img_bytes)
				if img_err != OK: img_err = img.load_jpg_from_buffer(img_bytes)
			else: # Default try PNG first
				img_err = img.load_png_from_buffer(img_bytes)
				if img_err != OK: img_err = img.load_jpg_from_buffer(img_bytes)
				if img_err != OK: img_err = img.load_webp_from_buffer(img_bytes)

			if img_err != OK:
				push_error("DocumentManager: Failed to decode image from archive: %s" % archive_img_path)
				continue

			var tex: Texture2D = ImageTexture.create_from_image(img)
			var dim: Vector2i = img.get_size()
			var display_name: String = asset_dict.get("display_name", "")
			var source_path: String = asset_dict.get("source_path", "")

			# Instantiate the asset
			var asset_obj: ImageAssetData = ImageAssetData.new(
				asset_id,
				display_name,
				source_path,
				tex,
				img,
				dim
			)

			# Store the cached buffer and extension so subsequent saves are instant
			asset_obj.raw_file_buffer = img_bytes
			asset_obj.file_extension = ext

			doc.assets.append(asset_obj)
			asset_map[asset_id] = asset_obj

	# 4. Reconstruct PhotoItemData list
	var items_arr: Array = data.get("photo_items", [])
	for item_dict in items_arr:
		var asset_id: String = item_dict.get("asset_id", "")
		if not asset_map.has(asset_id):
			continue

		var item: PhotoItemData = PhotoItemData.new()
		item.asset = asset_map[asset_id]

		var size_arr: Array = item_dict.get("size_mm", [30.0, 40.0])
		item.size_mm = Vector2(size_arr[0], size_arr[1])

		item.isolate_row = bool(item_dict.get("isolate_row", false))
		item.isolate_page = bool(item_dict.get("isolate_page", false))

		item.quantity = int(item_dict.get("quantity", 1))

		for index in item_dict.get("framings", {}).keys():
			var framings = item_dict.get("framings")[index]
			item.set_framing(index, framings.scale, Vector2(framings.offset[0], framings.offset[1]), framings.fitting_mode as PhotoItemData.FittingMode)

		item.border_enabled = bool(item_dict.get("border_enabled", false))
		item.border_width = float(item_dict.get("border_width", 1.0))

		var color_arr: Array = item_dict.get("border_color", [0.0, 0.0, 0.0, 1.0])
		item.border_color = Color(color_arr[0], color_arr[1], color_arr[2], color_arr[3])

		doc.add_photo_item_no_signal(item)

	reader.close()
	return doc
