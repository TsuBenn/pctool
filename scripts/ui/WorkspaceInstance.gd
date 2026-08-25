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

func _ready() -> void:
	assets_panel.request_import_dialog.connect(_on_import_dialog_requested)
	assets_panel.add_asset_to_sheet.connect(_on_add_asset_to_sheet)

	image_import_dialog.files_selected.connect(_on_image_files_selected)
	save_document_dialog.file_selected.connect(func(file): request_save_document(file))

	canvas_panel.on_photo_item_selected.connect(_on_photo_item_selected)
	properties_panel.add_asset_to_sheet.connect(_on_add_asset_to_sheet)
	_init_children()

	if not quick_import_files.is_empty():
		_on_image_files_selected(quick_import_files)
		quick_import_files.clear()

func _init_children():
	toolbar.setup(document_data)
	assets_panel.setup(document_data)
	canvas_panel.setup(document_data)
	properties_panel.setup(document_data)

func _on_photo_item_selected(photo_item: PhotoItemData):
	properties_panel.photo_item = photo_item
	pass

func setup(data: DocumentData, files: PackedStringArray) -> void:
	document_data = data
	quick_import_files = files

func _on_add_asset_to_sheet(asset_datas: Array[AssetData], add_assets_action: CanvasPanel.AddAssetAction = CanvasPanel.AddAssetAction.ADD, select_on_add: bool = false):
	canvas_panel.add_asset_to_sheet(asset_datas, add_assets_action, select_on_add)

func request_save_document(file: String = document_data.save_path):
	var save_path = document_data.save_path
	if file.is_empty() and (save_path.is_empty() or not FileAccess.file_exists(save_path)):
		save_document_dialog.get_line_edit().text = name.to_lower().replace(" ", "-") + DocumentManager.EXTENSION_DOT
		save_document_dialog.popup_centered(Vector2i(600,400))
		return

	document_data.save_path = file
	if DocumentManager.save_document(document_data, file) == OK:
		name = file.get_file().get_basename()

func _on_image_files_selected(files: PackedStringArray) -> void:
	for file in files:
		var asset: AssetData = ImageAssetData.create_from_file(file)
		if asset:
			document_data.assets.append(asset)
			assets_panel.instantiate_asset_card(asset)

func _on_import_dialog_requested() -> void:
	image_import_dialog.popup_centered(Vector2i(600, 400))
