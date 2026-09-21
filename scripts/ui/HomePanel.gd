class_name HomePanel
extends Panel

signal new_document_requested()
signal open_document_requested()
signal open_recent_requested(file: String)
signal import_assets_requested()

@onready var new_document_button: Button = %NewDocumentButton
@onready var open_document_button: Button = %OpenDocumentButton
@onready var import_assets_button: Button = %ImportAssetsButton

@onready var version_label: Label = %VersionLabel

@onready var recents_vbox_container: VBoxContainer = %RecentsVBoxContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	new_document_button.pressed.connect(new_document_requested.emit)
	open_document_button.pressed.connect(open_document_requested.emit)
	import_assets_button.pressed.connect(import_assets_requested.emit)

	Global.on_config_changed.connect(
		func(section, key):
			if section == "recent" and key == "files":
				_sync_recents_list()
	)

	version_label.text = Global.version_v

	_sync_recents_list()


func _sync_recents_list():
	for child in recents_vbox_container.get_children():
		recents_vbox_container.remove_child(child)
		child.queue_free()

	var recent_files: Array = Global.get_config("recent", "files")
	recent_files.reverse()

	for file: String in recent_files:
		var button: Button = Button.new()

		button.text = file.get_file()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.theme_type_variation = "FlatButton"
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS

		button.pressed.connect(open_recent_requested.emit.bind(file))

		recents_vbox_container.add_child(button)

