class_name WorkspaceInstance
extends PanelContainer

var document_data: DocumentData
var quick_import_files: PackedStringArray

@onready var image_import_dialog: FileDialog = %ImageImportDialog
@onready var save_document_dialog: FileDialog = %SaveDocumentDialog

@onready var toolbar: MarginContainer = %Toolbar
@onready var assets_panel: AssetsPanel = %AssetsPanel
@onready var canvas_panel: CanvasPanel = %CanvasPanel
@onready var properties_panel: PropertiesPanel = %PropertiesPanel

@onready var advanced_cropping_window: Window = %AdvancedCroppingWindow

func _ready() -> void:
	assets_panel.request_import_dialog.connect(_on_import_dialog_requested)
	assets_panel.add_asset_to_sheet.connect(_on_add_asset_to_sheet)

	image_import_dialog.files_selected.connect(_on_image_files_selected)
	save_document_dialog.file_selected.connect(func(file): request_save_document(file))

	canvas_panel.on_photo_item_selected.connect(_on_photo_item_selected)

	properties_panel.request_duplicate.connect(
		func():
			canvas_panel._on_photo_tile_context_menu_pressed(CanvasPanel.TILE_DUPLICATE)
	)
	properties_panel.request_copy.connect(
		func():
			canvas_panel._on_photo_tile_context_menu_pressed(CanvasPanel.TILE_COPY_PROPERTIES)
	)
	properties_panel.request_paste.connect(
		func():
			canvas_panel._on_photo_tile_context_menu_pressed(CanvasPanel.TILE_PASTE_PROPERTIES)
	)

	properties_panel.request_advanced_cropping.connect(_open_advanced_cropping_window)

	_init_children()

	if not quick_import_files.is_empty():
		_on_image_files_selected(quick_import_files)
		quick_import_files.clear()

func _init_children():
	toolbar.setup(document_data)
	assets_panel.setup(document_data)
	canvas_panel.setup(document_data)
	properties_panel.setup(document_data)

func _on_photo_item_selected(photo_item: PhotoItemData, sub_asset_index: int):
	properties_panel.photo_item = photo_item
	properties_panel.sub_asset_index = sub_asset_index
	pass

func setup(data: DocumentData, files: PackedStringArray) -> void:
	document_data = data
	quick_import_files = files

func _on_add_asset_to_sheet(asset_datas: Array[AssetData], add_assets_action: CanvasPanel.AddAssetAction = CanvasPanel.AddAssetAction.ADD, select_on_add: bool = false):
	canvas_panel.add_asset_to_sheet(asset_datas, add_assets_action, select_on_add)

func request_save_document(file: String = document_data.save_path):
	if file.is_empty() or not FileAccess.file_exists(document_data.save_path):
		save_document_dialog.get_line_edit().text = name.to_lower().replace(" ", "-") + DocumentManager.EXTENSION_DOT
		save_document_dialog.popup_centered(Vector2i(600,400))
		return

	document_data.save_path = file
	if await DocumentManager.save_document(document_data, file) == OK:
		name = file.get_file().get_basename()

func _on_image_files_selected(files: PackedStringArray) -> void:

	Global.progress_started("Importing")

	var asset_buffer_map: Dictionary = {}
	var asset_buffer_keys: Array = []

	var imported_buffers: int = 0

	for file in files:
		var buffer: PackedByteArray = FileAccess.get_file_as_bytes(file)
		if buffer.is_empty():
			push_error("Cannot import file at %s (Reason: Empty)" % file)
			continue
		asset_buffer_map[file] = buffer
		imported_buffers += 1

	asset_buffer_keys = asset_buffer_map.keys()

	var imported_assets: Array = []
	imported_assets.resize(imported_buffers)

	var mutex: Mutex = Mutex.new()
	var shared_counter: Dictionary = {
		"current": 0,
		"total": imported_buffers,
	}

	Global.progress_update("Creating assets (%d/%d)" % [shared_counter["current"],shared_counter["total"]], shared_counter["current"]/float(shared_counter["total"]))
	await Engine.get_main_loop().process_frame

	var create_asset = func(i: int):
		var file: String = asset_buffer_keys[i]
		var buffer: PackedByteArray = asset_buffer_map[file]
		var asset: AssetData = ImageAssetData.create_from_buffer(buffer, file)
		if asset:
			imported_assets[i] = asset
			# document_data.assets.append(asset)
			# assets_panel.instantiate_asset_card.call_deferred(asset)
		mutex.lock()
		shared_counter["current"] += 1
		mutex.unlock()

	var group_id: int = WorkerThreadPool.add_group_task(
		create_asset,
		files.size(),
		-1,
		true,
		"IMPORT_ASSETS"
	)

	while shared_counter["current"] < shared_counter["total"]:
		Global.progress_update("Creating assets (%d/%d)" % [shared_counter["current"],shared_counter["total"]], shared_counter["current"]/float(shared_counter["total"]))
		await Engine.get_main_loop().process_frame

	WorkerThreadPool.wait_for_group_task_completion(group_id)

	shared_counter["current"] = 0

	var milestone: int = Time.get_ticks_msec()

	Global.progress_update("Importing files (%d/%d)" % [shared_counter["current"],shared_counter["total"]], shared_counter["current"]/float(shared_counter["total"]))
	await Engine.get_main_loop().process_frame

	for asset in imported_assets:
		document_data.assets.append(asset)
		assets_panel.instantiate_asset_card(asset)

		shared_counter["current"] += 1
		if Time.get_ticks_msec() - milestone > 100:
			milestone = Time.get_ticks_msec()
			Global.progress_update("Importing files (%d/%d)" % [shared_counter["current"],shared_counter["total"]], shared_counter["current"]/float(shared_counter["total"]))
			await Engine.get_main_loop().process_frame


	Global.progress_finished()

func _on_import_dialog_requested() -> void:
	image_import_dialog.popup_centered(Vector2i(600, 400))

func _open_advanced_cropping_window():
	var item: PhotoItemData = canvas_panel.selected_photo_item
	var index: int = canvas_panel.selected_sub_asset_index
	advanced_cropping_window.request_open(item, index)
