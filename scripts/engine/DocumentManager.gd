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

	Global.progress_started("Saving %s%s" % [output_path.get_file().get_basename(), EXTENSION_DOT])

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
	var saved_asset_id: Array[String] = []

	Global.progress_update("Writing Asset Datas (%d/%d)" % [0, doc.assets.size()], 0)
	await Engine.get_main_loop().process_frame

	var saved: int = 0
	var milestone: float = Time.get_ticks_msec()

	var start_time: float = Time.get_ticks_usec()

	for asset in doc.assets:
		if saved_asset_id.has(asset.id):
			continue
		if asset is ImageAssetData:
			var image_asset_manifest: Dictionary = get_image_asset_manifest(asset)
			asset_manifest_list.append(image_asset_manifest)
			saved_asset_id.append(asset.id)
		if asset is PdfAssetData:
			var pdf_asset_manifest: Dictionary = get_pdf_asset_manifest(asset)
			asset_manifest_list.append(pdf_asset_manifest)
			saved_asset_id.append(asset.id)
		if asset is GroupAssetData:
			var sub_assets: Array[Dictionary] = []
			for sub_asset in asset.flatten():
				if sub_asset is ImageAssetData:
					var image_asset_manifest: Dictionary = get_image_asset_manifest(sub_asset)
					sub_assets.append(image_asset_manifest)
					if not saved_asset_id.has(sub_asset.id):
						saved_asset_id.append(sub_asset.id)

			saved_asset_id.append(asset.id)
			asset_manifest_list.append({
				"id": asset.id,
				"type": "group",
				"display_name": asset.display_name,
				"children": sub_assets
			})

		saved += 1
		if Time.get_ticks_msec() - milestone > 100:
			milestone = Time.get_ticks_msec()
			Global.progress_update("Writing Asset Datas (%d/%d)" % [float(saved), doc.assets.size()], float(saved)/doc.assets.size())
			await Engine.get_main_loop().process_frame

	print("Saving Asset: " + str((Time.get_ticks_usec() - start_time)/1000.0) + "ms")

	saved = 0

	Global.progress_update("Writing Photo Item Datas (%d/%d)" % [0, doc.photo_items.size()], 0)
	await Engine.get_main_loop().process_frame

	milestone = Time.get_ticks_msec()

	# 2. Serialize photo items (referencing assets by their ID)
	var item_manifest_list: Array[Dictionary] = []
	for item in doc.photo_items:
		if item == null or item.asset == null:
			continue

		var framings: Dictionary = {}

		for index in range(item.framings.size()):
			framings[index] = {
				"scale": item.framings[index].scale,
				"offset": [item.framings[index].offset.x, item.framings[index].offset.y],
				"fitting_mode": item.framings[index].fitting_mode,
				"top_left_corner": [item.framings[index].top_left_corner.x, item.framings[index].top_left_corner.y],
				"top_right_corner": [item.framings[index].top_right_corner.x, item.framings[index].top_right_corner.y],
				"bottom_right_corner": [item.framings[index].bottom_right_corner.x, item.framings[index].bottom_right_corner.y],
				"bottom_left_corner": [item.framings[index].bottom_left_corner.x, item.framings[index].bottom_left_corner.y],
			}

		item_manifest_list.append({
			"asset_id": item.asset.id,
			"size_mm": [item.size_mm.x, item.size_mm.y],
			"isolate_row": item.isolate_row,
			"isolate_page": item.isolate_page,
			"quantity": item.quantity,
			"framings": framings,
			"border_enabled": item.border_enabled,
			"border_width": item.border_width,
			"border_color": [item.border_color.r, item.border_color.g, item.border_color.b, item.border_color.a]
		})

		saved += 1
		if Time.get_ticks_msec() - milestone > 100:
			milestone = Time.get_ticks_msec()
			Global.progress_update("Writing Photo Item Datas (%d/%d)" % [float(saved), doc.photo_items.size()], float(saved)/doc.photo_items.size())
			await Engine.get_main_loop().process_frame

	# 3. Assemble root project manifest dictionary
	var project_data: Dictionary = {
		"version": "2.0",
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

	var recents: Array = Global.get_config("recent", "files")

	if recents.has(output_path):
		recents.erase(output_path)
	recents.append(output_path)

	Global.set_config("recent", "files", recents)
	Global.save_config()

	Global.progress_finished()
	packer.close()
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

	Global.progress_started("Opening %s%s" % [file_path.get_file().get_basename(), EXTENSION_DOT])

	var manifest_bytes: PackedByteArray = reader.read_file(MANIFEST_FILENAME)
	var manifest_str: String = manifest_bytes.get_string_from_utf8()

	var json: JSON = JSON.new()
	if json.parse(manifest_str) != OK:
		Global.notice("Parsing Error", "Failed to parse project data:\n%s" % json.get_error_message())
		push_error("DocumentManager: Failed to parse JSON manifest: %s" % json.get_error_message())
		reader.close()
		Global.progress_finished()
		return null

	var data: Dictionary = json.data
	var doc: DocumentData = DocumentData.new()

	if data.has("version"):
		if data["version"] != "2.0":
			Global.progress_finished()
			Global.notice("Incompatible Version", "This Document's version isn't compatible with the current version of the program.")
			return null
	else:
		Global.progress_finished()
		Global.notice("Unknown Version", "This Document doesn't version.")
		return null


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

	var opened: int = 0

	Global.progress_update("Loading Asset Datas (%d/%d)" % [float(opened), assets_arr.size()], float(opened)/assets_arr.size())
	await Engine.get_main_loop().process_frame

	for asset_dict in assets_arr:
		var type: String = asset_dict.get("type", "")

		if type.is_empty():
			push_error("DocumentManager: Unknown Asset Type")
			continue

		match type:
			"image":
				if asset_map.has(asset_dict.get("id", "")):
					continue
				var source_path = asset_dict.get("source_path", "")
				if not FileAccess.file_exists(source_path):
					push_error("Asset doesn't exists on device anymore! Source path: %s" % source_path)
					continue
				asset_map[asset_dict.get("id", "")] = ImageAssetData.create_from_file(source_path)
			"pdf":
				if asset_map.has(asset_dict.get("id", "")):
					continue
				var source_path = asset_dict.get("source_path", "")
				if not FileAccess.file_exists(source_path):
					push_error("Asset doesn't exists on device anymore! Source path: %s" % source_path)
					continue
				asset_map[asset_dict.get("id", "")] = PdfAssetData.create_from_file(source_path)
			"group":
				if asset_dict.children.size() <= 1:
					push_error("DocumentManager: Invalid Group Asset %s" % asset_dict.id)
					continue
				for child in asset_dict.get("children", []):
					if asset_map.has(child.get("id", "")):
						continue
					var source_path = child.get("source_path", "")
					if not FileAccess.file_exists(source_path):
						push_error("Asset in Group Asset doesn't exists on device anymore! Source path: %s" % source_path)
						continue
					asset_map[child.get("id", "")] = ImageAssetData.create_from_file(source_path)

				var child_assets: Array[AssetData] = []

				for child in asset_dict.get("children", []):
					if not asset_map.has(child.get("id", "")):
						continue
					child_assets.append(asset_map[child.get("id", "")])

				asset_map[asset_dict.get("id", "")] = GroupAssetData.create_from_assets(child_assets, asset_dict.get("display_name", "UNKNOWN GROUP"))


		opened += 1
		Global.progress_update("Loading Asset Datas (%d/%d)" % [float(opened), assets_arr.size()], float(opened)/assets_arr.size())
		await Engine.get_main_loop().process_frame

	for asset: AssetData in asset_map.values():
		if asset:
			# if asset is ImageAssetData:
			# 	if not asset.thumbnail:
			# 		asset.generate_thumbnail()
			doc.assets.append(asset)

	PreviewTextureEngine.provide()

	# 4. Reconstruct PhotoItemData list
	var items_arr: Array = data.get("photo_items", [])

	opened = 0

	Global.progress_update("Loading Photo Item Datas (%d/%d)" % [float(opened), items_arr.size()], float(opened)/items_arr.size())
	await Engine.get_main_loop().process_frame

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

			var offset: Array = framings.get("offset", [0.0,0.0])
			var top_left_corner: Array = framings.get("top_left_corner", [0.0,0.0])
			var top_right_corner: Array = framings.get("top_right_corner", [1.0,0.0])
			var bottom_right_corner: Array = framings.get("bottom_right_corner", [1.0,1.0])
			var bottom_left_corner: Array = framings.get("bottom_left_corner", [0.0,1.0])

			item.set_framing(
				int(index),
				framings.scale,
				Vector2(offset[0], offset[1]),
				framings.fitting_mode as PhotoItemData.FittingMode,
				Vector2(top_left_corner[0],top_left_corner[1]),
				Vector2(top_right_corner[0],top_right_corner[1]),
				Vector2(bottom_right_corner[0],bottom_right_corner[1]),
				Vector2(bottom_left_corner[0],bottom_left_corner[1]),
			)

		item.border_enabled = bool(item_dict.get("border_enabled", false))
		item.border_width = float(item_dict.get("border_width", 1.0))

		var color_arr: Array = item_dict.get("border_color", [0.0, 0.0, 0.0, 1.0])
		item.border_color = Color(color_arr[0], color_arr[1], color_arr[2], color_arr[3])

		doc.add_photo_item_no_signal(item)

		# item.commit_size()

		opened += 1

		Global.progress_update("Loading Photo Item Datas (%d/%d)" % [float(opened), items_arr.size()], float(opened)/items_arr.size())
		await Engine.get_main_loop().process_frame

	# Global.undo_redo[doc].clear_history()

	Global.progress_finished()
	reader.close()
	return doc

static func get_image_asset_manifest(asset: ImageAssetData) -> Dictionary:
	return {
			"id": asset.id,
			"type": "image",
			"display_name": asset.display_name,
			"source_path": asset.source_path,
		}

static func get_pdf_asset_manifest(asset: PdfAssetData) -> Dictionary:
	return {
			"id": asset.id,
			"type": "pdf",
			"display_name": asset.display_name,
			"source_path": asset.source_path,
		}

