@tool
extends HBoxContainer
class_name LabeledSpinBox

signal value_changed(new_value: float)

@export var label: String = "Label:":
	set(new_text):
		label = new_text
		if is_node_ready():
			$Label.text = new_text

@export var editable: bool = true:
	set(new_val):
		editable = new_val
		if is_node_ready():
			$SpinBox.editable = new_val

@export var prefix: String = "":
	set(new_prefix):
		prefix = new_prefix
		if is_node_ready():
			$SpinBox.prefix = new_prefix

@export var suffix: String = "":
	set(new_suffix):
		suffix = new_suffix
		if is_node_ready():
			$SpinBox.suffix = new_suffix

@export var value: float = 0.0:
	set(new_val):
		value = new_val
		if is_node_ready():
			$SpinBox.value = value

@export var min_value: float = 0.0:
	set(new_min):
		min_value = new_min
		if is_node_ready():
			$SpinBox.min_value = min_value

@export var max_value: float = 100.0:
	set(new_max):
		max_value = new_max
		if is_node_ready():
			$SpinBox.max_value = max_value

@export var step: float = 1.0:
	set(new_step):
		step = new_step
		if is_node_ready():
			$SpinBox.step = step

@export var spinbox_width: int = 0:
	set(new_width):
		spinbox_width = max(new_width, 0)
		if is_node_ready():
			$SpinBox.custom_minimum_size = Vector2(new_width, 0)

func _ready() -> void:
	# Push initial values to child nodes once they are loaded
	$Label.text = label
	$SpinBox.editable = editable
	$SpinBox.prefix = prefix
	$SpinBox.suffix = suffix
	$SpinBox.custom_minimum_size = Vector2(spinbox_width, 0)
	$SpinBox.value = value
	$SpinBox.min_value = min_value
	$SpinBox.max_value = max_value
	$SpinBox.step = step

	# Forward the inner SpinBox signal to our custom outer signal
	if not Engine.is_editor_hint():
		$SpinBox.value_changed.connect(_on_spin_box_value_changed)


func _on_spin_box_value_changed(new_value: float) -> void:
	value = new_value
	value_changed.emit(new_value)
