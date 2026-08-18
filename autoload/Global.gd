extends Node

signal on_noticed(title: String, message: String, ok_button_text: String)


func notice(title: String, message: String, ok_button_text: String = "OK"):
	on_noticed.emit(title, message, ok_button_text)
