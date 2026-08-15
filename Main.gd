extends Node

func _ready() -> void:
	get_window().files_dropped.connect(_on_files_dropped)

func _on_files_dropped(files: PackedStringArray) -> void:
	print("--- Drop Event Detected ---")

	for item in files:
		if FileAccess.file_exists(item):
			print("Valid File Path: ", item)
			# Safe to emit to GlobalSignalBus here
		else:
			print("Ignored (Not a file on disk, likely raw text): ", item.left(30), "...")
