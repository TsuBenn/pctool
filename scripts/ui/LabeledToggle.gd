@tool
extends HBoxContainer

@onready var check_button: CheckButton = $CheckButton

@export var label: String = "Label":
	set(new_label):
		label = new_label
		if is_node_ready():
			$Label.text = new_label

@export var button_pressed: bool = false:
	set(new_toggle):
		button_pressed = new_toggle
		$CheckButton.button_pressed = button_pressed

# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	check_button.toggled.connect(_on_toggled)
	$Label.text = label
	$CheckButton.button_pressed = button_pressed

	pass # Replace with function body.

func _on_toggled(toggle: bool):
	button_pressed = toggle
	pass
