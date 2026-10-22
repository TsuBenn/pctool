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

	image_import_dialog.files_selected.connect(_on_files_selected)
	save_document_dialog.file_selected.connect(func(file): request_save_document(file))

	canvas_panel.on_photo_item_selected.connect(_on_photo_item_selected)

	properties_panel.request_duplicate.connect(
		func(): canvas_panel._on_photo_tile_context_menu_pressed(CanvasPanel.TILE_DUPLICATE)
	)
	properties_panel.request_copy.connect(
		func(): canvas_panel._on_photo_tile_context_menu_pressed(CanvasPanel.TILE_COPY_PROPERTIES)
	)
	properties_panel.request_paste.connect(
		func(): canvas_panel._on_photo_tile_context_menu_pressed(CanvasPanel.TILE_PASTE_PROPERTIES)
	)

	properties_panel.request_advanced_cropping.connect(_open_advanced_cropping_window)

	_init_children()

	if not quick_import_files.is_empty():
		_on_files_selected(quick_import_files)
		quick_import_files.clear()


func _init_children():
	toolbar.setup(document_data)
	assets_panel.setup(document_data)
	canvas_panel.setup(document_data)
	properties_panel.setup(document_data)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_Z and event.ctrl_pressed:
			if event.shift_pressed:
				Global.undo_redo[document_data].redo()
				accept_event()
			else:
				Global.undo_redo[document_data].undo()
				accept_event()


func _on_photo_item_selected(photo_item: PhotoItemData, sub_asset_index: int):
	properties_panel.photo_item = photo_item
	properties_panel.sub_asset_index = sub_asset_index
	pass


func setup(data: DocumentData, files: PackedStringArray) -> void:
	document_data = data
	quick_import_files = files


func _on_add_asset_to_sheet(
	asset_datas: Array[AssetData],
	add_assets_action: CanvasPanel.AddAssetAction = CanvasPanel.AddAssetAction.ADD,
	select_on_add: bool = false
):
	canvas_panel.add_asset_to_sheet(asset_datas, add_assets_action, select_on_add)


func request_save_document(file: String = document_data.save_path):
	if (
		file.is_empty()
		and (
			document_data.save_path.is_empty()
			or not FileAccess.file_exists(document_data.save_path)
		)
	):
		save_document_dialog.get_line_edit().text = (
			name.to_lower().replace(" ", "-") + DocumentManager.EXTENSION_DOT
		)
		save_document_dialog.popup_centered(Vector2i(600, 400))
		return

	document_data.save_path = file
	if await DocumentManager.save_document(document_data, file) == OK:
		name = file.get_file().get_basename()


func _on_files_selected(files: PackedStringArray) -> void:
	# [
	#     [path, buffer],
	#     [path, buffer],
	#     [path, buffer]
	# ]
	var valid_image_files: Array[Array] = []
	var valid_pdf_files: Array[Array] = []

	for file in files:
		var ext: String = file.get_extension().to_lower()

		if ["png", "jpeg", "jpg", "webp"].has(ext):
			var info = ImageUtil.get_image_info(file)
			if not info.error.is_empty():
				push_error(info.error)
				continue
			valid_image_files.append([file, info])

		if "pdf" == ext:
			var info = PdfUtil.get_pdf_info(file)
			if not info.error.is_empty():
				push_error(info.error)
				continue
			valid_pdf_files.append([file, info])

	if not valid_image_files.is_empty():
		_import_image_files(valid_image_files)
	if not valid_pdf_files.is_empty():
		_import_pdf_files(valid_pdf_files)

