extends Node

signal on_noticed(title: String, message: String, ok_button_text: String)

var version: String= ProjectSettings.get_setting("application/config/version", "N/A")


var version_v: String= "v%s" % ProjectSettings.get_setting("application/config/version", "0")

var app_title_prefix: String= "PCTool %s" % version

func notice(title: String, message: String, ok_button_text: String = "OK"):
	on_noticed.emit(title, message, ok_button_text)
