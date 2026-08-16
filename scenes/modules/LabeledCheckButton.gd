@tool
extends HBoxContainer
class_name LabeledCheckButton

signal toggled(toggled_on: bool)

@export var label: String = "Label:":
	set(new_val):
		label = new_val
		if is_node_ready():
			$Label.text = new_val

@export var disabled: bool = false:
	set(new_val):
		disabled = new_val
		if is_node_ready():
			$CheckButton.disabled = new_val

@export var button_pressed: bool = false:
	set(new_val):
		if (button_pressed == new_val):
			return
		button_pressed = new_val
		if is_node_ready():
			$CheckButton.button_pressed = new_val

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Label.text = label
	$CheckButton.disabled = disabled
	$CheckButton.button_pressed = button_pressed

	if not Engine.is_editor_hint():
		$CheckButton.toggled.connect(_on_toggled)

func _on_toggled(toggled_on: bool):
	button_pressed = toggled_on
	toggled.emit(toggled_on)
