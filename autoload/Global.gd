extends Node

signal on_noticed(title: String, message: String, ok_button_text: String)

signal on_progress_started(title: String)
signal on_progress_finished()
signal on_progress_updated(message: String, value: float)

signal on_config_changed(section: String, file: String)

var version: String= ProjectSettings.get_setting("application/_config/version", "N/A")

var version_v: String= "v%s" % ProjectSettings.get_setting("application/_config/version", "0")

var undo_redo: Dictionary[DocumentData, UndoRedo] = {}
var is_undoing: bool = false

var app_title_prefix: String= "PCTool %s" % version

var progress_flag: bool = false

var _config : ConfigFile = ConfigFile.new()

var _config_path: String = "user://settings.cfg"

var _default_config: Dictionary = {
	"recent": {
		"files": []
	}
}

func get_config(section: String, key: String) -> Variant:
	var default_value: Variant = null
	if _default_config.has(section) and _default_config[section].has(key):
		default_value = _default_config[section][key]
	else:
		push_error("ConfigFile: _config for key %s of section %s does not exists" % [key, section])
	return _config.get_value(section, key, default_value)

func set_config(section: String, key: String, value: Variant):
	if not _default_config.has(section) or not _default_config[section].has(key):
		push_error("ConfigFile: _config for key %s of section %s does not exists" % [key, section])
		return

	_config.set_value(section, key, value)
	on_config_changed.emit(section, key)

func save_config() -> Error:
	var err: Error = _config.save(_config_path)
	if err != OK:
		push_error("ConfigFile: Failed to write _config to disk: %d" % err)
	return err

func _ready() -> void:
	var err := _config.load(_config_path)

	if err != OK:
		push_warning("ConfigFile: Had trouble loading _config file at %s" % _config_path)

func notice(title: String, message: String, ok_button_text: String = "OK"):
	on_noticed.emit(title, message, ok_button_text)

func progress_finished():
	on_progress_finished.emit()
	progress_flag = false

func cancel_progress():
	progress_flag = true

func progress_started(new: String = ""):
	on_progress_started.emit(new)

func progress_update(message: String = "", value: float = -1):
	on_progress_updated.emit(message, value)

func get_memory_usage_mb():
	return OS.get_static_memory_usage()/(1024.0*1024.0)

func get_video_memory_usage_mb():
	var video_vram: float = 0 #Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	var texture_vram: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	var buffer_vram: float = Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)
	var video_mb: float = video_vram / (1024.0 * 1024.0)
	var texture_mb: float = texture_vram / (1024.0 * 1024.0)
	var buffer_mb: float = buffer_vram / (1024.0 * 1024.0)
	var total_mb: float = texture_mb + buffer_mb + video_mb
	return total_mb

func get_available_os_memory_mb():
	var mem_info = OS.get_memory_info()
	return mem_info["free"] / 1024.0 / 1024.0

func print_memory_usage():
	print(" RAM:   %.2f MB" % get_memory_usage_mb())

func print_video_memory_usage():
	print("VRAM:   %.2f MB" % get_video_memory_usage_mb())

func wait(second: int):
	var tree: SceneTree = Engine.get_main_loop()
	await tree.create_timer(second).timeout

func flatten_string(string: String):
	return string.replace(" ", "").replace("-", "").replace("_", "").to_lower()
