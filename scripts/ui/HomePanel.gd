class_name HomePanel
extends Panel

signal new_document_requested()
signal open_document_requested()
signal import_assets_requested()

@onready var new_document_button: Button = %NewDocumentButton
@onready var open_document_button: Button = %OpenDocumentButton
@onready var import_assets_button: Button = %ImportAssetsButton

@onready var version_label: Label = %VersionLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	new_document_button.pressed.connect(new_document_requested.emit)
	open_document_button.pressed.connect(open_document_requested.emit)
	import_assets_button.pressed.connect(import_assets_requested.emit)

	version_label.text = Global.version_v
