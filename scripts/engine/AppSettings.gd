class_name AppSettings
extends RefCounted

const CONFIG_PATH: String = "user://settings.cfg"
const MAX_RECENT_FILES: int = 8

# Section Names
const SEC_LAYOUT: String = "Layout"
const SEC_RECENT: String = "Recent"


## Loads all saved settings into a ConfigFile instance.
static func _load_config() -> ConfigFile:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("AppSettings: Failed to load config file: %d" % err)
	return config


## Saves the ConfigFile back to user:// directory.
static func _save_config(config: ConfigFile) -> void:
	var err = config.save(CONFIG_PATH)
	if err != OK:
		push_error("AppSettings: Failed to save config file: %d" % err)


# ==============================================================================
# RECENT FILES MANAGEMENT
# ==============================================================================

## Returns the list of recent .pctl file paths that still exist on disk.
static func get_recent_files() -> Array[String]:
	var config = _load_config()
	var raw_list = config.get_value(SEC_RECENT, "files", [])

	var valid_files: Array[String] = []
	var list_modified: bool = false

	# Filter out files that may have been deleted/moved outside the app
	for path in raw_list:
		if typeof(path) == TYPE_STRING and FileAccess.file_exists(path):
			valid_files.append(path)
		else:
			list_modified = true

	# If missing files were pruned, update the config file
	if list_modified:
		config.set_value(SEC_RECENT, "files", valid_files)
		_save_config(config)

	return valid_files


## Adds a file path to the top of the recent list, deduplicates, and caps at MAX_RECENT_FILES.
static func add_recent_file(file_path: String) -> void:
	if file_path.is_empty():
		return

	var config = _load_config()
	var list: Array = config.get_value(SEC_RECENT, "files", [])

	# Remove if already in list to avoid duplicates
	list.erase(file_path)

	# Push to top of list
	list.push_front(file_path)

	# Cap list length
	while list.size() > MAX_RECENT_FILES:
		list.pop_back()

	config.set_value(SEC_RECENT, "files", list)
	_save_config(config)


# ==============================================================================
# UI PANEL SPLIT & WINDOW SIZES
# ==============================================================================

## Saves split panel positions (e.g. Assets splitter and Properties splitter).
static func save_split_offsets(assets_split: int, properties_split: int) -> void:
	var config = _load_config()
	config.set_value(SEC_LAYOUT, "assets_split_offset", assets_split)
	config.set_value(SEC_LAYOUT, "properties_split_offset", properties_split)
	_save_config(config)


## Loads saved split panel offsets. Returns default values if no save exists.
static func get_split_offsets() -> Dictionary:
	var config = _load_config()
	return {
		"assets_split": config.get_value(SEC_LAYOUT, "assets_split_offset", 0),
		"properties_split": config.get_value(SEC_LAYOUT, "properties_split_offset", 0)
	}
