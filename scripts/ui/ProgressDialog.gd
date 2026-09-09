extends Window

@onready var message: Label = %Message
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var cancel_button: Button = %CancelButton

func _ready() -> void:
	cancel_button.pressed.connect(
		func():
			hide()
	)
	close_requested.connect(
		func():
			hide()
	)
	Global.on_progress_finished.connect(
		func():
			hide()
	)
	Global.on_progress_started.connect(
		func(new):
			title = new
			popup_centered()
	)
	Global.on_progress_updated.connect(
		func(new_message, new_value):
			if not new_message.is_empty():
				set_message(new_message)
			if new_value != -1:
				set_progress(new_value)
	)

func set_progress(new: float):
	progress_bar.value = new

func set_message(new: String):
	message.text = new

