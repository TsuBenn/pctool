extends RefCounted
class_name DocumentManager

static var extension: String = ".pctl"

static func save_document(document_data: DocumentData, output_path: String) -> Error:
	if document_data == null:
		Global.notice("Cannot Save Document", "Cannot save null DocumentData!")
		push_error("ProjectFileManager: Cannot save null DocumentData!")
		return ERR_INVALID_PARAMETER

	if not output_path.ends_with(extension):
		output_path += extension

	var save_file = FileAccess.open(output_path, FileAccess.WRITE)
	if save_file == null:
		var err = FileAccess.get_open_error()
		Global.notice("Cannot Save Document", "Failed to save file at: %s (Error: %d)" % [output_path, err])
		push_error("ProjectFileManager: Failed to save file at: %s (Error: %d)" % [output_path, err])
		return err

	var bytes: PackedByteArray = var_to_bytes_with_objects(document_data)
	save_file.store_buffer(bytes.compress(FileAccess.COMPRESSION_GZIP))
	save_file.close()

	return OK

static func open_document(file_path: String) -> DocumentData:
	if not FileAccess.file_exists(file_path):
		Global.notice("Cannot Open Document", "File does not exist at: %s" % file_path)
		push_error("ProjectFileManager: File does not exist at: %s" % file_path)
		return null

	var load_file = FileAccess.open(file_path, FileAccess.READ)
	if load_file == null:
		Global.notice("Cannot Open Document", "Failed to load file at: %s" % file_path)
		push_error("ProjectFileManager: Failed to load file at: %s" % file_path)
		return null

	var compressed_bytes = load_file.get_buffer(load_file.get_length())
	load_file.close()

	var bytes = compressed_bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)

	var doc = bytes_to_var_with_objects(bytes)

	if doc == null:
		Global.notice("Cannot Open Document", "Loaded file is not a valid DocumentData resource: %s" % file_path)
		push_error("ProjectFileManager: Loaded file is not a valid DocumentData resource: %s" % file_path)
		return null

	# 2. Hydrate GPU textures (rebuild ImageTexture from raw Image data)
	_hydrate_assets(doc.assets)

	# 3. Re-connect reactivity signals so modifying items updates the document
	_reconnect_signals(doc)

	return doc


## Iterates through all loaded assets and re-creates their GPU preview textures.
static func _hydrate_assets(assets: Array[AssetData]) -> void:
	for asset in assets:
		if asset is ImageAssetData:
			var img_asset = asset as ImageAssetData
			if img_asset.original_image and not img_asset.original_image.is_empty():
				img_asset.preview_texture = ImageTexture.create_from_image(img_asset.original_image)
				img_asset.pixel_dimensions = img_asset.original_image.get_size()
		# elif asset is GroupAssetData:
		# 	var group_asset = asset as GroupAssetData
		# 	_hydrate_assets(group_asset.children)


## Re-establishes the item.changed -> doc.emit_changed signal links after deserialization.
static func _reconnect_signals(doc: DocumentData) -> void:
	for item in doc.photo_items:
		if item:
			# Disconnect first to ensure no duplicate connections exist
			if item.changed.is_connected(doc.emit_changed):
				item.changed.disconnect(doc.emit_changed)
			item.changed.connect(doc.emit_changed)
