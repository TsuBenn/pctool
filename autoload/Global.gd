extends Node

signal on_noticed(title: String, message: String, ok_button_text: String)

signal on_progress_started(title: String)
signal on_progress_finished()
signal on_progress_updated(message: String, value: float)

var version: String= ProjectSettings.get_setting("application/config/version", "N/A")


var version_v: String= "v%s" % ProjectSettings.get_setting("application/config/version", "0")

var app_title_prefix: String= "PCTool %s" % version

func notice(title: String, message: String, ok_button_text: String = "OK"):
	on_noticed.emit(title, message, ok_button_text)

func progress_finished():
	on_progress_finished.emit()

func progress_started(new: String = ""):
	on_progress_started.emit(new)

func progress_update(message: String = "", value: float = -1):
	on_progress_updated.emit(message, value)
