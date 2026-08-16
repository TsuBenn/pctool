class_name WorkspaceInstance
extends PanelContainer

var document: DocumentData

@onready var image_import_dialog: FileDialog = %ImageImportDialog

@onready var assets_panel: AssetsPanel = %AssetsPanel

func _ready() -> void:
	assets_panel.request_import_dialog.connect(_on_import_dialog_requested)
	image_import_dialog.files_selected.connect(_on_files_selected)


func setup(data: DocumentData) -> void:
	document = data

func _on_files_selected(files: PackedStringArray):
	for file in files:
		var asset: AssetData = ImageAssetData.create_from_file(file)
		if asset:
			document.assets.append(asset)
			assets_panel.instantiate_asset_card(asset)
	pass

func _on_import_dialog_requested():
	image_import_dialog.popup_centered(Vector2i(300, 200))
