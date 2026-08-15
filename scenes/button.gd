extends Button

var file_dialog: FileDialog

func _ready() -> void:
	pressed.connect(_on_pressed)

	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray([
		"*.png, *.jpg, *.jpeg, *.webp ; Supported Images"
	])
	file_dialog.use_native_dialog = true
	file_dialog.files_selected.connect(_on_files_selected)
	add_child(file_dialog)

func _on_pressed() -> void:
	file_dialog.popup_centered(Vector2i(800, 500))

func _on_files_selected(paths: PackedStringArray) -> void:
	print("--- Selected Files via FileDialog ---")
	for path in paths:
		print("  -> ", path)

	var drop_pos: Vector2 = get_viewport().get_mouse_position()
	GlobalSignalBus.files_dropped.emit(paths, drop_pos)