# [
#     [path, buffer],
#     [path, buffer],
#     [path, buffer]
# ]
func _import_pdf_files(files: Array[Array]):
	Global.progress_started("Importing PDFs")

	if files.is_empty():
		push_error("Empty files while importing Pdf files")
		return

	Global.set_config("file_dialog_dir", "import", files[0][0].get_base_dir())
	Global.save_config()

	var total_files = files.size()

	var imported_assets: Array[AssetData] = []
	imported_assets.resize(total_files)

	var mutex: Mutex = Mutex.new()
	var shared_counter: Dictionary = {
		"current": 0,
		"total": total_files,
	}

	Global.progress_update(
		"Creating Pdf assets (%d/%d)" % [shared_counter["current"], shared_counter["total"]],
		shared_counter["current"] / float(shared_counter["total"])
	)
	await Engine.get_main_loop().process_frame

	var create_asset = func(i: int):
		var file: String = files[i][0]
		var info: PdfInfo = files[i][1]
		var asset: AssetData = PdfAssetData.create_from_file(file, info)
		if asset:
			imported_assets[i] = asset
		mutex.lock()
		shared_counter["current"] += 1
		mutex.unlock()

	# var group_id: int = WorkerThreadPool.add_group_task(
	# 	create_asset, total_files, -1, true, "IMPORT_ASSETS"
	# )

	# while shared_counter["current"] < shared_counter["total"]:
	# 	Global.progress_update(
	# 		"Creating Image assets (%d/%d)" % [shared_counter["current"], shared_counter["total"]],
	# 		shared_counter["current"] / float(shared_counter["total"])
	# 	)
	# 	await Engine.get_main_loop().process_frame

	# WorkerThreadPool.wait_for_group_task_completion(group_id)

	for i in range(total_files):
		create_asset.call(i)
		Global.progress_update(
			"Creating Pdf assets (%d/%d)" % [shared_counter["current"], shared_counter["total"]],
			shared_counter["current"] / float(shared_counter["total"])
		)
		await Engine.get_main_loop().process_frame

	shared_counter["current"] = 0

	var milestone: int = Time.get_ticks_msec()

	Global.progress_update(
		"Importing Pdf files (%d/%d)" % [shared_counter["current"], shared_counter["total"]],
		shared_counter["current"] / float(shared_counter["total"])
	)
	await Engine.get_main_loop().process_frame

	for asset in imported_assets:
		document_data.assets.append(asset)
		assets_panel.instantiate_asset_card(asset)

		shared_counter["current"] += 1
		if Time.get_ticks_msec() - milestone > 100:
			milestone = Time.get_ticks_msec()
			Global.progress_update(
				(
					"Importing Image files (%d/%d)"
					% [shared_counter["current"], shared_counter["total"]]
				),
				shared_counter["current"] / float(shared_counter["total"])
			)
			await Engine.get_main_loop().process_frame

	PreviewTextureEngine.provide()

	Global.progress_finished()

	PreviewTextureEngine.provide()

	Global.progress_finished()


func _import_image_files(files: Array[Array]):
	Global.progress_started("Importing Images")

	if files.is_empty():
		push_error("Empty files while importing images files")
		return

	Global.set_config("file_dialog_dir", "import", files[0][0].get_base_dir())
	Global.save_config()

	var total_files = files.size()

	var imported_assets: Array[AssetData] = []
	imported_assets.resize(total_files)

	var mutex: Mutex = Mutex.new()
	var shared_counter: Dictionary = {
		"current": 0,
		"total": total_files,
	}

	Global.progress_update(
		"Creating Image assets (%d/%d)" % [shared_counter["current"], shared_counter["total"]],
		shared_counter["current"] / float(shared_counter["total"])
	)
	await Engine.get_main_loop().process_frame

	var create_asset = func(i: int):
		var file: String = files[i][0]
		var info: ImageInfo = files[i][1]
		var asset: AssetData = ImageAssetData.create_from_file(file, info)
		if asset:
			imported_assets[i] = asset
		mutex.lock()
		shared_counter["current"] += 1
		mutex.unlock()

	# var group_id: int = WorkerThreadPool.add_group_task(
	# 	create_asset, total_files, -1, true, "IMPORT_ASSETS"
	# )

	# while shared_counter["current"] < shared_counter["total"]:
	# 	Global.progress_update(
	# 		"Creating Image assets (%d/%d)" % [shared_counter["current"], shared_counter["total"]],
	# 		shared_counter["current"] / float(shared_counter["total"])
	# 	)
	# 	await Engine.get_main_loop().process_frame

	# WorkerThreadPool.wait_for_group_task_completion(group_id)

	for i in range(total_files):
		create_asset.call(i)
		Global.progress_update(
			"Creating Image assets (%d/%d)" % [shared_counter["current"], shared_counter["total"]],
			shared_counter["current"] / float(shared_counter["total"])
		)
		await Engine.get_main_loop().process_frame

	shared_counter["current"] = 0

	var milestone: int = Time.get_ticks_msec()

	Global.progress_update(
		"Importing Image files (%d/%d)" % [shared_counter["current"], shared_counter["total"]],
		shared_counter["current"] / float(shared_counter["total"])
	)
	await Engine.get_main_loop().process_frame

	for asset in imported_assets:
		document_data.assets.append(asset)
		assets_panel.instantiate_asset_card(asset)

		shared_counter["current"] += 1
		if Time.get_ticks_msec() - milestone > 100:
			milestone = Time.get_ticks_msec()
			Global.progress_update(
				(
					"Importing Image files (%d/%d)"
					% [shared_counter["current"], shared_counter["total"]]
				),
				shared_counter["current"] / float(shared_counter["total"])
			)
			await Engine.get_main_loop().process_frame

	PreviewTextureEngine.provide()

	Global.progress_finished()


func _on_import_dialog_requested() -> void:
	var current_dir: String = Global.get_config("file_dialog_dir", "import")
	if DirAccess.dir_exists_absolute(current_dir):
		image_import_dialog.current_dir = current_dir
	image_import_dialog.popup_centered(Vector2i(600, 400))


func _open_advanced_cropping_window():
	var item: PhotoItemData = canvas_panel.selected_photo_item
	var index: int = canvas_panel.selected_sub_asset_index
	advanced_cropping_window.request_open(item, index)
